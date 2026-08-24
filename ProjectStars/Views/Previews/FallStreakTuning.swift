//
//  FallStreakTuning.swift
//  Project Stars
//
//  The bench for the death screen's falling streaks.
//

import SwiftUI

#if DEBUG

/// Live knobs for `FallStreaks`.
///
/// Its own bench rather than a corner of the card's: the two fields fill
/// differently shaped holes — a bar the width of the screen against the whole
/// screen — so a number that reads well in one reads wrong in the other. That
/// is the reason `FallStreaks` exists at all, and sharing a bench would have
/// undone it on the first drag of a slider.
@Observable
@MainActor
final class FallStreakTuning {

    static let shared = FallStreakTuning()

    /// How bright the field is. Zero turns it off, which is the quickest way to
    /// see what the streaks are actually contributing.
    var glow: Double = store.value("glow", FallStreakStyle.defaultGlow) {
        didSet { FallStreakTuning.store.set("glow", glow) }
    }

    /// How many are in flight.
    var count: Double = store.value("count", Double(FallStreakStyle.defaultCount)) {
        didSet { FallStreakTuning.store.set("count", count) }
    }

    /// How long the longest is, in screens.
    var length: Double = store.value("length", FallStreakStyle.defaultLength) {
        didSet { FallStreakTuning.store.set("length", length) }
    }

    /// How far the fastest travels each second, in screens.
    var speed: Double = store.value("speed", FallStreakStyle.defaultSpeed) {
        didSet { FallStreakTuning.store.set("speed", speed) }
    }

    /// How wide one is, in points.
    var thickness: Double = store.value("thickness", FallStreakStyle.defaultThickness) {
        didSet { FallStreakTuning.store.set("thickness", thickness) }
    }

    nonisolated static let store = BenchStore(
        prefix: "fallstreak.",
        vintage: 1,
        names: ["glow", "count", "length", "speed", "thickness"]
    )

    func reset() {
        FallStreakTuning.store.forget()
        glow = FallStreakStyle.defaultGlow
        count = Double(FallStreakStyle.defaultCount)
        length = FallStreakStyle.defaultLength
        speed = FallStreakStyle.defaultSpeed
        thickness = FallStreakStyle.defaultThickness
    }

    /// Prints the settled numbers in the shape they would be pasted back into
    /// `FallStreakStyle` — the bench's whole purpose is to end with a number
    /// written down in the source, not a slider left where it was.
    func dump() {
        print("── fall streaks ──")
        print(String(format: "  static let defaultGlow: Double = %.2f", glow))
        print("  static let defaultCount = \(Int(count))")
        print(String(format: "  static let defaultLength: Double = %.2f", length))
        print(String(format: "  static let defaultSpeed: Double = %.2f", speed))
        print(String(format: "  static let defaultThickness: Double = %.1f", thickness))
    }
}

/// The bench for it.
struct FallStreakControls: View {

    @Bindable var tuning = FallStreakTuning.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text("streaks").foregroundStyle(Palette.gold)
                Button("print") { tuning.dump() }
                Button("reset") { tuning.reset() }
            }

            row("glow", $tuning.glow, 0 ... 2, 0.02, "%.2f")
            row("count", $tuning.count, 1 ... 160, 1, "%.0f")
            row("length", $tuning.length, 0.02 ... 1.5, 0.01, "%.2f")
            row("speed", $tuning.speed, 0.05 ... 6, 0.05, "%.2f")
            row("thick", $tuning.thickness, 0.5 ... 12, 0.5, "%.1f")
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
            Text(label).frame(width: 38, alignment: .leading)
            Button("−") {
                value.wrappedValue = max(range.lowerBound, value.wrappedValue - step)
            }
            Slider(value: value, in: range, step: step).frame(width: 110)
            Button("+") {
                value.wrappedValue = min(range.upperBound, value.wrappedValue + step)
            }
            Text(String(format: format, value.wrappedValue))
                .frame(width: 38, alignment: .trailing)
        }
    }
}

#endif
