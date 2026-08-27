//
//  BoardScene.swift
//  Project Stars
//
//  The top screen as a retained scene rather than a rebuilt view tree.
//

import SpriteKit
import SwiftUI

/// The world, drawn once and then moved.
///
/// ## Why
///
/// The SwiftUI board describes itself from scratch whenever the session
/// publishes — twenty-four times a second while a move resolves — and SwiftUI
/// then diffs and lays out the result. That cost does not scale with what is on
/// the board, which is why removing the ground, the panel, the clouds, the
/// trail and the glow each bought a few frames and none of them fixed it.
///
/// A scene does not work that way. The nodes exist. Moving the piece is setting
/// `position`; moving the camera is setting `position`. `update(_:)` runs on
/// SpriteKit's own loop, reads the session directly — outside any view body, so
/// nothing is observed and nothing is invalidated — and writes the two or three
/// numbers that changed. Nothing is described, diffed or laid out.
///
/// ## What is here so far
///
/// The column's sky, both planes' ground, and the piece, with the camera
/// following `cameraRow`. That is the slice that answers the question: it is
/// everything that was on screen for the measurements that would not move.
///
/// Not here yet: the cursor, the facing arrow, the Nexys, coins, effects, the
/// wake, the dip, wear. All of them are more nodes and more `update`, and none
/// of them changes the shape of the answer.
@MainActor
final class BoardScene: SKScene {

    /// Held strongly, not `unowned`.
    ///
    /// Nothing here is a cycle — the session does not know the scene exists —
    /// and `unowned` would trap if the scene ever outlived it during a teardown,
    /// which is exactly the moment a toggle tears one down and builds another.
    private let session: GameSession
    private let metrics: PixelArtMetrics
    private let side: CGFloat

    /// One container per plane, parked at its row in the column.
    private var planes: [Plane: SKNode] = [:]
    private var grounds: [Plane: SKNode] = [:]
    private var scenery: [Plane: SKNode] = [:]
    private var piece = SKNode()
    private var figure = SKSpriteNode()
    private var cursor = SKSpriteNode()
    /// The coins on the board, by the square they are standing on.
    ///
    /// Kept rather than rebuilt: a coin that has not moved is a node that does
    /// not need touching, and the hunt puts one down and takes it away perhaps
    /// twice a minute.
    private var coins: [GridPoint: SKSpriteNode] = [:]

    /// What each of those coins is, so it can be drawn at its own size.
    private var coinLooks: [GridPoint: PentacleAppearance] = [:]

    /// The mark each coin leaves on its tile, kept so it can be moved with the
    /// coin without hunting through the holder's children for it.
    private var coinPools: [GridPoint: SKSpriteNode] = [:]

    /// The sparkles on the board, by the square they are marking.
    private var sparkles: [GridPoint: SKSpriteNode] = [:]

    /// Which set drew them, so a changed pattern redraws rather than lingers.
    private var sparkleSet: SparkleSet?

    /// The bursts already playing, so one is started once rather than restarted
    /// every frame it is still alive.
    private var playing: Set<UUID> = []

    private var island = SKSpriteNode()
    private var pillar = SKSpriteNode()
    private var shadow = SKSpriteNode()
    private var arrow = SKSpriteNode()
    private var facing: SwipeDirection?

    /// `-1` when the drawing is the mirror of one on the sheet, `1` otherwise.
    private var mirror: CGFloat = 1
    private let follow = SKCameraNode()

    /// Where the camera was last sent, so a journey is started once.
    private var aimedAt: CGFloat = .greatestFiniteMagnitude

    /// What the piece was last drawn wearing, so the texture is only rebuilt
    /// when it actually changes rather than every frame.
    private var wearing: SpriteID?

    /// The square the piece was last sent to.
    ///
    /// A step changes `piece.point` in one go — the model does not travel, it
    /// arrives — so setting the position from it every frame would teleport.
    /// SwiftUI hides that by animating the change; a scene has to be told, and
    /// what it is told is an action to run.
    private var sentTo: GridPoint?
    private var sentOn: Plane?

    /// The board each plane was last built from.
    ///
    /// A scene is only cheap because it is not rebuilt — so it has to be told
    /// when the thing it was built from has changed. Comparing the board is
    /// forty-nine tile comparisons against rebuilding forty-nine nodes, and it
    /// is the difference between a scene that is fast and a scene that is
    /// wrong.
    private var built: [Plane: Board] = [:]

    /// And which of their tiles were standing proud when it was drawn — the
    /// board alone does not say, and a tile popping changes the strip.
    private var builtRaised: [Plane: Set<GridPoint>] = [:]

    /// And what the dials said when it was drawn.
    ///
    /// **All of them, not just the pop.** The edges are built in `rebuild`, so
    /// a dial that does not invalidate is a slider that does nothing — which is
    /// what the four edge dials were until they were checked here too.
    private var builtDials: [Plane: Dials] = [:]

