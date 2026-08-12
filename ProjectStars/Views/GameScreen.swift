//
//  GameScreen.swift
//  Project Stars
//
//  The two-square layout: board on top, information and input below.
//

import SwiftUI

/// The whole game, laid out as two stacked squares.
///
/// The square edge is `min(width, height / 2)`, so both halves stay square on
/// every device and the pair is centred vertically. Anything left over becomes
/// letterboxing rather than distortion — which matters for pixel art, where a
/// stretched grid is immediately visible.
struct GameScreen: View {

    /// The sign chosen on the selection screen. Fixed for the whole run.
    let zodiac: Zodiac

    /// Returns to piece selection — the only ordinary way to change sign.
    let onQuit: () -> Void

    @State private var session: GameSession

    init(zodiac: Zodiac, onQuit: @escaping () -> Void) {
        self.zodiac = zodiac
        self.onQuit = onQuit
        self._session = State(initialValue: GameSession(zodiac: zodiac))
    }

    var body: some View {
        GeometryReader { proxy in
            let side = squareSide(in: proxy.size)

            VStack(spacing: 0) {
                // Upper square: the playfield.
                ZStack {
                    // The sky fills the whole square, not just the grid — the
                    // letterboxing either side of a 7x7 board at whole-pixel
                    // scale is part of the view, and should be sky rather than
                    // chrome.
                    SkyView(plane: session.visiblePlane, side: side)
                    BoardView(session: session, availableSide: side)

                    // Names what is being looked at, so it belongs with the
                    // thing being looked at rather than among the controls.
                    PlaneBadgeView(plane: session.visiblePlane)
                        .padding(10)
                        .frame(width: side, height: side, alignment: .topTrailing)

                    // What you just opened, on every pickup rather than only the
                    // first. Pinned low so it never covers the piece.
                    if let banner = session.pentacleBanner {
                        PentacleBannerView(id: banner)
                            .padding(.horizontal, 10)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                            .padding(.bottom, 6)
                    }
                }
                .frame(width: side, height: side)

                // Lower square: information and the input zone.
                ControlPanelView(session: session, side: side)
                    .frame(width: side, height: side)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .background(Palette.background)
        .ignoresSafeArea(.container, edges: .bottom)
        .overlay {
            // A first-encounter splash outranks game over: it is explaining the
            // very move that may have just ended the run.
            if let intro = session.pentacleIntro {
                PentacleIntroView(
                    id: intro,
                    accent: session.zodiac.definition.accentColor,
                    onDismiss: { session.dismissPentacleIntro() }
                )
            } else if session.isChoosingPiece {
                PieceChoiceOverlay(session: session) { sign in
                    session.resolvePickupChoice(.piece(sign))
                }
            } else if session.isPaused {
                PauseMenuView(session: session, onQuit: onQuit)
            } else if session.phase == .gameOver {
                GameOverOverlay(session: session, onChangeSign: onQuit)
            }
        }
        .background { keyboardCommands }
        .animation(.easeInOut(duration: 0.3), value: session.phase)
        .animation(.easeInOut(duration: 0.25), value: session.pentacleIntro)
        .animation(.easeInOut(duration: 0.2), value: session.isPaused)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: session.pentacleBanner)
        .statusBarHidden()
    }

    /// Hardware-keyboard shortcuts, for testing on the simulator and on iPad.
    ///
    /// Zero-sized buttons in the background rather than `onKeyPress`, which needs
    /// the view to take focus — and taking focus here would fight the drag
    /// surface for input. A `keyboardShortcut` only needs the button to be in the
    /// hierarchy.
    ///
    /// - **Arrow keys / WASD** move, at the shortest distance available.
    /// - **R** restarts the run with the same sign.
    /// - **N** sends the Nexys to the other plane (debug builds only).
    /// - **Z** fills the Zodiaction meter (debug builds only).
    /// - **X** fills *and* pops it, skipping the hold (debug builds only).
    /// - **L** makes the *next* Pentacle an Astral Bolt (debug builds only).
    /// - **C** cycles the control scheme (debug builds only).
    private var keyboardCommands: some View {
        ZStack {
            // Reach 0 — the nearest option. A key press carries no magnitude, so
            // there is nothing to derive a longer move from; signs with a choice
            // of distance still need the drag.
            ForEach(SwipeDirection.allCases) { direction in
                ForEach(Array(direction.keyEquivalents.enumerated()), id: \.offset) { _, key in
                    Button(direction.rawValue) { session.submit(direction, reach: 0) }
                        .keyboardShortcut(key, modifiers: [])
                }
            }

            Button("Restart run") { session.restart() }
                .keyboardShortcut("r", modifiers: [])

            #if DEBUG
            Button("Shift Nexys") { session.debugShiftNexys() }
                .keyboardShortcut("n", modifiers: [])

            Button("Fill Zodiaction") { session.debugFillZodiaction() }
                .keyboardShortcut("z", modifiers: [])

            Button("Pop Zodiaction") { session.debugPopZodiaction() }
                .keyboardShortcut("x", modifiers: [])

            Button("Stage lightning") { session.debugStageLightning() }
                .keyboardShortcut("l", modifiers: [])

            Button("Cycle controls") { session.debugCycleControls() }
                .keyboardShortcut("c", modifiers: [])

            #endif
        }
        .frame(width: 0, height: 0)
        .opacity(0)
        .accessibilityHidden(true)
    }

    /// Edge length shared by both squares.
    private func squareSide(in size: CGSize) -> CGFloat {
        max(min(size.width, size.height / 2), 1)
    }
}

// MARK: - Preview

#Preview {
    GameScreen(zodiac: .aries, onQuit: {})
}
