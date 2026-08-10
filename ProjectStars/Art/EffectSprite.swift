//
//  EffectSprite.swift
//  Project Stars
//
//  The imported effect animations, and what each one is for.
//

import Foundation

/// A drawn effect animation: one horizontal strip, one frame per cell.
///
/// ## Why these are their own type
///
/// Everything else in `SpriteID` is a *thing* — a tile, a piece, a coin — and
/// lives on the 16px master sheet. These are events: they play once, they are
/// 64px, and each arrives as its own strip. Giving them their own enum keeps
/// `SpriteAtlas`'s cell arithmetic honest and means an effect can be added
/// without touching the board's art at all.
///
/// ## Naming
///
/// The asset catalog namespaces them by element (`Fire/`, `Water/`), so the
/// element is not repeated in the name. `folder` and `file` here reproduce that
/// path exactly — get it wrong and the sprite silently falls back to a
/// placeholder rather than failing the build, which is the one downside of
/// string-addressed assets.
///
/// ## Frame counts
///
/// Read from the sheets, not guessed: every strip is 64px tall and a whole
/// number of 64px frames wide.
enum EffectSprite: String, CaseIterable, Hashable {

    // MARK: Fire

    /// Aries' Zodiaction. 8 frames.
    case ariesZodiaction

    /// The Pentacle, not a sign. 10 frames.
    case astralBlaze

    /// Leo's landing passive. 11 frames.
    case leoPridefulLanding

    /// Leo's Zodiaction, in two variants and a summon. 22 / 22 / 9 frames.
    case leoZodiactionOne
    case leoZodiactionTwo
    case leoZodiactionSummon

    /// Unassigned fire, kept for whatever wants it. 9 frames.
    case fireMisc

    /// Sagittarius' long jump. 8 frames.
    case sagittariusJump

    // MARK: Water

    /// Cancer's Zodiaction — Astral Bastion — and its alternate. 22 frames each.
    case cancerZodiaction
    case cancerZodiactionAlternate

    /// Libra's Zodiaction. 22 frames.
    case libraZodiaction

    // MARK: - Where the art is

    /// Which element folder in the asset catalog it lives in.
    var element: ZodiacElement {
        switch self {
        case .ariesZodiaction, .astralBlaze, .leoPridefulLanding,
             .leoZodiactionOne, .leoZodiactionTwo, .leoZodiactionSummon,
             .fireMisc, .sagittariusJump:
            .fire
        case .cancerZodiaction, .cancerZodiactionAlternate, .libraZodiaction:
            .water
        }
    }

    /// The image set's name inside its element folder.
    var file: String {
        switch self {
        case .ariesZodiaction: "aries_zaction"
        case .astralBlaze: "astralblaze"
        case .leoPridefulLanding: "leo_pridefullanding"
        case .leoZodiactionOne: "leo_zaction1"
        case .leoZodiactionTwo: "leo_zaction2"
        case .leoZodiactionSummon: "leo_zaction_summon"
        case .fireMisc: "misc"
        case .sagittariusJump: "sagittarius_jump"
        case .cancerZodiaction: "cancer_zaction"
        case .cancerZodiactionAlternate: "cancer_zaction_v2"
        case .libraZodiaction: "libra_zaction"
        }
    }

    /// The namespaced asset path. The element folders provide a namespace, so
    /// `Fire/misc` and a future `Water/misc` cannot collide.
    var assetName: String {
        "\(element.folderName)/\(file)"
    }

    // MARK: - How it plays

    /// How many frames the strip holds.
    var frames: Int {
        switch self {
        case .ariesZodiaction, .sagittariusJump: 8
        case .fireMisc, .leoZodiactionSummon: 9
        case .astralBlaze: 10
        case .leoPridefulLanding: 11
        case .leoZodiactionOne, .leoZodiactionTwo,
             .cancerZodiaction, .cancerZodiactionAlternate, .libraZodiaction: 22
        }
    }

    /// The rate it plays at.
    ///
    /// The long strips run at the top of the range on purpose: 22 frames at 12fps
    /// is nearly two seconds, which is far longer than the move it is decorating
    /// and would leave the effect still playing while the player takes their
    /// next turn. At 24 it lands just under a second.
    var rate: SpriteRate {
        frames >= 20 ? .fps24 : .fps15
    }

    /// How long one play-through takes.
    var duration: TimeInterval { rate.duration(frames: frames) }

    /// The effect that belongs to a sign's Zodiaction, if one has been drawn.
    ///
    /// The lookup rather than a switch at the call site: one place decides which
    /// sign owns which strip, and the eight signs with nothing drawn yet simply
    /// return `nil` and keep their programmatic burst.
    /// The effect that belongs to a Pentacle, if one has been drawn.
    ///
    /// Only Astral Blaze so far. The other three Essences keep the shader burst
    /// until strips arrive for them.
    static func pickup(for id: PickupID) -> EffectSprite? {
        switch id {
        case .astralBlaze: .astralBlaze
        default: nil
        }
    }

    static func zodiaction(for zodiac: Zodiac) -> EffectSprite? {
        switch zodiac {
        case .aries: .ariesZodiaction
        case .leo: .leoZodiactionOne
        case .cancer: .cancerZodiaction
        case .libra: .libraZodiaction
        default: nil
        }
    }
}

// MARK: - Element folders

extension ZodiacElement {
    /// The asset-catalog folder this element's effects live in.
    var folderName: String {
        switch self {
        case .fire: "Fire"
        case .water: "Water"
        case .earth: "Earth"
        case .air: "Air"
        }
    }
}
