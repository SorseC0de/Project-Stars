//
//  GameEngine.swift
//  Project Stars
//
//  The complete rules of the game, with no dependency on SwiftUI.
//

import Foundation

// MARK: - Piece

/// The player's piece: which sign it is, where it stands, and which way it
/// looks.
struct Piece: Equatable {
    var zodiac: Zodiac
    var plane: Plane
    var point: GridPoint

    /// The direction the piece is facing.
    ///
    /// Updated on every committed move, including one that is blocked from
    /// completing. Several signs' passives read this, so it is real state rather
    /// than a presentation detail.
    var facing: SwipeDirection = .up
}

// MARK: - RevealedPickup

/// A pickup that has materialised on a specific square and is waiting to be
/// collected.
struct RevealedPickup: Equatable {
    let id: PickupID
    let plane: Plane
    let point: GridPoint

    /// Which coin this *is*, as opposed to which effect it holds.
    ///
    /// Two Tears on the board at once are two things; a Tear destroyed and a
    /// Tear revealed somewhere else a moment later are two different things
    /// again. Nothing else here can tell those cases apart — `id` is the effect
    /// and `point` is where it happens to be — and the view layer needs to,
    /// because an identity it reuses is an identity it *animates between*. That
    /// is how a destroyed Pentacle came to slide across the board to the next
    /// glow phase.
    ///
    /// Counted rather than randomised so a seeded run stays reproducible.
    let serial: Int
}

// MARK: - GameEngine

/// The authoritative game state and rules.
///
/// A value type with no reference to any view, timer, or framework. Two methods
/// matter:
///
/// - ``plan(_:)`` works out everything a swipe causes and returns it as an
///   ordered list of `GameEvent`s. All randomness is resolved here.
/// - ``apply(_:)`` performs a single event. Applying a plan's events in order
///   produces exactly the state the plan predicted.
///
/// Splitting the two is what lets the UI animate a move step by step while the
/// simulation stays a pure function of (state, input, seed).
///
/// - Important: The game is **move-based**. Nothing in this type changes except
///   as the consequence of a committed move or a popped Zodiaction. There are no
///   timers and no elapsed-time inputs.
struct GameEngine {

    // MARK: Stored state

    /// One board per plane.
    private(set) var boards: [Plane: Board]

    /// The plane the Nexys island is currently on.
    ///
    /// The island exists in exactly one place at a time: the centre square of
    /// this plane is the indestructible Nexys, and the centre square of the
    /// other plane is a chasm. `applyNexysLayout()` keeps that true.
    private(set) var nexysPlane: Plane

    /// The player's piece.
    private(set) var piece: Piece

    /// The sparkling tiles currently telegraphing a pickup, if any.
    ///
    /// Non-nil only during a **sparkle phase**, which ends the moment the player
    /// commits a move.
    private(set) var sparkles: SparkleSet?

    /// The pickup hiding in the current sparkle set.
    ///
    /// The engine knows *which* pickup from the moment the sparkles appear, but
    /// its square is not decided until the player commits a move.
    private(set) var pendingPickup: PickupID?

    /// The pickup once it has appeared on the board, during a **pickup phase**.
    /// Every Pentacle currently out on the board.
    ///
    /// Usually one. Sagittarius' Fortunate Find can put a second one up, so the
    /// rest of the engine has to cope with a set rather than a single coin —
    /// taking either shatters the other, so it is never more than briefly two.
    private(set) var revealedPickups: [RevealedPickup] = []

    #if DEBUG
    /// Forces the next Pentacle to be this one, whatever the roll says.
    ///
    /// Cleared as soon as it is used, so it stages exactly one coin. Debug
    /// builds only — the Astral Bolt is one draw in four hundred, which is the
    /// whole design and completely impractical to test against.
    var debugNextPickup: PickupID?
    #endif

    /// The square currently popped up, if any.
    ///
    /// Deliberately *not* derived from `revealedPickup`. A tile pops up to
    /// present a coin, but it outlives it: the coin can be taken, destroyed, or
    /// dragged off by Leo's sun, and the square stays raised until somebody
    /// stands on it. Deriving one from the other made a raised tile teleport
    /// after a coin that had been pulled away from it.
    private(set) var raisedTiles: [RevealedPickup] = []

    /// Pentacles swept up mid-journey, waiting for the piece to stop.
    ///
    /// Borrowed from party games: crossing a coin does not interrupt the
    /// movement, it queues. The piece carries it visibly and the effect runs
    /// once it has come to rest — which also means an effect that moves the
    /// piece cannot fire while it is already moving.
    private(set) var carriedPickups: [RevealedPickup] = []

    /// A Pentacle that has been opened but is waiting on the player to answer a
    /// question before it can resolve. See `planChoice(_:)`.
    private(set) var pendingChoice: (source: ChoiceSource, kind: PickupChoice)?

    /// True for the duration of a move a passive is carrying on the wind.
    ///
    /// Not on `SignState`: it belongs to *this move*, not to the run, and it is
    /// set and cleared inside a single `plan` — so putting it in the sign's
    /// memory would be a lie about its lifetime.
    private var airborneThisMove = false

    /// True while the piece is arriving somewhere **the player picked**.
    ///
    /// An ordinary move, and any effect that stopped to ask which square — a
    /// warp the player aimed, a corner they chose to fly to. False for anything
    /// that carried the piece off on its own: a slide from Astral Brook, a fall,
    /// a Zodiaction that scatters you.
    ///
    /// Leo's Courageous Charge is the reason this exists. A reward for walking
    /// onto a hole *on purpose* has to be able to tell that apart from being
    /// dumped into one, or it is a reward for being unlucky.
    private var arrivalWasChosen = false

    private(set) var moveCount: Int

    /// Hands out `RevealedPickup.serial`. Only ever counts up.
    private var pickupSerial = 0
    private(set) var pickupsCollected: Int

    /// Charge toward the current sign's Zodiaction.
    private(set) var zodiactionMeter: Int

    /// What the current sign remembers between moves. Only ever changed by
    /// `GameEvent.signStateChanged` — see `SignState` for why.
    private(set) var signState: SignState

    /// Two per-move rolls handed to chance-based passives, redrawn at the start
    /// of every plan so hooks can stay pure functions of their context.
    private(set) var luck: Double
    private(set) var luckAlt: Double

    /// Why the run ended, or `nil` while it is still going.
    private(set) var gameOverReason: GameOverReason?

    /// The seeded generator. Only planning and setup draw from it.
    private(set) var rng: SeededRandom

    // MARK: Derived

    var isGameOver: Bool { gameOverReason != nil }

    /// The board the piece is standing on.
    var currentBoard: Board { self[piece.plane] }

    /// Pips needed to pop the current sign's Zodiaction.
    var zodiactionMeterMax: Int { piece.zodiac.zodiaction.meterMax(on: piece.plane) }

    /// True when the Zodiaction can be popped right now.
    var isZodiactionReady: Bool {
        guard !isGameOver else { return false }

        let zodiaction = piece.zodiac.zodiaction
        let context = passiveContext

        // A free pop needs no meter — see `Zodiaction.ignoresMeter`.
        guard zodiaction.ignoresMeter(context: context)
            || zodiactionMeter >= zodiactionMeterMax
        else { return false }

        // Asked here rather than only at the moment of firing, so the panel can
        // show it as unavailable instead of letting the player spend a full
        // meter on nothing.
        return zodiaction.canActivate(context: context)
    }

    /// True when the piece is standing on the Nexys island.
    var isOnNexys: Bool {
        piece.plane == nexysPlane && piece.point == GameRules.nexysPoint
    }

    /// Whether `point` on `plane` is the Nexys island.
    func isNexys(_ point: GridPoint, on plane: Plane) -> Bool {
        plane == nexysPlane && point == GameRules.nexysPoint
    }

    subscript(plane: Plane) -> Board {
        get {
            guard let board = boards[plane] else {
                preconditionFailure("Missing board for plane \(plane.rawValue)")
            }
            return board
        }
        set { boards[plane] = newValue }
    }

    // MARK: - Lifecycle

    /// Starts a fresh run.
    ///
    /// The piece begins standing on the Nexys island at the centre of Astra, and
    /// a sparkle set is rolled immediately, so the "there is always a pickup
    /// available" guarantee holds from the very first frame.
    ///
    /// - Parameters:
    ///   - zodiac: The sign to control.
    ///   - seed: Fixed seed for a reproducible run, or `nil` for a random one.
    init(zodiac: Zodiac, seed: UInt64? = nil) {
        self.boards = Dictionary(uniqueKeysWithValues: Plane.allCases.map { ($0, Board()) })
        self.nexysPlane = GameRules.startingNexysPlane
        self.piece = Piece(
            zodiac: zodiac,
            plane: GameRules.startingPlane,
            point: GameRules.startingPoint,
            facing: GameRules.startingFacing
        )
        self.sparkles = nil
        self.pendingPickup = nil
        self.revealedPickups = []
        self.raisedTiles = []
        self.carriedPickups = []
        self.pendingChoice = nil
        self.moveCount = 0
        self.pickupsCollected = 0
        self.zodiactionMeter = 0
        self.signState = SignState()
        self.luck = 0
        self.luckAlt = 0
        self.gameOverReason = nil
        self.rng = seed.map { SeededRandom(seed: $0) } ?? SeededRandom()

        applyNexysLayout()

        // Opening sparkle set. Applied directly rather than replayed as an
        // animation, because there is no move to animate yet.
        let openingPlane = piece.plane
        let openingBoard = self[openingPlane]
        let openingPoint = piece.point
        let openingWeighting = pickupWeighting()
        let mirrorChance = piece.zodiac.passives.mirroredSparkleChance(context: passiveContext)
        if let opening = Self.rollSparkles(
            on: openingPlane,
            board: openingBoard,
            piecePoint: openingPoint,
            weighting: openingWeighting,
            mirrorChance: mirrorChance,
            using: &rng
        ).map({ staged($0) }) {
            apply(opening)
        }
    }

    /// Stamps the Nexys island and its chasm onto the two boards.
    ///
    /// Called at setup and after every `nexysMoved` event. Idempotent.
    private mutating func applyNexysLayout() {
        let point = GameRules.nexysPoint
        for plane in Plane.allCases {
            self[plane][point] = (plane == nexysPlane) ? .nexys : .chasm
        }
    }

