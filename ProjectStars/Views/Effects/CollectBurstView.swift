//
//  CollectBurstView.swift
//  Project Stars
//
//  The scatter of sparkles thrown off by opening a Pentacle.
//

import SwiftUI

/// Sparkles flying outward from a collected coin.
///
/// Reuses the sparkle drawing rather than a sprite, for the same reason the
/// glow sparkles are drawn: it has to work at any size for the tutorial splash
/// graphics, and a sheet cell would not.
///
/// Evaluated purely from elapsed time, so there is no animation state to leave
/// stranded if a move is cancelled mid-flight.
struct CollectBurstView: View {

    /// Size of a board cell, in points.
    let tileSize: CGFloat

    /// Whole-pixel scale, for art-pixel distances.
    let scale: CGFloat

    /// When the burst began.
    let start: Date

    /// Which element's colours to throw. Defaults to plain light.
    var ramp: ElementFX = .neutral

    private var tones: [Color] { ramp.tones }

    var body: some View {
        TimelineView(.animation) { timeline in
            let progress = min(
                max(timeline.date.timeIntervalSince(start) / GameRules.collectBurstDuration, 0),
                1
            )

            ZStack {
                ForEach(0..<GameRules.collectBurstCount, id: \.self) { index in
                    let spark = spark(index: index, progress: progress)

                    SparkleGlyph()
                        .fill(tones[index % tones.count])
                        .frame(width: spark.size, height: spark.size)
                        .opacity(spark.opacity)
                        .offset(x: spark.x, y: spark.y)
                }
            }
            .frame(width: tileSize, height: tileSize)
            // Energy is light, so it *adds* to what is behind it rather than
            // covering it. Two palette colours summed are brighter than either
            // and still on-palette, which is how these pop without reaching for
            // a colour the art could not contain.
            .blendMode(.plusLighter)
        }
        .allowsHitTesting(false)
    }

    /// Where one spark is, and how bright.
    ///
    /// Fired evenly around the circle with a small per-spark wobble, so the
    /// scatter looks thrown rather than stamped, but never leaves a visible gap.
    private func spark(index: Int, progress: Double) -> (x: CGFloat, y: CGFloat, size: CGFloat, opacity: Double) {
        let count = Double(GameRules.collectBurstCount)
        let wobble = Double((index &* 2654435761) % 1000) / 1000
        let angle = (Double(index) / count + wobble * 0.06) * 2 * .pi

        // Flies out fast and slows — the opposite of falling.
        let eased = CGFloat(1 - pow(1 - progress, 2.2))
        let distance = eased * GameRules.collectBurstSpread * scale * CGFloat(0.7 + wobble * 0.6)

        // Rises slightly as it spreads, so it reads as light rather than debris.
        let lift = eased * scale * 3

        return (
            x: CGFloat(cos(angle)) * distance,
            y: CGFloat(sin(angle)) * distance * 0.7 - lift,
            size: tileSize * 0.22 * (1 - CGFloat(progress) * 0.45),
            opacity: 1 - progress * progress
        )
    }
}
