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
    var popY: CGFloat = store.value("popY", GameRules.tilePopLift) {
        didSet { TileEdgeTuning.store.set("popY", popY) }
    }

    /// Sideways nudge for the edge.
    var edgeX: CGFloat = store.value("edgeX", 0) {
        didSet { TileEdgeTuning.store.set("edgeX", edgeX) }
    }

    /// Vertical nudge for the edge. Positive is down.
    var edgeY: CGFloat = store.value("edgeY", 0) {
        didSet { TileEdgeTuning.store.set("edgeY", edgeY) }
    }

    /// Widens or narrows the edge against the tile it belongs to.
    var edgeXscale: CGFloat = store.value("edgeXscale", 1) {
        didSet { TileEdgeTuning.store.set("edgeXscale", edgeXscale) }
    }

    /// Stretches the uncovered strip of the drawing, against what the pop
    /// uncovered.
    ///
    /// **The slice is `popY`'s to decide; this only scales it.** Letting the
    /// scale take a bigger slice as well grew the top while the bottom stayed
    /// on the floor, which reads as a nudge rather than a scale — and `edgeY`
    /// is already the nudge.
    var edgeYscale: CGFloat = store.value("edgeYscale", 1) {
        didSet { TileEdgeTuning.store.set("edgeYscale", edgeYscale) }
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

    nonisolated static let store = BenchStore(
        prefix: "tileEdge.",
        vintage: 2,
        names: ["popY", "edgeX", "edgeY", "edgeXscale", "edgeYscale", "boardX"]
    )

    func reset() {
        TileEdgeTuning.store.forget()
        popY = GameRules.tilePopLift
        edgeX = 0
        edgeY = 0
        edgeXscale = 1
        edgeYscale = 1
        boardX = 0
    }

    func dump() {
        print("── tile edge ──")
        print(String(format: "  popY        %.2f px", popY))
        print(String(format: "  edgeX       %+.2f px", edgeX))
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
            }

            row("popY", value: $tuning.popY, in: 0...24)
            row("edgeX", value: $tuning.edgeX, in: -12...12)
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
        in range: ClosedRange<CGFloat>
    ) -> some View {
        HStack(spacing: 6) {
            Text(label).frame(width: 48, alignment: .leading)
            Button("−") { value.wrappedValue -= 0.25 }
            Slider(value: value, in: range, step: 0.25).frame(width: 150)
            Button("+") { value.wrappedValue += 0.25 }
            Text(String(format: "%.2f", value.wrappedValue))
                .frame(width: 40, alignment: .trailing)
        }
        .buttonStyle(.plain)
    }
}

#endif
