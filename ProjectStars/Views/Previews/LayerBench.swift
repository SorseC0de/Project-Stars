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

    /// **The port.** The whole top screen drawn by SpriteKit instead of SwiftUI.
    ///
    /// Not a layer toggle like the rest of these — it swaps the entire board for
    /// `BoardScene`, which draws the sky, both planes' ground and the piece as
    /// nodes that exist rather than a tree that is described. Incomplete on
    /// purpose: no cursor, no arrow, no island, no coins, no effects. It is the
    /// slice that answers whether a retained scene costs less than a rebuilt
    /// one, and everything missing from it is more nodes rather than a different
    /// answer.
    var scene = false

    /// The whole control panel — the entire bottom half of the screen.
    ///
    /// Never once isolated. It is a full SwiftUI tree of its own — meters,
    /// buttons, the swipe surface, the grid — and it rebuilds on every publish
    /// exactly as the board does. Half the screen, outside every measurement in
    /// this hunt.
    var panel = true

    /// **The other experiment.** Astra's clouds drawn by SpriteKit.
    ///
    /// A retained scene against a redrawn canvas — see `CloudScene`. This is the
    /// comparison that matters, and it is not the same question the one-canvas
    /// toggle asks: a `Canvas` is still a full CPU redraw every frame, one
    /// surface or seven. A scene is nodes that exist, drifted by the render
    /// thread, with nothing woken per frame.
    ///
    /// Incomplete on purpose: no wake, no dip, no wear. Enough to measure.
    var spritekit = false

    /// **The experiment.** Astra's ground drawn as ONE canvas instead of seven.
    ///
    /// The seven exist so clouds interleave with the objects standing on them,
    /// so this is visually wrong while it is on — the piece will sort against
    /// the whole field rather than row by row. That is expected and it is not
    /// the point. The point is the number: if `late` improves sharply, the cost
    /// is per-surface and the board wants to be drawn rather than assembled. If
    /// it does not, that theory is dead for the price of one toggle.
    var oneCanvas = false

    /// The wash that comes up while a move resolves — and the zIndex lift it
    /// puts on every object standing on the ground, which is the half of it
    /// that has never been measured.
    var wash = true


    /// The star field in the sky behind Astra.
    var stars = true

    #else

    let scenery = true
    let tileEdges = true
    let ground = true
    let clouds = true
    let sparkles = true
    let fracture = true
    let panel = true
    let scene = false
    let wash = true
    let oneCanvas = false
    let spritekit = false
    let stars = true

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

    @Bindable private var bench = LayerBench.shared

    /// Takes the board apart a layer at a time, with the frame counter running.
    ///
    /// The only honest way to find what a plane costs: turn one thing off, read
    /// the number, turn it back on. Astra and Terra draw almost nothing in
    /// common, so the answer to "why is Astra slower" is in here rather than in
    /// anybody's reading of the code.
    var body: some View {
        BenchPanel("layers") {
            VStack(alignment: .leading, spacing: 2) {
                Text("astra").foregroundStyle(Palette.sky)
                toggle("clouds", \.clouds)
                toggle("ONE canvas", \.oneCanvas)
                toggle("SPRITEKIT", \.spritekit)
                toggle("stars", \.stars)

                Text("terra").foregroundStyle(Palette.gold).padding(.top, 3)
                toggle("scenery", \.scenery)
                toggle("tile edges", \.tileEdges)

                Text("screen").foregroundStyle(Palette.gold).padding(.top, 3)
                toggle("SCENE (spritekit)", \.scene)
                toggle("PANEL", \.panel)

                Text("both").foregroundStyle(Palette.stone).padding(.top, 3)
                toggle("ground", \.ground)
                toggle("sparkles", \.sparkles)
                toggle("fracture", \.fracture)
                toggle("wash", \.wash)
            }
            .font(.system(size: 9, weight: .semibold, design: .monospaced))
            .foregroundStyle(Palette.stone)
        }
    }

    private func toggle(
        _ label: String,
        _ path: ReferenceWritableKeyPath<LayerBench, Bool>
    ) -> some View {
        Button {
            bench[keyPath: path].toggle()
        } label: {
            HStack(spacing: 5) {
                Text(bench[keyPath: path] ? "◉" : "○")
                Text(label)
            }
            .foregroundStyle(bench[keyPath: path] ? Palette.stone : Palette.textSecondary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#endif
