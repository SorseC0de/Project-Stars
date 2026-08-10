//
//  PieceChoiceOverlay.swift
//  Project Stars
//
//  Asks the player to pick a sign, mid-run. Raised by the Alignment Pentacle.
//

import SwiftUI

/// Asks the player to pick a sign.
///
/// A strip in the same idiom as the first-encounter banner rather than a
/// full-screen takeover: the board stays visible behind it, because which sign
/// you want depends entirely on the position you are looking at.
///
/// Choosing the sign you already have is explicitly allowed — see
/// `AlignmentEffect`.
struct PieceChoiceOverlay: View {

    let session: GameSession
    let onChoose: (Zodiac) -> Void

    @State private var hasAppeared = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 6)

    var body: some View {
        ZStack {
            Palette.background.opacity(0.55)
                .ignoresSafeArea()

            VStack(spacing: 10) {
                Text("ALIGNMENT")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(3)
                    .foregroundStyle(Palette.textSecondary)

                Text("CHOOSE A SIGN")
                    .font(.system(size: 16, weight: .heavy, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(Palette.pentacle)

                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(Zodiac.allCases) { sign in
                        signButton(sign)
                    }
                }

                Text("Keeping your current sign is a valid choice.")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(Palette.textSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(
                Palette.panel
                    .overlay(
                        VStack {
                            Rectangle().fill(Palette.pentacle).frame(height: 2)
                            Spacer()
                            Rectangle().fill(Palette.pentacle).frame(height: 2)
                        }
                    )
            )
            .shadow(color: .black.opacity(0.6), radius: 12)
            .scaleEffect(y: hasAppeared ? 1 : 0.2, anchor: .center)
            .opacity(hasAppeared ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                hasAppeared = true
            }
        }
        .transition(.opacity)
    }

    private func signButton(_ sign: Zodiac) -> some View {
        let definition = sign.definition
        let isCurrent = sign == session.zodiac

        return VStack(spacing: 2) {
            PieceIconView(zodiac: sign, size: 34)
            Text(definition.displayName.prefix(3).uppercased())
                .font(.system(size: 6, weight: .bold, design: .monospaced))
                .foregroundStyle(Palette.textSecondary)
        }
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(isCurrent ? definition.accentColor.opacity(0.22) : Palette.background.opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .strokeBorder(
                    isCurrent ? definition.accentColor : Palette.outline,
                    lineWidth: isCurrent ? 2 : 1
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: 7))
        .onTapGesture { onChoose(sign) }
    }
}
