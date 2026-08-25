//
//  RenderTally.swift
//  Project Stars
//
//  A count of how often the board's views are being evaluated, for debug builds.
//

import SwiftUI

#if DEBUG

/// How many times each part of the board rebuilt itself in the last second.
///
/// ## Why this exists
///
/// The frame counter says *that* the board is slow. It cannot say **what** is
/// slow, and every attempt to answer that by reading the code has been wrong —
/// the Hydroponic tank survived taking the cover art away, taking the cover
/// objects away, and covering the board with no sweep at all, which between them
/// eliminate everything the code says could be responsible. When the reading
/// disagrees with the measurement that many times, the reading is what is wrong.
///
/// So this counts. A view that is being rebuilt sixty times a second in a
/// turn-based game is the bug, whatever the code around it looks like, and a
/// number on screen settles it in one run instead of another round of guesses.
///
/// ## Why a bare static
///
/// It is written from inside `body`, which is supposed to be free of
/// consequence — so it must not touch anything SwiftUI observes, or the count
/// would invalidate the view it is counting and become its own cause. An
/// unobserved integer changes nothing and tells no one; the readout picks it up
/// on its own clock.
///
/// ## Reading the names
///
/// A clock is named for the file it lives in, numbered `#1`, `#2` … in the order
/// they appear when a file holds more than one. Line numbers were the obvious
/// label and were wrong within the hour — the first edit that added a line to a
/// file sent every label in it somewhere else, and a diagnostic that lies is
/// worse than no diagnostic.
@MainActor
enum RenderTally {

    /// Evaluations since the last drain, by name.
    private static var counts: [String: Int] = [:]

    /// Standing totals that are not evaluations — how many of a thing are alive.
    private static var gauges: [String: Int] = [:]

    /// Records one evaluation of `key`.
    static func tick(_ key: String) {
        counts[key, default: 0] += 1
    }

    /// Records that there are currently `value` of `key` on the board.
    static func gauge(_ key: String, _ value: Int) {
        gauges[key] = value
    }

    /// The last second, busiest first — and starts the next one.
    ///
    /// One entry per line rather than one long line: this is read at a glance
    /// while something else is happening on screen, and a wrapped run-on of
    /// name-number pairs cannot be. Sorted by count so the thing that just
    /// multiplied is always at the top, wherever it came from.
    static func drain() -> [String] {
        let busiest = counts
            .filter { $0.value > 0 }
            .sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
            .map { "\($0.key) \($0.value)" }

        let held = gauges
            .filter { $0.value > 0 }
            .sorted { $0.key < $1.key }
            .map { "\($0.key) \($0.value)" }

        counts.removeAll(keepingCapacity: true)
        return busiest + held
    }

}

// MARK: - The readout

/// The tally, on screen, once a second.
///
/// A single column down the right-hand edge, busiest at the top — so the thing
/// that just multiplied is always the first line your eye lands on, wherever in
/// the codebase it came from. Concatenating them into a paragraph was tried and
/// is unreadable while something is happening on the board, which is the only
/// time this is worth looking at.
///
/// `FPS` is in the list rather than beside it, because it is the same kind of
/// fact: one more clock, counting itself.
struct RenderTallyView: View {

    /// Read once a second for the standing facts — which planes are asleep, and
    /// whether anything still thinks a crossing is in progress.
    ///
    /// A flag that leaks is invisible until something it gates misbehaves hours
    /// later; on the readout it is a `1` that should be a `0`.
    let session: GameSession

    @State private var lines: [String] = []

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // **The frame clock.**
            //
            // Ticks itself into the tally like every other clock, so the fps
            // number is measured the same way as everything it is being
            // compared against. Drawing nothing: it exists to be asked for a
            // frame, not to show one.
            TimelineView(.animation) { _ in
                let _ = RenderTally.tick("FPS")
                Color.clear
            }

            VStack(alignment: .trailing, spacing: 0) {
                ForEach(lines, id: \.self) { line in
                    Text(line)
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Palette.white)
                        .shadow(color: Palette.coolBlack, radius: 0, x: 1, y: 1)
                }
            }
            .padding(.trailing, 4)
            .padding(.top, 2)
        }
        .allowsHitTesting(false)
        // Drained on its own clock rather than inside `body`: writing state
        // from a view's body makes the count its own cause.
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else { return }

                RenderTally.gauge("f.chg", session.isChangingPlane ? 1 : 0)
                RenderTally.gauge("f.rides", session.nexysRidesCamera ? 1 : 0)
                RenderTally.gauge("f.fall", session.isFalling ? 1 : 0)
                for plane in Plane.allCases {
                    RenderTally.gauge(
                        "awake.\(plane.rawValue)",
                        session.planeIsAsleep(plane) ? 0 : 1
                    )
                }

                lines = RenderTally.drain()
            }
        }
    }
}

#endif
