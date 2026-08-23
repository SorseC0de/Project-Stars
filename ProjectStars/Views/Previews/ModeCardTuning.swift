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

    /// Extra length on each bar, in bar-thicknesses, added outward only.
    var spread: CGFloat = ModeCardStyle.defaultSpread

    /// Where the fade finishes, as a share of a bar's length in from its outer
    /// end.
    var fade: CGFloat = ModeCardStyle.defaultFade

    func dump() {
        print("── mode card ──")
        print(String(format: "  spread %.2f bars", spread))
        print(String(format: "  fade   %.2f of length", fade))
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

            row("spread", value: $tuning.spread, in: 0...6, step: 0.1)
            row("fade", value: $tuning.fade, in: 0...0.9, step: 0.01)
        }
        .font(.system(size: 10, weight: .semibold, design: .monospaced))
        .foregroundStyle(Palette.stone)
        .padding(8)
        .background(Palette.midnight.opacity(0.9), in: RoundedRectangle(cornerRadius: 8))
    }

    private func row(
        _ label: String,
        value: Binding<CGFloat>,
        in range: ClosedRange<CGFloat>,
        step: CGFloat
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
