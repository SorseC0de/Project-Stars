//
//  BoardSceneView.swift
//  Project Stars
//
//  The scene, hosted.
//

import SpriteKit
import SwiftUI

/// The top screen, drawn by SpriteKit.
///
/// **The scene is built once and held.** A scene constructed inside `body` is a
/// new scene every time the body runs — and this body runs whenever the session
/// publishes, which is the whole problem it exists to solve. Built that way,
/// SpriteKit measured slower than the canvas it was meant to replace.
///
/// Nothing feeds it. `BoardScene.update(_:)` reads the session on SpriteKit's
/// own loop, outside any view body, so no observation is registered and no
/// invalidation happens. This view exists only to put the scene on screen.
struct BoardSceneView: View {

    let session: GameSession
    let side: CGFloat

    @State private var scene: BoardScene?

    /// The game over card.
    ///
    /// **Left in SwiftUI while the room around it moved into the scene.** The
    /// room has to be a row of the world so that falling into it is the camera
    /// travelling and nothing else; the card does not, because it is centred on
    /// the screen rather than on a row. Keeping it here also keeps its entrance
    /// and its exit — a splash view already knows how to arrive and leave, and
    /// there is nothing to be gained by teaching a scene the same thing.
    @ViewBuilder
    private var card: some View {
        if session.phase == .gameOver || session.deathCardIsLeaving {
            GameModeSplashView(
                title: DeathStyle.title,
                subtitle: session.engine.gameOverReason?.displayText ?? "",
                ink: Palette.red,
                titleDrop: DeathStyle.titleDrop,
                blurbDrop: DeathStyle.blurbDrop,
                isLeaving: session.deathCardIsLeaving,
                onLanded: {},
                onFinished: {}
            )
        }
    }

    var body: some View {
        Group {
            if let scene {
                SpriteView(scene: scene, options: [.allowsTransparency])
            } else {
                Palette.coolBlack
            }
        }
        .frame(width: side, height: side)
        .overlay { card }
        .allowsHitTesting(false)
        .onAppear {
            if scene == nil { scene = BoardScene(session: session, side: side) }
        }
    }
}
