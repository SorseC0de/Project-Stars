//
//  CloudScene.swift
//  Project Stars
//
//  Astra's clouds, as a retained scene instead of a redrawn one.
//

import SpriteKit
import SwiftUI

/// The forty-nine clouds, built once and left alone.
///
/// ## Why this exists
///
/// `CloudSpriteField` draws the same clouds by recomputing every one of them
/// into a `Canvas`, thirty times a second, for ever. That is immediate mode: the
/// picture is thrown away and made again each tick, and the cost is the whole
/// field however little of it moved.
///
/// A scene is retained. Each cloud is a node that exists; drifting it is an
/// `SKAction` the render thread interpolates, and the CPU does nothing per frame
/// at all. Textures come from the same atlas already in the project and batch
/// into a handful of draw calls rather than forty-nine.
///
/// ## What this is not, yet
///
/// A proof. It draws the board it was handed at the moment it was built, drifts
/// them, and stops there — no wake, no dip, no wear as tiles break, no promotion
/// of the square a Pentacle is standing on. Those are all straightforward to add
/// and none of them changes the shape of the answer, which is whether a retained
/// scene costs meaningfully less than a redrawn one.
///
/// Measure it against `CloudSpriteField` with the layer bench's `spritekit`
/// toggle and read `late`.
@MainActor
final class CloudScene: SKScene {

    private let board: Board
    private let metrics: PixelArtMetrics

    init(board: Board, metrics: PixelArtMetrics) {
        self.board = board
        self.metrics = metrics
        super.init(size: CGSize(width: metrics.boardSize, height: metrics.boardSize))

        scaleMode = .aspectFit
        backgroundColor = .clear
        // SpriteKit measures up from the bottom left; the board measures down
        // from the top. Anchoring at the top left and negating y lets every
        // position below be the board's own, unconverted.
        anchorPoint = CGPoint(x: 0, y: 1)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not from a nib") }

    override func didMove(to view: SKView) {
        guard children.isEmpty else { return }
        for point in board.allPoints { add(point) }
    }

    /// One cloud, placed where the floor says and set drifting.
    private func add(_ point: GridPoint) {
        let tile = board[point]
        guard tile.kind == .normal, !tile.health.isHole else { return }

        let shade = Palette.TileShade.at(point)
        guard let art = PaletteRecolour.image(
            .astraCloud(shade),
            frame: 0,
            swaps: GameRules.cloudWearSwaps(tile.health, shade: shade)
        ) else { return }

        let texture = SKTexture(image: art)
        // Pixel art is resized by repeating pixels, never by blending them.
        texture.filteringMode = .nearest

        let spot = metrics.projected(
            point,
            zoom: GameRules.astraForeshortenScale,
            lift: GameRules.astraForeshortenLift,
            emphasis: GameRules.astraDepthEmphasis,
            pivot: GameRules.astraDepthPivot,
            spacing: CGSize(
                width: GameRules.cloudSpacingX,
                height: GameRules.cloudSpacingY
            )
        )

        let side = metrics.tileSize
            * CGFloat(GameRules.cloudSpritePixelSize) / CGFloat(GameRules.tilePixelSize)
            * GameRules.cloudSpriteScale
            * GameRules.cloudBaseSize
            * GameRules.cloudScale(tile.health)
            * spot.scale

        let node = SKSpriteNode(texture: texture, size: CGSize(width: side, height: side))
        node.position = CGPoint(
            x: spot.position.x,
            y: -(spot.position.y
                 - GameRules.astraCloudLift * metrics.scale
                 + GameRules.cloudSpriteDrop * metrics.scale)
        )
        // The board's own painter's order: further down the screen is nearer.
        node.zPosition = CGFloat(point.y)

        node.run(drift(seed: point.x * 7 + point.y * 13))
        addChild(node)
    }

    /// The ambient wander, as an action rather than a recomputation.
    ///
    /// Committed once. The render thread interpolates it for the life of the
    /// scene and nothing on the CPU is woken for it — which is the whole
    /// difference being measured.
    private func drift(seed: Int) -> SKAction {
        let reach = GameRules.cloudSpriteShift * metrics.scale
        let period = GameRules.cloudSpriteShiftPeriod

        // A phase per cloud, so the field breathes rather than pulsing as one.
        let phase = Double(seed % 17) / 17 * period

        let out = SKAction.moveBy(x: reach, y: reach * 0.6, duration: period / 2)
        let back = SKAction.moveBy(x: -reach, y: -reach * 0.6, duration: period / 2)
        out.timingMode = .easeInEaseOut
        back.timingMode = .easeInEaseOut

        return .sequence([
            .wait(forDuration: phase),
            .repeatForever(.sequence([out, back])),
        ])
    }
}

/// The scene, in the view tree.
///
/// **Built once and held.** A scene constructed inside `body` is a *new* scene
/// every time the body runs — and the board's body runs on every publish of a
/// move, roughly twenty-four times a second. That allocates a scene, rebuilds
/// forty-nine nodes and re-uploads forty-nine textures, which is the exact
/// opposite of what retaining a scene is for. Measured that way, SpriteKit came
/// out slower than the canvas it was meant to beat.
///
/// Transparent, so the column's sky shows through it exactly as it does behind
/// the canvas version.
struct CloudSceneView: View {

    let board: Board
    let metrics: PixelArtMetrics

    @State private var scene: CloudScene?

    var body: some View {
        Group {
            if let scene {
                SpriteView(scene: scene, options: [.allowsTransparency])
            } else {
                Color.clear
            }
        }
        .frame(width: metrics.boardSize, height: metrics.boardSize)
        .allowsHitTesting(false)
        .onAppear {
            // Once. Not on every board size change either — a resize would want
            // a rebuild, but this is a proof and the board does not resize.
            if scene == nil {
                scene = CloudScene(board: board, metrics: metrics)
            }
        }
    }
}
