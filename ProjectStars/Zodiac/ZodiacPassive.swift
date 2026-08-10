//
//  ZodiacPassive.swift
//  Project Stars
//
//  The hook surface a sign's always-on ability plugs into.
//

import Foundation

/// A sign's permanent, always-active ability.
///
/// Passives are **decision-making, not state-mutating**. Each hook is handed a
/// read-only `PassiveContext` and returns an answer; the engine applies the
/// result. That keeps passives trivially testable and impossible to get into an
/// inconsistent state with the engine mid-move.
///
/// Every hook has a default implementation matching the base rules, so a sign
/// only writes the ones it actually changes.
///
/// ## Passives are plane-dependent
///
/// A sign does not behave the same on both planes. `context.plane` says where
/// the piece is and `context.isEmpowered` says whether that is the sign's
/// strong plane — broadly, fire and earth are stronger on Terra, air and water
/// on Astra (`ZodiacElement.empoweredPlane`). Write every hook as a decision
/// about *this* plane, not a global one.
///
/// ## Signs have several
///
/// Each sign carries **two or three** passives, held in
/// `ZodiacDefinition.passives` and combined by the rules in
/// `Array<any ZodiacPassive>` below. Write each one as a single self-contained
/// rule; do not try to make one passive account for another.
///
/// - Note: When a real design needs something these hooks cannot express, add a
///   hook here rather than reaching into the engine from a sign file.
protocol ZodiacPassive {

    /// Name shown in the info panel.
    var displayName: String { get }

    /// One-line rules text. Should describe both planes when they differ.
    var summary: String { get }

    // MARK: Movement hooks

    /// Adjusts the sign's base movement before a swipe is resolved.
    ///
    /// Use for passives that add or remove hops (e.g. "may also move
    /// diagonally on Astra"). Default: unchanged.
    func adjustedMovement(base: MovementPattern, context: PassiveContext) -> MovementPattern

    /// Extra moves granted after this one resolves, as a count of free hops.
    ///
    /// Default: `0`.
    func bonusMoves(context: PassiveContext) -> Int

    // MARK: Landing hooks

    /// Whether landing here wears the tile.
    ///
    /// Return `false` for "light-footed" passives that leave tiles intact.
    /// Default: `true`.
    func causesWear(on tile: Tile, at point: GridPoint, plane: Plane, context: PassiveContext) -> Bool

    /// Whether the piece survives a fall it would normally take.
    ///
    /// Return `true` to hover over a hole instead of dropping through. Applies
    /// to the Astra drop and the fatal Terra drop alike, so check `plane`.
    /// Default: `false` — normal falling rules.
    func preventsFall(from plane: Plane, at point: GridPoint, context: PassiveContext) -> Bool

    /// Whether wear lands on the tile being entered or the one being left.
    ///
    /// Aquarius is airborne and always damages on exit; Aries' Blaze Path
    /// switches to exit for its duration. Default: `.onEntry`.
    func wearTiming(context: PassiveContext) -> WearTiming

    /// Reshapes the wear about to be applied to a tile.
    ///
    /// The one hook that can both change an outcome *and* remember that it did:
    /// the proposal carries a mutable `signState`, so a passive that spends a
    /// cooldown or a per-visit charge records it in the same breath. Whatever it
    /// returns is what happens, and any state edit rides out on a
    /// `signStateChanged` event alongside the damage.
    ///
    /// Default: unchanged.
    func modifyWear(_ proposal: WearProposal, context: PassiveContext) -> WearProposal

    /// Whether arriving here by falling fully restores the tile landed on.
    ///
    /// Holes are never restored this way — a hole is what you fell into, not
    /// what you landed on. Default: `false`.
    func restoresTileOnFallArrival(
        tile: Tile,
        at point: GridPoint,
        plane: Plane,
        context: PassiveContext
    ) -> Bool

    /// The sign's memory after a move was taken with `option`.
    ///
    /// `adjustedMovement` is read-only, so a pattern that is only *sometimes*
    /// available cannot spend anything for being used. This is the other half:
    /// offer the option there, charge for it here. Capricorn's climb is the only
    /// user — it puts itself on cooldown for a turn.
    ///
    /// - Returns: The new memory, or `nil` to leave it alone.
    func stateAfterMove(
        option: MovementPattern.MoveOption,
        direction: SwipeDirection,
        context: PassiveContext
    ) -> SignState?

    /// Extra squares to wear alongside the one being landed on.
    ///
    /// `modifyWear` describes one tile's fate and nothing more, so a passive that
    /// moves the impact *elsewhere* needs this as well: spare the landing square
    /// there, name the real targets here.
    ///
    /// Each returned square takes one stage. They do not cascade — an extra
    /// target never produces further extras — so a passive cannot accidentally
    /// wear the whole board.
    func additionalWear(from proposal: WearProposal, context: PassiveContext) -> [GridPoint]

