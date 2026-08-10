//
//  Zodiaction.swift
//  Project Stars
//
//  The charged, player-fired ability each sign has.
//

import Foundation

/// A sign's super: a meter that charges through play and an ability that fires
/// when the player spends it.
///
/// Two halves, both per-sign and both plane-dependent:
///
/// - **Charging.** Every sign builds meter its own way — one might charge by
///   cracking tiles, another by falling, another by collecting pickups. That is
///   `meterGain(from:context:)`, which is handed a summary of the move that
///   just resolved and returns how much meter it was worth.
/// - **Firing.** `activate(context:)` returns the events the super produces,
///   exactly like a `PickupEffect`. It never mutates anything itself.
///
/// Like passives, supers differ by plane: check `context.plane` and
/// `context.isEmpowered` rather than assuming one behaviour.
///
/// - Note: All twelve signs currently use `PlaceholderZodiaction`, which charges a
///   flat amount per move and does nothing when fired.
protocol Zodiaction {

    /// Name shown on the meter.
    var displayName: String { get }

    /// One-line rules text. Should describe both planes when they differ, and
    /// say how the meter charges.
    var summary: String { get }

    /// Meter required to fire.
    var meterMax: Int { get }

    /// How much meter the move that just resolved was worth.
    ///
    /// **Required — there is deliberately no default.** There is no universal
    /// charge rule in this game: every sign builds its meter its own way, and a
    /// shared fallback would let a sign quietly ship without one. Return `0` for
    /// moves that do not charge this sign.
    func meterGain(from move: MoveSummary, context: PassiveContext) -> Int

    /// The events popping the Zodiaction produces.
    ///
    /// Return an empty array for one that only exists as a marker for now. The
    /// engine spends the meter regardless.
    ///
    /// - Parameter generator: The run's seeded generator. Zodiactions that pick
    ///   a random square or re-roll a glow phase draw from it, so a seeded run
    ///   stays reproducible right through a pop.
    func activate(context: PassiveContext, generator: inout SeededRandom) -> [GameEvent]
}

// MARK: - Default implementations

extension Zodiaction {
    var meterMax: Int { GameRules.defaultZodiactionMeterMax }

    func activate(context: PassiveContext, generator: inout SeededRandom) -> [GameEvent] {
        []
    }
}

// MARK: - MoveSummary

/// What a single committed move amounted to.
///
/// Handed to `Zodiaction.meterGain(from:context:)` so a charging rule can be
/// written against what actually happened — "charge when you crack a tile",
/// "charge when you fall", "charge only on your strong plane" — without a super
/// having to inspect the whole event list itself.
struct MoveSummary: Equatable {
    /// The swipe that was committed.
    let direction: SwipeDirection

    /// Where the piece started.
    let origin: GridPoint

    /// Where the hop was aimed. Not necessarily where the piece ended up, if it
    /// fell from there.
    let destination: GridPoint

    /// The plane the move started on.
    let startingPlane: Plane

    /// The plane the piece ended the move on.
    let endingPlane: Plane

    /// Where the piece came to rest.
    let restingPoint: GridPoint

    /// How many tiles took wear during the move.
    let tilesWorn: Int

    /// How many tiles reached `hole` during the move.
    let tilesBroken: Int

    /// True when the piece dropped through at least one plane.
    let fell: Bool

    /// True when the piece rode the Nexys back up to Astra this move.
    let ascended: Bool

    /// The pickup collected, if any.
    let collectedPickup: PickupID?

    /// True when the Pentacle collected was the one revealed on this very move —
    /// i.e. the sparkle the piece was already heading for turned out to be the
    /// one hiding it. Sagittarius' Lucky Reveal pays out on exactly this.
    let collectedOnRevealTile: Bool

    /// True when the piece reached the Nexys by something other than walking
    /// there — a Pentacle, a Zodiaction, a fall. Cancer's Homebound Surge
    /// excludes ordinary movement, and this is that distinction.
    let arrivedAtNexysByEffect: Bool

    /// True when the move went to either side of the facing the piece held
    /// *before* it committed.
    ///
    /// Recorded by the engine because facing updates as part of the move: by the
    /// time anything else can look, the sideways step has become the new
    /// forward.
    let wasSideways: Bool

    /// How many holes the move passed over without dropping into them.
    ///
    /// Only jumps can do this; a slide settles on every square it crosses.
    let holesJumped: Int

    /// True when the run ended on this move.
    let endedRun: Bool

    /// True when the move started and ended on the sign's strong plane.
    func wasEmpowered(for zodiac: Zodiac) -> Bool {
        zodiac.element.empoweredPlane == endingPlane
    }
}

// MARK: - PlaceholderZodiaction

/// Fallback Zodiaction, used only if a sign somehow has none of its own.
///
/// **Not** what the twelve signs use — each declares its own in its own file, so
/// that their charging rules stay visibly separate and none of them can quietly
/// inherit someone else's. This exists so `ZodiacDefinition` has a sane default.
struct PlaceholderZodiaction: Zodiaction {
    var displayName: String = "—"
    var summary: String = "Zodiaction not yet implemented."

    func meterGain(from move: MoveSummary, context: PassiveContext) -> Int {
        GameRules.placeholderZodiactionMeterGain
    }
}
