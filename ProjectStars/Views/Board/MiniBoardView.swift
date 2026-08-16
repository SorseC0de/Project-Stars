//
//  MiniBoardView.swift
//  Project Stars
//
//  A thumbnail of the plane below, so falling isn't blind.
//

import SwiftUI

/// A compact read-only preview of another plane's tile states.
///
/// Shown in the info panel while the piece is on Astra, so the player can see
/// what is waiting under a hole before committing to it — including whether the
/// centre square is the Nexys island or the chasm it leaves behind. Deliberately
/// tiny and abstract: it is information, not a second playfield.
struct MiniBoardView: View {

    let board: Board
    let plane: Plane

    /// Total rendered edge length in points.
    var side: CGFloat = 56

    /// Highlighted square, e.g. where the piece would land. `nil` for none.
    var highlight: GridPoint?

    var body: some View {
        let cell = side / CGFloat(board.size)

        VStack(spacing: 0) {
            ForEach(0..<board.size, id: \.self) { y in
                HStack(spacing: 0) {
                    ForEach(0..<board.size, id: \.self) { x in
                        let point = GridPoint(x, y)
                        Rectangle()
                            .fill(color(for: board[point], at: point))
                            .frame(width: cell, height: cell)
                            .overlay {
                                if point == highlight {
                                    Rectangle()
                                        .strokeBorder(Palette.textPrimary, lineWidth: 1)
                                }
                            }
                    }
                }
            }
        }
        .overlay(Rectangle().strokeBorder(Palette.outline, lineWidth: 1))
    }

    private func color(for tile: Tile, at point: GridPoint) -> Color {
        switch tile.kind {
        case .normal: Palette.tileFace(tile.health, on: plane, shade: .at(point))
        case .nexys: Palette.nexysFace
        case .chasm: Palette.chasm
        case .pool: Palette.sky
        }
    }
}
