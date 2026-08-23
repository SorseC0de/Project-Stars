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

    /// Which tunnel is showing: the wormhole, or the parked side-on field.
    var sideOn: Bool = ModeCardTuning.rememberedFlag("sideOn") {
        didSet { ModeCardTuning.remember("sideOn", sideOn ? 1 : 0) }
    }

    /// How bright the warp streaks running through the bars are.
    var warp: Double = ModeCardTuning.remembered("warp", ModeCardStyle.defaultWarp) {
        didSet { ModeCardTuning.remember("warp", warp) }
    }

    /// How thick a capsule is at the rim.
    var thickness: Double = ModeCardTuning.remembered("thickness", ModeCardStyle.defaultThickness) {
        didSet { ModeCardTuning.remember("thickness", thickness) }
    }

    /// The clear eye at the middle of the tunnel.
    var core: Double = ModeCardTuning.remembered("core", ModeCardStyle.defaultCore) {
        didSet { ModeCardTuning.remember("core", core) }
    }

    /// How many of the tunnel's marks are stars rather than streaks.
    var stars: Double = ModeCardTuning.remembered("stars", ModeCardStyle.defaultStars) {
        didSet { ModeCardTuning.remember("stars", stars) }
    }

    /// How the tunnel is laid over the bars.
    ///
    /// Kept as a place in `BlendMode.pickable` rather than as the mode itself:
    /// `BlendMode` is not something that can be written to `UserDefaults`, and
    /// its place in that list is stable in a way a raw value would not be.
    var blendIndex: Int = Int(ModeCardTuning.remembered("blendIndex", ModeCardTuning.defaultBlendIndex)) {
        didSet { ModeCardTuning.remember("blendIndex", Double(blendIndex)) }
    }

    var blend: BlendMode {
        BlendMode.pickable[min(max(blendIndex, 0), BlendMode.pickable.count - 1)]
    }

    static let defaultBlendIndex = Double(
        BlendMode.pickable.firstIndex(of: ModeCardStyle.defaultBlend) ?? 0
    )

    // ── Kept between builds ───────────────────────────────────────────
    //
    // A knob that resets on every rebuild is a knob you tune twice: once to
    // find the value and once to get back to it after the next compile. These
    // live in `UserDefaults` under their own prefix, debug builds only, and the
    // shipped defaults are what a fresh install reads.

    private static let prefix = "modeCard."

    /// Bumped whenever a shipped default changes.
    ///
    /// Stored values otherwise win over new defaults for ever: a knob tuned to
    /// the old number reads back as that number, and the value written in the
    /// source is never seen again on any machine that has tuned it once. On a
    /// bump every knob is forgotten, so the shipped values are what comes up.
    private static let vintage = 4

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

    private static func rememberedFlag(_ name: String) -> Bool {
        remembered(name, 0) > 0.5
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
        warp = ModeCardStyle.defaultWarp
        sideOn = false
        thickness = ModeCardStyle.defaultThickness
        core = ModeCardStyle.defaultCore
        stars = ModeCardStyle.defaultStars
        blendIndex = Int(ModeCardTuning.defaultBlendIndex)
    }

    private static let names = [
        "length", "spread", "fadeFrom", "fadeTo", "warp", "sideOn",
        "thickness", "core", "stars", "blendIndex",
    ]

    func dump() {
        print("── mode card ──")
        print(String(format: "  length   %.2f bars", length))
        print(String(format: "  spread   %.2f bars", spread))
        print(String(format: "  fade     %.2f → %.2f of length", fadeFrom, fadeTo))
        print(String(format: "  warp     %.2f  %@", warp, sideOn ? "side-on" : "wormhole"))
        print(String(format: "  tunnel   thick %.1f  eye %.2f  stars %.2f  %@",
                     thickness, core, stars, String(describing: blend)))
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
            row("warp", value: $tuning.warp, in: 0...1, step: 0.01)

            Button(tuning.sideOn ? "tunnel: side-on" : "tunnel: wormhole") {
                tuning.sideOn.toggle()
            }

            row("thick", value: $tuning.thickness, in: 0.5...12, step: 0.1)
            row("eye", value: $tuning.core, in: 0...0.4, step: 0.005)
            row("stars", value: $tuning.stars, in: 0...1, step: 0.01)

            Picker("blend", selection: $tuning.blendIndex) {
                ForEach(Array(BlendMode.pickable.enumerated()), id: \.offset) { index, mode in
                    Text(String(describing: mode)).tag(index)
                }
            }
            .pickerStyle(.menu)
            .tint(Palette.white)
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