    // MARK: - Planning

    /// Works out everything a swipe in `direction` causes.
    ///
    /// This is the only place randomness is consumed during play. The returned
    /// events are a complete, deterministic script of the move; nothing is left
    /// for ``apply(_:)`` to decide.
    ///
    /// - Note: `mutating` only because it advances the generator. Every other
    ///   part of the state is untouched — the move is simulated on a private
    ///   copy, and the caller is expected to apply the returned events.
    /// - Parameter reach: Which of the distances available in `direction` the
    ///   player's swipe selected. `0` is the nearest. Ignored by patterns with a
    ///   single option that way, which is most of them.
    mutating func plan(_ direction: SwipeDirection, reach: Int = 0) -> [GameEvent] {
        guard !isGameOver else { return [] }

        // `sim` is where the move is played out. Only its RNG is carried back.
        var sim = self
        defer { self.rng = sim.rng }

        // Draw this move's luck up front so chance-based passives can stay pure
        // functions of their context rather than each rolling their own.
        sim.luck = Double(sim.rng.next() % 10_000) / 10_000
        sim.luckAlt = Double(sim.rng.next() % 10_000) / 10_000
        self.luck = sim.luck
        self.luckAlt = sim.luckAlt

        guard let move = sim.resolvedMove(for: direction, reach: reach) else {
            return [.moveBlocked(direction: direction)]
        }

        // Some signs cross a long move on the wind — see
        // `ZodiacPassive.walksOnAir(during:context:)`. Scoped to this move, and
        // cleared however it ends.
        sim.airborneThisMove = sim.piece.zodiac.passives.walksOnAir(
            during: move.option,
            context: sim.passiveContext
        )
        defer { sim.airborneThisMove = false }

        // A swipe is the player choosing a square, whatever else happens later
        // in the move.
        sim.arrivalWasChosen = true
        defer { sim.arrivalWasChosen = false }

        let origin = sim.piece.point
        let startingPlane = sim.piece.plane
        // Captured before `moveCommitted` turns the piece: "sideways" is
        // measured against where it *was* looking.
        let facingBefore = sim.piece.facing
        var events: [GameEvent] = []

        /// Records an event and folds it into the simulation, so later steps
        /// see the board as it will actually be.
        func commit(_ event: GameEvent) {
            events.append(event)
            sim.apply(event)
        }

        // 1. Committing the move ends the sparkle phase: the sparkles vanish and
        //    the pickup appears on one of the tiles they occupied, all as the
        //    piece begins its hop.
        var revealedThisMove = false
        for reveal in sim.rollPickupReveal(destination: move.destination) {
            commit(reveal)
            revealedThisMove = true
        }

        // Arriving through a rift closes the torn set.
        if move.usedRift, sim.signState.terraRifts {
            var closed = sim.signState
            closed.terraRifts = false
            commit(.signStateChanged(closed))
        }

        // 2. Commit: the move counts, and the piece turns to face the way it is
        //    going, before it has gone anywhere.
        // …unless a passive says the piece keeps watching where it was.
        // Cancer's Seafoam Scuttle does exactly that.
        let keepsFacing = sim.piece.zodiac.passives.retainsFacing(
            direction: direction,
            option: move.option,
            context: sim.passiveContext
        )
        commit(.moveCommitted(direction: keepsFacing ? facingBefore : direction))

        // 2b. Airborne signs pay their wear to the tile they are pushing off
        //     from, not the one they are about to reach. Charged here, while the
        //     piece is still standing on it.
        // A slide charges the tile it pushes off from as well as the one it
        // reaches — those two ends are the only ground it touches, so between
        // them they carry the whole move's wear.
        let departure = sim.departCurrentTile(force: move.style == .slide)
        events += departure.events

        // A jump touches nothing it flies over — not the ground, and not what is
        // standing on it. Sailing past a Pentacle is the same rule as sailing
        // past a cracked tile: a leap is *not being there*, and a coin scooped
        // out of the air while the tile beneath it went unmarked never read as
        // consistent.
        let flownOver: [GridPoint] = []

        // 3. Travel. A slide walks each square in turn and wears every one; a
        //    jump touches only the destination. Either way, a tile that breaks
        //    underfoot drops the piece there and the rest of the path is
        //    abandoned.
        var landing = sim.travel(move.path, style: move.style)
        events += landing.events
        // Fold the departure's tallies in (its events already went out above) so
        // the move summary counts wear dealt on exit as wear dealt.
        landing.tilesWorn += departure.tilesWorn
        landing.tilesBroken += departure.tilesBroken

        var collectedPickup: PickupID?

        if !sim.isGameOver {

            // 4. Collecting the pickup, and whatever it does.
            // Landing on the coin is already handled inside `settle`, which
            // opens it before the ground check. This second pass is only for a
            // Pentacle the move *passed over* — the squares a vault flew across.
            let sweep = sim.resolvePickupCollection(covering: landing.covered + flownOver)
            events += sweep.events
            collectedPickup = landing.collectedPickup ?? sweep.pickup

            // 4b. Leo's sun drags the coin a square closer to itself. Before
            //     the reachability check below, so a coin dragged onto a hole is
            //     destroyed by the same rule that governs any coin over a hole.
            let pulled = sim.planPickupPull()
            events += pulled

            // A coin dragged onto the square the piece is standing on has
            // arrived, and arriving is collecting. Checked after the pull rather
            // than only on landing, because on this turn the *coin* did the
            // moving — Leo's Magnetic Mane and its sun both do exactly that.
            if !pulled.isEmpty {
                let gathered = sim.resolvePickupCollection()
                events += gathered.events
                landing.collectedPickup = landing.collectedPickup ?? gathered.pickup
            }

            // 5. Keep a Pentacle reachable. See `ensurePentacleAvailable`.
            events += sim.ensurePentacleAvailable(previousPlane: startingPlane)
        }

        // 5a. Some options cost something to have taken — Capricorn's climb puts
        //     itself on cooldown. Asked after the move so a climb that never
        //     happened is never charged for.
        if let spent = sim.piece.zodiac.passives.stateAfterMove(
            option: move.option,
            direction: direction,
            context: sim.passiveContext
        ), spent != sim.signState {
            commit(.signStateChanged(spent))
        }

        // 5b. Passives that react to what the move did rather than to what it
        //     was doing — Gemini mirroring repairs downward, Libra levelling a
        //     row that has just gone uniform. Their output is not itself
        //     amended, so a reaction cannot retrigger itself.
        let reactions = sim.piece.zodiac.passives.amend(events, context: sim.passiveContext)
        for reaction in reactions {
            if let allowed = sim.sheltered(reaction) { commit(allowed) }
        }

        // 6. Fold the move into the sign's memory: advance the direction
        //    streak, then tick every cooldown and buff down by one. Done before
        //    charging so a streak pays out on the move that extended it.
        var updatedState = sim.signState
        updatedState.recordMove(direction: direction)
        updatedState.recordHoleJumps(landing.holesJumped)
        updatedState.tickTimers()
        if updatedState != sim.signState {
            commit(.signStateChanged(updatedState))
        }

        // 7. Charge the Zodiaction off what the move amounted to. Built before
        //    the call so the summary is not read while `sim` is being mutated.
        let nexysPoint = GameRules.nexysPoint
        let walkedToNexys = move.path.last == nexysPoint && !landing.fell

        // A jump flies over the squares between origin and destination; any of
        // those that were open are holes it cleared. A slide settles on every
        // square it crosses, so it can never clear one.
        if move.style == .jump, !landing.fell {
            landing.holesJumped = Self.squaresBetween(origin, move.destination)
                .filter { !sim[startingPlane][$0].isSolid }
                .count
        }
        let summary = MoveSummary(
            direction: direction,
            origin: origin,
            destination: move.destination,
            startingPlane: startingPlane,
            endingPlane: sim.piece.plane,
            restingPoint: sim.piece.point,
            tilesWorn: landing.tilesWorn,
            tilesBroken: landing.tilesBroken,
            fell: landing.fell,
            ascended: landing.ascended,
            collectedPickup: collectedPickup,
            collectedOnRevealTile: collectedPickup != nil && revealedThisMove,
            arrivedAtNexysByEffect: sim.piece.point == nexysPoint
                && sim.isOnNexys
                && !walkedToNexys,
            wasSideways: facingBefore.perpendicular.contains(direction),
            holesJumped: landing.holesJumped,
            endedRun: sim.isGameOver
        )
        events += sim.chargeSuper(for: summary)

        // TODO: `ZodiacPassive.bonusMoves` and the forced-movement pickups both
        // need a follow-up move appended here. Deferred until those designs are
        // specified — the hook exists but nothing returns a non-zero value yet.

        return events
    }

    /// Fills the Zodiaction meter outright.
    ///
    /// Returns an event rather than assigning, so it travels the same path as
    /// every other state change and cannot desync a replay — the rule this
    /// project has broken twice by taking the shortcut.
    ///
    /// Exposed for the debug key. Nothing in play grants a full meter directly;
    /// signs charge through `meterBonus` and `meterGain`.
    mutating func planFillZodiaction() -> [GameEvent] {
        guard !isGameOver, zodiactionMeter < zodiactionMeterMax else { return [] }
        return [.zodiactionMeterChanged(to: zodiactionMeterMax)]
    }

    /// Sends the Nexys island to the other plane, on its own.
    ///
    /// The same move `NexysShiftEffect` makes, planned properly rather than
    /// applied as a bare event — because the island may have been the only thing
    /// holding the piece up. Losing it has to drop the piece, and dropping to a
    /// new plane has to roll a fresh sparkle phase, both of which fall out of
    /// reusing the ordinary machinery.
    ///
    /// Exposed for the debug key; the Pentacle goes through
    /// `applyEffect(_:choice:)` as usual.
    mutating func planNexysShift() -> [GameEvent] {
        guard !isGameOver else { return [] }

        var sim = self
        defer { self.rng = sim.rng }

        var events: [GameEvent] = []
        func commit(_ event: GameEvent) {
            events.append(event)
            sim.apply(event)
        }

        let previousPlane = sim.piece.plane
        commit(.nexysMoved(to: sim.nexysPlane.opposite, carryingPiece: false))

        // Standing where the island used to be is standing on a chasm. `settle`
        // wears nothing here — a chasm cannot be worn — it only drops the piece.
        if !sim[sim.piece.plane][sim.piece.point].isSolid {
            events += sim.settle(arrivedByFalling: false).events
        }

        events += sim.ensurePentacleAvailable(previousPlane: previousPlane)
        return events
    }

