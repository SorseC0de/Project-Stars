//
//  CarriedPickupView.swift
//  Project Stars
//
//  The Pentacle a sliding piece is carrying but has not opened.
//

import SwiftUI

/// A coin held above the piece's head while it is still travelling.
///
/// ## Why a coin is carried at all
///
/// Sliding onto a Pentacle used to open it where it lay, which stopped the slide
/// dead halfway across the board — and a slide is *one continuous movement*, so
/// interrupting it is the one thing it must not do. Party games solved this long
/// ago: crossing a coin queues it, the piece carries it visibly, and it resolves
/// when the movement ends. That also makes an effect that moves the piece safe,
/// since it can never fire while the piece is already moving.
///
/// ## Why it bobs
///
/// It is being carried rather than worn. A mark pinned rigidly above a moving
/// piece reads as part of the sprite; one that lags and settles reads as an
/// object going along for the ride.
struct CarriedPickupView: View {
    @Environment(\.planeIsAsleep) private var planeIsAsleep



    /// Size of a board cell, in points.
    let tileSize: CGFloat

    /// Whole-pixel scale, for art-pixel offsets.
    let scale: CGFloat

    /// The ambient clock, which stops while the game waits on the player.
    ///
    /// Ambient motion carrying on under a frozen game is the clearest possible
    /// signal that nothing is waiting on anything. See
    /// `GameSession.ambientClock(at:)`.
    var clock: (TimeInterval) -> TimeInterval = { $0 }


    var body: some View {
        TimelineView(.animation(paused: planeIsAsleep)) { timeline in
            #if DEBUG
            let _ = RenderTally.tick("CarriedPickup")
            #endif
            let now = clock(timeline.date.timeIntervalSinceReferenceDate)
            let bob = sin(now / GameRules.carriedBobPeriod * 2 * .pi)
            let side = GameRules.carriedSize * scale

            ZStack {
                Circle()
                    .fill(Palette.gold.celShadow)
                    .frame(width: side, height: side)
                    .offset(y: scale)

                Circle()
                    .fill(Palette.gold)
                    .frame(width: side, height: side)

                Circle()
                    .fill(Palette.yellow)
                    .frame(width: side * 0.5, height: side * 0.5)
            }
            .offset(y: -GameRules.carriedLift * scale + CGFloat(bob) * GameRules.carriedBob * scale)
        }
        .allowsHitTesting(false)
    }
}
