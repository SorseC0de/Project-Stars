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
/// One puff of dust a landing throws up.
struct LandingDust {
    let point: GridPoint

    /// Against the usual landing puff. Two smaller clouds read as a pair of
    /// impacts; two full-sized ones read as the screen going grey.
    let magnitude: CGFloat
}

protocol ZodiacPassive {

    /// Name shown in the info panel.
    var displayName: String { get }

    /// One-line rules text. Should describe both planes when they differ.
    var summary: String { get }

    // MARK: Movement hooks

    /// Whether falling off this plane leaves half of the piece behind.
    ///
    /// Gemini alone. Asked rather than hard-coded so the engine never has to
    /// name a sign — every other rule in this file follows that, and this one
    /// is the most tempting to break because there is exactly one answer.
    func splitsOnDescent(context: PassiveContext) -> Bool

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
    /// Aquarius is airborne and always damages on exit; Aries' Brazen Blaze
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
    /// into, which is exactly what Gemini's Mirrored Mending (react to repairs)
    /// and Libra's Careful Current (react to a row levelling out) need.
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
    /// Scorpio's Samsaric Shed buys one death at the cost of the way back up.
    func blocksAscent(context: PassiveContext) -> Bool

    /// Whether the piece keeps the way it is looking through this move.
    ///
    /// Ordinarily a piece turns to face where it is going. A crab does not: it
    /// scuttles sideways while still watching what it was watching, which is the
    /// whole read of the animal and the reason Cancer's movement is a sidestep
    /// rather than a step.
    ///
    /// Facing is not cosmetic — it decides where Leo's sun hangs, which way
    /// Libra's arms reach, and what counts as sideways next move — so this
    /// changes what a sign can do, not only how it looks.
    func retainsFacing(
        direction: SwipeDirection,
        option: MovementPattern.MoveOption,
        context: PassiveContext
    ) -> Bool

    /// Reweights one effect in the roll that hides a Pentacle.
    ///
    /// Called per effect while a sparkle set is being seeded, before anything is
    /// on the board — so a sign can change *what tends to turn up* without
    /// touching what a coin does when opened. Return `base` to leave it alone.
    ///
    /// Weights are relative within a tier, so a passive wanting a straight swap
    /// should read the other effect's weight rather than hardcode a number.
    func pickupWeight(_ base: Int, for id: PickupID, context: PassiveContext) -> Int

    /// How often a sparkle phase reveals a *second* Pentacle as well as the
    /// first, `0` to `1`.
    ///
    /// The second coin comes up on one of the sparkles the first did not take,
    /// and is rolled independently — so a sign with this sees rare Pentacles
    /// more often simply by drawing more of them. Taking either shatters the
    /// other, so it is a choice rather than a haul.
    func secondPickupChance(context: PassiveContext) -> Double

    /// How often the Pentacle is dragged toward the piece on an ordinary step.
    ///
    /// Distinct from Leo's sun, which drags the coin toward *itself*. Where both
    /// would act the piece wins — see `GameEngine.planPickupPull`.
    func magneticPullChance(context: PassiveContext) -> Double

    /// Whether this move is made on air: holes crossed rather than fallen into,
    /// without the move itself changing shape.
    ///
    /// Distinct from turning the option into a jump. A jump *skips* the ground
    /// between, so it wears nothing and collects nothing; this keeps the move
    /// exactly as it was — a slide still settles on every square and wears every
    /// square — and only removes the falling.
    func walksOnAir(during option: MovementPattern.MoveOption, context: PassiveContext) -> Bool

    /// How often a sparkle phase comes up mirrored, doubling its shape across
    /// the board's middle.
    func mirroredSparkleChance(context: PassiveContext) -> Double

    /// Changes what a Pentacle's charge is worth to this sign.
    ///
    /// Takes the plane rather than a whole `PassiveContext`, because it is asked
    /// from inside a pickup effect — which has its own context and no business
    /// building a passive one.
    func chargeFromPickup(_ base: Int, id: PickupID, plane: Plane) -> Int

    /// Replaces a move that would otherwise run off the board.
    ///
    /// Consulted only when the ordinary path is illegal, so it can never
    /// override a legal move. Return the squares to travel instead — normally a
    /// single square, since passing through a mirror is a jump, not a walk.
    ///
    /// Gemini's Reflective Rifts is the only user: from a centre-edge square, moving out
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
    /// Controlled Compensation bends it: whatever square the move is heading for, if
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

    /// Whether a movement option may be taken along this particular path.
    ///
    /// `adjustedMovement` decides what a sign *can* do; this decides whether it
    /// can do it **here**. The distinction matters for any rule that depends on
    /// what the move would cross — Scorpio's vault, which is only a vault if
    /// there is a hole to clear — because a movement pattern is direction-blind
    /// and cannot see the ground.
    ///
    /// Default: yes. Consulted both when a swipe is resolved and when the reach
    /// selector is built, so an option that will be refused is never offered.
    func allows(
        _ option: MovementPattern.MoveOption,
        direction: SwipeDirection,
        path: [GridPoint],
        context: PassiveContext
    ) -> Bool

