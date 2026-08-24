//
//  BoardView.swift
//  Project Stars
//
//  The playfield: the upper square of the screen.
//

import SwiftUI

/// Renders the plane the piece is currently on.
///
/// ## Two passes over the grid
///
/// The board is drawn twice. The first pass lays down a full 7x7 of **edge**
/// strips; the second covers them with the **faces**. Normally the faces hide
/// the edges completely — but the tile holding a Pentacle is drawn lifted by
/// `GameRules.tilePopLift`, and the sliver of edge that appears underneath is
/// what sells the lift as depth rather than as a tile that simply moved.
///
/// Everything else layers over that, back to front: sparkles, the coin, the
/// cursor, then the piece and the Nexys — whose order relative to each other is
/// decided per frame, see `nexysDrawsBehindPiece`.
struct BoardView: View {
    @Environment(\.planeIsAsleep) private var planeIsAsleep



    let session: GameSession

    /// Which plane this view is drawing.
    ///
    /// Explicit rather than read off the session, so the board can be asked for
    /// a plane that is not the one being stood on. That is the whole
    /// prerequisite for stacking them: a transition wants Astra *and* Terra on
    /// screen at once, and a view that can only ever draw "wherever the piece
    /// is" can never show the relationship between them.
    ///
    /// Defaults to the visible one, so every existing caller is unchanged.
    var plane: Plane?

    /// The plane being drawn.
    private var shown: Plane { plane ?? session.visiblePlane }

    /// The side length available for the board, in points.
    let availableSide: CGFloat

    var body: some View {
        #if DEBUG
        let _ = RenderTally.tick("board")
        #endif
        let metrics = PixelArtMetrics(availableSide: availableSide)
        let plane = shown
        let board = session.visibleBoard

        // The whole board seen through the tear, chrome excepted.
        //
        // Wrapped inside the compass overlay on purpose: the compass is a label
        // on the world rather than a thing in it, and a rippling HUD reads as a
        // rendering fault where a rippling board reads as the world coming
        // apart. See `FractureField`.
        FractureField(
            isActive: session.isFractured && LayerBench.shared.fracture,
            scale: metrics.scale
        ) {
            ZStack {
            if plane == .terra {
                // - TODO: Terra only while the two are compared. Astra keeps
                //   the projection below.
                // Under the bands, because an edge is the side of the tile in
                // front of it. It takes scale and placement only — an edge is a
                // vertical face, so squashing it with the floor would be
                // squashing the one surface that is not lying down.
                if LayerBench.shared.tileEdges {
                    edgeLayer(board: board, plane: plane, metrics: metrics)
                }
                // The bands themselves are drawn with everything standing on
                // them, a row at a time — see `BoardObjectKind.tileRow`.
                layers(board: board, plane: plane, metrics: metrics, ground: false)
            } else {
            // The world tilts; the chrome over it does not. See `Foreshortened`.
            // No keystone above. Astra's clouds and its island are drawn
            // foreshortened already, so a projection would foreshorten them
            // twice — and there is no grid up here that has to tile, which is
            // the only thing the bands were ever needed for. Every square asks
            // its row how big to be and where to sit, and that is the whole
            // perspective. See `PixelArtMetrics.projected(_:)`.
            layers(board: board, plane: plane, metrics: metrics)
            }
            }
        }
        .overlay(alignment: .bottomLeading) {
            // With the HUD, above everything on the board.
            //
            // It is a label on the world rather than a thing in it, so being
            // overlapped by a piece standing in front of it read as a drawing
            // mistake. Above and faded when the piece is under it says what is
            // true: this is chrome, and it will move aside for you.
            compass(metrics: metrics)
        }
        .frame(width: metrics.boardSize, height: metrics.boardSize)
        // A heavy landing jolts the board. Only the upper square shakes — the
        // panel below is under the player's thumb, and shaking a control surface
        // reads as a fault rather than as impact.
        .screenShake(
            startedAt: session.shakeStartedAt,
            scale: metrics.scale,
            strength: session.shakeStrength
        )
        // An illegal swipe shoves the board a few points and springs back.
        //
        // One tree either way, paused when idle — see `ScreenShake`. A branch
        // here would put the board's resting layout at the mercy of whether a
        // nudge happened to be running.
        .modifier(BoardNudge(offset: nudgeOffset(at:), settled: nudgeSettled))
        // Not clipped: the cursor may hang past the edge when the projected move
        // would leave the grid, and the Nexys overhangs its square.
    }

    /// Everything in the world, in draw order.
    @ViewBuilder
    private func layers(
        board: Board,
        plane: Plane,
        metrics: PixelArtMetrics,
        ground: Bool = true
    ) -> some View {
        ZStack {
            backdrop(plane: plane, metrics: metrics)
            mirrors(plane: plane, metrics: metrics)

            // Terra lays its own ground in bands, because it is a grid of
            // squares and a grid has to tile. Everything *standing* on that
            // ground is the same problem on both planes — a scale and a place
            // per row — so it is drawn by the one stack either way.
            if ground {
                edgeLayer(board: board, plane: plane, metrics: metrics)
                faceLayer(board: board, plane: plane, metrics: metrics)
            }




            // The island and the piece share a clock, so the piece can ride the
            // island's drift while standing on it.
            // Paused means paused: the board's whole clock stops, so nothing
            // is quietly still moving behind the menu.
            // **The board is not on a clock. The things that move are.**
            //
            // This whole stack used to sit inside one `TimelineView`, which is
            // a rebuild of every object on the board sixty times a second — in
            // a game where the board changes only when a turn is taken. The
            // ground alone is forty-nine of those, and it does not move at all.
            //
            // The clock belongs to the handful of things that genuinely animate
            // between turns: the piece and its pose, the cursor, the island's
            // drift, the retinue, the facing arrow, Scorpio's tail. Each takes
            // its own — see `ticking` — which also keeps them sorted against
            // the ground, since a single shared timeline would be one sibling
            // of this stack and everything inside it would share that one
            // place in the order.
            ZStack {
                objects(
                    board: board,
                    plane: plane,
                    metrics: metrics
                )

                // **The wash, with everything standing on the board punched
                // out of it.**
                //
                // The dim used to be a layer between the ground pass and the
                // object pass, which is what made it "over the ground and under
                // everything on it". Drawn a row at a time there is no such
                // moment any more, so the wash goes over the scene and the
                // things that should stay lit are cut back out of it — the same
                // object stack, from the same frame of the same clock, so the
                // holes cannot drift out of step with what they are exempting.
                //
                // Inside the timeline for exactly that reason: the poses are
                // the ones this frame drew.
                // **Built only when there is a wash to build.**
                //
                // A mask is rasterised whether or not what it masks is visible,
                // and this one is a board-and-a-half of rectangle plus a
                // compositing group — paid on every frame of a game that is not
                // dimmed for the overwhelming majority of them. The dims fade
                // their own opacity in and out; what this skips is the machinery
                // around them.
                if session.isDimmed || session.isResolvingAction {
                ZStack {
                    actionDim(metrics: metrics)
                    boardDim(metrics: metrics)
                }
                .mask(
                    ZStack {
                        // **Sized, not scaled.**
                        //
                        // A mask is rasterised into its own layout bounds and
                        // everything outside them is discarded — the same rule
                        // that clips `PaletteGlow`, and the reason a
                        // `scaleEffect` here bought nothing: measured, the sky
                        // either side of the board came back at 99.9% of its
                        // undimmed brightness while the board itself dimmed. So
                        // the mask is given the room outright.
                        Rectangle()
                            .frame(
                                width: metrics.boardSize * 3,
                                height: metrics.boardSize * 3
                            )

                        // **A probe, for telling two failures apart.**
                        //
                        // If the holes do not appear, either the construction
                        // is wrong — a `destinationOut` layer inside a mask not
                        // cutting at all — or the construction is fine and the
                        // object stack is not rendering into the mask, which
                        // would point at the blend modes and drawing groups it
                        // carries inside it. A plain circle has neither, so a
                        // circular hole in the middle of the board says the
                        // construction works and the content is the problem.
                        if GameRules.debugDimHoleProbe, session.isDimmed || session.isResolvingAction {
                            Circle()
                                .frame(width: metrics.tileSize * 3, height: metrics.tileSize * 3)
                                .blendMode(.destinationOut)
                        }

                        // Built only while there is a wash to cut, because it
                        // is a second pass over every object on the board.
                        if !GameRules.debugDimHoleProbe,
                           session.isDimmed || session.isResolvingAction {
                                objects(
                                    board: board,
                                    plane: plane,
                                    includesGround: false,
                                    metrics: metrics
                                )
                                // **Rasterised first, not merely grouped.**
                                //
                                // A mask wants plain alpha, and this stack has
                                // none to offer: it is full of blend modes,
                                // drawing groups and timelines, none of which a
                                // mask renders the way the screen does. A plain
                                // `Circle` in this same slot cuts its hole
                                // perfectly, which is what proved the
                                // construction sound and the content the
                                // problem.
                                //
                                // `drawingGroup` renders the whole subtree into
                                // one bitmap, resolving every blend inside it
                                // into pixels — and a bitmap has exactly the one
                                // thing a mask is asking for.
                                //
                                // Padded going in and unpadded coming out,
                                // because that bitmap is cut to the view's
                                // layout bounds: a shard stands two tiles tall
                                // and the cursor hangs past the edge, and both
                                // would lose whatever crossed the line. The same
                                // reach `PaletteGlow` needs, for the same reason.
                                .padding(metrics.tileSize * 3)
                                .drawingGroup()
                                .padding(-metrics.tileSize * 3)
                                .blendMode(.destinationOut)
                        }
                    }
                    // The subtraction has to resolve inside the mask, against
                    // the rectangle it is cutting — not against whatever the
                    // mask happens to be drawn over.
                    .compositingGroup()
                )
                }
            }
            // **No group-wide z any more.**
            //
            // Giving the whole stack the piece's row sorted the *coins* by his
            // row too, which is why a Pentacle on row 4 fell behind grass on
            // row 3 the moment he stepped down. Everything in here is depth
            // sorted individually by `BoardObject.draw`, which is the board's
            // own painter's order and predates all of this — grass simply had
            // to join the list rather than be sorted beside it.

            #if DEBUG
            // Gemini's rift, parked until Gemini. Everything it needs is intact
            // in `BoardView+RiftPreview` — this line is the whole switch.
            // riftPreview(metrics: metrics)
            #endif

            // **Lifted back over the board.**
            //
            // These were drawn between the ground pass and the object pass, and
            // when the ground joined the objects that stopped being a place to
            // stand — every one of them went under the tiles, which is why
            // Scorpio's husk stopped appearing. Anything in this group that
            // ought to sort per row belongs in the object list rather than here.
            pools(board: board, plane: plane, metrics: metrics)
            shedSkin(plane: plane, metrics: metrics)
            sanctuary(plane: plane, metrics: metrics)
            arrow(metrics: metrics)
            waitingHalf(plane: plane, metrics: metrics)
            shadowDouble(plane: plane, metrics: metrics)

            aquariusTransform(metrics: metrics)
            constellation(metrics: metrics)
            warpBeam(metrics: metrics)
            fallingCloud(metrics: metrics)
            cloudPoofs(metrics: metrics)
            dust(metrics: metrics)
            prongPulse(metrics: metrics)
            collectBurst(metrics: metrics)
            elementalBurst(metrics: metrics)
            sparkleDispersal(metrics: metrics)
            effectBurst(metrics: metrics)
            healFlashClouds(plane: plane, metrics: metrics)
            statueClouds(plane: plane, metrics: metrics)
            healSparkles(metrics: metrics)
            bastionAura(metrics: metrics)
            loosedArrow(metrics: metrics)
            reeledCoin(metrics: metrics)
            bankArc(metrics: metrics)
            slabLanding(metrics: metrics)
            slabDrop(metrics: metrics)

            // Above the cursor, and above the pieces.
            //
            // The slab is the thing being decided about, so nothing on the board
            // should draw across it — and the cursor especially, since the two
            // are always on the same square by definition and the brackets were
            // cutting the preview in half.
            tileChoice(metrics: metrics)

            // Hides the instant the planes swap during an ascent.
            Rectangle()
                .fill(Palette.white)
                .opacity(session.ascentFlash)
                .allowsHitTesting(false)
        }
    }

    /// Pisces' standing water. See `PoolView`.
    private func pools(board: Board, plane: Plane, metrics: PixelArtMetrics) -> some View {
        ForEach(board.allPoints.filter { board[$0].kind == .pool }, id: \.self) { point in
            PoolView(size: metrics.tileSize, clock: session.ambientClock(at:))
                .modifier(placedOnPlaneModifier(point, metrics: metrics))
                .transition(.opacity)
        }
    }

    /// The husk Scorpio left where it died. See `ScorpioSamsaricShed`.
    ///
    /// Drawn flat on the floor rather than as a board object, because it is not
    /// one: nothing stands on it, nothing sorts against it, and it must never
    /// occlude the piece that is still alive. A stain, not an actor.
    @ViewBuilder
    private func shedSkin(plane: Plane, metrics: PixelArtMetrics) -> some View {
        if let skin = session.engine.signState.shedSkin, skin.plane == plane {
            TimelineView(.animation(paused: planeIsAsleep)) { timeline in
                #if DEBUG
                let _ = RenderTally.tick("Bd#1")
                #endif
                let phase = timeline.date.timeIntervalSinceReferenceDate
                    / GameRules.shedSkinFloatPeriod * 2 * .pi
                let drift = CGFloat(sin(phase))
                    * GameRules.shedSkinFloat * metrics.scale

                PixelSprite(id: .pieceFacing(.scorpio, skin.facing)) { Color.clear }
                    .frame(width: metrics.tileSize, height: metrics.tileSize * 2)
                    .offset(
                        y: -metrics.tileSize / 2
                            - GameRules.pieceLift * metrics.scale
                            + drift
                    )
                    .opacity(GameRules.shedSkinOpacity)
                    // Washed towards the water it belongs to, so the husk is
                    // unmistakably *not* the piece even at a glance.
                    .colorMultiply(Palette.sky)
            }
            .frame(width: metrics.tileSize, height: metrics.tileSize * 2)
            .modifier(placedOnPlaneModifier(skin.point, metrics: metrics))
            .allowsHitTesting(false)
            .transition(.opacity)
        }
    }

    /// The arrow on its way up, out of the archer and off the board.
    ///
    /// Head *up* on the way out and head down coming back, which is the one
    /// place the art's rotation differs — a fired arrow points where it is
    /// going.
    @ViewBuilder
    private func loosedArrow(metrics: PixelArtMetrics) -> some View {
        if let shot = session.loosedArrow, shot.plane == shown {
            TimelineView(.animation(paused: planeIsAsleep)) { timeline in
                #if DEBUG
                let _ = RenderTally.tick("Bd#2")
                #endif
                let progress = min(
                    max(timeline.date.timeIntervalSince(shot.start)
                        / GameRules.arrowRiseDuration, 0),
                    1
                )
                // Accelerating away, so it reads as leaving under power rather
                // than drifting off.
                let eased = CGFloat(progress * progress)
                let centre = metrics.center(of: shot.point)

                PixelSprite(id: .effect(.sagittariusArrow)) { EmptyView() }
                    .frame(width: metrics.tileSize * 2, height: metrics.tileSize * 2)
                    .rotationEffect(.degrees(-GameRules.arrowArtRotation))
                    .position(
                        x: centre.x,
                        y: centre.y - metrics.tileSize
                            - eased * (metrics.boardSize + metrics.tileSize * 2)
                    )
            }
            .frame(width: metrics.boardSize, height: metrics.boardSize)
            .allowsHitTesting(false)
        }
    }

    /// A coin being drawn in to the piece.
    ///
    /// Travels the straight line between where it was and where the piece is,
    /// shrinking as it arrives — so a swept Pentacle is visibly *taken* rather
    /// than deleted from the square it was sitting on.
    @ViewBuilder
    private func reeledCoin(metrics: PixelArtMetrics) -> some View {
        if let flight = session.coinFlight, flight.plane == shown {
            TimelineView(.animation(paused: planeIsAsleep)) { timeline in
                #if DEBUG
                let _ = RenderTally.tick("Bd#3")
                #endif
                let progress = min(
                    max(timeline.date.timeIntervalSince(flight.start)
                        / GameRules.stingReelDuration, 0),
                    1
                )
                // Eased, so it leaves quickly and settles rather than sliding at
                // a constant rate like a dragged object.
                let eased = CGFloat(progress * progress * (3 - 2 * progress))

                let from = metrics.center(of: flight.from)
                let to = metrics.center(of: session.engine.piece.point)

                PentacleView(
                    appearance: PickupCatalog.effect(for: flight.id)
                        .appearance(on: shown),
                    size: metrics.tileSize,
                    scale: metrics.scale
                )
                .scaleEffect(1 - eased * 0.45)
                .position(
                    x: from.x + (to.x - from.x) * eased,
                    y: from.y + (to.y - from.y) * eased
                )
            }
            .frame(width: metrics.boardSize, height: metrics.boardSize)
            .allowsHitTesting(false)
        }
    }

