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

    /// How bright the prompt's streaks are.
    var warp: Double = ModeCardTuning.remembered("warp", PromptStyle.defaultWarp) {
        didSet { ModeCardTuning.remember("warp", warp) }
    }

    /// How thick one of them is.
    var thickness: Double = ModeCardTuning.remembered("thickness", PromptStyle.defaultThickness) {
        didSet { ModeCardTuning.remember("thickness", thickness) }
    }

    /// How long, and how fast.
    var streakLength: Double = ModeCardTuning.remembered("streakLength", PromptStyle.defaultStreakLength) {
        didSet { ModeCardTuning.remember("streakLength", streakLength) }
    }
    var streakSpeed: Double = ModeCardTuning.remembered("streakSpeed", PromptStyle.defaultStreakSpeed) {
        didSet { ModeCardTuning.remember("streakSpeed", streakSpeed) }
    }

    /// Whether the prompt's word leaves with its shape or goes first.
    var wordsRideOut: Bool = ModeCardTuning.rememberedFlag("wordsRideOut", true) {
        didSet { ModeCardTuning.remember("wordsRideOut", wordsRideOut ? 1 : 0) }
    }

    func dump() {
        print("── passive prompt ──")
        print(String(format: "  warp     %.2f", warp))
        print(String(format: "  thick    %.2f", thickness))
        print(String(format: "  streak   len %.2f  spd %.2f", streakLength, streakSpeed))
        print("  words    " + (wordsRideOut ? "ride out" : "go first"))
    }

    // ── Kept between builds ───────────────────────────────────────────
    //
    // A knob that resets on every rebuild is a knob you tune twice: once to
    // find the value and once to get back to it after the next compile. These
    // live in `UserDefaults` under their own prefix, debug builds only, and the
    // shipped defaults are what a fresh install reads.

    static let prefix = "modeCard."

    /// Bumped whenever a shipped default changes.
    ///
    /// Stored values otherwise win over new defaults for ever: a knob tuned to
    /// the old number reads back as that number, and the value written in the
    /// source is never seen again on any machine that has tuned it once. On a
    /// bump every knob is forgotten, so the shipped values are what comes up.
    private static let vintage = 7

    private static func checkVintage() {
        let store = UserDefaults.standard
        guard store.integer(forKey: prefix + "vintage") != vintage else { return }
        for name in names { store.removeObject(forKey: prefix + name) }
        store.set(vintage, forKey: prefix + "vintage")
    }

    private static func remembered(_ name: String, _ fallback: Double) -> Double {
        checkVintage()
        let store = UserDefaults.standard
        // `double(forKey:)` answers 0 for a key it has never seen, which is a
        // real value for most of these — so absence has to be asked about
        // separately rather than inferred from what comes back.
        guard store.object(forKey: prefix + name) != nil else { return fallback }
        return store.double(forKey: prefix + name)
    }

    private static func rememberedFlag(_ name: String, _ fallback: Bool) -> Bool {
        remembered(name, fallback ? 1 : 0) > 0.5
    }

    private static func remember(_ name: String, _ value: Double) {
        UserDefaults.standard.set(value, forKey: prefix + name)
    }

    /// Forgets every stored knob, so the next launch reads the shipped values.
    func reset() {
        let store = UserDefaults.standard
        for name in ModeCardTuning.names { store.removeObject(forKey: ModeCardTuning.prefix + name) }

        warp = PromptStyle.defaultWarp
        thickness = PromptStyle.defaultThickness
        streakLength = PromptStyle.defaultStreakLength
        streakSpeed = PromptStyle.defaultStreakSpeed
        wordsRideOut = true
    }

    static let names = [
        "warp", "thickness", "streakLength", "streakSpeed", "wordsRideOut",
    ]

}

/// The bench: reach, and taper.
struct ModeCardControls: View {

    @Bindable var tuning = ModeCardTuning.shared

    /// Fires a sample announcement, since every knob here is invisible without
    /// one on screen.
    let onTrigger: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Button("▸ sample") { onTrigger() }
                Button("print") { tuning.dump() }
                Button("reset") { tuning.reset() }
            }

            row("warp", value: $tuning.warp, in: 0...1, step: 0.01)
            row("thick", value: $tuning.thickness, in: 0.5...12, step: 0.1)
            row("len", value: $tuning.streakLength, in: 0.02...1.2, step: 0.01)
            row("spd", value: $tuning.streakSpeed, in: 0.02...2, step: 0.01)

            Button(tuning.wordsRideOut ? "words: ride out" : "words: go first") {
                tuning.wordsRideOut.toggle()
            }
        }
        .font(.system(size: 10, weight: .semibold, design: .monospaced))
        .foregroundStyle(Palette.stone)
        .padding(8)
        .background(Palette.midnight.opacity(0.9), in: RoundedRectangle(cornerRadius: 8))
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
