//
//  StartButtonTuning.swift
//  Project Stars
//
//  Dialling in the way in.
//

import SwiftUI

#if DEBUG

/// Everything about the Start button that can only be judged by looking at it.
@Observable
@MainActor
final class StartButtonTuning {

    static let shared = StartButtonTuning()

    /// How wide the lit edge is, and how bright the whole of it is.
    var strokeWidth: Double = store.value("strokeWidth", StartStyle.defaultStrokeWidth) {
        didSet { StartButtonTuning.store.set("strokeWidth", strokeWidth) }
    }
    var strokeOpacity: Double = store.value("strokeOpacity", StartStyle.defaultStrokeOpacity) {
        didSet { StartButtonTuning.store.set("strokeOpacity", strokeOpacity) }
    }

    /// Where the two inner stops sit. The outer two are the ends, and have
    /// nowhere else to be.
    var stopTwoAt: Double = store.value("stopTwoAt", StartStyle.defaultStopTwoAt) {
        didSet { StartButtonTuning.store.set("stopTwoAt", stopTwoAt) }
    }
    var stopThreeAt: Double = store.value("stopThreeAt", StartStyle.defaultStopThreeAt) {
        didSet { StartButtonTuning.store.set("stopThreeAt", stopThreeAt) }
    }

    /// How bright each stop is, as a share of the whole edge's brightness.
    var stopOneGlow: Double = store.value("stopOneGlow", StartStyle.defaultStopOneGlow) {
        didSet { StartButtonTuning.store.set("stopOneGlow", stopOneGlow) }
    }
    var stopTwoGlow: Double = store.value("stopTwoGlow", StartStyle.defaultStopTwoGlow) {
        didSet { StartButtonTuning.store.set("stopTwoGlow", stopTwoGlow) }
    }
    var stopThreeGlow: Double = store.value("stopThreeGlow", StartStyle.defaultStopThreeGlow) {
        didSet { StartButtonTuning.store.set("stopThreeGlow", stopThreeGlow) }
    }
    var stopFourGlow: Double = store.value("stopFourGlow", StartStyle.defaultStopFourGlow) {
        didSet { StartButtonTuning.store.set("stopFourGlow", stopFourGlow) }
    }

    /// Where the light comes from, and where it runs out to.
    var strokeFromCorner: Bool = store.flag("strokeFromCorner", true) {
        didSet { StartButtonTuning.store.set("strokeFromCorner", strokeFromCorner) }
    }
    var strokeToCorner: Bool = store.flag("strokeToCorner", false) {
        didSet { StartButtonTuning.store.set("strokeToCorner", strokeToCorner) }
    }

    nonisolated static let store = BenchStore(
        prefix: "start.",
        vintage: 2,
        names: [
            "strokeWidth", "strokeOpacity", "stopTwoAt", "stopThreeAt",
            "stopOneGlow", "stopTwoGlow", "stopThreeGlow", "stopFourGlow",
            "strokeFromCorner", "strokeToCorner",
        ]
    )

    func reset() {
        StartButtonTuning.store.forget()
        strokeWidth = StartStyle.defaultStrokeWidth
        strokeOpacity = StartStyle.defaultStrokeOpacity
        stopTwoAt = StartStyle.defaultStopTwoAt
        stopThreeAt = StartStyle.defaultStopThreeAt
        stopOneGlow = StartStyle.defaultStopOneGlow
        stopTwoGlow = StartStyle.defaultStopTwoGlow
        stopThreeGlow = StartStyle.defaultStopThreeGlow
        stopFourGlow = StartStyle.defaultStopFourGlow
        strokeFromCorner = true
        strokeToCorner = false
    }

    func dump() {
        print("── start button edge ──")
        print(String(format: "  width    %.1fpt   overall %.2f", strokeWidth, strokeOpacity))
        print(String(format: "  stops    0/%.2f  %.2f/%.2f  %.2f/%.2f  1/%.2f",
                     stopOneGlow, stopTwoAt, stopTwoGlow,
                     stopThreeAt, stopThreeGlow, stopFourGlow))
        print("  runs     " + (strokeFromCorner ? "topLeading" : "top")
              + " → " + (strokeToCorner ? "bottomTrailing" : "bottom"))
    }
}

/// The bench for it.
struct StartButtonControls: View {

    @Bindable var tuning = StartButtonTuning.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Button("print") { tuning.dump() }
                Button("reset") { tuning.reset() }

                Button(tuning.strokeFromCorner ? "from ◤" : "from ▲") {
                    tuning.strokeFromCorner.toggle()
                }
                Button(tuning.strokeToCorner ? "to ◢" : "to ▼") {
                    tuning.strokeToCorner.toggle()
                }
            }

            row("width", value: $tuning.strokeWidth, in: 1...10, step: 0.5)
            row("all α", value: $tuning.strokeOpacity, in: 0...1, step: 0.01)
            row("① α", value: $tuning.stopOneGlow, in: 0...1, step: 0.01)
            row("② at", value: $tuning.stopTwoAt, in: 0...1, step: 0.01)
            row("② α", value: $tuning.stopTwoGlow, in: 0...1, step: 0.01)
            row("③ at", value: $tuning.stopThreeAt, in: 0...1, step: 0.01)
            row("③ α", value: $tuning.stopThreeGlow, in: 0...1, step: 0.01)
            row("④ α", value: $tuning.stopFourGlow, in: 0...1, step: 0.01)
        }
        .font(.system(size: 9, weight: .semibold, design: .monospaced))
        .foregroundStyle(Palette.stone)
        .padding(6)
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
