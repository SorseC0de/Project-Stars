//
//  PaletteQuantise.swift
//  Project Stars
//
//  Making outside art into this game's art.
//

import SwiftUI

extension Image {

    /// Forces this image onto the game's palette **and** onto its pixel grid.
    ///
    /// Two halves of one job. Sourced art arrives with its own colours and its
    /// own resolution, and both are what give it away — a fixed forty-seven
    /// colour game at sixteen pixels is a style, and anything outside either
    /// reads as belonging to a different game.
    ///
    /// - The **grid** is handled here: the content is drawn into a frame of
    ///   whole art pixels with interpolation off, so it resolves at the art's
    ///   own density rather than the screen's, and is then scaled up hard-edged.
    /// - The **colours** are handled by `paletteQuantise`, which snaps each
    ///   pixel to its nearest palette entry.
    ///
    /// The result is not "a tornado made to look pixel-art". It is a tornado
    /// that *is* pixel art, in this game's palette, at this game's resolution —
    /// which is the difference between a shortcut and a compromise.
    ///
    /// On `Image` rather than on `View`, because the grid half needs
    /// `interpolation` and `antialiased`, which only an image has — and because
    /// the thing being brought in is always an image. Sprites off the master
    /// sheet are already on the palette and the grid and want none of this.
    ///
    /// - Parameters:
    ///   - artPixels: How many art pixels wide and tall to resolve at. A piece
    ///     is `GameRules.tilePixelSize`; something standing two cells tall is
    ///     twice that.
    ///   - scale: Points per art pixel.
    func paletteQuantised(artPixels: CGFloat, scale: CGFloat) -> some View {
        self
            .interpolation(.none)
            .antialiased(false)
            .resizable()
            .frame(width: artPixels, height: artPixels)
            .colorEffect(
                ShaderLibrary.paletteQuantise(
                    .floatArray(Palette.quantiseTable),
                    .float(Float(Palette.quantiseTable.count))
                )
            )
            // Rasterised at art size before it is enlarged, so the shader runs
            // over a few hundred pixels rather than a few hundred thousand — and
            // so what gets scaled up is the quantised result rather than the
            // original being quantised at screen resolution, which would put
            // palette colours on a grid that is not the art's.
            .drawingGroup()
            .scaleEffect(scale)
            .frame(width: artPixels * scale, height: artPixels * scale)
    }
}

extension Palette {

    /// Every palette colour as flat r,g,b floats, for `paletteQuantise`.
    ///
    /// Built once. Forty-seven entries is a hundred and forty-one floats handed
    /// to the GPU on every draw otherwise, for a table that never changes.
    static let quantiseTable: [Float] = indexed.flatMap { packed -> [Float] in
        [
            Float((packed >> 16) & 0xFF) / 255,
            Float((packed >> 8) & 0xFF) / 255,
            Float(packed & 0xFF) / 255,
        ]
    }
}
