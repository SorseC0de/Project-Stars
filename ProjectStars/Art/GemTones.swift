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

    /// What the gem is *shown* as at rest, when that is not the entry the art
    /// uses for it.
    ///
    /// The distinction matters and getting it wrong breaks the sign silently.
    /// `dim` is not a colour choice — it is the **identifier** the sprite is
    /// drawn with, and every swap and glow mask keys on it. Recolouring a gem by
    /// editing `dim` therefore does not recolour anything: the swap stops
    /// matching the art, the gem never lights, and the only thing left glowing
    /// is whatever body pixels happen to share the lit colour.
    ///
    /// So the resting look is its own entry, swapped in over the top.
    var resting: Color?

    /// - Note: The dim entries are fixed by the art — 44 water, 27 fire, 35
    ///   earth, 20 air. The lit entries are a choice, and each is the nearest
    ///   brighter entry of the same hue, so a gem reads as the same stone
    ///   catching light rather than as a different stone.
    static func forElement(_ element: ZodiacElement) -> GemTones {
        switch element {
        case .water:
            // Confirmed against the Pisces sheet: the only dark blue in it.
            GemTones(dim: Palette.darkBlue, lit: Palette.sky)

        case .fire:
            // Drawn as `darkRed` — index 27, fixed by the art — and *shown* as
            // coffee at rest. Against the vines' green a dark red gem read as
            // blood on the statue; coffee reads as a stone that is not lit.
            GemTones(dim: Palette.darkRed, lit: Palette.red, resting: Palette.coffee)

        case .earth:
            // `forest` is reserved for this and kept out of the moss, which uses
            // green, darkGreen and turquoise.
            GemTones(dim: Palette.forest, lit: Palette.lime)

        case .air:
            // Purple, settled. It is also clear of the moss greens, so it will
            // not light up overgrowth on a stone piece the way turquoise would.
            GemTones(dim: Palette.purple, lit: Palette.magenta)
        }
    }
}