    /// Fires the current sign's super, if it is charged.
    ///
    /// Separate from ``plan(_:)`` because a super is its own player action, not
    /// part of a move. It still produces an event list and is replayed the same
    /// way.
    mutating func planZodiaction() -> [GameEvent] {
        guard isZodiactionReady else { return [] }

        var sim = self
        defer { self.rng = sim.rng }

        var events: [GameEvent] = []
        func commit(_ event: GameEvent) {
            events.append(event)
            sim.apply(event)
        }

        let planeBefore = sim.piece.plane
        let pointBefore = sim.piece.point

        // A Zodiaction is an action, and every action is one turn. Committed
        // *first*, with the facing unchanged, because a turn beginning is what
        // ends the sparkle phase — the coin has to be on the board before a
        // teleport can land on it.
        //
        // Without this a pop was the one thing in the game that happened outside
        // of time: no move counted, no cooldown ticked, and the glow phase sat
        // there refusing to become a Pentacle. Reported against Aquarius, true
        // of all twelve.
        for reveal in sim.rollPickupReveal(destination: sim.piece.point) {
            commit(reveal)
        }
        commit(.moveCommitted(direction: sim.piece.facing))

        commit(.zodiactionFired(zodiac: sim.piece.zodiac, plane: sim.piece.plane))

        // Context read into a local first: it reads `sim`, and passing `&sim.rng`
        // in the same call would be overlapping access to the same value.
        let zodiactionContext = sim.passiveContext
        for event in sim.piece.zodiac.zodiaction.activate(
            context: zodiactionContext,
            generator: &sim.rng
        ) {
            guard let allowed = sim.sheltered(event) else { continue }
            commit(allowed)
            for sweep in sim.gatherIfCrossed(allowed) { commit(sweep) }
        }

        // A Zodiaction that carried the piece across coins opens them here, for
        // the same reason a Pentacle's slide does: once it has stopped.
        events += sim.openCarriedPickups()

        // Asked the player something? Then nothing below can be decided yet —
        // the meter is still spent, because the ability was used, but where the
        // piece ends up is the player's to say. `planChoice` resumes it.
        if sim.pendingChoice != nil {
            if !sim.piece.zodiac.zodiaction.ignoresMeter(context: sim.passiveContext) {
                commit(.zodiactionMeterChanged(to: 0))
            }
            events += sim.tickForTurn()
            return events
        }

        // Arriving somewhere new is a landing, and so is the floor leaving.
        //
        // Both halves matter. Pisces' Downstream sweeps the piece across the
        // board and has to pick up whatever it comes to rest on; Libra's
        // Balancing Breeze turns every healthy Astra tile into a hole, its own
        // square included, and without the second half the piece stood on air.
        // The same guarantee `applyEffect` already gives a Pentacle.
        let moved = sim.piece.plane != planeBefore || sim.piece.point != pointBefore
        let groundGone = !sim[sim.piece.plane][sim.piece.point].isSolid

        if !sim.isGameOver, moved || groundGone {
            events += sim.settle(arrivedByFalling: false, wearsOnArrival: false).events
        }

        if !sim.piece.zodiac.zodiaction.ignoresMeter(context: sim.passiveContext) {
            commit(.zodiactionMeterChanged(to: 0))
        }

        events += sim.tickForTurn()

        // A Zodiaction can change plane too — Taurus flops through Astra, Pisces
        // swims back up — so it owes the same guarantee a move does.
        events += sim.ensurePentacleAvailable(previousPlane: planeBefore)
        return events
    }

    /// Ages the sign's memory by one turn.
    ///
    /// The half of step 6 in `plan(_:)` that is not about direction: a
    /// Zodiaction advances no streak — it is not a step in any direction — but
    /// it is a turn, so everything counting turns has to hear about it.
    private mutating func tickForTurn() -> [GameEvent] {
        var aged = signState
        aged.tickTimers()
        guard aged != signState else { return [] }
        let event = GameEvent.signStateChanged(aged)
        apply(event)
        return [event]
    }

    // MARK: - Move queries

    /// A resolved move: every square it passes through, and how it travels.
    struct ResolvedMove {
        /// Squares the piece will enter, in order, excluding its current one.
        /// A jump has exactly one; a slide has one per square crossed.
        let path: [GridPoint]

        /// How it covers the ground.
        let style: MovementStyle

        /// The pattern option this came from, so a passive can be asked whether
        /// taking it costs anything.
        let option: MovementPattern.MoveOption

        /// Where it ends up if nothing interrupts it.
        var destination: GridPoint

        /// True when this move goes through one of Gemini's rifts.
        var usedRift = false

        init(path: [GridPoint], style: MovementStyle, option: MovementPattern.MoveOption, origin: GridPoint) {
            self.path = path
            self.style = style
            self.option = option
            self.destination = path.last ?? origin
        }
    }

    /// What a swipe in `direction` would do, or `nil` if it has nowhere to go.
    ///
    /// Holes and the Nexys chasm are deliberately *not* excluded — moving onto
    /// one is legal, and is how the player descends to Terra.
    func resolvedMove(for direction: SwipeDirection, reach: Int = 0) -> ResolvedMove? {
        let movement = piece.zodiac.passives.adjustedMovement(
            base: piece.zodiac.movement,
            context: passiveContext
        )
        guard let option = movement.option(
            for: direction,
            facing: piece.facing,
            reach: reach
        ) else { return nil }

        let path = movement.path(from: piece.point, direction: direction, option: option)
        // The whole path has to fit on the board, not just its end: a slide
        // cannot run off the edge and come back.
        if path.isEmpty || !path.allSatisfy({ currentBoard.contains($0) }) {
            // Unless a passive owns that edge. Gemini's mirrors turn the four
            // centre-edge squares into doorways rather than walls, so an
            // otherwise illegal move becomes a jump to the opposite side.
            // Asked of the rifts too when they have been left standing, since
            // the sign holding the board no longer has the passive that owns
            // them.
            let wrap = piece.zodiac.passives.wrappedMove(
                from: piece.point,
                direction: direction,
                context: passiveContext
            ) ?? lingeringRift(from: piece.point, direction: direction)

            if let wrapped = wrap,
               wrapped.allSatisfy({ currentBoard.contains($0) }) {
                var through = ResolvedMove(
                    path: wrapped,
                    style: .jump,
                    option: MovementPattern.MoveOption(.any, distance: 1, style: .jump),
                    origin: piece.point
                )
                through.usedRift = true
                return through
            }
            return nil
        }

        // A sign may refuse an option for reasons the pattern cannot see —
        // Scorpio's vault needs a hole under it. Checked after the path exists,
        // since that is the only thing that says what the move would cross.
        guard piece.zodiac.passives.allows(
            option, direction: direction, path: path, context: passiveContext
        ) else { return nil }

        return ResolvedMove(path: path, style: option.style, option: option, origin: piece.point)
    }

    /// Every distance available in `direction` right now, nearest first.
    ///
    /// Drives the on-screen reach selector. Goes through `adjustedMovement` so a
    /// passive that withholds an option — Capricorn's climb on cooldown — is
    /// reflected in what the player is offered, rather than being shown a move
    /// that will not happen.
    func moveOptions(for direction: SwipeDirection) -> [MovementPattern.MoveOption] {
        let movement = piece.zodiac.passives
            .adjustedMovement(base: piece.zodiac.movement, context: passiveContext)

        return movement.options(for: direction, facing: piece.facing).filter { option in
            let path = movement.path(from: piece.point, direction: direction, option: option)
            return piece.zodiac.passives.allows(
                option, direction: direction, path: path, context: passiveContext
            )
        }
    }

    /// The square a swipe would end on, or `nil` if it has nowhere to go.
    func destination(for direction: SwipeDirection, reach: Int = 0) -> GridPoint? {
        resolvedMove(for: direction, reach: reach)?.destination
    }

    // MARK: - Cursor

    /// What the destination cursor is sitting on.
    enum CursorStatus: Equatable {
        /// Solid ground, undamaged. Also the Nexys, which never breaks.
        case clear
        /// A cracked tile.
        case damaged
        /// A badly cracked tile — one more landing and it goes.
        case badlyDamaged
        /// A hole, or the Nexys chasm. Landing here drops the piece.
        case open
        /// Off the board. The move cannot be made.
        case impossible
    }

    /// Where the piece is aimed, and what is there.
    struct Cursor: Equatable {
        /// The projected destination. **May be off the board** — the cursor is
        /// deliberately allowed to hang over the edge so the player can see that
        /// a move is impossible rather than just finding it does nothing.
        let point: GridPoint
        let status: CursorStatus
    }

    /// The destination cursor, projected along the piece's current facing.
    ///
    /// Always exists: this is a standing readout of "where would I go if I moved
    /// the way I am looking", not something that appears only on valid moves.
    /// - Parameters:
    ///   - direction: Where to project. Defaults to the piece's facing; the panel
    ///     passes the live drag instead while one is in progress.
    ///   - reach: Which distance to project, for signs that offer several. This
    ///     is what lets the player *see* how far a longer drag will take them
    ///     before letting go.
    func cursor(direction: SwipeDirection? = nil, reach: Int = 0) -> Cursor {
        let heading = direction ?? piece.facing
        let movement = piece.zodiac.passives.adjustedMovement(
            base: piece.zodiac.movement,
            context: passiveContext
        )

        // Project even when the pattern has no move that way, so the cursor
        // still has somewhere to sit.
        let step = heading.unitOffset
        let distance = movement.option(for: heading, facing: piece.facing, reach: reach)?.distance ?? 1
        let point = GridPoint(
            piece.point.x + step.dx * distance,
            piece.point.y + step.dy * distance
        )

        guard currentBoard.contains(point) else {
            return Cursor(point: point, status: .impossible)
        }

        let tile = currentBoard[point]
        var status: CursorStatus = switch tile.kind {
        case .chasm: .open
        case .nexys: .clear
        case .normal:
            switch tile.health {
            case .healthy: .clear
            case .cracked: .damaged
            case .badlyCracked: .badlyDamaged
            case .hole: .open
            }
        }

        // Red means *you will fall*. If this piece cannot fall — the Astral
        // Bolt's star, or a passive holding it up — then open ground is simply
        // ground, and saying otherwise is the cursor lying about the one thing
        // it exists to report.
        if status == .open, !tile.isSolid, wouldSurvive(point) {
            status = .clear
        }

        return Cursor(point: point, status: status)
    }

