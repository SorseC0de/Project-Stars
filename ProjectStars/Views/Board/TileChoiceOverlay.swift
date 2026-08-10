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
/// the square they can see rather than a proxy for it. **Every** square is a
/// legal answer — holes, the chasm and the Nexys included — because the effect
/// that asks (Astral Breeze) deliberately has no restrictions, and picking a
/// hole on purpose is a real play.
///
/// Taps work here where they fail in the lower panel: the board carries no
/// `DragGesture`, so nothing competes with them.
struct TileChoiceOverlay: View {

    let session: GameSession
    let metrics: PixelArtMetrics
    let accent: Color

    @State private var pulse = false

    var body: some View {
        ZStack {
            // Highlights are display only. They must not carry the gesture:
            // `.position` fills the available space, so a hit shape applied
            // after it covers the whole board rather than one square, and 49
            // board-sized targets stack into "every tap hits the last one".
            ZStack {
                ForEach(GridPoint.allPoints(size: metrics.gridSize), id: \.self) { point in
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
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture(coordinateSpace: .local) { location in
                    guard let point = metrics.gridPoint(at: location) else { return }
                    session.resolvePickupChoice(.tile(point))
                }
        }
        .frame(width: metrics.boardSize, height: metrics.boardSize)
        .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: pulse)
        .onAppear { pulse = true }
        .transition(.opacity)
    }
}
