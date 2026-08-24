//
//  GameScreen.swift
//  Project Stars
//
//  The two-square layout: board on top, information and input below.
//

import SwiftUI

#if DEBUG
// MARK: - The sign under the knife
//
// **Here, at the top of the screen it opens.** It used to live three thousand
// lines into `GameRules`, between a fall distance and a smoke magnitude, which
// is nowhere anybody looks — so every time the work moved to another sign,
// finding this cost longer than changing it.
//
// Read by `RootView` to skip straight into a run and by
// `PieceSelectionScreen` to open on the right sign; both go through
// `GameRules.debugStartingSign`, which now forwards here.

/// Whoever is being worked on. Point it at them, and move it when the work
/// moves.
///
/// - TODO: **Debug only.** Never read in a shipped build.
let debugStartingSign: Zodiac = .aries
#endif

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

    /// How much room the turn counter takes, so the prompt can line up with it.
    @State private var counterSpan: CGSize = .zero

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
                        //planeSquare(.umbra, side: side)
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

                    // How far the run has got, opposite the plane badge.
                    //
                    // The two top corners are the run's two facts: where you
                    // are, and how long you have lasted. Nothing else competes
                    // for that band of sky.
                    // **A step down, not a fraction.**
                    //
                    // The counter should read smaller than the board it sits
                    // over, and the way to shrink pixel art is to draw it at
                    // the next whole scale — 0.75 of three is 2.25, which puts
                    // some art pixels at two screen pixels and some at three.
                    // One scale down is the same intent, honestly expressed.
                    TurnCounterView(
                        turn: session.engine.moveCount,
                        scale: max(PixelArtMetrics(availableSide: side).scale - 1, 1)
                    )
                    // Measured rather than guessed: the prompt below lines up
                    // with this, and the only thing that knows how wide the
                    // counter is is the counter.
                    .background {
                        GeometryReader { counter in
                            Color.clear.preference(
                                key: TurnCounterSpan.self,
                                value: counter.size
                            )
                        }
                    }
                    .padding(10)
                    .frame(width: side, height: side, alignment: .topLeading)

                    // What a passive just did, under the counter and out to its
                    // trailing edge. See `PassivePromptView`.
                    // **Stacked, not listed.** The newer one slides in over the
                    // older; in a `VStack` it would push the older one down the
                    // screen instead, and a zero height to stop that clips it.
                    ZStack(alignment: .topLeading) {
                        ForEach(session.passivePrompts) { prompt in
                            PassivePromptView(
                                prompt: prompt,
                                reach: counterSpan.width,
                                onLeaving: { session.passivePromptIsLeaving(prompt.id) },
                                onFinished: { session.passivePromptFinished(prompt.id) }
                            )
                        }
                    }
                    .padding(.leading, 10)
                    .padding(.top, counterSpan.height + 10 + PromptStyle.drop)
                    .frame(width: side, height: side, alignment: .topLeading)

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
                // The corners close in red while the rim is one step away.
                //
                // An overlay, so a warning can never change what the playfield
                // is laid out as — the board below is positioned square by
                // square, and every past attempt to add something at this level
                // with a frame threw those positions across the screen.
                .overlay { edgeVignette(side: side) }
                // **Read here, not beside the counter.** A preference travels
                // *up* the tree, so only an ancestor of the view that set it can
                // hear it — read from a sibling it never arrives, and the prompt
                // was being asked to fly a distance of zero.
                .onPreferenceChange(TurnCounterSpan.self) { counterSpan = $0 }
                // **The upper square, not the screen.**
                //
                // The card announces the run, and the run is the board — centred
                // over both squares it would sit half across the control panel,
                // naming a mode over a row of buttons. An overlay for the same
                // reason the vignette is one: it takes the playfield's bounds
                // without being able to move anything laid out inside them.
                .overlay {
                    if let mode = session.modeCard {
                        GameModeSplashView(
                    mode: mode,
                    isLeaving: session.modeCardIsLeaving,
                    onLanded: { session.modeCardHasLanded = true },
                    onFinished: { session.modeCardFinished() }
                )
                    }
                }

                // Lower square: information and the input zone.
                ControlPanelView(session: session, side: side, onQuit: onQuit)
                    .frame(width: side, height: side)
                    .overlay(alignment: .bottomLeading) {
                        #if DEBUG
                        // **Both benches parked.** The counter is placed and the rift is
                        // waiting for Gemini, so neither is being tuned — and a bench left
                        // on screen after the tuning is done is just something covering the
                        // panel. Uncomment the stack to bring either back; both control
                        // types and every value they drive are untouched.
                        //
                        // Both benches are parked: the counter is placed and the rift is
                        // waiting for Gemini. `TurnCounterTunerControls` and
                        // `RiftPreviewControls` are intact — this is the mount.
                        //
                        // The layer switchboard is *not* parked, because what it is for is
                        // not finished: it takes the board apart one layer at a time while
                        // the frame counter is running. See `LayerBench`.
                        LayerBenchControls(session: session)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            .padding(.leading, 6)
                            .padding(.top, 40)
                        #endif
                    }
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
        .overlay(alignment: .top) {
            #if DEBUG
            // Over everything, including the pause and game-over sheets: the
            // frames that matter most are the ones being dropped while
            // something is covering the board.
            //
            // Down the right edge rather than centred: the rate is one line but
            // the rebuild counts under it are a column as long as there are
            // clocks running, and a column has to hang off an edge to be read.
            // The top left is the turn counter's corner.
            FrameRateView()
                .padding(.top, 8)
                .padding(.trailing, 6)
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

    /// The playfield darkening red at its corners while a step would take you
    /// off the board.
    ///
    /// Only Aquarius and his phantom can leave at all, so for everyone else this
    /// is never built — standing beside the rim says nothing about a piece whose
    /// move off it is simply refused.
    @ViewBuilder
    private func edgeVignette(side: CGFloat) -> some View {
        if session.engine.isAgainstTheEdge {
            TimelineView(.animation(paused: session.isPaused)) { timeline in
                let clock = session.ambientClock(at: timeline.date.timeIntervalSinceReferenceDate)
                let breath = (1 - cos(clock / GameRules.edgeWarningPeriod * 2 * .pi)) / 2

                RadialGradient(
                    colors: [.clear, Palette.red],
                    center: .center,
                    startRadius: side / 2 * GameRules.edgeVignetteClear,
                    endRadius: side / 2 * GameRules.edgeVignetteReach
                )
                .opacity(GameRules.edgeWarningStrongest * breath)
                // Added to a night sky, taken out of a daylit one.
                //
                // A red glow over Astra's midnight is the whole effect; the
                // same glow over Terra's pale blue is invisible, because there
                // is nothing left to add. Multiplying darkens instead, which is
                // what a warning has to do on a bright ground.
                .blendMode(session.visiblePlane == .astra ? .plusLighter : .plusDarker)
            }
            .allowsHitTesting(false)
        }
    }

    /// How deep the ground under Terra's board is drawn, in points.
    private func terraFloor(side: CGFloat) -> CGFloat {
        let pixel = side / (7 * CGFloat(GameRules.tilePixelSize))
        #if DEBUG
        return TerraSceneryTuning.shared.floorDepth * pixel
        #else
        return GameRules.terraFloorDepth * pixel
        #endif
    }

    /// True while nothing may stand over the board's edges.
    ///
    /// **Asked of the piece, not of the run.** Aquarius is the only sign that
    /// can leave the board — and die doing it — but you can *become* her mid
    /// run through Forced Fate, an Alignment or one of Leo's phantoms, so the
    /// question is who is on the board right now.
    private var edgesMustBeClear: Bool {
        session.engine.floatsOverBoardEdge
    }

    /// One plane's square: its sky, and its board.
    ///
    /// The sky belongs to the plane rather than to the screen, which is what
    /// lets the two be stacked at all — Astra's stars and Terra's daylight are
    /// as much a part of where you are as the ground is.
    private func planeSquare(_ plane: Plane, side: CGFloat) -> some View {
        planeContents(plane, side: side)
            // Everything inside stops asking for frames while this plane is the
            // one off screen. See `EnvironmentValues.planeIsAsleep`.
            .environment(\.planeIsAsleep, session.planeIsAsleep(plane))
    }

    private func planeContents(_ plane: Plane, side: CGFloat) -> some View {
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

            // The land behind the board — over the sky, under everything else.
            //
            // **Two ridges, both behind.** The second is the same drawing drawn
            // again over the first and still under the board: two rows of hills
            // at different heights read as distance, where one reads as a wall.
            if plane == .terra, LayerBench.shared.scenery {
                TerraSceneryView(part: .backdrop, side: side, isRetreated: edgesMustBeClear)
                TerraSceneryView(part: .midground, side: side, isRetreated: edgesMustBeClear)
            }

            BoardView(session: session, plane: plane, availableSide: side)

            // **The ground under the board.**
            //
            // Terra's board floats over the sky, which is right for Astra and
            // wrong for a place made of earth: below the front row you could
            // see straight through the world. A flat fill closes it, in front
            // of the board so nothing on the board is behind it, and behind the
            // rocks so they still read as sitting on it.
            if plane == .terra, LayerBench.shared.scenery {
                Rectangle()
                    .fill(Palette.steel)
                    // Straight off, rather than retreating: it is a fill, and a
                    // fill has nowhere to go.
                    .opacity(edgesMustBeClear ? 0 : 1)
                    .frame(height: terraFloor(side: side))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .allowsHitTesting(false)
            }

            // The flanking rocks: in front of the board, behind the near rock.
            if plane == .terra, LayerBench.shared.scenery {
                TerraMidRocks(set: 1, side: side, isRetreated: edgesMustBeClear)
                TerraMidRocks(set: 0, side: side, isRetreated: edgesMustBeClear)
            }

            // And the rock in front of it, over **everything**: it is nearer
            // the camera than the board is, so the front row passing behind it
            // is the whole reason it exists.
            if plane == .terra, LayerBench.shared.scenery {
                TerraSceneryView(
                    part: .foreground,
                    side: side,
                    // Only the front row is behind it, and only on this plane.
                    isHiding: session.visiblePlane == .terra
                        && session.engine.piece.plane == .terra
                        && session.engine.piece.point.y
                            == session.engine.currentBoard.size - 1,
                    isRetreated: edgesMustBeClear
                )
            }
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
    /// - **X** fills *and* pops it, skipping the hold (debug builds only).s1
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
            Button("Replay the mode card") { session.modeCard = session.mode }
                .keyboardShortcut("m", modifiers: [])
            #endif

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

            // Fires the snipe flourish where the piece is standing, so the
            // question "does the sprite draw" can be answered without hunting
            // a coin on the move it appears.
            Button("Roll ten thousand coins") { session.debugRollDistribution() }
                .keyboardShortcut("7", modifiers: [])

            // Two puffs, front row and back row, at once — see
            // `GameSession.debugCompareDepth`.
            Button("Compare depth") { session.debugCompareDepth() }
                .keyboardShortcut("8", modifiers: [])

            Button("Arm a snipe") { session.debugArmSnipe() }
                .keyboardShortcut("6", modifiers: [])


            Button("Play the flourish") {
                session.playEffect(
                    .bonus, at: session.engine.piece.point, on: session.engine.piece.plane
                )
            }
            .keyboardShortcut("4", modifiers: [])

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

/// The turn counter's measured size, handed down to whatever lines up with it.
private struct TurnCounterSpan: PreferenceKey {
    static let defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        let next = nextValue()
        if next != .zero { value = next }
    }
}
