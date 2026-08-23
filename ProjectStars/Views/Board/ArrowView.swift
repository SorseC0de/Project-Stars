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
    @Environment(\.planeIsAsleep) private var planeIsAsleep



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
        TimelineView(.animation(paused: planeIsAsleep)) { timeline in
            #if DEBUG
            let _ = RenderTally.tick("Arrow")
            #endif
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

                // `PaletteGlow`, not a blur of the whole sprite.
                //
                // Blurring the shaft entire is what produced an outline of light
                // around a dark arrow: every pixel contributes, dark ones
                // included, so the bloom is the *silhouette* smeared outward.
                // `PaletteGlow` masks to the pixels bright enough to be a light
                // source and blooms those, which puts the glow inside the arrow
                // where the highlights actually are.
                PaletteGlow(
                    // Lower than the house threshold on purpose.
                    //
                    // The arrow is drawn in violets and a dull gold, and none of
                    // it clears the level that counts as "bright" across the
                    // rest of the game — so the mask kept everything and the
                    // glow came out as nothing at all. The setting exists for
                    // exactly this: a sprite whose own highlights are dark.
                    threshold: GameRules.arrowGlowThreshold,
                    radius: GameRules.arrowGlowRadius * scale,
                    intensity: (0.5 + 0.5 * pulse) * GameRules.arrowGlowIntensity,
                    trail: GameRules.arrowGlowPasses - 1
                ) {
                    shaft
                }
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
            // Masked **before** it is turned, and along the axis it is drawn
            // on. The art points right, so the head is at its right-hand edge
            // and that is the end that goes into the ground — clipping the
            // bottom of a horizontal arrow takes a stripe off its length
            // instead, which is why it came out whole and standing on its point.
            .mask(alignment: .leading) {
                Rectangle()
                    .frame(width: tileSize * 2 * GameRules.arrowBuriedFraction)
            }
            // The art's own rotation first, then the lean it landed at.
            .rotationEffect(.degrees(GameRules.arrowArtRotation + GameRules.arrowLean))
            // Its point is in the ground, so it stands *above* the square it
            // marks rather than centred on it.
            .offset(y: -GameRules.arrowRise * scale)
    }
}
