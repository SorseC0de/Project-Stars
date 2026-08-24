//
//  ModeCardTuning.swift
//  Project Stars
//
//  The two questions left about the passive prompt.
//

import SwiftUI

#if DEBUG

/// What is still being looked at on the passive prompt.
///
/// Its size, its place, its word and its streaks are all settled and written
/// down in `PromptStyle`. What is left is how fast it goes, and whether the word
/// goes with it — and a field to type a real passive name into, because length
/// is the thing that decides whether any of it works.
@Observable
@MainActor
final class ModeCardTuning {

    static let shared = ModeCardTuning()

    /// How long the card takes to fade as it slides out.
    var fade: Double = store.value("fade", PromptStyle.defaultFade) {
        didSet { ModeCardTuning.store.set("fade", fade) }
    }

    /// Whether the word leaves with its shape or goes first.
    var wordsRideOut: Bool = store.flag("wordsRideOut", true) {
        didSet { ModeCardTuning.store.set("wordsRideOut", wordsRideOut) }
    }

    /// What the sample button announces.
    var sampleText: String = store.words("sampleText", "Magnetic Mane") {
        didSet { ModeCardTuning.store.set("sampleText", sampleText) }
    }

    nonisolated static let store = BenchStore(
        prefix: "modeCard.",
        vintage: 9,
        names: ["fade", "wordsRideOut", "sampleText"]
    )

    func reset() {
        ModeCardTuning.store.forget()
        fade = PromptStyle.defaultFade
        wordsRideOut = true
        sampleText = "Magnetic Mane"
    }

    func dump() {
        print("── passive prompt ──")
        print(String(format: "  fade     %.2f", fade))
        print("  words    " + (wordsRideOut ? "ride out" : "go first"))
        print("  sample   " + sampleText)
    }
}

/// The bench for it.
struct ModeCardControls: View {

    @Bindable var tuning = ModeCardTuning.shared

    /// Fires a sample announcement, since neither knob here is visible without
    /// one on screen.
    let onTrigger: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Button("▸ sample") { onTrigger() }
                Button("print") { tuning.dump() }
                Button("reset") { tuning.reset() }
            }

            TextField("name", text: $tuning.sampleText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 170)

            row("fade", value: $tuning.fade, in: 0.02...1, step: 0.01)

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
            Text(label).frame(width: 32, alignment: .leading)
            Button("−") { value.wrappedValue = max(range.lowerBound, value.wrappedValue - step) }
            Slider(value: value, in: range, step: step).frame(width: 104)
            Button("+") { value.wrappedValue = min(range.upperBound, value.wrappedValue + step) }
            Text(String(format: "%.2f", value.wrappedValue))
                .frame(width: 34, alignment: .trailing)
        }
    }
}

#endif