    /// Whether the piece could stand on this square despite it being open.
    private func wouldSurvive(_ point: GridPoint) -> Bool {
        if signState.walksOnAir { return true }
        return piece.zodiac.passives.preventsFall(
            from: piece.plane,
            at: point,
            context: passiveContext
        )
    }

    /// Every direction that currently has a legal destination, and where it
    /// leads. Used by the HUD and by the tap-target control scheme.
    var legalDestinations: [SwipeDirection: GridPoint] {
        SwipeDirection.allCases.reduce(into: [:]) { result, direction in
            result[direction] = destination(for: direction)
        }
    }

    // MARK: - Planning steps
    //
    // Each of these mutates the simulation copy it is called on and returns the
    // events that produced the change.

    /// Ends the sparkle phase, choosing which of the sparkling tiles the pickup
    /// appears on.
    ///
    /// Tiles that are no longer legal hosts are skipped, so the pickup always
    /// lands somewhere the piece can stand.
    private mutating func rollPickupReveal(destination: GridPoint) -> [GameEvent] {
        guard revealedPickups.isEmpty,
              let sparkles,
              let pickup = pendingPickup
        else { return [] }

        let board = self[sparkles.plane]
        // A set that was allowed over broken ground keeps every square it has.
        // Filtering here would quietly undo Virgo's ring, whose whole offer is
        // that the coin might be hanging over nothing.
        let usable = sparkles.overBrokenGround
            ? sparkles.points
            : sparkles.points.filter { board[$0].canHostSparkle }

        // An effect pinned to one square appears there or not at all — the
        // catalogue only offered it because the set covers that square.
        if let required = PickupCatalog.effect(for: pickup).requiredSpawnPoint {
            guard usable.contains(required) else { return [] }
            return [.pickupRevealed(id: pickup, plane: sparkles.plane, point: required)]
                + secondReveal(among: usable, excluding: required, on: sparkles.plane)
        }

        // A passive may steer the reveal — Virgo's Controlled Compensation puts the
        // coin on the square the move is already heading for. Otherwise it is a
        // straight roll among the surviving sparkles.
        let steered = piece.zodiac.passives.preferredRevealPoint(
            among: usable,
            destination: destination,
            context: passiveContext
        )
        guard let point = steered ?? usable.randomElement(using: &rng) else { return [] }

        return [.pickupRevealed(id: pickup, plane: sparkles.plane, point: point)]
            + secondReveal(among: usable, excluding: point, on: sparkles.plane)
    }

    /// A second Pentacle on one of the sparkles the first did not take.
    ///
    /// Sagittarius only, so far — see `ZodiacPassive.secondPickupChance`.
    ///
    /// Rolled square first, then effect: the square is one of the leftovers, and
    /// the catalogue is then asked what could legally appear *there*. Doing it
    /// the other way round would let something pinned to one tile — Polaris —
    /// be drawn and then placed somewhere it is not allowed to be.
    ///
    /// The roll is independent of the first coin's, which is the quiet part of
    /// the passive: drawing twice is drawing twice, so a sign with this meets
    /// the rare Pentacles more often simply by seeing more of them.
    private mutating func secondReveal(
        among usable: [GridPoint],
        excluding taken: GridPoint,
        on plane: Plane
    ) -> [GameEvent] {
        let chance = piece.zodiac.passives.secondPickupChance(context: passiveContext)
        guard chance > 0 else { return [] }

        let roll = Double(rng.next() % 10_000) / 10_000
        guard roll < chance else { return [] }

        let leftovers = usable.filter { $0 != taken }
        guard let point = leftovers.randomElement(using: &rng),
              let pickup = PickupCatalog.rollPickup(
                  sparklePoints: [point],
                  weighting: pickupWeighting(),
                  using: &rng
              )
        else { return [] }

        return [.pickupRevealed(id: pickup, plane: plane, point: point)]
    }

    /// What a landing produced, beyond its events.
    private struct LandingResult {
        var events: [GameEvent] = []
        var tilesWorn = 0
        var tilesBroken = 0
        var fell = false
        var ascended = false

        /// Holes crossed without dropping in — only a jump can manage it.
        var holesJumped = 0

        /// The Pentacle opened during this landing, if any.
        var collectedPickup: PickupID?

        /// Every square the move covered, in order — squares landed on, and for
        /// a jump the ones flown over. A Pentacle anywhere in here is collected,
        /// so a vault cannot sail past one.
        var covered: [GridPoint] = []

        /// Folds another result into this one, in order.
        mutating func absorb(_ other: LandingResult) {
            events += other.events
            tilesWorn += other.tilesWorn
            tilesBroken += other.tilesBroken
            fell = fell || other.fell
            ascended = ascended || other.ascended
            holesJumped += other.holesJumped
            covered += other.covered
            collectedPickup = collectedPickup ?? other.collectedPickup
        }
    }

    /// Walks the piece along `path`, one square at a time.
    ///
    /// Each square entered is settled before the next is attempted, which is
    /// what makes a slide dangerous: if a tile gives way underfoot halfway
    /// along, the piece drops there and the remainder of the slide never
    /// happens.
    private mutating func travel(_ path: [GridPoint], style: MovementStyle) -> LandingResult {
        var result = LandingResult()
        guard !isGameOver else { return result }

        switch style {
        case .jump:
            // A leap touches only where it lands.
            guard let destination = path.last else { return result }

            let hop = GameEvent.pieceStepped(
                from: piece.point,
                to: destination,
                plane: piece.plane
            )
            result.events.append(hop)
            result.covered.append(destination)
            apply(hop)

            result.absorb(settle(arrivedByFalling: false))

        case .slide:
            // One turn, however far it goes.
            //
            // The squares between the ends are *crossed*, not stood on: no
            // wear, no landing checks, no chance to fall in halfway. Only the
            // tile pushed off and the tile arrived at are touched — see
            // `GameRules.slideWearsEndsOnly`.
            //
            // What is picked up along the way is a separate question, and one
            // the caller answers with `covered`.
            for square in path {
                let step = GameEvent.pieceSlid(
                    from: piece.point,
                    to: square,
                    plane: piece.plane
                )
                result.events.append(step)
                result.covered.append(square)
                apply(step)
            }

            result.absorb(settle(arrivedByFalling: false))
        }

        return result
    }

