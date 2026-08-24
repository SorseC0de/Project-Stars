//
//  FallTuning.swift
//  Project Stars
//
//  Which picture a landing throws.
//

import SwiftUI

#if DEBUG

/// What the piece does at the moment it comes down on the plane below.
///
/// The fall itself is settled — straight down its own column, gold the whole
/// way, upright at the bottom. What is still a drawing decision is the flash it
/// arrives in, so that is the one thing here.
@Observable
@MainActor
final class FallTuning {

    static let shared = FallTuning()

    var arrival: FallStyle.Arrival = FallStyle.Arrival(
        rawValue: store.words("arrival", FallStyle.defaultArrival.rawValue)
    ) ?? FallStyle.defaultArrival {
        didSet { FallTuning.store.set("arrival", arrival.rawValue) }
    }

    nonisolated static let store = BenchStore(
        prefix: "fall.",
        vintage: 1,
        names: ["arrival"]
    )

    func reset() {
        FallTuning.store.forget()
        arrival = FallStyle.defaultArrival
    }

    func dump() {
        print("── fall ──")
        print("  arrival  " + arrival.rawValue)
    }
}

/// The bench for it.
struct FallControls: View {

    @Bindable var tuning = FallTuning.shared

    /// Drops the piece, since the choice is invisible without one.
    let onFall: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Button("▸ fall") { onFall() }
                Button("print") { tuning.dump() }
                Button("reset") { tuning.reset() }
            }

            Button("arrival: \(tuning.arrival.rawValue)") {
                tuning.arrival = tuning.arrival.next
            }
        }
        .font(.system(size: 9, weight: .semibold, design: .monospaced))
        .foregroundStyle(Palette.stone)
        .padding(6)
        .background(Palette.midnight.opacity(0.9), in: RoundedRectangle(cornerRadius: 8))
    }
}

#endif
