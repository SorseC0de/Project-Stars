//
//  LayerBench.swift
//  Project Stars
//
//  A switchboard for finding what is costing the frame rate.
//

import SwiftUI

/// Which of the board's layers are drawn, so one can be taken away and the
/// frame counter asked what changed.
///
/// ## Why this exists rather than a set of experiments in the source
///
/// Turning a layer off, rebuilding, relaunching and reading the counter takes
/// minutes per question, and the answer is only worth having if the machine
/// underneath is steady. It is not: the same build measured on the simulator
/// gave 120 and 60 on two runs with nothing changed in between, which is enough
/// drift to make every single-sample A/B meaningless — a layer removed can
/// read *slower* than the same board with it.
///
/// A switch that flips at runtime removes the rebuild, the relaunch and the
/// drift all at once: the same board, the same second, one layer at a time.
/// Flip one, watch the counter, flip it back.
@Observable
final class LayerBench {

    static let shared = LayerBench()

    private init() {}

    // **Switches in a debug build, constants in a shipped one.**
    //
    // The gates around the board read these either way, so they have to exist
    // in both — but nothing should be able to turn a layer of the game off in
    // somebody's hands. As `let`s the optimiser folds every branch away and the
    // shipped board is the board with everything in it.
    #if DEBUG

    /// The land behind and in front of Terra — ridges, flanking rocks, the
    /// near rock, and the fill under the board. Terra only.
    var scenery = true

    /// The side of every tile, drawn under the bands. Terra only, 49 of them
    /// plus the front row's, each placed on its own.
    var tileEdges = true

    /// The ground itself, a row at a time. Turning this off drops the piece,
    /// so read the counter before it lands.
    var ground = true

    /// Astra's cloud field: 49 clusters in one `Canvas`.
    var clouds = true

    /// The glow phase's shimmer, one per candidate square.
    var sparkles = true

    /// The screen-wide fracture shader wrapped around the whole board.
    var fracture = true

    #else

    let scenery = true
    let tileEdges = true
    let ground = true
    let clouds = true
    let sparkles = true
    let fracture = true

    #endif
}

#if DEBUG

/// The switchboard's mount, with nothing on it.
///
/// **Parked, not deleted.** Every knob it carried has been settled and written
/// down — the layer toggles, the mode card, the Start button, the passive
/// prompt. What is worth keeping is the mount: somewhere already wired to the
/// session and already in the right corner, so the next thing that needs
/// looking at is a `VStack` away rather than a re-plumbing.
struct LayerBenchControls: View {

    let session: GameSession

    @State private var isOpen = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Folded away by default. A bench is for the thing being tuned right
            // now, and one left open covers the board it is tuning against.
            Button {
                isOpen.toggle()
            } label: {
                Text(isOpen ? "nexys ▾" : "nexys ▸")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(Palette.textPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Palette.background.opacity(0.85))
            }
            .buttonStyle(.plain)

            // The island is settled — its numbers are written down in
            // `NexysStyle` and its bench is parked in `NexysTuning`, intact for
            // whenever it is next opened up. What is being looked at now is the
            // underground's streaks.
            if isOpen { FallStreakControls() }
        }
    }
}

#endif
