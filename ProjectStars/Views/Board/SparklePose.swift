//
//  SparklePose.swift
//  Project Stars
//
//  How a glowing square hangs in the air.
//

import SwiftUI

/// Turns, bobs and breathes one square of the glow phase.
///
/// Borrowed wholesale from Polaris, which is the one thing in this game already
/// drawn as *a prize hanging in the air* — and a sparkle is making the same
/// promise about the square under it. Without the motion the phase was a
/// stamp: five identical marks appearing and vanishing, which reads as the
/// board being annotated rather than as something arriving on it.
///
/// **Every period is seeded off the square's index.** Five things sharing a
/// rhythm read as one object with five parts, which is the opposite of what a
/// scattered set of candidates should say — the whole point of a sparkle set is
/// that these are *separate* possibilities. Primes as multipliers, so the
/// periods drift apart rather than lining back up every few seconds.
struct SparklePose: ViewModifier {

    /// Which sparkle of the set this is.
    let index: Int

    /// The ambient clock, so the phase stops when the game is waiting.
    let clock: (TimeInterval) -> TimeInterval

    func body(content: Content) -> some View {
        TimelineView(.animation) { timeline in
            let now = clock(timeline.date.timeIntervalSinceReferenceDate)
            let seed = Double(index)

            let spin = now / (GameRules.sparkleSpinPeriod + seed * 0.7) * 2 * .pi
            let bob = now / (GameRules.sparkleBobPeriod + seed * 0.31) * 2 * .pi
            let breath = now / (GameRules.sparkleBreathPeriod + seed * 0.53) * 2 * .pi

            content
                .scaleEffect(1 + sin(breath) * GameRules.sparkleBreathSwing)
                .rotationEffect(.degrees(sin(spin) * GameRules.sparkleSpinSwing))
                .offset(y: sin(bob) * GameRules.sparkleBobHeight)
        }
    }
}
