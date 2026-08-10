//
//  PieceIconView.swift
//  Project Stars
//
//  A piece drawn as a square badge, for menus and readouts.
//

import SwiftUI

/// Shows a sign as an icon in a square box.
///
/// Separate from `PieceView` on purpose. On the board a piece is a 16x32 sprite
/// that rises out of its tile and overlaps whatever is behind it — exactly what
/// you do **not** want in a list of twelve signs, where every entry has to
/// occupy the same square and none may spill into its neighbour.
///
/// So this fits the same sprite inside its box instead of standing it on one,
/// and carries no shadow, no facing, and no drift.
struct PieceIconView: View {

    let zodiac: Zodiac

    /// Edge length of the box, in points.
    let size: CGFloat

    var body: some View {
        PixelSprite(id: .piece(zodiac)) {
            placeholder
        }
        // The sprite is twice as tall as it is wide; `.fit` keeps it whole and
        // centred rather than cropping it to the square.
        .aspectRatio(0.5, contentMode: .fit)
        .frame(width: size, height: size)
    }

    private var placeholder: some View {
        let definition = zodiac.definition
        return ZStack {
            RoundedRectangle(cornerRadius: size * 0.22)
                .fill(definition.accentColor)
            RoundedRectangle(cornerRadius: size * 0.22)
                .strokeBorder(.white.opacity(0.65), lineWidth: max(1, size * 0.05))
            Text(definition.glyph.monochromeGlyph)
                .font(.system(size: size * 0.55, weight: .bold))
                .foregroundStyle(.white)
        }
    }
}
