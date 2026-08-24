//
//  NexysTuning.swift
//  Project Stars
//
//  Placing the foreshortened island.
//

import SwiftUI

#if DEBUG

/// Where the island and its pillar sit, while the drawn-in-perspective version
/// is being tried against the flat one.
///
/// Both sprites are on the sheet and both are reachable — the toggle is the
/// whole point. A drawing decision that has not been made yet should not be a
/// deleted sprite.
@Observable
@MainActor
final class NexysTuning {

    static let shared = NexysTuning()

    /// Whether the board draws the foreshortened island instead of the flat one.
    var foreshortened: Bool = store.flag("foreshortened", NexysStyle.defaultForeshortened) {
        didSet { NexysTuning.store.set("foreshortened", foreshortened) }
    }

    /// Where the island sits, in art pixels from the centre of its square.
    var islandX: Double = store.value("islandX", NexysStyle.defaultIslandX) {
        didSet { NexysTuning.store.set("islandX", islandX) }
    }
    var islandY: Double = store.value("islandY", NexysStyle.defaultIslandY) {
        didSet { NexysTuning.store.set("islandY", islandY) }
    }

    /// And the pillar, measured the same way.
    var pillarX: Double = store.value("pillarX", NexysStyle.defaultPillarX) {
        didSet { NexysTuning.store.set("pillarX", pillarX) }
    }
    var pillarY: Double = store.value("pillarY", NexysStyle.defaultPillarY) {
        didSet { NexysTuning.store.set("pillarY", pillarY) }
    }

    nonisolated static let store = BenchStore(
        prefix: "nexys.",
        vintage: 1,
        names: ["foreshortened", "islandX", "islandY", "pillarX", "pillarY"]
    )

    func reset() {
        NexysTuning.store.forget()
        foreshortened = NexysStyle.defaultForeshortened
        islandX = NexysStyle.defaultIslandX
        islandY = NexysStyle.defaultIslandY
        pillarX = NexysStyle.defaultPillarX
        pillarY = NexysStyle.defaultPillarY
    }

    func dump() {
        print("── nexys ──")
        print("  sprite   " + (foreshortened ? "foreshortened" : "flat"))
        print(String(format: "  island   x %+.0f  y %+.0f", islandX, islandY))
        print(String(format: "  pillar   x %+.0f  y %+.0f", pillarX, pillarY))
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

            row("isl x", value: $tuning.islandX)
            row("isl y", value: $tuning.islandY)
            row("pil x", value: $tuning.pillarX)
            row("pil y", value: $tuning.pillarY)
        }
        .font(.system(size: 9, weight: .semibold, design: .monospaced))
        .foregroundStyle(Palette.stone)
        .padding(6)
        .background(Palette.midnight.opacity(0.9), in: RoundedRectangle(cornerRadius: 8))
    }

    /// Art pixels, whole ones. The island is pixel art and a half-pixel offset
    /// is a blurred edge rather than a smaller move.
    private func row(_ label: String, value: Binding<Double>) -> some View {
        HStack(spacing: 6) {
            Text(label).frame(width: 32, alignment: .leading)
            Button("−") { value.wrappedValue -= 1 }
            Slider(value: value, in: -24...24, step: 1).frame(width: 104)
            Button("+") { value.wrappedValue += 1 }
            Text(String(format: "%+.0f", value.wrappedValue))
                .frame(width: 30, alignment: .trailing)
        }
    }
}

#endif
