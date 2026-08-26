//
//  CloudSpriteField.swift
//  Project Stars
//
//  All of Astra's cloud, as drawn art, in one pass.
//

import SwiftUI

/// Every ordinary Astra square, drawn from the cloud sheet in a single `Canvas`.
///
/// ## Why this replaced the generated clusters
///
/// `CloudFieldView` built each square out of roughly forty primitives — puffs,
/// speckles, curls — which came to some two thousand shapes a pass. It was held
/// to thirty frames a second precisely because it could not afford more, and
/// Astra still ran at well under a third of Terra's rate. Terra draws forty-nine
/// sprites; Astra was drawing two thousand paths to say the same thing.
///
/// Six images, resolved once per pass and stamped forty-nine times, is the same
/// order of work as Terra. The programmatic version is kept — see
/// `CloudFieldView` — because it is the only thing that can draw a cloud at a
/// size the sheet was not authored for, and because it took a long time to get
/// right.
///
/// ## Why one canvas rather than forty-nine views
///
/// Unchanged from the version before it, and for the same reason: 49 separate
/// `TimelineView`s is 49 invalidations and 49 composited layers per frame for
/// something the player reads as one surface.
///
/// ## Why the clouds overlap
///
/// The art is 48x48 — three board cells across — so every cloud runs well into
/// its neighbours. That is deliberate. A field of separated puffs reads as a
/// grid of objects; an overlapping one reads as weather. What keeps it legible
/// is that they are drawn in **row order**, so a cloud always sits in front of
/// the one behind it, and that no two are the same size or in the same place for
/// long.
struct CloudSpriteField: View, Equatable {
    @Environment(\.planeIsAsleep) private var planeIsAsleep



    let board: Board
    let metrics: PixelArtMetrics

    /// Squares flashing because they just changed state.
    var flashing: Set<GridPoint> = []

    /// Squares that are lifted, with a Pentacle floating over them.
    var raised: Set<GridPoint> = []

    /// Squares mid-mend, drawn by `CloudSpriteView` instead.
    ///
    /// The flash is a palette swap — a ramp for a ramp, so the cloud keeps its
    /// folds — and a `Canvas` cannot run the shader that does it. Same
    /// arrangement as the lifted square.
    var mending: Set<GridPoint> = []

    /// Squares with something standing on them.
    ///
    /// These clouds are drawn last **within their own row**: in front of their
    /// row peers, still behind every row nearer the viewer. The art is wider
    /// than its square, so a neighbour along the same row laps over it and
    /// swallows the piece's footing — but the row in front is *supposed* to
    /// cover it, and promoting the whole way would put the piece's cloud on top
    /// of clouds that are genuinely closer.
    var occupied: Set<GridPoint> = []

    /// The ambient clock, which stops and resumes rather than jumping. See
    /// `GameSession.ambientClock(at:)`.
    var clock: (TimeInterval) -> TimeInterval = { $0 }

    /// Something dropping through the sky, pushing the clouds around it aside.
    var wake: CloudMotion.Wake?

    /// A landing pressing one square down.
    var bounce: CloudMotion.Bounce?

    /// True when the sheet is present. The field draws nothing without it and
    /// the caller falls back to the generated clusters.
    static var hasArt: Bool {
        SpriteSheetLoader.hasArt(for: .astraCloud(.light))
    }

    /// How hard depth bites — see `PixelArtMetrics.projected(_:)`.
    var emphasis: CGFloat = 1

    /// The plane's own framing zoom.
    var zoom: CGFloat = GameRules.boardForeshortenScale

    /// And how far up the square it sits.
    var lift: CGFloat = GameRules.boardForeshortenLift

    /// How big a cloud is drawn before depth touches it.
    ///
    /// The companion to `separation`: that one decides how far apart the
    /// squares sit, this one how much of its square a cloud fills. Together
    /// they cover the field however densely it wants to be covered, and neither
    /// says anything about the camera.
    var baseSize: CGFloat = GameRules.cloudBaseSize

    /// How far apart the clusters sit, independent of how big they are.
    ///
    /// Zoom moves them apart *and* grows them, because both come from the same
    /// scale — which is right for a camera and wrong for deciding how dense the
    /// field looks. This spreads the squares about the board's middle and leaves
    /// every cloud the size it was, so coverage can be tuned without retuning
    /// the perspective.
    var separationX: CGFloat = GameRules.cloudSpacingX
    var separationY: CGFloat = GameRules.cloudSpacingY

