//
//  SlabPhantomView.swift
//  Project Stars
//
//  The slab Libra is about to drop, hovering over the board.
//

import SwiftUI

/// The Galeforce Gavel's slab, drawn floating above the grid while Libra decides
/// where to put it.
///
/// ## Why it hovers over the middle rather than following the finger
///
/// A phone has no hover. There is nowhere to put a preview that tracks a pointer
/// because there is no pointer until a finger lands, and by then the finger is
/// covering the answer. So the phantom sits over the centre of the board saying
/// *this is what you are holding*, and the grid underneath says *and here is
/// where it fits* — see `TileChoiceOverlay.placement(_:)`.
///
/// ## Why it shows its wear state
///
/// The slab may arrive as anything from healthy ground to a hole, and which one
/// it is changes the decision completely: a healthy block wants to go where you
/// are about to walk, and a hole-shaped one wants to go as far from that as
/// possible. Drawing it in the tile colours it will actually take means the
/// player reads that the same way they read the rest of the board.
struct SlabPhantomView: View {

    let slab: GavelSlab
    let metrics: PixelArtMetrics

    /// The ambient clock, which stops while the game waits on the player.
    ///
    /// Ambient motion carrying on under a frozen game is the clearest possible
    /// signal that nothing is waiting on anything. See
    /// `GameSession.ambientClock(at:)`.
    var clock: (TimeInterval) -> TimeInterval = { $0 }


    var body: some View {
        // Squares relative to the shape's own top-left, so the drawing is
        // centred on itself rather than on wherever its anchor happens to sit.
        let cells = slab.squares(anchoredAt: GridPoint(0, 0))
        let minX = cells.map(\.x).min() ?? 0
        let minY = cells.map(\.y).min() ?? 0
        let width = (cells.map(\.x).max() ?? 0) - minX + 1
        let height = (cells.map(\.y).max() ?? 0) - minY + 1

        let cell = metrics.tileSize * Style.scale

        TimelineView(.animation) { timeline in
            let bob = sin(clock(timeline.date.timeIntervalSinceReferenceDate) * 2) * Style.bob

            ZStack(alignment: .topLeading) {
                ForEach(cells, id: \.self) { point in
                    RoundedRectangle(cornerRadius: cell * 0.12)
                        .fill(face)
                        .overlay(
                            RoundedRectangle(cornerRadius: cell * 0.12)
                                .strokeBorder(Palette.textPrimary.opacity(0.5), lineWidth: 1)
                        )
                        .frame(width: cell, height: cell)
                        .offset(
                            x: CGFloat(point.x - minX) * cell,
                            y: CGFloat(point.y - minY) * cell
                        )
                }
            }
            .frame(width: CGFloat(width) * cell, height: CGFloat(height) * cell)
            .shadow(color: Palette.coolBlack.opacity(0.55), radius: cell * 0.25, y: cell * 0.3)
            .opacity(Style.opacity)
            .offset(y: CGFloat(bob) * metrics.tileSize)
            .frame(width: metrics.boardSize, height: metrics.boardSize)
        }
        .allowsHitTesting(false)
    }

    /// The colour the ground will actually arrive as.
    private var face: Color {
        slab.health.isHole
            ? Palette.chasm
            : Palette.tileFace(slab.health, on: .terra, shade: .light)
    }

    private enum Style {
        /// Smaller than a board square, so it reads as something held above the
        /// grid rather than as part of it.
        static let scale: CGFloat = 0.62
        static let opacity: Double = 0.9

        /// How far it drifts, in tiles.
        static let bob: Double = 0.05
    }
}