    /// The tile a Nexyial Bastion is shielding.
    ///
    /// Cycling the elemental ramp, like the Astral Bolt — the aura is Astral
    /// energy rather than any one element's, and a colour that settles would
    /// imply it belonged to whichever one it stopped on.
    @ViewBuilder
    private func bastionAura(metrics: PixelArtMetrics) -> some View {
        if let point = session.engine.signState.bastion,
           session.engine.signState.bastionPlane == shown {
            TimelineView(.animation(paused: session.isPaused || planeIsAsleep)) { timeline in
                #if DEBUG
                let _ = RenderTally.tick("Bd#4")
                #endif
                let tick = session.ambientClock(
                    at: timeline.date.timeIntervalSinceReferenceDate
                )
                let step = Int(tick / GameRules.bastionColourHold)
                let ramp = ZodiacElement.allCases
                let tint = ElementFX.ramp(
                    for: ramp[((step % ramp.count) + ramp.count) % ramp.count]
                ).bright

                Rectangle()
                    .strokeBorder(tint, lineWidth: GameRules.bastionEdge * metrics.scale)
                    .background(Rectangle().fill(tint.opacity(GameRules.bastionFill)))
                    // A `Rectangle` takes every point it is offered, so it says
                    // its own size — the one thing `onBoard` cannot know.
                    .frame(width: metrics.tileSize, height: metrics.tileSize)
                    .onBoard(
                        point,
                        layer: .groundMark,
                        in: context(for: shown, metrics: metrics)
                    )
                    .blendMode(.plusLighter)
            }
            .allowsHitTesting(false)
        }
    }

    /// What a Match-shift Miasma has marked this square with, if anything.
    ///
    /// The colour is the tell: a mark is sky or orange, and the coin that
    /// answers it wears the other one.
    private func sigil(at point: GridPoint, on plane: Plane) -> Color? {
        let state = session.engine.signState
        guard let mark = state.miasmaMarks.first(
            where: { $0.point == point && $0.plane == plane }
        ) else { return nil }
        return mark.isWarm ? Palette.orange : Palette.sky
    }

    /// One shard, standing in the hole it punched.
    ///
    /// Two copies of the same crystal, both always mounted. The hard-light one
    /// is what a shard *is* — it keeps the drawing's own shading and lets the
    /// board come through it, which is what reads as something you could see
    /// into. The additive one on top is what being live looks like, faded in
    /// rather than switched to: a shard that changed blend mode outright looked
    /// like a different object arriving.
    @ViewBuilder
    private func prong(
        _ pole: SignState.Prongs.Pole,
        lit: Bool,
        metrics: PixelArtMetrics
    ) -> some View {
        let height = metrics.tileSize * GameRules.prongHeight * GameRules.prongScale

        // **The descent is driven by the clock, not read off it.**
        //
        // The offset has to be recomputed every frame, so the timeline has to
        // wrap the thing being moved — a timeline drawing a sibling redraws the
        // sibling and nothing else, which is a still crystal beside a very busy
        // `Color.clear`.
        //
        // Paused when nothing is falling, so a standing shard costs the same as
        // any other sprite.
        TimelineView(.animation(paused: session.prongsFalling == nil || planeIsAsleep)) { timeline in
            #if DEBUG
            let _ = RenderTally.tick("Bd#5")
            #endif
            let falling: CGFloat = {
                guard let began = session.prongsFalling else { return 0 }
                let progress = min(
                    max(
                        timeline.date.timeIntervalSince(began)
                            / GameRules.prongFallDuration,
                        0
                    ),
                    1
                )
                // Eased in: it is being dropped, so it should still be gathering
                // speed when it lands.
                return -metrics.tileSize * GameRules.prongFallHeight
                    * (1 - progress * progress)
            }()

            ZStack {
                crystal(pole.element, height: height, lit: false, scale: metrics.scale)
                    .blendMode(.hardLight)

                crystal(pole.element, height: height, lit: true, scale: metrics.scale)
                    .blendMode(.plusLighter)
                    .opacity(lit ? 1 : 0)
                    .animation(.easeInOut(duration: GameRules.prongLightFade), value: lit)
            }
            .offset(y: falling)
        }
        .offset(y: -height / 2 + metrics.tileSize / 2 + GameRules.prongDrop * metrics.scale)
        .onBoard(pole.point, layer: .object, in: context(for: shown, metrics: metrics))
    }

    /// The crystal itself, at one of its two brightnesses.
    private func crystal(
        _ element: ZodiacElement,
        height: CGFloat,
        lit: Bool,
        scale: CGFloat
    ) -> some View {
        PaletteGlow(
            threshold: GameRules.prongGlowThreshold,
            radius: GameRules.prongGlow * scale,
            intensity: lit ? GameRules.prongLitGlow : GameRules.prongDimGlow
        ) {
            PixelSprite(id: .polarityProng(element)) { EmptyView() }
                .frame(width: height / 2, height: height)
        }
    }

