//
//  PickupEffect.swift
//  Project Stars
//
//  What a collected Pentacle does, and how the catalogue is organised.
//

import Foundation

// MARK: - PickupRarity

/// How often a tier of Pentacle turns up.
///
/// Rolling happens in two stages — first a tier, then an effect within it — so
/// that adding a new common effect does not silently dilute the legendaries.
enum PickupRarity: String, CaseIterable, Codable {
    case common
    case uncommon
    case rare
    case legendary

    var displayName: String { rawValue.capitalized }

    /// Relative likelihood of this tier.
    ///
    /// Tuned against how a run actually plays rather than to look like a
    /// distribution: the coin is on the board constantly, so the *default*
    /// outcome has to be something small. Roughly three grabs in five are the
    /// common tier, and most of those are an Astral Tear.
    ///
    /// The tiers are deliberately lopsided. A rare that turned up every eleventh
    /// coin was not rare, and the two rares are both piece changers — the single
    /// most disruptive thing a Pentacle can do.
    var weight: Int {
        switch self {
        case .common: 75
        case .uncommon: 21
        case .rare: 4
        case .legendary: 1
        }
    }
}

// MARK: - PentacleAppearance

/// How a Pentacle looks on the board before it is opened.
///
/// Ordinary Pentacles are deliberately identical — the coin is a loot box. The
/// legendaries are the documented exception: they are rare enough that
/// telegraphing them is the point.
enum PentacleAppearance: String, CaseIterable, Codable {
    /// The standard gold coin. Every common, uncommon and rare uses this.
    case standard

    /// Desaturated and dark. Shadow Work only.
    case shadow

    /// Bright and starlit. Polaris only.
    case radiant

    /// A bead of water. Gaia droplets only, and the one appearance that is not
    /// a coin at all — see `PickupClass.boon`.
    case droplet

    /// Libra's gavel. A Pentacle in its own right rather than a coin with a
    /// glyph on it — see `PentacleView.gavel`.
    case gavel
}

// MARK: - PickupClass

/// What sort of thing this is, structurally.
///
/// ## Why the distinction exists
///
/// The board's whole economy is built around **one** Pentacle at a time: the
/// sparkle phase waits for the board to be clear, taking one shatters the other,
/// and `GameEngine.ensurePentacleAvailable` sweeps up anything stranded so the
/// hunt can never stall. Every one of those rules is correct for a Pentacle and
/// wrong for anything else.
///
/// Pisces' droplets are not part of that economy. They are put on the board by
/// an ability, they are meant to sit there, and the hunt should carry on around
/// them — so they share the pickup machinery (reveal, collect, run an effect)
/// and are excluded from every rule that governs the hunt.
///
/// Sibling classes rather than one class with exceptions: an exception has to be
/// remembered at each of a dozen call sites, where a class is asked.
enum PickupClass: String, Codable {

    /// The hunt. One at a time, and the sparkle phase waits on it.
    case pentacle

    /// Something an ability left lying on the board. Persists, ignores the
    /// hunt's rules, and the hunt ignores it.
    case boon
}

// MARK: - PickupChoice

/// A decision a Pentacle needs from the player before it can resolve.
///
/// Most effects resolve instantly during planning. A few cannot: they need input
/// that only the player can give. Those suspend the move, collect the answer,
/// and then plan the rest — the same shape as the first-encounter splash, but
/// with the answer changing the outcome rather than just the pacing.
enum PickupChoice: Equatable {
    /// No input needed. The overwhelming majority.
    case none

    /// Pick any square on the current plane, holes and the Nexys included.
    case tile

    /// Pick one of the twelve signs.
    case piece

    /// Pick one of the Pentacles in Capricorn's purse. See `ShopBarView`.
    case shop

    /// Pick where to drop a slab of ground.
    ///
    /// Carries the slab itself, because the board has to draw it: the player is
    /// choosing an anchor for a *shape*, and a cursor that showed only the
    /// square under their finger would be asking them to hold the other three in
    /// their head. See `GaleforceGavelEffect`.
    case place(GavelSlab)

    /// Pick one of a named handful of squares, or none of them.
    ///
    /// Unlike `tile`, this one may be **declined**: it is an offer rather than a
    /// question, and a passive that fires on arrival cannot be allowed to trap
    /// the player into moving. Aquarius' Corner Current is the first.
    case among([GridPoint])
}

/// What the player answered.
enum PickupChoiceResult: Equatable {
    case tile(GridPoint)
    case piece(Zodiac)

    /// A Pentacle bought back out of the purse.
    case item(PickupID)

    /// The player was offered something and said no. Only `PickupChoice.among`
    /// can produce this; everything else must be answered.
    case declined

    /// A slab, and the square its anchor was dropped on.
    ///
    /// Carries the slab back rather than trusting the effect to have kept it:
    /// the roll happened when the question was asked, and the answer has to name
    /// what it is an answer *to*.
    case place(GavelSlab, GridPoint)
}

// MARK: - PickupContext

/// Read-only snapshot handed to an effect when it is opened.
struct PickupContext {
    /// The board the piece is standing on.
    let currentBoard: Board

    /// The board below, or `nil` when the piece is already on Terra.
    let boardBelow: Board?

    /// Which plane the piece is on.
    let plane: Plane

    /// Which plane the Nexys island is currently on.
    let nexysPlane: Plane

    /// Where the piece is standing — i.e. where the Pentacle was opened.
    let piecePoint: GridPoint

    /// Which way the piece is looking. Directional effects key off this.
    let facing: SwipeDirection

    /// The sign currently being controlled.
    let zodiac: Zodiac

