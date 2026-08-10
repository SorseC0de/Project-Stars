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

            sanctuary(plane: plane, metrics: metrics)
            sun(metrics: metrics)
            sparkles(metrics: metrics)
            tileChoice(metrics: metrics)

            // The island and the piece share a clock, so the piece can ride the
            // island's drift while standing on it.
            TimelineView(.animation) { timeline in
                let bob = nexysBob(at: timeline.date, metrics: metrics)
                let pose = hopPose(at: timeline.date)
                let arrival = arrivalProgress(at: timeline.date)
                let sway = cloudSway(at: timeline.date, metrics: metrics)
                let flash = chargeFlash(at: timeline.date)
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
                    flash: flash
                )
            }

            constellation(metrics: metrics)
            warpBeam(metrics: metrics)
            cloudPoofs(metrics: metrics)
            dust(metrics: metrics)
            collectBurst(metrics: metrics)
            elementalBurst(metrics: metrics)
            effectBurst(metrics: metrics)

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
        }
    }

    /// Pass two: the flat faces.
    ///
    /// The lifted tile is **not** drawn here — it stands proud of the floor, so
    /// it is a `BoardObject` and gets depth-sorted with the island and the piece.
    /// Leaving a gap is correct: a face lifted by 4px uncovers exactly the 4px
    /// edge strip laid down in pass one.
    private func faceLayer(board: Board, plane: Plane, metrics: PixelArtMetrics) -> some View {
        // The raised square, which is not necessarily the coin's — Leo's sun can
        // drag a Pentacle off the tile that popped up for it.
        let poppedPoint = session.visibleRaisedTile?.point

        return ZStack {
            // Astra's ordinary squares are one canvas, not 49 — see
            // `CloudFieldView`. Everything else still draws a tile each.
            if plane == .astra {
                CloudFieldView(
                    board: board,
                    metrics: metrics,
                    flashing: session.flashingTiles,
                    excluding: poppedPoint
                )
            }

            faces(board: board, plane: plane, metrics: metrics, popped: poppedPoint)
        }
    }

    /// One view per square, for everything the cloud field does not cover.
    private func faces(
        board: Board,
        plane: Plane,
        metrics: PixelArtMetrics,
        popped: GridPoint?
    ) -> some View {
        let poppedPoint = popped

        return ForEach(board.allPoints.filter { $0 != poppedPoint }, id: \.self) { point in
            let popped = false

            TileView(
                tile: board[point],
                plane: plane,
                shade: .at(point),
                size: metrics.tileSize,
                isPopped: popped,
                isFlashing: session.flashingTiles.contains(point),
                point: point,
                drawnByField: plane == .astra
            )
            .position(metrics.center(of: point))
            .offset(y: popped ? -GameRules.tilePopLift * metrics.scale : 0)
            .animation(
                .spring(
                    response: GameRules.tilePopResponse,
                    dampingFraction: GameRules.tilePopDamping
                ),
                value: popped
            )
        }
    }

    /// Gemini's mirrors, on Astra only.
    @ViewBuilder
    private func mirrors(plane: Plane, metrics: PixelArtMetrics) -> some View {
        if session.zodiac == .gemini, plane == .astra {
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
            ForEach(Array(set.points.enumerated()), id: \.element) { index, point in
                SparkleView(
                    size: metrics.tileSize,
                    plane: session.visiblePlane,
                    index: index
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
    private var projectedCursor: GameEngine.Cursor {
        session.engine.cursor(
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
        if point == session.visibleRaisedTile?.point {
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
        flash: Double
    ) -> some View {
        ZStack {
            ForEach(BoardObject.draw(objectsOnBoard(plane: plane)), id: \.kind) { object in
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
                case .piece:
                    piece(
                        metrics: metrics,
                        bob: bob,
                        pose: pose,
                        arrival: arrival,
                        ascent: ascent,
                        sway: sway,
                        flash: flash
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
            BoardObject(kind: .cursorBack, point: cursorPoint),
            BoardObject(kind: .cursorFront, point: cursorPoint),
        ]

        // Two objects at two places: the coin can be dragged off the tile that
        // popped up for it, and the tile stays where it is.
        if let raised = session.visibleRaisedTile {
            objects.append(BoardObject(kind: .raisedTile, point: raised.point))
        }
        if let pickup = session.visiblePickup {
            objects.append(BoardObject(kind: .pentacle, point: pickup.point))
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

        return TileView(
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
    }

    /// The coin hovering over its lifted tile.
    ///
    /// Drawn separately from the tile that lifted it, even though the two always
    /// appear together — they have to sort independently, because the cursor's
    /// upper brackets pass *between* them.
    @ViewBuilder
    private func pentacle(at point: GridPoint, metrics: PixelArtMetrics) -> some View {
        if let pickup = session.visiblePickup {
            // Lifted only while it is standing on the raised tile. Dragged off
            // it, the coin sits on ordinary ground like anything else.
            let lifted = pickup.point == session.visibleRaisedTile?.point

            PentacleView(
                appearance: PickupCatalog.effect(for: pickup.id).appearance,
                size: metrics.tileSize,
                scale: metrics.scale
            )
            .offset(y: lifted ? -GameRules.tilePopLift * metrics.scale : 0)
            .position(metrics.center(of: point))
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
        flash: Double
    ) -> some View {
        // Falls under gravity rather than at a constant rate: squaring the
        // progress makes it accelerate into the ground.
        let remaining = 1 - arrival * arrival
        let dropOffset = -remaining * metrics.boardSize * GameRules.fallArrivalHeight

        // The shadow swells to meet it.
        let shadowScale = GameRules.fallArrivalShadowMin
            + (1 - GameRules.fallArrivalShadowMin) * arrival * arrival

        return ZStack {
            gemTrail(metrics: metrics)

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
            chargeFlash: flash
        )
        // Island and passenger travel as one object during an ascent.
        .scaleEffect(ascent.scale)
        .offset(y: ascent.lift)
        // Standing on a cloud means drifting with it.
        .offset(sway)
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
    /// Reads the very same `CloudCluster.drift` the square itself is drawn with
    /// — a second copy of that maths would drift apart the first time either was
    /// retuned, and a piece sliding off its own footing is worse than no sway.
    private func cloudSway(at date: Date, metrics: PixelArtMetrics) -> CGSize {
        let plane = session.visiblePlane
        let point = session.engine.piece.point

        // Cloud only: the island is carved rock and the chasm is nothing at all.
        guard plane == .astra,
              session.visibleBoard[point].kind == .normal,
              !session.isFalling
        else { return .zero }

        let drift = CloudCluster.drift(
            at: point,
            time: date.timeIntervalSinceReferenceDate,
            scale: metrics.scale
        )
        let amount = swayAmount(at: date)

        return CGSize(width: drift.width * amount, height: drift.height * amount)
    }

    /// `0` while the piece is airborne, easing to `1` once it has settled.
    private func swayAmount(at date: Date) -> CGFloat {
        guard let started = session.hopStartedAt else { return 1 }

        let settled = date.timeIntervalSince(started) - session.hopDuration
        let linear = min(max(settled / GameRules.cloudSwayEaseIn, 0), 1)

        return CGFloat(linear * linear * (3 - 2 * linear))
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
        let phase = date.timeIntervalSinceReferenceDate / GameRules.nexysFloatPeriod
        return CGFloat(sin(phase * 2 * .pi)) * GameRules.nexysFloatAmplitude * metrics.scale
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

    /// Clusters coming apart where Astra has given way.
    @ViewBuilder
    private func cloudPoofs(metrics: PixelArtMetrics) -> some View {
        if session.visiblePlane == .astra {
            ForEach(session.cloudPoofs) { poof in
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

    /// Dust kicked up by a landing.
    @ViewBuilder
    private func dust(metrics: PixelArtMetrics) -> some View {
        if let smoke = session.smoke, smoke.plane == session.visiblePlane {
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
        let distance: CGFloat = 6
        return switch direction {
        case .up: CGSize(width: 0, height: -distance)
        case .down: CGSize(width: 0, height: distance)
        case .left: CGSize(width: -distance, height: 0)
        case .right: CGSize(width: distance, height: 0)
        }
    }
}
