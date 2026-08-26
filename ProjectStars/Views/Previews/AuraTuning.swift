//
//  AuraTuning.swift
//  Project Stars
//
//  Live knobs for the charged piece's halo.
//

import SwiftUI

#if DEBUG

/// The aura is the most expensive thing the game draws.
///
/// Each layer is the whole silhouette taken through a shader and then a
/// Gaussian blur, and a blur is an offscreen pass. Two layers on a charged sign
/// is the difference between sixty frames and thirty-something, which is a
/// trade nobody can judge from the source — so it goes on a bench, beside the
/// frame counter, and gets judged by looking at it.
@Observable
@MainActor
final class AuraTuning {

    static let shared = AuraTuning()

    /// How many blurred copies sit behind the figure. Each one costs a pass.
    var layers: Double = store.value("layers", Double(AuraStyle.defaultLayers)) {
        didSet { AuraTuning.store.set("layers", layers) }
    }

    /// How far the tightest copy spreads, in art pixels.
    var radius: Double = store.value("radius", AuraStyle.defaultRadius) {
        didSet { AuraTuning.store.set("radius", radius) }
    }

    /// How strong the tightest copy is.
    var opacity: Double = store.value("opacity", AuraStyle.defaultOpacity) {
        didSet { AuraTuning.store.set("opacity", opacity) }
    }

    nonisolated static let store = BenchStore(
        prefix: "aura.",
        vintage: 1,
        names: ["layers", "radius", "opacity"]
    )

    func reset() {
        AuraTuning.store.forget()
        layers = Double(AuraStyle.defaultLayers)
        radius = AuraStyle.defaultRadius
        opacity = AuraStyle.defaultOpacity
    }

    func dump() {
        print("── aura ──")
        print("  static let defaultLayers = \(Int(layers))")
        print(String(format: "  static let defaultRadius: Double = %.1f", radius))
        print(String(format: "  static let defaultOpacity: Double = %.2f", opacity))
    }
}

/// The bench for it.
struct AuraControls: View {

    @Bindable var tuning = AuraTuning.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text("aura").foregroundStyle(Palette.gold)
                Button("print") { tuning.dump() }
                Button("reset") { tuning.reset() }
            }
            row("layers", $tuning.layers, 0 ... 3, 1, "%.0f")
            row("radius", $tuning.radius, 0.5 ... 12, 0.5, "%.1f")
            row("opacity", $tuning.opacity, 0 ... 1, 0.05, "%.2f")
        }
        .font(.system(size: 9, weight: .semibold, design: .monospaced))
        .foregroundStyle(Palette.stone)
        .padding(6)
        .background(Palette.midnight.opacity(0.9), in: RoundedRectangle(cornerRadius: 8))
    }

    private func row(
        _ label: String,
        _ value: Binding<Double>,
        _ range: ClosedRange<Double>,
        _ step: Double,
        _ format: String
    ) -> some View {
        HStack(spacing: 6) {
            Text(label).frame(width: 40, alignment: .leading)
            Button("−") { value.wrappedValue = max(range.lowerBound, value.wrappedValue - step) }
            Slider(value: value, in: range, step: step).frame(width: 100)
            Button("+") { value.wrappedValue = min(range.upperBound, value.wrappedValue + step) }
            Text(String(format: format, value.wrappedValue))
                .frame(width: 34, alignment: .trailing)
        }
    }
}

#endif
