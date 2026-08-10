//
//  PauseMenuView.swift
//  Project Stars
//
//  Pause, restart, or back out to piece selection.
//

import SwiftUI

/// The pause menu.
///
/// Built as a strip over a dimmed board rather than a full-screen takeover, in
/// the same idiom as the Pentacle splash — pausing to restart is usually a
/// reaction to the position you are looking at, so the position stays visible.
struct PauseMenuView: View {

    let session: GameSession

    /// Leaves the run entirely and returns to piece selection.
    let onQuit: () -> Void

    @State private var hasAppeared = false

    var body: some View {
        ZStack {
            Palette.background.opacity(0.55)
                .ignoresSafeArea()
                // Tapping the dimmed area resumes, which is the fastest way out
                // of a menu opened by accident.
                .contentShape(Rectangle())
                .onTapGesture { session.resume() }

            VStack(spacing: 12) {
                Text("PAUSED")
                    .font(.system(size: 16, weight: .heavy, design: .monospaced))
                    .tracking(4)
                    .foregroundStyle(Palette.textPrimary)

                runSummary

                VStack(spacing: 7) {
                    button("RESUME", tint: Palette.textPrimary) { session.resume() }
                    button("RESTART RUN", tint: Palette.pentacle) { session.restart() }
                    button("CHANGE SIGN", tint: Palette.textSecondary) {
                        session.resume()
                        onQuit()
                    }
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity)
            .background(
                Palette.panel.overlay(
                    VStack {
                        Rectangle().fill(Palette.outline).frame(height: 2)
                        Spacer()
                        Rectangle().fill(Palette.outline).frame(height: 2)
                    }
                )
            )
            .shadow(color: .black.opacity(0.6), radius: 12)
            .scaleEffect(y: hasAppeared ? 1 : 0.2, anchor: .center)
            .opacity(hasAppeared ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                hasAppeared = true
            }
        }
        .transition(.opacity)
    }

    // MARK: - Parts

    /// Where the run stands, so the decision to restart is an informed one.
    private var runSummary: some View {
        HStack(spacing: 14) {
            stat("SCORE", "\(session.engine.score)")
            stat("MOVES", "\(session.engine.moveCount)")
            stat("PENTACLES", "\(session.engine.pickupsCollected)")
            stat("PLANE", session.visiblePlane.displayName.uppercased())
        }
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 1) {
            Text(label)
                .font(.system(size: 7, weight: .bold, design: .monospaced))
                .foregroundStyle(Palette.textSecondary)
            Text(value)
                .font(.system(size: 12, weight: .heavy, design: .monospaced))
                .foregroundStyle(Palette.textPrimary)
        }
    }

    private func button(
        _ title: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .heavy, design: .monospaced))
                .tracking(2)
                .foregroundStyle(Palette.background)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(Capsule().fill(tint))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - PauseButton

/// The small control that opens the menu.
///
/// Lives in a corner of the board square, which carries no drag gesture — so
/// unlike the lower panel, an ordinary button works here without fighting
/// anything for the touch.
struct PauseButton: View {

    let action: () -> Void

    var body: some View {
        Button(action: action) {
            // Two bars: unmistakable at 20pt and needs no glyph font.
            HStack(spacing: 3) {
                ForEach(0..<2, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Palette.textSecondary)
                        .frame(width: 3, height: 11)
                }
            }
            .frame(width: 28, height: 28)
            .background(
                Circle()
                    .fill(Palette.panel.opacity(0.85))
                    .overlay(Circle().strokeBorder(Palette.outline, lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
    }
}