    /// Resolves the square the piece is standing on right now.
    ///
    /// The order matters and encodes the core rule: **wear first, then check
    /// whether you can still stand there.** A tile that reaches `hole` under the
    /// piece gives way immediately — there is no standing on a freshly-made
    /// hole. Loops because a drop can chain: breaking through Astra and landing
    /// on an already-broken Terra tile ends the run in one move.
    /// - Parameter wearsOnArrival: `false` for effects that already applied
    ///   their own wear square by square — Astral Brook — so the square they come
    ///   to rest on is not charged twice. Previously this was smuggled in through
    ///   `arrivedByFalling`, which did not actually work: with
    ///   `fallingLandingCausesWear` on, that flag never suppressed anything.
    private mutating func settle(
        arrivedByFalling: Bool,
        wearsOnArrival: Bool = true
    ) -> LandingResult {
        var result = LandingResult()
        var fellAlready = arrivedByFalling

        func commit(_ event: GameEvent) {
            result.events.append(event)
            apply(event)
        }

        while !isGameOver {
            let plane = piece.plane
            let point = piece.point

            // 1. Wear the tile the piece is on. Skipped for tiles that are
            //    already open, for the Nexys, and when a passive or the
            //    free-fall rule says this landing is weightless.
            let landed = self[plane][point]
            let earnsWear = wearsOnArrival
                && (!fellAlready || GameRules.fallingLandingCausesWear)
            let passiveAllows = piece.zodiac.passives.causesWear(
                on: landed,
                at: point,
                plane: plane,
                context: passiveContext
            )

            // Airborne signs charge their wear to the tile they push off from
            // instead, which `departCurrentTile()` handles at the other end of
            // the move. Nothing is owed on arrival.
            let timing = piece.zodiac.passives.wearTiming(context: passiveContext)

            if earnsWear, passiveAllows, timing == .onEntry, landed.canBeWorn {
                result.absorb(applyWear(to: point, on: plane, arrivedByFalling: fellAlready))
            }

            // A fall can be softened into a full repair — Virgo always, and
            // Sagittarius on a lucky one. Never fills a hole: a hole is what was
            // fallen into, not what was landed on.
            if fellAlready, landed.canBeRepaired || landed.health == .healthy,
               !landed.health.isHole,
               piece.zodiac.passives.restoresTileOnFallArrival(
                   tile: landed, at: point, plane: plane, context: passiveContext
               ),
               self[plane][point].health != .healthy {
                commit(.tileHealed(plane: plane, point: point, to: .healthy))
            }

            // 2. Open any Pentacle on this square **before** asking whether the
            //    ground still holds.
            //
            //    This ordering is load-bearing, not incidental: a coin sitting on
            //    a tile that the landing just broke is a rescue, and it can only
            //    rescue if it resolves first. Astral Brook sweeping you off a
            //    tile that has this instant become a hole is the case that
            //    matters — collect, get carried away, survive.
            //
            //    Note the wear in step 1 is *not* undone. The tile is a hole and
            //    stays one; what the Pentacle prevents is the fall, because by
            //    the time the ground below is consulted the piece is no longer
            //    standing on it.
            //
            //    The effect may move the piece or mend the ground beneath it, so
            //    anything it changes is picked up by looping round again rather
            //    than assumed away.
            if !revealedPickups.isEmpty, !isGameOver {
                let opened = resolvePickupCollection(settleAfterEffect: false)
                result.events += opened.events
                result.collectedPickup = result.collectedPickup ?? opened.pickup

                if opened.collected {
                    // The coin asked the player something and is waiting on the
                    // answer. This landing is *not* finished — it is suspended,
                    // and nothing below may run, least of all the check for
                    // whether the ground still holds. The answer is very often
                    // what decides that: Astral Breeze warping the piece off a
                    // tile the landing has just broken is the whole point of the
                    // coin, and falling through that tile while the player is
                    // still choosing where to go makes the rescue unwinnable.
                    //
                    // `planChoice` resumes from here — `applyEffect` settles the
                    // destination when the piece moves, and settles in place
                    // when it did not but the ground went. So a choice can never
                    // leave a piece hovering over a hole either.
                    if pendingChoice != nil { return result }

                    // The effect might have carried the piece somewhere else
                    // entirely; that square is a fresh arrival and owes its own
                    // wear and its own checks.
                    if piece.plane != plane || piece.point != point {
                        fellAlready = false
                        continue
                    }
                }
            }

            // 2a. Walking into your own arrow pulls it out of the ground.
            //
            //     It does not warp you — you are already here. The square was
            //     frozen while the arrow stood in it, which is why arriving does
            //     not damage it on the turn it is recovered: the freeze lifts
            //     with the arrow, not before it.
            if let arrow = signState.arrow, arrow.plane == plane, arrow.point == point {
                commit(.arrowCleared)
            }

            // 2b. A raised tile with nothing on it is just a step. Standing on
            //     one stamps it flat: no coin, no sparkles, no consequences —
            //     which is the whole of what it does.
            if raisedTiles.contains(where: { $0.plane == plane && $0.point == point }),
               !revealedPickups.contains(where: { $0.plane == plane && $0.point == point }) {
                commit(.tileStamped(plane: plane, point: point))
            }

            // 3. Can the piece stand on what is left? A tile it just broke
            //    cannot hold it.
            let remaining = self[plane][point]
            let hovers = piece.zodiac.passives.preventsFall(
                from: plane,
                at: point,
                context: passiveContext
            )
            if hovers, !remaining.isSolid {
                if let spent = piece.zodiac.passives
                    .stateAfterPreventingFall(context: passiveContext),
                   spent != signState {
                    // A guard that actually caught the piece spends itself here,
                    // rather than decaying on a timer whether it was needed or
                    // not.
                    commit(.signStateChanged(spent))
                }

                // And whatever else the save was worth — mending the ground,
                // paying for the nerve. Only ever reached when a passive really
                // did catch the piece.
                for event in piece.zodiac.passives.eventsOnPreventingFall(
                    at: point, on: plane, context: passiveContext
                ) {
                    commit(event)
                }
            }

            // Walking on air: holes hold the piece up, and so does the chasm.
            let airborne = signState.walksOnAir || airborneThisMove

            if remaining.isSolid || hovers || airborne {
                // Coming to rest on somebody else's work claims it.
                result.events += claimAbandonedWorks()

                // An always-on ability with something to offer asks here — at
                // rest, so it is looking at where the piece ended up rather than
                // where it was aimed. The move suspends exactly as a Pentacle's
                // question does; `planChoice` resumes it.
                if let offer = piece.zodiac.passives.offersChoice(context: passiveContext) {
                    commit(.choiceRequested(source: .passive(piece.zodiac), kind: offer))
                    return result
                }

                // Coming to rest on the island while it sits on Terra rides it
                // back up. Checked here — at rest — rather than on entering the
                // square, so a slide that merely crosses the island keeps going.
                if GameRules.nexysAscendsFromTerra,
                   plane == .terra,
                   self[plane][point].kind == .nexys,
                   !piece.zodiac.passives.blocksAscent(context: passiveContext) {
                    commit(.nexysMoved(to: .astra, carryingPiece: true))
                    result.ascended = true
                }
                return result
            }

            // 4. Down it goes — unless a passive can pull the piece back from
            //    it. Scorpio is the only sign that can, and only twice: once by
            //    dreaming its way back up, once by shedding.
            guard let below = plane.planeBelow else {
                if let rescue = piece.zodiac.passives.survivesFatalFall(
                    at: point, from: plane, context: passiveContext
                ) {
                    for event in rescue { commit(event) }
                    return result
                }
                commit(.gameOver(reason: .fellThroughTerra))
                return result
            }
            commit(.pieceFell(from: plane, to: below, at: point))
            result.fell = true
            fellAlready = true

            // Leaving Astra repairs it, so a player who can climb back up finds
            // fresh ground waiting. This is the mechanism that makes long runs
            // possible at all.
            if GameRules.astraRestoresOnDescent, plane == .astra {
                commit(.planeRestored(plane: .astra))
            }
        }

        return result
    }

    // MARK: - Abandoned works
    //
    // Three secrets, none of them stated anywhere the player can read. All of
    // them turn on holding a piece that did *not* make the thing being used,
    // which only happens after a mid-run piece change.

    /// Gemini's rifts, still open under somebody else's feet.
    ///
    /// Consulted only when the current sign has no wrap of its own, so Gemini
    /// holding the board still goes through its own passive.
    private func lingeringRift(
        from origin: GridPoint,
        direction: SwipeDirection
    ) -> [GridPoint]? {
        guard signState.riftsLinger else { return nil }
        return GeminiReflectiveRifts().wrappedMove(
            from: origin,
            direction: direction,
            context: passiveContext
        )
    }

    /// Charge claimed from a work its maker has walked away from.
    ///
    /// Standing in a Bastion as a water sign that is *not* Cancer, or on an Aten
    /// as a fire sign that is *not* Leo, fills the meter outright — and consumes
    /// the thing. The element is the key: the work recognises its own kind, and
    /// the sign that built it gets nothing, because for them it is already doing
    /// what it was built to do.
    ///
    /// Deliberately undocumented in-game. It is only reachable after a piece
    /// change, so it rewards a player who noticed that the board keeps what the
    /// last sign left.
    private mutating func claimAbandonedWorks() -> [GameEvent] {
        var events: [GameEvent] = []
        var state = signState
        let element = piece.zodiac.element
        var claimed = false

        if let bastion = state.sanctuary,
           bastion.covers(piece.point, on: piece.plane),
           element == .water, piece.zodiac != .cancer {
            state.sanctuary = nil
            claimed = true
        }

        if let aten = state.sun,
           aten.plane == piece.plane, aten.point == piece.point,
           element == .fire, piece.zodiac != .leo {
            state.sun = nil
            claimed = true
        }

        guard claimed else { return [] }

        func commit(_ event: GameEvent) {
            events.append(event)
            apply(event)
        }

        commit(.signStateChanged(state))
        if zodiactionMeter < zodiactionMeterMax {
            commit(.zodiactionMeterChanged(to: zodiactionMeterMax))
        }
        return events
    }

    // MARK: - Leo's sun

    /// Drags the revealed Pentacle one square toward a burning sun.
    ///
    /// Shortest path *including diagonals*, so a coin two across and two down
    /// arrives in two moves rather than four — the sun pulls, it does not walk
    /// the coin around a grid.
    ///
    /// Deliberately does not care what is on the destination square. A coin
    /// dragged over a hole is dealt with by `ensurePentacleAvailable`, which
    /// already destroys any coin left standing on nothing and starts a fresh
    /// glow phase; special-casing it here would be a second copy of that rule.
    mutating func planPickupPull() -> [GameEvent] {
        // The piece wins where both would act. A sun on the far side of the
        // board must never tug a coin away from a lion the coin was just drawn
        // to — the reward for having a sun out is the extra square below, not a
        // contest.
        if let magnetic = planMagneticPull() { return magnetic }
        return planSunPull()
    }

    /// Leo's Magnetic Mane: the coin drifts toward the *piece*.
    ///
    /// Returns `nil` when it does not fire, which is what lets the sun take the
    /// turn instead.
    private mutating func planMagneticPull() -> [GameEvent]? {
        let chance = piece.zodiac.passives.magneticPullChance(context: passiveContext)
        guard chance > 0 else { return nil }

        let roll = Double(rng.next() % 10_000) / 10_000
        guard roll < chance else { return nil }

        // An Aten burning is worth an extra square, rather than a second puller.
        let steps = signState.sun == nil
            ? GameRules.magneticManeSteps
            : GameRules.magneticManeStepsWithSun

        return pullCoins(toward: piece.point, on: piece.plane, steps: steps)
    }

    /// Leo's sun: the coin drifts toward the Aten.
    private mutating func planSunPull() -> [GameEvent] {
        guard let sun = signState.sun else { return [] }
        return pullCoins(toward: sun.point, on: sun.plane, steps: GameRules.sunPullPerMove)
    }

    /// Walks every coin on `plane` some squares closer to `target`.
    ///
    /// Shortest path *including diagonals*, so a coin two across and two down
    /// arrives in two moves rather than four — it is being pulled, not walked
    /// around a grid.
    ///
    /// Deliberately does not care what is on the destination square. A coin
    /// dragged over a hole is dealt with by `ensurePentacleAvailable`, which
    /// already destroys any coin left standing on nothing and starts a fresh
    /// glow phase; special-casing it here would be a second copy of that rule.
    private mutating func pullCoins(
        toward target: GridPoint,
        on plane: Plane,
        steps: Int
    ) -> [GameEvent] {
        var events: [GameEvent] = []

        for coin in revealedPickups where coin.plane == plane {
            var from = coin.point

            for _ in 0..<steps {
                guard from != target else { break }

                // One step along each axis that is not already lined up,
                // which is a diagonal whenever both are out.
                let to = GridPoint(
                    from.x + (target.x - from.x).signum(),
                    from.y + (target.y - from.y).signum()
                )

                let event = GameEvent.pickupMoved(
                    id: coin.id,
                    plane: coin.plane,
                    from: from,
                    to: to
                )
                apply(event)
                events.append(event)
                from = to
            }
        }

        return events
    }

    // MARK: - Sanctuary

