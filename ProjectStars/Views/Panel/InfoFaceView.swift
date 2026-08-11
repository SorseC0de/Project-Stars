//
//  InfoFaceView.swift
//  Project Stars
//
//  The back of the panel: what this sign actually does.
//

import SwiftUI

/// Everything about the sign in play, on the reverse of the control panel.
///
/// ## Why it is a separate face rather than always on screen
///
/// The old panel carried the sign's whole rules text at all times, which meant
/// the controls were squeezed around something the player reads twice and then
/// never again. This is the fighting-game answer: the move list is one press
/// away and you stop playing to read it. The same text is on the selection
/// screen before the run starts, so nobody meets a sign here for the first time.
struct InfoFaceView: View {

    let session: GameSession

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            entry(
                "MOVEMENT",
                session.zodiac.definition.movement.name,
                session.zodiac.definition.movement.summary
            )

            entry(
                "ZODIACTION",
                session.zodiac.definition.zodiaction.displayName,
                session.zodiac.definition.zodiaction.summary
            )

            ForEach(
                Array(session.zodiac.definition.passives.enumerated()),
                id: \.offset
            ) { index, passive in
                entry(index == 0 ? "PASSIVES" : nil, passive.displayName, passive.summary)
            }

            Spacer(minLength: 0)
        }
        .padding(GameRules.panelPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        HStack(spacing: 10) {
            SignBadgeView(zodiac: session.zodiac)
            Text(session.zodiac.definition.displayName.uppercased())
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .tracking(2)
                .foregroundStyle(Palette.gold)
        }
    }

    /// One titled block. The section label only appears on the first of a run,
    /// so three passives read as one list rather than three headings.
    @ViewBuilder
    private func entry(_ section: String?, _ name: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            if let section {
                Text(section)
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .tracking(3)
                    .foregroundStyle(Palette.lightBlue)
                    .padding(.bottom, 2)
            }

            Text(name)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Palette.white)

            Text(detail)
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(Palette.lightGray)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
