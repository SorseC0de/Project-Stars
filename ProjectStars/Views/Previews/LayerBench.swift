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

/// The switchboard itself, mounted over the panel in debug builds.
struct LayerBenchControls: View {

    @Bindable var bench = LayerBench.shared

    /// The session, for the actions that change the board rather than the view.
    let session: GameSession

    @State private var isOpen = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                isOpen.toggle()
            } label: {
                Text(isOpen ? "layers ▾" : "layers ▸")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(Palette.textPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Palette.background.opacity(0.85))
            }
            .buttonStyle(.plain)

            if isOpen {
                VStack(alignment: .leading, spacing: 2) {
                    toggle("scenery", $bench.scenery)
                    toggle("tile edges", $bench.tileEdges)
                    toggle("ground", $bench.ground)
                    toggle("clouds", $bench.clouds)
                    toggle("sparkles", $bench.sparkles)
                    toggle("fracture", $bench.fracture)
                    Divider().frame(width: 90)

                    // The card's two shape knobs, and the button that puts it
                    // back on screen to look at them.
                    ModeCardControls { session.modeCard = session.mode }
                }
                .padding(8)
                .background(Palette.background.opacity(0.85))
            }
        }
    }

    private func toggle(_ name: String, _ value: Binding<Bool>) -> some View {
        Button {
            value.wrappedValue.toggle()
        } label: {
            HStack(spacing: 6) {
                Text(value.wrappedValue ? "◉" : "○")
                Text(name)
            }
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundStyle(value.wrappedValue ? Palette.lime : Palette.textSecondary)
        }
        .buttonStyle(.plain)
    }
}

#endif
