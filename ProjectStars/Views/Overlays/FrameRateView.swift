//
//  FrameRateView.swift
//  Project Stars
//
//  A frame counter, for debug builds only.
//

import SwiftUI

#if DEBUG

/// Frames per second, drawn in the corner of the screen.
///
/// ## Why it counts its own ticks rather than asking the system
///
/// `CADisplayLink` reports what the display is doing, which is not the question.
/// The question is whether *this view tree* is keeping up — a board full of
/// `TimelineView(.animation)` canvases can fall behind while the display runs at
/// its full rate perfectly happily. So the counter rides the same clock every
/// effect in this game rides, and measures the interval between the ticks it
/// actually receives.
///
/// ## Why the sample is a class
///
/// SwiftUI evaluates a body as often as it likes and expects that to be free of
/// consequence. A rolling window has to survive between evaluations without
/// invalidating anything, which `@State` on a value type cannot do — writing to
/// it during a body is exactly the mutation SwiftUI warns about. A reference
/// held in `@State` is written through instead: the box changes, the binding
/// does not, and nothing is invalidated. The redraw comes from the
/// `TimelineView` itself, which is already ticking every frame.
struct FrameRateView: View {

    @State private var window = FrameWindow()
    @State private var tally = TallyWindow()

    var body: some View {
        TimelineView(.animation) { timeline in
            let rate = window.record(timeline.date)

            VStack(alignment: .trailing, spacing: 2) {
                Text(rate > 0 ? "\(Int(rate.rounded())) FPS" : "— FPS")
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    .foregroundStyle(colour(for: rate))

                // What rebuilt, and how often, over the same second. See
                // `RenderTally` — in a turn-based game every one of these
                // should be near zero while nothing is moving.
                /*ForEach(rebuilds, id: \.self) { line in
                    Text(line)
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(Palette.gold)
                        .fixedSize()
                }*/
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Palette.coolBlack.opacity(0.7))
            )
        }
        .allowsHitTesting(false)
    }

    /// Green at full rate, amber when it slips, red when it is bad.
    ///
    /// Thresholds rather than a gradient: the number is already the precise
    /// answer, and what the colour is for is being readable out of the corner of
    /// your eye while you are looking at something else.
    private func colour(for rate: Double) -> Color {
        switch rate {
        case 50...: Palette.jade
        case 30..<50: Palette.gold
        default: Palette.red
        }
    }
}

/// A rolling average of the last second or so of frame intervals.
///
/// Averaged rather than instantaneous because a single frame's interval is
/// mostly noise — one long frame in thirty is not a drop from 60 to 20, and a
/// counter that says so is worse than none.
@Observable
private final class FrameWindow {

    private var last: Date?
    private var intervals: [TimeInterval] = []

    /// How many samples to average over. About a second at full rate.
    private let capacity = 60

    /// Records this frame and returns the current rate, or `0` until there is
    /// enough to say.
    func record(_ now: Date) -> Double {
        defer { last = now }
        guard let last else { return 0 }

        let elapsed = now.timeIntervalSince(last)
        // A gap that large is the app having been suspended, not a slow frame.
        guard elapsed > 0, elapsed < 1 else { return average }

        intervals.append(elapsed)
        if intervals.count > capacity { intervals.removeFirst() }
        return average
    }

    private var average: Double {
        guard !intervals.isEmpty else { return 0 }
        let mean = intervals.reduce(0, +) / Double(intervals.count)
        return mean > 0 ? 1 / mean : 0
    }
}

/// A one-second sample of `RenderTally`, held between frames.
///
/// Sampled on the frame clock rather than a timer of its own: a second timer is
/// a second thing waking the main thread up, which is the very thing being
/// measured.
@MainActor
private final class TallyWindow {

    private var openedAt: Date?
    private var lines: [String] = []

    /// The last completed second's rebuild counts, busiest first.
    func record(_ now: Date) -> [String] {
        guard let openedAt else {
            self.openedAt = now
            _ = RenderTally.drain()
            return lines
        }

        guard now.timeIntervalSince(openedAt) >= 1 else { return lines }

        self.openedAt = now
        lines = RenderTally.drain()
        return lines
    }
}

#endif
