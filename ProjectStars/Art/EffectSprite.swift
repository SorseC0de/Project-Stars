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
        switch self {
        // The Bastion is two layers of the same bubble, and the lower one runs
        // slower on purpose: two identical strips in lockstep read as one
        // doubled-up drawing, while a beat between them reads as depth.
        case .cancerZodiaction: .fps15
        default: frames >= 20 ? .fps24 : .fps15
        }
    }

    /// How far this strip rides up from the middle of its square, in art
    /// pixels.
    ///
    /// A strip is a square of art centred on a square of board, which puts its
    /// middle at the middle of the tile. That is right for something hanging
    /// over the square — a sun, a burst overhead — and wrong for anything
    /// sitting on the floor, which wants its *base* on the tile.
    ///
    /// A number rather than a flag, because "on the ground" is not one height:
    /// each of these was drawn with its own idea of where the floor is inside
    /// its 64px frame, and there is nothing in the pixels that says so.
    var groundLift: CGFloat {
        switch self {
        case .ariesZodiaction, .astralBlaze, .sagittariusJump: 8
        case .fireMisc: 6
        case .cancerZodiaction, .cancerZodiactionAlternate: 4
        case .leoPridefulLanding: 0
        case .leoZodiactionOne, .leoZodiactionTwo, .leoZodiactionSummon,
             .libraZodiaction: 0
        }
    }

    /// True for anything that sits on the floor rather than hanging over it.
    /// Presentation only — the gallery labels with it.
    var isGrounded: Bool { groundLift > 0 }

    /// How brightly this strip blooms.
    ///
    /// Per element, because the art is lit differently: the water strips carry
    /// their own glow and only need a little help, while the fire ones are drawn
    /// flatter and need considerably more before they read as giving off light
    /// rather than as being a picture of fire.
    var glowIntensity: Double {
        switch element {
        case .fire: GameRules.effectGlowFireIntensity
        default: GameRules.effectGlowIntensity
        }
    }

    /// How long one play-through takes.
    var duration: TimeInterval { rate.duration(frames: frames) }

    /// How wide it is drawn, in tiles.
    ///
    /// Per-effect rather than one global size: these were authored by different
    /// hands at different scales, and a strip that reads as a burst covering
    /// three squares is a different thing from one meant to sit on a single
    /// tile. Defaults to `GameRules.effectSpan`.
    var span: CGFloat {
        switch self {
        default: GameRules.effectSpan
        }
    }

    /// The strip Aries' Blaze Path leaves on each square it burns.
    ///
    /// Not in `zodiaction(for:)` on purpose. Blaze Path does not happen where
    /// the piece is standing when it fires — it happens over the next five
    /// moves, on each tile the ram walks off. Playing it at the pop would be
    /// showing the fire in the one place it is not.
    static let blazeTrail = EffectSprite.ariesZodiaction

    /// The strip a sign throws when its meter gains, if one has been drawn.
    static func chargeGain(for zodiac: Zodiac) -> EffectSprite? {
        switch zodiac {
        case .aries: .fireMisc
        default: nil
        }
    }

    /// The two strips that make up Leo's sun, drawn stacked.
    static let leoSun: [EffectSprite] = [.leoZodiactionOne, .leoZodiactionTwo]

    /// The two strips that make up Cancer's Bastion, bottom first.
    ///
    /// The lower one also runs slower — see `rate`.
    static let cancerBastion: [EffectSprite] = [.cancerZodiaction, .cancerZodiactionAlternate]

    /// The strip a sign throws on a hard landing, *instead of* the dust.
    static func landing(for zodiac: Zodiac) -> EffectSprite? {
        switch zodiac {
        case .leo: .leoPridefulLanding
        default: nil
        }
    }

    /// The strip a sign throws when it clears ground in a single bound.
    static func longJump(for zodiac: Zodiac) -> EffectSprite? {
        switch zodiac {
        case .sagittarius: .sagittariusJump
        default: nil
        }
    }

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

    /// The effect that belongs to a sign's Zodiaction, if one has been drawn.
    ///
    /// A lookup rather than a switch at the call site: one place decides which
    /// sign owns which strip, and the eight signs with nothing drawn yet simply
    /// return `nil` and keep their programmatic burst.
    /// The strips a sign's Zodiaction throws where it fires, bottom layer
    /// first.
    ///
    /// A stack rather than one strip: several of these were authored as layers
    /// meant to be composited, and drawing them singly is not what they are.
    static func zodiaction(for zodiac: Zodiac) -> [EffectSprite] {
        switch zodiac {
        // Aries is deliberately absent — see `blazeTrail`.
        // Leo is too — its Zodiaction is a summon followed by the stacked sun,
        // which `GameSession.raiseTheSun` sequences.
        case .cancer: cancerBastion
        case .libra: [.libraZodiaction]
        default: []
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
