//
//  AfterimageView.swift
//  Project Stars
//
//  The colours a piece leaves behind it.
//

import SwiftUI

/// One afterimage of the piece, in an element's colours.
///
/// Two states leave a trail, and they say different things with it:
///
/// - **A full meter** trails the sign's own element. The piece itself stays gold
///   — this is what carries the state, streaming off it.
/// - **The star** cycles all four, and each copy wears the colour from when it
///   was there: copy `step` takes the element `step` places back in the cycle,
///   which makes the trail a readable record of the last half second rather than
///   a smear of one hue.
///
/// ## Why it remembers rather than lags
///
/// The first version placed every copy at the piece's *current* square under its
/// own slower spring. That is a smear, not an afterimage: the ghosts are always
/// somewhere between two squares, sliding continuously, and they read as one
/// blurred object being dragged.
///
/// An afterimage is a snapshot. Each copy is pinned to a square the piece
/// **actually stood on** and does not move at all — it appears where the piece
/// was, holds, and fades. The result is deliberately choppy, one ghost per
/// square, which is what makes it read as a trail of images rather than motion
/// blur.
struct AfterimageView: View {

    let zodiac: Zodiac

    /// The element this copy wears.
    let element: ZodiacElement

    /// Size of a board cell, in points.
    let tileSize: CGFloat

    /// Whole-pixel scale, for art-pixel offsets.
    let scale: CGFloat

    /// How far back in the trail this copy is. `0` is the square just left.
    let step: Int

    /// How far through its life this ghost is, `0` fresh to `1` gone.
    let age: Double

    var body: some View {
        PixelSprite(id: .piece(zodiac)) { Color.clear }
            .frame(width: tileSize, height: tileSize * 2)
            .paletteSwap(
                zip(Palette.pieceGoldTones, Palette.trailTones(for: element))
                    .map(PaletteSwap.init)
            )
            // Fades on its own clock as well as by distance, so a ghost never
            // outlives the moment it is a record of.
            .opacity(pow(GameRules.afterimageFalloff, Double(step + 1)) * (1 - age))
            // Matches `PieceView`'s figure box, so the ghost sits where the
            // piece was rather than near it.
            .offset(y: -tileSize / 2 - GameRules.pieceLift * scale)
            .allowsHitTesting(false)
    }
}