    init(session: GameSession, side: CGFloat) {
        self.session = session
        self.metrics = PixelArtMetrics(availableSide: side)
        self.side = side
        super.init(size: CGSize(width: side, height: side))

        scaleMode = .aspectFit
        backgroundColor = .clear
        camera = follow
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not from a nib") }

    override func didMove(to view: SKView) {
        guard children.isEmpty else { return }
        addChild(follow)
        addSky()
        for plane in Plane.allCases { addPlane(plane) }
        addPiece()
        addCursor()
        addIsland()
    }

    // MARK: - Building, once

    /// The column's sky: one gradient the height of the world.
    ///
    /// A texture rather than nine stacked nodes — it is one image, generated
    /// once, and SpriteKit will not touch it again.
    private func addSky() {
        let height = side * CGFloat(World.rows)
        let sky = SKSpriteNode(
            texture: SKTexture(image: Self.skyImage()),
            size: CGSize(width: side, height: height)
        )
        sky.position = CGPoint(x: side / 2, y: -height / 2)
        sky.zPosition = -1000
        addChild(sky)
    }

    private func addPlane(_ plane: Plane) {
        let holder = SKNode()
        holder.position = CGPoint(x: 0, y: -CGFloat(World.row(of: plane)) * side)
        addChild(holder)
        planes[plane] = holder
        // Its own child, so rebuilding the ground cannot take it with it.
        let land = SKNode()
        holder.addChild(land)
        scenery[plane] = land

        let floor = SKNode()
        holder.addChild(floor)
        grounds[plane] = floor

        rebuild(plane)
        if plane == .terra { addScenery(to: land) }
    }

    /// Terra's land: two ridges behind the board, and the near rock in front.
    ///
    /// Built once and never touched again — it is a backdrop, and the only
    /// thing that ever moves it is the retreat when the board's edges have to
    /// be clear, which is not in this slice.
    private func addScenery(to holder: SKNode) {
        let across: CGFloat = 7
        let pixel = side / (across * CGFloat(GameRules.tilePixelSize))

        // Behind the board, then in front of it, in the order they are drawn.
        let pieces: [(TerraScenery, CGFloat, CGFloat, CGFloat, Bool)] = [
            (.backdrop, 3, GameRules.terraBackdropDrop, -50, false),
            (.midground, 3, GameRules.terraMidgroundDrop, -40, false),
            // The near rock is nearer than the front row and nothing else, so
            // it takes the row after the last one — not a number above the whole
            // board, which put it over half the front row.
            (.foreground, 2, 0, Self.depth(row: GameRules.gridSize, layer: 0), true),
        ]

        for (part, cells, drop, depth, atBottom) in pieces {
            guard let art = PaletteRecolour.image(
                .terraScenery(part), frame: 0, swaps: []
            ) else { continue }

            let texture = SKTexture(image: art)
            texture.filteringMode = .nearest

            let height = side * cells / across
            let node = SKSpriteNode(
                texture: texture,
                size: CGSize(width: side, height: height)
            )
            // Aligned to the square's top or its bottom, as the view aligns it,
            // then nudged by its own drop.
            node.position = CGPoint(
                x: side / 2,
                y: atBottom
                    ? -side + height / 2 - drop * pixel
                    : -height / 2 - drop * pixel
            )
            node.zPosition = depth
            holder.addChild(node)
        }

        // And the fill under the board. Terra's ground floats over the sky,
        // which is right for a plane made of cloud and wrong for one made of
        // earth: below the front row you could see straight through the world.
        // The tuned depth, in art pixels, exactly as the screen computes it.
        let floor = SKSpriteNode(
            color: UIColor(Palette.steel),
            size: CGSize(width: side, height: GameRules.terraFloorDepth * pixel)
        )
        floor.anchorPoint = CGPoint(x: 0.5, y: 0)
        floor.position = CGPoint(x: side / 2, y: -side)
        floor.zPosition = Self.depth(row: GameRules.gridSize, layer: -1)
        holder.addChild(floor)
    }

    /// This plane's ground, from scratch.
    ///
    /// Called when the board it was built from stops matching — a tile worn, a
    /// hole opened, a plane restored. Everything else moves; only this is ever
    /// remade, and only when the squares themselves changed.
    private func rebuild(_ plane: Plane) {
        // The ground's own node, not the plane's. `removeAllChildren` on the
        // plane took the scenery with it — so Terra's ridges vanished the first
        // time anything on the board changed and never came back.
        guard let holder = grounds[plane] else { return }
        holder.removeAllChildren()

        let board = session.engine[plane]
        let inset = (side - metrics.boardSize) / 2
        var raised = Set(session.visibleRaisedTiles.map(\.point))
        #if DEBUG
        if TileEdgeTuning.shared.raiseCentre { raised.insert(GridPoint(3, 3)) }
        #endif

        if plane == .terra {
            // **The edge under every tile**, which is what gives the board its
            // thickness. `BoardView.edgeLayer` places these by the standing
            // model and then drops them a fixed distance in screen points —
            // not the row's — so that is what happens here.
            for point in board.allPoints {
                guard board[point].kind == .normal || board[point].kind == .nexys,
                      let art = PaletteRecolour.image(
                          .tileEdge(.terra, .at(point)), frame: 0, swaps: []
                      )
                else { continue }

                let texture = SKTexture(image: art)
                texture.filteringMode = .nearest

                // **The edge belongs to the band, not to the standing frame.**
                //
                // Its tile is drawn inside the warped strip, which is laid out
                // against `band.scale` across and `band.groundScale` down. The
                // edge was being placed against `depthScale` — the scale a
                // thing *standing on* the square gets — and those two part
                // company row by row, so it could never line up with the tile
                // it belongs to however far it was nudged. Everything below is
                // in the band's frame, which is also what makes a dial found on
                // one row the right dial on all of them.
                let band = BoardBand.at(row: point.y, metrics: metrics)
                let floorY = band.groundCentreY + metrics.tileSize / 2
                let across = metrics.tileSize * band.scale
                let middle = metrics.boardSize / 2
                let plainX = middle
                    + (metrics.center(of: point).x - middle) * band.scale
                    + inset
                let originX = plainX + set.x * metrics.scale * band.scale
                let sitsAt = -floorY - inset
                    - set.y * metrics.scale * band.groundScale

                // An edge is only ever what a lift uncovered, so it takes that
                // much of the drawing — the top of it, where it meets the face
                // — and draws it at the drawing's own proportions rather than
                // stretching what it has.
                if raised.contains(point) {
                    // **The slice is what the pop uncovered; the scale stretches
                    // it.** Growing both together moved the top while the bottom
                    // stayed on the floor, which read as a nudge — and there is
                    // already a dial for nudging.
                    let slice = min(
                        max(set.pop / CGFloat(GameRules.tilePixelSize), 0), 1
                    )

                    let node = SKSpriteNode(
                        texture: SKTexture(
                            rect: CGRect(x: 0, y: 1 - slice, width: 1, height: slice),
                            in: texture
                        ),
                        size: CGSize(
                            width: across * set.xScale,
                            height: set.pop * set.yScale
                                * metrics.scale * band.groundScale
                        )
                    )
                    node.anchorPoint = CGPoint(x: 0.5, y: 0)
                    node.position = CGPoint(x: originX, y: sitsAt)
                    node.zPosition = Self.depth(row: point.y, layer: -1)
                    holder.addChild(node)
                }

                // And the board's front lip — the one edge that shows without
                // anything having been lifted. Only the last row has no band in
                // front of it to cover this.
                if point.y == board.size - 1 {
                    // **Untied from the dials.** This one has been right since
                    // the edges came back, and it is a different problem from
                    // the popped edge — nothing has been lifted here, so there
                    // is no uncovered strip to match. Tuning the two together
                    // would only break the one that works.
                    let node = SKSpriteNode(
                        texture: texture,
                        size: CGSize(
                            width: across,
                            height: metrics.tileSize * band.groundScale
                        )
                    )
                    node.anchorPoint = CGPoint(x: 0.5, y: 1)
                    node.position = CGPoint(x: plainX, y: -floorY - inset)
                    node.zPosition = Self.depth(row: point.y, layer: -1)
                    holder.addChild(node)
                }
            }

            for row in 0..<board.size {
                guard let node = terraRow(
                    row, board: board, raised: raised, pop: set.pop
                ) else { continue }
                node.position.x += inset
                node.position.y -= inset
                holder.addChild(node)
            }
        } else {
            for point in board.allPoints {
                guard let node = ground(at: point, on: plane, board: board) else { continue }
                node.position.x += inset
                node.position.y -= inset
                holder.addChild(node)
            }
        }
        built[plane] = board
        builtRaised[plane] = raised
        builtDials[plane] = set
    }

    /// One row of Terra: seven tiles in a single sprite, warped into its band.
    ///
    /// **A row, not seven squares.** Terra's ground is a keystone — each band's
    /// top edge narrower than its bottom — and squares placed individually
    /// inside one open seams, which is the whole reason the SwiftUI board draws
    /// rows rather than tiles.
    ///
    /// The warp is **sampled from the board's own map**, not fitted to it. A
    /// trapezoid with the top corners pulled in by `1 / (1 + lean)` has the
    /// right corners and the wrong middle, because a warp cell interpolates
    /// linearly and a keystone is projective.
    private func terraRow(
        _ row: Int, board: Board, raised: Set<GridPoint>, pop: CGFloat
    ) -> SKSpriteNode? {
        guard let strip = Self.rowImage(
            row, board: board, raised: raised, pop: pop, metrics: metrics
        ) else {
            return nil
        }

        let texture = SKTexture(image: strip)
        texture.filteringMode = .nearest

        // **The board's own curve, sampled — not a straight line between the
        // band's two edges.**
        //
        // A one-cell warp interpolates its texture linearly, and a keystone is
        // projective: the two agree exactly at the corners and diverge most in
        // the middle, by an amount that changes with the row's lean. That is
        // why the edge under a tile could not be made to line up by any
        // constant — the tiles themselves were not quite where the arithmetic
        // said they were, and by a different amount on every row and column.
        //
        // So the strip is cut into slices of its own and every seam is placed
        // by `BoardBand.edgeY(at:)`, the same map the ground is drawn with,
        // read at fractional edges. Nothing here approximates anything.
        let cell = CGFloat(GameRules.tilePixelSize)
        let tall = Self.stripAbove(pop) + cell + Self.stripBelow

        // The strip's floor is this row's front edge; climbing it walks back
        // through the board, a tile of art to a row of board.
        let front = CGFloat(row + 1)
        let edge: (CGFloat) -> CGFloat = { up in front - up / cell }

        // **Pinned to the rounded boundaries.** `edgeY(_:)` rounds so that two
        // neighbouring bands share an integer edge and leave no hairline of sky
        // between them. Sampling the *unrounded* curve inside the strip ignored
        // that: a row's top landed up to half a point off the bottom of the row
        // behind it, on every row, by a different amount each time — which is a
        // seam that varies by row and looks like a tuning problem.
        //
        // So the curve is stretched to meet the rounded values at the two whole
        // edges it spans. Its shape between them is untouched.
        let floorY = BoardBand.edgeY(row + 1, metrics: metrics)
        let backY = BoardBand.edgeY(row, metrics: metrics)
        let looseFront = BoardBand.edgeY(at: front, metrics: metrics)
        let looseBack = BoardBand.edgeY(at: front - 1, metrics: metrics)
        let loose = looseBack - looseFront

        let trued: (CGFloat) -> CGFloat = { y in
            guard loose != 0 else { return y }
            return floorY + (y - looseFront) * (backY - floorY) / loose
        }

        let ceilY = trued(BoardBand.edgeY(at: edge(tall), metrics: metrics))
        let deep = floorY - ceilY

        let node = SKSpriteNode(
            texture: texture,
            size: CGSize(width: metrics.boardSize, height: deep)
        )
        node.anchorPoint = CGPoint(x: 0.5, y: 0)

        // Sixteen slices: enough that what is left of the linear error inside
        // any one of them is far under a pixel, and cheap — a strip is built
        // when the board changes, not per frame.
        // **A column per tile.** A warp cell interpolates its texture across
        // its own quad, and a quad whose top is narrower than its bottom cannot
        // do that the way perspective does — the error is nothing at the cell's
        // corners and most in its middle, which is how it came out as seams
        // that moved with the column. One cell per tile puts a corner on every
        // tile boundary, so the places a seam could show are the places the map
        // is exact.
        let slices = 16
        let columns = board.size
        var source: [SIMD2<Float>] = []
        var destination: [SIMD2<Float>] = []

        for step in 0...slices {
            let v = CGFloat(step) / CGFloat(slices)
            let here = edge(v * tall)
            let wide = GameRules.boardForeshortenScale
                / BoardBand.edgeDivisor(at: here, gridSize: metrics.gridSize)
            let up = deep > 0
                ? (floorY - trued(BoardBand.edgeY(at: here, metrics: metrics))) / deep
                : v

            for column in 0...columns {
                let u = CGFloat(column) / CGFloat(columns)
                source.append(.init(Float(u), Float(v)))
                destination.append(.init(Float(0.5 + (u - 0.5) * wide), Float(up)))
            }
        }

        node.warpGeometry = SKWarpGeometryGrid(
            __columns: columns, rows: slices,
            sourcePositions: source,
            destPositions: destination
        )

        // No scaling of its own: the warp already carries both the row's width
        // and its depth, taken from the board's map rather than from a pair of
        // scale factors that only agree with it at the edges.
        node.position = CGPoint(x: metrics.boardSize / 2, y: -floorY)
        node.zPosition = Self.depth(row: row, layer: 0)
        return node
    }

    /// A row's seven tiles, composited into one strip.
    /// How far above the tile row the strip reaches, in art pixels — the room
    /// a popped tile needs to rise into. Follows the dial, so tuning the pop
    /// does not clip the tile it is raising.
    private static func stripAbove(_ pop: CGFloat) -> CGFloat { max(pop, 0) }

    /// And how far below — nothing, now that no edge is drawn in here.
    ///
    /// **An edge stands, it does not lie.** It is the side of the board's
    /// thickness, facing the camera, so it is placed like the piece rather than
    /// sheared into the ground the way the faces are. Drawing it inside the
    /// row's keystone put a skewed copy exactly where the standing one already
    /// was, which is what has been wrong with the edges since the revamp.
    /// See `BoardLayer.lies` and `OnBoard.isStanding`.
    private static let stripBelow: CGFloat = 0

    private static func rowImage(
        _ row: Int,
        board: Board,
        raised: Set<GridPoint>,
        pop: CGFloat,
        metrics: PixelArtMetrics
    ) -> UIImage? {
        // **Baked at the art's own resolution.** Drawing 16-pixel tiles into a
        // strip measured in *points* resamples every one of them on the way in,
        // and no amount of nearest-neighbour filtering afterwards can put back
        // detail that was averaged away — which is what made the cracks blurry
        // while the flat faces looked passable. The strip is now exactly as
        // many pixels as the art is, and SpriteKit does the enlarging.
        let cell = CGFloat(GameRules.tilePixelSize)
        let size = CGSize(
            width: CGFloat(board.size) * cell,
            height: stripAbove(pop) + cell + stripBelow
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1

        var drewAnything = false
        let strip = UIGraphicsImageRenderer(size: size, format: format).image { context in
            context.cgContext.interpolationQuality = .none
            for column in 0..<board.size {
                let point = GridPoint(column, row)
                let tile = board[point]
                let shade = Palette.TileShade.at(point)
                // The tile's own place in the strip, and how far it has risen
                // out of it. `BandRow` stacks the edge and the face bottom-
                // aligned and then offsets each, which is what these two are.
                let isRaised = raised.contains(point)
                let box = CGRect(
                    x: CGFloat(column) * cell,
                    y: stripAbove(pop) - (isRaised ? pop : 0),
                    width: cell, height: cell
                )

                if let art = PaletteRecolour.image(
                    .tileFace(.terra, shade, popped: isRaised), frame: 0, swaps: []
                ) {
                    drewAnything = true
                    art.draw(in: box)
                }

                // The cast a badly cracked tile takes, over its face and under
                // its damage — `TileView` overlays the face with it.
                if tile.health == .badlyCracked {
                    context.cgContext.saveGState()
                    context.cgContext.setBlendMode(.plusDarker)
                    UIColor(Palette.khaki)
                        .withAlphaComponent(GameRules.badlyCrackedTint)
                        .setFill()
                    context.fill(box)
                    context.cgContext.restoreGState()
                }

                // **And whatever has happened to it.** The bake drew every tile
                // in mint condition and skipped the holes entirely, so a board
                // could be worn to pieces and still read as new.
                let wear: TileHealth? = switch tile.kind {
                case .chasm, .nexys: .hole
                case .normal: tile.health == .healthy ? nil : tile.health
                case .pool: nil
                }

                if let wear, let art = PaletteRecolour.image(
                    .tileDamage(.terra, wear), frame: 0, swaps: []
                ) {
                    drewAnything = true
                    art.draw(in: box)
                }
            }
        }
        return drewAnything ? strip : nil
    }

    /// One square of ground: a cloud on Astra, a tile face on Terra.
    private func ground(at point: GridPoint, on plane: Plane, board: Board) -> SKSpriteNode? {
        let tile = board[point]
        guard tile.kind == .normal, !tile.health.isHole else { return nil }

        let shade = Palette.TileShade.at(point)
        let id: SpriteID = plane == .astra
            ? .astraCloud(shade)
            : .tileFace(plane, shade, popped: false)
        let swaps = plane == .astra
            ? GameRules.cloudWearSwaps(tile.health, shade: shade)
            : []

        guard let art = PaletteRecolour.image(id, frame: 0, swaps: swaps) else { return nil }
        let texture = SKTexture(image: art)
        texture.filteringMode = .nearest

        let spot = metrics.projected(point, on: plane)

        let span = plane == .astra
            ? metrics.tileSize
                * CGFloat(GameRules.cloudSpritePixelSize) / CGFloat(GameRules.tilePixelSize)
                * GameRules.cloudSpriteScale * GameRules.cloudBaseSize
            : metrics.tileSize

        let node = SKSpriteNode(
            texture: texture,
            size: CGSize(width: span * spot.scale, height: span * spot.scale)
        )
        // **Clouds ride above the point they are projected at.** `CloudSpriteField`
        // lifts each one by `astraCloudLift` and drops it back by
        // `cloudSpriteDrop`; neither was here, so the whole sky sat low.
        node.position = CGPoint(
            x: spot.position.x,
            y: -spot.position.y + (plane == .astra
                ? (GameRules.astraCloudLift - GameRules.cloudSpriteDrop) * metrics.scale
                : 0)
        )

        // **The same depth scheme as everything else.** A bare row index put
        // every cloud below every object, so nothing on Astra could ever be
        // hidden behind a cloud in front of it.
        node.zPosition = Self.depth(row: point.y, layer: 0)

        if plane == .astra { node.run(Self.drift(seed: point.x * 7 + point.y * 13,
                                                 scale: metrics.scale)) }
        return node
    }

    /// The piece is two nodes: where it stands, and what it is doing.
    ///
    /// `piece` is the square it is on — moved by an action when it steps.
    /// `figure` is the drawing inside it, which hops, squashes and bobs against
    /// that. Kept apart so a hop cannot fight a step: one writes the parent,
    /// the other the child, and neither has to know about the other.
    private func addPiece() {
        piece.zPosition = 500
        figure.size = CGSize(width: metrics.tileSize, height: metrics.tileSize * 2)
        addChild(piece)

        // The mark on the square, under the figure and outside it: the figure
        // hops and the shadow stays on the ground, which is what anchors a
        // two-cell sprite to a one-cell square.
        //
        // Drawn on the sheet at the piece's own scale, so its cell lines up
        // with the piece's lower cell and the art does the seating.
        shadow.texture = Self.shadowTexture
        shadow.size = CGSize(width: metrics.tileSize, height: metrics.tileSize)
        shadow.anchorPoint = CGPoint(
            x: 0.5,
            y: GameRules.shadowSpriteSeat / CGFloat(GameRules.tilePixelSize)
        )
        shadow.alpha = GameRules.shadowSpriteOpacity
        shadow.zPosition = -1
        piece.addChild(shadow)

        // **Not a child of the piece.** It is a mark on the *square*, and
        // hanging it off a node that sits at the feet meant it inherited both
        // the feet's offset and the piece's depth — which is why it drew under
        // the tiles. Placed like anything else, on the layer effects use, so
        // the row in front cannot clip it.
        addChild(arrow)

        figure.anchorPoint = CGPoint(x: 0.5, y: 0)
        piece.addChild(figure)
    }

    /// Four corner brackets, baked once.
    ///
    /// Drawn into a texture rather than built from `SKShapeNode`s: a shape node
    /// is re-triangulated whenever it changes and there is no reason to pay that
    /// for a mark whose shape never changes. Only its colour and place do, and
    /// both are free on a sprite.
    private func addCursor() {
        cursor.texture = SKTexture(image: Self.bracketImage(
            side: metrics.tileSize,
            thickness: max(metrics.scale, 1),
            reach: metrics.tileSize * 0.28
        ))
        cursor.texture?.filteringMode = .nearest
        cursor.size = CGSize(width: metrics.tileSize, height: metrics.tileSize)
        cursor.zPosition = 400
        cursor.colorBlendFactor = 1
        addChild(cursor)
    }

    /// The island and the near corner that stands in front of whoever is on it.
    ///
    /// Two nodes because they are two drawings and the piece stands between
    /// them — the same reason the SwiftUI board splits them. Their z is set in
    /// `update`, since which of them is in front of the piece depends on where
    /// the piece is standing.
    private func addIsland() {
        for (node, id) in [
            (island, NexysStyle.foreshortened ? SpriteID.nexysDeep : SpriteID.nexys),
            (pillar, SpriteID.nexysPillar),
        ] {
            guard let art = PaletteRecolour.image(id, frame: 0, swaps: []) else { continue }
            let texture = SKTexture(image: art)
            texture.filteringMode = .nearest
            node.texture = texture
            addChild(node)
        }
        pillar.isHidden = !NexysStyle.foreshortened
    }

    // MARK: - Placement

    /// **The one place anything on the board is sized and put.**
    ///
    /// Everything standing on a square obeys the same two rules, and they are
    /// the board's rules rather than each sprite's:
    ///
    /// - **Size is measured in tiles.** A figure is one tile by two; a coin is
    ///   `pentacleCellSpan`; the island is three by three. That is how every
    ///   view in the SwiftUI board frames itself, because `tileSize` already
    ///   carries the whole-pixel art scale — so a size in tiles is the same
    ///   drawing at any board size.
    /// - **The row supplies the rest.** `projected` answers where a square is
    ///   and how much the perspective shrinks it, and everything standing there
    ///   takes both. Nothing is scaled by its own art's dimensions, which is
    ///   what made the coin and the arrow come out wrong while the piece looked
    ///   right: three sprites, three accidental formulas.
    ///
    /// `lift` is in art pixels, the unit every tuned offset in `GameRules` is
    /// written in.
    /// The depth a thing standing on `row` draws at.
    ///
    /// The board's own painter's order: a row owns a band ten wide, the ground
    /// sits at the bottom of it and everything standing on that ground sits
    /// above — so a piece on row three is in front of row three's tiles and
    /// behind row four's. The same scale `BoardObject.z` uses, for the same
    /// reason.
    private static func depth(row: Int, layer: Int) -> CGFloat {
        CGFloat(row * 10 + layer)
    }

    /// Above every row, for the things that are not standing on one.
    ///
    /// Smoke and effect strips are not objects on a square — they are what just
    /// happened there — and sorted into a row's band they clip behind the row in
    /// front, on every row but the nearest.
    private static let effects: CGFloat = 10_000

    /// How high the surface of a square sits, in art pixels above the tile.
    ///
    /// `BoardView.surfaceOffset(of:bob:metrics:)` is the same rule, in the
    /// opposite sign. The island hovers over its square and a popped tile
    /// stands proud of its own, and in both cases everything on that square —
    /// the piece, the cursor, a coin — has to come up with it or sink through.
    /// The lift a piece takes from *riding* the island, which is not the lift
    /// the island itself takes.
    ///
    /// `BoardView` passes this as `carryOffset`. The island's surface is not
    /// its middle, so a piece standing on it comes up by `nexysRideLift`
    /// rather than by `nexysRaise` — and the drawn-in-perspective sprite has
    /// its surface a pixel higher again, which belongs to that drawing rather
    /// than to the placement.
    private func carryLift() -> CGFloat {
        guard session.engine.isOnNexys else { return 0 }
        let phase = session.ambientClock(
            at: Date().timeIntervalSinceReferenceDate
        ) / GameRules.nexysFloatPeriod
        let bob = CGFloat(sin(phase * 2 * .pi)) * GameRules.nexysFloatAmplitude

        return bob * GameRules.carryFollow
            + GameRules.nexysRideLift
            - (NexysStyle.foreshortened ? NexysStyle.islandY : 0)
            + NexysStyle.rideLift
    }

    /// The pop and edge numbers: the bench's while tuning, the rules' when not.
    ///
    /// All in art pixels at row scale — applied inside the band's own frame, so
    /// a value found on one row is the same value on every other.
    struct Dials: Equatable {
        var pop: CGFloat
        var x: CGFloat
        var y: CGFloat
        var xScale: CGFloat
        var yScale: CGFloat
    }

    private var set: Dials {
        #if DEBUG
        let bench = TileEdgeTuning.shared
        return Dials(pop: bench.popY, x: bench.edgeX, y: bench.edgeY,
                     xScale: bench.edgeXscale, yScale: bench.edgeYscale)
        #else
        return Dials(pop: GameRules.tilePopLift, x: 0, y: 0, xScale: 1, yScale: 1)
        #endif
    }

    private func surfaceLift(of point: GridPoint, on plane: Plane) -> CGFloat {
        if session.engine.nexysPlane == plane, point == GameRules.nexysPoint {
            let phase = session.ambientClock(
                at: Date().timeIntervalSinceReferenceDate
            ) / GameRules.nexysFloatPeriod
            return CGFloat(sin(phase * 2 * .pi)) * GameRules.nexysFloatAmplitude
                + GameRules.nexysRaise
                - (NexysStyle.foreshortened ? NexysStyle.islandY : 0)
        }
        if session.visibleRaisedTiles.contains(where: { $0.point == point }) {
            switch plane {
            case .terra: return GameRules.tilePopLift
            case .astra: return GameRules.cloudSpriteRaiseLift + GameRules.astraCloudLift
            }
        }
        return 0
    }

    /// A mark drawn *on* the ground, as against something standing on it.
    ///
    /// `BoardView.asBoardSquare` is this rule. A mark lies in the plane of its
    /// row, so it is scaled about the band's **bottom edge** and takes the
    /// band's own `scale` across — which is not the `depthScale` a standing
    /// object gets — and, unless it opts out, the ground's squash down it.
    ///
    /// Placing the arrow as though it stood on the square is what made north
    /// and south want a different correction from east and west: the reach is
    /// vertical on two of them and zero on the other two, so the wrong vertical
    /// scale could only show up on half the compass.
    ///
    /// `offset` travels with the mark and is scaled by it. `outer` is applied
    /// afterwards against the row, which is where the cursor's lifts go.
    /// Both are in SwiftUI's sign, so down is positive.
    private func placeMark(
        _ node: SKSpriteNode,
        at point: GridPoint,
        on plane: Plane,
        tiles: CGSize,
        offset: CGSize = .zero,
        outer: CGFloat = 0,
        squashed: Bool = true,
        layer: Int = 5
    ) {
        // Only Terra draws in bands. Astra's marks are shaped by
        // `shapedAsGround`, and until that is ported they keep the old model.
        guard plane == .terra else {
            place(node, at: point, on: plane, tiles: tiles,
                  lift: -(offset.height + outer) / metrics.scale, layer: layer)
            return
        }

        node.zPosition = Self.depth(row: point.y, layer: layer)

        let band = BoardBand.at(row: point.y, metrics: metrics)
        let inset = (side - metrics.boardSize) / 2
        let middle = metrics.boardSize / 2
        let flat = metrics.center(of: point)
        let down = squashed ? band.groundScale : band.scale

        node.size = CGSize(
            width: tiles.width * metrics.tileSize,
            height: tiles.height * metrics.tileSize
        )
        node.xScale = band.scale
        node.yScale = down

        // Scaled about the bottom edge, so a full tile's frame keeps its floor
        // on the band's floor and only its top comes down. That leaves the art
        // centred half a tile up, less however much the squash took.
        let centreY = band.groundCentreY + metrics.tileSize / 2 * (1 - down)
        let drawnIn = 1 + band.lean / 2
        let row = metrics.projected(point, on: plane).scale

        node.position = CGPoint(
            x: middle + (flat.x - middle) * band.scale / drawnIn
                + inset + offset.width * band.scale,
            y: -CGFloat(World.row(of: plane)) * side - centreY - inset
                - offset.height * down - outer * row
        )
    }

    private func place(
        _ node: SKSpriteNode,
        at point: GridPoint,
        on plane: Plane,
        tiles: CGSize,
        lift: CGFloat = 0,
        shiftX: CGFloat = 0,
        onSurface: Bool = true,
        layer: Int = 5
    ) {
        node.zPosition = Self.depth(row: point.y, layer: layer)

        // Whatever this square's surface is doing, this rides it.
        let lift = lift + (onSurface ? surfaceLift(of: point, on: plane) : 0)

        let spot = metrics.projected(point, on: plane)
        let inset = (side - metrics.boardSize) / 2

        node.size = CGSize(
            width: tiles.width * metrics.tileSize,
            height: tiles.height * metrics.tileSize
        )
        node.setScale(spot.scale)
        // **The lift is scaled by the row.** Anything measured from a tile's
        // centre lives in that tile's space, and a tile at the back of the
        // board is smaller — SwiftUI gets this for free because it scales the
        // whole view *including* its offsets, about the point it then places.
        // Applied unscaled, every offset was a back-row error.
        node.position = CGPoint(
            x: spot.position.x + inset + shiftX * metrics.scale * spot.scale,
            y: -CGFloat(World.row(of: plane)) * side
                - Self.seatY(point, on: plane, metrics: metrics, spot: spot)
                - inset + lift * metrics.scale * spot.scale
        )
    }

    /// The height a thing standing on `point` is placed at, in board space.
    ///
    /// **Not the projected y**, on Terra. The view places anything standing on
    /// a band at the band's *drawn* centre plus a share of how much taller that
    /// band is than the scaled tile — `standOnBandShare` — because a square
    /// drawn in perspective is not the same height as the tile it stands for,
    /// and a thing standing on it splits the difference. Placed at the
    /// projected centre instead, everything sat about six pixels low.
    ///
    /// Astra has no bands, so its objects are placed where they are projected.
    private static func seatY(
        _ point: GridPoint,
        on plane: Plane,
        metrics: PixelArtMetrics,
        spot: (position: CGPoint, scale: CGFloat)
    ) -> CGFloat {
        guard plane == .terra else { return spot.position.y }

        let band = BoardBand.at(row: point.y, metrics: metrics)
        let mismatch = (band.heightY - metrics.tileSize * spot.scale)
            / 2 * GameRules.standOnBandShare
        return band.drawnCentreY + mismatch
    }

    // MARK: - The loop

    /// Called by SpriteKit, on its own clock.
    ///
    /// **This is the whole update.** It reads the session outside any view body,
    /// so nothing is observed and nothing is invalidated, and it writes two
    /// positions. Whatever else changed this frame, this is what it costs.
    override func update(_ currentTime: TimeInterval) {
        // **Travelled, not read.**
        //
        // `cameraRow` is animated, which in SwiftUI means the *model* reaches
        // its destination immediately and only the view takes the long way
        // there. A view interpolates it; a scene reading the number gets the
        // end of the journey on the first frame of it, which is why a plane
        // change warped instead of falling.
        // The bench can walk the camera sideways, which is the only way to
        // look at the board's corners — they sit outside the viewport.
        #if DEBUG
        let pan = TileEdgeTuning.shared.boardX * metrics.scale
        #else
        let pan: CGFloat = 0
        #endif
        let want = CGPoint(
            x: side / 2 - pan,
            y: -session.cameraRow * side - side / 2
        )
        if abs(want.y - aimedAt) > 0.5 {
            aimedAt = want.y
            follow.removeAction(forKey: "travel")

            let span = session.isChangingPlane || session.isDropping
                ? GameRules.fallDuration
                : 0
            if span > 0 {
                let go = SKAction.move(to: want, duration: span)
                go.timingMode = SKActionTimingMode.linear
                follow.run(go, withKey: "travel")
            } else {
                follow.position = want
            }
        } else if follow.action(forKey: "travel") == nil {
            follow.position = want
        }

        // **Shown, not built.** A scene is made once, so a build-time gate on a
        // bench toggle can never take effect — the switch did nothing at all.
        for land in scenery.values { land.isHidden = !LayerBench.shared.scenery }

        // Only when the squares themselves changed — see `built`.
        var risen = Set(session.visibleRaisedTiles.map(\.point))
        #if DEBUG
        if TileEdgeTuning.shared.raiseCentre { risen.insert(GridPoint(3, 3)) }
        #endif
        for plane in Plane.allCases
        where built[plane] != session.engine[plane] || builtRaised[plane] != risen
            || builtDials[plane] != set {
            rebuild(plane)
        }

        let standing = session.engine.piece
        let looking = session.visibleFacing
        let id = SpriteID.pieceFacing(standing.zodiac, looking)
        if id != wearing, let art = PaletteRecolour.image(id, frame: 0, swaps: []) {
            let texture = SKTexture(image: art)
            texture.filteringMode = .nearest
            figure.texture = texture
            // East is west, mirrored: there is no east drawing on the sheet.
            // See `PieceView.isMirrored`.
            mirror = looking == .right && standing.zodiac != .gemini ? -1 : 1
            wearing = id
        }

        let inset = (side - metrics.boardSize) / 2
        let spot = metrics.projected(standing.point, on: standing.plane)
        // **Where the feet go.**
        //
        // The view centres a frame two tiles tall on the tile's centre, offsets
        // it up by half a tile plus `pieceLift`, and scales the whole thing —
        // offsets included — about that centre. So the feet end up this far
        // below the tile's centre, *in the row's own scale*:
        //
        //     (tileSize / 2 - pieceLift × scale) × row scale
        //
        // Placed at the tile's bottom edge unscaled instead, the piece sat low
        // everywhere and lower still at the back, where the row is smaller.
        // How far the feet sit below the tile's centre, before the row scales it.
        // The children below live inside a node the row has *already* scaled, so
        // they want this unscaled — scaling it twice is what put the shadow and
        // the arrow under the board.
        let drop = metrics.tileSize / 2 - GameRules.pieceLift * metrics.scale
        let stand = drop * spot.scale

        // **A falling piece rides the camera down.** `BoardView` gets this by
        // moving the board under a piece that stays put — `fallOffset` — but
        // the scene lays every plane out in world space and moves a real
        // camera instead, so the piece has to be told to come along or it
        // simply waits on the plane it is bound for while the camera travels.
        //
        // Only while it is actually falling: sweeping the camera to look at
        // another plane must leave the piece where it is standing.
        let travelling = session.isChangingPlane || session.isDropping
            || session.isFalling
        let ride = travelling
            ? follow.position.y
                + CGFloat(World.row(of: standing.plane)) * side + side / 2
            : 0
        let seat = CGPoint(
            x: spot.position.x + inset,
            y: -CGFloat(World.row(of: standing.plane)) * side
                - Self.seatY(standing.point, on: standing.plane,
                             metrics: metrics, spot: spot)
                - inset - stand
                + (session.engine.isOnNexys
                    ? carryLift()
                    : surfaceLift(of: standing.point, on: standing.plane))
                * metrics.scale * spot.scale
                + ride
        )

        // **Sent, not set.** Only when the square actually changed, and as an
        // action the render thread carries out — which is the whole point:
        // travelling costs one instruction, not a position written every frame.
        if standing.point != sentTo || standing.plane != sentOn {
            sentTo = standing.point
            sentOn = standing.plane

            piece.removeAction(forKey: "step")
            piece.removeAction(forKey: "settle")
            let span = session.movement?.duration ?? GameRules.hopDuration
            if span > 0, piece.parent != nil, sentTo != nil {
                let go = SKAction.move(to: seat, duration: span)
                go.timingMode = SKActionTimingMode.easeInEaseOut
                piece.run(go, withKey: "step")
                // **Keyed too.** Unkeyed, this survived the `removeAction` that
                // cancels an interrupted step — so moving quickly and stopping
                // left a half-finished scale running, and the piece kept
                // whatever size the row it was passing through had given it.
                piece.run(.scale(to: spot.scale, duration: span), withKey: "settle")
            } else {
                piece.position = seat
                piece.setScale(spot.scale)
            }
        } else if piece.action(forKey: "step") == nil,
                  piece.action(forKey: "settle") == nil {
            // Standing still, or carried by the camera: keep it seated. This is
            // also the backstop for a scale that was interrupted — whatever
            // happened on the way, the square it is on decides its size.
            piece.position = seat
            piece.setScale(spot.scale)
        }
        piece.zPosition = Self.depth(row: standing.point.y, layer: 5)

        // **The hop, the squash and the bob, from the same clock the board
        // uses.** `HopPose` is already a pure function of elapsed time — it was
        // written that way so an animation could not leave it stuck part-way —
        // which means a scene can read it exactly as a view did.
        let hop = session.hopPose(at: Date())
        figure.position.y = hop.lift * metrics.scale
        // **Multiplied, not assigned.** The squash and the mirror both want
        // `xScale`, and written separately each wiped the other out — the hop
        // straightened an east-facing piece, and the mirror froze the squash.
        figure.xScale = hop.scaleX * mirror
        figure.yScale = hop.scaleY

        // The shadow stays down and narrows as the figure leaves it.
        shadow.isHidden = session.isChangingPlane || session.isFalling
        // Anchored on the mark itself, which sits a known height up its cell.
        // This node is at the feet, and the cell's bottom edge is the feet, so
        // that height is the whole offset — no tuning of mine in it.
        shadow.position.y = GameRules.shadowSpriteSeat * metrics.scale
        shadow.setScale(max(1 - hop.lift / GameRules.hopArcHeight * 0.4, 0.35))

        // And the arrow that says which way it is looking.
        if looking != facing,
           let art = PaletteRecolour.image(.directionArrow(looking), frame: 0, swaps: []) {
            let texture = SKTexture(image: art)
            texture.filteringMode = .nearest
            arrow.texture = texture
            // And it sits out from the piece toward the square it points at.

            facing = looking
        }
        // A ground mark on the piece's own square, reaching out toward the one
        // it points at. `facingArrowReach` is a share of a tile, so it is in the
        // row's scale like every other offset.
        let span = GameRules.facingArrowScale

        // **It rides above the square, and by how much depends on the row.**
        // `FacingArrowView` lifts by `facingArrowLift`, boosts that lift back
        // up as the rows shrink, and takes a depth term off the far ones. None
        // of it was here, which is why it lay flat on the tile.
        let last = CGFloat(max(GameRules.gridSize - 1, 1))
        let back = 1 - CGFloat(standing.point.y) / last
        let near = metrics.projected(
            GridPoint(standing.point.x, GameRules.gridSize - 1), on: standing.plane
        ).scale
        let boost = spot.scale > 0
            ? pow(near / spot.scale, GameRules.facingArrowRowPower)
            : 1
        let reachLift = (GameRules.facingArrowLift
            + (standing.plane == .astra ? GameRules.facingArrowAstraLift : 0))
            * boost + GameRules.facingArrowDepthLift * back

        // Its reach travels with the mark, so it takes the mark's own scale —
        // and the mark declines the squash, because the art is drawn as
        // something already lying on a tilted plane.
        let out = metrics.tileSize * GameRules.facingArrowReach
        placeMark(
            arrow, at: standing.point, on: standing.plane,
            tiles: CGSize(width: span, height: span),
            offset: CGSize(
                width: CGFloat(looking.unitOffset.dx) * out,
                height: CGFloat(looking.unitOffset.dy) * out
                    - reachLift * metrics.scale
            ),
            squashed: false
        )
        // **Facing north the arrow is behind the piece**, because the square it
        // reaches for is further up the board — so it goes under rather than
        // over. Every other direction reaches level or forward and stays on
        // the FX layer.
        arrow.zPosition = looking == .up
            ? Self.depth(row: standing.point.y, layer: 4)
            : Self.effects
        arrow.isHidden = shadow.isHidden

        // The cursor, on the square the next move would land on.
        let aim = session.engine.cursor(
            direction: session.previewDirection,
            reach: session.previewReach
        )
        let onIsland = session.engine.nexysPlane == standing.plane
            && aim.point == GameRules.nexysPoint
        placeMark(
            cursor, at: aim.point, on: standing.plane,
            tiles: CGSize(width: 1, height: 1),
            outer: -GameRules.cursorLift * metrics.scale
                - (onIsland ? NexysStyle.cursorLift * metrics.scale : 0)
                - surfaceLift(of: aim.point, on: standing.plane) * metrics.scale,
            layer: 2
        )
        cursor.color = UIColor(Self.tint(for: aim.status))

        // The island, on whichever plane it is currently part of. Three tiles
        // by three, as `NexysView` frames it; the pillar is one.
        let home = session.engine.nexysPlane

        // **It does not sit on the square, it hovers over it.** `NexysView`
        // raises the island by `nexysRaise` and then again by the deep sprite's
        // own `islandY`, and neither of those was here — which is the whole of
        // why it read as sitting a good sixteen pixels too low.
        // The island *is* the surface, so it takes the same lift it gives to
        // everything standing on it, bob and all.
        let deep = NexysStyle.foreshortened

        // The piece stands between the two halves of the same rock.
        place(island, at: GameRules.nexysPoint, on: home,
              tiles: CGSize(width: 3, height: 3),
              shiftX: deep ? NexysStyle.islandX : 0, layer: 3)
        place(pillar, at: GameRules.nexysPoint, on: home,
              tiles: CGSize(width: 1, height: 1),
              lift: -NexysStyle.pillarY,
              shiftX: deep ? NexysStyle.islandX + NexysStyle.pillarX : 0, layer: 7)

        syncCoins(on: standing.plane, inset: inset)
        syncSparkles()
        syncEffects(inset: inset)
        syncSmoke()
    }

    /// The dust a landing kicks up.
    ///
    /// Two tiles across times its magnitude, as `SmokeSpriteView` frames it,
    /// and played once as a strip like every other effect.
    private func syncSmoke() {
        for puff in session.smoke where !playing.contains(puff.id) {
            playing.insert(puff.id)

            let count = SpriteSheetLoader.frameCount(for: .smoke(puff.plane))
            guard count > 0 else { continue }

            var frames: [SKTexture] = []
            for index in 0..<count {
                guard let art = PaletteRecolour.image(
                    .smoke(puff.plane), frame: index, swaps: []
                ) else { continue }
                let texture = SKTexture(image: art)
                texture.filteringMode = .nearest
                frames.append(texture)
            }
            guard let first = frames.first else { continue }

            let node = SKSpriteNode(texture: first)
            let wide = 2 * puff.magnitude
            place(node, at: puff.point, on: puff.plane,
                  tiles: CGSize(width: wide, height: wide))
            node.zPosition = Self.effects
            addChild(node)

            let each = SpriteSheetLoader.frameDuration(for: .smoke(puff.plane))
            node.run(.sequence([
                .animate(with: frames, timePerFrame: each, resize: false, restore: false),
                .removeFromParent(),
            ]))
        }

        playing.formIntersection(
            Set(session.effectBursts.map(\.id)).union(session.smoke.map(\.id))
        )
    }

    /// The effect sprites, each played once and left to remove itself.
    ///
    /// **Started, not driven.** A strip is an `SKAction.animate(with:)` handed
    /// to a node — the render thread walks the frames and the node deletes
    /// itself at the end. Nothing here is asked about it again, which is the
    /// difference from a view that recomputes which frame it is on every time
    /// it is drawn.
    private func syncEffects(inset: CGFloat) {
        for burst in session.effectBursts where !playing.contains(burst.id) {
            playing.insert(burst.id)

            let count = SpriteSheetLoader.frameCount(for: .effect(burst.effect))
            guard count > 0 else { continue }

            var frames: [SKTexture] = []
            for index in 0..<count {
                guard let art = PaletteRecolour.image(
                    .effect(burst.effect), frame: index, swaps: []
                ) else { continue }
                let texture = SKTexture(image: art)
                texture.filteringMode = .nearest
                frames.append(texture)
            }
            guard let first = frames.first else { continue }
            if burst.reversed { frames.reverse() }

            // **The tile's size times the effect's span**, which is how the
            // view has always sized these. Taking the texture's own dimensions
            // and multiplying by the pixel scale drew them at the size of the
            // *art* — three or four tiles across — so a puff of dust covered a
            // quarter of the board.
            let node = SKSpriteNode(texture: first)
            let wide = burst.effect.span * burst.scale
            let high = wide
                * burst.effect.frameSize.height / burst.effect.frameSize.width
                * burst.effect.spanScaleY

            // **Where the effect thinks the floor is.** `EffectSpriteView`
            // raises each one by its own `groundLift`, and a `.standing` one by
            // half its height again so it sits on the square rather than
            // through it. Neither was here, which is what dropped the snipe
            // bonus down out of its overhead spot.
            let stand = burst.effect.anchor == .standing
                ? high * CGFloat(GameRules.tilePixelSize) / 2
                : 0

            place(
                node, at: burst.center, on: burst.plane,
                tiles: CGSize(width: wide, height: high),
                lift: burst.effect.groundLift + stand
            )
            node.zPosition = Self.effects
            node.zRotation = CGFloat(burst.angle) * .pi / 180
            node.xScale = burst.mirrored ? -1 : 1
            if let tint = burst.tint {
                node.color = UIColor(tint)
                node.colorBlendFactor = 1
            }
            if burst.glows { node.blendMode = .add }
            addChild(node)

            let each = SpriteSheetLoader.frameDuration(for: .effect(burst.effect))
            node.run(.sequence([
                .animate(with: frames, timePerFrame: each, resize: false, restore: false),
                .removeFromParent(),
            ]))
        }

    }

    /// The sparkle, rasterised once from the drawing the view uses.
    ///
    /// Rebuilding a four-layer blur stack in Core Graphics would be a second
    /// implementation of the same bloom, and the two would drift. Rendering
    /// the real one and keeping the picture is one implementation.
    ///
    /// Drawn into a box twice the tile so the blur has somewhere to spread;
    /// anything tighter clips the glow at the edges.
    private static func sparkleImage(
        size: CGFloat, plane: Plane, tint: Color?
    ) -> UIImage? {
        let glow = tint ?? Palette.sparkleGlow(on: plane)
        let bloom = plane == .terra ? GameRules.sparkleGlowTerraDamping : 1
        let side = size * 0.45

        let art = ZStack {
            Circle()
                .fill(glow)
                .frame(
                    width: size * GameRules.sparkleTileGlowSize,
                    height: size * GameRules.sparkleTileGlowSize
                )
                .blur(radius: size * GameRules.sparkleTileGlowBlur)
                .opacity(GameRules.sparkleTileGlowOpacity * bloom)
                .blendMode(.plusLighter)
                .offset(
                    x: -GameRules.sparkleNudge.width,
                    y: -GameRules.sparkleNudge.height
                )

            ZStack {
                ZStack {
                    ForEach(Array(0..<GameRules.sparkleGlowLayers), id: \.self) { step in
                        SparkleGlyph()
                            .fill(glow)
                            .frame(width: side, height: side)
                            .blur(
                                radius: size * GameRules.sparkleGlowRadius
                                    * (1 + CGFloat(step) * 0.9)
                            )
                            .opacity(
                                GameRules.sparkleGlowIntensity * bloom
                                    / Double(step + 1)
                            )
                    }
                }
                .blendMode(.plusLighter)

                SparkleGlyph()
                    .fill(Palette.sparkleCore)
                    .frame(
                        width: side * GameRules.sparkleCoreScale,
                        height: side * GameRules.sparkleCoreScale
                    )
            }
        }
        .frame(width: size * 2, height: size * 2)

        let renderer = ImageRenderer(content: art)
        renderer.scale = 2
        renderer.isOpaque = false
        return renderer.uiImage
    }

    /// The sparkles a set puts out, and the pulse each one keeps.
    ///
    /// Every sparkle runs on its own period, spread by its index — a board of
    /// them beating in step reads as one thing blinking rather than many.
    private func syncSparkles() {
        let set = session.visibleSparkles

        if set != sparkleSet {
            for (_, node) in sparkles { node.removeFromParent() }
            sparkles.removeAll()
            sparkleSet = set

            if let set {
                let tint: Color? = set.pattern == .ring ? Palette.pink : nil
                guard let art = Self.sparkleImage(
                    size: metrics.tileSize, plane: set.plane, tint: tint
                ) else { return }

                let texture = SKTexture(image: art)
                for point in set.points {
                    let node = SKSpriteNode(texture: texture)
                    node.blendMode = .add
                    addChild(node)
                    sparkles[point] = node
                }
            }
        }

        guard let set else { return }

        let now = session.ambientClock(at: Date().timeIntervalSinceReferenceDate)
        for (index, point) in set.points.enumerated() {
            guard let node = sparkles[point] else { continue }

            place(
                node, at: point, on: set.plane,
                tiles: CGSize(width: 2, height: 2),
                shiftX: GameRules.sparkleNudge.width / metrics.scale,
                layer: 7
            )

            let spread = Double((index &* 2_654_435_761 &+ 12_345) % 1_000) / 1_000
            let period = GameRules.sparklePulseFastest
                + (GameRules.sparklePulseSlowest - GameRules.sparklePulseFastest)
                * spread
            let turns = now / period * 2 * .pi + spread * 2 * .pi
            let pulse = CGFloat(sin(turns) + 1) / 2

            node.setScale(node.xScale * (0.72 + 0.28 * pulse))
            node.alpha = (0.55 + 0.45 * pulse) * GameRules.sparkleOpacity
            node.zPosition = Self.effects - 1
        }
    }

    /// The Pentacles, added and removed as the hunt puts them out.
    ///
    /// Diffed against what is already there rather than cleared and rebuilt: an
    /// untouched coin should cost nothing, and almost every frame touches none
    /// of them.
    private func syncCoins(on plane: Plane, inset: CGFloat) {
        let wanted = session.visiblePickups.filter { $0.plane == plane }
        let places = Set(wanted.map(\.point))

        for (point, node) in coins where !places.contains(point) {
            node.parent?.removeFromParent()
            coins[point] = nil
            coinLooks[point] = nil
            coinPools[point] = nil
        }

        for pickup in wanted where coins[pickup.point] == nil {
            let look = PickupCatalog.effect(for: pickup.id).appearance(on: plane)
            let swaps = pickup.fromRing ? PentacleView.ringSwaps : []

            // **The coin is eight frames, not one.** The gold and shadow coins
            // spin; drawing frame zero and leaving it there is what made them
            // look like tokens lying on the board rather than Pentacles.
            let id = SpriteID.pentacle(look)
            let count = max(SpriteAtlas.slice(for: id)?.frames ?? 1, 1)
            let frames: [SKTexture] = (0..<count).compactMap { frame in
                guard let art = PaletteRecolour.image(id, frame: frame, swaps: swaps)
                else { return nil }
                let texture = SKTexture(image: art)
                texture.filteringMode = .nearest
                return texture
            }
            guard let first = frames.first else { continue }
            coinLooks[pickup.point] = look

            let holder = SKSpriteNode()
            addChild(holder)

            // The mark it leaves on the tile. Hung on the holder rather than
            // the coin so it stays on the ground while the coin bobs above it,
            // and cut from the same drawing the piece casts — a smaller thing
            // throwing a smaller version of the same shadow.
            let mark = metrics.tileSize
                * GameRules.pentacleShadowSpan / GameRules.shadowSpriteSpan
            let pool = SKSpriteNode(texture: Self.shadowTexture)
            pool.size = CGSize(width: mark, height: mark)
            pool.anchorPoint = CGPoint(
                x: 0.5,
                y: GameRules.shadowSpriteSeat / CGFloat(GameRules.tilePixelSize)
            )
            pool.position.y = -GameRules.pentacleShadowDrop * metrics.scale
            pool.alpha = GameRules.shadowSpriteOpacity
            pool.zPosition = -1
            holder.addChild(pool)
            coinPools[pickup.point] = pool

            let node = SKSpriteNode(texture: first)
            holder.addChild(node)
            coins[pickup.point] = node

            if frames.count > 1 {
                node.run(.repeatForever(.animate(
                    with: frames,
                    timePerFrame: SpriteSheetLoader.frameDuration(for: id),
                    resize: false,
                    restore: false
                )), withKey: "spin")
            }
        }

        for (point, node) in coins {
            // **Placed by the parent, bobbing in the child.** `place` writes a
            // position every frame; an action writing the same property would
            // be overwritten by it every frame, which is why the coin sat
            // still. The holder is placed, the coin hovers inside it.
            guard let holder = node.parent as? SKSpriteNode else { continue }
            // The span is the appearance's, not one number for all of them —
            // a Polaris drawn at the gold coin's three cells is half again
            // too big, which is most of what looked misplaced about it.
            let span = (coinLooks[point] ?? .standard).spriteSpan
            place(holder, at: point, on: plane,
                  tiles: CGSize(width: span, height: span), layer: 6)
            node.size = holder.size

            // **The coin's own motion, read off the same clock the view reads.**
            // It orbits, it floats, and it shrinks a little at the top of that
            // float; the mark on the ground tracks the orbit and swings the
            // other way, because a coin further from the tile throws a smaller
            // shadow. Written here rather than run as actions: `place` owns the
            // holder's position and an action on the same property loses.
            let beat = session.ambientClock(
                at: Date().timeIntervalSinceReferenceDate
            ) + TimeInterval(point.x * 3 + point.y * 5) * 0.37

            let swing = beat / GameRules.pentacleFloatPeriod * 2 * .pi
            let rise = CGFloat(sin(swing) + 1) / 2
            let float = CGFloat(sin(swing))
                * GameRules.pentacleFloatAmplitude * metrics.scale

            let turns = beat / GameRules.pentacleOrbitPeriod * 2 * .pi
            #if DEBUG
            let radius = PentacleTuning.shared.orbit * metrics.scale
            #else
            let radius = GameRules.pentacleOrbitRadius * metrics.scale
            #endif
            let orbit = CGPoint(
                x: CGFloat(cos(turns)) * radius,
                y: CGFloat(sin(turns)) * radius * 0.4
            )

            #if DEBUG
            let lift = -PentacleTuning.shared.coinY
            let mark = PentacleTuning.shared.markY
            #else
            let lift = GameRules.pentacleLift
            let mark = GameRules.pentacleShadowDrop
            #endif

            node.position = CGPoint(
                x: orbit.x,
                y: lift * metrics.scale - float - orbit.y
            )
            node.setScale(1 - GameRules.pentacleRiseScaleSwing * rise)

            if let pool = coinPools[point] {
                pool.position = CGPoint(
                    x: orbit.x,
                    y: -orbit.y - mark * metrics.scale
                )
                pool.setScale(1 - GameRules.pentacleShadowScaleSwing * rise)
            }
        }
    }

    /// What the cursor says about where it is pointing.
    private static func tint(for status: GameEngine.CursorStatus) -> Color {
        switch status {
        case .clear: Palette.white
        case .damaged: Palette.gold
        case .badlyDamaged: Palette.brown
        case .open, .impossible: Palette.red
        default: Palette.white
        }
    }

    // MARK: - Made once

    /// The drift, as an action the render thread owns.
    private static func drift(seed: Int, scale: CGFloat) -> SKAction {
        let reach = GameRules.cloudSpriteShift * scale
        let period = GameRules.cloudSpriteShiftPeriod

        let out = SKAction.moveBy(x: reach, y: reach * 0.6, duration: period / 2)
        let back = SKAction.moveBy(x: -reach, y: -reach * 0.6, duration: period / 2)
        out.timingMode = .easeInEaseOut
        back.timingMode = .easeInEaseOut

        return .sequence([
            .wait(forDuration: Double(seed % 17) / 17 * period),
            .repeatForever(.sequence([out, back])),
        ])
    }

    /// The shadow drawing, cut once and shared by everything that casts one.
    private static let shadowTexture: SKTexture? = {
        guard let art = PaletteRecolour.image(.pieceShadow, frame: 0, swaps: [])
        else { return nil }
        let texture = SKTexture(image: art)
        texture.filteringMode = .nearest
        return texture
    }()

    /// The bracket frame: four corners, open in the middle.
    private static func bracketImage(
        side: CGFloat,
        thickness: CGFloat,
        reach: CGFloat
    ) -> UIImage {
        let size = CGSize(width: side, height: side)
        return UIGraphicsImageRenderer(size: size).image { context in
            let ink = context.cgContext
            ink.setFillColor(UIColor.white.cgColor)

            for x in [CGFloat(0), side - reach] {
                for y in [CGFloat(0), side - thickness] {
                    ink.fill(CGRect(x: x, y: y, width: reach, height: thickness))
                }
            }
            for x in [CGFloat(0), side - thickness] {
                for y in [CGFloat(0), side - reach] {
                    ink.fill(CGRect(x: x, y: y, width: thickness, height: reach))
                }
            }
        }
    }

    /// The sky, drawn once into a small image and stretched.
    ///
    /// **Small deliberately.** Drawn at its real size this is nine plane
    /// squares tall — about ten and a half thousand pixels on a 3x screen,
    /// which is past the maximum texture size on most GPUs, and asking for it
    /// takes the app down. A vertical gradient needs no horizontal resolution
    /// and very little vertical, so it is baked at a couple of hundred pixels
    /// and the sprite is sized to the column.
    ///
    /// The same stops the SwiftUI column uses, so the two are the same sky and
    /// not two opinions about one.
    private static func skyImage() -> UIImage {
        let rows = Double(World.rows)
        let terra = Double(World.row(of: .terra))
        let stops: [(CGFloat, UIColor)] = [
            (0, UIColor(Palette.coolBlack)),
            (CGFloat((terra - WorldSky.dawn) / rows), UIColor(Palette.coolBlack)),
            (CGFloat((terra + 0.5) / rows), UIColor(Palette.cyan)),
            (CGFloat((terra + 1 + WorldSky.dusk) / rows), UIColor(Palette.coolBlack)),
            (1, UIColor(Palette.coolBlack)),
        ]

        let size = CGSize(width: 8, height: 512)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1

        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            let space = CGColorSpaceCreateDeviceRGB()
            guard let gradient = CGGradient(
                colorsSpace: space,
                colors: stops.map(\.1.cgColor) as CFArray,
                locations: stops.map(\.0)
            ) else {
                UIColor(Palette.coolBlack).setFill()
                context.fill(CGRect(origin: .zero, size: size))
                return
            }

            context.cgContext.drawLinearGradient(
                gradient,
                start: .zero,
                end: CGPoint(x: 0, y: size.height),
                options: []
            )
        }
    }
}
