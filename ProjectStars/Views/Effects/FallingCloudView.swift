//
//  FallingCloudView.swift
//  Project Stars
//
//  A cloud coming down out of Astra with an arrow inside it.
//

import SwiftUI

/// The cloud Sagittarius' arrow tears out of Astra on its way to Terra.
///
/// ## Why the cloud is split in two
///
/// The arrow is *in* it, not on it. `CloudCluster` already draws in two passes —
/// a shaded body and a lit crown over the top — so the arrow simply goes between
/// them: body, arrow, crown. Nothing about the cluster changes, and the arrow is
/// wrapped rather than pasted on.
///
/// ## Why it falls rather than fades in
///
/// The whole point of the shot is that it went up over Astra and came back down
/// somewhere else. Arriving from off the top of the board is the only part of
/// that journey the player can actually see, so it is worth the half second.
struct FallingCloudView: View {

    /// The square it is coming down on.
    let point: GridPoint

    let metrics: PixelArtMetrics

    /// When the descent began.
    let start: Date

    var body: some View {
        TimelineView(.animation) { timeline in
            let now = timeline.date
            let elapsed = now.timeIntervalSince(start) / GameRules.arrowFlightDuration
            let progress = min(max(elapsed, 0), 1)

            // Squared: it accelerates, because it is falling rather than being
            // lowered.
            let fallen = progress * progress
            let above = metrics.boardSize + metrics.tileSize
            let clock = now.timeIntervalSinceReferenceDate

            ZStack {
                cluster(.body, at: clock)
                ArrowView(tileSize: metrics.tileSize, scale: metrics.scale)
                cluster(.crown, at: clock)
            }
            .frame(width: metrics.tileSize, height: metrics.tileSize)
            .position(metrics.center(of: point))
            .offset(y: -above * (1 - fallen))
        }
        .allowsHitTesting(false)
    }

    /// One half of the cluster, drawn exactly as the board draws its own.
    private func cluster(_ layer: CloudCluster.Layer, at now: TimeInterval) -> some View {
        Canvas { context, size in
            var pass = context
            CloudCluster.paint(
                CloudCluster.Brush(
                    centre: CGPoint(x: size.width / 2, y: size.height / 2),
                    point: point,
                    wear: 1,
                    tones: Palette.cloudTones(.at(point)),
                    speckleTones: Palette.speckleTones(raised: false),
                    scale: metrics.scale,
                    size: metrics.tileSize,
                    isFlashing: false
                ),
                into: &pass,
                at: now,
                layer: layer
            )
        }
        .frame(width: metrics.tileSize, height: metrics.tileSize)
    }
}
