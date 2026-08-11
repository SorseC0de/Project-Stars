//
//  GameOverOverlay.swift
//  Project Stars
//
//  End-of-run screen.
//

import SwiftUI

/// Covers the screen when a run ends.
struct GameOverOverlay: View {

    let session: GameSession

    /// Returns to piece selection.
    let onChangeSign: () -> Void

    var body: some View {
        ZStack {
            // Nearly opaque: the board stays faintly visible behind the card as
            // context, but nothing underneath competes with the text.
            Palette.background.opacity(0.93)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                Text("GAME OVER")
                    .font(.system(size: 26, weight: .heavy, design: .monospaced))
                    .tracking(4)
                    .foregroundStyle(Palette.danger)

                if let reason = session.engine.gameOverReason {
                    Text(reason.displayText)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(Palette.textSecondary)
                }

                VStack(spacing: 4) {
                    resultRow("MOVES", "\(session.engine.moveCount)")
                    resultRow("PICKUPS", "\(session.engine.pickupsCollected)")
                }
                .padding(.top, 4)

                // Plain tap gestures rather than `Button`s: this overlay sits
                // above the panel's swipe surface, and a `Button` there loses
                // gesture arbitration to it — see `SwipeInputSurface`.
                VStack(spacing: 8) {
                    Text("PLAY AGAIN")
                        .font(.system(size: 13, weight: .heavy, design: .monospaced))
                        .tracking(2)
                        .foregroundStyle(Palette.background)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(Palette.textPrimary))
                        .contentShape(Capsule())
                        .onTapGesture { session.newGame() }

                    Text("CHANGE SIGN")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .tracking(2)
                        .foregroundStyle(Palette.textSecondary)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 8)
                        .contentShape(Capsule())
                        .onTapGesture(perform: onChangeSign)
                }
                .padding(.top, 8)
            }
            .padding(28)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Palette.panel)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Palette.outline, lineWidth: 1)
                    )
            )
            .padding(24)
        }
        .transition(.opacity)
    }

    private func resultRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(Palette.textSecondary)
            Spacer(minLength: 24)
            Text(value)
                .foregroundStyle(Palette.textPrimary)
        }
        .font(.system(size: 12, weight: .bold, design: .monospaced))
        .frame(width: 180)
    }
}
