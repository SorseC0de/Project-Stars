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

    let session: GameSession

    /// The side length available for the board, in points.
    let availableSide: CGFloat

    var body: some View {
        let metrics = PixelArtMetrics(availableSide: availableSide)
        let plane = session.visiblePlane
        let board = session.visibleBoard

        ZStack {
            backdrop(plane: plane, metrics: metrics)
            mirrors(plane: plane, metrics: metrics)

            edgeLayer(board: board, plane: plane, metrics: metrics)
            faceLayer(board: board, plane: plane, metrics: metrics)

            // Over the ground, under everything that moves: the piece, the
            // coins and the move's own effects all sit above this and stay lit.
            actionDim(metrics: metrics)
            choiceDim(metrics: metrics)

            pools(board: board, plane: plane, metrics: metrics)
            shedSkin(plane: plane, metrics: metrics)
            sanctuary(plane: plane, metrics: metrics)
            sun(metrics: metrics)
            arrow(metrics: metrics)
            sparkles(metrics: metrics)
            tileChoice(metrics: metrics)

            // The island and the piece share a clock, so the piece can ride the
            // island's drift while standing on it.
            // Paused means paused: the board's whole clock stops, so nothing
            // is quietly still moving behind the menu.
            TimelineView(.animation(paused: session.isPaused)) { timeline in
                let bob = nexysBob(at: timeline.date, metrics: metrics)
                let pose = hopPose(at: timeline.date)
                let arrival = arrivalProgress(at: timeline.date)
                let sway = cloudSway(at: timeline.date, metrics: metrics)
                let flash = chargeFlash(at: timeline.date)
                let starElement = starElement(at: timeline.date)
                let ascent = ascentPose(at: timeline.date, metrics: metrics)
                let travel = nexysTravelPose(at: timeline.date, metrics: metrics)
                objects(
                    plane: plane,
                    metrics: metrics,
                    bob: bob,
                    pose: pose,
                    arrival: arrival,
                    ascent: ascent,
                    travel: travel,
                    sway: sway,
                    flash: flash,
                    starElement: starElement
                )
            }

            constellation(metrics: metrics)
            warpBeam(metrics: metrics)
            fallingCloud(metrics: metrics)
            cloudPoofs(metrics: metrics)
            dust(metrics: metrics)
            collectBurst(metrics: metrics)
            elementalBurst(metrics: metrics)
            effectBurst(metrics: metrics)
            healFlashClouds(plane: plane, metrics: metrics)
            healSparkles(metrics: metrics)
            stingLance(metrics: metrics)
            reeledCoin(metrics: metrics)
            bankArc(metrics: metrics)

            // Hides the instant the planes swap during an ascent.
            Rectangle()
                .fill(Palette.white)
                .opacity(session.ascentFlash)
                .allowsHitTesting(false)
        }
        .frame(width: metrics.boardSize, height: metrics.boardSize)
        // A heavy landing jolts the board. Only the upper square shakes — the
        // panel below is under the player's thumb, and shaking a control surface
        // reads as a fault rather than as impact.
        .screenShake(startedAt: session.shakeStartedAt, scale: metrics.scale)
        // An illegal swipe shoves the board a few points and springs back.
        .offset(nudgeOffset)
        .animation(.spring(response: 0.22, dampingFraction: 0.35), value: session.blockedNudge)
        // Not clipped: the cursor may hang past the edge when the projected move
        // would leave the grid, and the Nexys overhangs its square.
    }

    // MARK: - Board layers

    /// Pisces' standing water. See `PoolView`.
    private func pools(board: Board, plane: Plane, metrics: PixelArtMetrics) -> some View {
        ForEach(board.allPoints.filter { board[$0].kind == .pool }, id: \.self) { point in
            PoolView(size: metrics.tileSize, clock: session.ambientClock(at:))
                .position(metrics.center(of: point))
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
            TimelineView(.animation) { timeline in
                let phase = timeline.date.timeIntervalSinceReferenceDate
                    / GameRules.shedSkinFloatPeriod * 2 * .pi
                let drift = CGFloat(sin(phase))
                    * GameRules.shedSkinFloat * metrics.scale

                PixelSprite(id: .piece(.scorpio)) { Color.clear }
                    .frame(width: metrics.tileSize, height: metrics.tileSize * 2)
                    .offset(
                        y: -metrics.tileSize / 2
                            - GameRules.pieceLift * metrics.scale
                            + drift
                    )
                    .opacity(GameRules.shedSkinOpacity)
                    // Washed towards the water it belongs to, so the husk is
                    // unmistakably *not* the piece even at a glance.
                    .colorMultiply(Palette.lightBlue)
            }
            .frame(width: metrics.tileSize, height: metrics.tileSize * 2)
            .position(metrics.center(of: skin.point))
            .allowsHitTesting(false)
            .transition(.opacity)
        }
    }

    /// A coin being drawn in to the piece.
    ///
    /// Travels the straight line between where it was and where the piece is,
    /// shrinking as it arrives — so a swept Pentacle is visibly *taken* rather
    /// than deleted from the square it was sitting on.
    @ViewBuilder
    private func reeledCoin(metrics: PixelArtMetrics) -> some View {
        if let flight = session.coinFlight, flight.plane == session.visiblePlane {
            TimelineView(.animation) { timeline in
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
                    appearance: PickupCatalog.effect(for: flight.id).appearance,
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

    /// Scorpio's tail, reaching down its facing. See `StingLanceView`.
    @ViewBuilder
    private func stingLance(metrics: PixelArtMetrics) -> some View {
        if let strike = session.stingStrike, strike.plane == session.visiblePlane {
            StingLanceView(
                direction: strike.direction,
                reach: strike.reach,
                tileSize: metrics.tileSize,
                start: strike.start
            )
            .position(metrics.center(of: strike.from))
        }
    }

    /// What each just-mended square is flashing, keyed by square.
    ///
    /// Read off the same list the motes come from, so the two halves of a mend
    /// are one event by construction rather than by two timers agreeing.
    private var healFlashes: [GridPoint: (ramp: [Color], strength: Double)] {
        var found: [GridPoint: (ramp: [Color], strength: Double)] = [:]
        let now = Date()

        for sparkle in session.healSparkles where sparkle.plane == session.visiblePlane {
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
                    .position(metrics.center(of: point))
                }
            }
        }
    }

    /// Every square that was just mended, shimmering. See `HealSparkleView`.
    private func healSparkles(metrics: PixelArtMetrics) -> some View {
        ForEach(session.healSparkles.filter { $0.plane == session.visiblePlane }) { sparkle in
            HealSparkleView(
                start: sparkle.start,
                tileSize: metrics.tileSize,
                // Seeded off the square, so two tiles mended at once throw
                // different motes instead of the same picture twice.
                seed: sparkle.point.x &* 31 &+ sparkle.point.y
            )
            .frame(width: metrics.tileSize * 2, height: metrics.tileSize * 2)
            .position(metrics.center(of: sparkle.point))
        }
    }

    /// Capricorn's takings, on their way off the board.
    ///
    /// Aimed at the bottom edge rather than at the strip's real position: the
    /// strip is not on screen when a coin is banked, and the point of the arc is
    /// that the money went *down there*. See `BankArcView`.
    @ViewBuilder
    private func bankArc(metrics: PixelArtMetrics) -> some View {
        if let arc = session.bankArc, arc.plane == session.visiblePlane {
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
    private func choiceDim(metrics: PixelArtMetrics) -> some View {
        Rectangle().fill(Palette.midnight)
            .frame(width: availableSide, height: availableSide)
            .opacity(session.isChoosingTile ? GameRules.choiceDim : 0)
            .animation(.easeOut(duration: 0.18), value: session.isChoosingTile)
            .allowsHitTesting(false)
            .frame(width: metrics.boardSize, height: metrics.boardSize)
    }

    /// The wash that says the board is mid-move.
    @ViewBuilder
    private func actionDim(metrics: PixelArtMetrics) -> some View {
        Rectangle()
            .fill(Palette.coolBlack)
            .frame(width: metrics.boardSize, height: metrics.boardSize)
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
                    .position(metrics.center(of: point))
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
                    .position(metrics.center(of: point))
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
              bounce.plane == session.visiblePlane
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
        guard session.visiblePlane == .astra,
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

        return ZStack {
            // Astra's ordinary squares are one canvas, not 49.
            //
            // Drawn art if the sheet is there, generated clusters if it is not —
            // the same rule every placeholder in this game follows. The drawn
            // version is also the one that made Astra affordable: see
            // `CloudSpriteField`.
            if plane == .astra {
                if CloudSpriteField.hasArt {
                    CloudSpriteField(
                        board: board,
                        metrics: metrics,
                        flashing: session.flashingTiles,
                        raised: popped,
                        // Whatever is being stood on or hovered over has to stay
                        // clear of its neighbours' overlap.
                        mending: Set(healFlashes.keys),
                        occupied: occupiedSquares(on: plane, popped: popped),
                        clock: session.ambientClock(at:),
                        wake: cloudWake,
                        bounce: surfaceBounce
                    )
                } else {
                    CloudFieldView(
                        board: board,
                        metrics: metrics,
                        flashing: session.flashingTiles,
                        freeze: session.ambientClock(at: Date().timeIntervalSinceReferenceDate),
                        excluding: popped,
                        isPaused: session.isPaused
                    )
                }
            }

            faces(board: board, plane: plane, metrics: metrics, popped: popped)
        }
    }

    /// One view per square, for everything the cloud field does not cover.
    private func faces(
        board: Board,
        plane: Plane,
        metrics: PixelArtMetrics,
        popped: Set<GridPoint>
    ) -> some View {
        ForEach(board.allPoints.filter { !popped.contains($0) }, id: \.self) { point in
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
                drawnByField: plane == .astra
            )
            .position(metrics.center(of: point))
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
        let torn = plane == .astra || session.engine.signState.terraRifts

        // Drawn for Gemini, and for whoever inherits the rifts afterwards.
        if session.zodiac == .gemini || session.engine.signState.riftsLinger, torn {
            ReflectiveRiftsView(metrics: metrics, accent: session.zodiac.definition.accentColor)
                .frame(width: metrics.boardSize, height: metrics.boardSize)
        }
    }

    /// The drawn effect strips currently playing, each over the square that set
    /// it off.
    private func effectBurst(metrics: PixelArtMetrics) -> some View {
        ForEach(session.effectBursts.filter { $0.plane == session.visiblePlane }) { burst in
            EffectSpriteView(
                effect: burst.effect,
                tileSize: metrics.tileSize,
                start: burst.start
            )
            .position(metrics.center(of: burst.center))
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
        guard piece.plane == session.visiblePlane, !session.isFalling else { return 0 }
        guard !session.visibleBoard[piece.point].isSolid else { return 0 }

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
        if let falling = session.fallingCloud, falling.plane == session.visiblePlane {
            FallingCloudView(point: falling.point, metrics: metrics, start: falling.start)
                .id(falling.id)
        }
    }

    /// Sagittarius' arrow, standing in the square it chose.
    @ViewBuilder
    private func arrow(metrics: PixelArtMetrics) -> some View {
        if let planted = session.visibleArrow {
            ArrowView(tileSize: metrics.tileSize, scale: metrics.scale,
                      clock: session.ambientClock(at:))
                .position(metrics.center(of: planted.point))
                .transition(.scale(scale: 0.3).combined(with: .opacity))
        }
    }

    /// Leo's sun, burning over its square for as long as it lasts.
    @ViewBuilder
    private func sun(metrics: PixelArtMetrics) -> some View {
        if let burning = session.visibleSun {
            SunView(sun: burning, tileSize: metrics.tileSize)
                .position(metrics.center(of: burning.point))
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
                SparkleView(
                    size: metrics.tileSize,
                    plane: session.visiblePlane,
                    index: index,
                    // Virgo's ring, which plays by different rules and says so.
                    tint: set.pattern == .ring ? Palette.pink : nil,
                    sway: { surfaceSway(of: point, at: $0, metrics: metrics) },
                    clock: session.ambientClock(at:)
                )
                    .position(metrics.center(of: point))
                    .offset(GameRules.sparkleNudge)
            }
            .transition(.opacity)
        }
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
        return CursorView(
            status: cursor.status,
            size: metrics.tileSize,
            scale: metrics.scale,
            corners: corners,
            showsWarning: showsWarning
        )
            .position(metrics.center(of: point))
            .offset(
                y: -GameRules.cursorLift * metrics.scale
                    + surfaceOffset(of: point, bob: bob, metrics: metrics)
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

    /// How far above the flat board the surface of `point` currently sits.
    ///
    /// The one place that knows a square might not be at floor height, so
    /// anything standing on one can ask rather than re-deriving it.
    private func surfaceOffset(
        of point: GridPoint,
        bob: CGFloat,
        metrics: PixelArtMetrics
    ) -> CGFloat {
        if session.engine.nexysPlane == session.visiblePlane, point == GameRules.nexysPoint {
            return bob - GameRules.nexysRaise * metrics.scale
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
        plane: Plane,
        metrics: PixelArtMetrics,
        bob: CGFloat,
        pose: HopPose,
        arrival: CGFloat,
        ascent: AscentPose,
        travel: AscentPose,
        sway: CGSize,
        flash: Double,
        starElement: ZodiacElement?
    ) -> some View {
        ZStack {
            ForEach(BoardObject.draw(objectsOnBoard(plane: plane))) { object in
                switch object.kind {
                case .raisedTile:
                    raisedTile(at: object.point, plane: plane, metrics: metrics)
                case .cursorBack:
                    cursor(
                        at: object.point, metrics: metrics, bob: bob,
                        corners: [.topLeft, .topRight], showsWarning: false
                    )
                case .cursorFront:
                    cursor(
                        at: object.point, metrics: metrics, bob: bob,
                        corners: [.bottomLeft, .bottomRight], showsWarning: true
                    )
                case .pentacle:
                    pentacle(at: object.point, metrics: metrics)
                case .nexys:
                    nexys(plane: plane, metrics: metrics, bob: bob, ascent: ascent, travel: travel)
                case .facing:
                    FacingArrowView(
                        facing: session.engine.piece.facing,
                        tileSize: metrics.tileSize,
                        scale: metrics.scale
                    )
                    .position(metrics.center(of: session.engine.piece.point))
                    .offset(y: surfaceOffset(
                        of: session.engine.piece.point, bob: bob, metrics: metrics
                    ))
                    .offset(sway)

                case .piece:
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
                }
            }
        }
        .frame(width: metrics.boardSize, height: metrics.boardSize)
    }

    /// Which objects are on the board right now.
    private func objectsOnBoard(plane: Plane) -> [BoardObject] {
        let cursorPoint = projectedCursor.point
        var objects: [BoardObject] = [
            BoardObject(kind: .piece, point: session.engine.piece.point),
            BoardObject(kind: .facing, point: session.engine.piece.point),
            BoardObject(kind: .cursorBack, point: cursorPoint),
            BoardObject(kind: .cursorFront, point: cursorPoint),
        ]

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
                .offset(y: -GameRules.cloudSpriteRaiseLift * metrics.scale)
                .position(metrics.center(of: point))
                .transition(.opacity)
            )
        }

        return AnyView(
            TileView(
                tile: board[point],
                plane: plane,
                shade: .at(point),
                size: metrics.tileSize,
                isPopped: true,
                isFlashing: session.flashingTiles.contains(point),
                point: point
            )
            .offset(y: -GameRules.tilePopLift * metrics.scale)
            .position(metrics.center(of: point))
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

            PentacleView(
                appearance: PickupCatalog.effect(for: pickup.id).appearance,
                size: metrics.tileSize,
                scale: metrics.scale,
                clock: session.ambientClock(at:),
                // A coin dealt by a ring wears the ring's colours, so what it is
                // worth is readable from across the board rather than remembered.
                swaps: pickup.fromRing ? PentacleView.ringSwaps : []
            )
            .offset(y: lifted ? -GameRules.tilePopLift * metrics.scale : 0)
            .position(metrics.center(of: point))
            // Hovering over a cloud that is drifting means drifting with it.
            .offset(surfaceSway(of: point, at: Date(), metrics: metrics))
            .transition(.scale(scale: 0.2).combined(with: .opacity))
        }
    }

    /// The Nexys island, at whatever height its drift and any transition put it.
    @ViewBuilder
    private func nexys(
        plane: Plane,
        metrics: PixelArtMetrics,
        bob: CGFloat,
        ascent: AscentPose,
        travel: AscentPose
    ) -> some View {
        if session.engine.nexysPlane == plane {
            NexysView(
                tileSize: metrics.tileSize,
                scale: metrics.scale,
                bob: bob,
                isFaded: pieceIsJustNorthOfNexys
            )
            // Two poses stack: the ascent (island *and* piece, when ridden) and
            // the island's own travel (island alone).
            .scaleEffect(ascent.scale * travel.scale)
            .offset(y: ascent.lift + travel.lift)
            .position(metrics.center(of: GameRules.nexysPoint))
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
        starElement: ZodiacElement?
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
            retinue(metrics: metrics)

            PieceView(
            zodiac: session.zodiac,
            tileSize: metrics.tileSize,
            scale: metrics.scale,
            plane: session.visiblePlane,
            isCharged: session.engine.isZodiactionReady,
            facing: session.engine.piece.facing,
            isFalling: session.isFalling,
            // Standing on the island means riding it.
            carryOffset: session.engine.isOnNexys
                ? bob - GameRules.nexysRideLift * metrics.scale
                : 0,
            pose: pose,
            spin: session.fallSpin,
            dropOffset: dropOffset,
            shadowScale: shadowScale,
            chargeFlash: flash,
            starElement: starElement
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
        .position(metrics.center(of: session.engine.piece.point))
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
        let plane = session.visiblePlane
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

    /// The phantoms following Leo.
    ///
    /// Drawn inside the piece's own stack so they inherit its position, and
    /// given a slower spring so they arrive late — see `RetinueView`.
    @ViewBuilder
    private func retinue(metrics: PixelArtMetrics) -> some View {
        ForEach(Array(session.retinue.enumerated()), id: \.element) { step, follower in
            RetinueView(
                zodiac: follower,
                tileSize: metrics.tileSize,
                facing: session.engine.piece.facing,
                scale: metrics.scale,
                step: step
            )
            .animation(
                .spring(
                    response: GameRules.hopDuration * GameRules.retinueLag,
                    dampingFraction: 0.7
                ),
                value: session.engine.piece.point
            )
        }
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
        let charged = session.engine.isZodiactionReady

        // Also while sliding. A sweep is the one move fast enough to leave a
        // trail, and the trail is drawn in the sign's own element — which is how
        // the crab's scuttle gets its blue without anything knowing it is a crab.
        if starring != nil || charged || session.isSliding, !session.isFalling {
            let elements = ZodiacElement.allCases
            let cycle = date.timeIntervalSinceReferenceDate / GameRules.starCyclePeriod
            let current = Int(cycle * Double(elements.count))

            ForEach(Array(session.afterimages.enumerated()), id: \.element.id) { step, ghost in
                let age = date.timeIntervalSince(ghost.born) / GameRules.afterimageLife

                if ghost.plane == session.visiblePlane, age < 1 {
                    // Starred, each ghost wears the colour from `step` places
                    // back in the cycle — what the piece was wearing when it was
                    // standing there. Merely charged, they all wear the sign's.
                    let index = ((current - step - 1) % elements.count + elements.count)
                        % elements.count

                    AfterimageView(
                        zodiac: session.zodiac,
                        element: starring == nil ? session.zodiac.element : elements[index],
                        tileSize: metrics.tileSize,
                        scale: metrics.scale,
                        step: step,
                        age: age
                    )
                    .position(metrics.center(of: ghost.point))
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
        if session.engine.isZodiactionReady, !session.isFalling {
            ForEach(0..<GameRules.gemTrailCount, id: \.self) { step in
                GemTrailView(
                    zodiac: session.zodiac,
                    tileSize: metrics.tileSize,
                    scale: metrics.scale,
                    step: step
                )
                .position(metrics.center(of: session.engine.piece.point))
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
    private func hopPose(at date: Date) -> HopPose {
        // A deliberate leap outranks a hop: it is a different shape, and the two
        // are never wanted at once.
        if let leapt = session.leapStartedAt {
            return .leap(progress: date.timeIntervalSince(leapt) / GameRules.leapDuration)
        }

        guard let started = session.hopStartedAt else { return .rest }
        return .at(
            progress: date.timeIntervalSince(started) / session.hopDuration,
            distance: session.hopDistance
        )
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
            scale: metrics.scale
        )

        return float + give
    }

    /// True while the piece stands on one of the three squares directly north
    /// of the island, where the overhang would otherwise cover it.
    private var pieceIsJustNorthOfNexys: Bool {
        let nexys = GameRules.nexysPoint
        let piece = session.engine.piece.point
        guard session.engine.nexysPlane == session.visiblePlane else { return false }
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
        if let summon = session.constellation, summon.plane == session.visiblePlane {
            ConstellationView(
                zodiac: summon.zodiac,
                tileSize: metrics.tileSize,
                start: summon.start
            )
            .position(metrics.center(of: session.engine.piece.point))
            .offset(y: -GameRules.constellationRise * metrics.scale)
            .id(summon.id)
        }
    }

    /// The pillar of light at one end of a warp.
    @ViewBuilder
    private func warpBeam(metrics: PixelArtMetrics) -> some View {
        if let beam = session.warpBeam, beam.plane == session.visiblePlane {
            WarpBeamView(
                tileSize: metrics.tileSize,
                scale: metrics.scale,
                start: beam.start,
                isDeparture: beam.isDeparture
            )
            .position(metrics.center(of: beam.point))
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
        if session.visiblePlane == .astra {
            ForEach(session.cloudPoofs) { poof in
                if SmokeSpriteView.hasArt(on: .astra) {
                    SmokeSpriteView(
                        plane: .astra,
                        tileSize: metrics.tileSize,
                        start: poof.start,
                        magnitude: GameRules.cloudPoofMagnitude,
                        swaps: SmokeSpriteView.cloudSwaps
                    )
                    .position(metrics.center(of: poof.point))
                    .id(poof.id)
                } else {
                    CloudPoofView(
                        shade: .at(poof.point),
                        point: poof.point,
                        size: metrics.tileSize,
                        start: poof.start
                    )
                    .position(metrics.center(of: poof.point))
                }
            }
        }
    }

    /// Dust kicked up by a landing.
    @ViewBuilder
    private func dust(metrics: PixelArtMetrics) -> some View {
        if let smoke = session.smoke, smoke.plane == session.visiblePlane {
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
                .position(metrics.center(of: smoke.point))
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
                .position(metrics.center(of: smoke.point))
                .id(smoke.id)
            }
        }
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

    /// Sparkles thrown off by an opened Pentacle.
    @ViewBuilder
    private func collectBurst(metrics: PixelArtMetrics) -> some View {
        if let burst = session.collectBurst, burst.plane == session.visiblePlane {
            CollectBurstView(
                tileSize: metrics.tileSize,
                scale: metrics.scale,
                start: burst.start
            )
            .position(metrics.center(of: burst.center))
            .offset(y: -GameRules.tilePopLift * metrics.scale)
            .id(burst.id)
        }
    }

    @ViewBuilder
    private func elementalBurst(metrics: PixelArtMetrics) -> some View {
        if let burst = session.elementalBurst, burst.plane == session.visiblePlane {
            ElementalBurstView(
                element: burst.element,
                center: metrics.center(of: burst.center),
                radius: metrics.tileSize * 2.6,
                start: burst.start
            )
            .frame(width: metrics.boardSize, height: metrics.boardSize)
            .id(burst.id)
        }
    }

    /// A small shove in the direction of a rejected swipe.
    private var nudgeOffset: CGSize {
        guard let direction = session.blockedDirection, session.blockedNudge % 2 == 1 else {
            return .zero
        }
        // Derived from the offset rather than enumerated, so a diagonal shove
        // leans into the corner it was aimed at.
        let distance: CGFloat = 6
        let step = direction.unitOffset
        return CGSize(width: CGFloat(step.dx) * distance,
                      height: CGFloat(step.dy) * distance)
    }
}
