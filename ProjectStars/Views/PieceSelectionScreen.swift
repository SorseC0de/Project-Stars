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
                PlaneChip(plane: definition.empoweredPlane)
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

    /// One ability, split into its two planes wherever it says something
    /// different on each.
    ///
    /// Almost every summary in the game is written `"Astra: … Terra: …"`,
    /// because almost every ability *is* two abilities. Run together in one
    /// paragraph that is a sentence to parse; split into badged rows it is a
    /// table to scan, which is what a player comparing twelve signs is doing.
    private func labelled(_ label: String, _ body: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text(label)
                .font(.system(size: 7, weight: .bold, design: .monospaced))
                .foregroundStyle(Palette.textSecondary)
                .frame(width: 52, alignment: .leading)

            let halves = PlaneSplit(summary: body)

            if halves.isEmpty {
                prose(body)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(halves.rows, id: \.plane) { row in
                        HStack(alignment: .top, spacing: 5) {
                            PlaneChip(plane: row.plane)
                            prose(row.text)
                        }
                    }
                }
            }
        }
    }

    private func prose(_ body: String) -> some View {
        Text(body)
            .font(.system(size: 9, design: .monospaced))
            .foregroundStyle(Palette.textPrimary.opacity(0.85))
            .fixedSize(horizontal: false, vertical: true)
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

// MARK: - Plane badges

/// A plane's name in that plane's own colour.
///
/// Universal on purpose. These badges are the one thing on this screen that
/// means the same on every card, so tinting them by sign — which is what they
/// used to do — made the *sign* the information and left the plane, the thing
/// actually being named, to be read as words. `Palette.planeTint` is the same
/// pair `PlaneBadgeView` uses in play, so what the player learns here still
/// holds once the run starts.
struct PlaneChip: View {

    let plane: Plane

    var body: some View {
        Text(plane.displayName.uppercased())
            .font(.system(size: 7, weight: .heavy, design: .monospaced))
            .tracking(1)
            .foregroundStyle(Palette.textPrimary)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Capsule().fill(Palette.planeTint(plane)))
            .overlay(Capsule().strokeBorder(Palette.outline, lineWidth: 1))
            .fixedSize()
    }
}

/// A summary broken at its `"Astra:"` / `"Terra:"` markers.
///
/// Deliberately a *parse of the existing text* rather than a change to how
/// abilities declare themselves. Every summary in the game is already written
/// this way; asking eighty of them to be restructured to gain a badge would be
/// paying a large price for a small one. Anything that does not follow the
/// convention simply comes back empty and is drawn as it always was.
struct PlaneSplit {

    struct Row {
        let plane: Plane
        let text: String
    }

    let rows: [Row]

    var isEmpty: Bool { rows.isEmpty }

    init(summary: String) {
        var found: [Row] = []

        // Located by index rather than by splitting, so the halves keep their
        // order and a summary naming only one plane still works.
        let markers: [(Plane, String)] = [(.astra, "Astra:"), (.terra, "Terra:")]
        var hits: [(plane: Plane, start: String.Index, bodyStart: String.Index)] = []

        for (plane, marker) in markers {
            if let range = summary.range(of: marker) {
                hits.append((plane, range.lowerBound, range.upperBound))
            }
        }
        hits.sort { $0.start < $1.start }

        for (index, hit) in hits.enumerated() {
            let end = index + 1 < hits.count ? hits[index + 1].start : summary.endIndex
            let text = summary[hit.bodyStart..<end]
                .trimmingCharacters(in: .whitespacesAndNewlines)
                // The halves are joined by a full stop that belongs to neither
                // of them once they are separate rows.
                .trimmingCharacters(in: CharacterSet(charactersIn: ". "))
            guard !text.isEmpty else { continue }
            found.append(Row(plane: hit.plane, text: text + "."))
        }

        rows = found
    }
}

// MARK: - Preview

#Preview {
    PieceSelectionScreen(onBegin: { _ in })
        .preferredColorScheme(.dark)
}
