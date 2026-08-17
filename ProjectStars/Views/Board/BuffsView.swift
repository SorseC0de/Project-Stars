//
//  BuffsView.swift
//  Project Stars
//
//  What is currently true about you, left of the plane's name.
//

import SwiftUI

/// The temporary effects the player is carrying, as a row of marks.
///
/// Grows **leftward** from the plane badge, so nothing already on screen moves
/// when one arrives or expires. A row that grew rightward would push the plane's
/// name around, and the name is the one fixed landmark up here — a HUD element
/// that relocates because something unrelated started is a HUD element the
/// player has to re-find every time.
///
/// ## Why this is a row rather than named badges
///
/// Because there is no limit to how many can run at once. Polaris got its own
/// badge when it was the only thing being carried, and the two Essences, the
/// star and Stelluna Sprite make that pattern a queue of special cases. One row
/// that anything can join costs the same as the second badge would have.
///
/// Each mark shows its remaining moves when it has a count. A buff with no
/// number is one that ends on a condition rather than a clock — Stelluna's
/// hole-walk lasts until you use it — and a made-up number would be worse than
/// none.
struct BuffsView: View {

    let session: GameSession

    private enum Style {
        static let size: CGFloat = 18
        static let spacing: CGFloat = 6
        static let countSize: CGFloat = 9
    }

    var body: some View {
        HStack(spacing: Style.spacing) {
            ForEach(buffs, id: \.icon) { buff in
                mark(buff)
            }
        }
    }

    /// What is running, in the order it should be read.
    private var buffs: [(icon: String, tint: Color, moves: Int?)] {
        var out: [(String, Color, Int?)] = []
        let state = session.engine.signState

        if state.astralEssenceMoves > 0 {
            out.append((
                "soul",
                ElementFX.ramp(for: .air).bright,
                state.astralEssenceMoves
            ))
        }

        if state.umbralEssenceMoves > 0 {
            out.append((
                "essence",
                Palette.lavender,
                state.umbralEssenceMoves
            ))
        }

        return out
    }

    private func mark(_ buff: (icon: String, tint: Color, moves: Int?)) -> some View {
        Image(buff.icon)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: Style.size, height: Style.size)
            .foregroundStyle(buff.tint)
            .padding(4)
            .background {
                Circle().fill(Palette.midnight.opacity(0.8))
            }
            .overlay(alignment: .bottomTrailing) {
                if let moves = buff.moves {
                    Text("\(moves)")
                        .font(.system(size: Style.countSize, weight: .heavy, design: .rounded))
                        .foregroundStyle(Palette.white)
                        .padding(.horizontal, 3)
                        .background(Capsule().fill(Palette.warmBlack))
                        .offset(x: 3, y: 2)
                }
            }
    }
}
