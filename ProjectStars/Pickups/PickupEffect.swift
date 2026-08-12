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
}

/// What the player answered.
enum PickupChoiceResult: Equatable {
    case tile(GridPoint)
    case piece(Zodiac)

    /// A Pentacle bought back out of the purse.
    case item(PickupID)
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

    /// Input this effect needs from the player before it can resolve.
    var choice: PickupChoice { get }

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
}
