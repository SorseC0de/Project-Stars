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

    var body: some View {
        ZStack {
            ForEach(0..<GameRules.polarisSparkCount, id: \.self) { index in
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

        // Flattened, like the coin's orbit: a ring seen at this angle is an
        // ellipse, and a circular one would read as a halo rather than an orbit.
        let twinkle = sin(phase * (1.4 + hash) + hash * 6.28)

        return (
            x: CGFloat(cos(angle)) * radius,
            y: CGFloat(sin(angle)) * radius * 0.45,
            size: size * 0.16 * CGFloat(0.75 + hash * 0.5),
            opacity: 0.45 + 0.55 * (twinkle + 1) / 2
        )
    }
}