    /// An offer this passive wants to make now that the piece has come to rest.
    ///
    /// Returns `nil` — the overwhelming majority — when there is nothing to
    /// offer. A returned `PickupChoice.among` suspends the move and asks; the
    /// answer comes back to `resolveChoice(_:context:)`.
    ///
    /// Asked only once the landing is settled, so the passive is looking at
    /// where the piece actually ended up rather than where it was headed.
    func offersChoice(context: PassiveContext) -> PickupChoice?

    /// What the player's answer to `offersChoice` produces.
    ///
    /// Return an empty array for a declined offer, or for an answer this passive
    /// does not recognise.
    func resolveChoice(_ choice: PickupChoiceResult, context: PassiveContext) -> [GameEvent]

    /// What this sign does when it opens a coin, beyond whatever the coin does.
    ///
    /// Fires at the moment of collection, before the ground under the piece is
    /// consulted — which is the only moment at which `wasSolid` is still
    /// answerable, and the only moment early enough to mend a hole the piece is
    /// standing over. Virgo's Regulated Reboot is the whole reason it exists.
    ///
    /// Default: nothing.
    func collected(
        _ id: PickupID,
        at point: GridPoint,
        on plane: Plane,
        wasSolid: Bool,
        context: PassiveContext
    ) -> [GameEvent]

    /// Whether a fall to `plane` is a **controlled descent** for this sign.
    ///
    /// Presentation only, and the one hook here that is. A fall normally spins
    /// the piece end over end, because for eleven signs out of twelve falling is
    /// something that happened *to* them. For a sign whose descent is
    /// guaranteed to pay — charge on landing, ground mended on arrival — that
    /// tumble is the game lying about what just occurred.
    ///
    /// So those signs keep the shrink, which is distance, and lose the spin,
    /// which is helplessness. Deliberately **not** true for a merely *likely*
    /// payoff: Sagittarius' Lucky Landing is a roll, and a piece that dropped
    /// serenely and then broke the tile anyway would be worse than one that
    /// tumbled either way.
    func fallIsControlled(to plane: Plane, context: PassiveContext) -> Bool

    /// Where a landing throws up its dust, and how much of it.
    ///
    /// Default is `nil`, meaning the one square the piece came down on. A sign
    /// answers only if its impact is somewhere else — Libra lands on two pans
    /// and cracks the squares either side of her, so the dust belongs where the
    /// ground is actually being broken and not under a body that never touched
    /// it.
    ///
    /// Returned as points rather than as a flag, because "which squares does
    /// this landing hit" is the same question `additionalWear` answers and
    /// giving it two answers is how they come apart.
    func landingDust(
        at point: GridPoint,
        context: PassiveContext
    ) -> [LandingDust]?

    /// The chance, per bubble, that one appears alongside this reveal.
    ///
    /// Zero for everybody but Pisces below — see `PiscesAridAquanaut`. Bubbles
    /// are not part of the hunt and do not displace the coin: they are rolled
    /// after it, onto the sparkles it did not take.
    func bubbleChance(context: PassiveContext) -> Double

    /// Whether falling to the plane below spills the meter onto it as bubbles
    /// rather than simply losing it.
    ///
    /// Its own question rather than "would bubbles spawn for me down there",
    /// because that one is asked of the plane the piece is still standing on and
    /// answers no every time — and because a sign could reasonably want one of
    /// these without the other.
    func spillsMeterOnDescent(context: PassiveContext) -> Bool

    /// Whether leaving Astra should repair it.
    ///
    /// True for everyone but Libra, whose whole arrangement is that both boards
    /// persist — an Astra that healed itself every time she went down would make
    /// half of her game disappear behind her. Default: the global rule.
    func restoresPlaneOnDescent(context: PassiveContext) -> Bool

    /// Whether standing on the Nexys should take the piece *down* as well as up.
    ///
    /// The island only ever went one way, because for everyone else the point of
    /// it is the ride home. Libra rides it both ways — see
    /// `LibraJudicatorElevator`. Default: false.
    func ridesNexysDown(context: PassiveContext) -> Bool

    /// Whether an opened Pentacle should be banked rather than set off.
    ///
    /// Capricorn's Celestial Commerce alone. The engine puts the coin in
    /// `SignState.purse` and skips its effect entirely; Z-Charge is exempt at
    /// the engine, since charge cannot be saved as charge. Default: false.
    func banksPickups(_ id: PickupID, context: PassiveContext) -> Bool
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
    /// Variable Voyager does not merely refuse to break a badly cracked Terra tile,
    /// it mends one stage back. A passive that wants that returns a negative
    /// here rather than needing a separate healing hook.
    var stages: Int

