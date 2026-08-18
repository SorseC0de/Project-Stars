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

    /// Aries' Zodiaction: the trail it leaves on each burning tile. 8 frames.
    case ariesZodiaction

    /// Aries' Zodiaction: the flare of it being lit. 16 frames.
    case ariesActivation

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

    /// The Astral Tear's droplet. 14 frames.
    case droplet

    /// The arrow itself. One frame — it is an object, not an animation.
    case sagittariusArrow

    /// The impact where Sagittarius' arrow strikes the ground. 12 frames.
    case sagittariusArrowHit

    /// The warp square the planted arrow leaves humming. 11 frames, looped for
    /// as long as the arrow is out there.
    case sagittariusTeleTile

    // MARK: New art

    /// Wind, for anything gusty without a drawing of its own. Replaces the
    /// programmatic gust behind Astral Breeze.
    case windMisc

    /// The lightning that plays in front of a piece struck by an Astral Bolt.
    case lightningMisc

    /// Aquarius' Zodiaction. Wired ahead of the effect it will decorate.
    case aquariusZodiaction

    /// One band of Aquarius' storm — stacked, scaled and turned to build the
    /// funnel around the silhouette. See `AquariusStormView`.
    case aquariusArmor

    /// The same blade with a grey core instead of a gold one.
    ///
    /// A second drawing rather than a palette swap: the gold is not one entry
    /// but a ramp through the middle of the plate, and swapping a ramp for a
    /// ramp by hand is what the art already does better.
    case aquariusArmorGrey

    /// The glow phase, replacing the rendered version.
    case glowPhase

    /// Sparkles, for the glow phase and anything else that wants them.
    case sparkles

    /// Played over the piece on any ZC gain. Drawn in greys on purpose, so the
    /// four tones can be swapped for whichever element earned it.
    case absorb

    /// The overhead flourish for a sniped Pentacle.
    case bonus

    /// Cancer's scuttle bubbles.
    case cancerScuttle

    /// Gemini's rift, in two drawings. 60 frames each, 256px.
    ///
    /// Both are in the game at once on purpose: the shape it should be is not
    /// decided, and a rift is a thing you can only judge standing on the board
    /// next to a piece. See `riftPreview(metrics:)`.
    case geminiRiftOne
    case geminiRiftTwo

    // MARK: - Where the art is

    /// Which element this belongs to, or `nil` for the ones outside the wheel.
    ///
    /// Lightning is the fifth Essence and no sign is attuned to it, so it has no
    /// element and lives in its own folder — see `folder`.
    var element: ZodiacElement? {
        if Self.lightning.contains(self) { return nil }
        // The Tear belongs to no sign either — the comment on its case said so
        // and the code answered `.water` anyway, which sent the loader to
        // `Water/droplet` while the art sits in `Astral/`. A strip that resolves
        // to a folder it is not in simply does not draw, and says nothing about
        // why.
        if self == .droplet { return nil }
        // The new astral set: none of these belong to a sign either.
        if Self.astral.contains(self) { return nil }
        return elementalFamily
    }

    /// The strips that belong to no element, and so live in `Astral/`.
    private static let astral: Set<EffectSprite> = [
        .lightningMisc, .glowPhase, .sparkles, .absorb, .bonus,
    ]

    /// The asset-catalog folder this strip lives in.
    var folder: String {
        element?.folderName ?? "Astral"
    }

    private var elementalFamily: ZodiacElement {
        switch self {
        case .ariesZodiaction, .astralBlaze, .leoPridefulLanding,
             .leoZodiactionOne, .leoZodiactionTwo, .leoZodiactionSummon,
             .fireMisc, .sagittariusJump, .explosion, .ariesActivation,
             .sagittariusArrow, .sagittariusArrowHit, .sagittariusTeleTile:
            .fire
        case .cancerZodiaction, .cancerZodiactionAlternate,
             .crabWalk, .waterSplash:
            .water
        // Libra is air, and the diamonds were filed under water only because the
        // first draft of them was drawn in blue.
        case .libraZodiaction, .windMisc, .aquariusZodiaction, .aquariusArmor,
             .aquariusArmorGrey, .geminiRiftOne, .geminiRiftTwo:
            .air
        case .cancerScuttle:
            .water
        case .lightningMisc, .glowPhase, .sparkles, .absorb, .bonus:
            .air  // Unreachable: `element` short-circuits these to nil.
        case .astralBloom:
            .earth
        // Astral rather than elemental: the Tear belongs to no sign.
        case .droplet:
            .water
        case .lightning1, .lightning2, .lightning3, .lightning4:
            .air  // Unreachable: `element` short-circuits lightning to nil.
        }
    }

    /// The image set's name inside its element folder.
    var file: String {
        switch self {
        case .ariesZodiaction: "aries_zaction"
        case .ariesActivation: "aries_zaction2"
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
        case .droplet: "droplet"
        case .sagittariusArrow: "saggitarius_arrow"
        case .sagittariusArrowHit: "saggitarius_arrowhit"
        case .sagittariusTeleTile: "saggitarius_teletile"
        case .windMisc: "misc"
        case .lightningMisc: "lightning_misc"
        case .aquariusZodiaction: "aquarius_zaction"
        case .aquariusArmor: "aquarius_armor"
        case .aquariusArmorGrey: "aquarius_armor_v2"
        case .glowPhase: "glow_phase"
        case .sparkles: "sparkles"
        case .absorb: "absorb"
        case .bonus: "bonus"
        case .cancerScuttle: "cancer_scuttle"
        case .geminiRiftOne: "wind_gemini_rift_v1"
        case .geminiRiftTwo: "wind_gemini_rift_v2"
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
        case .explosion, .sagittariusArrow: CGSize(width: 96, height: 96)
        case .waterSplash: CGSize(width: 48, height: 48)
        // Wide rather than square: the flourish spans four tiles so it can be
        // read from across the board without sitting on top of the coin.
        case .bonus: CGSize(width: 256, height: 96)
        case .windMisc, .absorb, .cancerScuttle:
            CGSize(width: 128, height: 128)
        case .lightningMisc, .aquariusZodiaction, .glowPhase, .sparkles:
            CGSize(width: 96, height: 96)
        case .geminiRiftOne, .geminiRiftTwo:
            CGSize(width: 256, height: 256)
        // Redrawn at twice their first size. The widest plate is blown up to
        // about 200 points on screen, which at 64px put its art pixels at more
        // than twice the size of a board tile's — the plates read as coarser
        // than everything around them, and worse the bigger they got. At 128
        // they land within a tenth of the board's own pixel.
        case .aquariusArmor, .aquariusArmorGrey:
            CGSize(width: 128, height: 128)
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

    /// Where the strip's own frame sits against the square it is played on.
    ///
    /// Every effect is one of two things, and the difference is not a nudge:
    ///
    /// - **Centred** on the square. Something happening *at* a place — a burst,
    ///   a splash, a glow phase lighting a tile.
    /// - **Standing** on it, with the frame's bottom edge on the square and the
    ///   art rising from there. Something that belongs *over* a place — the
    ///   snipe banner overhead, and anything else drawn to be read above the
    ///   piece rather than around it.
    ///
    /// Stated rather than dialled, because "come up by half of however tall you
    /// happen to be" is not something a call site can know and is exactly what
    /// `groundLift` was being asked to approximate one effect at a time.
    ///
    /// The default is centred — what every strip did before this existed — so
    /// moving one over is a deliberate line here rather than a silent shift of
    /// everything at once.
    var anchor: EffectAnchor {
        switch self {
        case .bonus: .standing
        default: .centred
        }
    }

    /// The frame size this strip's **bloom** was tuned against.
    ///
    /// `EffectSpriteView` measures its glow in the art's own pixels — radius
    /// times `side / frameSize.width` — which is right while the pixel count
    /// says something about how big the drawing is. It stops being right the
    /// moment a strip is **re-exported at a higher resolution**: the same
    /// picture at twice the pixels is drawn at the same size on the board, but
    /// the bloom silently halves, and the whole thing goes dark.
    ///
    /// That is what happened to the storm. The plates went from 64 to 128 to
    /// fix their pixels being coarser than the board's, and took the funnel's
    /// light with them — build 18 is visibly brighter for exactly this reason
    /// and nothing else changed about the art. The file is byte for byte the
    /// same; three hashes say so.
    ///
    /// So a strip may say what its bloom was tuned at, and the default is what
    /// it is drawn at — which is every other strip, unchanged.
    var glowBasis: CGFloat {
        switch self {
        case .aquariusArmor, .aquariusArmorGrey: 64
        default: frameSize.width
        }
    }

    /// How many frames sit on one row of the sheet, or `nil` for all of them.
    ///
    /// A packing detail rather than an art one — see `SpriteSlice.columns` for
    /// why the rift is the one strip that wraps.
    var stripColumns: Int? {
        switch self {
        case .geminiRiftOne, .geminiRiftTwo: 8
        default: nil
        }
    }

    /// How many frames the strip holds.
    var frames: Int {
        switch self {
        case .ariesZodiaction, .sagittariusJump: 8
        case .fireMisc, .leoZodiactionSummon: 9
        case .astralBlaze, .waterSplash,
             .lightning1, .lightning2, .lightning3, .lightning4: 10
        case .crabWalk, .ariesActivation: 16
        case .explosion: 28
        case .astralBloom: 16
        case .sagittariusArrow: 1
        case .droplet: 14
        case .leoPridefulLanding, .sagittariusTeleTile: 11
        case .sagittariusArrowHit: 12
        case .leoZodiactionOne, .leoZodiactionTwo,
             .cancerZodiaction, .cancerZodiactionAlternate, .libraZodiaction: 22
        case .windMisc, .lightningMisc, .aquariusZodiaction: 10
        case .glowPhase: 12
        case .aquariusArmor, .aquariusArmorGrey: 16
        case .sparkles: 24
        case .absorb: 31
        case .cancerScuttle: 40
        case .geminiRiftOne, .geminiRiftTwo: 60
        case .bonus: 44
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
        // The Essence plumes are the whole story of what a coin just did to the
        // board, and at 15fps they were over before the eye found them.
        case .astralBlaze, .astralBloom: .fps12
        // Forty-four frames. At twelve it lasts nearly four seconds, which is
        // longer than the move that earned it and reads as the game stopping to
        // congratulate you; at twenty it is over in two.
        case .bonus: .fps20
        // Prideful Plant, one stage down. Eleven frames of fire went past too
        // quickly to read as a landing.
        case .leoPridefulLanding: .fps10
        // The shot's two halves. The strike is a single loud moment and the warp
        // square is a thing that hums for as long as the arrow is out there;
        // both were going past too quickly to be read as either.
        case .sagittariusArrowHit: .fps10
        case .sagittariusTeleTile, .aquariusZodiaction: .fps12
        // The Tear's droplet is fourteen frames of a single splash. At the house
        // default it was over in about a second and never seen at all.
        case .droplet: .fps15
        // The Bastion is two layers of the same bubble, and the lower one runs
        // slower on purpose: two identical strips in lockstep read as one
        // doubled-up drawing, while a beat between them reads as depth.
        case .cancerZodiaction, .crabWalk, .waterSplash: .fps15
        // Long strips of dissipating smoke: at 15 the tail crawls.
        case .explosion: .fps20
        // Aries Activation 15 -> 24. The early and late frames are very similar
        case .ariesActivation: .fps24
        case .lightning1, .lightning2, .lightning3, .lightning4: GameRules.lightningRate
        // The long ones, at sixty. Forty-four frames at 24fps is close to two
        // seconds, which outlasts the move it is decorating; at 60 they land
        // inside it.
        //
        // Not the bonus: it was slowed to twelve above, deliberately, so the
        // flourish lasts long enough to register as a reward.
        case .absorb, .sparkles: .fps60
        // The storm's band ends on an empty cell, so it is a gust rather than a
        // loop. Slow, and staggered by whoever stacks it — see `AquariusStorm`.
        case .aquariusArmor: .fps20
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
    ///
    /// - Important: The piece is drawn **centred on its square**, not standing
    ///   at the bottom of it — see `PieceView`, where a 16x32 sprite is lifted
    ///   so its middle sits on the tile. So an effect centred on the tile centre
    ///   lands at the piece's *feet*, not its middle, and almost everything here
    ///   wants lifting further than seems right.
    var groundLift: CGFloat {
        switch self {
        case .ariesZodiaction, .astralBlaze, .sagittariusJump: 8
        // Bursts around the piece rather than at its feet.
        case .ariesActivation: 8
        case .fireMisc: 6
        case .cancerZodiaction, .cancerZodiactionAlternate: 2
        case .explosion, .crabWalk, .waterSplash: 4
        // A tile and a half up. The bubbles come off the crab rather than off
        // the ground it is crossing, and at the art's own height they read as
        // foam on the floor.
        case .cancerScuttle: CGFloat(GameRules.tilePixelSize) * 1.5
        // The bolt comes down *onto* the square, so its foot sits on the tile
        // and the rest of it towers overhead. Tuned from `GameRules`.
        case .lightning1, .lightning2, .lightning3, .lightning4: GameRules.lightningLift
        case .leoPridefulLanding: 0
        // Authored centred, so it needs no lift at all.
        case .astralBloom: 0
        case .leoZodiactionOne, .leoZodiactionTwo, .leoZodiactionSummon,
             .libraZodiaction: 0
        // Both belong to the ground: the strike is where the shaft went in, and
        // the warp square is the square itself.
        //
        // The hit is the exception: as the flourish for becoming charged it is
        // the shot being nocked rather than one landing, so it belongs at the
        // top of the bow — a full tile above the ground everything else here is
        // measured from.
        case .sagittariusArrowHit: CGFloat(GameRules.tilePixelSize)
        case .sagittariusTeleTile: 0
        case .sagittariusArrow: 0
        // A hole in the ground, so it belongs to the ground.
        case .geminiRiftOne, .geminiRiftTwo: 0
        // Water landing on a square, so it belongs to the square.
        case .droplet: 0
        // Over the piece rather than at its feet: the absorb is the charge
        // arriving in the statue, and the lightning strikes the figure itself.
        case .absorb, .lightningMisc: 8
        // The storm wakes around him, not under him. At the art's own height it
        // burst at the statue's feet, which is where the funnel *ends*.
        case .aquariusZodiaction: CGFloat(GameRules.tilePixelSize)
        // Clear of the head, on top of standing on the square — see `anchor`.
        // A piece is two tiles tall, so the banner starts a tile above the one
        // it is standing on.
        case .bonus: CGFloat(GameRules.tilePixelSize)
        // Ground-level: wind blows across a square, the glow phase is the
        // square lighting up, and the scuttle's bubbles come off the floor.
        case .windMisc, .glowPhase, .sparkles: 0
        // Around the whole figure, not under it.
        case .aquariusArmor, .aquariusArmorGrey: 8
        }
    }

    /// True for anything that sits on the floor rather than hanging over it.
    /// Presentation only — the gallery labels with it.
    var isGrounded: Bool { groundLift > 0 }

    /// How this strip sits against what is under it.
    ///
    /// Normal for everything drawn as an object in the world. Additive for the
    /// ones that are *light* rather than a thing — the absorb is charge
    /// arriving, and multiplying a grey ramp by a colour keeps its detail but
    /// can only ever darken what it lands on. Adding it makes the same pixels
    /// read as glow.
    var blend: BlendMode {
        switch self {
        case .absorb: .plusLighter
        // The rift is a tear in the world rather than a light in it: hard light
        // keeps the dark of it dark against both skies, where the additive
        // modes bleached it on Astra and lost it entirely on Terra.
        case .geminiRiftOne, .geminiRiftTwo: .hardLight
        default: .normal
        }
    }

    /// How brightly this strip blooms.
    ///
    /// Per element, because the art is lit differently: the water strips carry
    /// their own glow and only need a little help, while the fire ones are drawn
    /// flatter and need considerably more before they read as giving off light
    /// rather than as being a picture of fire.
    var glowIntensity: Double {
        // Named strips first, since a few are meant to be brighter than their
        // element's default — an arrow landing and a warp square humming are
        // both *events*, and an event that does not carry its own light gets
        // lost against a board full of ambient motion.
        switch self {
        case .sagittariusArrowHit, .sagittariusTeleTile, .libraZodiaction,
             // The Breeze's gust is the moment the Essence fires, and the wind
             // art is drawn pale — without a strong bloom it reads as haze on
             // the board rather than as something happening.
             .windMisc, .glowPhase, .aquariusZodiaction,
             // The splash is the fish coming loose, which is the same kind of
             // moment as the arrow landing: a state change rather than
             // scenery. See `chargedFlourish(for:)`.
             .waterSplash,
             // Whether it glows at all is one of the things being looked at.
             .geminiRiftOne, .geminiRiftTwo:
            return GameRules.effectGlowStrongIntensity
        default:
            break
        }

        // The absorb carries no bloom at all. It is drawn additively, which is
        // already light — a blurred copy underneath was a second glow on top of
        // the one the blend mode provides, and it smeared the detail the art has
        // back out again.
        if self == .absorb { return 0 }

        switch element {
        case .fire: return GameRules.effectGlowFireIntensity
        // Lightning is the brightest thing in the game by a distance.
        case .none: return GameRules.effectGlowFireIntensity
        default: return GameRules.effectGlowIntensity
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
        // The charged flourish, not a droplet landing: it is the fish coming
        // loose, and at one tile it read as something small happening near him.
        case .waterSplash: 2.0
        // The warp square marks *one* square and has to fit inside it. At the
        // standard span it reached into its neighbours, which for a marker
        // saying "this tile is the one" is the whole thing it must not do.
        case .sagittariusTeleTile: GameRules.effectSpan * 0.75

        // ── The new set ─────────────────────────────────────────────────
        //
        // `effectSpan` was tuned against 64px art. These are drawn at 96 and
        // 128, so left on the default every one of them comes out undersized —
        // not by taste, but by the ratio between what they were drawn at and
        // what the number assumes.
        //
        // Stated per strip rather than derived from the frame size, because how
        // much board a thing should cover is not the same question as how many
        // pixels it was drawn with: the glow phase is 96px and still has to sit
        // inside one square, because its whole job is to say *this tile*.

        // One square each, and no more. A phase that spilled into its
        // neighbours would be pointing at the wrong tiles.
        case .glowPhase, .sparkles: 1.1

        // Around the piece rather than under it.
        case .windMisc, .absorb: GameRules.effectSpan * 1.6
        case .cancerScuttle: GameRules.effectSpan * 1.3

        // A strike, and it should read as one.
        case .lightningMisc: GameRules.effectSpan * 2

        // The storm's own art, at the size the storm is.
        case .aquariusZodiaction: 4

        // A banner over the board rather than a mark on a square — but eleven
        // tiles is wider than the board itself, which read as a title card
        // rather than as something that happened on a square.
        case .bonus: 6

        // A tear in the board is bigger than the square it opens on, but it is
        // still a *place* — at four it stopped being somewhere you could stand
        // beside. Squeezed to three quarters across by `riftPreview`, which is
        // the drawn shape rather than the coverage this answers.
        case .geminiRiftOne, .geminiRiftTwo: 2

        default: GameRules.effectSpan
        }
    }

    /// How much taller than wide this is drawn, against its own proportions.
    ///
    /// Separate from `span` because the two are answering different questions:
    /// `span` is how much of the board it covers, and this is the shape of the
    /// thing. The warp square has to fit one tile across and still read as a
    /// column of fire, which is not a square.
    var spanScaleY: CGFloat {
        switch self {
        case .sagittariusTeleTile: 1.25
        // **Nothing.** `height` already takes the frame's own proportions, so
        // stating them again here squashed the banner to a third of its drawn
        // shape — the aspect was applied twice and the word came out flattened.
        case .bonus: 1
        default: 1
        }
    }

    /// A nudge in art pixels, for a strip that is not centred in its own cell.
    ///
    /// The alternative is editing the sheet, which is worse: the art is right
    /// and its *placement* is what needs saying, so it is said here rather than
    /// baked into pixels somebody has to re-find later.
    var artNudge: CGSize {
        switch self {
        case .sagittariusTeleTile: CGSize(width: 1, height: 0)
        // The strike is authored high in its cell, so it landed above the
        // square it is supposed to have hit.
        case .sagittariusArrowHit: CGSize(width: 0, height: 2)
        // The droplet is authored low in its cell, so it sat below the tile it
        // was mending.
        case .droplet: CGSize(width: 0, height: -8)
        default: .zero
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

    /// The flourish a sign throws the moment it becomes charged.
    ///
    /// Distinct from `chargeGain`, which plays on *every* pip. This is the one
    /// crossing that changes what the piece is — Pisces' fish comes loose and
    /// the archer's shot is nocked — and a sign whose look changes there should
    /// say so once rather than letting the sprite quietly swap.
    static func chargedFlourish(for zodiac: Zodiac) -> EffectSprite? {
        switch zodiac {
        case .pisces: .waterSplash
        case .sagittarius: .sagittariusArrowHit
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
        // The drawn scuttle. `crabWalk` was the stand-in, and it is being kept
        // rather than deleted because the big bubble it used is wanted
        // elsewhere — see the Cancer rework.
        case .cancer: .cancerScuttle
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
        case .restoreTile: .droplet
        // A stand-in until the water set is filled out — see `waterSplash`.
        case .astralBrook: .waterSplash
        default: nil
        }
    }

    /// Where a coin's strip is played.
    enum PickupShape {
        /// On the square the coin was opened on.
        case here

        /// On all nine squares it works over, whether or not each one changed.
        case ring

        /// On each square as the effect reaches it, over the course of the
        /// move — a slide does not happen all at once.
        case trailing

        /// Played on whatever square the coin *mends*, which it does not know
        /// until the effect has run. Held and spent on the repair, the same way
        /// `trailing` is held and spent on each square of a slide.
        case mending
    }

    /// How the coin's strip is laid out.
    ///
    /// Keyed on the coin rather than on what its events turned out to do. The
    /// first version played a plume only where a tile actually changed, so an
    /// Astral Blossom opened on healthy ground drew nothing at all and a Blaze
    /// over holes drew almost nothing — the effect looked broken exactly when
    /// the board was in the state that made it useless. What the coin *does* is
    /// the thing worth showing.
    static func shape(for id: PickupID) -> PickupShape {
        switch id {
        case .astralBlaze, .astralBlossom: .ring
        case .astralBrook: .trailing
        // On the square it repairs, which is not where the player is standing —
        // the Tear mends the worst tile on the board, wherever that is.
        case .restoreTile: .mending
        default: .here
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
    /// The strip a Zodiaction leaves on each square it damages as it travels.
    ///
    /// Pisces' Downstream *is* the Astral Brook, so it marks the ground the same
    /// way the coin does. Without this the Zodiaction swept the board in
    /// silence, which read as a different, lesser effect.
    static func zodiactionTrail(for zodiac: Zodiac, on plane: Plane) -> EffectSprite? {
        switch (zodiac, plane) {
        case (.pisces, .astra): .waterSplash
        default: nil
        }
    }

    /// The strip a sign lays down on every square of a **slide**.
    ///
    /// Pisces' surf used to be half of a Zodiaction and drew its water from
    /// `zodiactionTrail`. Making the surf ordinary movement left the water
    /// behind with the super it came from, so the sign's signature move became a
    /// silent glide. It is a property of the *movement*, so it lives here.
    static func slideTrail(for zodiac: Zodiac, on plane: Plane) -> EffectSprite? {
        switch (zodiac, plane) {
        case (.pisces, .astra): .waterSplash
        default: nil
        }
    }

    static func zodiaction(for zodiac: Zodiac) -> [EffectSprite] {
        switch zodiac {
        // Aries has two: this is the flare of Brazen Blaze catching, while
        // `blazeTrail` burns on each tile it leaves over the moves that follow.
        case .aries: [.ariesActivation]
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
