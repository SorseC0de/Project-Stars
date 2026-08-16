//
//  DebugSpawnGrid.swift
//  Project Stars
//
//  Where to put the thing the spawner is holding.
//

import SwiftUI

#if DEBUG

/// The board as a grid of targets, for placing a chosen Pentacle.
///
/// Its own view rather than a mode of `GridPadView`, which answers a question
/// the *game* asked and is bound to the rules about which squares are legal.
/// This one has no rules: any square, any coin, including squares the game
/// would never offer. Folding the two together would mean teaching the real
/// control about a case that must never reach a player.
///
/// - TODO: **Debug only.** Never ships.
struct DebugSpawnGrid: View {

    let session: GameSession

    /// Edge length of the square this fills, in points.
    let side: CGFloat

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                if let holding = session.debugSpawning {
                    Text(PickupCatalog.effect(for: holding).glyph)
                        .font(.system(size: 15))

                    Text(PickupCatalog.effect(for: holding).displayName.uppercased())
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .foregroundStyle(Palette.white)
                }

                Spacer(minLength: 0)

                Button("CANCEL") { session.debugSpawning = nil }
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .foregroundStyle(Palette.blush)
            }
            .padding(.horizontal, 4)

            grid
        }
        .frame(width: side, height: side)
    }

    private var grid: some View {
        // Sized off whatever is left after the header, so the squares stay
        // square however the panel's rows are laid out.
        GeometryReader { proxy in
            let cell = min(proxy.size.width, proxy.size.height) / CGFloat(GameRules.gridSize)

            VStack(spacing: 0) {
                ForEach(0..<GameRules.gridSize, id: \.self) { row in
                    HStack(spacing: 0) {
                        ForEach(0..<GameRules.gridSize, id: \.self) { column in
                            square(GridPoint(column, row), cell: cell)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func square(_ point: GridPoint, cell: CGFloat) -> some View {
        let tile = session.visibleBoard[point]
        let isHole = tile.kind == .chasm || tile.health.isHole

        return Rectangle()
            .fill(isHole ? Palette.coolBlack : Palette.midnight)
            .overlay {
                Rectangle()
                    .strokeBorder(Palette.outline.opacity(0.6), lineWidth: 1)
            }
            .overlay {
                // The piece's own square, so the board in the panel can be read
                // against the board on screen without counting rows.
                if session.engine.piece.point == point {
                    Circle()
                        .fill(Palette.yellowGreen)
                        .padding(cell * 0.3)
                }
            }
            .frame(width: cell, height: cell)
            .contentShape(Rectangle())
            .onTapGesture {
                guard let holding = session.debugSpawning else { return }
                session.debugSpawn(holding, at: point)
            }
    }
}

#endif