    /// This event with anything a standing sanctuary refuses stripped out of it,
    /// or `nil` if that leaves nothing to do.
    ///
    /// ## Why this is a filter and not a check inside `apply`
    ///
    /// `apply` has to be a faithful reading of an event: the session replays the
    /// very same list the planner produced, and the views animate straight off
    /// the payloads. An event that says nine tiles crack while only six of them
    /// do would draw six tiles cracking and three flashing for no reason.
    /// Sheltered squares are removed while the move is being *planned*, so the
    /// event never claims something that does not happen.
    ///
    /// ## Why it sits at the boundary
    ///
    /// The sanctuary protects against damage "by any means", and damage arrives
    /// from four places: the engine's own wear, a Pentacle's effect, a
    /// Zodiaction, and a passive reacting to the move. Filtering at each of
    /// those four handoffs means a Pentacle written next year is covered without
    /// knowing sanctuaries exist.
    func sheltered(_ event: GameEvent) -> GameEvent? {
        guard signState.sanctuary != nil || signState.arrow != nil else { return event }

        switch event {
        case let .tilesWorn(plane, changes):
            let kept = permitted(changes, on: plane)
            return kept.isEmpty ? nil : .tilesWorn(plane: plane, changes: kept)

        case let .tilesWornOnExit(plane, changes):
            let kept = permitted(changes, on: plane)
            return kept.isEmpty ? nil : .tilesWornOnExit(plane: plane, changes: kept)

        case let .tilesChanged(plane, changes):
            let kept = permitted(changes, on: plane)
            return kept.isEmpty ? nil : .tilesChanged(plane: plane, changes: kept)

        default:
            return event
        }
    }

    /// The entries of a tile-change payload a sanctuary allows through.
    ///
    /// Damage to a sheltered square is dropped. Repair is not: a sanctuary is
    /// protection, and there is no reading of it under which mending the ground
    /// inside it should be forbidden.
    private func permitted(
        _ changes: [GridPoint: TileHealth],
        on plane: Plane
    ) -> [GridPoint: TileHealth] {
        changes.filter { point, health in
            // An arrow pins its square outright — not merely against damage, as
            // a sanctuary does. Whatever state it was stuck in is the state it
            // stays in until the arrow is pulled.
            if let arrow = signState.arrow, arrow.plane == plane, arrow.point == point {
                return false
            }

            guard signState.isSheltered(point, on: plane) else { return true }
            return health < self[plane][point].health
        }
    }

    /// Deals one landing's worth of wear to a tile, after passives have shaped
    /// it.
    ///
    /// Everything that makes wear interesting lives in the proposal: Taurus
    /// doubling it on Astra or halving it on Terra, Virgo refusing to let a
    /// badly cracked tile break, Sagittarius getting lucky. The passive may also
    /// spend a cooldown while it is here, which rides out as a `signStateChanged`
    /// alongside the damage.
    /// - Parameter onExit: Tags the damage as coming from the piece *leaving*
    ///   this square, so the replay can pace it differently. See
    ///   `GameEvent.tilesWornOnExit`.
    private mutating func applyWear(
        to point: GridPoint,
        on plane: Plane,
        arrivedByFalling: Bool,
        onExit: Bool = false
    ) -> LandingResult {
        var result = LandingResult()
        func commit(_ event: GameEvent) {
            result.events.append(event)
            apply(event)
        }

        let tile = self[plane][point]
        guard tile.canBeWorn else { return result }

        let proposal = WearProposal(
            tile: tile,
            point: point,
            plane: plane,
            arrivedByFalling: arrivedByFalling,
            stages: GameRules.wearPerLanding,
            signState: signState
        )
        let final = piece.zodiac.passives.modifyWear(proposal, context: passiveContext)

        if final.signState != signState {
            commit(.signStateChanged(final.signState))
        }

        // Everything this landing does to the board, gathered before anything
        // is emitted — see `GameEvent.tilesWorn` for why it leaves as one event.
        var changes: [GridPoint: TileHealth] = [:]

        // Redirected impact: Libra spares what it lands on and hits the flanks
        // instead. Gathered first so a passive that zeroes `stages` still gets
        // its extras.
        for extra in piece.zodiac.passives.additionalWear(from: final, context: passiveContext) {
            guard self[plane].contains(extra) else { continue }
            let target = self[plane][extra]
            guard target.canBeWorn else { continue }

            let health = target.health.damaged
            changes[extra] = health
            result.tilesWorn += 1
            if health.isHole { result.tilesBroken += 1 }
        }

        // The tile underfoot. Several stages resolve to one final state rather
        // than to one event each.
        if final.stages > 0 {
            var health = tile.health
            for _ in 0..<final.stages where health != .hole {
                health = health.damaged
            }
            if health != tile.health {
                changes[point] = health
                result.tilesWorn += 1
                if health.isHole { result.tilesBroken += 1 }
            }
        } else if final.stages < 0 {
            // Negative stages repair — see `WearProposal.stages`.
            var health = tile.health
            for _ in 0..<(-final.stages) where health != .healthy {
                health = health.healed
            }
            if health != tile.health {
                changes[point] = health
            }
        }

        // The star wears nothing. Checked here rather than at each caller
        // because this is the one funnel every landing's damage goes through —
        // arrival, departure, and the extra squares passives add.
        guard !signState.isStarred else { return result }

        guard !changes.isEmpty else { return result }
        // Same rule as everywhere else: a sanctuary refuses the damage, and the
        // event never claims it happened.
        guard let allowed = sheltered(onExit
            ? .tilesWornOnExit(plane: plane, changes: changes)
            : .tilesWorn(plane: plane, changes: changes))
        else { return result }
        commit(allowed)

        return result
    }

    /// Charges wear to the tile the piece is standing on *before* it moves.
    ///
    /// Only does anything for signs whose `wearTiming` is `.onExit`. Called at
    /// the top of a move, while the piece is still on the square it is leaving.
    /// - Note: Emits `tilesWornOnExit` rather than `tilesWorn`. Same rule,
    ///   different pacing — see the event's documentation.
    /// - Parameter force: True when the move charges its start tile whatever the
    ///   sign's timing says — which a slide always does, since the two ends are
    ///   the only ground it touches.
    private mutating func departCurrentTile(force: Bool = false) -> LandingResult {
        guard force || piece.zodiac.passives.wearTiming(context: passiveContext) == .onExit else {
            return LandingResult()
        }
        let point = piece.point
        let plane = piece.plane
        guard piece.zodiac.passives.causesWear(
            on: self[plane][point], at: point, plane: plane, context: passiveContext
        ) else { return LandingResult() }

        return applyWear(to: point, on: plane, arrivedByFalling: false, onExit: true)
    }

    /// Collects the revealed Pentacle if the piece came to rest on it.
    /// - Parameter covered: Every square the move passed through, including the
    ///   ones a jump flew over. A Pentacle anywhere along that line is collected;
    ///   the piece does not have to come to rest on it.
    /// - Parameter settleAfterEffect: `false` when called from inside `settle`,
    ///   which is already looping and will handle whatever the effect changed.
    ///   Leaving it `true` there would re-enter `settle` from within itself.
    private mutating func resolvePickupCollection(
        covering covered: [GridPoint] = [],
        settleAfterEffect: Bool = true
    ) -> (collected: Bool, pickup: PickupID?, events: [GameEvent]) {
        guard let pickup = revealedPickups.first(where: { coin in
            coin.plane == piece.plane
                && (coin.point == piece.point || covered.contains(coin.point))
        }) else { return (false, nil, []) }

        var events: [GameEvent] = []
        func commit(_ event: GameEvent) {
            events.append(event)
            apply(event)
        }

        // Read before the collection, since opening the coin can mend the very
        // square it was sitting on.
        let wasSolid = self[pickup.plane][pickup.point].isSolid

        commit(.pickupCollected(id: pickup.id, plane: pickup.plane, point: pickup.point))

        // What the *sign* makes of having opened one, before the ground under
        // the piece is consulted — a coin over a hole is only rescuable here.
        for event in piece.zodiac.passives.collected(
            pickup.id,
            at: pickup.point,
            on: pickup.plane,
            wasSolid: wasSolid,
            context: passiveContext
        ) {
            commit(event)
        }

        // Taking one shatters any other. Two coins are a choice, not a haul —
        // and the destruction is the ordinary event, so the tile it was on
        // stays raised to be stamped flat like any other.
        for other in revealedPickups where other.id != pickup.id || other.point != pickup.point {
            commit(.pickupDestroyed(id: other.id, plane: other.plane, point: other.point))
        }

        // Capricorn does not open coins, it banks them — the effect never runs
        // and the contents are spent later through Cosmic Cash-in. Z-Charge is
        // the exception the design names: charge cannot be stored as charge, so
        // it goes off like anyone else's.
        if pickup.id != .zCharge,
           piece.zodiac.passives.banksPickups(pickup.id, context: passiveContext) {
            var state = signState
            state.purse.append(pickup.id)
            commit(.signStateChanged(state))
            commit(.pickupBanked(id: pickup.id, plane: pickup.plane, point: pickup.point))
            return (true, pickup.id, events)
        }

        let effect = PickupCatalog.effect(for: pickup.id)

        // Effects that need an answer park here. The session collects it and
        // calls `planChoice(_:)`, which resumes from exactly this point.
        guard effect.choice == .none else {
            commit(.choiceRequested(source: .pickup(pickup.id), kind: effect.choice))
            return (true, pickup.id, events)
        }

        events += applyEffect(effect, choice: nil)
        return (true, pickup.id, events)
    }

