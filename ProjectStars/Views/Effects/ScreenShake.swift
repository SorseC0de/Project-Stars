//
//  ScreenShake.swift
//  Project Stars
//
//  A short, decaying jolt of the board.
//

import SwiftUI

/// Shakes its content for `GameRules.shakeDuration` after `startedAt`.
///
/// A decaying oscillation evaluated from elapsed time, like `HopPose` — nothing
/// to get stuck part-way through, and no animation state to reset.
///
/// The `TimelineView` only wraps the content **while a shake is running**. That
/// matters: the board is fifty-odd sprites, and driving all of them off a
/// display-linked clock permanently would cost a full redraw every frame for an
/// effect that plays for a third of a second.
///
/// The two axes run at different frequencies so the motion reads as a jolt
/// rather than a tidy diagonal wobble.
struct ScreenShake: ViewModifier {

    /// When the current shake began, or `nil` for none.
    let startedAt: Date?

    /// How hard, against the usual amplitude.
    var strength: CGFloat = 1

    /// Whole-pixel scale, for art-pixel amplitude.
    let scale: CGFloat

    func body(content: Content) -> some View {
        if let startedAt {
            TimelineView(.animation) { timeline in
                content.offset(offset(at: timeline.date, from: startedAt))
            }
        } else {
            content
        }
    }

    private func offset(at date: Date, from start: Date) -> CGSize {
        let elapsed = date.timeIntervalSince(start)
        guard elapsed >= 0, elapsed < GameRules.shakeDuration else { return .zero }

        // Linear decay to zero, so the shake ends flat rather than being cut off
        // mid-swing.
        let decay = 1 - elapsed / GameRules.shakeDuration
        let amplitude = GameRules.shakeAmplitude * scale * CGFloat(decay) * strength

        // Both axes on `sin`, so both start at zero.
        //
        // The vertical one was `cos`, which is 1 at t=0 — so the board jumped
        // by six tenths of the amplitude on the first frame of every shake and
        // oscillated about a position it had never been in. It came home only
        // when the decay ran out, which is why the jolt read as the board
        // drifting rather than as an impact.
        //
        // The offset ratio still does the work of keeping the motion from being
        // a tidy diagonal: 0.73 is not a harmonic of 1, so the two axes stay out
        // of step for far longer than a shake lasts.
        let phase = elapsed * GameRules.shakeFrequency * 2 * .pi
        return CGSize(
            width: amplitude * CGFloat(sin(phase)),
            height: amplitude * CGFloat(sin(phase * 0.73)) * 0.6
        )
    }
}

extension View {
    /// Jolts this view when `startedAt` changes to a fresh timestamp.
    /// - Parameter strength: A multiplier on the usual amplitude. A fall is
    ///   `1`; things that happen constantly want far less, or the board never
    ///   holds still.
    func screenShake(startedAt: Date?, scale: CGFloat, strength: CGFloat = 1) -> some View {
        modifier(ScreenShake(startedAt: startedAt, strength: strength, scale: scale))
    }
}
