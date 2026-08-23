//
//  ModeCardTuning.swift
//  Project Stars
//
//  Shaping the mode card's bars.
//

import SwiftUI

#if DEBUG

/// The two things about the card that can only be judged by looking at it.
///
/// How far the bars reach toward the screen's edges, and how far in from those
/// edges they have finished fading. Neither is derivable — they are a matter of
/// how much of the screen the card should feel like it occupies, which is a
/// drawing decision made with the card in front of you.
@Observable
@MainActor
final class ModeCardTuning {

    static let shared = ModeCardTuning()

    /// How much longer each bar is, in bar-thicknesses, all of it at the outer
    /// end. Negative shortens it.
    var length: Double = ModeCardStyle.defaultLength

    /// How much further apart the two bars sit, in bar-thicknesses. A move
    /// rather than a resize — see `ModeCardStyle.spread`.
    var spread: Double = ModeCardStyle.defaultSpread

    /// The two ends of the taper, as shares of a bar's length in from its outer
    /// edge: where the clear run stops, and where full black begins.
    var fadeFrom: Double = ModeCardStyle.defaultFadeFrom
    var fadeTo: Double = ModeCardStyle.defaultFadeTo

    /// The bars: in, held, out.
    var arrival: Double = ModeCardStyle.defaultArrival
    var hold: Double = ModeCardStyle.defaultHold
    var departure: Double = ModeCardStyle.defaultDeparture

    /// The words, timed on their own.
    var textDelay: Double = ModeCardStyle.defaultTextDelay
    var textResponse: Double = ModeCardStyle.defaultTextResponse
    var textBounce: Double = ModeCardStyle.defaultTextBounce

    func dump() {
        print("── mode card ──")
        print(String(format: "  length   %.2f bars", length))
        print(String(format: "  spread   %.2f bars", spread))
        print(String(format: "  fade     %.2f → %.2f of length", fadeFrom, fadeTo))
        print(String(format: "  bars     in %.2f  hold %.2f  out %.2f", arrival, hold, departure))
        print(String(format: "  words    delay %.2f  spring %.2f  bounce %.2f",
                     textDelay, textResponse, textBounce))
    }
}

/// The bench: reach, and taper.
struct ModeCardControls: View {

    @Bindable var tuning = ModeCardTuning.shared

    /// Puts the card back on screen, since both knobs are invisible without it.
    let onReplay: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Button("▸ play") { onReplay() }
                Button("print") { tuning.dump() }
            }

            group("shape")
            row("length", value: $tuning.length, in: -4...8, step: 0.1)
            row("spread", value: $tuning.spread, in: 0...6, step: 0.1)
            row("fade a", value: $tuning.fadeFrom, in: 0...0.9, step: 0.01)
            row("fade b", value: $tuning.fadeTo, in: 0...0.9, step: 0.01)

            group("bars")
            row("in", value: $tuning.arrival, in: 0.05...1.5, step: 0.01)
            row("hold", value: $tuning.hold, in: 0.2...5, step: 0.05)
            row("out", value: $tuning.departure, in: 0.05...1.5, step: 0.01)

            group("words")
            row("delay", value: $tuning.textDelay, in: 0...1.5, step: 0.01)
            row("spring", value: $tuning.textResponse, in: 0.05...1.2, step: 0.01)
            row("bounce", value: $tuning.textBounce, in: 0.2...1, step: 0.01)
        }
        .font(.system(size: 10, weight: .semibold, design: .monospaced))
        .foregroundStyle(Palette.stone)
        .padding(8)
        .background(Palette.midnight.opacity(0.9), in: RoundedRectangle(cornerRadius: 8))
    }

    /// A heading, so nine sliders read as three groups.
    private func group(_ name: String) -> some View {
        Text(name)
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .foregroundStyle(Palette.textSecondary)
            .padding(.top, 2)
    }

    private func row(
        _ label: String,
        value: Binding<Double>,
        in range: ClosedRange<Double>,
        step: Double
    ) -> some View {
        HStack(spacing: 6) {
            Text(label).frame(width: 44, alignment: .leading)
            Button("−") { value.wrappedValue = max(range.lowerBound, value.wrappedValue - step) }
            Slider(value: value, in: range, step: step).frame(width: 150)
            Button("+") { value.wrappedValue = min(range.upperBound, value.wrappedValue + step) }
            Text(String(format: "%.2f", value.wrappedValue))
                .frame(width: 40, alignment: .trailing)
        }
    }
}

#endif
