//
//  EmberView.swift
//  Project Stars
//
//  The sparks coming off a piece that is burning.
//

import SwiftUI

/// Embers rising off the piece while Aries' Brazen Blaze burns.
///
/// ## Why these rise rather than orbit
///
/// Polaris' sparks circle their star because a star is a thing hanging in space.
/// A piece that is *on fire* sheds upward — heat goes one way, and a ring of
/// twinkles around a burning ram would read as jewellery. They start low, drift
/// up and outward, and go out.
///
/// ## Why they loop on their own clocks
///
/// Brazen Blaze lasts five moves and a move takes as long as the player takes,
/// so there is no duration to animate against. Each ember runs its own cycle
/// from the wall clock and simply repeats, which means the fire is *there* for
/// as long as the buff is and needs no start or end.
struct EmberView: View {

    /// Size of a board cell, in points.
    let tileSize: CGFloat

    /// Whole-pixel scale, for art-pixel distances.
    let scale: CGFloat

    /// Which element these are made of.
    ///
    /// Fire rises off a burning ram; Aquarius' gale streams off a piece being
    /// carried by it. Same particles, different direction and ramp — a second
    /// view would have been the same forty lines with two numbers changed.
    var element: ZodiacElement = .fire

    /// How far they blow sideways relative to how far they climb.
    ///
    /// Fire goes almost straight up. Wind goes almost straight across.
    var drift: CGFloat = 0

    var body: some View {
        TimelineView(.animation) { timeline in
            let now = timeline.date.timeIntervalSinceReferenceDate

            ZStack {
                ForEach(0..<GameRules.emberCount, id: \.self) { index in
                    let ember = ember(index, at: now)

                    Circle()
                        .fill(ember.colour)
                        .frame(width: ember.size, height: ember.size)
                        .offset(x: ember.x, y: ember.y)
                        .opacity(ember.opacity)
                }
            }
            .blendMode(.plusLighter)
        }
        .allowsHitTesting(false)
    }

    /// One ember's place in its cycle.
    ///
    /// Everything is derived from the index, so no state is kept and nothing can
    /// be left half-risen when the buff ends.
    private func ember(
        _ index: Int,
        at now: TimeInterval
    ) -> (x: CGFloat, y: CGFloat, size: CGFloat, opacity: Double, colour: Color) {
        let seed = Double(index) * 0.618        // Golden ratio: spreads without clumping.
        let period = GameRules.emberPeriod * (0.7 + seed.truncatingRemainder(dividingBy: 0.6))
        let life = ((now / period) + seed).truncatingRemainder(dividingBy: 1)

        // Drifts outward as it climbs, and wanders as it goes.
        let sway = sin(life * 6 + seed * 10) * Double(GameRules.emberSway)
        let spread = (seed.truncatingRemainder(dividingBy: 0.4) - 0.2) * 12

        // Hottest at the bottom, cooling as it rises: the fire ramp, in order.
        let ramp = ElementFX.ramp(for: element)
        let colour = life < 0.35 ? ramp.bright : (life < 0.7 ? ramp.mid : ramp.deep)

        return (
            x: CGFloat(spread + sway) * scale + CGFloat(life) * drift * scale,
            y: CGFloat(GameRules.emberFoot - life * Double(GameRules.emberRise)) * scale,
            size: GameRules.emberSize * scale * CGFloat(1 - life * 0.5),
            // Fades in fast, out slowly, so nothing pops into existence.
            opacity: min(life * 6, 1) * (1 - life),
            colour: colour
        )
    }
}