    /// What is doing the damage. Drives how much and how it looks — see
    /// `WearCause`. Set it through `caused(by:)` rather than directly, so the
    /// stage count and the identity cannot disagree.
    var cause: WearCause = .landing

    /// Attributes this damage to `cause`, taking its stage count with it.
    ///
    /// The count is the cause's own, resolved for the plane the damage is
    /// happening on — see `WearCause.stages(on:)`. A passive that wants a
    /// different number still assigns `stages` afterwards, which is what the
    /// free footfall does.
    mutating func caused(by newCause: WearCause) {
        cause = newCause
        stages = newCause.stages(on: plane)
    }

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
    func splitsOnDescent(context: PassiveContext) -> Bool { false }

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

    func retainsFacing(
        direction: SwipeDirection,
        option: MovementPattern.MoveOption,
        context: PassiveContext
    ) -> Bool {
        false
    }

    func pickupWeight(_ base: Int, for id: PickupID, context: PassiveContext) -> Int {
        base
    }

    func secondPickupChance(context: PassiveContext) -> Double { 0 }
    func magneticPullChance(context: PassiveContext) -> Double { 0 }

    func walksOnAir(during option: MovementPattern.MoveOption, context: PassiveContext) -> Bool {
        false
    }
    func mirroredSparkleChance(context: PassiveContext) -> Double { 0 }