    /// Reacts to everything a move just did, and adds to it.
    ///
    /// The only hook that sees a move *after* the fact. Passives are otherwise
    /// consulted during resolution and cannot observe the state the board settled
    /// into, which is exactly what Gemini's Mirrored Healing (react to repairs)
    /// and Libra's Perfect Balance (react to a row levelling out) need.
    ///
    /// - Parameter events: Everything the move produced, in order.
    /// - Returns: Extra events to apply after it. Return `[]` for no reaction.
    ///   These are **not** re-amended, so a reaction cannot trigger itself.
    func amend(_ events: [GameEvent], context: PassiveContext) -> [GameEvent]

    /// Intercepts a fall that would otherwise end the run.
    ///
    /// Consulted at the exact moment the engine is about to emit `gameOver` for
    /// dropping through Terra. Distinct from `preventsFall`, which stops the fall
    /// from happening — by the time this is called the piece has already fallen
    /// all the way through, and the question is only whether it comes back.
    ///
    /// - Returns: The events to apply *instead* of the game over, or `nil` to let
    ///   the run end.
    func survivesFatalFall(
        at point: GridPoint,
        from plane: Plane,
        context: PassiveContext
    ) -> [GameEvent]?

    /// Whether this sign is currently barred from returning to Astra.
    ///
    /// Scorpio's Shed buys one death at the cost of the way back up.
    func blocksAscent(context: PassiveContext) -> Bool

    /// Replaces a move that would otherwise run off the board.
    ///
    /// Consulted only when the ordinary path is illegal, so it can never
    /// override a legal move. Return the squares to travel instead — normally a
    /// single square, since passing through a mirror is a jump, not a walk.
    ///
    /// Gemini's Mirrors is the only user: from a centre-edge square, moving out
    /// through that edge arrives at the opposite one.
    func wrappedMove(
        from origin: GridPoint,
        direction: SwipeDirection,
        context: PassiveContext
    ) -> [GridPoint]?

    /// The sign's memory after a fall it just prevented.
    ///
    /// Called only when `preventsFall` returned `true`, so a one-shot guard can
    /// spend itself at the moment it actually saves the piece rather than
    /// decaying on a timer. Return `nil` to leave the memory alone.
    func stateAfterPreventingFall(context: PassiveContext) -> SignState?

    /// Overrides which sparkling tile the Pentacle appears on.
    ///
    /// The reveal is normally a random pick among the surviving sparkles. Virgo's
    /// Controlled Landing bends it: whatever square the move is heading for, if
    /// it was sparkling, that is where the coin turns up.
    ///
    /// - Returns: A square from `candidates`, or `nil` to leave the roll alone.
    ///   A returned square outside `candidates` is ignored.
    func preferredRevealPoint(
        among candidates: [GridPoint],
        destination: GridPoint,
        context: PassiveContext
    ) -> GridPoint?

    /// Zodiaction charge this passive awards for the move that just resolved.
    ///
    /// Most signs' charge comes from a passive rather than from the Zodiaction
    /// itself — Aries pays for a streak, Leo for falling, Pisces simply for
    /// being on Astra. Returns pips, and may be negative. Default: `0`.
    func meterBonus(from move: MoveSummary, context: PassiveContext) -> Int
}

// MARK: - WearTiming

/// When a move's wear is charged.
enum WearTiming: Equatable {
    /// The tile the piece lands on. The default for everything grounded.
    case onEntry

    /// The tile the piece leaves. Nothing is charged on arrival, so an airborne
    /// piece can cross a fragile board and only break what it pushes off from.
    case onExit
}

// MARK: - WearProposal

/// The wear about to be dealt to one tile, before passives have their say.
///
/// Passed through `ZodiacPassive.modifyWear(_:context:)` and returned modified.
struct WearProposal: Equatable {
    /// The tile as it stands right now.
    let tile: Tile

    let point: GridPoint
    let plane: Plane

    /// True when the piece arrived here by falling rather than by moving.
    let arrivedByFalling: Bool

    /// How many health stages to advance.
    ///
    /// Zero spares the tile entirely. **Negative repairs it** — Sagittarius'
    /// Safe Landing does not merely refuse to break a badly cracked Terra tile,
    /// it mends one stage back. A passive that wants that returns a negative
    /// here rather than needing a separate healing hook.
    var stages: Int

    /// The sign's memory, editable — this is where a passive records that it
    /// spent a cooldown or a once-per-visit charge.
    var signState: SignState

    /// The health the tile would end at, given `stages`.
    var resultingHealth: TileHealth {
        var health = tile.health
        if stages >= 0 {
            for _ in 0..<stages where health != .hole {
                health = health.damaged
            }
        } else {
            for _ in 0..<(-stages) where health != .healthy {
                health = health.healed
            }
        }
        return health
    }

