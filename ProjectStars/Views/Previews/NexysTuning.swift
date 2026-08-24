//
//  NexysTuning.swift
//  Project Stars
//
//  The two questions left about the island.
//

import SwiftUI

#if DEBUG

/// What is still being looked at on the Nexys.
///
/// Its placement and the whole shape of its settling are decided and written
/// down in `NexysStyle`. What is left is which drawing it uses, and how fast the
/// settling runs — one number for the second, because the parts of that only
/// mean anything in proportion to each other.
@Observable
@MainActor
final class NexysTuning {

    static let shared = NexysTuning()

    /// Whether the board draws the foreshortened island instead of the flat one.
    ///
    /// Both are on the sheet and both are reachable. Which one the board wants
    /// is a drawing decision, and a decision that has not been made should not
    /// be a deleted sprite.
    var foreshortened: Bool = store.flag("foreshortened", NexysStyle.defaultForeshortened) {
        didSet { NexysTuning.store.set("foreshortened", foreshortened) }
    }

    /// How fast the settling runs. Above one is quicker, below one is slower,
    /// and nothing about the shape changes either way.
    var speed: Double = store.value("speed", NexysStyle.defaultSpeed) {
        didSet { NexysTuning.store.set("speed", speed) }
    }

    nonisolated static let store = BenchStore(
        prefix: "nexys.",
        vintage: 2,
        names: ["foreshortened", "speed"]
    )

    func reset() {
        NexysTuning.store.forget()
        foreshortened = NexysStyle.defaultForeshortened
        speed = NexysStyle.defaultSpeed
    }

    func dump() {
        print("── nexys ──")
        print("  sprite   " + (foreshortened ? "foreshortened" : "flat"))
        print(String(format: "  speed    %.2fx", speed))
        print(String(format: "  → hold %.3fs  bounce %.3fs",
                     NexysStyle.rockHold, NexysStyle.bounceHold))
    }
}

/// The bench for it.
struct NexysControls: View {

    @Bindable var tuning = NexysTuning.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Button(tuning.foreshortened ? "island: deep" : "island: flat") {
                    tuning.foreshortened.toggle()
                }
                Button("print") { tuning.dump() }
                Button("reset") { tuning.reset() }
            }

            row("speed", value: $tuning.speed)
        }
        .font(.system(size: 9, weight: .semibold, design: .monospaced))
        .foregroundStyle(Palette.stone)
        .padding(6)
        .background(Palette.midnight.opacity(0.9), in: RoundedRectangle(cornerRadius: 8))
    }

    private func row(_ label: String, value: Binding<Double>) -> some View {
        HStack(spacing: 6) {
            Text(label).frame(width: 34, alignment: .leading)
            Button("−") { value.wrappedValue = max(0.2, value.wrappedValue - 0.05) }
            Slider(value: value, in: 0.2...2.5, step: 0.05).frame(width: 110)
            Button("+") { value.wrappedValue = min(2.5, value.wrappedValue + 0.05) }
            Text(String(format: "%.2fx", value.wrappedValue))
                .frame(width: 38, alignment: .trailing)
        }
    }
}

#endif
