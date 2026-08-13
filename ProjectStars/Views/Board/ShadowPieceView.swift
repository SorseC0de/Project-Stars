//
//  ShadowPieceView.swift
//  Project Stars
//
//  The mirrored double Shadow Work leaves on the board.
//

import SwiftUI

/// The player's piece, in shadow.
///
/// ## Why it is the same sprite
///
/// Because it *is* the player's piece — that is the whole idea, and a different
/// drawing would make it a monster rather than a reflection. It is the figure
/// with every colour taken out of it and the silhouette left behind, which reads
/// as a shadow at any size and needs no art of its own.
///
/// ## Why it is flipped
///
/// It mirrors your moves, so it mirrors you. Facing the other way is the cheapest
/// possible reminder of the rule you are about to have to plan around: west for
/// you is east for it.
struct ShadowPieceView: View {

    let zodiac: Zodiac

    /// Size of a board cell, in points.
    let tileSize: CGFloat

    /// Whole-pixel scale, for art-pixel offsets.
    let scale: CGFloat

    var body: some View {
        PixelSprite(id: .piece(zodiac)) { Color.clear }
            .frame(width: tileSize, height: tileSize * 2)
            // Flattened to a silhouette, then tinted. `colorMultiply` cannot
            // brighten, which for once is exactly what is wanted: every tone in
            // the figure collapses toward the same dark violet and the shape is
            // all that survives.
            .saturation(0)
            .colorMultiply(Palette.midnight)
            .opacity(GameRules.shadowOpacity)
            .scaleEffect(x: -1, y: 1)
            // Matches `PieceView`'s figure box, so it stands on the ground
            // rather than hovering over it.
            .offset(y: -tileSize / 2 - GameRules.pieceLift * scale)
            .allowsHitTesting(false)
    }
}
