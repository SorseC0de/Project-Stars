//
//  FallStreaks.swift
//  Project Stars
//
//  The world rushing up past something falling through it.
//

import SwiftUI

/// Vertical streaks running bottom to top.
///
/// ## Why not the card's streaks turned on their side
///
/// `SideStreaks` says *this arrived from over there, fast.* It is a horizontal
/// field living inside a bar the width of the screen, and every length and
/// speed in it is a share of that bar's length.
///
/// This says something else: *you are falling, and the walls are going the
/// other way.* It runs the tall axis of a whole screen rather than the long
/// axis of a bar — a different aspect ratio, a different count, a different
/// sense of speed. Rotating the other field ninety degrees would have measured
/// all of it against the wrong edge. So it is its own field, with its own
/// bench, sharing only the two things that genuinely are shared: the hash that
/// scatters them and the mix they are coloured from.
///
/// Upward, because the streaks are the world, and the world is what moves when
/// the camera is stuck to a falling piece.
struct FallStreaks: View {

    /// Whether this is being looked at.
    ///
    /// The underground is a permanent row of the world column, so this view is
    /// mounted for the whole run whether or not anybody has died. A canvas
    /// asking for sixty frames a second behind a plane nobody is on is exactly
    /// the shape of the bug that cost this project a week — see
    /// `EnvironmentValues.planeIsAsleep`.
    var isLive = true

    var body: some View {
        TimelineView(.animation(paused: !isLive)) { timeline in
            Canvas { context, size in
                guard FallStreakStyle.glow > 0 else { return }
                // Between the streaks themselves: where they cross, they are two
                // lights rather than one in front of the other.
                context.blendMode = .plusLighter

                let now = timeline.date.timeIntervalSinceReferenceDate
                let thickness = FallStreakStyle.thickness

                for index in 0..<FallStreakStyle.count {
                    let span = scatter(index, 2)
                    let pace = scatter(index, 3)

                    // Measured against the height, which is the axis they run.
                    let length = size.height * FallStreakStyle.length
                        * (FallStreakStyle.shortest + span)
                    let speed = size.height * FallStreakStyle.speed
                        * (FallStreakStyle.slowest + pace)

                    // Wrapped over the height plus one streak, so a streak
                    // leaves the top and returns at the bottom with no moment
                    // where it is half-drawn at both.
                    let run = size.height + length
                    let travelled = (now * speed + Double(index) * 97)
                        .truncatingRemainder(dividingBy: run)

                    // Zero puts the whole streak below the bottom edge; `run`
                    // puts it above the top one. Upward, which is what falling
                    // looks like from inside.
                    let y = size.height - travelled

                    let x = scatter(index, 1) * size.width
                    let streak = CGRect(
                        x: x - thickness / 2,
                        y: y,
                        width: thickness,
                        height: length
                    )

                    let colour = streakColour(scatter(index, 5))
                    let glow = FallStreakStyle.glow
                        * (FallStreakStyle.faintest + scatter(index, 4))
                        * ModeCardStyle.gain(of: colour)

                    context.fill(
                        Capsule().path(in: streak),
                        with: .color(colour.opacity(glow))
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// What the falling streaks are made of.
///
/// Every knob is a `var` in front of a `default`, which is the seam the bench
/// reads through — see `FallStreakStyle.glow` for the shape and
/// `FallStreakTuning` for the other end of it.
///
/// `@MainActor` for the same reason `NexysStyle` is: the bench it reads through
/// is main-actor state, and an accessor that is not isolated cannot see it.
@MainActor
enum FallStreakStyle {

    /// How bright the field is. Zero turns it off.
    static var glow: Double {
        #if DEBUG
        FallStreakTuning.shared.glow
        #else
        defaultGlow
        #endif
    }

    /// How many are in flight at once.
    static var count: Int {
        #if DEBUG
        max(Int(FallStreakTuning.shared.count), 1)
        #else
        defaultCount
        #endif
    }

    /// How long the longest streak is, as a share of the screen's height.
    static var length: CGFloat {
        #if DEBUG
        CGFloat(FallStreakTuning.shared.length)
        #else
        CGFloat(defaultLength)
        #endif
    }

    /// How far the fastest travels each second, in screens.
    static var speed: CGFloat {
        #if DEBUG
        CGFloat(FallStreakTuning.shared.speed)
        #else
        CGFloat(defaultSpeed)
        #endif
    }

    /// How wide a streak is, in points.
    static var thickness: CGFloat {
        #if DEBUG
        CGFloat(FallStreakTuning.shared.thickness)
        #else
        CGFloat(defaultThickness)
        #endif
    }

    static let defaultGlow: Double = 0.66
    static let defaultCount = 48
    static let defaultLength: Double = 0.22
    static let defaultSpeed: Double = 1.1
    static let defaultThickness: Double = 2

    /// How short, how slow and how faint the meekest streak is allowed to be,
    /// as shares of the boldest. A spread is what makes a field read as depth;
    /// all one length and one speed reads as a moving pattern.
    ///
    /// Settled rather than benched — this is the same spread the card's tunnel
    /// uses, and it was tuned there.
    static let shortest: Double = 0.18
    static let slowest: Double = 0.35
    static let faintest: Double = 0.15
}
