//
//  Palette.swift
//  Project Stars
//
//  Placeholder colours. Everything here is temporary art direction.
//

import SwiftUI

// MARK: - Color(hex:)

extension Color {
    /// Builds a colour from a packed `0xRRGGBB` literal.
    ///
    /// Used so the sign definitions can state their accent colour inline and
    /// stay readable.
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

// MARK: - Palette

/// The stand-in colour scheme.
///
/// Semantic names — what a colour is *for*. The colours themselves come from
/// the fixed 47-entry palette in `PaletteColors.swift`; anything here that still
/// spells out a hex literal is a placeholder standing in for art, and should end
/// up either replaced by a sprite or re-pointed at a palette entry.
enum Palette {

    // MARK: Chrome

    /// Behind everything.
    static let background = Color(hex: 0x0B0D18)

    /// The info/input half of the screen.
    static let panel = Color(hex: 0x141829)

    /// Hairlines and grid separators.
    static let outline = Color(hex: 0x2A3050)

    static let textPrimary = Color(hex: 0xE8ECFF)
    static let textSecondary = Color(hex: 0x8A93BF)

    // MARK: Planes

    /// Backdrop tint per plane. Astra reads cool and high, Terra warm and low.
    static func planeTint(_ plane: Plane) -> Color {
        switch plane {
        case .astra: Color(hex: 0x2B3A6B)
        case .terra: Color(hex: 0x4A3320)
        }
    }

    /// Which of the two alternating tones a square uses.
    ///
    /// The board is shaded like a chequerboard so the eye can count squares and
    /// judge distance at a glance. Kept subtle on purpose — it is a readability
    /// aid, not a second colour scheme competing with the wear states.
    enum TileShade {
        case light
        case dark

        /// Squares alternate by the parity of `x + y`, so no two orthogonal
        /// neighbours share a tone.
        static func at(_ point: GridPoint) -> TileShade {
            (point.x + point.y).isMultiple(of: 2) ? .light : .dark
        }

        /// How much to darken the face.
        ///
        /// This is the *only* thing separating one square from the next — there
        /// are no grid lines — so it carries a little more weight than a pure
        /// decorative chequer would. Still deliberately gentle; raise it here if
        /// the board ever reads as mushy.
        var darkening: Double {
            switch self {
            case .light: 0
            case .dark: 0.13
            }
        }
    }

    /// Tile face colour for a given wear state, plane, and alternating tone.
    static func tileFace(
        _ health: TileHealth,
        on plane: Plane,
        shade: TileShade = .light
    ) -> Color {
        let base = baseTileFace(health, on: plane)

        // Holes are voids, not surfaces — shading them would only muddy the one
        // state the player most needs to read instantly.
        guard !health.isHole else { return Color(hex: base) }

        return Color(hex: base.darkened(by: shade.darkening))
    }

    /// The unshaded face, as a packed hex so the alternating tone can be derived
    /// from it arithmetically rather than maintained as a second palette.
    private static func baseTileFace(_ health: TileHealth, on plane: Plane) -> UInt32 {
        switch (plane, health) {
        case (.astra, .healthy): 0x6E86D8
        case (.astra, .cracked): 0x56699F
        case (.astra, .badlyCracked): 0x3B4A73
        case (.astra, .hole): 0x0A0C14

        case (.terra, .healthy): 0xB0824A
        case (.terra, .cracked): 0x8A6539
        case (.terra, .badlyCracked): 0x5E4527
        case (.terra, .hole): 0x0A0C14
        }
    }

    /// Face of the Nexys island. Reads as carved stone against both planes.
    static let nexysFace = Color(hex: 0xD8CBA0)

    /// The island's rim, and the glow under it.
    static let nexysEdge = Color(hex: 0x8A7A4E)

    /// The gap the Nexys leaves behind — darker than an ordinary hole, because
    /// it is permanent and cannot be repaired.
    static let chasm = Color(hex: 0x05060B)

