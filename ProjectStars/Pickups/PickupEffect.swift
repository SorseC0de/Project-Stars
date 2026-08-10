//
//  PickupEffect.swift
//  Project Stars
//
//  What a collected Pentacle does, and how the catalogue is organised.
//

import Foundation

// MARK: - PickupID

/// Stable identifier for every Pentacle effect in the game.
///
/// State stores this rather than the effect object, which keeps the engine
/// `Equatable` and `Codable` and makes save/replay straightforward. Look the
/// behaviour up through `PickupCatalog.effect(for:)`.
///
/// - Note: Names marked provisional in the design are marked here too. Renaming
///   a case changes its `rawValue`, which is both the asset suffix and the
///   `PentacleCodex` storage key — so a rename also resets that effect's
///   first-encounter prompt. That is usually what you want during design.
enum PickupID: String, CaseIterable, Codable, Identifiable, Hashable {

    // MARK: Common

    /// *Provisional name.* Grants a flat amount of Zodiaction charge.
    case zCharge

    /// *Provisional name.* Fully repairs one random damaged tile on this plane.
    case restoreTile

    // MARK: Uncommon

    /// Astral Essence — Water. Slides you to the border, damaging as you go.
    case astralBrook

    /// Astral Essence — Air. Teleports you to a tile of your choosing.
    case astralBreeze

    /// Astral Essence — Fire. Damages the 3x3 around you, paying out charge.
    case astralBlaze

    /// Astral Essence — Earth. Repairs the 3x3 around you.
    case astralBlossom

    /// *Provisional name.* Teleports you to a random corner, safe or not.
    case cornerWarp

    /// Brings the island to your plane, or warps you onto it if it is already
    /// there.
    case nexysShift

    // MARK: Rare

    /// Changes your piece to a random other sign, whether you like it or not.
    case forcedFate

    /// Lets you choose a new sign — including the one you already have.
    case alignment

    // MARK: Legendary

    /// Only ever spawns from a sparkle on the north-middle tile.
    case polaris

    /// Spawns a mirrored shadow of your piece.
    case shadowWork

    var id: String { rawValue }
}

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
    /// - TODO: Untuned. These are placeholders pending real balancing.
    var weight: Int {
        switch self {
        case .common: 58
        case .uncommon: 32
        case .rare: 9
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
enum PentacleAppearance: String, Codable {
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
}

/// What the player answered.
enum PickupChoiceResult: Equatable {
    case tile(GridPoint)
    case piece(Zodiac)
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
    var requiredSpawnPoint: GridPoint? { nil }
    var choice: PickupChoice { .none }
    var arrivalWearsTile: Bool { true }
}

// MARK: - PickupCatalog

/// The registry of every Pentacle, and the roll that decides which one spawns.
enum PickupCatalog {

    /// Every implemented effect, keyed by id.
    static let allEffects: [PickupID: any PickupEffect] = [
        .zCharge: ZChargeEffect(),
        .restoreTile: RestoreTileEffect(),

        .astralBrook: AstralBrookEffect(),
        .astralBreeze: AstralBreezeEffect(),
        .astralBlaze: AstralBlazeEffect(),
        .astralBlossom: AstralBlossomEffect(),
        .cornerWarp: CornerWarpEffect(),
        .nexysShift: NexysShiftEffect(),

        .forcedFate: ForcedFateEffect(),
        .alignment: AlignmentEffect(),

        .polaris: PolarisEffect(),
        .shadowWork: ShadowWorkEffect(),
    ]

    /// The effect for an id. Traps on an unregistered id, which can only happen
    /// if a `PickupID` case was added without its implementation.
    static func effect(for id: PickupID) -> any PickupEffect {
        guard let effect = allEffects[id] else {
            preconditionFailure("No PickupEffect registered for \(id.rawValue)")
        }
        return effect
    }

    /// Rolls the Pentacle to hide in a sparkle set.
    ///
    /// Two stages — tier, then effect within the tier — so the odds of a
    /// legendary do not shift every time a common one is added.
    ///
    /// - Parameter sparklePoints: Squares the set covers. Effects with a
    ///   `requiredSpawnPoint` are only eligible when the set includes it, which
    ///   is how Polaris stays pinned to the north-middle tile.
    static func rollPickup(
        sparklePoints: [GridPoint],
        using generator: inout SeededRandom
    ) -> PickupID? {
        let covered = Set(sparklePoints)

        /// Effects in `rarity` that could legally appear in this set.
        func eligible(in rarity: PickupRarity) -> [(value: PickupID, weight: Int)] {
            allEffects.values
                .filter { effect in
                    guard effect.rarity == rarity, effect.weight > 0 else { return false }
                    guard let required = effect.requiredSpawnPoint else { return true }
                    return covered.contains(required)
                }
                .map { (value: $0.id, weight: $0.weight) }
        }

        // Only offer tiers that actually have something to give, so an empty
        // legendary tier cannot swallow a roll.
        let tiers = PickupRarity.allCases
            .filter { !eligible(in: $0).isEmpty }
            .map { (value: $0, weight: $0.weight) }

        guard let tier = generator.pick(weighted: tiers) else { return nil }
        return generator.pick(weighted: eligible(in: tier))
    }
}
