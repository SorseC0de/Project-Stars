//
//  PaletteColors.swift
//  Project Stars
//
//  The game's fixed 47-colour palette. Nothing may be drawn outside it.
//

import SwiftUI

/// The palette every pixel in the game comes from.
///
/// Ported from the GameMaker `pal_*` macros, keeping the names exactly — the art
/// is authored against these, so `pal_darkBrown` in a note about a sprite and
/// `Palette.darkBrown` here have to mean the same thing or the shared vocabulary
/// stops working.
///
/// The palette is **fixed by design**. New colours are not mixed; a shade that
/// does not exist here is a shade the game does not have. That constraint is
/// what lets a sprite be recoloured by index — see the note on
/// ``Palette/index(of:)``.
///
/// Index numbers are the palette's own ordering, preserved so a future
/// palette-swap shader can address a colour by index rather than by value.
extension Palette {

    // MARK: Greys — indices 1–6

    static let white = Color(hex: 0xF8F8F8)          // 1
    static let lightGray = Color(hex: 0xBCB7C5)      // 2
    static let gray = Color(hex: 0x8D87A2)           // 3
    static let darkGray = Color(hex: 0x50576B)       // 4
    static let smoke = Color(hex: 0x2E3740)          // 5
    static let coolBlack = Color(hex: 0x101E29)      // 6

    // MARK: Neutrals — indices 7–12

    static let warmBlack = Color(hex: 0x302C2E)      // 7
    static let iron = Color(hex: 0x5A5353)           // 8
    static let steel = Color(hex: 0x7D7071)          // 9
    static let stone = Color(hex: 0xA0938E)          // 10
    static let slate = Color(hex: 0xCFC6B8)          // 11
    static let cream = Color(hex: 0xF4CCA1)          // 12

    // MARK: Earths — indices 13–18

    static let khaki = Color(hex: 0xEEA160)          // 13
    static let brown = Color(hex: 0xBF7958)          // 14
    static let darkBrown = Color(hex: 0xA05B53)      // 15
    static let maroon = Color(hex: 0x7A444A)         // 16
    static let plum = Color(hex: 0x5E3643)           // 17
    static let mocha = Color(hex: 0x472D3C)          // 18

    // MARK: Violets — indices 19–24

    static let midnight = Color(hex: 0x39314B)       // 19
    static let purple = Color(hex: 0x64468D)         // 20
    static let darkMagenta = Color(hex: 0x8E478C)    // 21
    static let magenta = Color(hex: 0xAE57A4)        // 22
    static let pink = Color(hex: 0xEA71BD)           // 23
    static let sakura = Color(hex: 0xFFAEB6)         // 24

    // MARK: Warms — indices 25–30

    static let blush = Color(hex: 0xFF8B9C)          // 25
    static let red = Color(hex: 0xE1534A)            // 26
    static let darkRed = Color(hex: 0xA93B3B)        // 27
    static let orange = Color(hex: 0xF47E1B)         // 28
    static let gold = Color(hex: 0xF4B41B)           // 29
    static let yellow = Color(hex: 0xFFCE00)         // 30

    // MARK: Greens — indices 31–36

    static let yellowGreen = Color(hex: 0xFBFCAA)    // 31
    static let lime = Color(hex: 0xB6D53C)           // 32
    static let green = Color(hex: 0x71AA34)          // 33
    static let darkGreen = Color(hex: 0x3F7E00)      // 34
    static let forest = Color(hex: 0x005F1B)         // 35
    static let turqoise = Color(hex: 0x00635C)       // 36

    // MARK: Cools — indices 37–42

    static let teal = Color(hex: 0x00A383)           // 37
    static let jade = Color(hex: 0x3FC778)           // 38
    static let grass = Color(hex: 0xA1EF79)          // 39
    static let ice = Color(hex: 0xDFF6F5)            // 40
    static let cyan = Color(hex: 0x92F4FF)           // 41
    static let lightBlue = Color(hex: 0x42CAFD)      // 42

    // MARK: Blues — indices 43–47

    static let blue = Color(hex: 0x3978A8)           // 43
    static let darkBlue = Color(hex: 0x243F72)       // 44
    static let dusk = Color(hex: 0x564064)           // 45
    static let lavender = Color(hex: 0x827094)       // 46
    static let navy = Color(hex: 0x4F546B)           // 47
}

// MARK: - Indexed access

extension Palette {

    /// Every palette colour, in index order, as packed `0xRRGGBB`.
    ///
    /// Kept as raw values rather than `Color` because the use for it is a
    /// palette-swap shader: hand Metal a source index and a destination index and
    /// it can recolour a sprite in place, which is how the cursor is tinted from
    /// a single white bracket set in the original.
    static let indexed: [UInt32] = [
        0xF8F8F8, 0xBCB7C5, 0x8D87A2, 0x50576B, 0x2E3740, 0x101E29,
        0x302C2E, 0x5A5353, 0x7D7071, 0xA0938E, 0xCFC6B8, 0xF4CCA1,
        0xEEA160, 0xBF7958, 0xA05B53, 0x7A444A, 0x5E3643, 0x472D3C,
        0x39314B, 0x64468D, 0x8E478C, 0xAE57A4, 0xEA71BD, 0xFFAEB6,
        0xFF8B9C, 0xE1534A, 0xA93B3B, 0xF47E1B, 0xF4B41B, 0xFFCE00,
        0xFBFCAA, 0xB6D53C, 0x71AA34, 0x3F7E00, 0x005F1B, 0x00635C,
        0x00A383, 0x3FC778, 0xA1EF79, 0xDFF6F5, 0x92F4FF, 0x42CAFD,
        0x3978A8, 0x243F72, 0x564064, 0x827094, 0x4F546B,
    ]

    /// The palette index of a packed colour, or `nil` if it is off-palette.
    ///
    /// Indices are 1-based, matching the original macros.
    static func index(of packed: UInt32) -> Int? {
        indexed.firstIndex(of: packed).map { $0 + 1 }
    }
}
