//
//  PaletteRamp.swift
//  Project Stars
//
//  Neighbours within the fixed palette, for flat shading.
//

import SwiftUI

/// One step lighter or darker, staying inside the 47 entries.
///
/// ## Why this is a table and not arithmetic
///
/// Multiplying a colour by 0.8 gives a colour the game does not own. Every other
/// surface here is shaded by *choosing another palette entry* — the piece's
/// stone form, the cloud's three layers, the elemental ramps — and the buttons
/// have to be shaded the same way or they will not sit in the same picture.
///
/// The ramps are the palette's own families, read in order, so a step is always
/// a step the artist already drew.
enum PaletteRamp {

    /// The families, light to dark. A colour finds itself and steps along.
    private static let ramps: [[Color]] = [
        [Palette.white, Palette.lightGray, Palette.gray, Palette.darkGray,
         Palette.smoke, Palette.coolBlack],
        [Palette.slate, Palette.stone, Palette.steel, Palette.iron, Palette.warmBlack],
        [Palette.cream, Palette.khaki, Palette.brown, Palette.darkBrown,
         Palette.maroon, Palette.plum, Palette.mocha],
        [Palette.yellowGreen, Palette.yellow, Palette.gold, Palette.orange,
         Palette.darkBrown],
        [Palette.grass, Palette.lime, Palette.green, Palette.darkGreen,
         Palette.forest, Palette.turqoise],
        [Palette.ice, Palette.cyan, Palette.lightBlue, Palette.blue,
         Palette.darkBlue, Palette.midnight],
        [Palette.sakura, Palette.blush, Palette.pink, Palette.magenta,
         Palette.darkMagenta, Palette.purple, Palette.dusk],
        [Palette.jade, Palette.teal, Palette.turqoise],
        [Palette.lavender, Palette.navy, Palette.midnight],
        [Palette.red, Palette.darkRed, Palette.maroon],
    ]

    static func darker(_ colour: Color) -> Color { step(colour, by: 1) }
    static func lighter(_ colour: Color) -> Color { step(colour, by: -1) }

    /// Walks `distance` places along whichever ramp holds this colour.
    ///
    /// Falls back to the colour itself when it is not on a ramp or is already at
    /// the end — a button that cannot be shaded should look flat rather than
    /// wrong.
    private static func step(_ colour: Color, by distance: Int) -> Color {
        for ramp in ramps {
            guard let index = ramp.firstIndex(where: { $0 == colour }) else { continue }
            let moved = index + distance
            guard ramp.indices.contains(moved) else { return colour }
            return ramp[moved]
        }
        return colour
    }
}