    /// Which row of the board this copy draws, or `nil` for all of them.
    ///
    /// **The board sorts by row, so the ground has to be drawn by row.** Astra's
    /// clouds were one canvas covering the whole plane, drawn before the stack
    /// that holds everything standing on it — which meant nothing on Astra could
    /// ever be occluded by ground in front of it. The island is three rows tall
    /// and sat over the lot.
    ///
    /// One canvas per row costs the same drawing spread over seven layers, which
    /// is exactly what Terra already pays for the same reason — see `BandRow`.
    var row: Int?

    /// Whether the game is paused. Every other clock on the board asks this;
    /// this one did not, so seven fields drifted behind the pause menu.
    var isPaused = false

    /// **Compared on its values, ignoring its clock.**
    ///
    /// The field is the most expensive thing on Astra — forty-nine clusters in
    /// one `Canvas` — and it is throttled to `cloudFrameRate` internally, which
    /// governs its *own* timeline and nothing else. What was redrawing it sixty
    /// times a second was the parent: `clock` is a closure, a closure is never
    /// equal to itself, so SwiftUI could not tell the view was unchanged and
    /// rebuilt it on every session update. During a move the session updates
    /// constantly, which is exactly when the board felt worst and exactly why
    /// it was Astra and every sign rather than any one of them.
    ///
    /// Everything that really decides what is drawn is a value and is compared
    /// here. The clock is a pure function of a timestamp; two of them differ in
    /// identity and never in what they answer.
    static func == (lhs: CloudSpriteField, rhs: CloudSpriteField) -> Bool {
        lhs.row == rhs.row
            && lhs.isPaused == rhs.isPaused
            && lhs.board == rhs.board
            && lhs.metrics == rhs.metrics
            && lhs.flashing == rhs.flashing
            && lhs.raised == rhs.raised
            && lhs.mending == rhs.mending
            && lhs.occupied == rhs.occupied
            && lhs.wake == rhs.wake
            && lhs.bounce == rhs.bounce
            && lhs.emphasis == rhs.emphasis
            && lhs.zoom == rhs.zoom
            && lhs.lift == rhs.lift
    }

    var body: some View {
        // Forty-nine clusters, each a sprite with its own wander and breath —
        // the most expensive still thing on the board, and none of it moves
        // fast enough to need a frame a frame.
        TimelineView(.animation(minimumInterval: 1 / GameRules.cloudFrameRate, paused: planeIsAsleep || isPaused)) { timeline in
            #if DEBUG
            let _ = RenderTally.tick("clouds")
            #endif
            let now = clock(timeline.date.timeIntervalSinceReferenceDate)

            // Padded well past the board on every side.
            //
            // A `Canvas` clips to its own bounds, and these clouds are wider
            // than the squares they belong to — framed to the board exactly, the
            // outer ring was sliced off flat against the edge and the whole
            // field read as a rectangle of weather rather than as sky.
            let wall = timeline.date.timeIntervalSinceReferenceDate

            Canvas { context, _ in
                context.translateBy(x: overhang, y: overhang)
                draw(&context, at: now, impulseNow: wall)
            }
            .frame(
                width: metrics.boardSize + overhang * 2,
                height: metrics.boardSize + overhang * 2
            )
            // …and then reported to the layout as board-sized.
            //
            // The padding above is drawing room, not size. Without this the
            // enclosing `ZStack` grew to the padded bounds, and everything else
            // in it that positions itself — the tile faces, the sparkles —
            // resolved `.position` against the larger space and drew a cloud's
            // width off the grid.
            //
            // **And it is not worth narrowing to the row.** That was tried: a
            // cloud is two tiles across, so a band with enough margin either
            // side of its row came out *taller* than the board it replaced, and
            // paid for an extra offset and frame on each of seven rows for the
            // privilege. Measured, it cost frames.
            .frame(width: metrics.boardSize, height: metrics.boardSize)
        }
        .allowsHitTesting(false)
    }

    /// The size one cloud is drawn at, in points.
    private var cloudSide: CGFloat {
        metrics.tileSize * CGFloat(GameRules.cloudSpritePixelSize)
            / CGFloat(GameRules.tilePixelSize)
            * GameRules.cloudSpriteScale
    }

    /// A cloud's drawn identity: which square of the chequerboard it is, and
    /// how worn.
    private struct Look: Hashable {
        let shade: Palette.TileShade
        let health: TileHealth
    }

    /// How far a cloud may hang past the board and still be drawn.
    ///
    /// One whole cloud's width, which is more than any of them needs — the
    /// drift and the stretch both move them, and a margin that merely *usually*
    /// suffices is a margin that clips on the frame nobody was looking at.
    private var overhang: CGFloat { cloudSide }

    // MARK: - Drawing

