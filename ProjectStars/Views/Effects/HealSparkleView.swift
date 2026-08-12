//
//  HealSparkleView.swift
//  Project Stars
//
//  The little teal motes a mended tile throws off.
//

import SwiftUI

/// A short burst of pale teal motes rising off a tile that was just repaired.
///
/// ## Why healing needed its own mark
///
/// Damage announces itself — the tile visibly cracks, and there is a whole
/// vocabulary of dust and fire behind it. Repair changes the same art in the
/// other direction and had nothing on top of it, so a Tear mending a square in
/// the corner of the board was easy to miss entirely. Worse, the effects that
/// heal *several* squares looked like a flicker.
///
/// So every mend, from any source, throws these. One rule, no exceptions: the
/// player learns the colour once and then always knows what just happened.
///
/// ## Why teal
///
/// The lightest cool on the palette, and one no element's ramp uses. Fire,
/// water, air and earth all mean something already, and a heal borrowing one of
/// them would read as *that element* doing something rather than as the ground
/// being restored.
struct HealSparkleView: View {

    /// When the mend happened.
    let start: Date

    /// Size of a board cell, in points.
    let tileSize: CGFloat

    /// Which sparkle pattern this is. Two tiles healed together should not throw
    /// identical motes, so the point's own coordinates seed it.
    let seed: Int

    var body: some View {
        TimelineView(.animation) { timeline in
            let elapsed = timeline.date.timeIntervalSince(start)
            let life = GameRules.healSparkleDuration

            Canvas { context, size in
                guard elapsed >= 0, elapsed <= life else { return }
                let centre = CGPoint(x: size.width / 2, y: size.height / 2)

                for index in 0..<GameRules.healSparkleCount {
                    var random = SeededRandom(seed: UInt64(seed &* 977 &+ index))

                    // Staggered so they do not all pop and die together, which
                    // reads as one flash rather than as a shimmer.
                    let lead = Double.random(in: 0...0.35, using: &random)
                    let progress = (elapsed / life - lead) / (1 - lead)
                    guard progress > 0, progress < 1 else { continue }

                    let angle = Double.random(in: 0...(2 * .pi), using: &random)
                    let spread = Double.random(in: 0.15...0.42, using: &random)
                    let rise = Double.random(in: 0.3...0.7, using: &random)

                    let drift = tileSize * spread * progress
                    let point = CGPoint(
                        x: centre.x + cos(angle) * drift,
                        y: centre.y + sin(angle) * drift * 0.5
                            - tileSize * rise * progress
                    )

                    // Fade in fast, out slow — the mote is brightest just after
                    // it leaves the tile, where the eye is already looking.
                    let fade = progress < 0.2
                        ? progress / 0.2
                        : 1 - (progress - 0.2) / 0.8
                    let radius = tileSize * GameRules.healSparkleSize * (1 - progress * 0.4)

                    let box = CGRect(
                        x: point.x - radius, y: point.y - radius,
                        width: radius * 2, height: radius * 2
                    )
                    context.opacity = fade
                    context.fill(Path(ellipseIn: box), with: .color(Palette.cyan))
                }
            }
        }
        // Additive: two on-palette colours summed are brighter than either and
        // still on-palette, which is how the motes read as light rather than as
        // teal paint on the tile.
        .blendMode(.plusLighter)
        .allowsHitTesting(false)
    }
}
