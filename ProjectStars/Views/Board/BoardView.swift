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

            sparkles(metrics: metrics)
            tileChoice(metrics: metrics)

            // The island and the piece share a clock, so the piece can ride the
            // island's drift while standing on it.
            TimelineView(.animation) { timeline in
                let bob = nexysBob(at: timeline.date, metrics: metrics)
                let pose = hopPose(at: timeline.date)
                let arrival = arrivalProgress(at: timeline.date)
                let ascent = ascentPose(at: timeline.date, metrics: metrics)
                let travel = nexysTravelPose(at: timeline.date, metrics: metrics)
                objects(
                    plane: plane,
                    metrics: metrics,
                    bob: bob,
                    pose: pose,
                    arrival: arrival,
                    ascent: ascent,
                    travel: travel
                )
            }

            spectralHead(metrics: metrics)
            warpBeam(metrics: metrics)
            dust(metrics: metrics)
            collectBurst(metrics: metrics)
            elementalBurst(metrics: metrics)

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

    /// The plane's background. Falls back to a flat tint before art exists.
    private func backdrop(plane: Plane, metrics: PixelArtMetrics) -> some View {
        PixelSprite(id: .planeBackground(plane)) {
            Rectangle().fill(Palette.planeTint(plane))
        }
        .frame(width: metrics.boardSize, height: metrics.boardSize)
        .animation(.easeInOut(duration: 0.25), value: plane)
    }

    /// Pass one: every tile's edge, pushed down so its visible sliver sits at
    /// the bottom of the square, ready to be uncovered.
    private func edgeLayer(board: Board, plane: Plane, metrics: PixelArtMetrics) -> some View {
        ForEach(board.allPoints, id: \.self) { point in
            TileEdgeView(plane: plane, shade: .at(point), size: metrics.tileSize)
                .position(metrics.center(of: point))
                .offset(y: GameRules.tileEdgeDrop * metrics.scale)
        }
    }

    /// Pass two: the flat faces.
    ///
    /// The lifted tile is **not** drawn here — it stands proud of the floor, so
    /// it is a `BoardObject` and gets depth-sorted with the island and the piece.
    /// Leaving a gap is correct: a face lifted by 4px uncovers exactly the 4px
    /// edge strip laid down in pass one.
    private func faceLayer(board: Board, plane: Plane, metrics: PixelArtMetrics) -> some View {
        let poppedPoint = session.visiblePickup?.point

        return ForEach(board.allPoints.filter { $0 != poppedPoint }, id: \.self) { point in
            let popped = false

            TileView(
                tile: board[point],
                plane: plane,
                shade: .at(point),
                size: metrics.tileSize,
                isPopped: popped,
                isFlashing: session.flashingTiles.contains(point)
            )
            .position(metrics.center(of: point))
            .offset(y: popped ? -GameRules.tilePopLift * metrics.scale : 0)
            .animation(
                .spring(response: GameRules.tilePopResponse, dampingFraction: 0.72),
                value: popped
            )
        }
    }

    /// Gemini's mirrors, on Astra only.
    @ViewBuilder
    private func mirrors(plane: Plane, metrics: PixelArtMetrics) -> some View {
        if session.zodiac == .gemini, plane == .astra {
            MirrorsView(metrics: metrics, accent: session.zodiac.definition.accentColor)
                .frame(width: metrics.boardSize, height: metrics.boardSize)
        }
    }

    @ViewBuilder
    private func sparkles(metrics: PixelArtMetrics) -> some View {
        if let set = session.visibleSparkles {
            ForEach(Array(set.points.enumerated()), id: \.element) { index, point in
                SparkleView(size: metrics.tileSize, index: index)
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
        if point == session.visiblePickup?.point {
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
        travel: AscentPose
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
                        ascent: ascent
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

        if let pickup = session.visiblePickup {
            objects.append(BoardObject(kind: .raisedTile, point: pickup.point))
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
            isFlashing: session.flashingTiles.contains(point)
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
            PentacleView(
                appearance: PickupCatalog.effect(for: pickup.id).appearance,
                size: metrics.tileSize,
                scale: metrics.scale
            )
            .offset(y: -GameRules.tilePopLift * metrics.scale)
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
        ascent: AscentPose
    ) -> some View {
        // Falls under gravity rather than at a constant rate: squaring the
        // progress makes it accelerate into the ground.
        let remaining = 1 - arrival * arrival
        let dropOffset = -remaining * metrics.boardSize * GameRules.fallArrivalHeight

        // The shadow swells to meet it.
        let shadowScale = GameRules.fallArrivalShadowMin
            + (1 - GameRules.fallArrivalShadowMin) * arrival * arrival

        return PieceView(
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
            shadowScale: shadowScale
        )
        // Island and passenger travel as one object during an ascent.
        .scaleEffect(ascent.scale)
        .offset(y: ascent.lift)
        .position(metrics.center(of: session.engine.piece.point))
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
    /// on the board, it is looming over it, and depth-sorting it against tiles
    /// would let a row of ground occlude a ghost.
    @ViewBuilder
    private func spectralHead(metrics: PixelArtMetrics) -> some View {
        if let summon = session.spectralHead, summon.plane == session.visiblePlane {
            SpectralHeadView(
                zodiac: summon.zodiac,
                tileSize: metrics.tileSize,
                start: summon.start
            )
            .position(metrics.center(of: session.engine.piece.point))
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