    /// True when applying this proposal would open a hole.
    var wouldBreak: Bool {
        !tile.health.isHole && resultingHealth.isHole
    }
}

// MARK: - Default implementations

extension ZodiacPassive {
    func adjustedMovement(base: MovementPattern, context: PassiveContext) -> MovementPattern {
        base
    }

    func bonusMoves(context: PassiveContext) -> Int {
        0
    }

    func causesWear(on tile: Tile, at point: GridPoint, plane: Plane, context: PassiveContext) -> Bool {
        true
    }

    func preventsFall(from plane: Plane, at point: GridPoint, context: PassiveContext) -> Bool {
        false
    }

    func wearTiming(context: PassiveContext) -> WearTiming {
        .onEntry
    }

    func modifyWear(_ proposal: WearProposal, context: PassiveContext) -> WearProposal {
        proposal
    }

    func restoresTileOnFallArrival(
        tile: Tile,
        at point: GridPoint,
        plane: Plane,
        context: PassiveContext
    ) -> Bool {
        false
    }

    func stateAfterMove(
        option: MovementPattern.MoveOption,
        direction: SwipeDirection,
        context: PassiveContext
    ) -> SignState? {
        nil
    }

    func additionalWear(from proposal: WearProposal, context: PassiveContext) -> [GridPoint] {
        []
    }

    func amend(_ events: [GameEvent], context: PassiveContext) -> [GameEvent] {
        []
    }

    func survivesFatalFall(
        at point: GridPoint,
        from plane: Plane,
        context: PassiveContext
    ) -> [GameEvent]? {
        nil
    }

    func blocksAscent(context: PassiveContext) -> Bool {
        false
    }

    func wrappedMove(
        from origin: GridPoint,
        direction: SwipeDirection,
        context: PassiveContext
    ) -> [GridPoint]? {
        nil
    }

    func stateAfterPreventingFall(context: PassiveContext) -> SignState? {
        nil
    }

    func preferredRevealPoint(
        among candidates: [GridPoint],
        destination: GridPoint,
        context: PassiveContext
    ) -> GridPoint? {
        nil
    }

    func meterBonus(from move: MoveSummary, context: PassiveContext) -> Int {
        0
    }
}

// MARK: - PassiveContext

/// A read-only snapshot of the game handed to every passive and Zodiaction hook.
///
/// Hooks never receive the engine itself — only this. Add fields here as
/// abilities need more information.
struct PassiveContext {
    /// The sign being controlled.
    let zodiac: Zodiac

    /// The board the piece is currently on.
    let currentBoard: Board

    /// The board below, or `nil` when the piece is already on Terra.
    let boardBelow: Board?

    /// Which plane the piece is on.
    let plane: Plane

    /// Which plane the Nexys island is on.
    let nexysPlane: Plane

    /// Where the piece is standing.
    let piecePoint: GridPoint

    /// Which way the piece is looking.
    ///
    /// Several signs' passives are deterministic on direction, so this is a
    /// first-class input rather than a presentation detail. It updates the
    /// instant a move is committed, before the piece has travelled.
    let facing: SwipeDirection

    /// Moves committed so far this run.
    let moveCount: Int

    /// Current score.
    let score: Int

    /// Current Zodiaction meter, in pips.
    let zodiactionMeter: Int

    /// Where the revealed Pentacle is sitting, if one is out on this plane.
    ///
    /// Anything that rewrites the board wholesale has to be able to leave it
    /// alone — a coin dropped into a hole by an ability that also removed
    /// everywhere a new one could spawn ends the hunt outright.
    let pickupPoint: GridPoint?

    /// What the sign remembers between moves — streaks, cooldowns, per-visit
    /// charges. See `SignState`.
    let signState: SignState

    /// Two independent rolls in `0..<1`, drawn once per move from the engine's
    /// seeded generator.
    ///
    /// Chance-based passives compare against these instead of rolling their own,
    /// which keeps hooks pure functions and keeps a seeded run reproducible.
    /// Two of them so a sign with two chance passives — Sagittarius has exactly
    /// that — does not have both fire or neither on the same coin flip.
    let luck: Double
    let luckAlt: Double

    // MARK: Derived

    /// True when the piece is on the plane its element is strong on.
    ///
    /// The single most common thing a plane-dependent ability needs to ask.
    var isEmpowered: Bool {
        zodiac.element.empoweredPlane == plane
    }

    /// True when the piece is standing on the Nexys island.
    var isOnNexys: Bool {
        plane == nexysPlane && piecePoint == GameRules.nexysPoint
    }
}

// MARK: - PlaceholderPassive

