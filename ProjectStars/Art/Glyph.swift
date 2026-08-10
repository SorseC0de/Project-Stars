//
//  Glyph.swift
//  Project Stars
//
//  Forcing monochrome rendering of the zodiac characters.
//

import Foundation

extension String {

    /// The same string, forced to render as text rather than colour emoji.
    ///
    /// The twelve zodiac characters (U+2648…U+2653) have
    /// `Emoji_Presentation = Yes`, so on Apple platforms a bare `Text("♈")`
    /// draws Apple's purple emoji tile — ignoring `foregroundStyle`, `font`
    /// weight, and everything else. Appending variation selector 15 (U+FE0E)
    /// asks for the text form instead, which is a plain outline the app can
    /// colour like any other glyph.
    ///
    /// Every view that draws a `ZodiacDefinition.glyph` or a pickup glyph goes
    /// through this. It becomes unnecessary once real pixel-art sprites replace
    /// the placeholders, but costs nothing to leave in.
    var monochromeGlyph: String {
        self + "\u{FE0E}"
    }
}
