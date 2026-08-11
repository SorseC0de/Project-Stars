//
//  ZodiactionBarView.swift
//  Project Stars
//
//  The button that spends the meter, with the meter in it.
//

import SwiftUI

/// The Zodiaction button: its name, and how charged it is, as one control.
///
/// ## Why the meter is inside the button
///
/// They are the same fact. A separate bar above a separate button asks the
/// player to connect two things that are always about each other; putting the
/// charge *on* the thing it charges says it once.
///
/// The button names the Zodiaction and nothing else. What it does is on the back
/// of the panel and on the selection screen — mid-run a player needs to know it
/// is ready and what it is called, and reading its rules is a thing they stop to
/// do.
struct ZodiactionBarView: View {

    let session: GameSession

    var body: some View {
        // Read from the session rather than reaching into the engine, so the
        // button tracks the meter however it changed — including from a debug
        // key, which is where it was previously found lagging.
        let ready = session.isZodiactionReady

        CelButton(
            tint: ready ? Palette.yellow : Palette.stone,
            isEnabled: ready && session.acceptsInput
        ) {
            session.fireZodiaction()
        } label: {
            VStack(spacing: 5) {
                Text(session.zodiac.definition.zodiaction.displayName.uppercased())
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .tracking(1)
                    .minimumScaleFactor(0.55)
                    .lineLimit(1)

                meter
            }
            .padding(.horizontal, 16)
        }
        .frame(height: GameRules.zodiactionButtonHeight)
    }

    /// Pips rather than a bar: the meter is a whole number of charges and the
    /// player counts them, which a continuous fill hides.
    private var meter: some View {
        let filled = session.zodiactionMeter
        let capacity = session.zodiactionMeterMax

        return HStack(spacing: 3) {
            ForEach(0..<capacity, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(index < filled ? Palette.warmBlack : Palette.warmBlack.opacity(0.22))
                    .frame(height: GameRules.meterPipHeight)
            }
        }
        .animation(.easeOut(duration: 0.18), value: filled)
    }
}