    private func draw(
        _ context: inout GraphicsContext,
        at now: TimeInterval,
        impulseNow: TimeInterval
    ) {
        // Resolved once for the whole pass. `GraphicsContext.resolve` is the
        // expensive half of drawing an image, and there are only ever six
        // distinct ones however many squares are on the board.
        let frame = pingPong(at: now)
        var resolved: [Look: GraphicsContext.ResolvedImage] = [:]

        // One resolved image per shade *and* wear state. Still a handful —
        // two shades by four states — and each is built once for the life of
        // the process. See `PaletteRecolour`.
        for shade in [Palette.TileShade.light, .dark] {
            for health in TileHealth.allCases {
                guard let art = PaletteRecolour.image(
                    .astraCloud(shade),
                    frame: frame,
                    swaps: GameRules.cloudWearSwaps(health, shade: shade)
                ) else { continue }

                resolved[Look(shade: shade, health: health)] =
                    context.resolve(Image(uiImage: art))
            }
        }
        guard !resolved.isEmpty else { return }

        // Row order is depth order: a cloud nearer the bottom of the screen is
        // nearer the viewer and draws over the one behind it. Within a row, an
        // occupied square goes last — see `occupied`.
        let order = board.allPoints
            .filter { row == nil || $0.y == row }
            .sorted {
                ($0.y, occupied.contains($0) ? 1 : 0, $0.x)
                    < ($1.y, occupied.contains($1) ? 1 : 0, $1.x)
            }

        for point in order {
            let tile = board[point]
            guard tile.kind == .normal, !tile.health.isHole else { continue }
            // The lifted square is drawn by `CloudSpriteView` instead, which is
            // a real view and can therefore run the palette shader. A `Canvas`
            // cannot, and that square is the only one that needs it.
            guard !raised.contains(point) else { continue }
            guard !mending.contains(point) else { continue }
            guard let image = resolved[
                Look(shade: .at(point), health: tile.health)
            ] else { continue }

            drawCloud(
                &context, image: image, at: point, tile: tile,
                now: now, impulseNow: impulseNow
            )
        }
    }

    private func drawCloud(
        _ context: inout GraphicsContext,
        image: GraphicsContext.ResolvedImage,
        at point: GridPoint,
        tile: Tile,
        now: TimeInterval,
        impulseNow: TimeInterval
    ) {
        let isRaised = raised.contains(point)
        let stages = tile.health.rawValue

        // Size: the wear shrink, times an independent horizontal and vertical
        // breath. Two periods rather than one, so the cloud never simply pulses.
        let wear = GameRules.cloudScale(tile.health)
        let side = cloudSide * baseSize

        // What this cloud's row does to it: how big, and where. A cloud is drawn
        // foreshortened already, so depth owes it a size and a place and nothing
        // else — no taper, no shear.
        let spot = metrics.projected(
                        point,
                        zoom: zoom,
                        lift: lift,
                        emphasis: emphasis,
                        pivot: GameRules.astraDepthPivot,
                        spacing: CGSize(width: separationX, height: separationY)
                    )
        let depth = spot.scale / zoom

        let width = side * wear * depth * stretch(point, now: now, salt: 0,
                                                  period: GameRules.cloudSpriteStretchPeriodH)
        let height = side * wear * depth * stretch(point, now: now, salt: 97,
                                                   period: GameRules.cloudSpriteStretchPeriodV)

        // Position: the square's centre, plus this cloud's own wander, plus the
        // lift if a Pentacle is sitting on it.
        let centre = spot.position
        let wander = shift(point, now: now)
        let shove = CloudMotion.shove(
            point, wake: wake, now: impulseNow, scale: metrics.scale
        )
        let give = CloudMotion.dip(
            point, bounce: bounce, now: impulseNow, scale: metrics.scale
        )
        let lift = isRaised ? GameRules.cloudSpriteRaiseLift * metrics.scale : 0

        let box = CGRect(
            x: centre.x + wander.width + shove.width - width / 2,
            y: centre.y + wander.height + shove.height + give - height / 2 - lift
                - GameRules.astraCloudLift * metrics.scale
                + GameRules.cloudSpriteDrop * metrics.scale,
            width: width,
            height: height
        )

        var layer = context
        // Wear drains the colour out of a cloud rather than fading it — see
        // `GameRules.cloudWear`. Order matters: desaturate first, then darken,
        // or the darkening is what gets desaturated.
        let worn = GameRules.cloudWear(tile.health)
        if worn.saturation != 1 {
            layer.addFilter(.saturation(worn.saturation))
        }
        if worn.luminance < 1 {
            layer.addFilter(.colorMultiply(Color(white: worn.luminance)))
        }

        // The struck-square flash, drawn additively.
        //
        // It was a `colorMultiply` by white, which is the identity — so every
        // square Libra's trenches opened on Astra changed silently, and the only
        // thing marking them was the smoke of the ones that broke outright. That
        // is why shrinking the smoke lost the indicator: the smoke *was* the
        // indicator, standing in for a flash that had never worked.
        //
        // Drawn after the cloud rather than as a filter on it, since a filter
        // cannot brighten.
        let struck = flashing.contains(point)

        // Kept for the day something other than a Pentacle lifts a square. The
        // Pentacle's own lifted cloud is skipped above and drawn by
        // `CloudSpriteView`, which can recolour it.
        if isRaised {
            // Drawn into its own layer so the blur has something bounded to work
            // on.
            //
            // A blur added straight to the context is a filter over everything
            // that follows, with no defined extent — which composited as an
            // opaque rectangle sitting over the board rather than as light. That
            // was the stray black square.
            for pass in 0..<GameRules.cloudSpriteGlowPasses {
                layer.drawLayer { bloom in
                    bloom.opacity = layer.opacity * glow(at: now)
                    bloom.blendMode = .plusLighter
                    // Each pass wider than the last: a tight core with a soft
                    // halo around it, rather than one flat smear.
                    bloom.addFilter(
                        .blur(
                            radius: GameRules.cloudSpriteGlowRadius
                                * metrics.scale
                                * (1 + CGFloat(pass) * 0.8)
                        )
                    )
                    bloom.draw(image, in: box)
                }
            }
        }

        if struck {
            // Solid white, briefly.
            //
            // Additive blending was the third attempt at this and still did not
            // read: a magenta cloud summed with a soft white is a slightly
            // paler magenta cloud, on a plane where everything is already
            // bright. Replacing the colour outright is unambiguous — the square
            // is *white* for two frames and then it is not, which is the one
            // thing that cannot be mistaken for ambient motion.
            // Stacked additively until every channel saturates. A filter cannot
            // brighten and a multiply cannot either — summing the same image
            // into itself is the only thing in a `Canvas` that reaches white.
            for _ in 0..<GameRules.cloudStrikePasses {
                var lit = layer
                lit.opacity = 1
                lit.blendMode = .plusLighter
                lit.draw(image, in: box)
            }
        }

        // Flipped one way, then the other, as it wears — so a square that has
        // taken a hit is not merely smaller but visibly *not the same cloud*.
        // Free, since the art is symmetrical enough to bear it, and it catches
        // the eye in a way a size change on its own does not.
        if stages.isMultiple(of: 2) {
            layer.draw(image, in: box)
        } else {
            layer.translateBy(x: box.midX, y: 0)
            layer.scaleBy(x: -1, y: 1)
            layer.translateBy(x: -box.midX, y: 0)
            layer.draw(image, in: box)
        }
    }

