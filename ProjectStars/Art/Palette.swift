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
        case .astra: darkBlue
        case .terra: plum
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

    // MARK: - Healing

    /// The ramps a mended square runs through, in order.
    ///
    /// Every light entry in the palette bar `cream`, which is the one that reads
    /// as *dirty* light rather than bright — it is the parchment tone the earthen
    /// ramp is built on, and it lands as a stain in the middle of a flash that is
    /// supposed to be a burst of health.
    ///
    /// Each is a **three-shade ramp**, lightest first, rather than a single
    /// colour. A cloud is drawn in four tones and a flat tint would iron it into
    /// a silhouette; swapping one ramp for another keeps every fold in it and
    /// moves only the hue.
    ///
    /// Running the whole set is the point. Motes alone were too small an event
    /// for the thing they mark: repair is rare, it is the only good news the
    /// board ever gives, and a square that riffles through every colour it could
    /// possibly be is unmistakable from across the screen.
    static let healFlashRamps: [[Color]] = [
        [white, lightGray, gray],
        [ice, cyan, lightBlue],
        [cyan, lightBlue, blue],
        [grass, lime, green],
        [yellowGreen, lime, darkGreen],
        [sakura, blush, red],
        [blush, red, darkRed],
        [lightBlue, blue, darkBlue],
        [lightGray, gray, darkGray],
    ]

    /// The ramp a square mended `elapsed` ago should be wearing, and how hard,
    /// or `nil` once the flash is over.
    ///
    /// Stepped rather than blended: this is pixel art, and interpolating between
    /// palette entries spends most of its time on colours that are not in the
    /// palette at all.
    static func healFlash(elapsed: TimeInterval) -> (ramp: [Color], strength: Double)? {
        guard elapsed >= 0, elapsed < GameRules.healFlashDuration else { return nil }

        let progress = elapsed / GameRules.healFlashDuration
        let step = min(Int(progress * Double(healFlashRamps.count)), healFlashRamps.count - 1)

        // Fades out across the run, so the square settles into its own colour
        // rather than snapping back to it.
        return (healFlashRamps[step], GameRules.healFlashStrength * (1 - progress))
    }

    // MARK: Gameplay elements

    /// The shimmer on candidate pickup tiles.
    ///
    /// The hot centre of a glow-phase sparkle.
    ///
    /// White on both planes, and it has to be a *separate* colour from the
    /// bloom around it rather than the same one stacked up. Additive layers of
    /// an already-pale tint clamp to white everywhere, including the outside —
    /// which reads as a white blob rather than as a coloured light with a hot
    /// core. Light works the other way round: white in the middle, its colour
    /// showing where it is thinnest.
    static var sparkleCore: Color { white }

    /// The bloom around it.
    ///
    /// Per plane: gold sits on Terra's earth the way a glint of treasure should,
    /// but on Astra it competes with the gold already flecked through every
    /// cloud. Blue reads as something the plane is doing rather than as more of
    /// the same.
    ///
    /// Saturated on purpose — the pale entries wash out the moment anything is
    /// added on top of them.
    static func sparkleGlow(on plane: Plane) -> Color {
        switch plane {
        case .astra: lightBlue
        case .terra: gold
        }
    }

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

    // MARK: Astra clouds

    /// The tones one cloud is shaded with on a lit square, crown first.
    ///
    /// Astral rather than meteorological: these are not weather, they are the
    /// stuff Astra is made of, and the plane is named for the stars. Kept in the
    /// same cool family Polaris' sparks live in so the two read as one world.
    ///
    /// Flat steps rather than a gradient: the clouds are meant to read as
    /// cel-shaded volumes, and a gradient across a 16px cell would just look
    /// like mud.
    static let cloudLight: [Color] = [pink, magenta, purple]

    /// The same cloud on the board's darker squares.
    ///
    /// A full step down the magenta run each, not a half one. The chequer has to
    /// read as lighting rather than as two kinds of cloud, but it is also the
    /// *only* thing separating one square from the next — there are no grid
    /// lines — so tones a shade apart left the board mush.
    static let cloudDark: [Color] = [darkMagenta, purple, dusk]

    /// The flecks of light scattered through the cloudstuff.
    ///
    /// The two entries that are *not* in the magenta run, so they read as
    /// something caught in the cloud rather than as more of it. Same pairing
    /// Polaris' sparks use.
    static let cloudSpeckleTones: [Color] = [lightBlue, yellow]

    /// The same flecks on a raised cloud.
    ///
    /// Blue on blue is invisible, so the pairing inverts: magenta takes the
    /// place the pale blue holds everywhere else. Gold works against both and
    /// stays put.
    static let cloudRaisedSpeckleTones: [Color] = [magenta, yellow]

    static func speckleTones(raised: Bool) -> [Color] {
        raised ? cloudRaisedSpeckleTones : cloudSpeckleTones
    }

    /// The cloud a Pentacle is sitting on.
    ///
    /// Lifting a cluster four pixels is not enough on its own — a raised cloud
    /// against neighbouring clouds is still just cloud, and the pop is the one
    /// thing on the board that has to be readable at a glance. Pale blues down to a
    /// deep one: far enough from either chequer tone to be unmistakable, close
    /// enough to still belong to Astra.
    static let cloudRaised: [Color] = [cyan, lightBlue, darkBlue]

    /// The route each layer takes from its resting tone to its raised one.
    ///
    /// ## Why a ramp and not a crossfade
    ///
    /// Interpolating two colours continuously produces values that are not in
    /// the 47-entry palette — for most of the transition the cloud would be
    /// wearing colours this game does not own. Stepping through real entries
    /// instead keeps every frame legal, and at 16 pixels a three-step ramp over
    /// a quarter second reads as smooth anyway. It is also how the transition
    /// would have been drawn by hand.
    ///
    /// Layer counts differ on purpose: the layers arrive slightly out of step,
    /// which sells the change better than all three flipping together.
    static func cloudRaiseRamp(_ shade: TileShade) -> [[Color]] {
        switch shade {
        case .light: [
            [pink, lightBlue, cyan],
            [magenta, blue, lightBlue],
            [purple, navy, darkBlue],
        ]
        case .dark: [
            [darkMagenta, magenta, lightBlue, cyan],
            [purple, blue, lightBlue],
            [dusk, navy, darkBlue],
        ]
        }
    }

    /// This cloud's three layer tones, `raiseBlend` of the way along the ramp.
    ///
    /// `0` is a resting cloud and `1` a fully raised one; the ends of the ramps
    /// are exactly `cloudLight`/`cloudDark` and `cloudRaised`.
    static func cloudTones(_ shade: TileShade, raiseBlend: Double = 0) -> [Color] {
        // The overwhelmingly common cases, and worth taking early: every cloud
        // but one is resting, and this runs per layer per cloud per frame.
        if raiseBlend <= 0 { return shade == .light ? cloudLight : cloudDark }
        if raiseBlend >= 1 { return cloudRaised }

        return cloudRaiseRamp(shade).map { ramp in
            let travelled = min(max(raiseBlend, 0), 1)

            guard !GameRules.cloudRaiseSteps else {
                let step = Int(travelled * Double(ramp.count))
                return ramp[min(step, ramp.count - 1)]
            }

            // Continuous: slide along the same ramp, mixing between whichever
            // two entries the blend currently falls between. Still follows the
            // authored route rather than cutting straight across colour space,
            // which is what keeps magenta from passing through grey on its way
            // to blue.
            let position = travelled * Double(ramp.count - 1)
            let lower = min(Int(position), ramp.count - 1)
            let upper = min(lower + 1, ramp.count - 1)

            return mix(ramp[lower], ramp[upper], amount: position - Double(lower))
        }
    }

    /// Two colours blended in sRGB.
    ///
    /// Only used by the continuous cloud ramp — everything else in this game
    /// picks palette entries rather than computing colours.
    static func mix(_ from: Color, _ to: Color, amount: Double) -> Color {
        let a = from.shaderComponents
        let b = to.shaderComponents
        guard a.count >= 3, b.count >= 3 else { return to }

        func blend(_ index: Int) -> Double {
            let start = Double(a[index]), end = Double(b[index])
            return start + (end - start) * amount
        }

        return Color(.sRGB, red: blend(0), green: blend(1), blue: blend(2), opacity: 1)
    }

    // MARK: Pieces

    /// The gold form's entries, as drawn in the sheet.
    ///
    /// Sampled from the Pisces sprite, not guessed. The gem entry is
    /// deliberately absent — it must survive into the stone form untouched.
    static let pieceGoldTones: [Color] = [gold, brown, plum, midnight]

    /// The stone form's entries, in the same order.
    ///
    /// Taken from the hand-drawn stone variant, so the generated form matches
    /// the one piece that was drawn both ways.
    static let pieceStoneTones: [Color] = [slate, stone, iron, warmBlack]

    /// The piece redrawn in an element's own colours.
    ///
    /// ## Why a swap and not a blend
    ///
    /// `.blendMode(.color)` takes hue and saturation from the wash but
    /// *luminosity from the sprite underneath* — so a gold piece washed cyan
    /// comes out a mid-tone cyan, every tone landing near the lightness the gold
    /// already had. That is precisely the "not enough contrast" of it: the wash
    /// cannot make anything brighter or darker than what it covers.
    ///
    /// Swapping the entries instead gives the element's full range — its bright
    /// on the gold, its mid on the brown, its deep on the plum — which is how
    /// the stone form is already built, and how pixel art is recoloured
    /// generally.
    ///
    /// `midnight` is deliberately absent: the darkest entry is the outline, and
    /// an outline that changes colour stops reading as an outline.
    static func pieceTones(for element: ZodiacElement) -> [Color] {
        let ramp = ElementFX.ramp(for: element)
        return [ramp.bright, ramp.mid, ramp.deep]
    }

    /// The same idea for an afterimage, skewed light.
    ///
    /// A ghost drawn in the full range comes out muddy: it is already faded, and
    /// an element's `deep` under that reads as a dark smudge rather than as a
    /// colour. Two brights and a mid keeps it legible at low opacity.
    static func trailTones(for element: ZodiacElement) -> [Color] {
        let ramp = ElementFX.ramp(for: element)
        return [ramp.bright, ramp.bright, ramp.mid]
    }

    /// The greens moss is drawn from.
    ///
    /// Three of them, because one flat green reads as paint. `forest` is
    /// deliberately not here — it is the earth signs' gem.
    static let mossTones: [Color] = [green, darkGreen, turqoise]

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

    /// The colours a lightning strike cycles through, one per frame.
    ///
    /// Bright is what replaces the white in the art; dark replaces the blue, and
    /// is the next entry down the palette in every case — which is what keeps a
    /// recoloured frame reading as the same drawing rather than as four
    /// different ones.
    ///
    /// Indices 24, 25, 32 and 41: sakura, blush, lime, cyan. Nothing is attuned
    /// to lightning, so it wears no element's ramp — it borrows a colour from
    /// across the palette instead, which is why the set looks arbitrary and is
    /// not.
    static let strikeCycle: [(bright: Color, dark: Color)] = [
        (sakura, blush),    // 24 → 25
        (blush, red),       // 25 → 26
        (lime, green),      // 32 → 33
        (cyan, lightBlue),  // 41 → 42
    ]

    /// Polaris' sparks.
    static let polarisSparkTones: [Color] = [yellow, pink, lightBlue]

    /// The gavel's own light: the golds it is drawn in, plus the sky it belongs
    /// to. Libra is an air sign and the hammer is a storm front, not a coin.
    static let gavelGlowTones: [Color] = [white, cyan, lightBlue, gold]

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

    /// Astra's version: not dust but disturbed cloudstuff, in the same tones the
    /// plane is built from plus the gold that runs through it.
    static let astraSmokeTones: [Color] = [magenta, yellow, lightBlue, pink, cyan]

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
