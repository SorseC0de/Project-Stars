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

    var body: some View {
        ZStack {
            // **Behind the scene, not over it.** The underground is
            // `DeathView`'s row and always was — gradient, streaks and card,
            // all of it already tuned — so it stays a view rather than being
            // rebuilt as nodes. The scene's sky is cleared at that row, which
            // is what lets this show through, and what puts the piece *above*
            // the card the way the world column always did.
            DeathView(session: session)

            if let scene {
                SpriteView(scene: scene, options: [.allowsTransparency])
            } else {
                Palette.coolBlack
            }
        }
        .frame(width: side, height: side)
        .allowsHitTesting(false)
        .onAppear {
            if scene == nil { scene = BoardScene(session: session, side: side) }
        }
    }
}
