//
//  WarpBeamView.swift
//  Project Stars
//
//  The pillar of light a warp travels through.
//

import SwiftUI

/// A column of light standing on a square, with sparks rising or falling in it.
///
/// Used at both ends of a warp: once where the piece leaves, once where it
/// arrives. That symmetry is the point — a warp that only played an effect at
/// the destination would read as the piece having *walked* there and something
/// happening on arrival.
///
/// Additive, because it is light. Two palette colours summed are brighter than
/// either and still on-palette, which is how this reads as energy without
/// reaching for a colour the art could not contain.
struct WarpBeamView: View {

    /// Size of a board cell, in points.
    let tileSize: CGFloat

    /// Whole-pixel scale, for art-pixel distances.
    let scale: CGFloat

    /// When this end of the warp began.
    let start: Date

    /// Which way the sparks travel: up as the piece leaves, down as it arrives.
    let isDeparture: Bool

    /// Colours to build the beam from. White light unless an element owns it.
    var ramp: ElementFX = .neutral

    var body: some View {
        TimelineView(.animation) { timeline in
            let progress = min(
                max(timeline.date.timeIntervalSince(start) / GameRules.warpBeamDuration, 0),
                1
            )

            ZStack {
                column(progress: progress)
                sparks(progress: progress)
            }
            .frame(width: tileSize, height: tileSize)
            .blendMode(.plusLighter)
        }
        .allowsHitTesting(false)
    }

    // MARK: - Parts

    /// The shaft itself: snaps to full width, then narrows to nothing.
    ///
    /// Widening in and narrowing out both look like a door opening. A beam that
    /// arrives at once and thins away reads as something that *struck*.
    private func column(progress: CGFloat) -> some View {
        let height = tileSize * GameRules.warpBeamHeight
        let openness = progress < 0.18
            ? progress / 0.18
            : 1 - (progress - 0.18) / 0.82

        return ZStack {
            // A wide, soft body with a hard bright core, rather than one shape
            // at one opacity — that is what gives it a filament.
            Rectangle()
                .fill(ramp.deep)
                .frame(width: tileSize * 0.72 * openness, height: height)
                .opacity(0.55)

            Rectangle()
                .fill(ramp.mid)
                .frame(width: tileSize * 0.4 * openness, height: height)
                .opacity(0.8)

            Rectangle()
                .fill(ramp.bright)
                .frame(width: tileSize * 0.16 * openness, height: height)
        }
        // Stands *on* the square rather than being centred on it.
        .offset(y: -height / 2 + tileSize * 0.4)
    }

    /// Motes riding the beam, travelling with the piece.
    private func sparks(progress: CGFloat) -> some View {
        ZStack {
            ForEach(0..<GameRules.warpSparkCount, id: \.self) { index in
                let spark = spark(index: index, progress: progress)

                SparkleGlyph()
                    .fill(ramp.bright)
                    .frame(width: spark.size, height: spark.size)
                    .opacity(spark.opacity)
                    .offset(x: spark.x, y: spark.y)
            }
        }
    }

    private func spark(index: Int, progress: CGFloat) -> (x: CGFloat, y: CGFloat, size: CGFloat, opacity: Double) {
        let hash = Double((index &* 2_654_435_761 &+ 7919) % 1000) / 1000
        let lane = (hash - 0.5) * Double(tileSize) * 0.5

        // Each spark starts a little after the last, so the beam looks like it
        // is carrying a stream rather than a single ring.
        let stagger = hash * 0.35
        let travel = max(0, min((Double(progress) - stagger) / (1 - stagger), 1))

        let distance = CGFloat(travel) * tileSize * GameRules.warpBeamHeight * 0.7
        let y = isDeparture ? -distance : distance - tileSize * GameRules.warpBeamHeight * 0.7

        return (
            x: CGFloat(lane),
            y: y + tileSize * 0.3,
            size: tileSize * 0.18,
            opacity: travel <= 0 ? 0 : (1 - travel * travel)
        )
    }
}
