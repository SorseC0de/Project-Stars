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

    var body: some View {
        TimelineView(.animation) { timeline in
            let elapsed = timeline.date.timeIntervalSince(start)
            let frame = Int(elapsed / effect.rate.frameDuration)

            if elapsed >= 0, frame < effect.frames {
                let art = PixelSprite(id: .effect(effect), frame: frame) { EmptyView() }
                    .frame(width: side, height: side)

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
                .offset(y: lift)
            }
        }
        .allowsHitTesting(false)
    }

    private var side: CGFloat {
        tileSize * effect.span * magnitude
    }

    /// Points per art pixel at the size this is being drawn, so the bloom is
    /// measured in the art's own units rather than in screen points.
    private var artScale: CGFloat {
        side / CGFloat(GameRules.effectPixelSize)
    }
}