/// The stand-in ability used by all twelve signs until their real designs land.
///
/// Every hook falls through to the protocol defaults, so a piece using this
/// plays by the base rules exactly — on both planes.
struct PlaceholderPassive: ZodiacPassive {
    var displayName: String = "—"
    var summary: String = "Passive not yet implemented."
}

// MARK: - Combining a sign's passives

/// How a sign's two or three passives resolve into one answer.
///
/// The rules are chosen so that adding a passive can only ever be additive or
/// protective, never a silent nerf — no passive can undo another's permission:
///
/// - **Movement** folds in declaration order, so a later passive sees the
///   pattern an earlier one produced.
/// - **Bonus moves** sum.
/// - **Wear** is unanimous: a tile is worn only if *every* passive allows it, so
///   one light-footed passive is enough to spare the tile.
/// - **Fall prevention** is any-of: one passive that catches you is enough.
extension Array where Element == any ZodiacPassive {

    func adjustedMovement(base: MovementPattern, context: PassiveContext) -> MovementPattern {
        reduce(base) { pattern, passive in
            passive.adjustedMovement(base: pattern, context: context)
        }
    }

    func bonusMoves(context: PassiveContext) -> Int {
        reduce(0) { $0 + $1.bonusMoves(context: context) }
    }

    func causesWear(
        on tile: Tile,
        at point: GridPoint,
        plane: Plane,
        context: PassiveContext
    ) -> Bool {
        allSatisfy { $0.causesWear(on: tile, at: point, plane: plane, context: context) }
    }

    func preventsFall(from plane: Plane, at point: GridPoint, context: PassiveContext) -> Bool {
        contains { $0.preventsFall(from: plane, at: point, context: context) }
    }

    /// Any passive that lifts the piece off the ground wins — being airborne is
    /// not something a second passive can partially undo.
    func wearTiming(context: PassiveContext) -> WearTiming {
        contains { $0.wearTiming(context: context) == .onExit } ? .onExit : .onEntry
    }

    /// Folds in declaration order, each passive seeing the previous one's
    /// proposal — including its `signState` edits, so two passives spending
    /// different cooldowns on the same move both stick.
    func modifyWear(_ proposal: WearProposal, context: PassiveContext) -> WearProposal {
        reduce(proposal) { current, passive in
            passive.modifyWear(current, context: context)
        }
    }

    func restoresTileOnFallArrival(
        tile: Tile,
        at point: GridPoint,
        plane: Plane,
        context: PassiveContext
    ) -> Bool {
        contains {
            $0.restoresTileOnFallArrival(tile: tile, at: point, plane: plane, context: context)
        }
    }

    func meterBonus(from move: MoveSummary, context: PassiveContext) -> Int {
        reduce(0) { $0 + $1.meterBonus(from: move, context: context) }
    }

    func stateAfterPreventingFall(context: PassiveContext) -> SignState? {
        for passive in self {
            if let state = passive.stateAfterPreventingFall(context: context) { return state }
        }
        return nil
    }

    func stateAfterMove(
        option: MovementPattern.MoveOption,
        direction: SwipeDirection,
        context: PassiveContext
    ) -> SignState? {
        for passive in self {
            if let state = passive.stateAfterMove(
                option: option, direction: direction, context: context
            ) { return state }
        }
        return nil
    }

    func additionalWear(from proposal: WearProposal, context: PassiveContext) -> [GridPoint] {
        flatMap { $0.additionalWear(from: proposal, context: context) }
    }

    /// Every passive gets to react, in declaration order.
    func amend(_ events: [GameEvent], context: PassiveContext) -> [GameEvent] {
        flatMap { $0.amend(events, context: context) }
    }

    /// First passive that can save the piece does.
    func survivesFatalFall(
        at point: GridPoint,
        from plane: Plane,
        context: PassiveContext
    ) -> [GameEvent]? {
        for passive in self {
            if let rescue = passive.survivesFatalFall(at: point, from: plane, context: context) {
                return rescue
            }
        }
        return nil
    }

    func blocksAscent(context: PassiveContext) -> Bool {
        contains { $0.blocksAscent(context: context) }
    }

    /// First passive that owns this edge wins.
    func wrappedMove(
        from origin: GridPoint,
        direction: SwipeDirection,
        context: PassiveContext
    ) -> [GridPoint]? {
        for passive in self {
            if let path = passive.wrappedMove(from: origin, direction: direction, context: context) {
                return path
            }
        }
        return nil
    }

    /// First passive with an opinion wins, and its answer must still be one of
    /// the sparkles actually on the board.
    func preferredRevealPoint(
        among candidates: [GridPoint],
        destination: GridPoint,
        context: PassiveContext
    ) -> GridPoint? {
        for passive in self {
            if let choice = passive.preferredRevealPoint(
                among: candidates, destination: destination, context: context
            ), candidates.contains(choice) {
                return choice
            }
        }
        return nil
    }
}