    /// The live pole's pull, thrown over the whole board.
    ///
    /// **Deliberately outside the sorter.** It is not a thing standing on a
    /// square — it is a claim about the board, the way the action dim is — and
    /// a nine-tile ring cut off at the row in front of it would read as the
    /// pull stopping there. So it is drawn last, over everything, and takes its
    /// place from the shard rather than from a row.
    @ViewBuilder
    private func prongPulse(metrics: PixelArtMetrics) -> some View {
        if let prongs = session.engine.signState.prongs,
           prongs.plane == shown,
           // Nothing pulses on the way down: the rings are the tell for the
           // next pull, and there is no next pull until they land.
           session.prongsFalling == nil,
           let pole = prongs.poles.first(where: { $0.direction == prongs.active }) {

            TimelineView(.animation(paused: session.isPaused || planeIsAsleep)) { timeline in
                #if DEBUG
                let _ = RenderTally.tick("Bd#6")
                #endif
                // A fresh ring every `prongPulsePeriod`, from a clock rather
                // than from an event: nothing *happens* to start it, the pole
                // simply is the live one.
                let now = session.ambientClock(
                    at: timeline.date.timeIntervalSinceReferenceDate
                )
                let beat = (now / GameRules.prongPulsePeriod).rounded(.down)

                // **Points, not fractions.** The burst shader takes its centre
                // and radius in the view's own coordinates — a radius of `0.45`
                // is half a pixel, which is why there was nothing to see.
                let span = metrics.tileSize * GameRules.prongPulseSpan

                ElementalBurstView(
                    // The shape is Leo's; the colour is this crystal's.
                    kind: .polarityPulse(pole.element),
                    center: CGPoint(x: span / 2, y: span / 2),
                    radius: span * GameRules.prongPulseReach,
                    start: Date().addingTimeInterval(
                        -(now - beat * GameRules.prongPulsePeriod)
                    )
                )
                .frame(width: span, height: span)
            }
            // Off the shard's body rather than out of the ground behind it.
            .offset(y: -metrics.tileSize)
            .onBoard(pole.point, layer: .effect, in: context(for: shown, metrics: metrics))
            .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private func stingLance(metrics: PixelArtMetrics) -> some View {
        if let strike = session.stingStrike, strike.plane == shown {
            StingLanceView(
                direction: strike.direction,
                reach: strike.reach,
                tileSize: metrics.tileSize,
                start: strike.start
            )
            .modifier(placedOnPlaneModifier(strike.from, metrics: metrics))
        }
    }

    /// What each just-mended square is flashing, keyed by square.
    ///
    /// Read off the same list the motes come from, so the two halves of a mend
    /// are one event by construction rather than by two timers agreeing.
    private var healFlashes: [GridPoint: (ramp: [Color], strength: Double)] {
        var found: [GridPoint: (ramp: [Color], strength: Double)] = [:]
        let now = Date()

        for sparkle in session.healSparkles where sparkle.plane == shown {
            guard let tone = Palette.healFlash(
                elapsed: now.timeIntervalSince(sparkle.start)
            ) else { continue }
            found[sparkle.point] = tone
        }
        return found
    }

    /// Astra's mended squares, drawn as views so the flash can swap their ramp.
    ///
    /// The field skips these — a `Canvas` cannot run the palette shader, and a
    /// flat tint would iron the cloud into a silhouette. Same arrangement as the
    /// lifted square.
    @ViewBuilder
    private func healFlashClouds(plane: Plane, metrics: PixelArtMetrics) -> some View {
        if plane == .astra, CloudSpriteField.hasArt {
            let board = session.visibleBoard
            ForEach(Array(healFlashes.keys), id: \.self) { point in
                if board.contains(point), board[point].kind == .normal,
                   !board[point].health.isHole {
                    CloudSpriteView(
                        point: point,
                        health: board[point].health,
                        metrics: metrics,
                        clock: session.ambientClock(at:),
                        wake: cloudWake,
                        bounce: surfaceBounce,
                        healFlash: healFlashes[point]
                    )
                    .modifier(placedOnPlaneModifier(point, metrics: metrics))
                }
            }
        }
    }

    /// What Stubborn Statue looks like up here.
    ///
    /// **A second copy of the cloud, and nothing else.** Grass is Terra's; the
    /// same cover on Astra needed a picture of its own, and the honest one is
    /// the square itself lighting up rather than a plant growing out of a cloud.
    /// So each covered square is drawn again as its own silhouette in jade,
    /// breathing, and added to the light already there.
    ///
    /// Drawn only for the squares that have it. The overlay is meant to be a
    /// general thing — a spare layer on every cloud, waiting for whatever wants
    /// it next — and forty-nine invisible cloud sprites is a real cost for a
    /// layer nothing is using, so it arrives with its reason and leaves with it.
    @ViewBuilder
    private func statueClouds(plane: Plane, metrics: PixelArtMetrics) -> some View {
        if plane == .astra, CloudSpriteField.hasArt {
            let board = session.visibleBoard
            let covered = board.allPoints.filter {
                board[$0].cover != nil && board[$0].kind == .normal
                    && !board[$0].health.isHole
            }

            // No cover, no overlay, no timeline asking to be woken sixty times
            // a second to draw nothing.
            if !covered.isEmpty {
            TimelineView(.animation(paused: session.isPaused || planeIsAsleep)) { timeline in
                #if DEBUG
                let _ = RenderTally.tick("Bd#7")
                #endif
                let now = session.ambientClock(
                    at: timeline.date.timeIntervalSinceReferenceDate
                )
                // Slow, and never all the way out: a breath that reaches zero
                // reads as a flicker rather than as something alive.
                let breath = (1 - cos(now / GameRules.statueCloudPeriod * 2 * .pi)) / 2
                let strength = GameRules.statueCloudFaintest
                    + (GameRules.statueCloudBrightest - GameRules.statueCloudFaintest)
                    * breath

                ForEach(covered, id: \.self) { point in
                    CloudSpriteView(
                        point: point,
                        health: board[point].health,
                        metrics: metrics,
                        clock: session.ambientClock(at:),
                        wake: cloudWake,
                        bounce: surfaceBounce
                    )
                    .colorEffect(ShaderLibrary.flatSilhouette(.color(Palette.jade)))
                    .opacity(strength)
                    // Hard light rather than additive: adding jade to a cloud
                    // already lit pink arrives at white, which is the one colour
                    // that says nothing about whose ability this is.
                    .blendMode(.hardLight)
                    .modifier(placedOnPlaneModifier(point, metrics: metrics))
                }
            }
            .allowsHitTesting(false)
            }
        }
    }

    /// Every square that was just mended, shimmering. See `HealSparkleView`.
    private func healSparkles(metrics: PixelArtMetrics) -> some View {
        ForEach(session.healSparkles.filter { $0.plane == shown }) { sparkle in
            HealSparkleView(
                start: sparkle.start,
                tileSize: metrics.tileSize,
                // Seeded off the square, so two tiles mended at once throw
                // different motes instead of the same picture twice.
                seed: sparkle.point.x &* 31 &+ sparkle.point.y
            )
            .frame(width: metrics.tileSize * 2, height: metrics.tileSize * 2)
            .modifier(placedOnPlaneModifier(sparkle.point, metrics: metrics))
        }
    }

    /// Capricorn's takings, on their way off the board.
    ///
    /// Aimed at the bottom edge rather than at the strip's real position: the
    /// strip is not on screen when a coin is banked, and the point of the arc is
    /// that the money went *down there*. See `BankArcView`.
    @ViewBuilder
    private func bankArc(metrics: PixelArtMetrics) -> some View {
        if let arc = session.bankArc, arc.plane == shown {
            BankArcView(
                from: metrics.center(of: arc.from),
                to: CGPoint(x: metrics.boardSize / 2, y: metrics.boardSize),
                start: arc.start,
                tileSize: metrics.tileSize
            )
            .frame(width: metrics.boardSize, height: metrics.boardSize)
        }
    }

    /// The wash that says the game is waiting on an answer.
    ///
    /// ## Where it sits
    ///
    /// Over the whole upper square, sky and letterboxing included — the pause is
    /// about the *view*, not about the grid — but under the piece and the
    /// cursor, which are the two things the player is still working with. Dimmed
    /// ground with a bright cursor over it says exactly what is true: the board
    /// is on hold and the thing you are moving is not.
    ///
    /// Sized past the board and reported back at board size, so it can cover the
    /// sky without growing the stack it lives in and shifting everything that
    /// positions itself inside — the same arrangement `CloudSpriteField` needs,
    /// and for the same reason.
    ///
    /// Deeper than the action wash, and a different colour, because it means
    /// something different: an action is over in a moment, and this is not over
    /// until the player does something.
    private func boardDim(metrics: PixelArtMetrics) -> some View {
        Rectangle().fill(Palette.midnight)
            .frame(width: availableSide, height: availableSide)
            // One question, whatever the reason — see `GameSession.isDimmed`.
            .opacity(session.isDimmed ? GameRules.boardDim : 0)
            .animation(.easeOut(duration: 0.18), value: session.isDimmed)
            .allowsHitTesting(false)
            .frame(width: metrics.boardSize, height: metrics.boardSize)
    }

    /// The wash that says the board is mid-move.
    @ViewBuilder
    private func actionDim(metrics: PixelArtMetrics) -> some View {
        Rectangle()
            .fill(Palette.coolBlack)
            .frame(width: metrics.boardSize, height: metrics.boardSize)
            // Drawn three times its size, but **laid out** at one.
            //
            // Framing it larger grew the stack it sits in, and everything in
            // that stack is placed with `.position` — which is measured against
            // the container. The board kept its own frame, so the damage showed
            // up as objects flung toward a corner rather than as a bigger board.
            // `scaleEffect` does not touch layout, so the dim can cover the
            // screen without moving anything that shares the stack with it.
            .scaleEffect(3)
            .opacity(session.isResolvingAction ? GameRules.actionDim : 0)
            .animation(.easeOut(duration: 0.14), value: session.isResolvingAction)
            .allowsHitTesting(false)
    }

    /// The plane's background, when there is art for it.
    ///
    /// No fallback fill. `SkyView` is already behind the whole upper square —
    /// Astra's starfield, Terra's daylight — and a flat tinted rectangle here
    /// covered it up, boxing the cloud grid inside a square that should not be
    /// visible at all.
    @ViewBuilder
    private func backdrop(plane: Plane, metrics: PixelArtMetrics) -> some View {
        if SpriteLoader.hasAsset(for: .planeBackground(plane)) {
            PixelSprite(id: .planeBackground(plane)) { Color.clear }
                .frame(width: metrics.boardSize, height: metrics.boardSize)
                .animation(.easeInOut(duration: 0.25), value: plane)
        }
    }

    /// Pass one: every tile's edge, pushed down so its visible sliver sits at
    /// the bottom of the square, ready to be uncovered.
    @ViewBuilder
    private func edgeLayer(board: Board, plane: Plane, metrics: PixelArtMetrics) -> some View {
        // Cloud has no side to reveal, so Astra skips the pass entirely rather
        // than laying down strips nothing will ever uncover.
        if plane == .terra {
            ForEach(board.allPoints, id: \.self) { point in
                TileEdgeView(plane: plane, shade: .at(point), size: metrics.tileSize)
                    .modifier(placedOnPlaneModifier(point, metrics: metrics))
                    .offset(y: GameRules.tileEdgeDrop * metrics.scale)
            }

            // The front face of the board itself.
            //
            // Every other row's edge is hidden by the row in front of it and
            // only shows when a tile lifts. The last row has nothing in front of
            // it, so its side was never drawn at all and the plane ended in a
            // flat line — a picture of a slab rather than a slab. This is the
            // same strip, dropped just far enough to sit flush underneath.
            ForEach(board.allPoints.filter { $0.y == board.size - 1 }, id: \.self) { point in
                TileEdgeView(plane: plane, shade: .at(point), size: metrics.tileSize)
                    .modifier(placedOnPlaneModifier(point, metrics: metrics))
                    .offset(y: GameRules.tileFrontEdgeDrop * metrics.scale)
            }
        }
    }

    /// The disturbance the sky is currently reacting to, if any.
    ///
    /// Converted here rather than kept in the session's own terms because the
    /// drawing works in elapsed seconds off one clock, and a `Date` would have
    /// to be differenced against it on every cloud, every frame.
    private var cloudWake: CloudMotion.Wake? {
        session.cloudWake.map {
            CloudMotion.Wake(
                point: $0.point,
                start: $0.start.timeIntervalSinceReferenceDate
            )
        }
    }

    /// The landing the surface is currently giving under, if any.
    private var surfaceBounce: CloudMotion.Bounce? {
        guard let bounce = session.surfaceBounce,
              bounce.plane == shown
        else { return nil }

        return CloudMotion.Bounce(
            point: bounce.point,
            start: bounce.start.timeIntervalSinceReferenceDate
        )
    }

    /// How far the surface of `point` has wandered from its square right now.
    ///
    /// **Anything standing on a square offsets by this.** A cloud that drifts
    /// out from under the sparkle marking it, or the coin sitting on it, or the
    /// piece, reads as the board coming apart — a square and the things on it
    /// have to move as one object.
    ///
    /// Reads `CloudMotion`, which is the same description the cloud is drawn
    /// from. That is the whole point: a second copy of this maths drifts apart
    /// the first time either is retuned, which is exactly what had happened —
    /// the piece was still swaying on the generated cluster's old curve while
    /// the sprites moved on a new one, and nothing else swayed at all.
    ///
    /// Zero on Terra, where the ground is stone and holds still, and zero on the
    /// island and its chasm for the same reason.
    /// - Parameter driftScale: Damps the idle wander only. The piece uses this
    ///   to ease its footing back in after a hop — but a landing's give and a
    ///   fall's shove are impacts, and an impact that faded in would be no
    ///   impact at all.
    private func surfaceSway(
        of point: GridPoint,
        at date: Date,
        metrics: PixelArtMetrics,
        driftScale: CGFloat = 1
    ) -> CGSize {
        guard shown == .astra,
              session.visibleBoard.contains(point),
              session.visibleBoard[point].kind == .normal
        else { return .zero }

        // Drift on the ambient clock, impacts on the wall clock — see
        // `CloudMotion.init`. A shove set off *by* the action the ambient clock
        // is stopped for cannot be timed against that stopped clock.
        let wall = date.timeIntervalSinceReferenceDate
        let now = session.ambientClock(at: wall)

        let drift = CloudMotion.shift(point, now: now, scale: metrics.scale)
        let shove = CloudMotion.shove(
            point, wake: cloudWake, now: wall, scale: metrics.scale
        )
        let give = CloudMotion.dip(
            point, bounce: surfaceBounce, now: wall, scale: metrics.scale
        )

        return CGSize(
            width: drift.width * driftScale + shove.width,
            height: drift.height * driftScale + shove.height + give
        )
    }

    /// The preview riding the last tile down into the board.
    ///
    /// Drawn here rather than in `TileChoiceOverlay` because the choice is over
    /// by now — the overlay goes with it, and the phantom has to outlive its own
    /// question to be seen arriving. See `GameSession.SlabDrop`.
    @ViewBuilder
    private func slabDrop(metrics: PixelArtMetrics) -> some View {
        if let drop = session.slabDrop, drop.plane == shown {
            TimelineView(.animation(paused: planeIsAsleep)) { timeline in
                #if DEBUG
                let _ = RenderTally.tick("Bd#8")
                #endif
                let elapsed = timeline.date.timeIntervalSince(drop.start)
                let arrival = min(max(elapsed / GameRules.slabDropDuration, 0), 1)

                SlabPhantomView(
                    slab: drop.slab,
                    metrics: metrics,
                    plane: drop.plane,
                    anchor: drop.anchor,
                    arrival: arrival
                )
            }
            .allowsHitTesting(false)
        }
    }

    /// The squares a slab has just landed on, outlined while they settle.
    ///
    /// The same white the rest of Libra's work is marked in. A slab that simply
    /// became ground on the next frame threw away the one moment the ability is
    /// about — this says *these squares, just now, because of you*.

    @ViewBuilder
    private func slabLanding(metrics: PixelArtMetrics) -> some View {
        if let landing = session.slabLanding, landing.plane == shown {
            ZStack {
                ForEach(Array(landing.points), id: \.self) { point in
                    Rectangle()
                        .strokeBorder(Palette.white, lineWidth: GameRules.slabOutline)
                        .frame(width: metrics.tileSize, height: metrics.tileSize)
                        .modifier(placedOnPlaneModifier(point, metrics: metrics))
                }
            }
            .frame(width: metrics.boardSize, height: metrics.boardSize)
            .transition(.opacity)
            .allowsHitTesting(false)
        }
    }

    /// The direction guide, in the board's bottom-left corner.
    private func compass(metrics: PixelArtMetrics) -> some View {
        CompassView(facing: session.visibleFacing, tileSize: metrics.tileSize)
            // Faded when the piece is standing under it.
            //
            // It only overlaps on one square, and the honest answer is neither
            // to hide it nor to let it sit on top of the player: it is a label,
            // so it gets out of the way of the thing it is labelling.
            .opacity(session.engine.piece.point == compassCorner
                ? GameRules.compassFaded
                : 1)
            .animation(.easeOut(duration: 0.2), value: session.engine.piece.point)
            .offset(
                x: metrics.tileSize * GameRules.compassInset,
                y: -metrics.tileSize * GameRules.compassInset
            )
            .allowsHitTesting(false)
    }

    /// How far in the camera leans, given where the piece is standing.
    ///
    /// The near row is the resting framing; every row further back pushes in a
    /// little more, smoothly. Perspective costs the far rows their size, and a
    /// player who has walked to the back of the board should not have to watch
    /// their own turn happen at a distance — so the camera follows them in.
    ///
    /// Deliberately gentle, and bounded by the room the board has inside its
    /// square: the whole board stays visible from every row. This is a lean,
    /// not a chase.
    /// One row of Terra, laid down: its tiles, its edges, its lifted square.
    ///
    /// **Drawn from the object list, with everything standing on that row.**
    /// The band used to be a pass of its own that ran before the objects, so
    /// every object was above every row of ground no matter how far apart
    /// they stood — which is why anything hanging past the bottom of its own
    /// square landed on the row in front instead of behind it. Sorted with
    /// the rest, row four's ground covers row three's overhang, which is the
    /// whole reason the board is drawn a row at a time. See `BoardBand`.
    private func bandRow(
        _ row: Int,
        board: Board,
        plane: Plane,
        metrics: PixelArtMetrics
    ) -> some View {
        // **Values in, and then left alone.**
        //
        // The ground moved into the object list so it could interleave with the
        // things standing on it, and the object list lives inside the board's
        // animation timeline — so all forty-nine squares were being rebuilt
        // sixty times a second for a board that changes once a move. The row is
        // its own `Equatable` view now: hand it what it draws from and SwiftUI
        // skips it on every frame where none of that moved.
        BandRow(
            row: row,
            board: board,
            plane: plane,
            metrics: metrics,
            raised: Set(session.visibleRaisedTiles.map(\.point)),
            flashing: session.flashingTiles,
            pressed: session.pressedTiles
        )
        .equatable()
    }

    /// Placed on the plane the piece is standing on.
    /// Standing on a square.
    ///
    /// The same note as `groundMark`: this is the old name for what
    /// `onBoard(_:layer:in:)` now does, kept so the board's existing call sites
    /// keep working while new ones use the layer.
    func placedOnPlaneModifier(_ point: GridPoint, metrics: PixelArtMetrics) -> some ViewModifier {
        PlacedOnPlane(point: point, metrics: metrics, framing: planeFraming(shown))
    }

    /// A mark painted on a square — the cursor, the facing arrow.
    ///
    /// **Terra only takes the band.** `asBoardSquare` is built from
    /// `BoardBand`, which is Terra's geometry and nothing else: Terra's camera,
    /// Terra's lift, no spacing. Putting Astra's marks through it placed them by
    /// Terra's rows while every other thing on the plane used Astra's framing,
    /// and the two diverge furthest at the back — which is where the arrow's
    /// offset came apart and the cursor floated off the board.
    ///
    /// Astra has no bands to take. Its ground is scale and place, so a mark on
    /// it is placed exactly like anything else standing there, plus the slight
    /// stand-up that a cloud's mound wants.
    @ViewBuilder
    /// A mark lying on the ground.
    ///
    /// **Kept as a name, not as a second implementation.** Twenty-odd call
    /// sites use it, and rewriting all of them at once is how a working board
    /// gets broken; what matters is that there is one answer underneath. New
    /// things should call `onBoard(_:layer:in:)` directly — see `BoardLayer`.
    private func groundMark<V: View>(
        _ view: V,
        at point: GridPoint,
        metrics: PixelArtMetrics,
        squashed: Bool = true
    ) -> some View {
        if shown == .terra {
            view.asBoardSquare(point, metrics: metrics, squashed: squashed)
        } else {
            // Still in the tile layer — same squash, same lean, so it reads as
            // painted on the cloud rather than standing on it. Only the
            // *placement* comes from Astra, because that is the half Terra's
            // bands cannot answer for another plane.
            view
                .shapedAsGround(
                    row: point.y,
                    metrics: metrics,
                    stretch: GameRules.astraMarkStretch,
                    squashed: squashed
                )
                .modifier(placedOnPlaneModifier(point, metrics: metrics))
        }
    }

    /// The arrow's lift for the way it is pointing, on the plane it is on.
    ///
    /// - TODO: **Temporary.** Fold the four into `GameRules`.
    /// The arrow's lift. **Not** split by axis — measuring said east-west and
    /// north-south want the same number, once the arrow stopped being
    /// foreshortened twice.
    private var arrowLift: CGFloat {
        GameRules.facingArrowLift
            + (shown == .astra ? GameRules.facingArrowAstraLift : 0)
    }

    /// The per-row half, in art pixels: full at the far row, none at the near.
    private func arrowDepthLift(at point: GridPoint, metrics: PixelArtMetrics) -> CGFloat {
        let back = 1 - CGFloat(point.y) / CGFloat(max(metrics.gridSize - 1, 1))
        return GameRules.facingArrowDepthLift * back
    }


    /// How much a mark's lift must grow on `point`'s row to stay the height it
    /// is on the near one.
    ///
    /// The near row's scale over this row's — so the front of the board is left
    /// exactly as it was and every row behind is handed back what the
    /// perspective took off it.
    private func liftBoost(at point: GridPoint, metrics: PixelArtMetrics) -> CGFloat {
        let near = rowScale(
            at: GridPoint(point.x, metrics.gridSize - 1), metrics: metrics
        )
        let here = rowScale(at: point, metrics: metrics)
        guard here > 0 else { return 1 }
        // Squared — see `GameRules.facingArrowRowPower`.
        return pow(near / here, GameRules.facingArrowRowPower)
    }

    /// How much its row shrinks whatever stands on `point`.
    ///
    /// Needed because an `.offset` applied *after* a placement is in screen
    /// points, not board ones — the placement's own `scaleEffect` has already
    /// happened, so the offset never shrinks with the row. A lift of four
    /// pixels is four pixels on the near row and four on the far one, which is
    /// why the marks came apart from their squares at the back of the board.
    private func rowScale(at point: GridPoint, metrics: PixelArtMetrics) -> CGFloat {
        let framing = planeFraming(shown)
        return metrics.projected(
            point,
            zoom: framing.zoom,
            lift: framing.lift,
            emphasis: framing.emphasis,
            pivot: framing.pivot,
            spacing: framing.spacing
        ).scale
    }

    /// Puts an object on its square, on whichever plane's camera it stands.
    ///
    /// Terra is the true camera; Astra is allowed its own taper, size and
    /// height because nothing up there has to tile. Everything that stands on
    /// a square goes through here, so the two can never drift apart.
    /// What the board tells everything drawn on it. See `BoardContext`.
    ///
    /// Built once per plane and handed down, so a thing being placed states only
    /// what is true about itself — its square, its layer, how it moves — and
    /// nothing about the board it happens to be standing on.
    private func context(for plane: Plane, metrics: PixelArtMetrics) -> BoardContext {
        BoardContext(
            metrics: metrics,
            plane: plane,
            framing: planeFraming(plane),
            bounce: { point in
                CloudMotion.dip(
                    point,
                    bounce: surfaceBounce,
                    now: Date().timeIntervalSinceReferenceDate,
                    scale: metrics.scale
                )
            },
            clock: session.ambientClock(at:)
        )
    }

    private func planeFraming(
        _ plane: Plane
    ) -> (emphasis: CGFloat, zoom: CGFloat, lift: CGFloat, pivot: CGFloat, spacing: CGSize) {
        plane == .astra
            ? (GameRules.astraDepthEmphasis,
               GameRules.astraForeshortenScale,
               GameRules.astraForeshortenLift,
               GameRules.astraDepthPivot,
               CGSize(width: GameRules.cloudSpacingX, height: GameRules.cloudSpacingY))
            : (1,
               GameRules.boardForeshortenScale,
               GameRules.boardForeshortenLift,
               1,
               CGSize(width: 1, height: 1))
    }

    /// The square the compass sits over: bottom-left of the board.
    private var compassCorner: GridPoint {
        GridPoint(0, session.visibleBoard.size - 1)
    }

    /// Squares whose cloud must not be lapped over by its row neighbours.
    ///
    /// The piece's own square above all: standing on ground you cannot see is
    /// the one thing the overlap must never cost. The lifted squares join it,
    /// because a Pentacle hovering behind the cloud beside it looks like a
    /// Pentacle on a different square.
    private func occupiedSquares(on plane: Plane, popped: Set<GridPoint>) -> Set<GridPoint> {
        var points = popped
        if session.engine.piece.plane == plane {
            points.insert(session.engine.piece.point)
        }
        return points
    }

    /// Pass two: the flat faces.
    ///
    /// The lifted tile is **not** drawn here — it stands proud of the floor, so
    /// it is a `BoardObject` and gets depth-sorted with the island and the piece.
    /// Leaving a gap is correct: a face lifted by 4px uncovers exactly the 4px
    /// edge strip laid down in pass one.
    private func faceLayer(board: Board, plane: Plane, metrics: PixelArtMetrics) -> some View {
        // The raised squares, which are not necessarily the coins' — Leo's sun
        // can drag a Pentacle off the tile that popped up for it.
        let popped = Set(session.visibleRaisedTiles.map(\.point))

        // **Nothing here on Astra any more.**
        //
        // Its clouds and its squares are drawn a row at a time inside the sorted
        // stack now — see `cloudRow` — because a ground pass that runs before
        // that stack can never be in front of anything in it. Left as the mount
        // for the placeholder field, which has no row-by-row version and is only
        // ever seen when the sheet is missing.
        return ZStack {
            if plane == .astra, LayerBench.shared.clouds, !CloudSpriteField.hasArt {
                CloudFieldView(
                    board: board,
                    metrics: metrics,
                    flashing: session.flashingTiles,
                    freeze: session.ambientClock(at: Date().timeIntervalSinceReferenceDate),
                    excluding: popped,
                    isPaused: session.isPaused,
                    emphasis: GameRules.astraDepthEmphasis,
                    zoom: GameRules.astraForeshortenScale,
                    lift: GameRules.astraForeshortenLift
                )
            }
        }
    }

    /// One row of Astra: its clouds, and the squares the clouds do not cover.
    ///
    /// Astra's answer to `bandRow`. It has no bands — a cloud is a loose shape
    /// rather than a tile that has to meet its neighbours — so there is nothing
    /// to shear or stretch. What it needs from the row is only that it be *drawn*
    /// with it, so the sort can put the row in front of it over the top.
    @ViewBuilder
    private func cloudRow(_ row: Int, board: Board, metrics: PixelArtMetrics) -> some View {
        let popped = Set(session.visibleRaisedTiles.map(\.point))

        ZStack {
            if LayerBench.shared.clouds, CloudSpriteField.hasArt {
                CloudSpriteField(
                    board: board,
                    metrics: metrics,
                    flashing: session.flashingTiles,
                    raised: popped,
                    // Whatever is being stood on or hovered over has to stay
                    // clear of its neighbours' overlap.
                    mending: Set(healFlashes.keys),
                    occupied: occupiedSquares(on: .astra, popped: popped),
                    clock: session.ambientClock(at:),
                    wake: cloudWake,
                    bounce: surfaceBounce,
                    emphasis: GameRules.astraDepthEmphasis,
                    zoom: GameRules.astraForeshortenScale,
                    lift: GameRules.astraForeshortenLift,
                    row: row
                )
                // Skipped entirely when nothing about it has changed — see
                // `CloudSpriteField ==`, which compares the row too.
                .equatable()
            }

            faces(board: board, plane: .astra, metrics: metrics, popped: popped, row: row)
        }
    }

    /// One view per square, for everything the cloud field does not cover.
    ///
    /// Astra only now. Terra's squares are drawn inside their row's band, which
    /// is the only way a grid tiles without seams — see `bandRow`.
    private func faces(
        board: Board,
        plane: Plane,
        metrics: PixelArtMetrics,
        popped: Set<GridPoint>,
        row: Int? = nil
    ) -> some View {
        let squares = board.allPoints.filter {
            !popped.contains($0) && (row == nil || $0.y == row)
        }
        return ForEach(squares, id: \.self) { point in
            TileView(
                tile: board[point],
                plane: plane,
                shade: .at(point),
                size: metrics.tileSize,
                // Never raised: a popped square is excluded from this pass and
                // drawn by `raisedTile`, so it can depth-sort with the pieces.
                isPopped: false,
                isFlashing: session.flashingTiles.contains(point),
                healFlash: healFlashes[point],
                isPressed: session.pressedTiles.contains(point),
                point: point,
                // Handed in here too, not only in the band. Terra's squares got
                // their mark from `bandRow` and Astra's got none at all, which
                // is why the Miasma marked nothing up there.
                sigil: sigil(at: point, on: plane),
                drawnByField: plane == .astra
            )
            .modifier(placedOnPlaneModifier(point, metrics: metrics))
        }
    }

    /// Gemini's mirrors.
    ///
    /// Astra always, and Terra once the Zodiaction has torn them open down there
    /// — `SignState.terraRifts`. They were gated to Astra alone, so popping the
    /// super on Terra set the flag, opened the doorways, and drew nothing at
    /// all: the ability worked and was invisible, which is indistinguishable
    /// from it not working.
    @ViewBuilder
    private func mirrors(plane: Plane, metrics: PixelArtMetrics) -> some View {
        // Above they are innate and never close; below, only the pairs that are
        // still open are drawn — using one shuts that doorway and leaves the
        // other standing.
        let open: SignState.RiftAxes = plane == .astra
            ? .both
            : session.engine.signState.terraRifts

        // Drawn for Gemini, and for whoever inherits the rifts afterwards.
        if session.zodiac == .gemini || session.engine.signState.riftsLinger, !open.isEmpty {
            ReflectiveRiftsView(
                metrics: metrics,
                accent: session.zodiac.definition.accentColor,
                open: open
            )
                .frame(width: metrics.boardSize, height: metrics.boardSize)
        }
    }

    /// The drawn effect strips currently playing, each over the square that set
    /// it off.
    private func effectBurst(metrics: PixelArtMetrics) -> some View {
        ForEach(session.effectBursts.filter { $0.plane == shown }) { burst in
            EffectSpriteView(
                effect: burst.effect,
                tileSize: metrics.tileSize,
                start: burst.start,
                tint: burst.tint,
                swaps: burst.swaps
            )
            .scaleEffect(x: burst.mirrored ? -burst.scale : burst.scale, y: burst.scale)
            .rotationEffect(.degrees(burst.angle))
            // Lit for the ones that are made of light rather than of matter —
            // a firework and a gathered coin's sparkle both throw light on the
            // board around them, and a flat strip does not.
            .modifier(BurstGlow(on: burst.glows, radius: GameRules.burstGlow * metrics.scale))
            .modifier(placedOnPlaneModifier(burst.center, metrics: metrics))
        }
    }

    /// The elemental colour the star is washing the piece with, or `nil` when
    /// no star is running.
    ///
    /// Steps rather than blends: four flat colours in turn reads as a flicker
    /// between elements, which is what this is, where a smooth interpolation
    /// would spend most of its time on colours that belong to no element at all.
    private func starElement(at date: Date) -> ZodiacElement? {
        guard session.engine.signState.isStarred else { return nil }

        let elements = ZodiacElement.allCases
        let elapsed = date.timeIntervalSinceReferenceDate / GameRules.starCyclePeriod
        let step = Int(elapsed * Double(elements.count)) % elements.count

        return elements[step]
    }

    /// The lunge at a move that was refused.
    ///
    /// Out and back on one curve, so there is no state to unwind: a single sine
    /// over the attempt's duration leaves the piece exactly where it started,
    /// whatever happens next.
    private func balk(at date: Date, metrics: PixelArtMetrics) -> CGSize {
        guard let started = session.balkStartedAt,
              let direction = session.balkDirection
        else { return .zero }

        let elapsed = date.timeIntervalSince(started) / GameRules.balkDuration
        guard elapsed >= 0, elapsed <= 1 else { return .zero }

        let push = sin(elapsed * .pi) * GameRules.balkDistance * metrics.scale
        let step = direction.unitOffset

        return CGSize(width: CGFloat(step.dx) * push, height: CGFloat(step.dy) * push)
    }

    /// How far a piece standing over a hole has drifted, in art pixels.
    ///
    /// `0` whenever there is ground underfoot, which is the ordinary case — the
    /// only way to be here is the Astral Bolt's star or Scorpio's hover.
    private func hoverBob(at date: Date) -> CGFloat {
        let piece = session.engine.piece
        guard piece.plane == shown, !session.isFalling else { return 0 }
        // Nothing to hover over once carried off the edge — and no tile to
        // ask about either, which is what crashed here.
        guard let under = session.visibleBoard.tile(at: piece.point) else { return 0 }
        guard !under.isSolid else { return 0 }

        let phase = date.timeIntervalSinceReferenceDate
            / GameRules.hoverBobPeriod * 2 * .pi
        return CGFloat(sin(phase)) * GameRules.hoverBob
    }

    /// How hard the piece is flashing right now.
    ///
    /// Eases out rather than in: a charge is a hit, so the colour arrives all at
    /// once and leaves gradually.
    private func chargeFlash(at date: Date) -> Double {
        guard let started = session.chargeFlashStartedAt else { return 0 }

        let elapsed = date.timeIntervalSince(started) / GameRules.chargeFlashDuration
        guard elapsed >= 0, elapsed <= 1 else { return 0 }

        return GameRules.chargeFlashStrength * (1 - elapsed) * (1 - elapsed)
    }

    /// The cloud an arrow is riding down out of Astra.
    @ViewBuilder
    private func fallingCloud(metrics: PixelArtMetrics) -> some View {
        if let falling = session.fallingCloud, falling.plane == shown {
            FallingCloudView(point: falling.point, metrics: metrics, start: falling.start)
                .id(falling.id)
        }
    }

    /// Sagittarius' arrow, standing in the square it chose.
    @ViewBuilder
    private func arrow(metrics: PixelArtMetrics) -> some View {
        if let planted = session.visibleArrow {
            // **The island's float.** A planted arrow rises and falls exactly
            // as the Nexys does, and said so in its own code — one more curve
            // describing a motion that already had a name.
            ArrowView(tileSize: metrics.tileSize, scale: metrics.scale,
                      clock: session.ambientClock(at:))
                .onBoard(
                    planted.point,
                    layer: .object,
                    in: context(for: shown, metrics: metrics),
                    hover: .island
                )
                .transition(.scale(scale: 0.3).combined(with: .opacity))
        }
    }

    /// Leo's sun, burning over its square for as long as it lasts.
    @ViewBuilder
    private func sun(metrics: PixelArtMetrics) -> some View {
        if let burning = session.visibleSun {
            SunView(sun: burning, tileSize: metrics.tileSize)
                .modifier(placedOnPlaneModifier(burning.point, metrics: metrics))
        }
    }

    /// The ground Cancer's Bubble Bastion is holding, if one is standing.
    @ViewBuilder
    private func sanctuary(plane: Plane, metrics: PixelArtMetrics) -> some View {
        if let standing = session.engine.signState.sanctuary, standing.plane == plane {
            SanctuaryView(sanctuary: standing, metrics: metrics)
        }
    }

    @ViewBuilder
    private func sparkles(metrics: PixelArtMetrics) -> some View {
        if let set = session.visibleSparkles {
            // A plain `ForEach`, sitting directly in the board-sized stack.
            //
            // The drift is handed to the sparkle as a closure and applied inside
            // its own clock — see `SparkleView.sway`. Wrapping these in a
            // `TimelineView` to get a fresh offset instead put a container
            // between them and the board, and `.position` resolves against
            // whatever encloses it: they were laid out inside a box the size of
            // whatever they happened to add up to, and landed off the grid.
            ForEach(Array(set.points.enumerated()), id: \.element) { index, point in
                ZStack {
                    glowSparkle(at: point, index: index, set: set, metrics: metrics)

                    // **The Stardar's promise, drawn on the winner.**
                    //
                    // Over the sparkle rather than replacing it: the square is
                    // still a candidate doing what candidates do, and the extra
                    // shine is the coin telling you which one pays.
                    if set.marked == point {
                        EffectSpriteView(
                            effect: .sparkles,
                            tileSize: metrics.tileSize,
                            start: .distantPast,
                            loops: true,
                            clock: session.ambientClock(at:)
                        )
                    }
                }
                .modifier(placedOnPlaneModifier(point, metrics: metrics))
                .offset(GameRules.sparkleNudge)
            }
            .transition(.opacity)
        }
    }

    /// One square of the glow phase.
    ///
    /// The drawn strips when they are there, the generated shimmer when they are
    /// not — the same rule every placeholder in this game follows.
    ///
    /// Two strips rather than one: `glowPhase` is the light coming off the tile
    /// and `sparkles` is what is dancing in it. They are separate because they
    /// are wanted separately — the sparkles are reusable anywhere something
    /// should look magical, and welding them into the phase would mean drawing
    /// them twice.
    ///
    /// Each square is started a little later than the one before it, off its own
    /// index. Five squares lighting in unison read as one object blinking; a
    /// stagger reads as a phase sweeping the board, which is what it is.
    @ViewBuilder
    private func glowSparkle(
        at point: GridPoint,
        index: Int,
        set: SparkleSet,
        metrics: PixelArtMetrics
    ) -> some View {
        // The generated shimmer, deliberately.
        //
        // The drawn strips were tried and they are too much: a glow phase is a
        // question — *one of these five* — and art loud enough to be the answer
        // makes the board look like it has already resolved. The break is still
        // drawn, because that moment *is* a resolution.
        SparkleView(
            size: metrics.tileSize,
            plane: shown,
            index: index,
            tint: set.pattern == .ring ? Palette.pink : nil,
            sway: { surfaceSway(of: point, at: $0, metrics: metrics) },
            clock: session.ambientClock(at:)
        )
    }

    /// The destination cursor.
    ///
    /// While a drag is in progress it projects the *drag vector* rather than the
    /// piece's facing, so the player aims with the cursor and commits by
    /// releasing — changing the vector re-aims without costing a move.
    ///
    /// Rides whatever it is marking: a raised tile lifts it, and the island lifts
    /// *and* drifts it. A cursor that stayed flat while the thing under it moved
    /// would read as sitting inside that thing rather than on top of it.
    private func cursor(
        at point: GridPoint,
        metrics: PixelArtMetrics,
        bob: CGFloat,
        corners: [CursorCorner],
        showsWarning: Bool
    ) -> some View {
        let cursor = projectedCursor
        return groundMark(
            CursorView(
                status: cursor.status,
                size: metrics.tileSize,
                scale: metrics.scale,
                corners: corners,
                showsWarning: showsWarning
            ),
            at: point,
            metrics: metrics
        )
            // A mark painted on the floor, not a thing standing on it — so it
            // takes the row's squash and lean like any other ground, on both
            // planes. Placing it as an object is what kept it looking like a
            // sticker laid flat over a board that is lying down.
            // In board pixels, brought back to screen ones by the row.
            .offset(
                y: (-GameRules.cursorLift * metrics.scale
                    - nexysCursorLift(at: point, metrics: metrics)
                    + surfaceOffset(of: point, bob: bob, metrics: metrics))
                    * rowScale(at: point, metrics: metrics)
            )
            .animation(.spring(response: 0.18, dampingFraction: 0.8), value: point)
    }

    /// Where the cursor currently points, and what it is sitting on.
    ///
    /// While a question about a square is open the cursor stops projecting a
    /// move and starts reporting the answer being aimed at — anywhere on the
    /// board, green where the question would accept it and red where it would
    /// not. Those are different questions and the cursor can only answer one of
    /// them at a time.
    private var projectedCursor: GameEngine.Cursor {
        if session.isChoosingTile {
            let aim = session.targetAim ?? session.engine.piece.point
            return GameEngine.Cursor(
                point: aim,
                status: .targeting(legal: session.isLegalTarget(aim))
            )
        }
        return session.engine.cursor(
            direction: session.previewDirection,
            reach: session.previewReach
        )
    }

    /// The extra lift the cursor needs on the island's own square.
    ///
    /// The island's drawn surface is not quite where `GameRules.nexysRaise`
    /// says it is, so a mark placed by that number alone sits a pixel or two
    /// low. It has always done so — the flat sprite has the same discrepancy —
    /// and it shows up on the cursor rather than on the piece because the piece
    /// stands *on* the surface while the cursor is painted flat onto it.
    ///
    /// Cursor-only on purpose: correcting `surfaceOffset` instead would move
    /// everything standing there, which is not what is wrong.
    private func nexysCursorLift(at point: GridPoint, metrics: PixelArtMetrics) -> CGFloat {
        guard session.engine.nexysPlane == shown, point == GameRules.nexysPoint else {
            return 0
        }
        return NexysStyle.cursorLift * metrics.scale
    }

    /// How far above the flat board the surface of `point` currently sits.
    ///
    /// The one place that knows a square might not be at floor height, so
    /// anything standing on one can ask rather than re-deriving it.
    private func surfaceOffset(
        of point: GridPoint,
        bob: CGFloat,
        metrics: PixelArtMetrics
    ) -> CGFloat {
        if session.engine.nexysPlane == shown, point == GameRules.nexysPoint {
            // **The island's own nudge, inherited.**
            //
            // Everything that asks this question — the cursor, the coin, a
            // phantom — comes up with the island. The piece is the exception and
            // does *not* come through here: it rides the island rather than
            // standing at its height, so it carries its own lift and the nudge
            // is added there too. See `carryOffset` where the piece is built.
            return bob - GameRules.nexysRaise * metrics.scale
                + (NexysStyle.foreshortened ? NexysStyle.islandY * metrics.scale : 0)
        }
        if session.visibleRaisedTiles.contains(where: { $0.point == point }) {
            return -GameRules.tilePopLift * metrics.scale
        }
        return 0
    }

    @ViewBuilder
    private func tileChoice(metrics: PixelArtMetrics) -> some View {
        if session.isChoosingTile {
            TileChoiceOverlay(
                session: session,
                metrics: metrics,
                accent: session.zodiac.definition.accentColor
            )
        }
    }

    // MARK: - Piece and island

    /// Everything standing above the floor, drawn back to front.
    ///
    /// Sorting is the whole point — see `BoardObject` for the law. Wrapped in a
    /// board-sized `ZStack` because every child positions itself absolutely and
    /// needs a container that size to position within.
    private func objects(
        board: Board,
        plane: Plane,
        includesGround: Bool = true,
        metrics: PixelArtMetrics
    ) -> some View {
        ZStack {
            // **Drawn in list order and stacked by row, which have to agree.**
            //
            // List order alone is only ordering while every sibling composites
            // into the same layer: the moment one carries a blend mode or a
            // `drawingGroup` it becomes a layer of its own and draws above the
            // rest whatever the list said. So the row each object stands on is
            // stated outright, here, on the sibling — automatically, out of the
            // object itself, the same way for every kind there is.
            ForEach(
                BoardObject.draw(
                    objectsOnBoard(plane: plane, board: board, includesGround: includesGround)
                )
            ) { object in
                Group {
                    switch object.kind {
                    case .raisedTile:
                        raisedTile(at: object.point, plane: plane, metrics: metrics)
                    case .cursorBack:
                        // On its own clock — see `BoardView.ticking`.
                        ticking(metrics) { tick in
                            let bob = tick.bob
                            cursor(
                                at: object.point, metrics: metrics, bob: bob,
                                corners: [.topLeft, .topRight], showsWarning: false
                            )
                        }
                    case .cursorFront:
                        // On its own clock — see `BoardView.ticking`.
                        ticking(metrics) { tick in
                            let bob = tick.bob
                            cursor(
                                at: object.point, metrics: metrics, bob: bob,
                                corners: [.bottomLeft, .bottomRight], showsWarning: true
                            )
                        }
                    case .tileRow:
                        // Terra tiles, Astra clouds — the same place in the
                        // order either way.
                        if plane == .terra {
                            bandRow(object.point.y, board: board, plane: plane, metrics: metrics)
                        } else {
                            cloudRow(object.point.y, board: board, metrics: metrics)
                        }

                    case .pentacle:
                        pentacle(at: object.point, metrics: metrics)
                    case .libraPan:
                        // On its own clock — see `BoardView.ticking`.
                        ticking(metrics) { tick in
                            let bob = tick.bob
                            let pose = tick.pose
                            let arrival = tick.arrival
                            let ascent = tick.ascent
                            let sway = tick.sway
                            let flash = tick.flash
                            let starElement = tick.starElement
                            piece(
                                metrics: metrics, bob: bob, pose: pose,
                                arrival: arrival, ascent: ascent, sway: sway,
                                flash: flash, starElement: starElement,
                                // **Sorted forward, drawn in place.**
                                //
                                // The object sits on the row ahead so it clears
                                // that row's ground, but the pan is on the end of
                                // her arm and has to be drawn where her arm is —
                                // placing it forward as well tore it off her.
                                part: .frontPan,
                                placedAt: session.engine.piece.point
                            )

                        }
                    case .sigil:
                        if let tint = sigil(at: object.point, on: plane) {
                            // **Turning inside its own upright space, then laid
                            // down.** The rotation happens first and the ground's
                            // shear is applied to the result, so the mark turns
                            // *on* the board rather than spinning a flattened
                            // drawing against the edges of its square.
                            //
                            // `isStanding: false` is the whole of the fix for
                            // Astra: an object lies here rather than stands, so
                            // it takes the plane's ground shape either way.
                            TimelineView(.animation(paused: planeIsAsleep)) { timeline in
                                #if DEBUG
                                let _ = RenderTally.tick("Bd#9")
                                #endif
                                let turn = timeline.date.timeIntervalSinceReferenceDate
                                    / GameRules.miasmaMarkPeriod

                                PickupIconView(
                                    effect: PickupCatalog.effect(for: .matchShiftMiasma),
                                    size: metrics.tileSize * GameRules.miasmaMarkSize,
                                    tint: tint,
                                    background: nil
                                )
                                .frame(width: metrics.tileSize, height: metrics.tileSize)
                                .rotationEffect(
                                    .degrees(-turn.truncatingRemainder(dividingBy: 1) * 360)
                                )
                            }
                            .modifier(
                                SigilGlow(radius: GameRules.miasmaMarkGlow * metrics.scale)
                            )
                            .blendMode(.hardLight)
                            .onBoard(
                                object.point,
                                layer: .object,
                                in: context(for: plane, metrics: metrics),
                                isStanding: false
                            )
                            .allowsHitTesting(false)
                        }

                    case .sparkle:
                        if let set = session.visibleSparkles,
                           object.slot < set.points.count {
                            let point = set.points[object.slot]
                            ZStack {
                                glowSparkle(
                                    at: point, index: object.slot,
                                    set: set, metrics: metrics
                                )

                                // **The Stardar's promise, drawn on the
                                // winner.** Over the sparkle rather than
                                // replacing it: the square is still a candidate
                                // doing what candidates do, and the extra shine
                                // is the coin telling you which one pays.
                                if set.marked == point {
                                    EffectSpriteView(
                                        effect: .sparkles,
                                        tileSize: metrics.tileSize,
                                        start: .distantPast,
                                        loops: true,
                                        clock: session.ambientClock(at:)
                                    )
                                }
                            }
                            .modifier(placedOnPlaneModifier(point, metrics: metrics))
                            .offset(GameRules.sparkleNudge)
                        }

                    case .sting:
                        // On its own clock — see `BoardView.ticking`.
                        ticking(metrics) { tick in
                            let bob = tick.bob
                            if let strike = session.stingStrike {
                                StingLanceView(
                                    direction: strike.direction,
                                    reach: strike.reach,
                                    tileSize: metrics.tileSize,
                                    start: strike.start
                                )
                                // **Foreshortened going away, and behind him.**
                                //
                                // A tail thrown north is going *into* the board, so
                                // it is drawn short and passes behind the figure it
                                // comes off — at full length it stood up the board
                                // like a wall and covered him.
                                .scaleEffect(
                                    x: 1,
                                    y: strike.direction == .up ? GameRules.stingAwaySquash : 1,
                                    anchor: .bottom
                                )
                                .offset(y: -GameRules.stingLift * metrics.scale)
                                // Riding the island when he is standing on it, the
                                // same as everything else that stands there.
                                .offset(y: surfaceOffset(
                                    of: strike.from, bob: bob, metrics: metrics
                                ))
                                .onBoard(
                                    strike.from,
                                    // Thrown south it hangs out over every row in
                                    // front of him and would be sliced by each of
                                    // their tiles in turn; north it belongs behind
                                    // him, among the objects on his own row.
                                    layer: strike.direction == .down ? .effect : .object,
                                    in: context(for: plane, metrics: metrics)
                                )
                            }

                        }
                    case .prong:
                        if let prongs = session.engine.signState.prongs,
                           object.slot < prongs.poles.count {
                            let pole = prongs.poles[object.slot]
                            prong(
                                pole,
                                lit: pole.direction == prongs.active,
                                metrics: metrics
                            )
                        }
                    case .grassRow:
                        // **Parked.** A `Canvas` of blades per grassed row,
                        // redrawn on the sway — the most expensive thing on
                        // Terra by a wide margin. Drawn variants are coming to
                        // replace it; until then the cover sprite is the whole
                        // picture, and the row object stays so its place in the
                        // sort is not relearned later.
                        EmptyView()

                        // GrassRow(
                        //     row: object.point.y,
                        //     squares: session.visibleBoard.allPoints.filter {
                        //         $0.y == object.point.y
                        //             && (session.visibleBoard[$0].cover == .grass
                        //                 || session.visibleBoard[$0].cover == .tuft)
                        //     },
                        //     metrics: metrics,
                        //     sway: grassSway
                        // )

                    case .grass:
                        // **Parked, not removed.**
                        //
                        // The generated blades are a `Canvas` per square redrawn
                        // on the sway, and they were costing more than half the
                        // frame rate on a grassed board — batching their clock
                        // helped and did not come close to paying for them.
                        // Drawn variants are coming to replace them; until then
                        // the cover sprite is the whole picture.
                        //
                        // Everything around them is intact — the object, its
                        // row, its sorting — so bringing them back is deleting
                        // the comment markers below.
                        EmptyView()

                        // GrassBlades(
                        // shade: .at(object.point),
                        // point: object.point,
                        // size: metrics.tileSize,
                        // sway: grassSway
                        // )
                        // .onBoard(
                        // object.point,
                        // layer: .object,
                        // in: context(for: plane, metrics: metrics)
                        // )
                        // .allowsHitTesting(false)
                    case .nexys:
                        // On its own clock — see `BoardView.ticking`.
                        ticking(metrics) { tick in
                            let bob = tick.bob
                            let ascent = tick.ascent
                            let travel = tick.travel
                            nexys(
                                plane: plane, metrics: metrics, bob: bob,
                                ascent: ascent, travel: travel, rock: tick.nexysRock
                            )
                        }
                    case .nexysPillar:
                        // On its own clock — see `BoardView.ticking`. The same
                        // bob the island rides, so the two cannot drift apart.
                        ticking(metrics) { tick in
                            nexysPillar(
                                metrics: metrics, bob: tick.bob,
                                ascent: tick.ascent, travel: tick.travel
                            )
                        }
                    case .facing:
                        // On its own clock — see `BoardView.ticking`.
                        ticking(metrics) { tick in
                            let bob = tick.bob
                            let sway = tick.sway
                            // Positioned on the *piece's* square and offset forward from
                            // there by the view itself, even though it sorts by the
                            // square ahead — the arrow's reach is a fraction of a tile,
                            // so it belongs between the two rather than centred on
                            // either.
                            groundMark(
                                FacingArrowView(
                                    facing: session.visibleFacing,
                                    tileSize: metrics.tileSize,
                                    scale: metrics.scale,
                                    lift: arrowLift,
                                    liftScale: liftBoost(
                                        at: session.engine.piece.point, metrics: metrics
                                    ),
                                    depthLift: arrowDepthLift(
                                        at: session.engine.piece.point, metrics: metrics
                                    ),
                                    clock: session.ambientClock(at:)
                                ),
                                at: session.engine.piece.point,
                                metrics: metrics,
                                // The arrow's art is drawn as a mark already lying on a
                                // tilted plane, so the floor's squash would foreshorten
                                // it a second time. That double is exactly what four
                                // hand-tuned y-scales of 1.25 were cancelling — 1.25
                                // being 1 / 0.8, and 0.8 being the squash.
                                squashed: false
                            )
                            // Ground, like the cursor: it is a mark on the square
                            // ahead, not something standing there.
                            .offset(
                                y: surfaceOffset(
                                    of: session.engine.piece.point, bob: bob, metrics: metrics
                                ) * rowScale(at: session.engine.piece.point, metrics: metrics)
                            )
                            .offset(sway)

                        }
                    case .follower:
                        // On its own clock — see `BoardView.ticking`.
                        ticking(metrics) { tick in
                            let bob = tick.bob
                            let pose = tick.pose
                            let sway = tick.sway
                            follower(
                                step: object.slot,
                                at: object.point,
                                metrics: metrics,
                                bob: bob,
                                pose: pose,
                                sway: sway
                            )

                        }
                    case .sun:
                        // On its own clock — see `BoardView.ticking`.
                        ticking(metrics) { tick in
                            let bob = tick.bob
                            let sway = tick.sway
                            // On the lion's head, and over everything.
                            //
                            // It is not a thing on the board any more — it is the light
                            // that says a phantom is out — so it rides the piece rather
                            // than sitting on a square, and nothing may draw across it.
                            if let burning = session.visibleSun {
                                SunView(sun: burning, tileSize: metrics.tileSize)
                                    .modifier(placedOnPlaneModifier(object.point, metrics: metrics))
                                    .offset(y: surfaceOffset(
                                        of: object.point, bob: bob, metrics: metrics
                                    ))
                                    .offset(sway)
                                    .offset(y: -metrics.tileSize
                                        - GameRules.sunHeadroom * metrics.scale)
                            }

                        }
                    case .piece:
                        // On its own clock — see `BoardView.ticking`.
                        ticking(metrics) { tick in
                            let bob = tick.bob
                            let pose = tick.pose
                            let arrival = tick.arrival
                            let ascent = tick.ascent
                            let sway = tick.sway
                            let flash = tick.flash
                            let starElement = tick.starElement
                            // Sorted with everything else again. It was drawn outside
                            // the board while the perspective was being homed, which is
                            // exactly what stopped it depth-sorting — and there is
                            // nothing left to home.
                            piece(
                                metrics: metrics,
                                bob: bob,
                                pose: pose,
                                arrival: arrival,
                                ascent: ascent,
                                sway: sway,
                                flash: flash,
                                starElement: starElement
                            )
                            // Where the figure sits on its square, in art pixels.
                        }
                                        }
                }
                // Applied here, to the sibling, because this is the stack
                // whose order is in question — the same number set on some
                // descendant would order it against its own children instead.
                .zIndex(object.z)
            }
        }
        .frame(width: metrics.boardSize, height: metrics.boardSize)
    }

    /// Which objects are on the board right now.
    private func objectsOnBoard(
        plane: Plane,
        board: Board,
        includesGround: Bool = true
    ) -> [BoardObject] {
        let cursorPoint = projectedCursor.point
        // Only on the plane it is actually standing on.
        //
        // Unconditional was harmless while one board existed; with both on
        // screen it draws the piece twice, once on ground it is nowhere near.
        var objects: [BoardObject] = []

        // Before the piece's plane is asked about, the same way the ground is:
        // the strike is drawn on the plane it happens on, and it was sitting
        // below a guard that only lets the piece's own plane through.
        // Libra's near pan, one row ahead of her, when she is in profile.
        if session.engine.piece.plane == plane,
           session.zodiac == .libra,
           session.visibleFacing == .left || session.visibleFacing == .right {
            let ahead = session.engine.piece.point.offset(by: GridOffset(0, 1))
            if session.visibleBoard.contains(ahead) {
                objects.append(BoardObject(kind: .libraPan, point: ahead))
            }
        }

        // The Miasma's sigils, lying on the squares they mark.
        objects += session.engine.signState.miasmaMarks
            .filter { $0.plane == plane }
            .enumerated()
            .map { index, mark in
                BoardObject(kind: .sigil, point: mark.point, slot: index)
            }

        if let set = session.visibleSparkles, set.plane == plane,
           LayerBench.shared.sparkles {
            objects += set.points.enumerated().map { index, point in
                BoardObject(kind: .sparkle, point: point, slot: index)
            }
        }

        if let strike = session.stingStrike, strike.plane == plane {
            objects.append(BoardObject(kind: .sting, point: strike.from))
        }

        // **The ground first, and before the piece's plane is even asked
        // about:** a board nobody is standing on still has a floor.
        //
        // Terra only. Astra's ground is one canvas for the whole plane rather
        // than a band per row — there is no grid up there that has to tile —
        // so there are no rows to interleave with, and it keeps its own pass.
        // **Both planes, because both planes have ground.**
        //
        // Terra lays bands and Astra lays clouds, but the sort does not care
        // which — what it needs is that the ground be in this list, so that a
        // row of it can be drawn *after* something standing in the row behind.
        // Astra's ground used to be a pass of its own, running before all of
        // this, which is why nothing up there could ever be occluded by the
        // ground in front of it — the island simply sat over the whole plane.
        if includesGround, LayerBench.shared.ground {
            objects += (0..<board.size).map { row in
                BoardObject(kind: .tileRow, point: GridPoint(0, row), slot: row)
            }
        }

        if session.engine.piece.plane == plane {
            objects.append(BoardObject(kind: .piece, point: session.engine.piece.point))
        }
        // The cursor and the facing arrow belong to the piece, so they follow
        // it rather than appearing on whichever board is being drawn.
        guard session.engine.piece.plane == plane else { return objects }

        // Every patch, so the sorter places each against the piece and the coins
        // by its own row rather than as one block.
        let sown = session.visibleBoard
        // **Every square that has ordinary cover**, not only the ones wearing
        // `.grass`. The two levels are the same thing to look at — the variety
        // comes from the straw each square drew — so a `.tuft` square was
        // getting the blank tile and no blades at all, which is why patches of
        // the board looked bare.
        // The four shards, if they are standing.

        if let prongs = session.engine.signState.prongs, prongs.plane == plane {
            objects += prongs.poles.enumerated().map { index, pole in
                BoardObject(kind: .prong, point: pole.point, slot: index)
            }
        }

        // **One object per grassed row, not per grassed square.**
        //
        // Terra only: cover exists on Astra — Stubborn Statue lays it there —
        // but nothing grows out of a cloud, so there is nothing to draw and no
        // reason to pay for looking.
        if plane == .terra {
            let grassed = sown.allPoints.filter {
                sown[$0].cover == .grass || sown[$0].cover == .tuft
            }
            objects += Set(grassed.map(\.y)).sorted().map { row in
                BoardObject(kind: .grassRow, point: GridPoint(0, row), slot: row)
            }
        }

        objects += [
            // At the square it points at, not the square it comes from.
            //
            // Which is what restores north. The depth law sorts by row, so an
            // arrow one square ahead sorts one row ahead: pointing south it is
            // nearer the viewer and draws over the piece, and pointing north it
            // is further away and draws behind — exactly as a thing lying on
            // that patch of ground would. Anchored to the piece's own square it
            // had a single fixed layer and had to be either always in front or
            // always behind, and both are wrong half the time.
            BoardObject(
                kind: .facing,
                point: session.engine.piece.point
                    .offset(by: session.engine.piece.facing.unitOffset)
            ),
            BoardObject(kind: .cursorBack, point: cursorPoint),
            BoardObject(kind: .cursorFront, point: cursorPoint),
        ]

        // The Aten, over the lion.
        if let sun = session.engine.signState.sun, sun.plane == plane {
            objects.append(BoardObject(kind: .sun, point: session.engine.piece.point))
        }

        // Leo's company, each on its own square behind him.
        for (step, _) in session.retinue.enumerated()
        where session.engine.piece.plane == plane {
            objects.append(
                BoardObject(kind: .follower, point: followerSquare(step: step), slot: step)
            )
        }

        // Two objects at two places: the coin can be dragged off the tile that
        // popped up for it, and the tile stays where it is.
        //
        // Slotted by the coin's own serial rather than by its position in the
        // list. With two coins out, taking one renumbers the other — and a view
        // whose identity is reused for a different coin *travels* to it, which
        // is how a destroyed Pentacle appeared to fly to the next glow phase.
        for raised in session.visibleRaisedTiles {
            objects.append(BoardObject(kind: .raisedTile, point: raised.point, slot: raised.serial))
        }
        for pickup in session.visiblePickups {
            objects.append(BoardObject(
                kind: .pentacle,
                point: pickup.point,
                slot: pickup.serial,
                sweeping: session.isSliding
            ))
        }
        if session.engine.nexysPlane == plane {
            objects.append(BoardObject(kind: .nexys, point: GameRules.nexysPoint))

            // The near corner of the drawn-in-perspective island, which stands
            // in front of whoever is on it. Only that version has one.
            if NexysStyle.foreshortened {
                objects.append(BoardObject(kind: .nexysPillar, point: GameRules.nexysPoint))
            }
        }
        return objects
    }

    /// The lifted tile alone.
    private func raisedTile(
        at point: GridPoint,
        plane: Plane,
        metrics: PixelArtMetrics
    ) -> some View {
        let board = session.visibleBoard

        // Astra's raised square is already drawn — lifted and glowing — by
        // `CloudSpriteField`, which promotes it within its row. Drawing it again
        // here put the *generated* cluster on top of the sprite: a blue puff
        // sitting over the real cloud, on the one square the player was looking
        // hardest at.
        //
        // The cost is that it no longer depth-sorts against the piece and the
        // cursor. That is the right trade: the field already promotes occupied
        // squares past their neighbours, and the coin above it is a board object
        // of its own and still sorts.
        // Astra's lifted square is the one cloud that is recoloured, so it is a
        // view rather than a stamp in the field's canvas — see
        // `CloudSpriteView`. Same clock, same drift, same frame: it is the cloud
        // that was already there, turned blue.
        if plane == .astra, CloudSpriteField.hasArt {
            return AnyView(
                CloudSpriteView(
                    point: point,
                    health: board[point].health,
                    metrics: metrics,
                    clock: session.ambientClock(at:),
                    wake: cloudWake,
                    bounce: surfaceBounce,
                    swaps: CloudSpriteView.raisedSwaps,
                    glows: true
                )
                // The same base size the field draws every other cloud at.
                // The promoted square is a view rather than a stamp in the
                // canvas, so it never went through `cloudBaseSize` and came out
                // a tenth larger than its neighbours.
                .scaleEffect(GameRules.cloudBaseSize)
                .offset(y: -GameRules.cloudSpriteRaiseLift * metrics.scale)
                .modifier(placedOnPlaneModifier(point, metrics: metrics))
                .transition(.opacity)
            )
        }

        // Terra's lifted tile is drawn by its own band — see `bandRow`. It
        // is the same tile, raised, which is the only way it can be guaranteed
        // to share the row's perspective.
        if plane == .terra { return AnyView(EmptyView()) }

        return AnyView(
            ZStack(alignment: .top) {
                // Its own side, drawn with it.
                //
                // The edge pass lies under the bands, where it is meant to be
                // uncovered by whatever lifts in front of it — so a tile that
                // lifts has a side everywhere except under itself. Lifted, it
                // is the one tile whose side is the point.
                // Held at the ground while the face rises, so the side spans the
                // lift instead of travelling up with it. Riding along is why
                // nothing showed: the edge stayed exactly as hidden behind the
                // face as it had been before the tile moved.
                TileEdgeView(plane: plane, shade: .at(point), size: metrics.tileSize)
                    .offset(y: (GameRules.tileEdgeDrop + GameRules.tilePopLift) * metrics.scale)
                    .zIndex(-1)

                TileView(
                    tile: board[point],
                    plane: plane,
                    shade: .at(point),
                    size: metrics.tileSize,
                    isPopped: true,
                    isFlashing: session.flashingTiles.contains(point),
                    point: point
                )
            }
            // Ground, not an object. It was taking the object treatment —
            // one even scale — so a lifted tile came out flat while the floor
            // it rose from was lying down.
            .asBoardSquare(point, metrics: metrics)
            .offset(y: -GameRules.tilePopLift * metrics.scale)
            .transition(.opacity)
        )
    }

    /// The coin hovering over its lifted tile.
    ///
    /// Drawn separately from the tile that lifted it, even though the two always
    /// appear together — they have to sort independently, because the cursor's
    /// upper brackets pass *between* them.
    @ViewBuilder
    private func pentacle(at point: GridPoint, metrics: PixelArtMetrics) -> some View {
        if let pickup = session.visiblePickups.first(where: { $0.point == point }) {
            // Lifted only while it is standing on a raised tile. Dragged off it,
            // the coin sits on ordinary ground like anything else.
            let lifted = session.visibleRaisedTiles.contains { $0.point == point }

            // The storm's leavings are cloudstuff, not coinage. No raised tile
            // under them either — they hang over whatever is there, holes
            // included. See `StormCloudView`.
            if pickup.isCloud {
                StormCloudView(
                    size: metrics.tileSize,
                    clock: session.ambientClock(at:)
                )
                    .modifier(placedOnPlaneModifier(point, metrics: metrics))
                    .offset(surfaceSway(of: point, at: Date(), metrics: metrics))
                    .transition(.scale(scale: 0.2).combined(with: .opacity))
            } else {
            PentacleView(
                appearance: PickupCatalog.effect(for: pickup.id)
                    .appearance(on: pickup.plane),
                size: metrics.tileSize,
                scale: metrics.scale,
                clock: session.ambientClock(at:),
                // Off its own square, so a field of bubbles is a scatter rather
                // than one thing pulsing. Deterministic: the same square gives
                // the same offset every time, so nothing shifts under a redraw.
                phaseOffset: TimeInterval(point.x * 3 + point.y * 5) * 0.37,
                // A coin dealt by a ring wears the ring's colours, so what it is
                // worth is readable from across the board rather than remembered.
                swaps: pickup.fromRing ? PentacleView.ringSwaps : []
            )
            .offset(y: lifted ? -GameRules.tilePopLift * metrics.scale : 0)
            // Thrown, not placed.
            //
            // A spilled bubble erupts from the piece — out of nothing, up over
            // an arc, growing as it climbs, and raining down onto its square a
            // beat behind the one before it. Appearing on the square is what
            // made a scatter look like a board laid out in advance; rings read
            // as *lost* because you watch them leave.
            .modifier(BubbleThrow(
                flight: scattered(point, at: Date(), metrics: metrics),
                home: metrics.center(of: point)
            ))
            .modifier(placedOnPlaneModifier(point, metrics: metrics))
            // Hovering over a cloud that is drifting means drifting with it.
            .offset(surfaceSway(of: point, at: Date(), metrics: metrics))
            .transition(.scale(scale: 0.2).combined(with: .opacity))
            }
        }
    }

    /// Where a bubble is on its way out, or `nil` if nothing is being thrown.
    ///
    /// Eased so the handful leaves quickly and settles, rather than sliding at a
    /// constant rate — the same curve the reeled coin uses.
    private func scattered(
        _ point: GridPoint,
        at date: Date,
        metrics: PixelArtMetrics
    ) -> (position: CGPoint, scale: CGFloat)? {
        guard let scatter = session.bubbleScatter,
              let place = scatter.points.firstIndex(of: point)
        else { return nil }

        // Its own place in the queue: each bubble leaves a beat after the one
        // before it, so the handful erupts rather than appearing.
        let began = scatter.start
            .addingTimeInterval(GameRules.bubbleScatterStagger * Double(place))
        let elapsed = date.timeIntervalSince(began) / GameRules.bubbleScatterDuration

        // Not yet thrown: held at nothing, at the piece. A bubble waiting its
        // turn must not be sitting on its square already.
        guard elapsed >= 0 else { return (metrics.center(of: scatter.origin), 0) }
        guard elapsed < 1 else { return nil }

        let t = CGFloat(elapsed)
        let eased = t * t * (3 - 2 * t)

        let from = metrics.center(of: scatter.origin)
        let to = metrics.center(of: point)

        // Up and out, then raining down. A parabola over the straight line,
        // measured against the distance covered so a bubble thrown across the
        // board arcs higher than one dropped beside you.
        let span = hypot(to.x - from.x, to.y - from.y)
        let lift = sin(Double(eased) * .pi) * Double(span) * Double(GameRules.bubbleScatterArc)

        // Grows as it climbs and settles back to full — the volcano, rather
        // than something sliding across the floor.
        let swell = 1 + (GameRules.bubbleScatterGrowth - 1) * CGFloat(sin(Double(eased) * .pi))

        return (
            CGPoint(
                x: from.x + (to.x - from.x) * eased,
                y: from.y + (to.y - from.y) * eased - CGFloat(lift)
            ),
            eased < 0.25 ? eased / 0.25 * swell : swell
        )
    }

    /// The pillar under the drawn-in-perspective island's near corner.
    ///
    /// Placed on the island's own square and nudged from there, so the sort puts
    /// it in the island's row and the offset puts it in the corner — see
    /// `BoardObjectKind.nexysPillar` for why it is not part of the island.
    @ViewBuilder
    private func nexysPillar(
        metrics: PixelArtMetrics,
        bob: CGFloat,
        ascent: AscentPose,
        travel: AscentPose
    ) -> some View {
        NexysPillarView(
            tileSize: metrics.tileSize,
            scale: metrics.scale,
            bob: bob,
            isFaded: pieceIsJustNorthOfNexys
        )
        .modifier(islandTransform(metrics: metrics, ascent: ascent, travel: travel))
    }

    /// Everything that happens to the island as a whole.
    ///
    /// **Both halves take it, because they are one object.** The pillar is drawn
    /// apart from the island only so the piece can stand between them — every
    /// other way it is the same rock, and anything the island does it has to do
    /// too. Written once so a third thing cannot be added to one and forgotten
    /// on the other, which is exactly how the pillar came to be the only part of
    /// the island that did not fade.
    private func islandTransform(
        metrics: PixelArtMetrics,
        ascent: AscentPose,
        travel: AscentPose
    ) -> some ViewModifier {
        IslandTransform(
            // Two poses stack — the ascent (island *and* piece, when ridden) and
            // the island's own travel (island alone) — *except* while it is
            // carrying somebody, when they are the same pose and stacking them
            // applies the journey twice.
            scale: session.nexysCarryingPiece ? travel.scale : ascent.scale * travel.scale,
            lift: session.nexysCarryingPiece ? travel.lift : ascent.lift + travel.lift,
            placement: placedOnPlaneModifier(GameRules.nexysPoint, metrics: metrics)
        )
    }

    /// The Nexys island, at whatever height its drift and any transition put it.
    @ViewBuilder
    private func nexys(
        plane: Plane,
        metrics: PixelArtMetrics,
        bob: CGFloat,
        ascent: AscentPose,
        travel: AscentPose,
        rock: CGFloat?
    ) -> some View {
        if session.engine.nexysPlane == plane {
            NexysView(
                tileSize: metrics.tileSize,
                scale: metrics.scale,
                bob: bob,
                isFaded: pieceIsJustNorthOfNexys,
                rock: rock
            )
            .modifier(islandTransform(metrics: metrics, ascent: ascent, travel: travel))
        }
    }

    private func piece(
        metrics: PixelArtMetrics,
        bob: CGFloat,
        pose: HopPose,
        arrival: CGFloat,
        ascent: AscentPose,
        sway: CGSize,
        flash: Double,
        starElement: ZodiacElement?,
        part: LibraPieceView.Part = .whole,
        placedAt: GridPoint? = nil
    ) -> some View {
        // Falls under gravity rather than at a constant rate: squaring the
        // progress makes it accelerate into the ground.
        let remaining = 1 - arrival * arrival
        let dropOffset = -remaining * metrics.boardSize * GameRules.fallArrivalHeight

        // The shadow swells to meet it.
        var shadowScale = GameRules.fallArrivalShadowMin
            + (1 - GameRules.fallArrivalShadowMin) * arrival * arrival

        // Standing on nothing: drift, and pull the shadow in. Only the star and
        // Scorpio's hover can be here at all, and both should look like it.
        let hover = hoverBob(at: Date())
        if hover != 0 { shadowScale *= GameRules.hoverShadowScale }

        return ZStack {
            afterimages(metrics: metrics, starring: starElement, at: Date())
            gemTrail(metrics: metrics)

            // Split, the active half is drawn cropped and its twin is drawn
            // wherever it is standing — dimmed, and only when that is the plane
            // being looked at.
            // A sign with a drawing of its own half does not get a cropped one.
            //
            // Gemini has three sprites, so `PieceView` draws the gold twin
            // directly. This was drawing a *second* figure on the same square on
            // top of it — and asking `SplitHalfView` for it, which answers with
            // the silver twin, so the same half appeared twice: once here in
            // half, once beside its own other half.
            if session.isSplit, !session.zodiac.hasOwnHalves {
                SplitHalfView(
                    zodiac: session.zodiac,
                    tileSize: metrics.tileSize,
                    scale: metrics.scale,
                    side: .left
                )
                .offset(y: -metrics.tileSize / 2 - GameRules.pieceLift * metrics.scale)
            }

            PieceView(
            zodiac: session.zodiac,
            tileSize: metrics.tileSize,
            scale: metrics.scale,
            plane: shown,
            // Or the mane catching, which lights the same gemstone for a
            // moment — see `GameSession.blazeMane()`.
            isCharged: session.isZodiactionCharged || session.isManeBlazing,
            twin: session.engine.piece.twin,
            // The forward copy is a pan on a string; the shadow belongs to the
            // figure, which is drawing its own on its own square.
            showsShadow: part == .whole,
            // Which copy this is: the whole figure, or the one pan that sorts a
            // row ahead of her. See `LibraPieceView.Part`.
            part: part,
            spawnWash: session.spawnWash,
            movement: session.movement,
            facing: session.visibleFacing,
            isFalling: session.isFalling,
            // Standing on the island means riding it.
            // The island's carry, plus the climb when the archer has thrown
            // himself off the top of the board after his own arrow.
            //
            // **The island's nudge is in here too.** The piece does not go
            // through `surfaceOffset` — it has its own lift, because it rides
            // the island rather than merely standing at its height — so raising
            // the island had to be added here as well or the sprite went up and
            // the figure stayed put. Two places that both have to know, which is
            // why they name each other.
            carryOffset: (session.engine.isOnNexys
                ? bob * GameRules.carryFollow
                    - GameRules.nexysRideLift * metrics.scale
                    + (NexysStyle.foreshortened ? NexysStyle.islandY * metrics.scale : 0)
                    // The deep sprite's surface is drawn a pixel higher than the
                    // flat one's — see `NexysStyle.rideLift`.
                    - NexysStyle.rideLift * metrics.scale
                : 0) + launchLift(metrics: metrics),
            pose: pose,
            spin: session.fallSpin,
            dropOffset: dropOffset,
            shadowScale: shadowScale,
            chargeFlash: flash,
            starElement: starElement,
            clock: session.ambientClock(at:),
            stormPhase: aquariusPhase,
            stormFilm: session.stormFilm
        )
        // The launch itself: a fast climb rather than a spring, because it is
        // meant to leave rather than to arrive somewhere.
        .animation(
            .easeIn(duration: GameRules.vaultLaunchDuration),
            value: session.isLaunching
        )
        .overlay {
            // A burning piece sheds embers, for as long as the charge runs.
            if session.isCharging {
                EmberView(tileSize: metrics.tileSize, scale: metrics.scale,
                          clock: session.ambientClock(at:))
            }
            // And a piece the wind is carrying streams the same particles
            // sideways — see `EmberView`.
            if session.engine.signState.galeMoves > 0 {
                EmberView(
                    tileSize: metrics.tileSize,
                    scale: metrics.scale,
                    element: .air,
                    drift: GameRules.galeDrift
                )
            }
        }
        .overlay {
            // Polaris' own sparks, borrowed. The star is the same idea — a thing
            // lit from inside — and one orbit of twinkles is enough to say so
            // without a second effect being written.
            if starElement != nil {
                PolarisSparksView(
                    size: metrics.tileSize,
                    scale: metrics.scale,
                    phase: Date().timeIntervalSinceReferenceDate,
                    layer: .inFront
                )
                .offset(y: -GameRules.starSparkLift * metrics.scale)
            }
        }
        .overlay(alignment: .top) {
            // What the piece is carrying, riding above its head until it stops
            // and the coin opens.
            if !session.engine.carriedPickups.isEmpty {
                CarriedPickupView(tileSize: metrics.tileSize, scale: metrics.scale,
                                  clock: session.ambientClock(at:))
            }
        }
        // Island and passenger travel as one object during an ascent.
        .scaleEffect(ascent.scale)
        .offset(y: ascent.lift)
        // Standing on a cloud means drifting with it.
        .offset(sway)
        // Standing on nothing means drifting on your own.
        .offset(y: hover * metrics.scale)
        // And a move it could not make is still attempted.
        .offset(balk(at: Date(), metrics: metrics))
        // On the same camera as everything else it shares a square with. It
        // was placed by a separate linear model, which is why it agreed with
        // the board only where the two happened to cross.
        .modifier(placedOnPlaneModifier(placedAt ?? session.engine.piece.point, metrics: metrics))
        }
        .frame(width: metrics.boardSize, height: metrics.boardSize)
    }

    /// How far the cloud under the piece has wandered, and therefore how far
    /// the piece has.
    ///
    /// Only while it is standing still. Mid-hop the piece is in the air and off
    /// its footing entirely, so the sway eases back in over
    /// `cloudSwayEaseIn` once it lands rather than switching on at the
    /// moment of contact.
    ///
    /// Reads `surfaceSway`, the same description the square itself is drawn
    /// from — a second copy of that maths drifts apart the first time either is
    /// retuned, and a piece sliding off its own footing is worse than no sway.
    private func cloudSway(at date: Date, metrics: PixelArtMetrics) -> CGSize {
        let plane = shown
        let point = session.engine.piece.point

        // Cloud only: the island is carved rock and the chasm is nothing at all.
        guard plane == .astra,
              session.visibleBoard[point].kind == .normal,
              !session.isFalling
        else { return .zero }

        return surfaceSway(
            of: point,
            at: date,
            metrics: metrics,
            driftScale: swayAmount(at: date)
        )
    }

    /// `0` while the piece is airborne, easing to `1` once it has settled.
    private func swayAmount(at date: Date) -> CGFloat {
        guard let started = session.hopStartedAt else { return 1 }

        let settled = date.timeIntervalSince(started) - session.hopDuration
        let linear = min(max(settled / GameRules.cloudSwayEaseIn, 0), 1)

        return CGFloat(linear * linear * (3 - 2 * linear))
    }

    /// Shadow Work's double, wherever it currently is.
    ///
    /// Drawn in the board's stack rather than depth-sorted with the piece: it is
    /// a hazard on the ground, and having it occasionally occlude the player
    /// would be the board hiding the thing the player most needs to see.
    @ViewBuilder
    private func shadowDouble(plane: Plane, metrics: PixelArtMetrics) -> some View {
        if let shadow = session.shadow, shadow.plane == plane {
            ZStack {
                // Its floor, when the real island is on the other plane.
                //
                // Without this the shadow appeared to be standing on the open
                // chasm — so walking it into the middle of the board looked like
                // a free disposal, and the engine quietly refusing was
                // indistinguishable from a bug. The rule was there; the thing
                // the rule is about was not drawn.
                if shadow.onShadowNexys, shadow.point == GameRules.nexysPoint {
                    NexysView(
                        tileSize: metrics.tileSize,
                        scale: metrics.scale,
                        bob: 0,
                        isFaded: false
                    )
                        .saturation(0)
                        .colorMultiply(Palette.midnight)
                        .brightness(GameRules.shadowRampUp)
                        .opacity(GameRules.shadowNexysOpacity)
                        .allowsHitTesting(false)
                }

                // Its own shadow, like anything else standing on the board.
                PieceShadowView(
                    tileSize: metrics.tileSize,
                    opacity: GameRules.retinueShadowOpacity
                )
                .offset(y: metrics.tileSize * GameRules.retinueShadowDrop)

                ShadowPieceView(
                    zodiac: session.zodiac,
                    tileSize: metrics.tileSize,
                    scale: metrics.scale
                )
            }
            .modifier(placedOnPlaneModifier(shadow.point, metrics: metrics))
            .offset(y: surfaceOffset(of: shadow.point, bob: 0, metrics: metrics))
            .animation(
                .spring(response: GameRules.hopDuration * 1.4, dampingFraction: 0.75),
                value: shadow.point
            )
        }
    }

    /// Gemini's other half, standing where it was left.
    ///
    /// Drawn in the board's own stack rather than the piece's, because it is not
    /// where the piece is — that is the entire point of it.
    @ViewBuilder
    private func waitingHalf(plane: Plane, metrics: PixelArtMetrics) -> some View {
        if let half = session.otherHalf, half.plane == plane {
            SplitHalfView(
                zodiac: half.zodiac,
                tileSize: metrics.tileSize,
                scale: metrics.scale,
                side: .right,
                twin: half.twin
            )
            .offset(y: -metrics.tileSize / 2 - GameRules.pieceLift * metrics.scale)
            .modifier(placedOnPlaneModifier(half.point, metrics: metrics))
            .offset(y: surfaceOffset(of: half.point, bob: 0, metrics: metrics))
        }
    }

    /// The phantoms following Leo.
    ///
    /// Drawn inside the piece's own stack so they inherit its position, and
    /// given a slower spring so they arrive late — see `RetinueView`.
    /// One of Leo's phantoms, drawn with everything a real piece gets.
    ///
    /// ## Why it takes the piece's pose
    ///
    /// Because it is a piece. It hops when Leo hops, sways with the cloud it is
    /// standing on, rides the island, and sits up on a popped tile — a phantom
    /// that skipped any of those would be a sticker being dragged around the
    /// board, which is exactly what it looked like when this was a bare image
    /// with a position on it.
    ///
    /// The pose is shared rather than delayed. They are one body in two places,
    /// so they land together; the *position* is what lags, and that reads as
    /// following without the two of them ever falling out of step.
    @ViewBuilder
    private func follower(
        step: Int,
        at point: GridPoint,
        metrics: PixelArtMetrics,
        bob: CGFloat,
        pose: HopPose,
        sway: CGSize
    ) -> some View {
        if step < session.retinue.count {
            let phantom = session.retinue[step]

            // Its own everything, read from the square it is standing on.
            //
            // Not Leo's. It was taking the lion's sway, which is the sway of a
            // different cloud — so it drifted with ground it was not on, which
            // is the tell that it was pinned to the piece rather than standing
            // anywhere. A phantom is an entity: it asks the board about its own
            // square, exactly as the piece does about its.
            let ownSway = surfaceSway(of: point, at: Date(), metrics: metrics)
            let ownGround = surfaceOffset(of: point, bob: bob, metrics: metrics)
            let ownPose = followerPose(step: step, at: Date())

            ZStack {
                // Shadow first, so it stands *on* something — and over a hole
                // there is nothing to stand on, which is exactly when a shadow
                // and a float say the most.
                PieceShadowView(
                    tileSize: metrics.tileSize,
                    opacity: GameRules.retinueShadowOpacity
                )
                .offset(y: metrics.tileSize * GameRules.retinueShadowDrop)

                RetinueView(
                    zodiac: phantom,
                    tileSize: metrics.tileSize,
                    facing: session.visibleFacing,
                    scale: metrics.scale,
                    step: step,
                    hovering: isHole(point)
                )
            }
            // Its own hop, started late — see `followerPose(step:at:)`.
            .scaleEffect(x: ownPose.scaleX, y: ownPose.scaleY, anchor: .bottom)
            .offset(y: -ownPose.lift * metrics.scale)
            .modifier(placedOnPlaneModifier(point, metrics: metrics))
            .offset(y: ownGround)
            .offset(ownSway)
            // The *same* hop as Leo's, delayed. Not a slower one.
            //
            // A longer spring is a stiffer body being dragged along; what was
            // wanted is the de-synchronised Ice Climbers — the same jump, a beat
            // apart, so the second one lands on the square the first has just
            // left. Delaying an identical animation is that, exactly, and it
            // needs no lag constant at all.
            // Keyed to the phantom's **own** square, not Leo's.
            //
            // This is what made the hop and the travel disagree. The trail is
            // updated on the turn stamp, which lands a render before the piece
            // moves — so the follower's square changed at one moment and the
            // value the animation watched changed at another, and it slid
            // whenever it happened to notice rather than when it jumped. The
            // arc and the journey were running off two different clocks, which
            // is exactly the dubbing.
            .animation(
                .spring(response: GameRules.hopDuration * 1.6, dampingFraction: 0.72)
                    .delay(GameRules.retinueBeat * Double(step + 1)),
                value: point
            )
        }
    }

    /// A phantom's hop, which is Leo's hop started a beat later.
    ///
    /// Read from the same clock and the same curve — it is the identical jump,
    /// simply begun late. Before the delay is up it is at rest, which is what
    /// makes the pair read as two bodies rather than one drawing shown twice:
    /// Leo leaves the ground, lands, and only then does the phantom crouch.
    private func followerPose(step: Int, at date: Date) -> HopPose {
        guard let started = session.hopStartedAt else { return .rest }

        let late = date.timeIntervalSince(started)
            - GameRules.retinueBeat * Double(step + 1)
        guard late > 0 else { return .rest }

        // The same stretched clock the lion's own pose runs on, or the retinue
        // would be animating a shape he stopped using.
        return .at(
            progress: late / (session.hopDuration * GameRules.hopPoseStretch),
            distance: session.hopDistance
        )
    }

    /// Whether that square is open air.
    private func isHole(_ point: GridPoint) -> Bool {
        let board = session.visibleBoard
        guard board.contains(point) else { return false }
        return board[point].health.isHole || board[point].kind == .chasm
    }

    /// The square a follower stands on — the engine's answer, not a second one.
    private func followerSquare(step: Int) -> GridPoint {
        session.engine.retinueSquare(step: step)
    }


    /// The colours a piece drags behind it.
    ///
    /// Drawn by a charged meter in the sign's own element, and by the star in
    /// all four at once. Under the piece, so it is never dimmed by a ghost
    /// passing over it.
    ///
    /// Each ghost is pinned to a square the piece really stood on and never
    /// moves — see `AfterimageView`.
    @ViewBuilder
    private func afterimages(
        metrics: PixelArtMetrics,
        starring: ZodiacElement?,
        at date: Date
    ) -> some View {
        let charged = session.isZodiactionCharged

        // Also while sliding. A sweep is the one move fast enough to leave a
        // trail, and the trail is drawn in the sign's own element — which is how
        // the crab's scuttle gets its blue without anything knowing it is a crab.
        if starring != nil || charged || session.isSliding, !session.isFalling {
            let elements = ZodiacElement.allCases
            let cycle = date.timeIntervalSinceReferenceDate / GameRules.starCyclePeriod
            let current = Int(cycle * Double(elements.count))

            ForEach(Array(session.afterimages.enumerated()), id: \.element.id) { step, ghost in
                let age = date.timeIntervalSince(ghost.born) / GameRules.afterimageLife

                if ghost.plane == shown, age < 1 {
                    // Starred, each ghost wears the colour from `step` places
                    // back in the cycle — what the piece was wearing when it was
                    // standing there. Merely charged, they all wear the sign's.
                    let index = ((current - step - 1) % elements.count + elements.count)
                        % elements.count

                    AfterimageView(
                        zodiac: session.zodiac,
                        // What the piece **is** right now, so the trail is made
                        // of the same figure that is casting it.
                        stormPhase: aquariusPhase,
                        plane: shown,
                        isCharged: session.isZodiactionCharged,
                        element: starring == nil ? session.trailElement : elements[index],
                        tileSize: metrics.tileSize,
                        scale: metrics.scale,
                        facing: session.visibleFacing,
                        step: step,
                        age: age
                    )
                    .modifier(placedOnPlaneModifier(ghost.point, metrics: metrics))
                }
            }
            // Pinned, and pinned means pinned: an inherited transaction would
            // animate a ghost from wherever the last one was, which is exactly
            // the sliding this replaced.
            .transaction { $0.animation = nil }
        }
    }

    /// Lines of light off the gems of a charged piece.
    ///
    /// Each copy is placed at the piece's current square but given its own,
    /// slower spring — `.animation(_:value:)` overrides the replay's
    /// transaction — so they arrive late and the gems streak. See `GemTrailView`.
    @ViewBuilder
    private func gemTrail(metrics: PixelArtMetrics) -> some View {
        if session.isZodiactionCharged, !session.isFalling {
            ForEach(0..<GameRules.gemTrailCount, id: \.self) { step in
                GemTrailView(
                    zodiac: session.zodiac,
                    tileSize: metrics.tileSize,
                    scale: metrics.scale,
                    step: step
                )
                .modifier(placedOnPlaneModifier(session.engine.piece.point, metrics: metrics))
                .animation(
                    .spring(
                        response: GameRules.gemTrailLag * Double(step + 2),
                        dampingFraction: 0.9
                    ),
                    value: session.engine.piece.point
                )
            }
        }
    }

    /// How the piece is deformed mid-hop.
    /// How far off the top of the board a launching piece has climbed.
    private func launchLift(metrics: PixelArtMetrics) -> CGFloat {
        session.isLaunching ? -(metrics.boardSize + metrics.tileSize * 2) : 0
    }

    /// How far through its sway the grass is, in turns — one number for the
    /// whole board, and a coarse one.
    ///
    /// Rounded to `GameRules.grassSwaySteps` positions per turn so that most
    /// frames hand every patch the value it already had, and every patch is
    /// then skipped. See `GrassBlades.sway`.
    private var grassSway: Double {
        let now = session.ambientClock(at: Date().timeIntervalSinceReferenceDate)
        let turns = now / GameRules.grassSwayPeriod
        let steps = GameRules.grassSwaySteps
        return (turns * steps).rounded(.down) / steps
    }

    /// Everything about the board that changes between *frames* rather than
    /// between turns.
    ///
    /// Small and cheap to build, because it is built once per animated object
    /// per frame rather than once for the whole board — and a handful of
    /// objects move where forty-nine tiles do not.
    struct BoardTick {

        let bob: CGFloat
        let pose: HopPose
        let arrival: CGFloat
        let ascent: AscentPose
        let travel: AscentPose
        let sway: CGSize
        let flash: Double
        let starElement: ZodiacElement?

        /// How far through the island's settling rock, or `nil` when it is not
        /// rocking. See `NexysStyle.Rock`.
        let nexysRock: CGFloat?
    }

    private func boardTick(at date: Date, metrics: PixelArtMetrics) -> BoardTick {
        BoardTick(
            bob: nexysBob(at: date, metrics: metrics),
            pose: hopPose(at: date),
            arrival: arrivalProgress(at: date),
            ascent: ascentPose(at: date, metrics: metrics),
            travel: nexysTravelPose(at: date, metrics: metrics),
            sway: cloudSway(at: date, metrics: metrics),
            flash: chargeFlash(at: date),
            starElement: starElement(at: date),
            nexysRock: nexysRock(at: date)
        )
    }

    /// Puts one board object on its own clock.
    ///
    /// Its own, rather than a shared one wrapped round the board: a timeline is
    /// a view, and everything inside a view shares that view's place in the
    /// stack it sits in. One timeline over the whole board would collapse every
    /// moving thing onto a single rung of the row order, which is the ordering
    /// the board is built to get right.
    @ViewBuilder
    private func ticking<Content: View>(
        _ metrics: PixelArtMetrics,
        @ViewBuilder content: @escaping (BoardTick) -> Content
    ) -> some View {
        TimelineView(.animation(paused: session.isPaused || planeIsAsleep)) { timeline in
            #if DEBUG
            let _ = RenderTally.tick("Bd#10")
            #endif
            content(boardTick(at: timeline.date, metrics: metrics))
        }
    }

    private func hopPose(at date: Date) -> HopPose {
        // A deliberate leap outranks a hop: it is a different shape, and the two
        // are never wanted at once.
        if let leapt = session.leapStartedAt {
            let weight = session.leapWeight
            let span = weight == .flop ? GameRules.flopDuration : GameRules.leapDuration
            return .leap(progress: date.timeIntervalSince(leapt) / span, weight: weight)
        }

        guard let started = session.hopStartedAt else { return .rest }

        // Only a style that leaves the ground gets the arc and the squash.
        //
        // Every step sets `hopStartedAt`, whatever it is — the style rides on
        // the event rather than deciding whether it fired — so a slide was
        // being posed as a hop. `arcs` is already the question, and it is the
        // same one `bouncesOnArrival` asks a few lines further down.
        guard session.movement?.style.arcs ?? true else { return .rest }

        var pose = HopPose.at(
            // Stretched past the step it belongs to — see
            // `GameRules.hopPoseStretch`.
            progress: date.timeIntervalSince(started)
                / (session.hopDuration * GameRules.hopPoseStretch),
            distance: session.hopDistance
        )
        // Landing on the island is a climb, not a step. See
        // `GameRules.hopArcHeightOntoNexys`.
        if session.engine.piece.point == GameRules.nexysPoint,
           session.engine.nexysPlane == session.engine.piece.plane {
            pose.lift *= (1 + GameRules.hopArcHeightOntoNexys)
        }
        return pose
    }

    /// How far through the island's settling rock, or `nil` when it is still.
    ///
    /// **The same instant the give starts, so the two cannot drift.** The island
    /// dipping and the island tipping are one event seen twice, and timing them
    /// separately means every change to either one has to be paid for in the
    /// other. `surfaceBounce` is the session's own record of weight arriving —
    /// raised for the island by name, in `bounceSurface(at:on:)` — so both read
    /// it and only their *lengths* differ.
    ///
    /// It replaced a landing time derived from `hopStartedAt` plus a hop's
    /// duration. That was right about when weight lands and wrong in principle:
    /// two descriptions of one moment, one of which had to be kept in step by
    /// hand.
    ///
    /// A window on a timestamp rather than a stored flag, for the same reason
    /// `HopPose` is: a pure function of elapsed time cannot be left stuck part
    /// way through.
    private func nexysRock(at date: Date) -> CGFloat? {
        guard NexysStyle.foreshortened,
              let bounce = surfaceBounce,
              bounce.point == GameRules.nexysPoint
        else { return nil }

        let since = date.timeIntervalSinceReferenceDate - bounce.start
        guard since >= 0, since < NexysStyle.rockHold else { return nil }

        return CGFloat(since / NexysStyle.rockHold)
    }

    /// How far through an arrival the piece is, `0` at the top of its fall and
    /// `1` on the ground. `1` whenever it is not arriving.
    private func arrivalProgress(at date: Date) -> CGFloat {
        guard let started = session.fallArrivalStartedAt else { return 1 }
        let elapsed = date.timeIntervalSince(started) / GameRules.fallArrivalDuration
        return CGFloat(min(max(elapsed, 0), 1))
    }

    /// Where the ascent is up to, as a pure function of elapsed time.
    ///
    /// Two timestamps rather than one: the rise happens on Terra and the growth
    /// on Astra, with the plane swap hidden behind the flash between them.
    private func ascentPose(at date: Date, metrics: PixelArtMetrics) -> AscentPose {
        // Aboard, the piece *is* the island as far as motion goes.
        //
        // It used to keep its own pose, which for a ride down meant the island
        // performed a departure and the piece simply appeared on the other
        // plane — the elevator worked and looked like a teleport. Sharing one
        // timeline is the only way two things travelling together can be
        // guaranteed to arrive together.
        if session.nexysCarryingPiece {
            return nexysTravelPose(at: date, metrics: metrics)
        }

        if let rising = session.ascentRiseStartedAt {
            let progress = date.timeIntervalSince(rising) / GameRules.ascentRiseDuration
            return .rising(progress: min(max(progress, 0), 1), boardSize: metrics.boardSize)
        }
        if let growing = session.ascentGrowStartedAt {
            let progress = date.timeIntervalSince(growing) / GameRules.ascentGrowDuration
            return .growing(progress: progress)
        }
        return .rest
    }

    /// Where the island's own journey is up to. `.rest` when it is not moving.
    ///
    /// Directional, because the two planes are not symmetrical. Astra is the top
    /// of the world: an island coming or going there has nowhere above it to
    /// travel through, so it swells in and shrinks out on the spot. Terra has a
    /// sky, so an island arrives by falling out of it and leaves by climbing
    /// back into it — the same rise the player sees when riding it home, minus
    /// the whiteout, because the player has not gone anywhere.
    private func nexysTravelPose(at date: Date, metrics: PixelArtMetrics) -> AscentPose {
        let goingUp = session.nexysTravellingUp

        if let departing = session.nexysDepartStartedAt {
            let progress = date.timeIntervalSince(departing)
                / (goingUp ? GameRules.ascentRiseDuration : GameRules.nexysTravelDepartDuration)

            return goingUp
                ? .rising(progress: min(max(progress, 0), 1), boardSize: metrics.boardSize)
                : .departing(progress: progress, boardSize: metrics.boardSize, goingUp: false)
        }

        if let arriving = session.nexysArriveStartedAt {
            let progress = date.timeIntervalSince(arriving)
                / (goingUp ? GameRules.ascentGrowDuration : GameRules.fallArrivalDuration)

            return goingUp
                ? .growing(progress: progress)
                : .fallingIn(progress: progress, boardSize: metrics.boardSize)
        }
        return .rest
    }

    /// The island's current drift, in points. Negative is up.
    private func nexysBob(at date: Date, metrics: PixelArtMetrics) -> CGFloat {
        // The ambient clock, so the island holds its height while the game waits
        // on an answer. Its dip stays on the wall clock below — that is an
        // impact, not ambience.
        let phase = session.ambientClock(at: date.timeIntervalSinceReferenceDate)
            / GameRules.nexysFloatPeriod
        let float = CGFloat(sin(phase * 2 * .pi))
            * GameRules.nexysFloatAmplitude * metrics.scale

        // The island is a rock hanging in the air, so it dips under a landing
        // like the clouds do. Added to the bob rather than applied separately
        // because everything riding the island already reads this one number —
        // see `surfaceOffset(of:bob:metrics:)` — so the piece and the coin come
        // down with it for free.
        let give = CloudMotion.dip(
            GameRules.nexysPoint,
            bounce: surfaceBounce,
            now: date.timeIntervalSinceReferenceDate,
            scale: metrics.scale,
            over: NexysStyle.bounceHold,
            depth: NexysStyle.bounceDepth,
            attack: NexysStyle.bounceAttack,
            rebound: NexysStyle.rebound
        )

        return float + give
    }

    /// True while the piece stands on one of the three squares directly north
    /// of the island, where the overhang would otherwise cover it.
    private var pieceIsJustNorthOfNexys: Bool {
        let nexys = GameRules.nexysPoint
        let piece = session.engine.piece.point
        guard session.engine.nexysPlane == shown else { return false }
        return piece.y == nexys.y - 1 && abs(piece.x - nexys.x) <= 1
    }

    // MARK: - Effects

    /// The apparition a Zodiaction summons, hanging over the piece.
    ///
    /// Drawn above the sorted objects rather than among them: it is not standing
    /// on the board, it is hanging over it, and depth-sorting it against tiles
    /// would let a row of ground occlude it.
    @ViewBuilder
    private func constellation(metrics: PixelArtMetrics) -> some View {
        if let summon = session.constellation, summon.plane == shown {
            ConstellationView(
                zodiac: summon.zodiac,
                tileSize: metrics.tileSize,
                start: summon.start
            )
            .modifier(placedOnPlaneModifier(session.engine.piece.point, metrics: metrics))
            .offset(y: -GameRules.constellationRise * metrics.scale)
            .id(summon.id)
        }
    }

    /// The pillar of light at one end of a warp.
    @ViewBuilder
    private func warpBeam(metrics: PixelArtMetrics) -> some View {
        if let beam = session.warpBeam, beam.plane == shown {
            WarpBeamView(
                tileSize: metrics.tileSize,
                scale: metrics.scale,
                start: beam.start,
                isDeparture: beam.isDeparture
            )
            .modifier(placedOnPlaneModifier(beam.point, metrics: metrics))
            .id(beam.id)
        }
    }

    /// Clusters coming apart where Astra has given way, and squares stamping
    /// flat when a raised one goes back down.
    ///
    /// Drawn smoke in the cloud's own violets when the strip is there; the
    /// generated dispersal — see `CloudPoofView` — when it is not.
    @ViewBuilder
    private func cloudPoofs(metrics: PixelArtMetrics) -> some View {
        if shown == .astra {
            ForEach(session.cloudPoofs) { poof in
                if SmokeSpriteView.hasArt(on: .astra) {
                    SmokeSpriteView(
                        plane: .astra,
                        tileSize: metrics.tileSize,
                        start: poof.start,
                        magnitude: GameRules.cloudPoofMagnitude,
                        swaps: SmokeSpriteView.cloudSwaps
                    )
                    .modifier(placedOnPlaneModifier(poof.point, metrics: metrics))
                    .id(poof.id)
                } else {
                    CloudPoofView(
                        shade: .at(poof.point),
                        point: poof.point,
                        size: metrics.tileSize,
                        start: poof.start
                    )
                    .modifier(placedOnPlaneModifier(poof.point, metrics: metrics))
                }
            }
        }
    }

    /// Every puff in the air, each its own sibling so the row can order it.
    ///
    /// **On the effect layer**, which is where smoke belongs: it is a thing
    /// happening rather than a thing standing there. The layer already carries
    /// the rules — placed and scaled by its square like anything else, ordered
    /// by row among the other effects, and above the scene, because an effect
    /// that a piece of scenery can hide is an effect nobody sees.
    ///
    /// No modifier on the `ForEach`: attaching one collapses every puff into a
    /// single child, and then they sort among themselves instead of by row.
    @ViewBuilder
    private func dust(metrics: PixelArtMetrics) -> some View {
        ForEach(session.smoke.filter { $0.plane == shown }) { puff in
            dust(puff, metrics: metrics)
        }
        // - Note: filtered on `shown` rather than on the plane this copy of
        //   `layers` is drawing, which is the same test every other effect here
        //   makes. Both planes are built every frame — see `planeSquare` — so
        //   this is worth revisiting when the other one is.
    }

    /// Dust kicked up by a landing.
    ///
    /// One puff, drawn. The looping and the ordering belong to the sorter now
    /// — see `BoardObject.draw` — which is what lets a puff on a near row sit
    /// in front of a piece on a far one.
    @ViewBuilder
    private func dust(_ smoke: SmokePuff, metrics: PixelArtMetrics) -> some View {
        Group {
            // Drawn smoke wherever there is a strip for the plane. Astra's is
            // recoloured into its violets, so cloudstuff disperses as cloudstuff
            // rather than as grey.
            if SmokeSpriteView.hasArt(on: smoke.plane) {
                SmokeSpriteView(
                    plane: smoke.plane,
                    tileSize: metrics.tileSize,
                    start: smoke.start,
                    magnitude: smoke.magnitude,
                    swaps: smokeSwaps(for: smoke),
                    tint: smoke.tint
                )
                .id(smoke.id)
            } else {
                SmokeBurstView(
                    tileSize: metrics.tileSize,
                    scale: metrics.scale,
                    plane: smoke.plane,
                    seed: smoke.id.hashValue,
                    magnitude: smoke.magnitude,
                    start: smoke.start
                )
                .id(smoke.id)
            }
        }
        .onBoard(
            smoke.point,
            layer: .effect,
            in: context(for: smoke.plane, metrics: metrics)
        )
    }

    /// Which recolouring a puff of smoke wants.
    ///
    /// Terra's dust is earth and is drawn as it was authored. Astra's is
    /// cloudstuff and takes the sky's violets — unless it came off the *lifted*
    /// square, which is blue while it is up and has to smoke blue on the way
    /// down.
    private func smokeSwaps(for smoke: SmokePuff) -> [PaletteSwap] {
        // Cloud that fell out of the sky is cloud wherever it lands.
        if smoke.cloudstuff { return SmokeSpriteView.cloudSwaps }
        guard smoke.plane == .astra else { return [] }
        return smoke.fromRaisedTile
            ? SmokeSpriteView.raisedCloudSwaps
            : SmokeSpriteView.cloudSwaps
    }

    /// The moment the storm first appears, and only that moment.
    ///
    /// Fired on the crossing from nothing to something rather than on every
    /// change of phase: the funnel growing is continuous and needs no
    /// announcement, but the first breath of it is the sign coming alive and
    /// would otherwise happen in silence.
    @ViewBuilder
    private func aquariusTransform(metrics: PixelArtMetrics) -> some View {
        if session.zodiac == .aquarius, let start = session.stormWokeAt {
            EffectSpriteView(
                effect: .aquariusZodiaction,
                tileSize: metrics.tileSize,
                start: start
            )
            .scaleEffect(GameRules.aquariusTransformScale)
            .modifier(placedOnPlaneModifier(session.engine.piece.point, metrics: metrics))
            .allowsHitTesting(false)
        }
    }

    /// How much storm Aquarius is wearing, from his meter.
    ///
    /// - TODO: The sign's meter is meant to read backwards — full at the start,
    ///   spent at zero — so this will want *readiness* rather than the
    ///   displayed charge once that lands. See the Aquarius rework.
    private var aquariusPhase: Int {
        guard session.zodiac == .aquarius, session.zodiactionMeterMax > 0 else { return 0 }
        let full = Double(session.zodiactionMeter) / Double(session.zodiactionMeterMax)
        let phase = Int((full * 10).rounded())
        session.noteStormPhase(phase)
        return phase
    }

    /// Sparkles thrown off by an opened Pentacle.
    @ViewBuilder
    private func collectBurst(metrics: PixelArtMetrics) -> some View {
        if let burst = session.collectBurst, burst.plane == shown {
            CollectBurstView(
                tileSize: metrics.tileSize,
                scale: metrics.scale,
                start: burst.start
            )
            .modifier(placedOnPlaneModifier(burst.center, metrics: metrics))
            .offset(y: -GameRules.tilePopLift * metrics.scale)
            .id(burst.id)
        }
    }

    @ViewBuilder
    private func elementalBurst(metrics: PixelArtMetrics) -> some View {
        if let burst = session.elementalBurst, burst.plane == shown {
            // **Projected**, not flat.
            //
            // This one hides from a search for `.position`: the burst is a
            // shader over the whole board and takes its origin as a *parameter*,
            // so it was reading `metrics.center(of:)` — where the square would
            // be on an untilted board. That is why it drifted up the sprite as
            // the piece walked back, and why it never shrank with the row.
            //
            // Lifted a cell, so it fires where the figure is rather than at its
            // feet — for Pisces that is exactly where the fish rides.
            let spot = metrics.projected(
                burst.center,
                zoom: planeFraming(shown).zoom,
                lift: planeFraming(shown).lift,
                emphasis: planeFraming(shown).emphasis,
                pivot: planeFraming(shown).pivot
            )

            // Drawn on a canvas wider than the board, so a ripple at the edge
            // finishes instead of being cut off at it.
            //
            // The shader works in its own view's coordinates, so the origin
            // moves by exactly the padding — and the board's stack does not
            // clip, which is what lets the extra reach be seen at all.
            let pad = metrics.tileSize * 3

            // Laid out at board size, **drawn** larger.
            //
            // Framing the canvas bigger grew the stack it lives in, and every
            // sibling in that stack is placed with `.position` — which is
            // measured against the container. So the wider canvas moved the
            // whole board. An overlay draws outside its host without changing
            // what the host measures, which is the only way to have both.
            Color.clear
                .frame(width: metrics.boardSize, height: metrics.boardSize)
                .overlay {
                    ElementalBurstView(
                        kind: burst.kind,
                        center: CGPoint(
                            x: spot.position.x + pad,
                            y: spot.position.y - metrics.tileSize * spot.scale + pad
                        ),
                        radius: metrics.tileSize * 2.6 * spot.scale,
                        start: burst.start
                    )
                    .frame(
                        width: metrics.boardSize + pad * 2,
                        height: metrics.boardSize + pad * 2
                    )
                }
                .id(burst.id)
        }
    }

    /// The glow phase coming apart, one burst per square it had lit.
    @ViewBuilder
    private func sparkleDispersal(metrics: PixelArtMetrics) -> some View {
        ForEach(session.sparkleDispersals.filter { $0.plane == shown }) { burst in
            // The **same view** a coin going down with its tile throws.
            //
            // `pickupDestroyed` sets `collectBurst`, which draws through
            // `CollectBurstView` — the sparks. I reached for `ElementalBurstView`
            // instead, which is the coloured ring an Essence throws, and it is a
            // completely different picture: a wash of element where what was
            // wanted was something coming apart.
            CollectBurstView(
                tileSize: metrics.tileSize,
                scale: metrics.scale,
                start: burst.start
            )
            .modifier(placedOnPlaneModifier(burst.center, metrics: metrics))
            .id(burst.id)
        }
    }

    /// A small shove in the direction of a rejected swipe, out and back.
    ///
    /// `sin` over half a period: zero at both ends, so however the timing falls
    /// the board can only come to rest where it started.
    private func nudgeOffset(at date: Date) -> CGSize {
        guard let direction = session.blockedDirection, let started = session.blockedAt else {
            return .zero
        }
        let elapsed = date.timeIntervalSince(started)
        guard elapsed >= 0, elapsed < GameRules.blockedNudgeDuration else { return .zero }

        let travel = CGFloat(sin(elapsed / GameRules.blockedNudgeDuration * .pi))
        let distance = GameRules.blockedNudgeDistance * travel

        // Derived from the offset rather than enumerated, so a diagonal shove
        // leans into the corner it was aimed at.
        let step = direction.unitOffset
        return CGSize(width: CGFloat(step.dx) * distance,
                      height: CGFloat(step.dy) * distance)
    }

    /// True once the shove has run itself out.
    private var nudgeSettled: Bool {
        guard let started = session.blockedAt else { return true }
        return Date().timeIntervalSince(started) >= GameRules.blockedNudgeDuration
    }
}


/// A bloom around an effect, or nothing at all.
private struct BurstGlow: ViewModifier {
    let on: Bool
    let radius: CGFloat

    @ViewBuilder
    func body(content: Content) -> some View {
        if on {
            PaletteGlow(radius: radius, intensity: GameRules.burstGlowStrength) { content }
        } else {
            content
        }
    }
}


/// One row of Terra's ground, drawn edge to edge.
///
/// Its own view rather than a method so it can be compared: everything it draws
/// from is a value, so a frame that changes none of them redraws none of it.
/// See `BoardView.bandRow(_:board:plane:metrics:)`.
struct BandRow: View, Equatable {

    let row: Int
    let board: Board
    let plane: Plane
    let metrics: PixelArtMetrics
    let raised: Set<GridPoint>
    let flashing: Set<GridPoint>
    let pressed: Set<GridPoint>

    var body: some View {
        #if DEBUG
        let _ = RenderTally.tick("row")
        #endif

        // The row's ground, laid edge to edge so no seam can open between
        // neighbours however the band is scaled.
        HStack(spacing: 0) {
            ForEach(0..<metrics.gridSize, id: \.self) { column in
                let point = GridPoint(column, row)
                // A lifted tile is **this** tile, raised — not a second one
                // drawn over the top with its own placement. Anything placed
                // separately has to be made to agree with the row it came from,
                // and it never quite does; drawn inside the band it cannot
                // disagree, because it is the band.
                let isRaised = raised.contains(point)

                ZStack(alignment: .bottom) {
                    // Its side, revealed by the rise and left behind on the
                    // ground the tile came off.
                    if isRaised {
                        TileEdgeView(
                            plane: plane,
                            shade: .at(point),
                            size: metrics.tileSize
                        )
                        .offset(y: GameRules.tileEdgeDrop * metrics.scale)
                    }

                    TileView(
                        tile: board[point],
                        plane: plane,
                        shade: .at(point),
                        size: metrics.tileSize,
                        isPopped: isRaised,
                        isFlashing: flashing.contains(point),
                        healFlash: nil,
                        isPressed: pressed.contains(point),
                        point: point,
                        drawnByField: false
                    )
                    .offset(y: isRaised ? -GameRules.tilePopLift * metrics.scale : 0)
                }
                .frame(width: metrics.tileSize, height: metrics.tileSize)
            }
        }
        .overlay { cover }
        .frame(width: metrics.boardSize, height: metrics.tileSize)
        .asBoardRow(row, metrics: metrics)
    }

    /// Every covered square in this row, painted into one canvas.
    ///
    /// **One view for the row, not one per square.** Cover used to be a child
    /// of each tile, which is seven more nodes per row and forty-nine more on
    /// the board — and a board that is rebuilt every frame pays for every node
    /// it holds whether or not anything about it changed. That cost is in
    /// SwiftUI's own layout and compositing rather than in any code here, which
    /// is why it did not matter what the cover was drawn *as*: a flat rectangle
    /// cost the same as the sprite, because the expense was the view and not
    /// the picture.
    ///
    /// A `Canvas` has no children. It draws.
    private var cover: some View {
        Canvas { context, _ in
            #if DEBUG
            RenderTally.tick("cover")
            #endif

            var resolved: [SpriteID: GraphicsContext.ResolvedImage] = [:]

            for column in 0..<metrics.gridSize {
                let point = GridPoint(column, row)
                guard let grown = board[point].cover else { continue }

                // Two shades and three covers between them, so the same handful
                // of images is drawn seven times over. Resolved once each.
                let id = SpriteID.tileCover(.at(point), grown)
                let image: GraphicsContext.ResolvedImage
                if let cached = resolved[id] {
                    image = cached
                } else if let art = SpriteLoader.image(for: id) {
                    image = context.resolve(Image(uiImage: art))
                    resolved[id] = image
                } else {
                    continue
                }

                // **Rides the tile it is growing on.**
                //
                // A popped square lifts, and its cover has to lift with it —
                // painted flat at `y: 0` the grass stayed on the ground while
                // the tile rose out from under it, which reads as the cover
                // being *over* the raised tile rather than on it.
                let lift = raised.contains(point)
                    ? -GameRules.tilePopLift * metrics.scale
                    : 0

                context.draw(image, in: CGRect(
                    x: CGFloat(column) * metrics.tileSize,
                    y: lift,
                    width: metrics.tileSize,
                    height: metrics.tileSize
                ))
            }
        }
        .frame(width: metrics.boardSize, height: metrics.tileSize)
        .allowsHitTesting(false)
    }
}

/// The island's whole-object placement: its journey, and where it sits.
///
/// A modifier rather than a pair of calls so both halves of the island take
/// exactly the same thing — see `BoardView.islandTransform(metrics:ascent:travel:)`.
private struct IslandTransform<Placement: ViewModifier>: ViewModifier {

    let scale: CGFloat
    let lift: CGFloat

    /// The island keeps the **true** camera. The emphasis is a licence taken
    /// with the clouds, which are loose shapes whose recession is a matter of
    /// taste — the Nexys is a solid object at a known place, and exaggerating
    /// its depth would put it at odds with the piece standing on it.
    let placement: Placement

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .offset(y: lift)
            .modifier(placement)
    }
}
