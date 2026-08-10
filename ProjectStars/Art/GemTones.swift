//
//  GemTones.swift
//  Project Stars
//
//  The eye and base pixels that light up when a piece is charged.
//

import SwiftUI

/// The two states of a piece's gem: dim at rest, bright when charged.
///
/// Every sign reserves one palette entry for its gem and uses it **nowhere
/// else** in the sprite. That is what makes the effect possible at all: the glow
/// shader matches on colour, so a gem entry appearing anywhere else would light
/// that up too.
///
/// The dim entry is what is drawn in the sheet. The lit entry replaces it when
/// the Zodiaction is charged or firing, and is what blooms.
struct GemTones {

    /// As drawn in the sprite.
    let dim: Color

    /// Swapped in when charged, and the entry the glow keys on.
    let lit: Color

    /// - Note: The dim entries are fixed by the art — 44 water, 27 fire, 35
    ///   earth, 20 air. The lit entries are a choice, and each is the nearest
    ///   brighter entry of the same hue, so a gem reads as the same stone
    ///   catching light rather than as a different stone.
    static func forElement(_ element: ZodiacElement) -> GemTones {
        switch element {
        case .water:
            // Confirmed against the Pisces sheet: the only dark blue in it.
            GemTones(dim: Palette.darkBlue, lit: Palette.lightBlue)

        case .fire:
            GemTones(dim: Palette.darkRed, lit: Palette.red)

        case .earth:
            // `forest` is reserved for this and kept out of the moss, which uses
            // green, darkGreen and turquoise.
            GemTones(dim: Palette.forest, lit: Palette.lime)

        case .air:
            // Purple, provisionally — the one element whose gem has not been
            // settled. `purple` is at least clear of the moss greens, so it will
            // not light up overgrowth on a stone piece the way turquoise would.
            GemTones(dim: Palette.purple, lit: Palette.magenta)
        }
    }
}