    // MARK: - Motion

    /// Which frame of the strip is showing.
    ///
    /// Ping-pong rather than a loop: three frames cycling forwards jump from the
    /// last back to the first, which on a shape this soft reads as a stutter.
    /// Out and back has no seam — `0, 1, 2, 1` and round again.
    private func pingPong(at now: TimeInterval) -> Int {
        let frames = GameRules.cloudSpriteFrames
        guard frames > 1 else { return 0 }

        let span = frames * 2 - 2
        let tick = Int(now / GameRules.cloudSpriteRate.frameDuration) % span
        return tick < frames ? tick : span - tick
    }

    /// This cloud's wander from its square.
    ///
    /// Measured in art pixels — see `GameRules.cloudSpriteShift`.
    private func shift(_ point: GridPoint, now: TimeInterval) -> CGSize {
        let amount = GameRules.cloudSpriteShift * metrics.scale
        let clock = now / GameRules.cloudSpriteShiftPeriod * 2 * .pi
        let phase = CloudCluster.phase(at: point)

        return CGSize(
            width: CGFloat(sin(clock + phase)) * amount,
            height: CGFloat(cos(clock * 0.8 + phase)) * amount * 0.6
        )
    }

    /// This cloud's stretch on one axis, as a multiplier around `1`.
    private func stretch(
        _ point: GridPoint,
        now: TimeInterval,
        salt: Int,
        period: TimeInterval
    ) -> CGFloat {
        let phase = CloudCluster.hash(point, salt: salt) * 2 * .pi
        let wave = sin(now / period * 2 * .pi + phase)
        return 1 + CGFloat(wave) * GameRules.cloudSpriteStretch
    }

    /// The breath of a lifted cloud's glow.
    private func glow(at now: TimeInterval) -> Double {
        let phase = now / GameRules.cloudSpriteGlowPeriod * 2 * .pi
        let breath = (sin(phase) + 1) / 2
        return GameRules.cloudSpriteGlowMin
            + (GameRules.cloudSpriteGlowMax - GameRules.cloudSpriteGlowMin) * breath
    }
}