    /// Runs an effect and everything that follows from it.
    ///
    /// Shared by the immediate path and the resumed-after-a-choice path so both
    /// get identical treatment: the effect's own events, then a landing at the
    /// destination if it moved the piece, then Astra's repair if that move was a
    /// descent.
    private mutating func applyEffect(
        _ effect: any PickupEffect,
        choice: PickupChoiceResult?,
        settleAfter: Bool = true
    ) -> [GameEvent] {
        var events: [GameEvent] = []
        func commit(_ event: GameEvent) {
            events.append(event)
            apply(event)
        }

        let planeBefore = piece.plane
        let pointBefore = piece.point

        let context = PickupContext(
            currentBoard: self[piece.plane],
            boardBelow: piece.plane.planeBelow.map { self[$0] },
            plane: piece.plane,
            nexysPlane: nexysPlane,
            piecePoint: piece.point,
            facing: piece.facing,
            zodiac: piece.zodiac,
            zodiactionMeter: zodiactionMeter,
            zodiactionMeterMax: zodiactionMeterMax,
            signState: signState
        )

        for event in effect.plan(context: context, choice: choice, generator: &rng) {
            guard let allowed = sheltered(event) else { continue }
            commit(allowed)
            for sweep in gatherIfCrossed(allowed) { commit(sweep) }
        }

        // Whatever was swept up on the way opens now that the piece has landed.
        events += openCarriedPickups()

        // Arriving somewhere new is landing, and every gameplay check happens on
        // landing — so the destination settles exactly like the end of a move.
        // Settling also has to happen when the piece did *not* move but the
        // ground under it did: an effect that opens a hole underfoot must drop
        // the piece, not leave it hovering. Astral Blaze used to do exactly that.
        let moved = piece.plane != planeBefore || piece.point != pointBefore
        let groundGone = !self[piece.plane][piece.point].isSolid
        if settleAfter, moved || groundGone, !isGameOver {
            let landing = settle(
                arrivedByFalling: false,
                wearsOnArrival: effect.arrivalWearsTile
            )
            events += landing.events
        }

        // Leaving Astra repairs it however you left, not only by falling.
        if GameRules.astraRestoresOnDescent,
           planeBefore == .astra,
           piece.plane == .terra,
           !events.contains(.planeRestored(plane: .astra)) {
            commit(.planeRestored(plane: .astra))
        }

        // An Essence opened by its own element pays a little charge on top.
        // Applied here rather than in the four effects: it is a rule about the
        // *piece*, not about any one coin, and adding a fifth Essence should not
        // mean remembering to write this again.
        if let element = effect.element, element == piece.zodiac.element {
            let target = min(zodiactionMeter + GameRules.elementAffinityCharge, zodiactionMeterMax)
            if target != zodiactionMeter {
                commit(.zodiactionMeterChanged(to: target))
            }
        }

        return events
    }

    /// Resumes a Pentacle that was waiting on the player.
    ///
    /// Called after the session has collected the answer. Plans the effect and
    /// everything downstream of it, then rolls the next sparkle phase — the tail
    /// of the move that `plan(_:)` could not finish without input.
    mutating func planChoice(_ result: PickupChoiceResult) -> [GameEvent] {
        guard let pending = pendingChoice else { return [] }

        var sim = self
        defer { self.rng = sim.rng }

        var events: [GameEvent] = []
        func commit(_ event: GameEvent) {
            events.append(event)
            sim.apply(event)
        }

        let planeBefore = sim.piece.plane

        // Answering with a square is choosing one — the same thing a swipe does,
        // and it should be worth the same to anything that cares.
        if case .tile = result { sim.arrivalWasChosen = true }
        defer { sim.arrivalWasChosen = false }

        commit(.choiceResolved)

        // Buying from the purse is not a question any one sign answers — it is
        // a Pentacle being opened late, so it is run here rather than inside
        // Cosmic Cash-in, which has no way to reach `applyEffect`.
        if case let .item(id) = result {
            if let index = sim.signState.purse.firstIndex(of: id) {
                var state = sim.signState
                state.purse.remove(at: index)
                commit(.signStateChanged(state))
            }
            commit(.pickupSpent(id: id))

            let effect = PickupCatalog.effect(for: id)
            // A banked coin that still owes a question asks it now, through the
            // ordinary pickup path — buying an Astral Breeze should feel like
            // opening one.
            if effect.choice != .none {
                commit(.choiceRequested(source: .pickup(id), kind: effect.choice))
                return events
            }
            events += sim.applyEffect(effect, choice: nil)
            events += sim.ensurePentacleAvailable(previousPlane: planeBefore)
            return events
        }

        switch pending.source {
        case let .pickup(id):
            events += sim.applyEffect(PickupCatalog.effect(for: id), choice: result)

        case let .passive(zodiac):
            // Same shape as a Zodiaction resuming, and the same debt: an
            // accepted offer moves the piece, and a piece that moved owes a
            // landing. A declined one produces nothing and settles nothing,
            // which is correct — it is still standing where it already was.
            let passiveContext = sim.passiveContext
            let answer = zodiac.passives.resolveChoice(result, context: passiveContext)
            for event in answer {
                if let allowed = sim.sheltered(event) { commit(allowed) }
            }
            if !answer.isEmpty, !sim.isGameOver {
                events += sim.settle(arrivedByFalling: false, wearsOnArrival: false).events
            }

        case let .zodiaction(zodiac):
            // The Zodiaction picks up where it left off, and owes the same
            // settle a coin's effect does: it has almost certainly moved the
            // piece, which is the only reason it asked.
            let context = sim.passiveContext
            for event in zodiac.zodiaction.resolve(
                choice: result,
                context: context,
                generator: &sim.rng
            ) {
                if let allowed = sim.sheltered(event) { commit(allowed) }
            }
            if !sim.isGameOver {
                events += sim.settle(arrivedByFalling: false, wearsOnArrival: false).events
            }
        }

        events += sim.ensurePentacleAvailable(previousPlane: planeBefore)
        return events
    }

    /// Applies the current sign's charging rule to the move that just resolved.
    private mutating func chargeSuper(for move: MoveSummary) -> [GameEvent] {
        // Most signs' charge comes from their passives rather than from the
        // Zodiaction's own rule; both contribute and the two simply sum.
        // An arrow in the ground is charge already spent and not yet cashed:
        // nothing accrues until it is recalled. Checked before anything is
        // summed rather than clamped afterwards, so a passive cannot sneak a pip
        // past it.
        guard signState.arrow == nil else { return [] }

        // The star charges for nothing but moving, whoever is carrying it.
        let starCharge = signState.isStarred ? GameRules.starChargePerMove : 0
        let gain = piece.zodiac.zodiaction.meterGain(from: move, context: passiveContext)
            + piece.zodiac.passives.meterBonus(from: move, context: passiveContext)
            + starCharge
        guard gain != 0 else { return [] }

        let capped = min(max(zodiactionMeter + gain, 0), zodiactionMeterMax)
        guard capped != zodiactionMeter else { return [] }

        let event = GameEvent.zodiactionMeterChanged(to: capped)
        apply(event)
        return [event]
    }

    /// The squares strictly between two points on a shared row or column.
    ///
    /// Empty for anything that is not a straight line, which is correct: a
    /// knight-style hop has no meaningful "flown over" set.
    static func squaresBetween(_ a: GridPoint, _ b: GridPoint) -> [GridPoint] {
        if a.x == b.x {
            let range = min(a.y, b.y) + 1 ..< max(a.y, b.y)
            return range.map { GridPoint(a.x, $0) }
        }
        if a.y == b.y {
            let range = min(a.x, b.x) + 1 ..< max(a.x, b.x)
            return range.map { GridPoint($0, a.y) }
        }
        return []
    }

    /// Restores the invariant that a Pentacle is always obtainable.
    ///
    /// **Every planner ends by calling this**, which is the point: the rule is
    /// attached to the *state*, not to any one route through it. It used to live
    /// inside `plan(_:)` alone, so anything else that changed plane — a
    /// Zodiaction like Taurus' Flowering Flop, a Pentacle that teleports — left the
    /// board with no sparkle phase and no coin, and the loop simply stopped.
    ///
    /// Rolls when any of these is true:
    ///
    /// - the piece changed plane, so whatever was out there is on the wrong board;
    /// - a revealed Pentacle is stranded on a plane the piece is no longer on;
    /// - there is neither a sparkle phase nor a coin, by any route at all.
    ///
    /// That last clause is a catch-all rather than a specific rule, and it is
    /// deliberate: it makes this class of bug unreachable instead of fixing the
    /// one case that was reported.
    ///
    /// Skipped while a Pentacle is parked awaiting an answer — `planChoice(_:)`
    /// finishes that move and calls this itself.
    private mutating func ensurePentacleAvailable(previousPlane: Plane) -> [GameEvent] {
        guard !isGameOver, pendingChoice == nil else { return [] }

        var events: [GameEvent] = []

        // A coin whose tile has broken underneath it goes down with it. Area
        // effects and board-wide Zodiactions can open a hole anywhere, the
        // Pentacle's own square included — and a coin left hovering over a hole
        // is not just odd to look at, it is unreachable, since landing there
        // drops the piece straight through.
        //
        // Checked here rather than at each place a tile can break: this is
        // already the one function every planner ends with, and every one of
        // them can break a tile.
        for pickup in revealedPickups
        where pickup.plane == piece.plane && !self[pickup.plane][pickup.point].isSolid {
            let destroyed = GameEvent.pickupDestroyed(
                id: pickup.id,
                plane: pickup.plane,
                point: pickup.point
            )
            apply(destroyed)
            events.append(destroyed)
        }

        let changedPlane = piece.plane != previousPlane && GameRules.relocatePickupOnPlaneChange
        let stranded = !revealedPickups.isEmpty
            && revealedPickups.allSatisfy { $0.plane != piece.plane }
        let nothingAvailable = sparkles == nil && revealedPickups.isEmpty

        guard changedPlane || stranded || nothingAvailable else { return events }

        let plane = piece.plane
        let board = self[plane]
        let point = piece.point
        let weighting = pickupWeighting()
        let mirrorChance = piece.zodiac.passives.mirroredSparkleChance(context: passiveContext)
        guard let spawn = Self.rollSparkles(
            on: plane,
            board: board,
            piecePoint: point,
            weighting: weighting,
            mirrorChance: mirrorChance,
            using: &rng
        ).map({ staged($0) }) else { return events }

        apply(spawn)
        events.append(spawn)
        return events
    }

    /// Rolls a sparkle set together with the pickup hiding inside it.
    private static func rollSparkles(
        on plane: Plane,
        board: Board,
        piecePoint: GridPoint,
        weighting: (PickupID, Int) -> Int,
        mirrorChance: Double,
        using generator: inout SeededRandom
    ) -> GameEvent? {
        guard let spawned = SparkleSet.spawn(
            on: plane,
            board: board,
            avoiding: piecePoint,
            using: &generator
        ) else { return nil }

        // Libra's Stellar Scales folds the shape across the board.
        var set = spawned
        if mirrorChance > 0 {
            let roll = Double(generator.next() % 10_000) / 10_000
            if roll < mirrorChance { set = spawned.mirrored(on: board) }
        }

        guard let pickup = PickupCatalog.rollPickup(
            sparklePoints: set.points,
            weighting: weighting,
            using: &generator
        ) else { return nil }
        return .sparklesSpawned(set: set, pickup: pickup)
    }

