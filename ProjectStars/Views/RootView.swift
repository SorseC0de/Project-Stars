//
//  RootView.swift
//  Project Stars
//
//  App-level flow: choose a sign, then play it.
//

import SwiftUI

/// Switches between piece selection and a run.
///
/// The sign is chosen before a run and fixed for its duration, so the two are
/// separate screens rather than one screen with a picker. Ending a run returns
/// here, which is the only ordinary way to change sign.
struct RootView: View {

    /// Which screen is up.
    private enum Stage: Equatable {
        case choosingPiece
        case playing(Zodiac)
    }

    /// Straight into a run in debug builds, on `GameRules.debugStartingSign`.
    ///
    /// Pre-selecting the sign in the picker was not enough — it still cost the
    /// tap on BEGIN and looked identical to not having changed anything, which
    /// is how it went unnoticed. Skipping the screen is the thing that was
    /// actually wanted.
    ///
    /// Quitting still returns to the picker, so every sign is reachable; this
    /// only decides where a launch lands.
    @State private var stage: Stage = {
        #if DEBUG
        return .playing(GameRules.debugStartingSign)
        #else
        return .choosingPiece
        #endif
    }()

    var body: some View {
        content
            // Hidden on every screen, not just in-game, so the transition
            // between them does not shift the layout.
            .statusBarHidden()
    }

    @ViewBuilder
    private var content: some View {
        switch stage {
        case .choosingPiece:
            PieceSelectionScreen { sign in
                withAnimation(.easeInOut(duration: 0.3)) {
                    stage = .playing(sign)
                }
            }
            .transition(.opacity)

        case let .playing(sign):
            // `id:` forces a fresh `GameScreen` — and so a fresh `GameSession`
            // and engine — per sign, rather than reusing a previous run's state.
            GameScreen(
                zodiac: sign,
                onQuit: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        stage = .choosingPiece
                    }
                }
            )
            .id(sign)
            .transition(.opacity)
        }
    }
}
