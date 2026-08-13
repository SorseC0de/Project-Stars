//
//  TileChoiceOverlay.swift
//  Project Stars
//
//  Asks the player to pick a square. Lives with the board it is laid over.
//

import SwiftUI

/// Asks the player to pick a square on the board.
///
/// Laid directly over the grid, matching its metrics exactly, so the player taps
/// the square they can see rather than a proxy for it.
///
/// ## Two shapes of question
///
/// `PickupChoice.tile` allows **every** square — holes, the chasm and the Nexys
/// included — because the effect that asks (Astral Breeze) deliberately has no
/// restrictions, and picking a hole on purpose is a real play.
///
/// `PickupChoice.among` names a handful instead, and may be **declined**. That
/// is what an always-on ability offering something on arrival looks like:
/// Aquarius' Corner Current is not a prize to be collected, it is a door left
/// open, and a door you cannot walk past is a corridor.
///
/// Taps work here where they fail in the lower panel: the board carries no
/// `DragGesture`, so nothing competes with them.
struct TileChoiceOverlay: View {

    let session: GameSession
    let metrics: PixelArtMetrics
    let accent: Color

    @State private var pulse = false

    /// True when the answer is being collected on the pad in the control area
    /// instead of here.
    ///
    /// The board still draws what is being *held* — Libra's slab hangs over the
    /// grid whichever scheme is running, because it is a thing in the world —
    /// and still offers the way to decline. What moves down to the pad is the
    /// aiming, which is the part that wants a thumb.
    ///
    /// Always, now. It was briefly conditional on the third control scheme being
    /// active, which left the other two answering on the board — the exact
    /// arrangement the change was meant to replace.
    private var answeredBelow: Bool { true }

    var body: some View {
        let allowed = session.choosableTiles

        if let slab = session.placingSlab {
            placement(slab)
        } else {
            picker(allowed)
        }
    }

    // MARK: - Placing a slab

    /// Libra aiming the Galeforce Gavel.
    ///
    /// The slab floats over the board rather than under the finger, because the
    /// finger is on top of the answer: the player has to be able to see the
    /// squares the shape would cover, and a hand covering three of four of them
    /// is the whole reason a phantom exists.
    ///
    /// Green where it would land, red where it would not. Drawn for **every**
    /// anchor at once rather than following a hover, since a phone has no hover
    /// — the board simply shows where the shape fits, and the player taps one.
    private func placement(_ slab: GavelSlab) -> some View {
        ZStack {
            ForEach(answeredBelow ? [] : GridPoint.allPoints(size: metrics.gridSize), id: \.self) { anchor in
                let fits = slab.canBePlaced(anchoredAt: anchor, on: session.engine.currentBoard)

                Rectangle()
                    .fill((fits ? Palette.jade : Palette.red).opacity(pulse ? 0.30 : 0.14))
                    .overlay(
                        Rectangle().strokeBorder(
                            (fits ? Palette.jade : Palette.red).opacity(0.85),
                            lineWidth: 1
                        )
                    )
                    .frame(width: metrics.tileSize, height: metrics.tileSize)
                    .position(metrics.center(of: anchor))
            }
            .allowsHitTesting(false)

            if !answeredBelow {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture(coordinateSpace: .local) { location in
                        guard let anchor = metrics.gridPoint(at: location) else { return }
                        guard slab.canBePlaced(
                            anchoredAt: anchor, on: session.engine.currentBoard
                        ) else { return }
                        session.resolvePickupChoice(.place(slab, anchor))
                    }
            }

            SlabPhantomView(slab: slab, metrics: metrics)
                .allowsHitTesting(false)
        }
        .frame(width: metrics.boardSize, height: metrics.boardSize)
        .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: pulse)
        .onAppear { pulse = true }
        .transition(.opacity)
    }

    // MARK: - Picking a square

    private func picker(_ allowed: [GridPoint]?) -> some View {
        ZStack {
            // Highlights are display only. They must not carry the gesture:
            // `.position` fills the available space, so a hit shape applied
            // after it covers the whole board rather than one square, and 49
            // board-sized targets stack into "every tap hits the last one".
            ZStack {
                ForEach(answeredBelow ? [] : highlighted(allowed), id: \.self) { point in
                    Rectangle()
                        .fill(accent.opacity(pulse ? 0.22 : 0.10))
                        .overlay(
                            Rectangle().strokeBorder(accent.opacity(0.8), lineWidth: 1)
                        )
                        .frame(width: metrics.tileSize, height: metrics.tileSize)
                        .position(metrics.center(of: point))
                }
            }
            .allowsHitTesting(false)

            // One tap surface for the whole grid, resolved back to a square
            // through the same metrics that laid the board out — so the square
            // the player taps is by construction the square they see.
            if !answeredBelow {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture(coordinateSpace: .local) { location in
                        guard let point = metrics.gridPoint(at: location) else { return }
                        // A tap outside the offered set is not an answer. Ignored
                        // rather than treated as a decline: a mis-tap should cost
                        // nothing, and the way to say no is to say no.
                        if let allowed, !allowed.contains(point) { return }
                        session.resolvePickupChoice(.tile(point))
                    }
            }

        }
        .frame(width: metrics.boardSize, height: metrics.boardSize)
        .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: pulse)
        .onAppear { pulse = true }
        .transition(.opacity)
    }

    /// Which squares to light up.
    private func highlighted(_ allowed: [GridPoint]?) -> [GridPoint] {
        allowed ?? GridPoint.allPoints(size: metrics.gridSize)
    }
}
