//
//  TileEdgeTuning.swift
//  Project Stars
//
//  Homing the popped tile and the edge it uncovers.
//

import SwiftUI

#if DEBUG

/// How far a tile pops, and where the edge under it sits.
///
/// **Every one of these is in art pixels at row scale, not in points.** They
/// are applied inside the band's own frame — sideways against `band.scale`,
/// vertically against `band.groundScale` — so a value found on one row is the
/// same value on all of them. That is the point of tuning here rather than
/// nudging the finished positions: the rows are not the same size, and a
/// number that fixes the front row by eye would be wrong everywhere else.
@Observable
@MainActor
final class TileEdgeTuning {

    static let shared = TileEdgeTuning()

    /// How far a popped tile rises. Also decides how much edge is uncovered.
    var popY: CGFloat = max(store.value("popY", GameRules.tilePopLift), 0) {
        didSet {
            let safe = max(popY, 0)
            if safe != popY { popY = safe; return }
            TileEdgeTuning.store.set("popY", popY)
        }
    }

    /// Sideways nudge for the popped **face**, in art pixels.
    ///
    /// Separate from `edgeX` because the face and the edge under it are drawn
    /// by different means — the face is a tile of the board, the edge is the
    /// side of one — and the whole question is whether they agree.
    var popX: CGFloat = store.value("popX", 0) {
        didSet { TileEdgeTuning.store.set("popX", popX) }
    }

    /// Sideways nudge for the edge.
    var edgeX: CGFloat = store.value("edgeX", 0) {
        didSet { TileEdgeTuning.store.set("edgeX", edgeX) }
    }

    /// Sideways nudge **per column away from the middle**, in art pixels.
    ///
    /// Positive pulls the outer columns toward the centre. A single number
    /// here is a horizontal scale on the edges as a whole, so whatever value
    /// reads right is a measurement of how much the edge row is drawn wider
    /// than the tiles above it — which is a thing with a formula, once its
    /// size is known.
    ///
    /// Steps in twentieths, because the difference being looked for is under
    /// a pixel a column.
    var edgeXper: CGFloat = store.value("edgeXper", 0) {
        didSet { TileEdgeTuning.store.set("edgeXper", edgeXper) }
    }

    /// A multiplier on how far the edge sits from the board's middle.
    ///
    /// **The one to reach for first.** The front lip is right, and it is placed
    /// by the same expression as every other edge — so if a single number here
    /// squares the rest of them up, the edges and the tiles above them differ
    /// by a constant ratio, and a ratio has a closed form. If instead it needs
    /// a different value per row, they do not, and `edgeX/col` is the way to
    /// measure what they do differ by.
    ///
    /// Steps in two-hundredths: a column out at the board's edge is roughly
    /// forty pixels from the middle, so this is a tenth of a pixel there.
    var edgeXmul: CGFloat = store.value("edgeXmul", 1) {
        didSet { TileEdgeTuning.store.set("edgeXmul", edgeXmul) }
    }

    /// Vertical nudge for the edge. Positive is down.
    var edgeY: CGFloat = store.value("edgeY", 0) {
        didSet { TileEdgeTuning.store.set("edgeY", edgeY) }
    }

    /// Widens or narrows the edge against the tile it belongs to.
    var edgeXscale: CGFloat = max(store.value("edgeXscale", 1), 0) {
        didSet {
            let safe = max(edgeXscale, 0)
            if safe != edgeXscale { edgeXscale = safe; return }
            TileEdgeTuning.store.set("edgeXscale", edgeXscale)
        }
    }

    /// Stretches the uncovered strip of the drawing, against what the pop
    /// uncovered.
    ///
    /// **The slice is `popY`'s to decide; this only scales it.** Letting the
    /// scale take a bigger slice as well grew the top while the bottom stayed
    /// on the floor, which reads as a nudge rather than a scale — and `edgeY`
    /// is already the nudge.
    var edgeYscale: CGFloat = max(store.value("edgeYscale", 1), 0) {
        didSet {
            // **Clamped in the setter, not just in the slider.** A negative
            // scale is a negative height, which is a crash rather than a small
            // sprite — and because the bench persists, one stray tap of the
            // minus button would keep crashing on every launch afterwards.
            let safe = max(edgeYscale, 0)
            if safe != edgeYscale { edgeYscale = safe; return }
            TileEdgeTuning.store.set("edgeYscale", edgeYscale)
        }
    }

