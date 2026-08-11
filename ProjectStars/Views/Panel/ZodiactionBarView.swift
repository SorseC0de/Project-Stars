//
//  ZodiactionBarView.swift
//  Project Stars
//
//  The meter, and the button that spends it.
//

import SwiftUI

/// The Zodiaction meter with its fire button beneath.
///
/// The button names the Zodiaction and nothing else. What it *does* is on the
/// back of the panel and on the selection screen — a player mid-run needs to
/// know it is ready and what it is called, and reading its rules is a thing they
/// stop to do.
struct ZodiactionBarView: View {

    let session: GameSession

    var body: some View {
        VStack(spacing: 8) {
            meter

            CelButton(
                tint: session.engine.isZodiactionReady ? Palette.yellow : Palette.stone,
                isEnabled: session.engine.isZodiactionReady && session.acceptsInput
            ) {
                session.fireZodiaction()
            } label: {
                VStack(spacing: 1) {
                    Text("ZODIACTION")
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .tracking(3)
                    Text(session.zodiac.definition.zodiaction.displayName.uppercased())
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .tracking(1)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                }
            }
            .frame(height: GameRules.zodiactionButtonHeight)
        }
    }

    /// Pips rather than a bar: the meter is a whole number of charges and the
    /// player counts them, which a continuous fill hides.
    private var meter: some View {
        let max = session.engine.zodiactionMeterMax
        let filled = session.engine.zodiactionMeter

        return HStack(spacing: 3) {
            ForEach(0..<max, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(index < filled ? Palette.yellow : Palette.midnight)
                    .frame(height: GameRules.meterPipHeight)
            }
        }
        .animation(.easeOut(duration: 0.18), value: filled)
    }
}
