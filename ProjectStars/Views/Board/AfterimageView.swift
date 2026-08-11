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
/// ## Why it lags rather than remembering
///
/// Same trick as `GemTrailView`: every copy is placed at the piece's *current*
/// square and given its own slower spring, so `.animation(_:value:)` overrides
/// the replay's transaction and the copy arrives late. No position history to
/// keep, and nothing to clean up — when the piece stops, the copies settle onto
/// it and the trail closes.
struct AfterimageView: View {

    let zodiac: Zodiac

    /// The element this copy wears.
    let element: ZodiacElement

    /// Size of a board cell, in points.
    let tileSize: CGFloat

    /// Whole-pixel scale, for art-pixel offsets.
    let scale: CGFloat

    /// How far back in the trail this copy is. `0` rides closest to the piece.
    let step: Int

    var body: some View {
        PixelSprite(id: .piece(zodiac)) { Color.clear }
            .frame(width: tileSize, height: tileSize * 2)
            .paletteSwap(
                zip(Palette.pieceGoldTones, Palette.trailTones(for: element))
                    .map(PaletteSwap.init)
            )
            .opacity(pow(GameRules.afterimageFalloff, Double(step + 1)))
            // Matches `PieceView`'s figure box, so the ghost sits where the
            // piece was rather than near it.
            .offset(y: -tileSize / 2 - GameRules.pieceLift * scale)
            .allowsHitTesting(false)
    }
}
