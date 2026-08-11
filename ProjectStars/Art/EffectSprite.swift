//
//  EffectSprite.swift
//  Project Stars
//
//  The imported effect animations, and what each one is for.
//

import SwiftUI

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

    /// Unassigned. 28 frames, 96px — a dark plume with fire at its heart.
    case explosion

    // MARK: Astral

    /// The Astral Bolt's strike, in four variants. 10 frames each, 64x160.
    ///
    /// Four rather than one because it is the rarest thing in the game: a player
    /// who sees it twice in a year should not see the same drawing twice.
    case lightning1
    case lightning2
    case lightning3
    case lightning4

    // MARK: Earth

    /// The Pentacle, not a sign. 16 frames.
    case astralBloom

    // MARK: Water

    /// The bubbles Cancer's seafoam scuttle kicks up. 16 frames.
    case crabWalk

    /// Unassigned. 10 frames, 48px.
    case waterSplash

    /// Cancer's Zodiaction — Bubble Bastion — and its alternate. 22 frames each.
    case cancerZodiaction
    case cancerZodiactionAlternate

    /// Libra's Zodiaction. 22 frames.
    case libraZodiaction

    // MARK: - Where the art is

    /// Which element this belongs to, or `nil` for the ones outside the wheel.
    ///
    /// Lightning is the fifth Essence and no sign is attuned to it, so it has no
    /// element and lives in its own folder — see `folder`.
    var element: ZodiacElement? {
        if Self.lightning.contains(self) { return nil }
        return elementalFamily
    }

    /// The asset-catalog folder this strip lives in.
    var folder: String {
        element?.folderName ?? "Astral"
    }

    private var elementalFamily: ZodiacElement {
        switch self {
        case .ariesZodiaction, .astralBlaze, .leoPridefulLanding,
             .leoZodiactionOne, .leoZodiactionTwo, .leoZodiactionSummon,
             .fireMisc, .sagittariusJump, .explosion:
            .fire
        case .cancerZodiaction, .cancerZodiactionAlternate, .libraZodiaction,
             .crabWalk, .waterSplash:
            .water
        case .astralBloom:
            .earth
        case .lightning1, .lightning2, .lightning3, .lightning4:
            .air  // Unreachable: `element` short-circuits lightning to nil.
        }
    }

    /// The image set's name inside its element folder.
    var file: String {
        switch self {
        case .ariesZodiaction: "aries_zaction"
        case .astralBlaze: "astralblaze"
        case .lightning1: "lightning1"
        case .lightning2: "lightning2"
        case .lightning3: "lightning3"
        case .lightning4: "lightning4"
        case .explosion: "explosion"
        case .crabWalk: "crabwalk"
        case .waterSplash: "splash"
        case .astralBloom: "astralbloom"
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
        "\(folder)/\(file)"
    }

    // MARK: - How it plays

    /// The native size of one frame, in pixels.
    ///
    /// Not all of these are 64: the strips come from different sources and were
    /// authored at whatever size suited them. Keeping the real number means the
    /// atlas slices correctly and the bloom is measured in the art's own units,
    /// rather than everything being forced onto one grid it was never drawn on.
    var frameSize: CGSize {
        switch self {
        case .explosion: CGSize(width: 96, height: 96)
        case .waterSplash: CGSize(width: 48, height: 48)
        // Tall and narrow: a bolt reaches from the sky to the ground, and its
        // frame is the only one here that is not square.
        case .lightning1, .lightning2, .lightning3, .lightning4:
            CGSize(width: 64, height: 160)
        default: CGSize(
            width: GameRules.effectPixelSize,
            height: GameRules.effectPixelSize
        )
        }
    }

    /// How many frames the strip holds.
    var frames: Int {
        switch self {
        case .ariesZodiaction, .sagittariusJump: 8
        case .fireMisc, .leoZodiactionSummon: 9
        case .astralBlaze, .waterSplash,
             .lightning1, .lightning2, .lightning3, .lightning4: 10
        case .crabWalk: 16
        case .explosion: 28
        case .astralBloom: 16
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
        // The Essence plumes are the whole story of what a coin just did to the
        // board, and at 15fps they were over before the eye found them.
        case .astralBlaze, .astralBloom: .fps12
        // Long strips of dissipating smoke: at 15 the tail crawls.
        case .explosion: .fps20
        case .crabWalk, .waterSplash: .fps15
        // Tuned from `GameRules` — see the note there.
        case .lightning1, .lightning2, .lightning3, .lightning4: GameRules.lightningRate
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
        case .cancerZodiaction, .cancerZodiactionAlternate: 2
        case .explosion, .crabWalk, .waterSplash: 4
        // The bolt comes down *onto* the square, so its foot sits on the tile
        // and the rest of it towers overhead. Tuned from `GameRules`.
        case .lightning1, .lightning2, .lightning3, .lightning4: GameRules.lightningLift
        case .leoPridefulLanding: 0
        // Authored centred, so it needs no lift at all.
        case .astralBloom: 0
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
        // Lightning is the brightest thing in the game by a distance.
        case .none: GameRules.effectGlowFireIntensity
        default: GameRules.effectGlowIntensity
        }
    }

    /// How long one play-through takes.
    var duration: TimeInterval { rate.duration(frames: frames) }

    /// The two colours in the source art this strip is recoloured *from*, if it
    /// is recoloured at all.
    ///
    /// Some art arrives in one palette and has to be played in another. Rather
    /// than baking four copies of a sheet, the frame is swapped at draw time —
    /// see `EffectSpriteView` — which also allows the colour to change *per
    /// frame*, which no amount of pre-baking would.
    ///
    /// - Note: These are the colours as they appear in the file, and have to be
    ///   sampled from it rather than guessed. Left `nil`, the strip draws
    ///   exactly as drawn.
    var sourceTones: (light: Color, dark: Color)? {
        switch self {
        // Sampled from the files: these strips are drawn in exactly two
        // colours, neither of them on the palette.
        case .lightning1, .lightning2, .lightning3, .lightning4:
            (Color(hex: 0xF1F6F0), Color(hex: 0x92C7F0))
        default: nil
        }
    }

    /// The palette pairs this strip cycles through, a frame at a time.
    ///
    /// Only meaningful alongside `sourceTones`.
    var recolourCycle: [(bright: Color, dark: Color)] {
        switch self {
        case .lightning1, .lightning2, .lightning3, .lightning4: Palette.strikeCycle
        default: []
        }
    }

    /// How wide it is drawn, in tiles.
    ///
    /// Per-effect rather than one global size: these were authored by different
    /// hands at different scales, and a strip that reads as a burst covering
    /// three squares is a different thing from one meant to sit on a single
    /// tile. Defaults to `GameRules.effectSpan`.
    var span: CGFloat {
        switch self {
        // Drawn at 96px against everything else's 64, and an explosion should
        // look like one.
        case .explosion: 2.4
        // Native size put a bolt across most of the board, which read as
        // scenery rather than as a strike. Tuned from `GameRules`.
        case .lightning1, .lightning2, .lightning3, .lightning4: GameRules.lightningSpan
        // Under the piece's feet, not around it.
        case .crabWalk: 1.2
        case .waterSplash: 1.0
        default: GameRules.effectSpan
        }
    }

    /// The strip Aries' Brazen Blaze leaves on each square it burns.
    ///
    /// Not in `zodiaction(for:)` on purpose. Brazen Blaze does not happen where
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

    /// The four strike variants.
    static let lightning: [EffectSprite] = [
        .lightning1, .lightning2, .lightning3, .lightning4,
    ]

    /// The two strips that make up Leo's sun, drawn stacked.
    static let leoSun: [EffectSprite] = [.leoZodiactionOne, .leoZodiactionTwo]

    /// The two strips that make up Cancer's Bastion, bottom first.
    ///
    /// The lower one also runs slower — see `rate`.
    static let cancerBastion: [EffectSprite] = [.cancerZodiaction, .cancerZodiactionAlternate]

    /// Which bubble a sheltered square wears.
    ///
    /// One per square rather than both stacked: layered, the two strips are near
    /// enough identical that the pair read as one drawing at slightly wrong
    /// opacity. Split across the chequer they do visible work — the Bastion
    /// picks up the board's own alternation instead of flattening it.
    ///
    /// Which of the two is darker was measured, not guessed: `cancer_zaction`
    /// averages 0.71 luminance over its lit pixels against `_v2`'s 0.87.
    static func bastionBubble(on shade: Palette.TileShade) -> EffectSprite {
        switch shade {
        case .dark: .cancerZodiaction
        case .light: .cancerZodiactionAlternate
        }
    }

    /// The strip a sign throws on a hard landing, *instead of* the dust.
    static func landing(for zodiac: Zodiac) -> EffectSprite? {
        switch zodiac {
        case .leo: .leoPridefulLanding
        default: nil
        }
    }

    /// The strip a sign throws when it walks sideways without turning.
    static func sidestep(for zodiac: Zodiac) -> EffectSprite? {
        switch zodiac {
        case .cancer: .crabWalk
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
        case .astralBlossom: .astralBloom
        default: nil
        }
    }

    /// One of the four strikes, chosen by something that varies between them.
    ///
    /// Deliberately not `randomElement()`: the run is a pure function of its
    /// seed and inputs, and while a strike variant changes nothing about the
    /// game state, a replay that looked different would still be a replay that
    /// looked different. Keyed on the move instead, which varies between strikes
    /// and reproduces exactly.
    static func strike(at moveCount: Int) -> EffectSprite {
        lightning[abs(moveCount) % lightning.count]
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