    /// Current Zodiaction charge, and the cap it is measured against.
    let zodiactionMeter: Int
    let zodiactionMeterMax: Int

    /// What the sign remembers between moves. An effect that grants a lasting
    /// state — the Astral Bolt's star — amends this and returns it in a
    /// `signStateChanged`, exactly as a Zodiaction would.
    let signState: SignState

    /// True when the piece is standing on the Nexys island.
    var isOnNexys: Bool {
        plane == nexysPlane && piecePoint == GameRules.nexysPoint
    }

    /// Charge, clamped and expressed as the absolute value the meter should
    /// become — which is the form `GameEvent.zodiactionMeterChanged` takes.
    func meter(afterGaining amount: Int) -> Int {
        min(max(zodiactionMeter + amount, 0), zodiactionMeterMax)
    }
}

// MARK: - PickupEffect

/// The behaviour of one Pentacle.
///
/// Effects are **planners, not mutators**. `plan` inspects the snapshot, rolls
/// whatever randomness it needs, and returns a list of `GameEvent`s describing
/// the outcome. The engine applies those events, and the UI replays the same
/// list to animate them. One list, one source of truth, no chance of the
/// simulation and the animation disagreeing.
protocol PickupEffect {

    /// Which Pentacle this implements.
    var id: PickupID { get }

    /// How often it turns up.
    var rarity: PickupRarity { get }

    /// The tier this is *rolled* in, when that differs from what it is.
    ///
    /// For effects whose rarity is enforced by something other than the dice.
    /// Polaris is pinned to one square, so it is only ever a candidate when a
    /// sparkle set happens to cover the top-centre tile — that restriction is
    /// already doing the work a legendary weight would do, and applying both
    /// makes it something no player will ever see. It rolls as a common and
    /// stays a legendary in everything the player is shown: the tier on its
    /// banner, and its own radiant coin.
    ///
    /// Defaults to `rarity`, which is right for everything else.
    var rollsAsRarity: PickupRarity { get }

    /// Name shown when opened.
    var displayName: String { get }

    /// One-line rules text.
    var summary: String { get }

    /// Stand-in glyph for the first-encounter strip, until art arrives.
    var glyph: String { get }

    /// How it looks on the board. Defaults to the anonymous gold coin.
    var appearance: PentacleAppearance { get }

    /// The element this effect belongs to, if any.
    ///
    /// Drives the elemental burst played when it resolves — see
    /// `ElementalBurstView`. Only the four Astral Essences have one; everything
    /// else returns `nil` and plays no burst.
    var element: ZodiacElement? { get }

    /// Relative weight against the other effects **in the same tier**.
    ///
    /// Set to `0` to keep an effect implemented but out of rotation.
    var weight: Int { get }

    /// A square this effect may only ever appear on, or `nil` for anywhere.
    ///
    /// Enforced twice: an effect with a requirement is only eligible when the
    /// sparkle set actually covers that square, and the reveal is forced there.
    var requiredSpawnPoint: GridPoint? { get }

    /// A last gate, rolled *after* this effect has already won its draw.
    ///
    /// One for almost everything. It exists for coins whose rarity cannot be
    /// expressed as a weight, because a weight is relative to the tier and the
    /// tier is not where the scarcity is meant to come from — Polaris is pinned
    /// to a single square, which sounds rare and is not: the square is in play
    /// often enough that winning its tier a fifth of the time made it several a
    /// run. Failing this gate re-draws from everything else.
    var spawnChance: Double { get }

    /// Whether this belongs to the Pentacle hunt or is something an ability left
    /// on the board. See `PickupClass`.
    var pickupClass: PickupClass { get }

    /// Input this effect needs from the player before it can resolve.
    ///
    /// A *description* of the question, and therefore static. An effect whose
    /// question has random content in it — Libra's Gavel, which rolls the slab
    /// before showing it — declares the shape of the question here and supplies
    /// the real one from `rolledChoice(using:)`.
    var choice: PickupChoice { get }

    /// The question actually put to the player, with anything random in it
    /// already decided.
    ///
    /// Defaults to `choice`. Rolled at the moment the question is asked and
    /// carried inside it, so the answer names what it was answering and a seeded
    /// run replays identically.
    func rolledChoice(using generator: inout SeededRandom) -> PickupChoice

    /// Whether arriving somewhere new because of this effect wears the tile
    /// landed on.
    ///
    /// True for teleports — arriving *is* landing, and every gameplay check
    /// happens on landing. False for effects that already applied their own wear
    /// along the way, so the destination is not charged twice.
    var arrivalWearsTile: Bool { get }

    /// Decides what this Pentacle does.
    ///
    /// - Parameter choice: The player's answer, when `self.choice` is not
    ///   `.none`. Always `nil` otherwise.
    /// - Returns: The events to apply, in order. May be empty when the effect
    ///   has nothing to do.
    func plan(
        context: PickupContext,
        choice: PickupChoiceResult?,
        generator: inout SeededRandom
    ) -> [GameEvent]
}

// MARK: - Defaults

extension PickupEffect {
    var appearance: PentacleAppearance { .standard }
    var element: ZodiacElement? { nil }
    var weight: Int { 1 }
    var rollsAsRarity: PickupRarity { rarity }
    var requiredSpawnPoint: GridPoint? { nil }
    var choice: PickupChoice { .none }
    var arrivalWearsTile: Bool { true }
    var pickupClass: PickupClass { .pentacle }
    var spawnChance: Double { 1 }

    func rolledChoice(using generator: inout SeededRandom) -> PickupChoice { choice }
}
