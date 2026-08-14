//
//  ArrowView.swift
//  Project Stars
//
//  The shaft Sagittarius leaves standing in a square.
//

import SwiftUI

/// An Astral Arrow, stuck in the ground and waiting to be recalled.
///
/// ## Why it is drawn rather than sprited
///
/// It is a line of light, and a line of light is cheaper to draw than to store —
/// four palette colours, a shaft, a head and fletching, none of which needs
/// pixel art to read at this size. It also lets the glow pulse continuously
/// without a frame count, which matters for something that may stand in the
/// board for fifty moves.
///
/// ## Why it leans, having flown straight
///
/// The shot itself is vertical: the arrow goes up out of the board and comes
/// back down onto it, both at ninety degrees, because that is the shape of a
/// thing fired into the sky and not a thing thrown across a room.
///
/// Where it *sticks* is another matter. Straight up reads as a post, and
/// everything else the game draws in the air turns or drifts, so the planted
/// shaft leans a few degrees — which says it arrived rather than being
/// installed, without pretending it flew at that angle.
struct ArrowView: View {

    /// Rendered edge length of one cell, in points.
    let tileSize: CGFloat

    /// Whole-pixel scale, for art-pixel measurements.
    let scale: CGFloat

    /// The ambient clock, which stops while the game waits on the player.
    ///
    /// Ambient motion carrying on under a frozen game is the clearest possible
    /// signal that nothing is waiting on anything. See
    /// `GameSession.ambientClock(at:)`.
    var clock: (TimeInterval) -> TimeInterval = { $0 }


    var body: some View {
        TimelineView(.animation) { timeline in
            let now = clock(timeline.date.timeIntervalSinceReferenceDate)
            let pulse = (sin(now / GameRules.arrowPulsePeriod * 2 * .pi) + 1) / 2

            ZStack {
                // The square it planted itself in, humming. Under the shaft, so
                // the arrow reads as standing in it.
                EffectSpriteView(
                    effect: .sagittariusTeleTile,
                    tileSize: tileSize,
                    start: .distantPast,
                    loops: true,
                    clock: clock
                )

                shaft
                    .blur(radius: GameRules.arrowGlowRadius * scale)
                    .opacity(0.5 + 0.5 * pulse)
                    .blendMode(.plusLighter)

                shaft
            }
        }
        .allowsHitTesting(false)
    }

    /// The shaft, buried to the head.
    ///
    /// ## Why it is masked rather than drawn short
    ///
    /// The art is a whole arrow, because the same sprite is the thing that flies
    /// — straight up out of the board and straight back down onto it. What is
    /// left standing afterwards is the part that did not go in, so the sprite is
    /// clipped at ground level rather than being a second, shorter drawing that
    /// would have to be kept in step with the first.
    private var shaft: some View {
        PixelSprite(id: .effect(.sagittariusArrow)) { EmptyView() }
            .frame(width: tileSize * 2, height: tileSize * 2)
            .mask(alignment: .top) {
                // Everything above the ground line survives; the head and a
                // little shaft below it are buried.
                Rectangle()
                    .frame(height: tileSize * 2 * GameRules.arrowBuriedFraction)
            }
            // The art's own rotation first, then the lean it landed at.
            .rotationEffect(.degrees(GameRules.arrowArtRotation + GameRules.arrowLean))
            // Its point is in the ground, so it stands *above* the square it
            // marks rather than centred on it.
            .offset(y: -GameRules.arrowRise * scale)
    }
}
