//
//  PieceSelectionScreen.swift
//  Project Stars
//
//  Choosing a sign, before a run starts.
//

import SwiftUI

/// The screen shown before a run: pick which of the twelve to play.
///
/// Selection happens **here and nowhere else**. Once a run is underway the sign
/// is fixed for its duration — the only things that may change it mid-run are
/// two rare Pentacles that do not exist yet. That is why this is a separate
/// screen rather than a control inside the game: the choice is a commitment, and
/// it should feel like one.
///
/// - Note: The `#if DEBUG` picker in `ControlPanelView` deliberately violates
///   that rule so any sign can be dropped onto the board while the game is being
///   built. Delete it, not this screen, when debugging aids come out.
struct PieceSelectionScreen: View {

    /// Called with the chosen sign when the player commits.
    let onBegin: (Zodiac) -> Void

    @State private var selection: Zodiac = .aries

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

    var body: some View {
        let definition = selection.definition

        VStack(spacing: 0) {
            header

            grid

            Spacer(minLength: 12)

            detail(definition)

            beginButton(definition)
                .padding(.top, 14)
                .padding(.bottom, 24)
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.background)
    }

    // MARK: - Parts

    private var header: some View {
        VStack(spacing: 4) {
            Text("PROJECT STARS")
                .font(.system(size: 20, weight: .heavy, design: .monospaced))
                .tracking(4)
                .foregroundStyle(Palette.textPrimary)

            Text("CHOOSE YOUR SIGN")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(3)
                .foregroundStyle(Palette.textSecondary)
        }
        .padding(.top, 40)
        .padding(.bottom, 26)
    }

    private var grid: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(Zodiac.allCases) { sign in
                tile(for: sign)
            }
        }
    }

    private func tile(for sign: Zodiac) -> some View {
        let definition = sign.definition
        let isSelected = sign == selection

        return VStack(spacing: 5) {
            PieceIconView(zodiac: sign, size: 42)

            Text(definition.displayName.uppercased())
                .font(.system(size: 7, weight: .bold, design: .monospaced))
                .foregroundStyle(isSelected ? Palette.textPrimary : Palette.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? definition.accentColor.opacity(0.22) : Palette.panel)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(
                    isSelected ? definition.accentColor : Palette.outline,
                    lineWidth: isSelected ? 2 : 1
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: 10))
        .onTapGesture {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                selection = sign
            }
        }
    }

    /// What the highlighted sign brings. Reads from the definition, so it fills
    /// itself in as the designs land.
    private func detail(_ definition: ZodiacDefinition) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(definition.displayName.uppercased())
                    .font(.system(size: 16, weight: .heavy, design: .monospaced))
                    .foregroundStyle(definition.accentColor)

                Text("\(definition.element.displayName.uppercased()) · \(definition.movement.summary.uppercased())")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(Palette.textSecondary)
            }

            // Which plane this sign wants to be on is the single most useful
            // thing to know before committing to it.
            HStack(spacing: 5) {
                Text("STRONG ON")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(Palette.textSecondary)
                Text(definition.empoweredPlane.displayName.uppercased())
                    .font(.system(size: 8, weight: .heavy, design: .monospaced))
                    .foregroundStyle(Palette.background)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(definition.accentColor))
            }

            ForEach(Array(definition.passives.enumerated()), id: \.offset) { _, passive in
                labelled("PASSIVE", passive.summary)
            }
            labelled("ZODIACTION", definition.zodiaction.summary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(Palette.panel))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Palette.outline, lineWidth: 1)
        )
    }

    private func labelled(_ label: String, _ body: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text(label)
                .font(.system(size: 7, weight: .bold, design: .monospaced))
                .foregroundStyle(Palette.textSecondary)
                .frame(width: 52, alignment: .leading)
            Text(body)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(Palette.textPrimary.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func beginButton(_ definition: ZodiacDefinition) -> some View {
        Text("BEGIN")
            .font(.system(size: 14, weight: .heavy, design: .monospaced))
            .tracking(3)
            .foregroundStyle(Palette.background)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Capsule().fill(definition.accentColor))
            .contentShape(Capsule())
            .onTapGesture { onBegin(selection) }
    }
}

// MARK: - Preview

#Preview {
    PieceSelectionScreen(onBegin: { _ in })
        .preferredColorScheme(.dark)
}
