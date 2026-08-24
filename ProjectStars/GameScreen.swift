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
// Read by `RootView` to skiap straight into a run and by
// `PieceSelectionScreen` to open on the right sign; both go through
// `GameRules.debugStartingSign`, which now forwards here.

/// Whoever is being worked on. Point it at them, and move it when the work
/// moves.
///
/// - TODO: **Debug only.** Never read in a shipped build.
let debugStartingSign: Zodiac = .aries

/// Whether the ground wears out under the piece.
///
/// Set it to `false` to walk about a board that never breaks — which is most of
/// what testing anything else needs, since the alternative is falling through
/// the floor a dozen moves into whatever you were actually looking at and
/// starting the run again.
///
/// **Only what movement costs the ground.** Anything that sets out to break a
/// tile still does — Aries' charge, Pisces surfacing through a cloud, a
/// Zodiaction that opens a ring of holes — because those are the thing being
/// tested when they are on screen, and a switch that quietly disabled them
/// would be a switch that lies about what the game does.
///
/// - TODO: **Debug only.** Never read in a shipped build.
let debugDamagesTiles = false
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

            ZStack(alignment: .top) {
                // **The world, drawn once, behind everything.**
                //
                // Nine squares in one column — see `World`. The window onto it
                // is the whole screen rather than the playfield, because the
                // lower square is behind the control panel and what is behind
                // the panel is still being drawn: that is what lets a piece fall
                // out of Terra into the underground without anything being
                // moved to meet it.
                ZStack(alignment: .top) {
                    // Past both ends of the column, and the same colour the
                    // column ends in. The camera overruns the world by a row at
                    // the seam, and this is what it sees there — see
                    // `World.wrapped(_:)`.
                    Palette.coolBlack

                    worldColumn(side: side)
                        .offset(y: -CGFloat(session.cameraRow) * side)
                }
                .frame(width: side, height: side * 2, alignment: .top)
                .clipped()

                VStack(spacing: 0) {
                // Upper square: everything the playfield is labelled with.
                ZStack {
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
                    // **The direction guide, with the rest of the chrome.**
                    //
                    // It lived inside `BoardView`, which put it inside a plane's
                    // square, which was wrong in three ways at once. It was
                    // drawn under Terra's near scenery, because the floor fill
                    // and the front rock are siblings declared after the board.
                    // It was drawn *twice* whenever two rows were on screen. And
                    // both copies rode the camera down the column, which is not
                    // something a label on the world should do.
                    //
                    // It is a label. Labels live up here with the badges and the
                    // turn counter. The inner frame re-establishes the board's
                    // own bounds inside the square, which is what its corner
                    // placement is measured against.
                    CompassView(
                        facing: session.visibleFacing,
                        tileSize: PixelArtMetrics(availableSide: side).tileSize
                    )
                    .opacity(session.engine.piece.point == compassCorner
                        ? GameRules.compassFaded
                        : 1)
                    .animation(.easeOut(duration: 0.2), value: session.engine.piece.point)
                    .offset(
                        x: PixelArtMetrics(availableSide: side).tileSize * GameRules.compassInset,
                        y: -PixelArtMetrics(availableSide: side).tileSize * GameRules.compassInset
                    )
                    .allowsHitTesting(false)
                    .frame(
                        width: PixelArtMetrics(availableSide: side).boardSize,
                        height: PixelArtMetrics(availableSide: side).boardSize,
                        alignment: .bottomLeading
                    )
                    .frame(width: side, height: side)

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
                            title: mode.title,
                            subtitle: mode.blurb,
                            isLeaving: session.modeCardIsLeaving,
                            onLanded: { session.modeCardHasLanded = true },
                            onFinished: { session.modeCardFinished() }
                        )
                    } else if session.phase == .gameOver {
                        // **The same card, saying the opposite thing.** It opens
                        // the run and it closes it, in the same place, so the two
                        // read as one object rather than two that resemble each
                        // other. It arrives and never leaves: `isLeaving` stays
                        // low, so the bars settle into their Z and hold.
                        GameModeSplashView(
                            title: DeathStyle.title,
                            subtitle: session.engine.gameOverReason?.displayText ?? "",
                            // The name is the announcement; the reason under it
                            // is the explanation, and an explanation in alarm
                            // red is a second alarm.
                            ink: Palette.red,
                            isLeaving: false,
                            onLanded: {},
                            onFinished: {}
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

    /// The world, top to bottom.
    ///
    /// Each place offset to its own row rather than stacked in a `VStack`, so a
    /// row can be left out — the underground has no board and Umbra has no
    /// anything yet — without everything below it sliding up to fill the gap.
    /// The column's geometry lives in `World`, and this is the only place that
    /// turns it into points.
    private func worldColumn(side: CGFloat) -> some View {
        ZStack(alignment: .top) {
            WorldSky(
                side: side,
                camera: session.cameraRow,
                cameraFrom: session.cameraFrom,
                clock: session.ambientClock(at:)
            )

            // The underground first, because it is the furthest thing from the
            // camera and nothing is ever in front of it except by falling into
            // it.
            row(World.underground, side: side) { DeathView(session: session) }

            // **The plane the piece is on draws last.**
            //
            // A `ZStack` draws its children in order, and for a whole fall the
            // piece is still drawn in the square it *left* — three rows above
            // the one it is heading for. In plain row order the destination's
            // board would be drawn over the piece falling towards it, and it
            // would disappear behind Terra at the exact moment the fall was
            // meant to be worth watching.
            //
            // `zIndex` rather than reordering the views: reordering a stack's
            // children can cost SwiftUI the identity of what is inside them, and
            // what is inside these is two boards — rebuilt, at the one moment in
            // the game where there is no frame to spare.
            row(World.row(of: .astra), side: side) { planeSquare(.astra, side: side) }
                .zIndex(session.engine.piece.plane == .astra ? 1 : 0)
            row(World.row(of: .terra), side: side) { planeSquare(.terra, side: side) }
                .zIndex(session.engine.piece.plane == .terra ? 1 : 0)
        }
        .frame(width: side, height: side * CGFloat(World.rows), alignment: .top)
    }

    /// One square of the column, in its place.
    ///
    /// **Mounted whether or not it can be seen**, and asleep when it cannot —
    /// see `GameSession.planeIsAsleep(_:)`. Unmounting would be cheaper to
    /// describe and worse to play: a board rebuilt from nothing every time the
    /// camera arrives is a board rebuilt at the exact moment the camera is
    /// moving, which is the one moment there is no frame to spare. What cost
    /// this project a week was a plane that kept *ticking* off screen, not one
    /// that kept existing.
    private func row<Content: View>(
        _ index: Int,
        side: CGFloat,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .frame(width: side, height: side)
            .offset(y: CGFloat(index) * side)
    }

    private func planeSquare(_ plane: Plane, side: CGFloat) -> some View {
        planeContents(plane, side: side)
            // Everything inside stops asking for frames while this plane is the
            // one off screen. See `EnvironmentValues.planeIsAsleep`.
            .environment(\.planeIsAsleep, session.planeIsAsleep(plane))
    }

    private func planeContents(_ plane: Plane, side: CGFloat) -> some View {
        ZStack {
            // **No sky here.** It used to be one per plane, each the size of its
            // own square and each ending at its own edge — which is precisely
            // why nothing could ever be seen travelling between two of them. The
            // sky is now the column's, drawn once behind all nine rows. See
            // `WorldSky`.

            // **No faux Terra under Astra.**
            //
            // There used to be a picture of Terra's horizon painted into the
            // bottom of Astra's square, seen through its holes — a stand-in for
            // a plane that was not really below it, because nothing was really
            // below anything.
            //
            // Terra *is* below it now, three rows down the column, and the
            // stand-in was drawn at the wrong scale to be it: a horizon on the
            // near edge of a square you are looking down into does not sit where
            // a whole board three rows further away would.

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
    /// - **Arrow keys / WASD** move, at the shortest distance available — or begin
    ///   the run, when it has not begun.
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
                    Button(direction.rawValue) {
                        // **On the start screen, any movement key is Start.**
                        //
                        // These shortcuts exist so the game can be played at
                        // speed without touching the panel, and a run that can
                        // be played entirely from the keyboard except for the
                        // one press that begins it is not that. It starts and
                        // does not also move: the card is still crossing the
                        // board, and the first thing a run does should not be
                        // hidden behind it.
                        if session.isAwaitingStart {
                            guard session.modeCardHasLanded else { return }
                            session.startRun()
                        } else {
                            session.submit(direction, reach: 0)
                        }
                    }
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
    /// The square the compass sits over: bottom-left of the board.
    private var compassCorner: GridPoint {
        GridPoint(0, session.visibleBoard.size - 1)
    }

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
