//
//  SplitHalfView.swift
//  Project Stars
//
//  One half of a split Gemini.
//

import SwiftUI

/// Half of the twins, drawn by cropping the whole sprite down the middle.
///
/// ## Why a crop
///
/// Because there is no half-sprite yet, and a placeholder that is obviously the
/// real figure with a piece missing is more honest than a stand-in shape: it
/// reads correctly at a glance, it is exactly the right size, and it will be
/// replaced by two drawings that need no code change beyond the sprite id.
///
/// The seam is deliberately hard rather than faded. A soft edge would say
/// *ghost*, and neither half is a ghost — they are both real, both take damage,
/// and both can die.
///
/// ## Which half is which
///
/// The one taking its turn keeps the side it is facing away from, so the two of
/// them face outward from the square they split on. It is arbitrary and it is
/// consistent, which between them are the only two properties that matter for
/// something the player will read a hundred times.
struct SplitHalfView: View {

    let zodiac: Zodiac

    /// Size of a board cell, in points.
    let tileSize: CGFloat

    /// Whole-pixel scale, for art-pixel offsets.
    let scale: CGFloat

    /// Which side of the figure survives the crop.
    let side: Side

    /// Dimmed, for the half that is not taking this turn.
    var isWaiting = false

    enum Side { case left, right }

    var body: some View {
        PixelSprite(id: .piece(zodiac)) { Color.clear }
            .frame(width: tileSize, height: tileSize * 2)
            .mask(alignment: side == .left ? .leading : .trailing) {
                Rectangle().frame(width: tileSize / 2)
            }
            // The cut edge sits on the square's centre line rather than the
            // figure's, so half a piece still stands where a whole one would.
            .offset(x: side == .left ? tileSize / 4 : -tileSize / 4)
            .opacity(isWaiting ? GameRules.splitWaitingOpacity : 1)
            // The waiting half is drained rather than merely faded: it is
            // somewhere else, on another plane, and colour is what says *here*.
            .saturation(isWaiting ? GameRules.splitWaitingSaturation : 1)
            .allowsHitTesting(false)
    }
}
