//
//  Zodiac.swift
//  Project Stars
//
//  The twelve signs, as an identity only. Behaviour lives in Zodiac/Signs/.
//

import Foundation

/// The twelve playable pieces.
///
/// This enum is *just the name*. Everything that makes a sign play differently —
/// movement, passive, super, art, colour — lives in its own file under
/// `Zodiac/Signs/` and is reached through `definition`. That keeps this file
/// stable while the per-sign design churns.
enum Zodiac: String, CaseIterable, Codable, Identifiable, Hashable {
    case aries
    case taurus
    case gemini
    case cancer
    case leo
    case virgo
    case libra
    case scorpio
    case sagittarius
    case capricorn
    case aquarius
    case pisces

    var id: String { rawValue }

    /// The sign's full behaviour and presentation record.
    ///
    /// Defined per-sign in `Zodiac/Signs/<Name>.swift`; the switch below is the
    /// only place the two halves are joined.
    var definition: ZodiacDefinition {
        switch self {
        case .aries: ZodiacCatalog.aries
        case .taurus: ZodiacCatalog.taurus
        case .gemini: ZodiacCatalog.gemini
        case .cancer: ZodiacCatalog.cancer
        case .leo: ZodiacCatalog.leo
        case .virgo: ZodiacCatalog.virgo
        case .libra: ZodiacCatalog.libra
        case .scorpio: ZodiacCatalog.scorpio
        case .sagittarius: ZodiacCatalog.sagittarius
        case .capricorn: ZodiacCatalog.capricorn
        case .aquarius: ZodiacCatalog.aquarius
        case .pisces: ZodiacCatalog.pisces
        }
    }

    // MARK: Convenience passthroughs

    var displayName: String { definition.displayName }
    var glyph: String { definition.glyph }
    var element: ZodiacElement { definition.element }
    var movement: MovementPattern { definition.movement }
    var passives: [any ZodiacPassive] { definition.passives }
    var zodiaction: any Zodiaction { definition.zodiaction }
}

// MARK: - Element

/// Classical element grouping, and the plane it favours.
///
/// The elements are not decoration: they decide which plane a sign is stronger
/// on, which every passive and Zodiaction is expected to key off.
enum ZodiacElement: String, CaseIterable, Codable {
    case fire
    case earth
    case air
    case water

    var displayName: String { rawValue.capitalized }

    /// The plane this element is stronger on.
    ///
    /// Fire and earth are grounded and favour **Terra**; air and water are
    /// elevated and favour **Astra**. This is the general rule — an individual
    /// sign is free to break it inside its own passive or super, but it should
    /// be a deliberate, documented exception rather than an accident.
    var empoweredPlane: Plane {
        switch self {
        case .fire, .earth: .terra
        case .air, .water: .astra
        }
    }

    /// The plane this element is weaker on.
    var diminishedPlane: Plane { empoweredPlane.opposite }
}

// MARK: - Catalog

/// Namespace holding the twelve `ZodiacDefinition` values.
///
/// Each sign extends this enum from its own file, so adding or editing a sign
/// means touching exactly one file.
enum ZodiacCatalog {
    /// All twelve definitions, in zodiacal order.
    static var all: [ZodiacDefinition] { Zodiac.allCases.map(\.definition) }
}
