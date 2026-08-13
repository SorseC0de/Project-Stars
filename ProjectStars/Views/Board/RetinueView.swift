//
//  RetinueView.swift
//  Project Stars
//
//  The phantoms following Leo.
//

import SwiftUI

/// A summoned sign trailing the piece.
///
/// ## Why it lags rather than sits on the square
///
/// It is *following*, and a follower that occupied the same cell would read as a
/// costume change rather than as a second body. Each phantom trails a little
/// further behind than the last, on its own slower spring, which is the same
/// trick `GemTrailView` uses — the offset is never computed, it falls out of the
/// animation arriving late.
///
/// ## Why it glows in its element rather than its accent
///
/// A phantom is *borrowed power*, and what the player needs to read off it at a
/// glance is what it can do, not which of twelve signs it happens to be. The
/// elemental colours are already the game's vocabulary for that — the gems, the
/// bursts, the star — so a follower lit in fire says "this one is going to burn
/// something" before its glyph has been recognised.
struct RetinueView: View {

    let zodiac: Zodiac

    /// Size of a board cell, in points.
    let tileSize: CGFloat

    /// Which way the lion is looking, so the line forms behind it.
    let facing: SwipeDirection

    /// Whole-pixel scale, for art-pixel offsets.
    let scale: CGFloat

    /// How far back in the line this one is. `0` follows closest.
    let step: Int

    var body: some View {
        let ramp = ElementFX.ramp(for: zodiac.element)

        PixelSprite(id: .piece(zodiac)) { Color.clear }
            .frame(width: tileSize, height: tileSize * 2)
            // Lit from inside in its element, then bloomed — the same treatment
            // a charged piece gets, which is the point: this *is* charge, parked
            // next to you.
            .colorMultiply(ramp.bright)
            .opacity(GameRules.retinueOpacity)
            .background {
                PixelSprite(id: .piece(zodiac)) { Color.clear }
                    .frame(width: tileSize, height: tileSize * 2)
                    .colorMultiply(ramp.mid)
                    .blur(radius: GameRules.retinueGlowRadius * scale)
                    .blendMode(.plusLighter)
                    // One offscreen pass — see `PaletteGlow`, which learned this
                    // the expensive way.
                    .drawingGroup()
            }
            // Matches `PieceView`'s figure box, so the phantom stands on the
            // ground rather than hovering over it.
            .offset(y: -tileSize / 2 - GameRules.pieceLift * scale)
            // Behind the lion, which is a direction rather than a corner.
            //
            // They used to trail off to the lower right whatever was happening,
            // so walking east put the retinue in front of the piece — a line of
            // followers leading the thing they follow. `behind` is simply the
            // reverse of the facing, and the whole column shifts when the lion
            // turns.
            .offset(
                x: -CGFloat(facing.unitOffset.dx) * CGFloat(step + 1)
                    * GameRules.retinueTrail * scale,
                y: -CGFloat(facing.unitOffset.dy) * CGFloat(step + 1)
                    * GameRules.retinueTrail * scale
            )
            .allowsHitTesting(false)
    }
}
