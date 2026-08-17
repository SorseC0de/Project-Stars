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
                    // **Both planes, actually stacked.**
                    //
                    // Astra above Terra, each in its own square, with the one
                    // being stood on scrolled into frame. Nothing about this
                    // changes what is seen today — the other plane is off screen
                    // and clipped away — but it is the difference between a
                    // transition that can travel between them and one that has
                    // to hide a swap behind a curtain.
                    VStack(spacing: 0) {
                        planeSquare(.astra, side: side)
                        planeSquare(.terra, side: side)
                    }
                    .offset(y: session.visiblePlane == .astra ? 0 : -side)
                    .frame(width: side, height: side, alignment: .top)
                    .clipped()

                    // Names what is being looked at, so it belongs with the
                    // thing being looked at rather than among the controls.
                    // The fragment you are carrying, immediately left of the
                    // plane's name.
                    //
                    // Beside it rather than anywhere else on the board, because
                    // the two are the same kind of statement: this is where the
                    // upper square tells you what is *true* right now. The panel
                    // has a button for spending it, which says something
                    // different — that you may use it — and while the fragment
                    // is dormant only the first of those is.
                    HStack(spacing: 8) {
                        // Anything running on a clock, growing leftward so
                        // nothing already on screen moves when one starts.
                        BuffsView(session: session)

                        PolarisBadgeView(
                            polaris: session.polaris,
                            scale: PixelArtMetrics(availableSide: side).scale
                        )
                        PlaneBadgeView(plane: session.visiblePlane)
                    }
                    .padding(10)
                    .frame(width: side, height: side, alignment: .topTrailing)

                    // What you just opened, on every pickup rather than only the
                    // first. Pinned low so it never covers the piece.
                    //
                    // The shop takes the same slot, and outranks it: the strip
                    // is waiting on an answer, the banner is only telling you
                    // something. Neither ever covers the board.
                    // Capricorn's belt is always out.
                    //
                    // A hotbar you cannot see is a hotbar you forget you have —
                    // and the purse is the sign's whole resource, so hiding it
                    // until the moment of spending meant the player could not
                    // plan around what they were carrying. Popping the super
                    // does not summon it, it makes it *live*.
                    if session.isChoosingShop || !session.purse.isEmpty {
                        ShopBarView(
                            context: session.summaryContext,
                            purse: session.purse,
                            accent: session.zodiac.definition.accentColor,
                            isLive: session.isChoosingShop
                        ) { id in
                            session.resolvePickupChoice(.item(id))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        .padding(.bottom, 6)
                    } else if let banner = session.pentacleBanner {
                        PentacleBannerView(context: session.summaryContext, id: banner)
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
                    context: session.summaryContext,
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
        .overlay(alignment: .topLeading) {
            #if DEBUG
            // Over everything, including the pause and game-over sheets: the
            // frames that matter most are the ones being dropped while
            // something is covering the board.
            FrameRateView()
                .padding(.leading, 8)
                .padding(.top, 8)
            #endif
        }
        // Every ambient animation below this reads it, `PixelSprite` included —
        // which is how the whole board stops at once rather than view by view as
        // somebody remembers each one.
        .environment(\.ambientClock, session.ambientClock(at:))
        .background { keyboardCommands }
        .animation(.easeInOut(duration: 0.3), value: session.phase)
        .animation(.easeInOut(duration: 0.25), value: session.pentacleIntro)
        .animation(.easeInOut(duration: 0.2), value: session.isPaused)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: session.pentacleBanner)
        .animation(.spring(response: 0.32, dampingFraction: 0.82), value: session.isChoosingShop)
        .animation(.spring(response: 0.32, dampingFraction: 0.82), value: session.purse)
        .statusBarHidden()
        // The picker's overlay renders here rather than at the button, because
        // a button inside the panel cannot draw outside the panel's bounds.
        // See `iMAPicker`.
        .iMAPickerHost()
    }

    /// One plane's square: its sky, and its board.
    ///
    /// The sky belongs to the plane rather than to the screen, which is what
    /// lets the two be stacked at all — Astra's stars and Terra's daylight are
    /// as much a part of where you are as the ground is.
    private func planeSquare(_ plane: Plane, side: CGFloat) -> some View {
        ZStack {
            // The sky fills the whole square, not just the grid — the
            // letterboxing either side of a 7x7 board at whole-pixel scale is
            // part of the view, and should be sky rather than chrome.
            SkyView(plane: plane, side: side, clock: session.ambientClock(at:))

            // Underneath the sky, and underneath the board with it — so it
            // shows through Astra's holes. See `GroundBelowView`.
            if plane == .astra {
                GroundBelowView(side: side, metrics: PixelArtMetrics(availableSide: side))
                    .frame(width: side, height: side)
            }

            BoardView(session: session, plane: plane, availableSide: side)
        }
        .frame(width: side, height: side)
    }

    /// Hardware-keyboard shortcuts, for testing on the simulator and on iPad.
    ///
    /// Zero-sized buttons in the background rather than `onKeyPress`, which needss
    /// the view to take focus — and taking focus here would fight the drag
    /// surface for input. A `keyboardShortcut` only needs the button to be in the
    /// hierarchy.
    ///
    /// - **Arrow keys / WASD** move, at the shortest distance available.
    /// - **Q / E / Z / C** move diagonally, for the signs that can.
    /// - **R** restarts the run with the same sign.
    /// - **N** sends the Nexys to the other plane (debug builds only).
    /// - **1** fills the Zodiaction meter (debug builds only).
    /// - **X** fills *and* pops it, skipping the hold (debug builds only).
    /// - **L** makes the *next* Pentacle an Astral Bolt (debug builds only).
    /// - **P** makes the *next* Pentacle a Polaris (debug builds only).
    /// - **+ / -** move the meter a pip either way (debug builds only).
    /// - **2** cycles the control scheme (debug builds only).
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

            // On the number row: Z and C are movement now.
            Button("Fill Zodiaction") { session.debugFillZodiaction() }
                .keyboardShortcut("1", modifiers: [])

            Button("Pop Zodiaction") { session.debugPopZodiaction() }
                .keyboardShortcut("x", modifiers: [])

            Button("Stage Polaris") { session.debugStagePolaris() }
                .keyboardShortcut("p", modifiers: [])

            // Both faces of each key: a keyboard sends "=" unshifted where the
            // legend says "+", and either is what somebody reaching for it will
            // press.
            Button("Meter up") { session.debugNudgeMeter(by: 1) }
                .keyboardShortcut("+", modifiers: [])
            Button("Meter up") { session.debugNudgeMeter(by: 1) }
                .keyboardShortcut("=", modifiers: [])

            Button("Meter down") { session.debugNudgeMeter(by: -1) }
                .keyboardShortcut("-", modifiers: [])
            Button("Meter down") { session.debugNudgeMeter(by: -1) }
                .keyboardShortcut("_", modifiers: [])

            Button("Stage lightning") { session.debugStageLightning() }
                .keyboardShortcut("l", modifiers: [])

            Button("Cycle controls") { session.cycleControls() }
                .keyboardShortcut("2", modifiers: [])

            Button("Toggle fissure") { session.debugToggleFissure() }
                .keyboardShortcut("3", modifiers: [])

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
    // Whoever is being worked on — see `GameRules.debugStartingSign`.
    //
    // This preview is a real entry point into the game, not a thumbnail: it
    // skips `RootView` and the picker entirely, so a sign hardcoded here is the
    // sign anybody testing through it actually gets.
    GameScreen(zodiac: GameRules.debugStartingSign, onQuit: {})
}