    // MARK: Cursor
    //
    // The destination cursor's colours *are* its meaning — see `CursorView`.

    /// Healthy ground, or the Nexys.
    static var cursorClear: Color { white }

    /// A cracked tile.
    static var cursorDamaged: Color { yellow }

    /// A badly cracked tile.
    static var cursorBadlyDamaged: Color { orange }

    /// A hole or the Nexys chasm — moving here drops the piece.
    static var cursorOpen: Color { red }

    /// Off the board. Deliberately faint: the move simply is not available.
    static let cursorImpossible = Color(hex: 0x9AA0BC, opacity: 0.35)

    /// The exclamation struck through an `open` cursor.
    static var cursorWarning: Color { yellow }

    // MARK: Gameplay elements

    /// The shimmer on candidate pickup tiles.
    static let sparkle = Color(hex: 0xFFE7A3)

    /// The Pentacle coin's face.
    static let pentacle = Color(hex: 0xE8B23C)

    /// Highlight on the coin, for the struck-metal sheen.
    static let pentacleHighlight = Color(hex: 0xFFE9A8)

    /// The coin's rim and the star struck into it.
    static let pentacleEdge = Color(hex: 0x8A5F16)

    /// Shadow Work's coin: desaturated and dark.
    static let pentacleShadow = Color(hex: 0x4A4459)
    static let pentacleShadowHighlight = Color(hex: 0x7A7290)
    static let pentacleShadowEdge = Color(hex: 0x241F2E)

    /// Polaris' coin: starlit.
    static let pentacleRadiant = Color(hex: 0xCFE4FF)
    static let pentacleRadiantHighlight = Color(hex: 0xFFFFFF)

    // MARK: Pentacles

    /// The five palette entries the gold coin is drawn in, brightest first.
    ///
    /// Read from the sprite rather than guessed — these are exactly what is in
    /// `Pentacle.png`.
    static let pentacleTones: [Color] = [white, yellowGreen, yellow, gold, orange]

    /// Shadow Work's coin: the same five entries, swapped one for one.
    ///
    /// Ordered to match `pentacleTones`, so the two lists zip into the swap.
    static let pentacleShadowTones: [Color] = [midnight, steel, navy, dusk, smoke]

    /// Entries that bloom on the gold coin.
    static let pentacleGlowTones: [Color] = [white, yellowGreen, yellow]

    /// Polaris' sparks.
    static let polarisSparkTones: [Color] = [yellow, pink, lightBlue]

    /// Rarity tints, used wherever a tier needs to read before the words do.
    static let pickupUncommon = Color(hex: 0x6FD4A8)
    static let pickupRare = Color(hex: 0x8FA8F0)
    static let pickupLegendary = Color(hex: 0xE8B23C)

    /// The drop shadow under pieces and coins.
    ///
    /// Exactly `midnight` — the palette already had the right colour for this.
    static var shadow: Color { midnight }

    /// Smoke kicked up by a landing.
    static var smokePuff: Color { smoke }

    /// Warning colour for the game-over state.
    static var danger: Color { red }
}

// MARK: - Shading

private extension UInt32 {
    /// This packed `0xRRGGBB` colour, mixed toward black by `amount` (0…1).
    ///
    /// Channel-wise so both board tones stay derived from a single source
    /// colour: change the tile palette and the alternation follows automatically.
    func darkened(by amount: Double) -> UInt32 {
        guard amount > 0 else { return self }
        // `Swift.` qualified: inside an extension on `UInt32`, bare `min`/`max`
        // resolve to that type's own static bounds rather than the free
        // functions.
        let factor = 1 - Swift.min(Swift.max(amount, 0), 1)

        func scale(_ shift: UInt32) -> UInt32 {
            let channel = Double((self >> shift) & 0xFF)
            return UInt32((channel * factor).rounded()) << shift
        }

        return scale(16) | scale(8) | scale(0)
    }
}