    func chargeFromPickup(_ base: Int, id: PickupID, plane: Plane) -> Int {
        base
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

    func eventsOnPreventingFall(
        at point: GridPoint,
        on plane: Plane,
        context: PassiveContext
    ) -> [GameEvent] { [] }

    func preferredRevealPoint(
        among candidates: [GridPoint],
        destination: GridPoint,
        context: PassiveContext
    ) -> GridPoint? {
        nil
    }

    func allows(
        _ option: MovementPattern.MoveOption,
        direction: SwipeDirection,
        path: [GridPoint],
        context: PassiveContext
    ) -> Bool { true }

    func offersChoice(context: PassiveContext) -> PickupChoice? { nil }

    func resolveChoice(
        _ choice: PickupChoiceResult,
        context: PassiveContext
    ) -> [GameEvent] { [] }

    func collected(
        _ id: PickupID,
        at point: GridPoint,
        on plane: Plane,
        wasSolid: Bool,
        context: PassiveContext
    ) -> [GameEvent] { [] }

    func fallIsControlled(to plane: Plane, context: PassiveContext) -> Bool { false }

    func landingDust(at point: GridPoint, context: PassiveContext) -> [LandingDust]? { nil }

    func bubbleChance(context: PassiveContext) -> Double { 0 }

    func spillsMeterOnDescent(context: PassiveContext) -> Bool { false }

    func restoresPlaneOnDescent(context: PassiveContext) -> Bool {
        GameRules.astraRestoresOnDescent
    }

    func ridesNexysDown(context: PassiveContext) -> Bool { false }

    func banksPickups(_ id: PickupID, context: PassiveContext) -> Bool { false }

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

    /// Current Zodiaction meter, in pips.
    let zodiactionMeter: Int

    /// What a full meter is for this sign on this plane.
    ///
    /// Carried alongside the meter because "am I full" is a question a passive
    /// can act on — Pisces' surf is offered only at the cap — and the cap varies
    /// by sign and by plane, so a passive cannot work it out from the pip count
    /// alone.
    let zodiactionMeterMax: Int

    /// True while a Zodiaction is what is resolving.
    ///
    /// The difference between a thing you did and a thing that happened to you,
    /// which several rules turn on and none could previously ask. Pisces is the
    /// clear case: going down *on purpose* is a dive, and going down because the
    /// floor gave way is a fall — same destination, opposite events.
    let duringZodiaction: Bool

    /// True when the piece is arriving on a square the player picked, rather
    /// than one something else carried it to. See
    /// `GameEngine.arrivalWasChosen`.
    let arrivalWasChosen: Bool

    /// True when the square was already open when the piece got there, rather
    /// than having broken underfoot. See `GameEngine.arrivedOnOpenGround`.
    let arrivedOnOpenGround: Bool

    /// Where the revealed Pentacles are sitting, on this plane.
    ///
    /// Anything that rewrites the board wholesale has to be able to leave them
    /// alone — a coin dropped into a hole by an ability that also removed
    /// everywhere a new one could spawn ends the hunt outright. Plural because
    /// Sagittarius can have two out at once.
    let pickupPoints: [GridPoint]

    /// The same coins, with what they are.
    ///
    /// `pickupPoints` answers "is there one there"; this answers "which one",
    /// which anything reaching out to *take* a coin needs — Scorpio's sting has
    /// to name the Pentacle it drags back.
    let pickups: [RevealedPickup]

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

    func splitsOnDescent(context: PassiveContext) -> Bool {
        contains { $0.splitsOnDescent(context: context) }
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

    func banksPickups(_ id: PickupID, context: PassiveContext) -> Bool {
        contains { $0.banksPickups(id, context: context) }
    }

    func fallIsControlled(to plane: Plane, context: PassiveContext) -> Bool {
        contains { $0.fallIsControlled(to: plane, context: context) }
    }

    /// The first answer wins. Two passives moving the same dust to two different
    /// places is a contradiction rather than a sum, and nothing in the game has
    /// two signs' worth of landing at once.
    func landingDust(at point: GridPoint, context: PassiveContext) -> [LandingDust]? {
        compactMap { $0.landingDust(at: point, context: context) }.first
    }

    /// The best offer, not the sum. Two passives that both want bubbles want
    /// *bubbles*, not twice as many.
    func bubbleChance(context: PassiveContext) -> Double {
        map { $0.bubbleChance(context: context) }.max() ?? 0
    }

    func spillsMeterOnDescent(context: PassiveContext) -> Bool {
        contains { $0.spillsMeterOnDescent(context: context) }
    }

    /// One refusal is enough: a sign that keeps its Astra keeps it.
    func restoresPlaneOnDescent(context: PassiveContext) -> Bool {
        allSatisfy { $0.restoresPlaneOnDescent(context: context) }
    }

    func ridesNexysDown(context: PassiveContext) -> Bool {
        contains { $0.ridesNexysDown(context: context) }
    }

    func collected(
        _ id: PickupID,
        at point: GridPoint,
        on plane: Plane,
        wasSolid: Bool,
        context: PassiveContext
    ) -> [GameEvent] {
        flatMap {
            $0.collected(id, at: point, on: plane, wasSolid: wasSolid, context: context)
        }
    }

    /// Every passive has to agree. A refusal is a rule about the ground, and a
    /// second passive has no standing to overrule one.
    func allows(
        _ option: MovementPattern.MoveOption,
        direction: SwipeDirection,
        path: [GridPoint],
        context: PassiveContext
    ) -> Bool {
        allSatisfy { $0.allows(option, direction: direction, path: path, context: context) }
    }

    /// The first offer anyone wants to make. One at a time on purpose: two
    /// questions stacked on a single landing is a queue the replay has no way
    /// to express, and no sign has ever needed it.
    func offersChoice(context: PassiveContext) -> PickupChoice? {
        for passive in self {
            if let offer = passive.offersChoice(context: context) { return offer }
        }
        return nil
    }

    func resolveChoice(
        _ choice: PickupChoiceResult,
        context: PassiveContext
    ) -> [GameEvent] {
        for passive in self {
            let events = passive.resolveChoice(choice, context: context)
            if !events.isEmpty { return events }
        }
        return []
    }

    func stateAfterPreventingFall(context: PassiveContext) -> SignState? {
        for passive in self {
            if let state = passive.stateAfterPreventingFall(context: context) { return state }
        }
        return nil
    }

    func eventsOnPreventingFall(
        at point: GridPoint,
        on plane: Plane,
        context: PassiveContext
    ) -> [GameEvent] {
        flatMap { $0.eventsOnPreventingFall(at: point, on: plane, context: context) }
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

    /// Any passive that wants the facing held, holds it.
    func retainsFacing(
        direction: SwipeDirection,
        option: MovementPattern.MoveOption,
        context: PassiveContext
    ) -> Bool {
        contains { $0.retainsFacing(direction: direction, option: option, context: context) }
    }

    /// Each passive sees what the one before it decided, so two reweights
    /// compose rather than one silently winning.
    func pickupWeight(_ base: Int, for id: PickupID, context: PassiveContext) -> Int {
        reduce(base) { $1.pickupWeight($0, for: id, context: context) }
    }

    /// The best offer among the sign's passives.
    func secondPickupChance(context: PassiveContext) -> Double {
        map { $0.secondPickupChance(context: context) }.max() ?? 0
    }

    func magneticPullChance(context: PassiveContext) -> Double {
        map { $0.magneticPullChance(context: context) }.max() ?? 0
    }

    func walksOnAir(during option: MovementPattern.MoveOption, context: PassiveContext) -> Bool {
        contains { $0.walksOnAir(during: option, context: context) }
    }

    func mirroredSparkleChance(context: PassiveContext) -> Double {
        map { $0.mirroredSparkleChance(context: context) }.max() ?? 0
    }

    func chargeFromPickup(_ base: Int, id: PickupID, plane: Plane) -> Int {
        reduce(base) { $1.chargeFromPickup($0, id: id, plane: plane) }
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
