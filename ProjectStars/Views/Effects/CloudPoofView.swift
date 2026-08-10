//
//  CloudPoofView.swift
//  Project Stars
//
//  A cloud square coming apart when it finally gives way.
//

import SwiftUI

/// The dispersal of a cluster whose square has become a hole.
///
/// Astra's version of a tile breaking. Terra's tiles fracture and stay put;
/// cloud has nothing to leave behind, so instead the puffs push apart, swell and
/// thin out — the square does not break, it stops being there.
///
/// Scatters the puffs the cluster actually had, taken from `CloudCluster`, so
/// the dispersal begins from exactly the shape that was on screen.
struct CloudPoofView: View {

    let shade: Palette.TileShade

    /// The square that gave way, so its puffs match what was standing there.
    let point: GridPoint

    /// Rendered edge length in points.
    let size: CGFloat

    /// When it began.
    let start: Date

    private var scale: CGFloat { size / CGFloat(GameRules.tilePixelSize) }

    var body: some View {
        TimelineView(.animation) { timeline in
            let progress = min(
                max(timeline.date.timeIntervalSince(start) / GameRules.cloudPoofDuration, 0),
                1
            )

            ZStack {
                ForEach(0..<GameRules.cloudPuffCount, id: \.self) { index in
                    let puff = CloudCluster.puff(index, at: point)
                    let drift = drift(puff, progress: progress)

                    Circle()
                        .fill(Palette.cloudTones(shade)[index % 2])
                        // Swells as it thins: dispersing cloud spreads out
                        // rather than simply fading, which is what separates it
                        // from something being switched off.
                        .frame(
                            width: puff.radius * 2 * scale * (1 + CGFloat(progress) * 0.9),
                            height: puff.radius * 2 * scale * (1 + CGFloat(progress) * 0.9)
                        )
                        .offset(x: drift.width, y: drift.height)
                        .opacity((1 - progress * progress) * 0.9)
                }
            }
            .frame(width: size, height: size)
        }
        .allowsHitTesting(false)
    }

    /// Each puff pushes away from the cluster's centre, fastest at first.
    private func drift(_ puff: CloudCluster.Puff, progress: Double) -> CGSize {
        let eased = CGFloat(1 - pow(1 - progress, 2))
        let reach = GameRules.cloudPoofSpread * scale * eased

        // Normalised direction from the centre, with a nudge upward so the
        // whole thing lifts as it goes — cloud does not fall.
        let length = max(sqrt(puff.x * puff.x + puff.y * puff.y), 0.001)
        return CGSize(
            width: puff.x / length * reach + puff.x * scale,
            height: puff.y / length * reach + puff.y * scale - eased * scale * 2
        )
    }
}
