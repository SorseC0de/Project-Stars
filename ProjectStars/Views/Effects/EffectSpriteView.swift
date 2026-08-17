//
//  EffectSpriteView.swift
//  Project Stars
//
//  Plays one of the imported effect strips, once.
//

import SwiftUI

/// A drawn effect animation, played through once and then gone.
///
/// ## Why it is stepped by hand rather than left to `PixelSprite`
///
/// `PixelSprite` cycles a multi-frame sprite on a wall clock, which is right for
/// ambient things — a coin glinting, a sparkle shimmering — and wrong for an
/// event. An effect fired by a Zodiaction has to start on the frame the
/// Zodiaction fired, play through, and stop. So the frame is computed from
/// elapsed time against a stored timestamp, exactly like every other effect in
/// this game, and pinned with `PixelSprite(frame:)`.
///
/// Past its last frame it draws nothing at all rather than holding the final
/// frame — a dissipating flame that stayed on screen would read as a bug.
///
/// ## Scale
///
/// The art is 64px, four tiles across. Drawn at native size it would swallow the
/// board, so `GameRules.effectSpan` sizes it in tiles. That is a fractional
/// scale, which for pixel art means the nearest-neighbour sampling in
/// `PixelSprite` is doing real work — it is why interpolation is off there.
struct EffectSpriteView: View {

    let effect: EffectSprite

    /// Size of a board cell, in points.
    let tileSize: CGFloat

    /// When it started.
    let start: Date

    /// Size multiplier on top of `GameRules.effectSpan`, for the odd effect that
    /// wants to be bigger than standard.
    var magnitude: CGFloat = 1

    /// Plays for ever instead of once.
    ///
    /// The exception rather than the rule — an effect is normally an *event* and
    /// stops. A warp square hums for as long as the arrow is standing in it,
    /// which is a state rather than a moment.
    var loops = false

    /// The ambient clock, so a looping effect holds still with everything else
    /// when the game is waiting on the player.
    var clock: (TimeInterval) -> TimeInterval = { $0 }

    /// Play only the first this-many frames, or `nil` for the whole strip.
    ///
    /// For strips whose tail is not wanted — a gust that ends on empty cells is
    /// fine played once and wrong looped, because the gap becomes a hole that
    /// comes round again.
    var frameCount: Int?

    /// Recolours the whole strip, for art drawn deliberately colourless.
    ///
    /// A flat silhouette rather than a palette swap: the absorb is greys with no
    /// named light and dark to pair off, and the point of drawing it that way is
    /// that whatever tints it is the only thing saying which element earned the
    /// charge. Shading it would mean naming its tones, which is the decision the
    /// grey art exists to avoid.
    var tint: Color?

    /// How many frames are actually played.
    private var playing: Int {
        min(max(frameCount ?? effect.frames, 1), effect.frames)
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            let now = clock(timeline.date.timeIntervalSinceReferenceDate)
            let elapsed = loops
                ? now
                : timeline.date.timeIntervalSince(start)
            let step = Int(elapsed / effect.rate.frameDuration)
            let frame = loops ? ((step % playing) + playing) % playing : step

            if elapsed >= 0, frame < playing {
                let art = recoloured(
                    PixelSprite(id: .effect(effect), frame: frame) { EmptyView() }
                        .frame(width: side, height: height),
                    frame: frame
                )

                let lift = -effect.groundLift
                    * (tileSize / CGFloat(GameRules.tilePixelSize))

                ZStack {
                    // The light it casts, under the art rather than over it, so
                    // the drawn detail stays readable through its own glow.
                    art
                        .blur(radius: GameRules.effectGlowRadius * artScale)
                        .opacity(effect.glowIntensity)
                        .blendMode(.plusLighter)

                    art
                }
                .blendMode(effect.blend)
                .offset(y: lift)
                .offset(
                    x: effect.artNudge.width * (tileSize / CGFloat(GameRules.tilePixelSize)),
                    y: effect.artNudge.height * (tileSize / CGFloat(GameRules.tilePixelSize))
                )
            }
        }
        .allowsHitTesting(false)
    }

    /// This frame in the palette it should be played in.
    ///
    /// A frame at a time, so a strip can strobe through several colours over its
    /// run — which is the whole reason this is done at draw time rather than
    /// baked into the art.
    @ViewBuilder
    private func recoloured(_ art: some View, frame: Int) -> some View {
        let cycle = effect.recolourCycle

        if let tint {
            // **Multiplied**, not flattened. A silhouette paints every pixel
            // one colour, which for greyscale art throws away the only thing in
            // it — the art *is* its shading. Multiplying a grey ramp by a colour
            // gives that colour's ramp, which is exactly what tinting greyscale
            // means and what keeps the detail readable.
            art.colorMultiply(tint)
        } else if let source = effect.sourceTones, !cycle.isEmpty {
            let tone = cycle[frame % cycle.count]
            art.paletteSwap([
                PaletteSwap(source.light, tone.bright),
                PaletteSwap(source.dark, tone.dark),
            ])
        } else {
            art
        }
    }

    /// Width in points. `span` is measured in tiles.
    private var side: CGFloat {
        tileSize * effect.span * magnitude
    }

    /// Height, from the frame's own proportions.
    ///
    /// Not every strip is square — a lightning bolt is 64x160 — so the height
    /// follows the art rather than being assumed equal to the width.
    private var height: CGFloat {
        side * effect.frameSize.height / effect.frameSize.width * effect.spanScaleY
    }

    /// Points per art pixel at the size this is being drawn, so the bloom is
    /// measured in the art's own units rather than in screen points.
    private var artScale: CGFloat {
        side / effect.frameSize.width
    }
}
