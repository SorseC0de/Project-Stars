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

    /// The light behind the glass, and how soft its bands are.
    var paneStrength: Double = store.value("paneStrength", StartStyle.defaultPaneStrength) {
        didSet { StartButtonTuning.store.set("paneStrength", paneStrength) }
    }
    var paneSoftness: Double = store.value("paneSoftness", StartStyle.defaultPaneSoftness) {
        didSet { StartButtonTuning.store.set("paneSoftness", paneSoftness) }
    }

    /// How tall the button's side is, against the panel's usual, and how solid.
    var depthScale: Double = store.value("depthScale", StartStyle.defaultDepthScale) {
        didSet { StartButtonTuning.store.set("depthScale", depthScale) }
    }
    var rimOpacity: Double = store.value("rimOpacity", StartStyle.defaultRimOpacity) {
        didSet { StartButtonTuning.store.set("rimOpacity", rimOpacity) }
    }

    /// The lit edge drawn round the face: how wide, how bright, and where its
    /// gradient runs out to.
    var strokeWidth: Double = store.value("strokeWidth", StartStyle.defaultStrokeWidth) {
        didSet { StartButtonTuning.store.set("strokeWidth", strokeWidth) }
    }
    var strokeOpacity: Double = store.value("strokeOpacity", StartStyle.defaultStrokeOpacity) {
        didSet { StartButtonTuning.store.set("strokeOpacity", strokeOpacity) }
    }
    var strokeToCorner: Bool = store.flag("strokeToCorner", false) {
        didSet { StartButtonTuning.store.set("strokeToCorner", strokeToCorner) }
    }

    /// The plane of light across the top of the face.
    var shine: Double = store.value("shine", StartStyle.defaultShine) {
        didSet { StartButtonTuning.store.set("shine", shine) }
    }

    /// How far the halo reaches, and how round it is.
    var glowSpread: Double = store.value("glowSpread", StartStyle.defaultGlowSpread) {
        didSet { StartButtonTuning.store.set("glowSpread", glowSpread) }
    }
    var glowCorner: Double = store.value("glowCorner", StartStyle.defaultGlowCorner) {
        didSet { StartButtonTuning.store.set("glowCorner", glowCorner) }
    }

    nonisolated static let store = BenchStore(
        prefix: "start.",
        vintage: 1,
        names: [
            "paneStrength", "paneSoftness", "depthScale", "rimOpacity",
            "strokeWidth", "strokeOpacity", "strokeToCorner", "shine",
            "glowSpread", "glowCorner",
        ]
    )

    func reset() {
        StartButtonTuning.store.forget()
        paneStrength = StartStyle.defaultPaneStrength
        paneSoftness = StartStyle.defaultPaneSoftness
        depthScale = StartStyle.defaultDepthScale
        rimOpacity = StartStyle.defaultRimOpacity
        strokeWidth = StartStyle.defaultStrokeWidth
        strokeOpacity = StartStyle.defaultStrokeOpacity
        strokeToCorner = false
        shine = StartStyle.defaultShine
        glowSpread = StartStyle.defaultGlowSpread
        glowCorner = StartStyle.defaultGlowCorner
    }

    func dump() {
        print("── start button ──")
        print(String(format: "  pane     strength %.2f  soft %.1f", paneStrength, paneSoftness))
        print(String(format: "  side     %.2fx  opacity %.2f", depthScale, rimOpacity))
        print(String(format: "  stroke   %.1fpt  white %.2f  to %@",
                     strokeWidth, strokeOpacity, strokeToCorner ? "bottomTrailing" : "bottom"))
        print(String(format: "  shine    %.2f", shine))
        print(String(format: "  glow     spread %.1f  corner %.1f", glowSpread, glowCorner))
    }
}

/// The bench for it.
struct StartButtonControls: View {

    @Bindable var tuning = StartButtonTuning.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Button("print") { tuning.dump() }
                Button("reset") { tuning.reset() }
            }

            row("pane", value: $tuning.paneStrength, in: 0...1, step: 0.01)
            row("soft", value: $tuning.paneSoftness, in: 0...40, step: 0.5)
            row("side", value: $tuning.depthScale, in: 1...3, step: 0.25)
            row("side α", value: $tuning.rimOpacity, in: 0...1, step: 0.01)
            row("edge", value: $tuning.strokeWidth, in: 1...10, step: 0.5)
            row("edge α", value: $tuning.strokeOpacity, in: 0...1, step: 0.01)
            row("shine", value: $tuning.shine, in: 0...1, step: 0.01)
            row("glow", value: $tuning.glowSpread, in: 0...40, step: 0.5)
            row("round", value: $tuning.glowCorner, in: 0...60, step: 1)

            Button(tuning.strokeToCorner ? "edge → corner" : "edge → bottom") {
                tuning.strokeToCorner.toggle()
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
