//
//  BoardScene.swift
//  Project Stars
//
//  The top screen as a retained scene rather than a rebuilt view tree.
//

import CoreImage
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

    /// The half a split sign left behind, and the line walking after it.
    private var twin: SKSpriteNode?
    private var retinue: [SKSpriteNode] = []

    /// Libra's two arms, two pans and two pan shadows, in that order.
    private var limbs: [SKSpriteNode] = []

    /// How far the surface under the piece has lifted it, in points.
    ///
    /// Kept so that anything hung off the piece which belongs on the *ground*
    /// can take it back off again — a shadow rides up with its caster
    /// otherwise, which is the one thing a shadow must never do.
    private var perch: CGFloat = 0

    /// The lit gems trailing behind a charged piece.
    private var gems: [SKSpriteNode] = []

    /// Pisces' fish, and Sagittarius' arrow in flight.
    private var fish: SKSpriteNode?
    private var fishHolder: SKNode?
    private var loosed: SKSpriteNode?

    /// The arrow he carries, as against the one he looses.
    private var quiver: SKSpriteNode?

    /// Virgo's three gems.
    private var virgoGems: [SKSpriteNode] = []
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

    /// And whether it was lit when that was cut, since the gems change with it.
    private var litUp = false

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
        // **A row beyond each end.** The world wraps: a fall runs off the
        // bottom at row eight and the camera comes back on at minus one, which
        // is a row the column does not have. It is sky at both ends, so the
        // gradient simply reaches past them and the seam has nothing to show.
        let height = side * CGFloat(World.rows + 2)
        let sky = SKSpriteNode(
            texture: SKTexture(image: Self.skyImage()),
            size: CGSize(width: side, height: height)
        )
        sky.position = CGPoint(x: side / 2, y: side - height / 2)
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

        // **The four overhanging rocks**, two sets of a left and a right.
        //
        // They sit between the board's floor and the foreground, hanging in
        // over the edges — the far pair smaller and further in, the near pair
        // full size and further out. `TerraMidRocks` pins each to the top
        // corner it belongs to and pushes it back in by its set's spread, so
        // the same two drawings serve both sets at two depths.
        //
        // Their numbers come from the bench in debug, as everything else in
        // this scenery does, so the sliders still move them.
        let span = side * 2 / across
        for set in [1, 0] {
            #if DEBUG
            let bench = TerraSceneryTuning.shared
            let spread = set == 0 ? bench.nearSpread : bench.farSpread
            let drop = set == 0 ? bench.nearRockY : bench.farRockY
            #else
            let spread = set == 0
                ? GameRules.terraRocksNearSpread : GameRules.terraRocksFarSpread
            let drop = set == 0 ? GameRules.terraRocksNearY : GameRules.terraRocksFarY
            #endif

            let size = span * (set == 0 ? 1 : GameRules.terraRocksFarScale)

            for part in [TerraScenery.midLeft, .midRight] {
                guard let art = PaletteRecolour.image(
                    .terraScenery(part), frame: 0, swaps: []
                ) else { continue }

                let texture = SKTexture(image: art)
                texture.filteringMode = .nearest

                let node = SKSpriteNode(
                    texture: texture,
                    size: CGSize(width: size, height: size)
                )
                let out = part == .midLeft ? spread : -spread
                node.position = CGPoint(
                    x: part == .midLeft
                        ? size / 2 + out * pixel
                        : side - size / 2 + out * pixel,
                    y: -size / 2 - drop * pixel
                )
                node.zPosition = Self.depth(row: GameRules.gridSize, layer: -2)
                    + CGFloat(set)
                holder.addChild(node)
            }
        }

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
        var forced: Set<GridPoint> = []
        #if DEBUG
        if TileEdgeTuning.shared.raiseCentre {
            let pick = Int(TileEdgeTuning.shared.raiseRow)
            for column in 0..<GameRules.gridSize {
                forced.insert(GridPoint(column, pick))
            }
            raised.formUnion(forced)
        }
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
                // How far out from the middle the edge sits, and the dial
                // that scales that distance. The front lip declines it, since
                // it is already right — see below.
                let outward = (metrics.center(of: point).x - middle) * band.scale
                let plainX = middle + outward + inset
                // The nudge, plus however much each column away from the
                // middle has to come in. One number describing the whole row,
                // rather than one per tile.
                let fromMiddle = CGFloat(point.x) - CGFloat(metrics.gridSize - 1) / 2
                let originX = middle + outward * set.spread + inset
                    + (set.x - set.perColumn * fromMiddle)
                    * metrics.scale * band.scale
                let sitsAt = -floorY - inset
                    - set.y * metrics.scale * band.groundScale

                // An edge is only ever what a lift uncovered, so it takes that
                // much of the drawing — the top of it, where it meets the face
                // — and draws it at the drawing's own proportions rather than
                // stretching what it has.
                if raised.contains(point) {
                    // **Stacked, not stretched.** The drawing is four pixels
                    // tall and lives in the top four rows of its cell — the
                    // rest of the cell is empty, so cropping to the pop's
                    // height took four pixels of art and four of nothing. A
                    // pop deeper than the drawing is covered by laying copies
                    // of it end to end, which is what the art is for; pulling
                    // one to twice its height is visible.
                    // **As tall as the face above it actually rose.** The
                    // wall joins the footprint's near corners to the top
                    // face's, and the top face's near edge lifts by its own
                    // corner's amount — so the wall's height is that rise, not
                    // a constant put through the row's squash. Squashing it
                    // would be treating the wall as though it lay on the
                    // ground, and it is the one thing here that does not.
                    let art = GameRules.tileEdgeHeight
                    let slice = min(
                        max(art / CGFloat(GameRules.tilePixelSize), 0), 1
                    )
                    // Measured to where the strip actually put the face's
                    // underside, not worked out again from the same rise. The
                    // strip rounds that to a whole art row; matching its answer
                    // is what closes the hairline between them.
                    let lifted = Self.riser(
                        row: point.y, lift: set.popLift, metrics: metrics
                    ).near
                    let wall = (floorY - screenY(artAbove: lifted, row: point.y))
                        * set.yScale
                    let copies = max(Int((wall / (art * metrics.scale)).rounded(.up)), 1)
                    let each = copies > 0 ? wall / CGFloat(copies) : wall

                    // **The flank: two uprights and two parallels.**
                    //
                    // Built as a shape that can only ever be that — a vertical
                    // at each end and its two ends joined — so no setting of
                    // the dials can make it something else. Everything about it
                    // is a multiple of what the board's own geometry gives, so
                    // one is the derived answer and the dials say how far off
                    // that answer is.
                    //
                    // `wide` is the board's convergence across one tile: a
                    // tile's inward edge sits nearer the middle at its far end
                    // than its near one. `drop` is how much further back that
                    // far end sits. `tall` is the wall's own height.
                    let cellArt = CGFloat(GameRules.tilePixelSize)
                    let rose = Self.riser(
                        row: point.y, lift: set.popLift, metrics: metrics
                    )
                    let middleArt = CGFloat(board.size) * cellArt / 2
                    let outward = (CGFloat(point.x) + 0.5) * cellArt - middleArt

                    if outward != 0, set.flankOn {
                        let flat = (outward > 0
                            ? CGFloat(point.x)
                            : CGFloat(point.x + 1)) * metrics.tileSize
                        let mid = metrics.boardSize / 2
                        let grid = metrics.gridSize
                        let at: (CGFloat) -> CGFloat = { edge in
                            mid + (flat - mid) * GameRules.boardForeshortenScale
                                / BoardBand.edgeDivisor(at: edge, gridSize: grid)
                                + inset
                        }

                        let backY = BoardBand.edgeY(point.y, metrics: metrics)
                        let near = at(CGFloat(point.y + 1))

                        let column = min(max(point.x, 0), set.flankWides.count - 1)
                        let wide = (at(CGFloat(point.y)) - near)
                            * set.flankWides[column]
                        let drop = (floorY - backY) * set.flankDrop
                        let tall = (floorY - screenY(artAbove: rose.near, row: point.y))
                            * set.flankTall

                        let x = near + set.flankX * metrics.scale * band.scale
                        let y = -floorY - inset
                            - set.flankY * metrics.scale * band.groundScale

                        let path = CGMutablePath()
                        path.move(to: CGPoint(x: x, y: y))
                        path.addLine(to: CGPoint(x: x, y: y + tall))
                        path.addLine(to: CGPoint(x: x + wide, y: y + drop + tall))
                        path.addLine(to: CGPoint(x: x + wide, y: y + drop))
                        path.closeSubpath()

                        let node = SKShapeNode(path: path)
                        node.fillColor = UIColor(Palette.tileFlank)
                        node.strokeColor = .clear
                        node.lineWidth = 0
                        node.isAntialiased = false
                        node.zPosition = Self.depth(row: point.y, layer: 1)
                        holder.addChild(node)
                    }

                    for copy in 0..<copies {
                        let node = SKSpriteNode(
                            texture: SKTexture(
                                rect: CGRect(x: 0, y: 1 - slice, width: 1, height: slice),
                                in: texture
                            ),
                            size: CGSize(width: across * set.xScale, height: each)
                        )
                        node.anchorPoint = CGPoint(x: 0.5, y: 0)

                        // **The bottom one is the one that flips.** Two
                        // identical four pixel strips stacked read as one
                        // drawing repeated; mirroring alternates hides that.
                        // Which alternate matters on the front row, where the
                        // lip sits directly under the lowest of these and is
                        // never mirrored — so it is the lowest that has to
                        // differ from it, not the highest.
                        let mirrored = copy.isMultiple(of: 2)
                        node.xScale = mirrored ? -1 : 1
                        node.yScale = mirrored && set.turns ? -1 : 1

                        // Turned over about a bottom anchor, a copy hangs
                        // below its own slot; the shift puts it back in it.
                        node.position = CGPoint(
                            x: originX,
                            y: sitsAt + CGFloat(copy) * each
                                + (node.yScale < 0 ? each : 0)
                        )
                        node.zPosition = Self.depth(row: point.y, layer: -1)
                        holder.addChild(node)
                    }
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
                    row, board: board, raised: raised, forced: forced,
                    popY: set.pop, popX: set.popX, lift: set.popLift
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
        _ row: Int, board: Board, raised: Set<GridPoint>,
        forced: Set<GridPoint>, popY: CGFloat, popX: CGFloat, lift: CGFloat
    ) -> SKSpriteNode? {
        guard let strip = Self.rowImage(
            row, board: board, raised: raised, forced: forced,
            popY: popY, popX: popX, lift: lift, metrics: metrics
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
        let tall = Self.stripAbove(row: row, lift: lift, metrics: metrics)
            + cell + Self.stripBelow

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

        // The node carries the margin too, so the extra art has somewhere to
        // land. It stays centred on the board — the margin hangs off each side.
        let margin = Self.stripSide * metrics.scale
        let wideNode = metrics.boardSize + 2 * margin
        let node = SKSpriteNode(
            texture: texture,
            size: CGSize(width: wideNode, height: deep)
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
        // **Six slices and one column.**
        //
        // A warp's geometry is walked every frame it is drawn, so this is the
        // one number in the bake that is also a per-frame cost — seven strips
        // at ten by seventeen was a hundred and seventy vertices apiece, and
        // Terra alone has the strips.
        //
        // Measured rather than guessed: a piecewise-linear fit of the row's
        // curve is out by 1.7pt at one slice, 0.12pt at four and 0.05pt at six,
        // on a board the size of a phone's. Sixteen was buying eight
        // thousandths of a point. Six is already far under the pixel it would
        // have to reach to be visible.
        //
        // One column, because at a given depth the horizontal map *is* linear
        // — the curve is all in the vertical. The extra columns were insurance
        // against an error that the slices already answer.
        let slices = 6
        let columns = 1
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

                // The row's scale is about the **board's** middle, not the
                // node's — the margin is not part of the board and must not be
                // foreshortened as though it were. So the sample is taken into
                // board space, scaled there, and put back.
                let onBoard = (u * wideNode - margin) / metrics.boardSize
                let thrown = 0.5 + (onBoard - 0.5) * wide
                let back = (margin + thrown * metrics.boardSize) / wideNode

                source.append(.init(Float(u), Float(v)))
                destination.append(.init(Float(back), Float(up)))
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
    /// Where a height above a row's floor lands on screen, in points.
    ///
    /// Through the **same pinned curve the strip is warped by** — sampled off
    /// `edgeY(at:)` and stretched to meet the rounded values at the row's two
    /// whole edges. Anything placed against the strip has to ask this rather
    /// than work it out for itself, or the two disagree by a fraction of a
    /// pixel and leave a hairline where they meet.
    private func screenY(artAbove: CGFloat, row: Int) -> CGFloat {
        let cell = CGFloat(GameRules.tilePixelSize)
        let front = CGFloat(row + 1)

        let floorY = BoardBand.edgeY(row + 1, metrics: metrics)
        let backY = BoardBand.edgeY(row, metrics: metrics)
        let looseFront = BoardBand.edgeY(at: front, metrics: metrics)
        let looseBack = BoardBand.edgeY(at: front - 1, metrics: metrics)
        let loose = looseBack - looseFront

        let here = BoardBand.edgeY(at: front - artAbove / cell, metrics: metrics)
        guard loose != 0 else { return here }
        return floorY + (here - looseFront) * (backY - floorY) / loose
    }

    /// Where a popped tile's two edges end up, in art pixels above the strip's
    /// floor.
    ///
    /// **Each corner rises by its own amount.** A vertical of a given world
    /// height is longer nearer the camera, so a tile's near edge lifts further
    /// than its far edge and the face arrives squashed in depth — by a
    /// different amount on every row. Its corners keep their x, because in this
    /// perspective the walls are vertical and a top corner sits directly above
    /// the footprint corner it belongs to.
    ///
    /// Worked in screen points and then put back into the strip's own art rows,
    /// since the strip's vertical is not linear — that is the whole reason a
    /// tile lifted *inside* it came out wrong.
    private static func riser(
        row: Int, lift: CGFloat, metrics: PixelArtMetrics
    ) -> (near: CGFloat, far: CGFloat) {
        let front = CGFloat(row + 1)
        let cell = CGFloat(GameRules.tilePixelSize)
        let tall = GameRules.tileEdgeHeight * max(lift, 0)
        guard tall > 0 else { return (0, cell) }

        let zoom = GameRules.boardForeshortenScale
        let rise: (CGFloat) -> CGFloat = { edge in
            tall * zoom
                / BoardBand.edgeDivisor(at: edge, gridSize: metrics.gridSize)
                * metrics.scale
        }

        let near = BoardBand.edgeY(at: front, metrics: metrics) - rise(front)
        let far = BoardBand.edgeY(at: front - 1, metrics: metrics) - rise(front - 1)

        // Clamped: a strip is a texture, and a bad number here is a texture
        // the size of a wall rather than a tile out of place.
        // **Whole art rows.** A sprite drawn at a fraction of a pixel is
        // resampled, and resampled pixel art is a smear — the eye picks that up
        // long before it picks up a third of a pixel of geometry. Rounding also
        // means the wall below can meet this exactly rather than nearly.
        let top = ((front - Self.edgeOf(near, metrics: metrics)) * cell).rounded()
        let bottom = ((front - Self.edgeOf(far, metrics: metrics)) * cell).rounded()
        return (
            min(max(top, 0), cell * 4),
            min(max(bottom, top + 1), cell * 5)
        )
    }

    /// Which edge lands on a given screen y — `BoardBand.edgeY(at:)` run
    /// backwards.
    ///
    /// Bisected rather than solved. The forward map is monotonic and this runs
    /// once a row when the board changes, so the closed form would buy nothing
    /// but a chance to get the algebra wrong.
    private static func edgeOf(_ y: CGFloat, metrics: PixelArtMetrics) -> CGFloat {
        // `edgeY` **increases** with the edge: nought is the far edge and sits
        // highest on screen. Comparing it the other way round converges on the
        // bound rather than the answer, which is a strip of absurd height and a
        // board with no rows left in it.
        var low = CGFloat(-4)
        var high = CGFloat(metrics.gridSize + 4)
        for _ in 0..<40 {
            let mid = (low + high) / 2
            if BoardBand.edgeY(at: mid, metrics: metrics) > y { high = mid } else { low = mid }
        }
        return (low + high) / 2
    }

    /// How far above the tile row the strip reaches, in art pixels — the room
    /// a popped tile needs to rise into.
    /// Rounded up to a whole art row, because the strip is **rasterised**. A
    /// fractional height leaves the renderer to round it on its own, and a
    /// texture a fraction taller than the geometry expects is a hairline along
    /// every row. The extra is transparent and costs nothing.
    private static func stripAbove(row: Int, lift: CGFloat, metrics: PixelArtMetrics) -> CGFloat {
        let head = riser(row: row, lift: lift, metrics: metrics).far
            - CGFloat(GameRules.tilePixelSize)
        return max(head, 0).rounded(.up)
    }

    /// How much room the strip keeps either side of the board, in art pixels.
    ///
    /// A tile thrown outward by the perspective, or by the bench, runs off the
    /// end of a strip cut to the board's exact width and is simply cut off
    /// there. A tile of margin costs one texture row either side and means the
    /// thing being looked at is never the clipping.
    private static let stripSide = CGFloat(GameRules.tilePixelSize)

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
        forced: Set<GridPoint>,
        popY: CGFloat,
        popX: CGFloat,
        lift: CGFloat,
        metrics: PixelArtMetrics
    ) -> UIImage? {
        // **Baked at the art's own resolution.** Drawing 16-pixel tiles into a
        // strip measured in *points* resamples every one of them on the way in,
        // and no amount of nearest-neighbour filtering afterwards can put back
        // detail that was averaged away — which is what made the cracks blurry
        // while the flat faces looked passable. The strip is now exactly as
        // many pixels as the art is, and SpriteKit does the enlarging.
        let cell = CGFloat(GameRules.tilePixelSize)
        let rise = riser(row: row, lift: lift, metrics: metrics)
        let head = stripAbove(row: row, lift: lift, metrics: metrics)

        // **Undoing what the warp does to a face drawn higher in the source.**
        //
        // The walls are vertical, so the top face keeps its footprint's columns
        // exactly. But it is drawn further up the strip, and up the strip is
        // back through the board — so the warp narrows it on the way out. The
        // fix is to widen it here by precisely what the warp will take off,
        // which lands it on the columns it started with.
        //
        // The same ratio at the near edge as at the far one, so it is a plain
        // scale rather than a keystone: the rise is a constant world height, so
        // the depth it stands in is a constant too. And the same on every row,
        // which is why one number held up wherever it was tried.
        let front = CGFloat(row + 1)
        let widen = BoardBand.edgeDivisor(
            at: front - rise.near / cell, gridSize: metrics.gridSize
        ) / BoardBand.edgeDivisor(at: front, gridSize: metrics.gridSize)
        let middle = CGFloat(board.size) * cell / 2
        let size = CGSize(
            width: CGFloat(board.size) * cell + 2 * stripSide,
            height: head + cell + stripBelow
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
                // The tile's own place in the strip, and how far it has risen
                // out of it. `BandRow` stacks the edge and the face bottom-
                // aligned and then offsets each, which is what these two are.
                // **Its x is untouched; only its depth changes.** The walls
                // are vertical, so a top corner is directly above the footprint
                // corner it belongs to — the face keeps its columns exactly and
                // arrives squashed, by however much more its near edge rose
                // than its far one.
                let isRaised = raised.contains(point)
                // An ordinary tile sits on the strip's floor and is one cell
                // tall. Only a raised one reaches up into the headroom.
                let top = isRaised ? head + cell - rise.far : head
                let bottom = isRaised ? head + cell - rise.near : head + cell

                // **Moved, not scaled.** Scaling a sprite into a fractional
                // width resamples every column of it, which is a smear; a
                // translation only shifts which source pixel each destination
                // one takes, so it stays crisp. The width the widening asked
                // for was 16.33 against 16 — a sixth of a pixel each side, well
                // under one — so all that is worth keeping from it is where the
                // tile's middle lands.
                let shift = (((CGFloat(column) + 0.5) * cell - middle)
                    * (widen - 1)).rounded()

                let box = CGRect(
                    x: stripSide + CGFloat(column) * cell
                        + (isRaised ? shift + popX : 0),
                    y: top + (isRaised ? popY : 0),
                    width: cell,
                    height: bottom - top
                )

                // **Face, then cast, then wear — see `TileMaterial`.** The wear
                // drawings are overlays with no face of their own, so this
                // stacks them rather than swapping between them. Asking there
                // rather than deciding here is what keeps the two renderers
                // from drifting apart, which they have done before.
                if let art = PaletteRecolour.image(
                    TileMaterial.face(
                        of: tile, on: .terra, shade: shade, popped: isRaised
                    ),
                    frame: 0, swaps: []
                ) {
                    drewAnything = true
                    art.draw(in: box)
                }

                // A tile the bench put up is a whole one. Raising a hole
                // shows the hole, which is nothing to measure a shift against.
                if forced.contains(point) { drewAnything = true; continue }

                // The cast a badly cracked tile takes, over its face and under
                // its damage — `TileView` overlays the face with it.
                if let tint = TileMaterial.tint(of: tile, on: .terra) {
                    context.cgContext.saveGState()
                    context.cgContext.setBlendMode(.plusDarker)
                    UIColor(tint.colour)
                        .withAlphaComponent(tint.share)
                        .setFill()
                    context.fill(box)
                    context.cgContext.restoreGState()
                }

                // **And whatever has happened to it.** The bake drew every tile
                // in mint condition and skipped the holes entirely, so a board
                // could be worn to pieces and still read as new.
                if let wear = TileMaterial.wear(of: tile),
                   let art = PaletteRecolour.image(
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
        // The real height is set each frame from the sign's own drawing — see
        // `cells(_:)`. This is only what it starts as.
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
        // **Above the island, below the figure.** The piece sits at layer five
        // of its row and the island at layer three, so a shadow three below the
        // piece lands at layer two — under the island, which is why it vanished
        // the moment she stood on one. One below keeps it clear of both.
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
    /// The island's own journey between planes.
    ///
    /// `BoardView.nexysTravelPose` is the same rule. It answers `.rest` while
    /// the island is riding the camera, because then the camera is doing the
    /// moving and the island only has to stay where it is relative to it.
    private func travelPose() -> AscentPose {
        guard !session.nexysRidesCamera else { return .rest }
        let now = Date()
        let up = session.nexysTravellingUp
        let board = metrics.boardSize

        if let leaving = session.nexysDepartStartedAt {
            let progress = now.timeIntervalSince(leaving)
                / (up ? GameRules.ascentRiseDuration : GameRules.nexysTravelDepartDuration)
            return up
                ? .rising(progress: min(max(progress, 0), 1), boardSize: board)
                : .departing(progress: progress, boardSize: board, goingUp: false)
        }

        if let arriving = session.nexysArriveStartedAt {
            let progress = now.timeIntervalSince(arriving)
                / (up ? GameRules.ascentGrowDuration : GameRules.fallArrivalDuration)
            return up
                ? .risingIn(progress: progress, boardSize: board)
                : .fallingIn(progress: progress, boardSize: board)
        }
        return .rest
    }

    /// How far the camera has travelled from where a plane sits at rest.
    ///
    /// Read off the camera node rather than off `cameraRow`, because the row is
    /// the *destination* — an animated value in the model is at its target from
    /// the first frame, and only the node is actually part-way there.
    private func cameraRide(on plane: Plane) -> CGFloat {
        follow.position.y + CGFloat(World.row(of: plane)) * side + side / 2
    }

    /// The give under something that has just landed on a square.
    private func dip(at point: GridPoint, on plane: Plane) -> CGFloat {
        guard let bounce = session.surfaceBounce, bounce.plane == plane else { return 0 }
        return CloudMotion.dip(
            point,
            bounce: CloudMotion.Bounce(
                point: bounce.point,
                start: bounce.start.timeIntervalSinceReferenceDate
            ),
            now: Date().timeIntervalSinceReferenceDate,
            scale: metrics.scale,
            over: NexysStyle.bounceHold,
            depth: NexysStyle.bounceDepth,
            attack: NexysStyle.bounceAttack,
            rebound: NexysStyle.rebound
        )
    }

    /// How far into its settling rock the island is, if it is in one.
    private func rocking() -> CGFloat? {
        guard NexysStyle.foreshortened,
              let bounce = session.surfaceBounce,
              bounce.point == GameRules.nexysPoint
        else { return nil }

        let since = Date().timeIntervalSinceReferenceDate
            - bounce.start.timeIntervalSinceReferenceDate
        guard since >= 0, since < NexysStyle.rockHold else { return nil }
        return CGFloat(since / NexysStyle.rockHold)
    }

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

    /// The give the piece takes from the island it is standing on.
    ///
    /// In points rather than art pixels, because that is how `CloudMotion.dip`
    /// answers — and it is applied after the row's scaling for the same reason
    /// the island's is, so the two settle together by the same amount.
    private func carryGive() -> CGFloat {
        guard session.engine.isOnNexys else { return 0 }
        return dip(at: GameRules.nexysPoint, on: session.engine.nexysPlane)
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
        var perColumn: CGFloat
        var spread: CGFloat
        var popX: CGFloat
        var popLift: CGFloat
        var flankOn: Bool
        var flankWides: [CGFloat]
        var flankDrop: CGFloat
        var flankTall: CGFloat
        var flankX: CGFloat
        var flankY: CGFloat

        /// **In here rather than read where it is used.** `rebuild` is what
        /// draws the edges, and `builtDials` is what decides whether to run it
        /// — so anything the edges depend on that is not in this struct is a
        /// control that changes nothing until the board happens to move.
        var turns: Bool
    }

    private var set: Dials {
        #if DEBUG
        let bench = TileEdgeTuning.shared
        return Dials(pop: bench.popY, x: bench.edgeX, y: bench.edgeY,
                     xScale: bench.edgeXscale, yScale: bench.edgeYscale,
                     perColumn: bench.edgeXper, spread: bench.edgeXmul,
                     popX: bench.popX, popLift: bench.popLift,
                     flankOn: bench.flankOn, flankWides: bench.flankWides,
                     flankDrop: bench.flankDrop, flankTall: bench.flankTall,
                     flankX: bench.flankX, flankY: bench.flankY,
                     turns: bench.stackTurns)
        #else
        return Dials(pop: GameRules.tilePopLift, x: 0, y: 0,
                     xScale: 1, yScale: 1, perColumn: 0, spread: 1,
                     popX: 0, popLift: 1,
                     flankOn: true,
                     flankWides: Array(repeating: 1, count: GameRules.gridSize),
                     flankDrop: 1, flankTall: 1,
                     flankX: 0, flankY: 0, turns: false)
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
            // **A wrap is a jump, not a journey.** At the seam the camera goes
            // from the bottom row to one above the top, which is the whole
            // column's height in one step — travelled, it would sail back up
            // through every plane it had just passed. Taken, it is invisible,
            // because both ends of the seam are sky.
            // **Both measured before the target moves.** `aimedAt` is the leg
            // being left; once it has been overwritten the distance to it is
            // nought, and a leg of no length is a leg of no duration — which is
            // every plane change happening instantly.
            let far = abs(want.y - aimedAt)
            let leap = far > side * CGFloat(World.rows - 2)
            let rows = far / side

            aimedAt = want.y
            follow.removeAction(forKey: "travel")

            // Paced by the distance, as the session paces it: one fixed
            // duration here against its per-row pace meant a two-row leg and a
            // three-row leg arrived at different moments in the two, and
            // anything riding the camera arrived with the wrong one.
            let pace = (GameRules.fallDuration + GameRules.fallArrivalDuration)
                / Double(World.row(of: .terra) - World.row(of: .astra))
            let span = !leap && (session.isChangingPlane || session.isDropping)
                ? rows * pace
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
        if TileEdgeTuning.shared.raiseCentre {
            let pick = Int(TileEdgeTuning.shared.raiseRow)
            for column in 0..<GameRules.gridSize {
                risen.insert(GridPoint(column, pick))
            }
        }
        #endif
        for plane in Plane.allCases
        where built[plane] != session.engine[plane] || builtRaised[plane] != risen
            || builtDials[plane] != set {
            rebuild(plane)
        }

        let standing = session.engine.piece
        let looking = session.visibleFacing
        let id = SpriteID.pieceFacing(standing.zodiac, looking)
        figure.size = CGSize(
            width: metrics.tileSize,
            height: metrics.tileSize * Self.cells(id)
        )

        // **The gems.** `PieceView` swaps the element's dim gem for its lit one
        // while the meter is full, and for its resting tone when it is not —
        // the drawing itself only ever holds the dim colour, so a piece drawn
        // with no swaps at all is a piece whose gems never light. Virgo's hair
        // is four pixels of it.
        let gem = GemTones.forElement(standing.zodiac.element)
        let swaps: [PaletteSwap] = session.isZodiactionCharged
            ? [PaletteSwap(gem.dim, gem.lit)]
            : (gem.resting.map { [PaletteSwap(gem.dim, $0)] } ?? [])

        if id != wearing || session.isZodiactionCharged != litUp,
           let art = PaletteRecolour.image(id, frame: 0, swaps: swaps) {
            litUp = session.isZodiactionCharged
            let texture = SKTexture(image: art)
            texture.filteringMode = .nearest
            figure.texture = texture
            // East is west, mirrored: there is no east drawing on the sheet.
            // See `PieceView.isMirrored`.
            mirror = looking == .right && standing.zodiac != .gemini ? -1 : 1
            wearing = id
        }

        let inset = (side - metrics.boardSize) / 2

        // **Placed by the plane it is made of, not the one the engine has put
        // it on.** Those differ for the length of a fall, and the two planes
        // seat a piece by different rules — Terra on its band, Astra where the
        // projection puts it — so taking the engine's answer moved the piece's
        // footing the instant it was said to have arrived, part-way down.
        // `BoardView` draws it on `materialPlane` for the same reason.
        let footing = session.materialPlane ?? standing.plane
        let spot = metrics.projected(standing.point, on: footing)
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

        // Whatever it is standing on, and how far that has lifted it.
        let stood = (session.engine.isOnNexys
            ? carryLift()
            : surfaceLift(of: standing.point, on: footing))
            * metrics.scale * spot.scale
        perch = stood

        // **A falling piece rides the camera down.** `BoardView` gets this by
        // moving the board under a piece that stays put — `fallOffset` — but
        // the scene lays every plane out in world space and moves a real
        // camera instead, so the piece has to be told to come along or it
        // simply waits on the plane it is bound for while the camera travels.
        //
        // **Always, not only while falling.** `BoardView` applies its offset
        // unconditionally, and the camera row only leaves a plane during a
        // transition — so gating it on the session's flags could only ever
        // disagree with the view, and did on the leg out of the underground,
        // where the piece hung at Astra's row and read as being pulled up into
        // it rather than dropped down into it.
        let ride = cameraRide(on: footing)
        let seat = CGPoint(
            x: spot.position.x + inset,
            y: -CGFloat(World.row(of: standing.plane)) * side
                - Self.seatY(standing.point, on: footing,
                             metrics: metrics, spot: spot)
                - inset - stand
                + stood
                + ride - carryGive()
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

        // **The island's journey, and the give under it when it lands.**
        //
        // It went missing between planes because it was pinned to the plane it
        // belonged to while the camera travelled without it. The piece already
        // rides the camera down; this is the same ride, and the same reason —
        // the scene keeps every plane in world space, so anything crossing
        // between them has to be told to come along.
        //
        // The travel pose is what carries it off one plane and onto the next
        // under its own power, for the times it is not riding the camera.
        // **Carried or travelling, never both.** `nexysTravelPose` answers
        // `.rest` while the island is riding the camera, because then the
        // camera is doing the moving — and an island given the camera's travel
        // *and* its own arrival lift is an island a whole board off the top of
        // the screen. That is the one going down to Terra.
        //
        // The ride outlasts its own flag on purpose: the flag drops before the
        // camera has finished arriving, and without this the island snapped
        // back to where its plane sits, which is off screen until the camera
        // catches up.
        let journey = travelPose()
        let carried = journey == .rest
            && (session.nexysRidesCamera
                || session.isChangingPlane || session.isDropping)
            ? cameraRide(on: home)
            : 0
        let settle = dip(at: GameRules.nexysPoint, on: home)

        for node in [island, pillar] {
            node.position.y += carried - journey.lift - settle
            node.setScale(node.xScale * journey.scale)
        }

        // Landing swaps the drawn-in-perspective island for the flat one and
        // swells it a little as it settles — the two only read as a landing
        // together, which is why the sprite is chosen here rather than once.
        let rock = rocking()
        island.texture = Self.art(
            NexysStyle.foreshortened && rock == nil ? .nexysDeep : .nexys
        )
        island.xScale *= rock.map {
            1 + NexysStyle.rockSquash * CGFloat(sin(Double($0) * .pi))
                / NexysStyle.islandArtWidth
        } ?? 1


        syncCoins(on: standing.plane, inset: inset)
        syncSparkles()
        syncHalf()
        syncRetinue(on: standing.plane)
        syncScales()
        syncGems()
        syncFish()
        syncQuiver()
        syncGems(for: standing)
        syncArrow()
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
            // **The row it happened on**, unless the drawing is one that
            // reads as being over the board rather than on it. `BoardLayer`
            // makes the same distinction: `.effect` is the one layer that does
            // not sort by row, and everything else does.
            node.zPosition = burst.effect.anchor == .standing
                ? Self.depth(row: burst.center.y, layer: 8)
                : Self.effects
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
            // **On its own row, not over the board.** A sparkle marks a
            // square; it belongs to that square's depth the way a coin or a
            // cursor does, and putting it on the effects layer drew it over
            // everything in front of it.
            node.zPosition = Self.depth(row: point.y, layer: 7)
        }
    }

    /// The fish that swims over Pisces' head.
    ///
    /// `PieceView` overlays it on the *top* of her two-cell frame, so it takes
    /// the upper cell. It turns to face where she faces, squashes when she is
    /// in profile — the drawing is seen edge-on then — and when the meter is
    /// full it swaps for the lit one and takes the star's hover, the same drift
    /// and spin Polaris has.
    private func syncFish() {
        let standing = session.engine.piece

        guard standing.zodiac == .pisces else {
            fishHolder?.isHidden = true
            return
        }

        // **A holder to squash in, and the fish to turn inside it.** The view
        // rotates first and scales after, so the squash is in screen space; a
        // node's own scale is in its own space, which a quarter turn has taken
        // sideways. Splitting the two puts each back where it belongs.
        let holder = fishHolder ?? {
            let made = SKNode()
            piece.addChild(made)
            fishHolder = made
            return made
        }()

        let node = fish ?? {
            let made = SKSpriteNode()
            made.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            holder.addChild(made)
            fish = made
            return made
        }()

        let facing = session.visibleFacing
        let pixel = metrics.scale
        let charged = session.isZodiactionCharged
        let now = session.ambientClock(at: Date().timeIntervalSinceReferenceDate)

        node.isHidden = false
        node.texture = Self.art(charged ? .piscesFishCharged : .piscesFish)
        node.size = CGSize(width: metrics.tileSize, height: metrics.tileSize)

        // Turned to her heading. SwiftUI counts a turn clockwise and SpriteKit
        // counts it the other way, so the sign flips on the way across.
        let turn: CGFloat = switch facing {
        case .right: -90
        case .up: -180
        case .left: -270
        default: 0
        }

        let squash: CGFloat = facing == .left || facing == .right
            ? GameRules.piscesFishSideSquash
            : 1
        let sink = (1 - squash) * metrics.tileSize / 2

        let drift = charged
            ? CGSize(
                width: -cos(now / GameRules.polarisBobPeriod * 2 * .pi)
                    * GameRules.polarisBobRadius,
                height: sin(now / GameRules.polarisBobPeriod * 2 * .pi)
                    * GameRules.polarisBobRise
            )
            : .zero

        node.zRotation = -turn * .pi / 180
            + (charged ? CGFloat(now / GameRules.polarisSpinPeriod * 2 * .pi) : 0)
        node.xScale = 1
        node.yScale = 1
        node.position = .zero

        // The squash is the holder's, so it stays on the screen's vertical
        // however far the fish has turned. The hop's is the holder's too — she
        // squashes as she lands and the fish goes with her.
        let hop = session.hopPose(at: Date())
        holder.isHidden = false
        holder.xScale = hop.scaleX
        holder.yScale = squash * hop.scaleY
        holder.position = CGPoint(
            x: drift.width * pixel,
            y: (metrics.tileSize * (Self.cells(.piece(.pisces)) + 0.5) - sink
                - GameRules.piscesFishDrop * pixel
                + (charged ? GameRules.piscesFishLift * pixel : 0)
                - drift.height * pixel) * hop.scaleY
                + hop.lift * pixel
        )
        holder.zPosition = 1
    }

    /// Virgo's three gems.
    ///
    /// Ported from `PieceView.virgoGemLayer` rather than reconstructed, because
    /// every offset in it was placed by eye: a `GemCast` per facing says which
    /// three drawings, where each sits, which of them go behind her, and which
    /// orbit rather than merely bobbing. All of that comes from the cast and
    /// from `GameRules`, so nothing here is a number of mine.
    ///
    /// The pair swings across on one clock and the middle bobs on another. In
    /// profile the pair also swings in *depth*, which is the front gem passing
    /// nearer and further rather than left and right.
    private func syncGems(for standing: Piece) {
        guard standing.zodiac == .virgo else {
            for gem in virgoGems { gem.isHidden = true }
            return
        }

        while virgoGems.count < 3 {
            let node = SKSpriteNode()
            node.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            piece.addChild(node)
            virgoGems.append(node)
        }

        let facing = session.visibleFacing
        let pixel = metrics.scale
        let now = session.ambientClock(at: Date().timeIntervalSinceReferenceDate)
        let hop = session.hopPose(at: Date())

        let swing = now / GameRules.virgoGemPeriod * 2 * .pi
        let bob = now / GameRules.virgoGemFloatPeriod * 2 * .pi
        let dip = (1 - cos(swing)) / 2
        let across = sin(swing)
        let drop = (1 - cos(bob)) / 2

        let cast = PieceView.GemCast.wearing(facing)
        let mirrored = standing.zodiac != .gemini && facing == .right

        // The two outer gems, then the middle one.
        let outer: [(VirgoGem, Double, CGSize, Bool, Double?, Bool, CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (cast.back, -across, cast.backAt, false,
             cast.pairOrbits ? swing + (cast.pairInPhase ? 0 : .pi) : nil,
             cast.pairSwingsWide, cast.pairRise, 0, 0, cast.pairSwingX),
            (cast.front, across, cast.frontAt, cast.frontIsMirrored,
             cast.pairOrbits ? swing : nil,
             cast.pairSwingsWide, cast.pairRise,
             cast.frontDepthSwing, cast.frontDepthBack, cast.pairSwingX),
        ]

        for (index, one) in outer.enumerated() {
            let (gem, sway, place, flipped, orbit, wide, rise, deep, back, swingX) = one
            let node = virgoGems[index]

            let lifted = orbit.map { -sin($0) * rise * pixel }
            let sideways = orbit == nil || wide ? CGFloat(sway) * swingX * pixel : 0
            let depth = orbit.map { turn -> CGFloat in
                let span = (deep + back) / 2
                let centre = (back - deep) / 2
                return (-CGFloat(cos(turn)) * span + centre) * pixel
            } ?? 0

            let grow = 1 + CGFloat(dip) * GameRules.virgoGemFloatGrowth

            node.isHidden = false
            node.texture = Self.art(.virgoGem(gem))
            node.size = CGSize(width: metrics.tileSize, height: metrics.tileSize)
            node.xScale = (flipped ? -1 : 1) * (mirrored ? -1 : 1) * grow * hop.scaleX
            node.yScale = grow * hop.scaleY
            node.position = CGPoint(
                x: ((sideways + depth + place.width * pixel) * (mirrored ? -1 : 1)),
                y: ((lifted ?? CGFloat(dip) * GameRules.virgoGemSwingY * pixel)
                    - place.height * pixel
                    + metrics.tileSize * 1.5) * hop.scaleY
                    + hop.lift * pixel
            )
            node.zPosition = (index == 0 ? cast.backBehind : cast.frontBehind)
                ? -5 : 1
        }

        let middle = virgoGems[2]
        let orbits = cast.middleOrbits
        let size: CGFloat = orbits
            ? GameRules.virgoGemOrbitFar
                + (1 - GameRules.virgoGemOrbitFar) * CGFloat(1 + cos(swing)) / 2
            : 1 + CGFloat(drop) * GameRules.virgoGemFloatGrowth
        let lifted: CGFloat = orbits
            ? -CGFloat(sin(swing)) * GameRules.virgoGemMiddleRise * pixel
            : CGFloat(drop) * GameRules.virgoGemFloat * pixel

        middle.isHidden = false
        middle.texture = Self.art(.virgoGem(cast.middle))
        middle.size = CGSize(width: metrics.tileSize, height: metrics.tileSize)
        middle.xScale = size * (mirrored ? -1 : 1) * hop.scaleX
        middle.yScale = size * hop.scaleY
        middle.position = CGPoint(
            x: cast.middleAt.width * pixel * (mirrored ? -1 : 1),
            y: (lifted - cast.middleAt.height * pixel
                + metrics.tileSize * 1.5) * hop.scaleY
                + hop.lift * pixel
        )
        middle.zPosition = cast.middleBehind ? -5 : 1
    }

    /// The arrow Sagittarius carries.
    ///
    /// **Not the one he looses** — that is `syncArrow`, and mistaking the two
    /// is why this went missing. This is a piece attachment like Libra's scales
    /// and Pisces' fish: it rests on the top cell of his frame, mirrors when he
    /// faces east, and while the meter is full it rises and falls on its own
    /// slow breath.
    private func syncQuiver() {
        let standing = session.engine.piece

        guard standing.zodiac == .sagittarius else {
            quiver?.isHidden = true
            return
        }

        let node = quiver ?? {
            let made = SKSpriteNode()
            made.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            made.zPosition = 1
            piece.addChild(made)
            quiver = made
            return made
        }()

        let facing = session.visibleFacing
        let pixel = metrics.scale
        let charged = session.isZodiactionCharged
        let now = session.ambientClock(at: Date().timeIntervalSinceReferenceDate)
        let hop = session.hopPose(at: Date())

        let rise = charged
            ? (1 - cos(now / GameRules.sagittariusArrowPeriod * 2 * .pi)) / 2
            : 0

        node.isHidden = false
        node.texture = Self.art(.sagittariusArrowRest(SpriteAxis(facing: facing)))
        node.size = CGSize(width: metrics.tileSize, height: metrics.tileSize)
        node.xScale = (facing == .right ? -1 : 1) * hop.scaleX
        node.yScale = hop.scaleY
        node.position = CGPoint(
            x: 0,
            y: (metrics.tileSize * 1.5
                + CGFloat(rise) * GameRules.sagittariusArrowFloat * pixel)
                * hop.scaleY
                + hop.lift * pixel
        )
    }

    /// Sagittarius' arrow, once it is loosed.
    ///
    /// It leaves from the square it was fired at and climbs off the top of the
    /// board, accelerating — the drawing is drawn on a diagonal, so it is
    /// turned back upright before it goes.
    private func syncArrow() {
        guard let shot = session.loosedArrow else {
            loosed?.isHidden = true
            return
        }

        let node = loosed ?? {
            let made = SKSpriteNode(texture: Self.art(.effect(.sagittariusArrow)))
            made.zPosition = Self.effects
            made.zRotation = GameRules.arrowArtRotation * .pi / 180
            addChild(made)
            loosed = made
            return made
        }()

        let progress = min(max(
            Date().timeIntervalSince(shot.start) / GameRules.arrowRiseDuration, 0
        ), 1)
        let eased = CGFloat(progress * progress)
        let inset = (side - metrics.boardSize) / 2
        let centre = metrics.center(of: shot.point)

        // Asked for each frame rather than once at birth: a texture that came
        // back nil the first time would otherwise stay nil for the run.
        node.isHidden = false
        node.texture = Self.art(.effect(.sagittariusArrow))
        node.size = CGSize(width: metrics.tileSize * 2, height: metrics.tileSize * 2)
        node.position = CGPoint(
            x: centre.x + inset,
            y: -CGFloat(World.row(of: shot.plane)) * side - inset
                - (centre.y - metrics.tileSize
                    - eased * (metrics.boardSize + metrics.tileSize * 2))
        )
    }

    /// The gems, lit and trailing, while the meter is full.
    ///
    /// `GemTrailView` is the reference. It is not a ghost of the piece: the
    /// shader masks everything except the element's *lit* gem colour, so what
    /// follows her is the stones and nothing else.
    ///
    /// **Every blur is baked.** The first pass hung each copy in an
    /// `SKEffectNode` running a Gaussian filter, which is seven full-screen
    /// convolutions a frame — and because each copy moves, none of them could
    /// be cached, so a charged piece cost about fifty frames a second. The
    /// radius never changes, so the blur is a property of the *drawing* rather
    /// than of the moment: cut once per sign and step, and what moves after
    /// that is a plain sprite.
    private func syncGems() {
        let standing = session.engine.piece
        let lit = session.isZodiactionCharged && !session.isFalling

        guard lit else {
            for gem in gems { gem.isHidden = true }
            return
        }

        while gems.count < GameRules.gemTrailCount {
            let step = gems.count
            let node = SKSpriteNode()
            node.anchorPoint = CGPoint(x: 0.5, y: 0)
            node.blendMode = .add
            node.alpha = pow(GameRules.gemTrailFalloff, Double(step + 1))
            addChild(node)
            gems.append(node)
        }

        let tall = Self.cells(.piece(standing.zodiac))

        for (step, node) in gems.enumerated() {
            node.isHidden = false
            node.texture = Self.gemBloom(standing.zodiac, step: step, scale: metrics.scale)

            // The bake is wider than the drawing, by the room the blur needed
            // to spread into — so it is drawn that much wider too, or the glow
            // comes back squeezed into the sprite it came from.
            let spread = Self.gemSpread(step: step, scale: metrics.scale)
            node.size = CGSize(
                width: metrics.tileSize + spread * 2,
                height: metrics.tileSize * tall + spread * 2
            )

            node.zPosition = piece.zPosition - CGFloat(step) - 2

            // Each eases toward the piece a little slower than the one before.
            let lag = CGFloat(1) / CGFloat(step + 2)
            let want = CGPoint(x: piece.position.x, y: piece.position.y - spread)
            if node.position == .zero {
                node.position = want
            } else {
                node.position.x += (want.x - node.position.x) * lag
                node.position.y += (want.y - node.position.y) * lag
            }
            node.setScale(piece.xScale)
        }
    }

    /// How far a step's blur reaches past the drawing, in points.
    private static func gemSpread(step: Int, scale: CGFloat) -> CGFloat {
        GameRules.gemTrailRadius * scale * (1 + CGFloat(step) * 0.45) * 3
    }

    /// One step of the trail, blurred once and kept.
    private static var gemBlooms: [String: SKTexture] = [:]

    private static func gemBloom(
        _ zodiac: Zodiac, step: Int, scale: CGFloat
    ) -> SKTexture? {
        let key = "\(zodiac.rawValue).\(step)"
        if let kept = gemBlooms[key] { return kept }
        guard let stones = gemsOnly(zodiac)?.cgImage() else { return nil }

        let spread = gemSpread(step: step, scale: scale)
        let radius = GameRules.gemTrailRadius * scale * (1 + CGFloat(step) * 0.45)

        let source = CIImage(cgImage: stones)
        guard let blur = CIFilter(name: "CIGaussianBlur", parameters: [
            kCIInputImageKey: source.clampedToExtent(),
            kCIInputRadiusKey: radius,
        ])?.outputImage else { return nil }

        let box = source.extent.insetBy(dx: -spread, dy: -spread)
        let context = CIContext(options: [.useSoftwareRenderer: false])
        guard let cut = context.createCGImage(blur, from: box) else { return nil }

        let texture = SKTexture(image: UIImage(cgImage: cut))
        gemBlooms[key] = texture
        return texture
    }

    /// The piece with everything but its lit gems taken out.
    ///
    /// Kept per sign: the swap and the mask are both fixed for a given element,
    /// so this is cut once and handed to every copy in the trail.
    private static var gemCuts: [Zodiac: SKTexture] = [:]

    private static func gemsOnly(_ zodiac: Zodiac) -> SKTexture? {
        if let kept = gemCuts[zodiac] { return kept }

        let gem = GemTones.forElement(zodiac.element)
        guard let art = PaletteRecolour.image(
            .piece(zodiac), frame: 0, swaps: [PaletteSwap(gem.dim, gem.lit)]
        ), let source = art.cgImage else { return nil }

        let wide = source.width, high = source.height
        var pixels = [UInt8](repeating: 0, count: wide * high * 4)
        guard let context = CGContext(
            data: &pixels, width: wide, height: high,
            bitsPerComponent: 8, bytesPerRow: wide * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.draw(source, in: CGRect(x: 0, y: 0, width: wide, height: high))

        // Keep only what the shader keeps: the lit gem colour itself.
        let want = UIColor(gem.lit)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        want.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        let target = (UInt8(red * 255), UInt8(green * 255), UInt8(blue * 255))

        for index in stride(from: 0, to: pixels.count, by: 4) {
            let near = abs(Int(pixels[index]) - Int(target.0)) < 12
                && abs(Int(pixels[index + 1]) - Int(target.1)) < 12
                && abs(Int(pixels[index + 2]) - Int(target.2)) < 12
            if !near { pixels[index + 3] = 0 }
        }

        guard let cut = context.makeImage() else { return nil }
        let texture = SKTexture(image: UIImage(cgImage: cut))
        texture.filteringMode = .nearest
        gemCuts[zodiac] = texture
        return texture
    }

    /// Libra's arms, the scales hanging from them, and the shadows they drop.
    ///
    /// `LibraPieceView` is the reference and its own documentation is the part
    /// that matters: **every offset is in art pixels measured from the body's
    /// bottom edge**, which works because the art was authored for it — an arm's
    /// lowest pixel sits at the same height in its cell as Libra's does in his.
    /// The scene's piece node *is* that bottom edge, so the numbers go in as
    /// they are written rather than being converted through a frame's middle.
    ///
    /// The hanging parts **take the hop's lift and decline its squash** — the
    /// view says so in as many words, and that is why they hung still while she
    /// hopped: they were children of the piece, which does not carry the lift,
    /// rather than of anything that does.
    ///
    /// Two drawings serve four directions. North is south from behind, so one
    /// arm drawing does both and the left is the right mirrored; in profile the
    /// far arm is the near one turned upside down. None of that depends on
    /// whether she faces east or west, so none of it takes the piece's own
    /// mirror either.
    ///
    /// Not yet here: the carriage — the swing that rocks the pans while she
    /// moves and rotates them about the horizontal — and the moss shading.
    private func syncScales() {
        let standing = session.engine.piece
        let facing = session.visibleFacing
        let profile = facing == .left || facing == .right
            || facing == .upLeft || facing == .upRight
            || facing == .downLeft || facing == .downRight

        guard standing.zodiac == .libra else {
            for part in limbs { part.isHidden = true }
            return
        }

        while limbs.count < 6 {
            let part = SKSpriteNode()
            part.anchorPoint = CGPoint(x: 0.5, y: 0)
            piece.addChild(part)
            limbs.append(part)
        }

        let pixel = metrics.scale
        let charged = session.isZodiactionCharged
        let hop = session.hopPose(at: Date()).lift * pixel
        let breath = CGFloat(sin(
            session.ambientClock(at: Date().timeIntervalSinceReferenceDate)
                / GameRules.libraArmSwayPeriod * 2 * .pi
        )) * GameRules.libraArmSway

        // The two sides: far and near in profile, left and right facing the
        // camera. The first of each pair leads — it is the one behind.
        for slot in 0..<6 {
            let part = limbs[slot]
            let back = slot % 2 == 0
            let kind = slot / 2                     // 0 arm, 1 pan, 2 shadow
            let sway = back ? -breath : breath

            let lift: CGFloat = profile
                ? (back ? GameRules.libraArmLiftEWBack : GameRules.libraArmLiftEW)
                : GameRules.libraArmLiftNS
            let gap: CGFloat = profile
                ? (back ? GameRules.libraScalesGapEWBack : GameRules.libraScalesGapEW)
                : GameRules.libraScalesGapNS

            // Sideways: nothing in profile, where the two arms stack in depth
            // rather than spreading — which is the view's own reason for the
            // insets being zero there.
            let arm = profile ? 0 : (back ? 1 : -1) * GameRules.libraArmInsetNS
            let outward = arm + (profile ? 0 : (back ? 1 : -1) * GameRules.libraScalesInsetX)

            part.isHidden = false

            if kind == 2 {
                // **It stays on the ground while the pan leaves it.** Which is
                // the whole point of drawing one: the shadow is what says the
                // pan is above the tile rather than painted on it, so it takes
                // neither the hop nor the lift the island gives — both of which
                // reach it through the piece, and both of which come back off
                // here. Reverse-inheriting the island's carry is what keeps it
                // on the rock she is standing on.
                //
                // And it shrinks by how far the pan has gone, the way a coin's
                // does: near the ground it is full size, and it draws in as the
                // pan rises away from it.
                let flank: CGFloat = back ? -1 : 1
                let raised = hop / pixel + perch / pixel - sway
                let shrink = 1 - min(max(raised / GameRules.libraPanShadowLiftRange, 0), 1)
                    * GameRules.libraPanShadowSpread

                part.texture = Self.shadowTexture
                part.anchorPoint = CGPoint(
                    x: 0.5,
                    y: GameRules.shadowSpriteSeat / CGFloat(GameRules.tilePixelSize)
                )
                // The piece's own drawing, three quarters the size — a pan is
                // smaller than she is.
                let mark = metrics.tileSize * GameRules.libraPanShadowSize
                part.size = CGSize(width: mark, height: mark)
                part.setScale(shrink)
                part.alpha = GameRules.shadowSpriteOpacity
                // Half a tile up from the body's bottom edge: the view offsets
                // it from the middle of a two-cell frame, and the difference
                // between that middle and this edge is a whole cell — of which
                // the drop and the flank rise then take their share back.
                part.position = CGPoint(
                    x: profile ? 0 : flank * metrics.tileSize,
                    y: metrics.tileSize / 2 - perch
                        + GameRules.libraPanShadowRise * pixel
                        - GameRules.pieceShadowDrop * pixel
                        - (profile
                            ? flank * metrics.tileSize * GameRules.libraPanShadowFlankRise
                            : 0)
                )
                // **On the square it falls on, in front of that square's tile.**
                // In profile the two shadows land a row apart — the far one
                // behind her and the near one in front — and the near one was
                // being buried by the tile of the row it had been pushed onto.
                part.zPosition = profile ? (back ? -8 : 9) : -4
                continue
            }

            let isPan = kind == 1
            part.anchorPoint = CGPoint(x: 0.5, y: 0)
            part.alpha = 1
            part.setScale(1)
            part.size = CGSize(width: metrics.tileSize, height: metrics.tileSize)

            // Straight off the body's bottom edge, in art pixels, exactly as
            // the view writes them.
            // Hung by eye on top of the drawing's own numbers: the pans come
            // up facing the camera, and in profile the two part company — the
            // front one up, the back one down, and the back arm with it.
            let nudge: CGFloat = isPan
                ? (profile
                    ? (back ? GameRules.libraPanRiseEWBack : GameRules.libraPanRiseEWFront)
                    : GameRules.libraPanRiseNS)
                : (profile && back ? GameRules.libraArmDropEWBack : 0)

            part.position = CGPoint(
                x: (isPan ? outward : arm) * pixel,
                y: (lift + nudge - sway
                    - (isPan ? GameRules.libraArmFootInCell + gap : 0)) * pixel
                    + hop
            )

            // **They squash with her.** The body is scaled about its feet as
            // she lands, and parts that hang at fixed heights while it does are
            // arms left floating over a shoulder that has dropped away from
            // them. Their heights and their own drawings take the same scale,
            // which closes the gap because it is the same movement.
            let squish = session.hopPose(at: Date())
            part.position.x *= squish.scaleX
            part.position.y *= squish.scaleY

            part.xScale = (!profile && back ? -1 : 1) * squish.scaleX

            // Turned over about its own box, not about its foot: the view flips
            // the far arm about its centre so it keeps the space it had, where
            // flipping about a bottom anchor hangs it below instead.
            let over = !isPan && profile && back
            part.yScale = (over ? -1 : 1) * squish.scaleY
            if over { part.position.y += metrics.tileSize * squish.scaleY }

            // Behind her or in front, and in profile the near pan sorts a whole
            // row ahead — it hangs out over the square in front, and drawn with
            // the rest of her that square's tile buried it.
            // In profile the far pan hangs behind its own arm and both behind
            // her; the near arm is in front and the near pan a whole row ahead,
            // since it overhangs the square in front. Facing the camera both
            // arms are behind and both pans in front. Minus one is spoken for
            // by her own shadow.
            part.zPosition = profile
                ? (back ? (isPan ? -3 : -2) : (isPan ? 10 : 1))
                : (isPan ? 1 : -2)

            if isPan, charged {
                if part.action(forKey: "weigh") == nil {
                    let frames = (0..<3).compactMap { frame in
                        PaletteRecolour.image(.libraScales, frame: frame, swaps: [])
                            .map { art -> SKTexture in
                                let texture = SKTexture(image: art)
                                texture.filteringMode = .nearest
                                return texture
                            }
                    }
                    if frames.count > 1 {
                        part.run(.repeatForever(.animate(
                            with: frames,
                            timePerFrame: SpriteSheetLoader.frameDuration(for: .libraScales),
                            resize: false, restore: false
                        )), withKey: "weigh")
                    }
                }
            } else if isPan {
                part.removeAction(forKey: "weigh")
                part.texture = Self.art(.libraScalesPlain)
            } else {
                part.texture = Self.art(.libraArm(profile ? .eastWest : .northSouth))
            }
        }
    }

    /// The other half of a split sign, waiting on its own square.
    ///
    /// Gemini leaves one behind; anything else that splits leaves a cropped
    /// copy of itself. `SplitHalfView` decides which by whether the sign has
    /// halves drawn for it, and this asks the same question.
    private func syncHalf() {
        guard let half = session.otherHalf else {
            twin?.isHidden = true
            return
        }

        let id: SpriteID = half.zodiac.hasOwnHalves && half.twin != nil
            ? .geminiHalf(half.twin!)
            : .piece(half.zodiac)

        let node = twin ?? {
            let made = SKSpriteNode()
            addChild(made)
            twin = made
            return made
        }()

        node.isHidden = false
        node.texture = Self.art(id)

        // Seated like the piece: a half stands on its square the same way a
        // whole one does, feet on the tile rather than centred in it.
        let spot = metrics.projected(half.point, on: half.plane)
        let drop = metrics.tileSize / 2 - GameRules.pieceLift * metrics.scale
        place(node, at: half.point, on: half.plane,
              tiles: CGSize(width: 1, height: 2), layer: 5)
        node.position.y -= drop * spot.scale
    }

    /// Virgo's retinue: the followers walking the squares behind the piece.
    ///
    /// Each keeps its own place in the line, so one added or lost does not
    /// shuffle the rest along — the engine already answers which square a given
    /// step stands on.
    private func syncRetinue(on plane: Plane) {
        let walking = session.retinue

        while retinue.count > walking.count {
            retinue.removeLast().removeFromParent()
        }
        while retinue.count < walking.count {
            let node = SKSpriteNode()
            let cast = SKSpriteNode(texture: Self.shadowTexture)
            cast.size = CGSize(width: metrics.tileSize, height: metrics.tileSize)
            cast.anchorPoint = CGPoint(
                x: 0.5, y: GameRules.shadowSpriteSeat / CGFloat(GameRules.tilePixelSize)
            )
            cast.alpha = GameRules.retinueShadowOpacity
            cast.zPosition = -1
            node.addChild(cast)
            addChild(node)
            retinue.append(node)
        }

        let drop = metrics.tileSize / 2 - GameRules.pieceLift * metrics.scale

        for (step, follower) in walking.enumerated() {
            let node = retinue[step]
            let point = session.engine.retinueSquare(step: step)
            node.texture = Self.art(.piece(follower))
            node.size = CGSize(width: metrics.tileSize, height: metrics.tileSize * 2)

            let spot = metrics.projected(point, on: plane)
            place(node, at: point, on: plane,
                  tiles: CGSize(width: 1, height: 2), layer: 4)
            node.position.y -= drop * spot.scale
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

    /// A sprite's texture, cut once and kept.
    ///
    /// Cheap to call every frame: the atlas hands back the same image, and the
    /// cache means the same `SKTexture` too, so a sprite that changes with the
    /// game's state can simply ask each frame rather than being told.
    private static var cut: [SpriteID: SKTexture] = [:]

    /// How many cells tall a drawing is, asked of the atlas rather than assumed.
    ///
    /// **Pisces is one cell.** His body was redrawn short — it sits on the
    /// bottom cell of his block so his feet line up with everyone else's, and
    /// his top half became the fish. Every other sign is two, and a piece drawn
    /// at two that is one comes out stretched to twice its height.
    private static func cells(_ id: SpriteID) -> CGFloat {
        guard let slice = SpriteAtlas.slice(for: id) else { return 2 }
        return CGFloat(slice.height) / CGFloat(GameRules.tilePixelSize)
    }

    private static func art(_ id: SpriteID) -> SKTexture? {
        if let kept = cut[id] { return kept }
        guard let image = PaletteRecolour.image(id, frame: 0, swaps: [])
        else { return nil }
        let texture = SKTexture(image: image)
        texture.filteringMode = .nearest
        cut[id] = texture
        return texture
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
        // **Measured over the span the node covers, not over the world.** The
        // sky reaches a row past each end so the wrap has nothing to show, and
        // a gradient measured over nine rows but drawn across eleven is a sky
        // stretched by two — its daylight landing a row off the plane it
        // belongs to.
        let rows = Double(World.rows + 2)
        let terra = Double(World.row(of: .terra) + 1)
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

            // **A hole where the underground is.** That row belongs to
            // `DeathView`, which is still a view and sits behind the scene, so
            // the sky has to stop rather than paint over it. Clearing here is
            // what lets the piece draw *above* the game over card — which it
            // could not while the card was an overlay on the whole scene, and
            // which is how the world column always had it.
            let deep = CGFloat(World.underground + 1) / CGFloat(rows)
            context.cgContext.setBlendMode(.clear)
            context.cgContext.fill(CGRect(
                x: 0,
                y: deep * size.height,
                width: size.width,
                height: size.height / CGFloat(rows)
            ))
        }
    }
}
