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
        PixelSprite(id: .piece(zodiac)) { Color.clear }
            .frame(width: tileSize, height: tileSize * 2)
            // The same treatment as Shadow Work's double, and for the same
            // reason: a summoned figure that keeps its own colours reads as a
            // second player rather than as a thing Leo is projecting.
            //
            // Not flipped, though. The shadow mirrors your moves and faces the
            // other way to say so; a phantom copies them, and turning it round
            // would be claiming the opposite.
            .saturation(0)
            .colorMultiply(Palette.midnight)
            .opacity(GameRules.retinueOpacity)
            // Matches `PieceView`'s figure box, so it stands on the ground
            // rather than hovering over it.
            .offset(y: -tileSize / 2 - GameRules.pieceLift * scale)
            .allowsHitTesting(false)
    }
}
