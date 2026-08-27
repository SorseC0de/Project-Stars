//
//  PentacleTuning.swift
//  Project Stars
//
//  Homing the coin and the mark it leaves, independently.
//

import SwiftUI

#if DEBUG

/// Where the coin sits over its tile, and where its mark sits on it.
///
/// **The two are separate knobs on purpose.** The coin hovers and the mark
/// lies on the ground; they are not one object at two heights, and tuning them
/// together only ever gets one of them right.
@Observable
@MainActor
final class PentacleTuning {

    static let shared = PentacleTuning()

    /// Art pixels **down** from the tile's own seat. Negative lifts it.
    ///
    /// Down rather than up so that it reads the same way as the mark's, which
    /// spares having to hold two opposite senses in mind while tuning.
    var coinY: CGFloat = store.value("coinY", -GameRules.pentacleLift) {
        didSet { PentacleTuning.store.set("coinY", coinY) }
    }

    /// Art pixels down for the mark, measured the same way.
    var markY: CGFloat = store.value("markY", GameRules.pentacleShadowDrop) {
        didSet { PentacleTuning.store.set("markY", markY) }
    }

    /// How far the coin circles, in art pixels. Steps in halves, which is the
    /// one place a fraction is wanted — the orbit is a path rather than a
    /// placement, so it is resampled anyway.
    var orbit: CGFloat = store.value("orbit", GameRules.pentacleOrbitRadius) {
        didSet { PentacleTuning.store.set("orbit", orbit) }
    }

    nonisolated static let store = BenchStore(
        prefix: "pentacle.",
        vintage: 1,
        names: ["coinY", "markY", "orbit"]
    )

    func reset() {
        PentacleTuning.store.forget()
        coinY = -GameRules.pentacleLift
        markY = GameRules.pentacleShadowDrop
        orbit = GameRules.pentacleOrbitRadius
    }

    func dump() {
        print("── pentacle ──")
        print(String(format: "  coin Y   %+.0f px (down)", coinY))
        print(String(format: "  mark Y   %+.0f px (down)", markY))
        print(String(format: "  orbit    %.1f px", orbit))
        print("  → pentacleLift \(-coinY), pentacleShadowDrop \(markY),"
            + " pentacleOrbitRadius \(orbit)")
    }
}

struct PentacleControls: View {

    @Bindable var tuning = PentacleTuning.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Button("print") { tuning.dump() }
                Button("reset") { tuning.reset() }
            }

            row("coin Y", value: $tuning.coinY, in: -24...24, step: 1)
            row("mark Y", value: $tuning.markY, in: -24...24, step: 1)
            row("orbit", value: $tuning.orbit, in: 0...12, step: 0.5)
        }
        .font(.system(size: 10, weight: .semibold, design: .monospaced))
        .foregroundStyle(Palette.stone)
    }

    private func row(
        _ label: String,
        value: Binding<CGFloat>,
        in range: ClosedRange<CGFloat>,
        step: CGFloat
    ) -> some View {
        HStack(spacing: 6) {
            Text(label).frame(width: 44, alignment: .leading)
            Button("−") { value.wrappedValue -= step }
            Slider(value: value, in: range, step: step).frame(width: 150)
            Button("+") { value.wrappedValue += step }
            Text(step < 1
                 ? String(format: "%.1f", value.wrappedValue)
                 : String(format: "%.0f", value.wrappedValue))
                .frame(width: 32, alignment: .trailing)
        }
        .buttonStyle(.plain)
    }
}

#endif
