//
//  PoolView.swift
//  Project Stars
//
//  The standing water Pisces leaves behind.
//

import SwiftUI

/// A **pool**: shallow water lying on a square, drawn over the tile face.
///
/// ## Why it is drawn rather than sprited
///
/// A pool has no wear states, no edges to match against its neighbours and no
/// pixel detail to preserve — it is a flat body of colour with light moving on
/// it. Code gets the movement for free and stays honest at any tile size, where
/// a sheet would need a strip per shimmer frame to say the same thing.
///
/// ## Why the surface moves
///
/// Everything else on the board that cannot be damaged looks *structural* — the
/// island is rock, the chasm is absence. Water has to read as a third thing, and
/// standing still would put it in the same category as the other two. So the
/// highlights drift, slowly, off the same wall clock as every other ambient
/// effect here.
struct PoolView: View {

    /// Size of a board cell, in points.
    let size: CGFloat

    /// The ambient clock, so the water holds its pose along with the rest of
    /// the ambient art. See `GameSession.ambientClock(at:)`.
    var clock: (TimeInterval) -> TimeInterval = { $0 }

    var body: some View {
        TimelineView(.animation) { timeline in
            let now = clock(timeline.date.timeIntervalSinceReferenceDate)

            ZStack {
                // The body of it, inset so the tile beneath still reads as a
                // square with water *on* it rather than a blue tile.
                RoundedRectangle(cornerRadius: size * 0.18)
                    .fill(Palette.blue)
                    .padding(size * 0.08)

                RoundedRectangle(cornerRadius: size * 0.16)
                    .fill(Palette.sky)
                    .padding(size * 0.16)
                    .opacity(0.55)

                // Two glints crossing at different rates, which is enough to
                // read as a surface without ever repeating visibly.
                glint(at: now, period: 3.1, offset: 0, width: 0.34)
                glint(at: now, period: 4.7, offset: .pi / 3, width: 0.22)
            }
            .frame(width: size, height: size)
        }
        .allowsHitTesting(false)
    }

    /// One highlight sliding across the surface.
    private func glint(at now: TimeInterval, period: Double, offset: Double, width: CGFloat) -> some View {
        let phase = sin(now / period * 2 * .pi + offset)

        return Capsule()
            .fill(Palette.ice)
            .frame(width: size * width, height: size * 0.07)
            .offset(x: CGFloat(phase) * size * 0.2, y: CGFloat(-phase) * size * 0.14)
            .opacity(0.5)
            // Additive, so the glint is light on water rather than a white mark
            // painted on it.
            .blendMode(.plusLighter)
    }
}