    /// The coin the piece has just slid onto, swept up rather than opened.
    ///
    /// Returns nothing for any event that is not a slide, which is most of them.
    private mutating func gatherIfCrossed(_ event: GameEvent) -> [GameEvent] {
        guard case let .pieceSlid(_, to, plane) = event,
              let coin = revealedPickups.first(where: { $0.plane == plane && $0.point == to })
        else { return [] }

        let gathered = GameEvent.pickupGathered(id: coin.id, plane: plane, point: to)
        apply(gathered)
        return [gathered]
    }

    /// Opens everything the piece swept up on its way, now that it has stopped.
    ///
    /// Each one runs its full effect, so a coin caught mid-slide behaves exactly
    /// as it would have if walked onto — including moving the piece again, which
    /// it could not safely have done while the piece was still travelling.
    private mutating func openCarriedPickups() -> [GameEvent] {
        guard !carriedPickups.isEmpty else { return [] }

        let carried = carriedPickups
        carriedPickups = []

        var events: [GameEvent] = []
        for coin in carried {
            let opened = GameEvent.pickupCollected(
                id: coin.id,
                plane: coin.plane,
                point: piece.point
            )
            apply(opened)
            events.append(opened)

            let effect = PickupCatalog.effect(for: coin.id)

            // A coin that needs an answer parks exactly as it would have.
            guard effect.choice == .none else {
                let asked = GameEvent.choiceRequested(
                    source: .pickup(coin.id),
                    kind: effect.choice
                )
                apply(asked)
                events.append(asked)
                break
            }

            events += applyEffect(effect, choice: nil)
        }
        return events
    }

    /// A spawn with any debug override applied.
    ///
    /// Release builds compile this to the identity, so the roll is untouched.
    private mutating func staged(_ event: GameEvent) -> GameEvent {
        #if DEBUG
        guard let forced = debugNextPickup,
              case let .sparklesSpawned(set, _) = event
        else { return event }

        debugNextPickup = nil
        return .sparklesSpawned(set: set, pickup: forced)
        #else
        return event
        #endif
    }

    /// The piece's opinion on what should turn up in a sparkle set.
    ///
    /// Built as a closure over a *snapshot* of the context rather than reading
    /// the engine as it runs: the roll happens with `&rng` already borrowed, and
    /// touching `self` inside it would be overlapping access to the same value.
    private func pickupWeighting() -> (PickupID, Int) -> Int {
        let context = passiveContext
        let passives = piece.zodiac.passives
        return { id, base in passives.pickupWeight(base, for: id, context: context) }
    }

    /// The read-only snapshot handed to passive and Zodiaction hooks.
    /// The same snapshot, for anything outside the engine that has to ask a
    /// passive a question — the panel, deciding which buttons to offer.
    var passiveSnapshot: PassiveContext { passiveContext }

    private var passiveContext: PassiveContext {
        PassiveContext(
            zodiac: piece.zodiac,
            currentBoard: self[piece.plane],
            boardBelow: piece.plane.planeBelow.map { self[$0] },
            plane: piece.plane,
            nexysPlane: nexysPlane,
            piecePoint: piece.point,
            facing: piece.facing,
            moveCount: moveCount,
            zodiactionMeter: zodiactionMeter,
            arrivalWasChosen: arrivalWasChosen,
            pickupPoints: revealedPickups.filter { $0.plane == piece.plane }.map(\.point),
            pickups: revealedPickups.filter { $0.plane == piece.plane },
            signState: signState,
            luck: luck,
            luckAlt: luckAlt
        )
    }

    // MARK: - Applying

    /// Performs a single event.
    ///
    /// Contains no decisions and no randomness — every choice was already made
    /// during planning, which is what makes replaying a plan deterministic.
    mutating func apply(_ event: GameEvent) {
        switch event {
        case .moveBlocked:
            break // Presentation only.

        case let .pickupRevealed(id, plane, point):
            // The sparkle phase ends here: the shimmer goes out as the pickup
            // appears.
            pickupSerial += 1
            revealedPickups.append(
                RevealedPickup(id: id, plane: plane, point: point, serial: pickupSerial)
            )
            // The tile pops up under it, and from here on the two are separate.
            raisedTiles.append(
                RevealedPickup(id: id, plane: plane, point: point, serial: pickupSerial)
            )
            sparkles = nil
            pendingPickup = nil

        case let .moveCommitted(direction):
            piece.facing = direction
            moveCount += 1

        case let .pieceTurned(direction):
            piece.facing = direction

        case let .pieceSlid(_, to, _):
            piece.point = to

        case let .pieceStepped(_, to, _):
            piece.point = to

        case let .tilesChanged(plane, changes):
            for (point, health) in changes {
                self[plane][point].health = health
            }

        case let .tilesWorn(plane, changes), let .tilesWornOnExit(plane, changes):
            for (point, health) in changes {
                self[plane][point].health = health
            }

        case let .tileDamaged(plane, point, health):
            self[plane][point].health = health

        case let .tileHealed(plane, point, health):
            self[plane][point].health = health

        case let .pieceTeleported(_, to, fromPlane, toPlane):
            // Arriving anywhere by warp closes the torn set, and leaving the
            // plane closes everything.
            signState.terraRifts = false
            if toPlane != fromPlane { signState.closeRifts() }
            piece.plane = toPlane
            piece.point = to

        case let .pieceChanged(zodiac):
            // Leaving Gemini leaves the rifts. See `SignState.riftsLinger`.
            if piece.zodiac == .gemini, zodiac != .gemini {
                signState.riftsLinger = true
            }
            signState = signState.clearedForPieceChange
            // Square, plane and facing all survive the change; only the sign
            // itself is replaced. Charge is kept too — the meter belongs to the
            // run, not to the piece, so a forced change cannot wipe it. Note the
            // *cap* may move, since each sign sets its own `meterMax`; the meter
            // is clamped here so it can never sit above a lower new cap.
            piece.zodiac = zodiac
            zodiactionMeter = min(zodiactionMeter, zodiactionMeterMax)

        case let .choiceRequested(source, kind):
            pendingChoice = (source, kind)

        case .choiceResolved:
            pendingChoice = nil

        case let .signStateChanged(state):
            signState = state

        case let .pieceFell(_, to, at):
            signState = signState.clearedForPlaneChange(atMove: moveCount)
            signState.closeRifts()
            piece.plane = to
            piece.point = at

        case let .planeRestored(plane):
            for point in self[plane].allPoints where self[plane][point].kind == .normal {
                self[plane][point].health = .healthy
            }
            // The plane has re-formed, so nothing is standing proud of it any
            // more. Without this a pop-up left behind on Astra was still there
            // on the next visit, alongside the new one — and the same going
            // back down.
            raisedTiles.removeAll { $0.plane == plane }

        case let .pickupDestroyed(_, plane, point):
            // Only the square the coin actually went down on. If the sun had
            // dragged it elsewhere first, the tile it popped up from is still
            // standing and still has to be stamped flat by hand.
            raisedTiles.removeAll { $0.plane == plane && $0.point == point }
            revealedPickups.removeAll { $0.plane == plane && $0.point == point }
            // The hunt only restarts once the board is empty of coins.
            if revealedPickups.isEmpty {
                pendingPickup = nil
                sparkles = nil
            }

        // Presentation only: what the tail caught arrives as its own
        // `pickupGathered`, and a miss changes nothing by definition.
        case .stingStruck:
            break

        // The purse itself moves through `signStateChanged`; these two are
        // announcements, so the strip and the arc of light have something to
        // animate off.
        case .pickupBanked, .pickupSpent:
            break

        case let .pickupCollected(_, plane, point):
            raisedTiles.removeAll { $0.plane == plane && $0.point == point }
            revealedPickups.removeAll { $0.plane == plane && $0.point == point }
            if revealedPickups.isEmpty {
                pendingPickup = nil
                sparkles = nil
            }
            pickupsCollected += 1

        case let .pickupMoved(id, plane, from, to):
            // The coin alone. `raisedTiles` is untouched on purpose.
            if let index = revealedPickups.firstIndex(where: {
                $0.plane == plane && $0.point == from
            }) {
                // Same coin, new square — so it keeps its serial and the view
                // slides it, which is exactly what a pull should look like.
                revealedPickups[index] = RevealedPickup(
                    id: id, plane: plane, point: to,
                    serial: revealedPickups[index].serial
                )
            }

        case let .pickupGathered(id, plane, point):
            // Off the board and onto the piece. The square it popped up from
            // stays raised, to be stamped flat like any other.
            revealedPickups.removeAll { $0.plane == plane && $0.point == point }
            pickupSerial += 1
            carriedPickups.append(
                RevealedPickup(id: id, plane: plane, point: point, serial: pickupSerial)
            )

        case let .arrowPlanted(plane, point):
            signState.arrow = SignState.Arrow(
                point: point,
                plane: plane,
                movesRemaining: GameRules.arrowMoves
            )

        case .arrowCleared:
            signState.arrow = nil

        case let .tileStamped(plane, point):
            raisedTiles.removeAll { $0.plane == plane && $0.point == point }

        case let .sparklesSpawned(set, pickup):
            sparkles = set
            pendingPickup = pickup
            revealedPickups = []
            // A fresh hunt clears the last one's leftovers: a raised square with
            // no coin on it is stampable, not permanent.
            raisedTiles = []

        case let .nexysMoved(destination, carryingPiece):
            nexysPlane = destination
            applyNexysLayout()
            if carryingPiece {
                if piece.plane != destination { signState.closeRifts() }
                piece.plane = destination
                piece.point = GameRules.nexysPoint
            }

        case let .zodiactionMeterChanged(value):
            zodiactionMeter = value

        case .zodiactionFired:
            break // Marker; the super's own events follow.

        case let .gameOver(reason):
            gameOverReason = reason
        }
    }
}
