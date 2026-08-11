//
//  StarTrailView.swift
//  Project Stars
//
//  The colours the star leaves behind it.
//

import SwiftUI

/// One afterimage of a starred piece, in a colour it was wearing a moment ago.
///
/// ## Why the colours differ per copy
///
/// The star cycles the piece through all four elements. If every afterimage wore
/// the *current* colour the trail would be a smear of one hue — but each copy
/// lags in time, so each one should wear the colour from when it was there.
/// Copy `step` takes the element `step` places back in the cycle, which makes
/// the trail a readable record of the last half second.
///
/// ## Why it lags rather than remembering
///
/// Same trick as `GemTrailView`: every copy is placed at the piece's *current*
/// square and given its own slower spring, so `.animation(_:value:)` overrides
/// the replay's transaction and the copy arrives late. No position history to
/// keep, and nothing to clean up — when the piece stops, the copies settle onto
/// it and the trail closes.
struct StarTrailView: View {

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
                zip(Palette.pieceGoldTones, Palette.pieceTones(for: element))
                    .map(PaletteSwap.init)
            )
            .opacity(pow(GameRules.starTrailFalloff, Double(step + 1)))
            // Matches `PieceView`'s figure box, so the ghost sits where the
            // piece was rather than near it.
            .offset(y: -tileSize / 2 - GameRules.pieceLift * scale)
            .allowsHitTesting(false)
    }
}
