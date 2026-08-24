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

    /// How much higher the cursor sits on the island's square.
    var cursorLift: Double = store.value("cursorLift", NexysStyle.defaultCursorLift) {
        didSet { NexysTuning.store.set("cursorLift", cursorLift) }
    }

    /// What the island does when somebody lands on it, and how it does it.
    var rock: NexysStyle.Rock = NexysStyle.Rock(
        rawValue: NexysTuning.store.words("rock", NexysStyle.defaultRock.rawValue)
    ) ?? NexysStyle.defaultRock {
        didSet { NexysTuning.store.set("rock", rock.rawValue) }
    }

    var rockHold: Double = store.value("rockHold", NexysStyle.defaultRockHold) {
        didSet { NexysTuning.store.set("rockHold", rockHold) }
    }

    /// How long the island's give lasts. Both it and the rock start at the same
    /// instant, so this is the other half of lining the two up.
    var bounceHold: Double = store.value("bounceHold", NexysStyle.defaultBounceHold) {
        didSet { NexysTuning.store.set("bounceHold", bounceHold) }
    }

    /// How much of the give is spent going down, as a share of its life.
    /// Lower drops faster and returns more slowly.
    var bounceAttack: Double = store.value("bounceAttack", NexysStyle.defaultBounceAttack) {
        didSet { NexysTuning.store.set("bounceAttack", bounceAttack) }
    }

    /// How far down the give pushes the island, in art pixels.
    var bounceDepth: Double = store.value("bounceDepth", NexysStyle.defaultBounceDepth) {
        didSet { NexysTuning.store.set("bounceDepth", bounceDepth) }
    }

    var rockSquash: Double = store.value("rockSquash", NexysStyle.defaultRockSquash) {
        didSet { NexysTuning.store.set("rockSquash", rockSquash) }
    }

    nonisolated static let store = BenchStore(
        prefix: "nexys.",
        vintage: 1,
        names: ["foreshortened", "islandX", "islandY", "rock", "rockHold", "rockSquash", "cursorLift", "bounceHold", "bounceDepth", "bounceAttack"]
    )

    func reset() {
        NexysTuning.store.forget()
        foreshortened = NexysStyle.defaultForeshortened
        islandX = NexysStyle.defaultIslandX
        islandY = NexysStyle.defaultIslandY
        cursorLift = NexysStyle.defaultCursorLift
        rock = NexysStyle.defaultRock
        rockHold = NexysStyle.defaultRockHold
        bounceHold = NexysStyle.defaultBounceHold
        bounceDepth = NexysStyle.defaultBounceDepth
        bounceAttack = NexysStyle.defaultBounceAttack
        rockSquash = NexysStyle.defaultRockSquash
    }

    func dump() {
        print("── nexys ──")
        print("  sprite   " + (foreshortened ? "foreshortened" : "flat"))
        print(String(format: "  island   x %+.0f  y %+.0f", islandX, islandY))
        print(String(format: "  cursor   +%.0f", cursorLift))
        print(String(format: "  rock     %@  hold %.2fs  bounce %.2fs  dip %.0fpx (drop %.2f)  squash %.0fpx",
                     rock.rawValue, rockHold, bounceHold, bounceDepth, bounceAttack, rockSquash))
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

            Button("rock: \(tuning.rock.rawValue)") { tuning.rock = tuning.rock.next }

            row("isl x", value: $tuning.islandX)
            row("isl y", value: $tuning.islandY)
            row("cur y", value: $tuning.cursorLift, in: -8...8, step: 1)
            row("hold", value: $tuning.rockHold, in: 0.02...2.5, step: 0.02, places: 2)
            row("bounce", value: $tuning.bounceHold, in: 0.02...2.5, step: 0.02, places: 2)
            row("dip", value: $tuning.bounceDepth, in: 0...24, step: 1)
            row("drop", value: $tuning.bounceAttack, in: 0.05...0.95, step: 0.05, places: 2)
            row("squash", value: $tuning.rockSquash, in: 0...10, step: 0.5, places: 1)
        }
        .font(.system(size: 9, weight: .semibold, design: .monospaced))
        .foregroundStyle(Palette.stone)
        .padding(6)
        .background(Palette.midnight.opacity(0.9), in: RoundedRectangle(cornerRadius: 8))
    }

    /// Art pixels by default, whole ones. The island is pixel art and a
    /// half-pixel offset is a blurred edge rather than a smaller move.
    private func row(
        _ label: String,
        value: Binding<Double>,
        in range: ClosedRange<Double> = -24...24,
        step: Double = 1,
        places: Int = 0
    ) -> some View {
        HStack(spacing: 6) {
            Text(label).frame(width: 32, alignment: .leading)
            Button("−") { value.wrappedValue = max(range.lowerBound, value.wrappedValue - step) }
            Slider(value: value, in: range, step: step).frame(width: 104)
            Button("+") { value.wrappedValue = min(range.upperBound, value.wrappedValue + step) }
            Text(String(format: "%+.\(places)f", value.wrappedValue))
                .frame(width: 34, alignment: .trailing)
        }
    }
}

#endif
