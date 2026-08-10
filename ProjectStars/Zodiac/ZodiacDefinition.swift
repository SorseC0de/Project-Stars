//
//  ZodiacDefinition.swift
//  Project Stars
//
//  The record that describes one sign completely.
//

import SwiftUI

/// Everything the game needs to know about a single zodiac piece.
///
/// One of these is declared per sign in `Zodiac/Signs/`. It is plain data plus a
/// passive and a super, which means a sign can be reviewed, diffed, and balanced
/// without reading any engine code.
struct ZodiacDefinition: Identifiable {

    // MARK: Identity

    /// Which sign this describes.
    let sign: Zodiac

    /// Name shown in the UI.
    let displayName: String

    /// Astrological glyph, used as the stand-in sprite until pixel art lands.
    let glyph: String

    /// Classical element grouping. Determines which plane the sign is stronger
    /// on — see `ZodiacElement.empoweredPlane`.
    let element: ZodiacElement

    var id: Zodiac { sign }

    // MARK: Behaviour

    /// How the piece hops.
    ///
    /// All twelve are `.cardinalStep` for now — single-tile orthogonal moves.
    /// Per-sign movement is a later pass; swap this value and nothing else
    /// needs to change.
    let movement: MovementPattern

    /// The sign's always-on abilities — **two or three per sign**, combined by
    /// the rules in `Array<any ZodiacPassive>`. All vary by plane.
    let passives: [any ZodiacPassive]

    /// The sign's charged, player-fired ability, and how its meter builds.
    /// Also varies by plane.
    let zodiaction: any Zodiaction

    // MARK: Presentation

    /// Stand-in colour for the piece sprite, and the sign's accent throughout
    /// the UI. Stays useful after real art arrives (HUD tint, meter, particles).
    let accentColor: Color

    /// The sprite this piece draws. Resolved through `SpriteID` so a missing
    /// asset falls back to the glyph placeholder automatically.
    var spriteID: SpriteID { .piece(sign) }

    /// The plane this sign is stronger on.
    var empoweredPlane: Plane { element.empoweredPlane }

    // MARK: Init

    /// - Parameters:
    ///   - movement: Defaults to a single orthogonal step, the current
    ///     behaviour for every sign.
    ///   - passives: Two or three. Defaults to a single no-op placeholder.
    ///   - zodiaction: Defaults to the flat-charge placeholder.
    init(
        sign: Zodiac,
        displayName: String,
        glyph: String,
        element: ZodiacElement,
        accentColor: Color,
        movement: MovementPattern = .cardinalStep,
        passives: [any ZodiacPassive] = [PlaceholderPassive()],
        zodiaction: any Zodiaction = PlaceholderZodiaction()
    ) {
        self.sign = sign
        self.displayName = displayName
        self.glyph = glyph
        self.element = element
        self.accentColor = accentColor
        self.movement = movement
        self.passives = passives
        self.zodiaction = zodiaction
    }
}
