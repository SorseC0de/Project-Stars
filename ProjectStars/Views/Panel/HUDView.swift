//
//  HUDView.swift
//  Project Stars
//
//  Score, move count, and which plane you are on.
//

import SwiftUI

/// The single readout row at the top of the lower square.
struct HUDView: View {

    let session: GameSession

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            stat(label: "SCORE", value: "\(session.engine.score)")
            Spacer(minLength: 8)
            planeBadge
            Spacer(minLength: 8)
            stat(label: "MOVES", value: "\(session.engine.moveCount)", alignment: .trailing)
        }
    }

    // MARK: - Parts

    private func stat(
        label: String,
        value: String,
        alignment: HorizontalAlignment = .leading
    ) -> some View {
        VStack(alignment: alignment, spacing: 1) {
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(Palette.textSecondary)
            Text(value)
                .font(.system(size: 20, weight: .heavy, design: .monospaced))
                .foregroundStyle(Palette.textPrimary)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .trailing)
    }

    private var planeBadge: some View {
        let plane = session.visiblePlane
        return Text(plane.displayName.uppercased())
            .font(.system(size: 12, weight: .heavy, design: .monospaced))
            .tracking(2)
            .foregroundStyle(Palette.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule().fill(Palette.planeTint(plane))
            )
            .overlay(
                Capsule().strokeBorder(Palette.outline, lineWidth: 1)
            )
            .animation(.easeInOut(duration: 0.25), value: plane)
    }
}
