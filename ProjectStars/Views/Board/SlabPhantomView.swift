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


    /// Which plane it will land on, so it is drawn as ground or as sky.
    var plane: Plane = .terra

    /// The square currently being aimed at.
    var anchor: GridPoint = GameRules.nexysPoint

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
                    ground(cell: cell)
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
            // Held over the square being aimed at, not parked in the middle of
            // the board. It is a preview of a placement, and a preview that does
            // not move with the thing it is previewing is a picture.
            .position(metrics.center(of: anchor))
            .frame(width: metrics.boardSize, height: metrics.boardSize)
        }
        .allowsHitTesting(false)
    }

    /// One square of the slab, drawn as the ground it will actually become.
    ///
    /// The real sprite in the real wear state, on the plane it is going to land
    /// on — cloud above, stone below. It used to be a flat rounded rectangle in
    /// roughly the right colour, which meant the player had to translate a
    /// symbol into a prediction. Drawing the thing itself removes the
    /// translation: what hovers over the cursor is what the board will look
    /// like, held up and slightly see-through.
    @ViewBuilder
    private func ground(cell: CGFloat) -> some View {
        if plane == .astra {
            CloudSpriteView(
                point: GridPoint(0, 0),
                health: slab.health,
                metrics: PixelArtMetrics(availableSide: cell * CGFloat(GameRules.gridSize)),
                clock: clock
            )
        } else {
            ZStack {
                // The edge under it, exactly as the board draws one — so a slab
                // of Terra looks like a slab and not a swatch. Drawn for every
                // square: the ones with a neighbour below have it covered, and
                // the bottom of the shape keeps it.
                // `tileFrontEdgeDrop`, not `tileEdgeDrop`.
                //
                // The board's usual drop assumes the row in front will cover the
                // gap, so used alone it hangs the edge well below the tile with
                // daylight between — which reads as no edge at all rather than
                // as a wrong one. A slab has nothing in front of it, so it wants
                // the value the board's own front row uses.
                TileEdgeView(plane: .terra, shade: .light, size: cell)
                    .offset(y: GameRules.tileFrontEdgeDrop
                        * (cell / CGFloat(GameRules.tilePixelSize)))

                TileView(
                    tile: Tile(kind: .normal, health: slab.health),
                    plane: .terra,
                    shade: .light,
                    size: cell,
                    point: GridPoint(0, 0)
                )
            }
        }
    }

    private enum Style {
        /// The size of the squares it is about to become.
        ///
        /// It was two-thirds, on the reasoning that something held above the
        /// board should look smaller than the board. That is true of a coin and
        /// false of this: the slab is a *preview*, and a preview drawn at a
        /// different size to the thing it previews is asking the player to
        /// imagine the difference. It reads as held because it floats and
        /// because you can see through it, which is enough.
        static let scale: CGFloat = 1
        static let opacity: Double = 0.66

        /// How far it drifts, in tiles.
        static let bob: Double = 0.05
    }
}
