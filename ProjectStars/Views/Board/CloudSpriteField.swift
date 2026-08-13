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
struct CloudSpriteField: View {

    let board: Board
    let metrics: PixelArtMetrics

    /// Squares flashing because they just changed state.
    var flashing: Set<GridPoint> = []

    /// Squares that are lifted, with a Pentacle floating over them.
    var raised: Set<GridPoint> = []

    /// A stopped clock, while a move plays out. See `GameSession.ambientFreeze`.
    var freeze: TimeInterval?

    /// True when the sheet is present. The field draws nothing without it and
    /// the caller falls back to the generated clusters.
    static var hasArt: Bool {
        SpriteSheetLoader.hasArt(for: .astraCloud(.light))
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            let now = freeze ?? timeline.date.timeIntervalSinceReferenceDate

            // Padded well past the board on every side.
            //
            // A `Canvas` clips to its own bounds, and these clouds are wider
            // than the squares they belong to — framed to the board exactly, the
            // outer ring was sliced off flat against the edge and the whole
            // field read as a rectangle of weather rather than as sky.
            Canvas { context, _ in
                context.translateBy(x: overhang, y: overhang)
                draw(&context, at: now)
            }
            .frame(
                width: metrics.boardSize + overhang * 2,
                height: metrics.boardSize + overhang * 2
            )
        }
        .allowsHitTesting(false)
    }

    /// How far a cloud may hang past the board and still be drawn.
    ///
    /// One whole cloud's width, which is more than any of them needs — the
    /// drift and the stretch both move them, and a margin that merely *usually*
    /// suffices is a margin that clips on the frame nobody was looking at.
    private var overhang: CGFloat {
        metrics.tileSize * CGFloat(GameRules.cloudSpritePixelSize)
            / CGFloat(GameRules.tilePixelSize)
    }

    // MARK: - Drawing

    private func draw(_ context: inout GraphicsContext, at now: TimeInterval) {
        // Resolved once for the whole pass. `GraphicsContext.resolve` is the
        // expensive half of drawing an image, and there are only ever six
        // distinct ones however many squares are on the board.
        let frame = pingPong(at: now)
        var resolved: [Palette.TileShade: GraphicsContext.ResolvedImage] = [:]

        for shade in [Palette.TileShade.light, .dark] {
            guard let art = SpriteSheetLoader.image(for: .astraCloud(shade), frame: frame) else {
                continue
            }
            resolved[shade] = context.resolve(Image(uiImage: art))
        }
        guard !resolved.isEmpty else { return }

        // Row order is depth order: a cloud nearer the bottom of the screen is
        // nearer the viewer and draws over the one behind it.
        for point in board.allPoints.sorted(by: { ($0.y, $0.x) < ($1.y, $1.x) }) {
            let tile = board[point]
            guard tile.kind == .normal, !tile.health.isHole else { continue }
            guard let image = resolved[.at(point)] else { continue }

            drawCloud(&context, image: image, at: point, tile: tile, now: now)
        }
    }

    private func drawCloud(
        _ context: inout GraphicsContext,
        image: GraphicsContext.ResolvedImage,
        at point: GridPoint,
        tile: Tile,
        now: TimeInterval
    ) {
        let isRaised = raised.contains(point)
        let stages = tile.health.rawValue

        // Size: the wear shrink, times an independent horizontal and vertical
        // breath. Two periods rather than one, so the cloud never simply pulses.
        let wear = GameRules.cloudScale(tile.health)
        let side = metrics.tileSize * CGFloat(GameRules.cloudSpritePixelSize)
            / CGFloat(GameRules.tilePixelSize)
            * GameRules.cloudSpriteScale

        let width = side * wear * stretch(point, now: now, salt: 0,
                                          period: GameRules.cloudSpriteStretchPeriodH)
        let height = side * wear * stretch(point, now: now, salt: 97,
                                           period: GameRules.cloudSpriteStretchPeriodV)

        // Position: the square's centre, plus this cloud's own wander, plus the
        // lift if a Pentacle is sitting on it.
        let centre = metrics.center(of: point)
        let wander = shift(point, now: now)
        let lift = isRaised ? GameRules.cloudSpriteRaiseLift * metrics.scale : 0

        let box = CGRect(
            x: centre.x + wander.width - width / 2,
            y: centre.y + wander.height - height / 2 - lift,
            width: width,
            height: height
        )

        var layer = context
        // Each stage of wear takes ten percent off. The shrink alone was not
        // reading as damage to anyone who had not been told — see
        // `GameRules.cloudSpriteWearFade`.
        layer.opacity = max(0, 1 - Double(stages) * GameRules.cloudSpriteWearFade)

        if flashing.contains(point) {
            layer.addFilter(.colorMultiply(Palette.white))
        }

        // The glow under a lifted cloud: the same image, blurred and additive,
        // breathing. Drawn first so the cloud sits inside its own light.
        if isRaised {
            var bloom = layer
            bloom.opacity = layer.opacity * glow(at: now)
            bloom.addFilter(.blur(radius: GameRules.cloudSpriteGlowRadius * metrics.scale))
            bloom.blendMode = .plusLighter
            bloom.draw(image, in: box)
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
    private func shift(_ point: GridPoint, now: TimeInterval) -> CGSize {
        let amount = GameRules.cloudSpriteShift * metrics.tileSize
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
