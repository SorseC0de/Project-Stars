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
            // TODO: Unconfirmed. Air has not been given a reserved entry yet, and
            // turquoise — the obvious choice — is already one of the three moss
            // greens, so on a mossy stone piece the glow would light up the
            // overgrowth. Left on dusk/lavender until an air sign is drawn and
            // its gem entry is chosen.
            GemTones(dim: Palette.dusk, lit: Palette.lavender)
        }
    }
}
