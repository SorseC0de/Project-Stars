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
    var length: Double = ModeCardTuning.remembered("length", ModeCardStyle.defaultLength) {
        didSet { ModeCardTuning.remember("length", length) }
    }

    /// How much further apart the two bars sit, in bar-thicknesses. A move
    /// rather than a resize — see `ModeCardStyle.spread`.
    var spread: Double = ModeCardTuning.remembered("spread", ModeCardStyle.defaultSpread) {
        didSet { ModeCardTuning.remember("spread", spread) }
    }

    /// The two ends of the taper, as shares of a bar's length in from its outer
    /// edge: where the clear run stops, and where full black begins.
    var fadeFrom: Double = ModeCardTuning.remembered("fadeFrom", ModeCardStyle.defaultFadeFrom) {
        didSet { ModeCardTuning.remember("fadeFrom", fadeFrom) }
    }
    var fadeTo: Double = ModeCardTuning.remembered("fadeTo", ModeCardStyle.defaultFadeTo) {
        didSet { ModeCardTuning.remember("fadeTo", fadeTo) }
    }

    /// The bars: in, and out. There is nothing between them to time — the card
    /// is held until Start is pressed.
    var arrival: Double = ModeCardTuning.remembered("arrival", ModeCardStyle.defaultArrival) {
        didSet { ModeCardTuning.remember("arrival", arrival) }
    }
    var departure: Double = ModeCardTuning.remembered("departure", ModeCardStyle.defaultDeparture) {
        didSet { ModeCardTuning.remember("departure", departure) }
    }

    /// The words, timed on their own.
    var textDelay: Double = ModeCardTuning.remembered("textDelay", ModeCardStyle.defaultTextDelay) {
        didSet { ModeCardTuning.remember("textDelay", textDelay) }
    }
    var textResponse: Double = ModeCardTuning.remembered("textResponse", ModeCardStyle.defaultTextResponse) {
        didSet { ModeCardTuning.remember("textResponse", textResponse) }
    }
    var textBounce: Double = ModeCardTuning.remembered("textBounce", ModeCardStyle.defaultTextBounce) {
        didSet { ModeCardTuning.remember("textBounce", textBounce) }
    }

    // ── Kept between builds ───────────────────────────────────────────
    //
    // A knob that resets on every rebuild is a knob you tune twice: once to
    // find the value and once to get back to it after the next compile. These
    // live in `UserDefaults` under their own prefix, debug builds only, and the
    // shipped defaults are what a fresh install reads.

    private static let prefix = "modeCard."

    private static func remembered(_ name: String, _ fallback: Double) -> Double {
        let store = UserDefaults.standard
        // `double(forKey:)` answers 0 for a key it has never seen, which is a
        // real value for most of these — so absence has to be asked about
        // separately rather than inferred from what comes back.
        guard store.object(forKey: prefix + name) != nil else { return fallback }
        return store.double(forKey: prefix + name)
    }

    private static func remember(_ name: String, _ value: Double) {
        UserDefaults.standard.set(value, forKey: prefix + name)
    }

    /// Forgets every stored knob, so the next launch reads the shipped values.
    func reset() {
        let store = UserDefaults.standard
        for name in ModeCardTuning.names { store.removeObject(forKey: ModeCardTuning.prefix + name) }

        length = ModeCardStyle.defaultLength
        spread = ModeCardStyle.defaultSpread
        fadeFrom = ModeCardStyle.defaultFadeFrom
        fadeTo = ModeCardStyle.defaultFadeTo
        arrival = ModeCardStyle.defaultArrival
        departure = ModeCardStyle.defaultDeparture
        textDelay = ModeCardStyle.defaultTextDelay
        textResponse = ModeCardStyle.defaultTextResponse
        textBounce = ModeCardStyle.defaultTextBounce
    }

    private static let names = [
        "length", "spread", "fadeFrom", "fadeTo",
        "arrival", "departure", "textDelay", "textResponse", "textBounce",
    ]

    func dump() {
        print("── mode card ──")
        print(String(format: "  length   %.2f bars", length))
        print(String(format: "  spread   %.2f bars", spread))
        print(String(format: "  fade     %.2f → %.2f of length", fadeFrom, fadeTo))
        print(String(format: "  bars     in %.2f  out %.2f", arrival, departure))
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
                Button("reset") { tuning.reset() }
            }

            group("shape")
            row("length", value: $tuning.length, in: -4...8, step: 0.1)
            // Centred on zero, so the slider's middle is the card as drawn and
            // either half of its travel is a decision. Negative draws the two
            // bars *toward* each other, past the overlap the sequence has.
            row("spread", value: $tuning.spread, in: -6...6, step: 0.1)
            row("fade a", value: $tuning.fadeFrom, in: 0...0.9, step: 0.01)
            row("fade b", value: $tuning.fadeTo, in: 0...0.9, step: 0.01)

            group("bars")
            row("in", value: $tuning.arrival, in: 0.05...1.5, step: 0.01)
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
