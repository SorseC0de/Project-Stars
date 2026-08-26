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

    private unowned let session: GameSession
    private let metrics: PixelArtMetrics
    private let side: CGFloat

    /// One container per plane, parked at its row in the column.
    private var planes: [Plane: SKNode] = [:]
    private var piece = SKSpriteNode()
    private let follow = SKCameraNode()

    /// What the piece was last drawn wearing, so the texture is only rebuilt
    /// when it actually changes rather than every frame.
    private var wearing: SpriteID?

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
    }

    // MARK: - Building, once

    /// The column's sky: one gradient the height of the world.
    ///
    /// A texture rather than nine stacked nodes — it is one image, generated
    /// once, and SpriteKit will not touch it again.
    private func addSky() {
        let height = side * CGFloat(World.rows)
        let sky = SKSpriteNode(
            texture: SKTexture(image: Self.skyImage(width: side, height: height)),
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

        let board = session.engine[plane]
        let inset = (side - metrics.boardSize) / 2

        for point in board.allPoints {
            guard let node = ground(at: point, on: plane, board: board) else { continue }
            node.position.x += inset
            node.position.y -= inset
            holder.addChild(node)
        }
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

    private func addPiece() {
        piece.anchorPoint = CGPoint(x: 0.5, y: 0)
        piece.zPosition = 500
        addChild(piece)
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

        let standing = session.engine.piece
        let id = SpriteID.pieceFacing(standing.zodiac, session.visibleFacing)
        if id != wearing, let art = PaletteRecolour.image(id, frame: 0, swaps: []) {
            let texture = SKTexture(image: art)
            texture.filteringMode = .nearest
            piece.texture = texture
            piece.size = CGSize(width: metrics.tileSize, height: metrics.tileSize * 2)
            wearing = id
        }

        let spot = metrics.projected(standing.point)
        let inset = (side - metrics.boardSize) / 2
        piece.position = CGPoint(
            x: spot.position.x + inset,
            y: -CGFloat(World.row(of: standing.plane)) * side
                - spot.position.y - inset - metrics.tileSize / 2
        )
        piece.setScale(spot.scale)
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

    /// The sky, drawn once into an image.
    ///
    /// The same three stops the column's gradient uses — dark, daylight where
    /// Terra sits, dark again — so the two are the same sky and not two
    /// opinions about one.
    private static func skyImage(width: CGFloat, height: CGFloat) -> UIImage {
        let rows = Double(World.rows)
        let terra = Double(World.row(of: .terra))
        let stops: [(CGFloat, UIColor)] = [
            (0, UIColor(Palette.coolBlack)),
            (CGFloat((terra - WorldSky.dawn) / rows), UIColor(Palette.coolBlack)),
            (CGFloat((terra + 0.5) / rows), UIColor(Palette.cyan)),
            (CGFloat((terra + 1 + WorldSky.dusk) / rows), UIColor(Palette.coolBlack)),
            (1, UIColor(Palette.coolBlack)),
        ]

        let size = CGSize(width: width, height: height)
        return UIGraphicsImageRenderer(size: size).image { context in
            let space = CGColorSpaceCreateDeviceRGB()
            guard let gradient = CGGradient(
                colorsSpace: space,
                colors: stops.map(\.1.cgColor) as CFArray,
                locations: stops.map(\.0)
            ) else { return }

            context.cgContext.drawLinearGradient(
                gradient,
                start: .zero,
                end: CGPoint(x: 0, y: height),
                options: []
            )
        }
    }
}
