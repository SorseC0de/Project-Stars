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
    private var piece = SKNode()
    private var figure = SKSpriteNode()
    private var cursor = SKSpriteNode()
    /// The coins on the board, by the square they are standing on.
    ///
    /// Kept rather than rebuilt: a coin that has not moved is a node that does
    /// not need touching, and the hunt puts one down and takes it away perhaps
    /// twice a minute.
    private var coins: [GridPoint: SKSpriteNode] = [:]

    private var island = SKSpriteNode()
    private var pillar = SKSpriteNode()
    private let follow = SKCameraNode()

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
        rebuild(plane)
    }

    /// This plane's ground, from scratch.
    ///
    /// Called when the board it was built from stops matching — a tile worn, a
    /// hole opened, a plane restored. Everything else moves; only this is ever
    /// remade, and only when the squares themselves changed.
    private func rebuild(_ plane: Plane) {
        guard let holder = planes[plane] else { return }
        holder.removeAllChildren()

        let board = session.engine[plane]
        let inset = (side - metrics.boardSize) / 2

        if plane == .terra {
            for row in 0..<board.size {
                guard let node = terraRow(row, board: board) else { continue }
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
    }

    /// One row of Terra: seven tiles in a single sprite, warped into its band.
    ///
    /// **A row, not seven squares.** Terra's ground is a keystone — each band's
    /// top edge narrower than its bottom — and squares placed individually
    /// inside one open seams, which is the whole reason the SwiftUI board draws
    /// rows rather than tiles. `SKWarpGeometryGrid` is the same trapezoid: the
    /// bottom corners stay and the top two come in by `1 / (1 + lean)`, which is
    /// exactly what the projective transform in `Foreshortened` works out to.
    private func terraRow(_ row: Int, board: Board) -> SKSpriteNode? {
        guard let strip = Self.rowImage(row, board: board, metrics: metrics) else {
            return nil
        }

        let texture = SKTexture(image: strip)
        texture.filteringMode = .nearest

        let band = BoardBand.at(row: row, metrics: metrics)
        let node = SKSpriteNode(
            texture: texture,
            size: CGSize(width: metrics.boardSize, height: metrics.tileSize)
        )
        node.anchorPoint = CGPoint(x: 0.5, y: 0)

        // The keystone. Normalised, origin bottom-left; the top edge is pulled
        // in and down by the same divisor the perspective applies.
        let pinch = 1 / (1 + band.lean)
        let source: [SIMD2<Float>] = [
            .init(0, 0), .init(1, 0), .init(0, 1), .init(1, 1),
        ]
        let destination: [SIMD2<Float>] = [
            .init(0, 0),
            .init(1, 0),
            .init(Float(0.5 - 0.5 * pinch), Float(pinch)),
            .init(Float(0.5 + 0.5 * pinch), Float(pinch)),
        ]
        node.warpGeometry = SKWarpGeometryGrid(
            __columns: 1, rows: 1,
            sourcePositions: source,
            destPositions: destination
        )

        node.xScale = band.scale
        node.yScale = band.groundScale
        node.position = CGPoint(
            x: metrics.boardSize / 2,
            y: -(band.groundCentreY + metrics.tileSize / 2)
        )
        node.zPosition = CGFloat(row)
        return node
    }

    /// A row's seven tiles, composited into one strip.
    private static func rowImage(
        _ row: Int,
        board: Board,
        metrics: PixelArtMetrics
    ) -> UIImage? {
        let size = CGSize(width: metrics.boardSize, height: metrics.tileSize)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1

        var drewAnything = false
        let strip = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            for column in 0..<board.size {
                let point = GridPoint(column, row)
                let tile = board[point]
                guard tile.kind == .normal, !tile.health.isHole else { continue }
                guard let art = PaletteRecolour.image(
                    .tileFace(.terra, .at(point), popped: false),
                    frame: 0,
                    swaps: []
                ) else { continue }

                drewAnything = true
                art.draw(in: CGRect(
                    x: CGFloat(column) * metrics.tileSize,
                    y: 0,
                    width: metrics.tileSize,
                    height: metrics.tileSize
                ))
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

        let spot = plane == .astra
            ? metrics.projected(
                point,
                zoom: GameRules.astraForeshortenScale,
                lift: GameRules.astraForeshortenLift,
                emphasis: GameRules.astraDepthEmphasis,
                pivot: GameRules.astraDepthPivot,
                spacing: CGSize(width: GameRules.cloudSpacingX,
                                height: GameRules.cloudSpacingY)
            )
            : metrics.projected(point)

        let span = plane == .astra
            ? metrics.tileSize
                * CGFloat(GameRules.cloudSpritePixelSize) / CGFloat(GameRules.tilePixelSize)
                * GameRules.cloudSpriteScale * GameRules.cloudBaseSize
            : metrics.tileSize

        let node = SKSpriteNode(
            texture: texture,
            size: CGSize(width: span * spot.scale, height: span * spot.scale)
        )
        node.position = CGPoint(x: spot.position.x, y: -spot.position.y)
        node.zPosition = CGFloat(point.y)

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
        addChild(piece)

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
            node.size = CGSize(
                width: art.size.width * metrics.scale,
                height: art.size.height * metrics.scale
            )
            addChild(node)
        }
        pillar.isHidden = !NexysStyle.foreshortened
    }

    // MARK: - The loop

    /// Called by SpriteKit, on its own clock.
    ///
    /// **This is the whole update.** It reads the session outside any view body,
    /// so nothing is observed and nothing is invalidated, and it writes two
    /// positions. Whatever else changed this frame, this is what it costs.
    override func update(_ currentTime: TimeInterval) {
        follow.position = CGPoint(
            x: side / 2,
            y: -session.cameraRow * side - side / 2
        )

        // Only when the squares themselves changed — see `built`.
        for plane in Plane.allCases where built[plane] != session.engine[plane] {
            rebuild(plane)
        }

        let standing = session.engine.piece
        let id = SpriteID.pieceFacing(standing.zodiac, session.visibleFacing)
        if id != wearing, let art = PaletteRecolour.image(id, frame: 0, swaps: []) {
            let texture = SKTexture(image: art)
            texture.filteringMode = .nearest
            figure.texture = texture
            figure.size = CGSize(width: metrics.tileSize, height: metrics.tileSize * 2)
            wearing = id
        }

        let inset = (side - metrics.boardSize) / 2
        let spot = metrics.projected(standing.point)
        let seat = CGPoint(
            x: spot.position.x + inset,
            y: -CGFloat(World.row(of: standing.plane)) * side
                - spot.position.y - inset - metrics.tileSize / 2
        )

        // **Sent, not set.** Only when the square actually changed, and as an
        // action the render thread carries out — which is the whole point:
        // travelling costs one instruction, not a position written every frame.
        if standing.point != sentTo || standing.plane != sentOn {
            sentTo = standing.point
            sentOn = standing.plane

            piece.removeAction(forKey: "step")
            let span = session.movement?.duration ?? GameRules.hopDuration
            if span > 0, piece.parent != nil, sentTo != nil {
                let go = SKAction.move(to: seat, duration: span)
                go.timingMode = SKActionTimingMode.easeInEaseOut
                piece.run(go, withKey: "step")
                piece.run(.scale(to: spot.scale, duration: span))
            } else {
                piece.position = seat
                piece.setScale(spot.scale)
            }
        } else if piece.action(forKey: "step") == nil {
            // Standing still, or carried by the camera: keep it seated.
            piece.position = seat
            piece.setScale(spot.scale)
        }

        // **The hop, the squash and the bob, from the same clock the board
        // uses.** `HopPose` is already a pure function of elapsed time — it was
        // written that way so an animation could not leave it stuck part-way —
        // which means a scene can read it exactly as a view did.
        let hop = session.hopPose(at: Date())
        figure.position.y = hop.lift * metrics.scale
        figure.xScale = hop.scaleX
        figure.yScale = hop.scaleY

        // The cursor, on the square the next move would land on.
        let aim = session.engine.cursor(
            direction: session.previewDirection,
            reach: session.previewReach
        )
        let mark = metrics.projected(aim.point)
        cursor.position = CGPoint(
            x: mark.position.x + inset,
            y: -CGFloat(World.row(of: standing.plane)) * side - mark.position.y - inset
        )
        cursor.setScale(mark.scale)
        cursor.color = UIColor(Self.tint(for: aim.status))

        // The island, on whichever plane it is currently part of.
        let home = session.engine.nexysPlane
        let perch = metrics.projected(GameRules.nexysPoint)
        let base = CGPoint(
            x: perch.position.x + inset,
            y: -CGFloat(World.row(of: home)) * side - perch.position.y - inset
        )
        for node in [island, pillar] {
            node.position = base
            node.setScale(perch.scale)
            // Behind the piece, and the pillar in front of it: the piece stands
            // between the two halves of the same rock.
            node.zPosition = node === pillar ? 600 : 300
        }

        syncCoins(on: standing.plane, inset: inset)
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
            node.removeFromParent()
            coins[point] = nil
        }

        for pickup in wanted where coins[pickup.point] == nil {
            let look = PickupCatalog.effect(for: pickup.id).appearance(on: plane)
            guard let art = PaletteRecolour.image(
                .pentacle(look), frame: 0, swaps: []
            ) else { continue }

            let texture = SKTexture(image: art)
            texture.filteringMode = .nearest

            let node = SKSpriteNode(texture: texture)
            node.size = CGSize(
                width: art.size.width * metrics.scale,
                height: art.size.height * metrics.scale
            )
            node.zPosition = 450
            addChild(node)
            coins[pickup.point] = node
        }

        for (point, node) in coins {
            let spot = metrics.projected(point)
            node.position = CGPoint(
                x: spot.position.x + inset,
                y: -CGFloat(World.row(of: plane)) * side - spot.position.y - inset
            )
            node.setScale(spot.scale)
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
