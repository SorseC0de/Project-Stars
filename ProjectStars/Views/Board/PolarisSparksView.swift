//
//  PolarisSparksView.swift
//  Project Stars
//
//  The motes circling Polaris.
//

import SwiftUI

/// Sparks orbiting the star, in its three palette colours.
///
/// Drawn rather than sprited, so the count, the spread and the colours are all
/// knobs — and so the same three entries that make up the star are literally the
/// ones thrown off it.
///
/// Additive, like every other energy effect: two palette colours summed are
/// brighter than either and still on-palette.
struct PolarisSparksView: View {

    /// Size of a board cell, in points.
    let size: CGFloat

    /// Whole-pixel scale, for art-pixel distances.
    let scale: CGFloat

    /// Shared clock, so the sparks stay in step with the star they circle.
    let phase: TimeInterval

    /// Which half of the ring this draws.
    ///
    /// The star sits between the two, so sparks genuinely pass around it. Drawn
    /// as one layer they read as a flat halo pinned to the front.
    let layer: Layer

    enum Layer { case behind, inFront }

    var body: some View {
        ZStack {
            ForEach(indices, id: \.self) { index in
                let spark = spark(index)

                SparkleGlyph()
                    .fill(Palette.polarisSparkTones[index % Palette.polarisSparkTones.count])
                    .frame(width: spark.size, height: spark.size)
                    .opacity(spark.opacity)
                    .offset(x: spark.x, y: spark.y)
            }
        }
        .blendMode(.plusLighter)
        .allowsHitTesting(false)
    }

    /// Alternating sparks, so each layer is spread around the whole ring rather
    /// than being one contiguous arc.
    private var indices: [Int] {
        let all = Array(0..<GameRules.polarisSparkCount)
        return layer == .behind ? all.filter { $0.isMultiple(of: 2) }
                                : all.filter { !$0.isMultiple(of: 2) }
    }

    /// Where one spark is, and how bright.
    ///
    /// Each rides its own slightly different radius and its own twinkle, so the
    /// ring reads as a swarm rather than as a rotating wheel of dots.
    private func spark(_ index: Int) -> (x: CGFloat, y: CGFloat, size: CGFloat, opacity: Double) {
        let count = Double(GameRules.polarisSparkCount)
        let hash = Double((index &* 2_654_435_761 &+ 4813) % 1000) / 1000

        let angle = (Double(index) / count) * 2 * .pi
            + phase / GameRules.polarisSparkPeriod * 2 * .pi
        let radius = GameRules.polarisSparkRadius * scale * CGFloat(0.7 + hash * 0.5)

        // Each spark twinkles on its own period, drawn from the range rather
        // than sharing one — a ring pulsing in unison reads as the whole thing
        // blinking.
        let period = GameRules.polarisTwinkleFastest
            + (GameRules.polarisTwinkleSlowest - GameRules.polarisTwinkleFastest) * hash
        let twinkle = CGFloat(sin(phase / period * 2 * .pi + hash * 6.28) + 1) / 2

        // Size carries most of the twinkle. Brightness alone reads as a
        // flicker; a star is something that swells and shrinks.
        let base = size * 0.16 * CGFloat(0.75 + hash * 0.5)
        let swing = GameRules.polarisTwinkleSwing

        return (
            x: CGFloat(cos(angle)) * radius,
            // Flattened, like the coin's orbit: a ring seen at this angle is an
            // ellipse, and a circular one would read as a halo rather than an
            // orbit.
            y: CGFloat(sin(angle)) * radius * 0.45,
            size: base * (1 - swing / 2 + swing * twinkle),
            opacity: 0.28 + 0.4 * Double(twinkle)
        )
    }
}