    /// Walks the camera sideways, in art pixels, so the board's corners can be
    /// looked at. They sit outside the viewport, which is the one thing that
    /// cannot be checked by eye without moving something.
    ///
    /// Not part of the board's layout — it moves the view, not the board, so
    /// nothing measured while it is off centre is measured wrongly.
    var boardX: CGFloat = store.value("boardX", 0) {
        didSet { TileEdgeTuning.store.set("boardX", boardX) }
    }

    /// Whether the mirrored copy in a stacked edge is turned over as well as
    /// flipped.
    ///
    /// Two identical strips stacked read as one drawing repeated. Mirroring
    /// hides that; mirroring *and* turning over hides it further, at the cost
    /// of putting the drawing's lit edge at the bottom. Which reads better is
    /// a matter for the eye, so it is a toggle rather than a decision.
    var stackTurns: Bool = store.flag("stackTurns", false) {
        didSet { TileEdgeTuning.store.set("stackTurns", stackTurns) }
    }

    /// Forces 3,3 to stand proud, so a popped tile can be looked at without
    /// waiting for the board to produce one.
    var raiseCentre: Bool = store.flag("raiseCentre", false) {
        didSet { TileEdgeTuning.store.set("raiseCentre", raiseCentre) }
    }

    nonisolated static let store = BenchStore(
        prefix: "tileEdge.",
        vintage: 3,
        names: ["popY", "popX", "edgeX", "edgeXper", "edgeXmul", "edgeY", "edgeXscale",
                "edgeYscale", "boardX", "raiseCentre", "stackTurns"]
    )

    func reset() {
        TileEdgeTuning.store.forget()
        popY = GameRules.tilePopLift
        popX = 0
        edgeX = 0
        edgeXper = 0
        edgeXmul = 1
        edgeY = 0
        edgeXscale = 1
        edgeYscale = 1
        boardX = 0
        raiseCentre = false
        stackTurns = false
    }

    func dump() {
        print("── tile edge ──")
        print(String(format: "  popY        %.2f px", popY))
        print(String(format: "  popX        %+.2f px", popX))
        print(String(format: "  edgeX       %+.2f px", edgeX))
        print(String(format: "  edgeXper    %+.2f px per column", edgeXper))
        print(String(format: "  edgeXmul    %.3f", edgeXmul))
        print(String(format: "  edgeY       %+.2f px (down)", edgeY))
        print(String(format: "  edgeXscale  %.2f", edgeXscale))
        print(String(format: "  edgeYscale  %.2f", edgeYscale))
        print(String(format: "  boardX      %+.2f px (view only)", boardX))
        print("  → tilePopLift \(popY)")
    }
}

struct TileEdgeControls: View {

    @Bindable var tuning = TileEdgeTuning.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Button("print") { tuning.dump() }
                Button("reset") { tuning.reset() }
                Toggle("raise 3,3", isOn: $tuning.raiseCentre)
                    .toggleStyle(.button)
                Toggle("flip H+V", isOn: $tuning.stackTurns)
                    .toggleStyle(.button)
            }

            row("popY", value: $tuning.popY, in: 0...24)
            row("popX", value: $tuning.popX, in: -12...12, step: 0.05)
            row("edgeX", value: $tuning.edgeX, in: -12...12)
            row("edgeX/col", value: $tuning.edgeXper, in: -3...3, step: 0.05)
            row("edgeXmul", value: $tuning.edgeXmul, in: 0.9...1.1, step: 0.005)
            row("edgeY", value: $tuning.edgeY, in: -12...12)
            row("edgeXs", value: $tuning.edgeXscale, in: 0...3)
            row("edgeYs", value: $tuning.edgeYscale, in: 0...4)
            row("boardX", value: $tuning.boardX, in: -160...160)
        }
        .font(.system(size: 10, weight: .semibold, design: .monospaced))
        .foregroundStyle(Palette.stone)
    }

    private func row(
        _ label: String,
        value: Binding<CGFloat>,
        in range: ClosedRange<CGFloat>,
        step: CGFloat = 0.25
    ) -> some View {
        HStack(spacing: 6) {
            Text(label).frame(width: 58, alignment: .leading)
            Button("−") { value.wrappedValue -= step }
            Slider(value: value, in: range, step: step).frame(width: 140)
            Button("+") { value.wrappedValue += step }
            Text(String(format: "%.2f", value.wrappedValue))
                .frame(width: 40, alignment: .trailing)
        }
        .buttonStyle(.plain)
    }
}

#endif
