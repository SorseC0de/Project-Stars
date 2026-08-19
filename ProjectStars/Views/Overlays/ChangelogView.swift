//
//  ChangelogView.swift
//  Project Stars
//
//  What changed since the build you last played.
//

import SwiftUI

/// One line of a build's notes.
///
/// The **kind** is the whole point. A tester reading "Forced Fate is rarer"
/// cannot tell whether that was meant as a kindness or a punishment, and the
/// answer changes how they read their next run. Three colours say it without a
/// sentence of explanation each time.
struct ChangeNote: Identifiable {

    enum Kind {
        /// Something got harder or weaker.
        case nerf
        /// Something got easier or stronger.
        case buff
        /// Traded one thing for another — neither better nor worse on balance.
        case sidegrade

        var colour: Color {
            switch self {
            case .nerf: Palette.red
            case .buff: Palette.neonGreen
            case .sidegrade: Palette.sky
            }
        }
    }

    let id = UUID()
    let kind: Kind
    let text: String
}

/// A build's worth of notes, global first and then by sign.
struct ChangelogEntry {

    /// The build these notes belong to. Compared against `CFBundleVersion`, so
    /// a new build shows its notes once and never again.
    let build: String
    let global: [ChangeNote]
    let signs: [(sign: Zodiac, notes: [ChangeNote])]
}

/// The notes shown when a tester opens a build they have not played before.
///
/// Written in the language a player uses, not the language the code uses: what
/// they will notice, not what was refactored. Everything that only matters to
/// us — the wear funnel, the cover model, the movement rework — is invisible
/// here on purpose, because a tester cannot act on it.
enum Changelog {

    /// The build being handed out. Bump this and write the notes above it.
    ///
    /// A string we control rather than `CFBundleVersion`: Xcode Cloud stamps
    /// the real number after this source is built, so reading it back would
    /// mean the notes never quite line up with the build that carries them.
    /// This is also the key the "already read" flag is stored against, so
    /// bumping it is exactly what makes the splash appear again.
    static let current = ChangelogEntry(
        build: "20",
        global: [
            ChangeNote(
                kind: .sidegrade,
                text: "Pentacle odds are now real percentages. What a coin says is what it is."
            ),
            ChangeNote(kind: .nerf, text: "Forced Fate turns up far less often — about one coin in 60, down from one in 40."),
            ChangeNote(kind: .buff, text: "Tears, ZCharge and the Essences are all a little more common."),
            ChangeNote(kind: .buff, text: "The Astral Bolt hides inside the elemental Essences, so it scales with them."),
            ChangeNote(kind: .buff, text: "Coins now favour your own element slightly."),
            ChangeNote(
                kind: .sidegrade,
                text: "Grass and flowers grow on Terra. Cover soaks up one hit and wears away; water feeds it, fire burns it off."
            ),
            ChangeNote(kind: .buff, text: "A turn counter, top left. You can finally see how far you got."),
            ChangeNote(kind: .sidegrade, text: "Nexys Node: using it while stood on the island now dismisses it."),
        ],
        signs: [
            (.aries, [
                ChangeNote(kind: .buff, text: "New passive — Rebounding Ram: bouncing off a wall turns you around."),
                ChangeNote(kind: .buff, text: "The first tile you touch on a plane takes no damage."),
                ChangeNote(kind: .sidegrade, text: "Charging through a Pentacle smashes it for +2 ZC instead of collecting it."),
            ]),
            (.taurus, [
                ChangeNote(kind: .sidegrade, text: "Hasty Hooves is now Hydroponic Hooves: arriving on Terra greens the whole board, and grass takes the hit your hooves used to shrug off."),
                ChangeNote(kind: .nerf, text: "That protection is spent when it is used, where the old one never ran out."),
                ChangeNote(kind: .buff, text: "Flowering Flop lands far harder, and leaves flowers behind. From Astra it now mends 25 tiles and hands you an Astral Essence."),
                ChangeNote(kind: .sidegrade, text: "Taurean Tear leaves grass where it mended, instead of sometimes mending a third tile."),
                ChangeNote(kind: .sidegrade, text: "New passive — Stubborn Statue: nothing moves you but you. Coins that would carry you plant cover instead, for 1 ZC."),
            ]),
            (.virgo, [
                ChangeNote(kind: .buff, text: "Shine-snipes work off a slide, and pay out properly."),
                ChangeNote(kind: .buff, text: "Sniping a pink coin now forces Virgo Victorylap."),
            ]),
            (.scorpio, [
                ChangeNote(kind: .nerf, text: "The cursor no longer offers a two-square vault when the vault is not available."),
            ]),
            (.capricorn, [
                ChangeNote(kind: .buff, text: "Standing on grass or flowers, the goat can leap two squares in any direction — and the tile pays on the way out."),
            ]),
            (.aquarius, [
                ChangeNote(kind: .buff, text: "New passive — Eolian Ejection: dying on Terra with no storm spends the transformation to throw you back up to Astra."),
                ChangeNote(kind: .buff, text: "The current drags a Pentacle one square toward you as it surfaces. If it lands on you, that counts as a snipe."),
                ChangeNote(kind: .nerf, text: "Landing on Terra costs you the whole storm."),
                ChangeNote(kind: .nerf, text: "Leaving the board kills you at every phase."),
                ChangeNote(kind: .buff, text: "Waterbearer Wipeout can be fired — a ring of holes, and the glow phase becomes a squall of coins."),
            ]),
            (.leo, [
                ChangeNote(kind: .buff, text: "Phantoms stand where they should again, follow properly, and stop wearing the ground twice."),
            ]),
            (.pisces, [
                ChangeNote(kind: .buff, text: "The fish waters the ground it crosses rather than wearing it."),
            ]),
        ]
    )
}

/// The splash a tester sees once per build.
struct ChangelogView: View {

    let entry: ChangelogEntry
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Palette.midnight.opacity(0.94)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        section(title: "Everything", notes: entry.global)

                        ForEach(entry.signs, id: \.sign) { group in
                            section(
                                title: group.sign.definition.displayName,
                                notes: group.notes,
                                accent: group.sign.definition.accentColor
                            )
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.vertical, 18)
                }

                key
            }
        }
        .onTapGesture(perform: onDismiss)
    }

    private var header: some View {
        VStack(spacing: 4) {
            Text("WHAT'S NEW")
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(Palette.textPrimary)

            Text("Build \(entry.build)")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Palette.stone)
        }
        .padding(.top, 26)
        .padding(.bottom, 8)
    }

    private func section(
        title: String,
        notes: [ChangeNote],
        accent: Color = Palette.textPrimary
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(accent)

            ForEach(notes) { note in
                HStack(alignment: .top, spacing: 8) {
                    // The colour is the verdict; the dot is where it lives.
                    Circle()
                        .fill(note.kind.colour)
                        .frame(width: 7, height: 7)
                        .padding(.top, 5)

                    Text(note.text)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Palette.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// What the three colours mean, spelled out once at the bottom.
    private var key: some View {
        HStack(spacing: 14) {
            legend(.buff, "Buff")
            legend(.nerf, "Nerf")
            legend(.sidegrade, "Sidegrade")
        }
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(Palette.coolBlack.opacity(0.6))
        .overlay(alignment: .top) {
            Text("tap anywhere to play")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Palette.stone)
                .offset(y: -18)
        }
    }

    private func legend(_ kind: ChangeNote.Kind, _ label: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(kind.colour).frame(width: 7, height: 7)
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Palette.stone)
        }
    }
}
