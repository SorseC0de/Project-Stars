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

    /// Which twin this is, for the signs that have drawings of their own.
    var twin: GeminiHalf?

    /// Which drawing this half is.
    ///
    /// Gemini has one of each — they are two figures, not one figure cut in two
    /// — so the twin says which. Every other sign that ever splits falls back to
    /// being masked in half, which is what this view was built for.
    private var spriteID: SpriteID {
        if let twin, zodiac.hasOwnHalves { return .geminiHalf(twin) }
        return .piece(zodiac)
    }

    /// Whether this has to be made out of a whole figure.
    private var cropped: Bool { !zodiac.hasOwnHalves || twin == nil }

    enum Side { case left, right }

    var body: some View {
        PixelSprite(id: spriteID) { Color.clear }
            .frame(width: tileSize, height: tileSize * 2)
            // Cut in half only for signs that have no half of their own.
            //
            // The crop is a stand-in: it makes half a figure out of a whole one
            // for a sign nobody has drawn twins for. Applied to a sprite that is
            // *already* one twin it takes half of a half, which is the clipped
            // fragment that was standing in the middle of the board.
            .mask(alignment: cropped ? (side == .left ? .leading : .trailing) : .center) {
                Rectangle().frame(width: cropped ? tileSize / 2 : tileSize)
            }
            // The cut edge sits on the square's centre line rather than the
            // figure's, so half a piece still stands where a whole one would.
            // A whole drawing needs no such correction.
            .offset(x: cropped ? (side == .left ? tileSize / 4 : -tileSize / 4) : 0)
            // Drawn at full strength, waiting or not.
            //
            // The half that is not taking its turn used to be faded and drained
            // of colour to say *this one is not you*. But the two halves are
            // split across planes — that is what splitting means — so the only
            // board that ever shows this one is the board the other half is not
            // on. There is nothing to tell it apart from, and a dimmed piece
            // alone on a plane just reads as a piece drawn wrong.
            .allowsHitTesting(false)
    }
}
