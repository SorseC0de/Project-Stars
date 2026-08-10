//
//  ZodiactionMeterView.swift
//  Project Stars
//
//  The super charge bar and its fire button.
//

import SwiftUI

/// Shows how charged the current sign's Zodiaction is.
///
/// The meter only ever moves when a move resolves — it is charged by
/// `Zodiaction.meterGain(from:context:)`, never by elapsed time.
///
/// ## This is a readout, not a control
///
/// Firing is a **double-tap anywhere in the input zone**, handled by
/// `SwipeInputSurface`. That is not a stylistic choice: a tappable control
/// placed in this panel does not work. The panel's `DragGesture` wins gesture
/// arbitration against it and the tap never arrives — verified against `Button`,
/// against a bare `TapGesture`, against `simultaneousGesture` and
/// `highPriorityGesture`, and with the drag surface moved out of the control's
/// ancestry into a sibling layer. The only arrangement that ever fired was one
/// with no `DragGesture` in the panel at all. Two gestures on the *same* view
/// compose fine, so the trigger lives there instead.
///
/// - TODO: Double-tap is an interim trigger — the real input for a Zodiaction is
///   still undesigned. Whatever replaces it should call
///   `GameSession.fireZodiaction()` and nothing else. If it needs to be an on-screen
///   control, it has to live outside the swipe zone.
struct ZodiactionMeterView: View {

    let session: GameSession

    var body: some View {
        let definition = session.zodiac.definition
        let ready = session.engine.isZodiactionReady

        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("ZODIACTION")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(Palette.textSecondary)

                    Text(definition.zodiaction.displayName)
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .foregroundStyle(ready ? definition.accentColor : Palette.textSecondary)

                    Spacer(minLength: 0)

                    Text("\(session.engine.zodiactionMeter)/\(session.engine.zodiactionMeterMax)")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(Palette.textSecondary)
                        .contentTransition(.numericText())
                }

                meterPips(accent: definition.accentColor, ready: ready)
            }
            // The readout is display only, so drags started on it still reach
            // the swipe surface behind the panel. Only the button takes touches.
            .allowsHitTesting(false)

            readyIndicator(accent: definition.accentColor, ready: ready)
        }
    }

    // MARK: - Parts

    /// The meter, drawn as discrete pips rather than a continuous bar.
    ///
    /// Ticks, not a fill: the player needs to count how many moves are left
    /// before the Zodiaction is available, and a smooth bar hides that. One pip
    /// per point, and the meter simply stays full until it is popped.
    private func meterPips(accent: Color, ready: Bool) -> some View {
        let max = session.engine.zodiactionMeterMax
        let filled = session.engine.zodiactionMeter

        return HStack(spacing: 3) {
            ForEach(0..<max, id: \.self) { index in
                Capsule()
                    .fill(index < filled ? (ready ? accent : accent.opacity(0.75))
                                         : Palette.background.opacity(0.8))
                    .overlay(Capsule().strokeBorder(Palette.outline, lineWidth: 1))
                    .frame(height: 8)
            }
        }
        .animation(.easeOut(duration: 0.2), value: filled)
        // A full meter glows, so "ready" reads without counting.
        .shadow(color: ready ? accent.opacity(0.8) : .clear, radius: 4)
    }

    /// Charge state at a glance. Deliberately inert — see the type's note.
    private func readyIndicator(accent: Color, ready: Bool) -> some View {
        Text(ready ? "READY" : "—")
            .font(.system(size: 9, weight: .heavy, design: .monospaced))
            .tracking(1)
            .foregroundStyle(ready ? Palette.background : Palette.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(ready ? accent : Palette.background.opacity(0.6))
            )
            .overlay(
                Capsule().strokeBorder(Palette.outline, lineWidth: 1)
            )
            .opacity(ready ? 1 : 0.5)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: ready)
            // Inert: firing is a double-tap on the input zone.
            .allowsHitTesting(false)
            .accessibilityLabel(ready ? "Zodiaction charged" : "Zodiaction charging")
    }
}
