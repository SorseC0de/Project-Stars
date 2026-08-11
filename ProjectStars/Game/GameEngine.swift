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
    private(set) var revealedPickup: RevealedPickup?

    /// The square currently popped up, if any.
    ///
    /// Deliberately *not* derived from `revealedPickup`. A tile pops up to
    /// present a coin, but it outlives it: the coin can be taken, destroyed, or
    /// dragged off by Leo's sun, and the square stays raised until somebody
    /// stands on it. Deriving one from the other made a raised tile teleport
    /// after a coin that had been pulled away from it.
    private(set) var raisedTile: RevealedPickup?

    /// A Pentacle that has been opened but is waiting on the player to answer a
    /// question before it can resolve. See `planChoice(_:)`.
    private(set) var pendingChoice: (id: PickupID, kind: PickupChoice)?

    private(set) var score: Int
    private(set) var moveCount: Int
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
    var zodiactionMeterMax: Int { piece.zodiac.zodiaction.meterMax }

    /// True when the Zodiaction can be popped right now.
    var isZodiactionReady: Bool {
        guard !isGameOver, zodiactionMeter >= zodiactionMeterMax else { return false }
        // Asked here rather than only at the moment of firing, so the panel can
        // show it as unavailable instead of letting the player spend a full
        // meter on nothing.
        return piece.zodiac.zodiaction.canActivate(context: passiveContext)
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
        self.revealedPickup = nil
        self.raisedTile = nil
        self.pendingChoice = nil
        self.score = 0
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
        if let opening = Self.rollSparkles(
            on: openingPlane,
            board: openingBoard,
            piecePoint: openingPoint,
            weighting: openingWeighting,
            using: &rng
        ) {
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
        if let reveal = sim.rollPickupReveal(destination: move.destination) {
            commit(reveal)
            revealedThisMove = true
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
        let departure = sim.departCurrentTile()
        events += departure.events

        // A jump covers the ground it flies over as well as where it lands, so a
        // Pentacle in the flight path is picked up in passing rather than sailed
        // straight past.
        let flownOver = move.style == .jump
            ? Self.squaresBetween(origin, move.destination)
            : []

        // 3. Travel. A slide walks each square in turn and wears every one; a
        //    jump touches only the destination. Either way, a tile that breaks
        //    underfoot drops the piece there and the rest of the path is
        //    abandoned.
        var landing = sim.travel(move.path)
        events += landing.events
        // Fold the departure's tallies in (its events already went out above) so
        // the move summary counts wear dealt on exit as wear dealt.
        landing.tilesWorn += departure.tilesWorn
        landing.tilesBroken += departure.tilesBroken

        var collectedPickup: PickupID?

        if !sim.isGameOver {
            commit(.scoreAwarded(GameRules.scorePerMove))

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
            events += sim.planSunPull()

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
        commit(.zodiactionFired(zodiac: sim.piece.zodiac, plane: sim.piece.plane))

        // Context read into a local first: it reads `sim`, and passing `&sim.rng`
        // in the same call would be overlapping access to the same value.
        let zodiactionContext = sim.passiveContext
        for event in sim.piece.zodiac.zodiaction.activate(
            context: zodiactionContext,
            generator: &sim.rng
        ) {
            if let allowed = sim.sheltered(event) { commit(allowed) }
        }

        // The ground it stood on may not have survived what it just did. Libra's
        // Balancing Breeze turns every healthy Astra tile into a hole, its own square
        // included, and without this the piece simply stood on the air.
        //
        // Same guarantee `applyEffect` gives a Pentacle: arriving somewhere new
        // is a landing, and so is the floor leaving.
        if !sim.isGameOver, !sim[sim.piece.plane][sim.piece.point].isSolid {
            events += sim.settle(arrivedByFalling: false, wearsOnArrival: false).events
        }

        commit(.zodiactionMeterChanged(to: 0))

        // A Zodiaction can change plane too — Taurus flops through Astra, Pisces
        // swims back up — so it owes the same guarantee a move does.
        events += sim.ensurePentacleAvailable(previousPlane: planeBefore)
        return events
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
                return ResolvedMove(
                path: wrapped,
                style: .jump,
                option: MovementPattern.MoveOption(.any, distance: 1, style: .jump),
                origin: piece.point
            )
            }
            return nil
        }

        return ResolvedMove(path: path, style: option.style, option: option, origin: piece.point)
    }

    /// Every distance available in `direction` right now, nearest first.
    ///
    /// Drives the on-screen reach selector. Goes through `adjustedMovement` so a
    /// passive that withholds an option — Capricorn's climb on cooldown — is
    /// reflected in what the player is offered, rather than being shown a move
    /// that will not happen.
    func moveOptions(for direction: SwipeDirection) -> [MovementPattern.MoveOption] {
        piece.zodiac.passives
            .adjustedMovement(base: piece.zodiac.movement, context: passiveContext)
            .options(for: direction, facing: piece.facing)
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
        let status: CursorStatus = switch tile.kind {
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

        return Cursor(point: point, status: status)
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
    private mutating func rollPickupReveal(destination: GridPoint) -> GameEvent? {
        guard revealedPickup == nil,
              let sparkles,
              let pickup = pendingPickup
        else { return nil }

        let board = self[sparkles.plane]
        let usable = sparkles.points.filter { board[$0].canHostSparkle }

        // An effect pinned to one square appears there or not at all — the
        // catalogue only offered it because the set covers that square.
        if let required = PickupCatalog.effect(for: pickup).requiredSpawnPoint {
            guard usable.contains(required) else { return nil }
            return .pickupRevealed(id: pickup, plane: sparkles.plane, point: required)
        }

        // A passive may steer the reveal — Virgo's Controlled Compensation puts the
        // coin on the square the move is already heading for. Otherwise it is a
        // straight roll among the surviving sparkles.
        let steered = piece.zodiac.passives.preferredRevealPoint(
            among: usable,
            destination: destination,
            context: passiveContext
        )
        guard let point = steered ?? usable.randomElement(using: &rng) else { return nil }

        return .pickupRevealed(id: pickup, plane: sparkles.plane, point: point)
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
    private mutating func travel(_ path: [GridPoint]) -> LandingResult {
        var result = LandingResult()

        for square in path {
            guard !isGameOver else { break }

            let step = GameEvent.pieceStepped(
                from: piece.point,
                to: square,
                plane: piece.plane
            )
            result.events.append(step)
            result.covered.append(square)
            apply(step)

            let settled = settle(arrivedByFalling: false)
            result.absorb(settled)

            // A drop ends the move; whatever was left of the path is moot.
            if settled.fell || isGameOver { break }
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
            if revealedPickup != nil, !isGameOver {
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

            // 2b. A raised tile with nothing on it is just a step. Standing on
            //     one stamps it flat: no coin, no sparkles, no consequences —
            //     which is the whole of what it does.
            if let raised = raisedTile,
               raised.plane == plane,
               raised.point == point,
               revealedPickup?.point != point {
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
            if hovers, !remaining.isSolid,
               let spent = piece.zodiac.passives.stateAfterPreventingFall(context: passiveContext),
               spent != signState {
                // A guard that actually caught the piece spends itself here,
                // rather than decaying on a timer whether it was needed or not.
                commit(.signStateChanged(spent))
            }

            if remaining.isSolid || hovers {
                // Coming to rest on somebody else's work claims it.
                result.events += claimAbandonedWorks()

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
    mutating func planSunPull() -> [GameEvent] {
        guard let sun = signState.sun,
              let coin = revealedPickup,
              coin.plane == sun.plane
        else { return [] }

        var events: [GameEvent] = []
        var from = coin.point

        for _ in 0..<GameRules.sunPullPerMove {
            guard from != sun.point else { break }

            // One step along each axis that is not already lined up, which is a
            // diagonal whenever both are out.
            let to = GridPoint(
                from.x + (sun.point.x - from.x).signum(),
                from.y + (sun.point.y - from.y).signum()
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
        guard signState.sanctuary != nil else { return event }

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
    private mutating func departCurrentTile() -> LandingResult {
        guard piece.zodiac.passives.wearTiming(context: passiveContext) == .onExit else {
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
        guard let pickup = revealedPickup, pickup.plane == piece.plane else {
            return (false, nil, [])
        }

        let reached = pickup.point == piece.point || covered.contains(pickup.point)
        guard reached else { return (false, nil, []) }

        var events: [GameEvent] = []
        func commit(_ event: GameEvent) {
            events.append(event)
            apply(event)
        }

        commit(.pickupCollected(id: pickup.id, plane: pickup.plane, point: pickup.point))

        let effect = PickupCatalog.effect(for: pickup.id)

        // Effects that need an answer park here. The session collects it and
        // calls `planChoice(_:)`, which resumes from exactly this point.
        guard effect.choice == .none else {
            commit(.choiceRequested(id: pickup.id, kind: effect.choice))
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
            zodiactionMeterMax: zodiactionMeterMax
        )

        for event in effect.plan(context: context, choice: choice, generator: &rng) {
            if let allowed = sheltered(event) { commit(allowed) }
        }

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

        commit(.scoreAwarded(GameRules.scorePerPickup))
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
        commit(.choiceResolved)

        let effect = PickupCatalog.effect(for: pending.id)
        events += sim.applyEffect(effect, choice: result)

        events += sim.ensurePentacleAvailable(previousPlane: planeBefore)
        return events
    }

    /// Applies the current sign's charging rule to the move that just resolved.
    private mutating func chargeSuper(for move: MoveSummary) -> [GameEvent] {
        // Most signs' charge comes from their passives rather than from the
        // Zodiaction's own rule; both contribute and the two simply sum.
        let gain = piece.zodiac.zodiaction.meterGain(from: move, context: passiveContext)
            + piece.zodiac.passives.meterBonus(from: move, context: passiveContext)
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
        if let pickup = revealedPickup,
           pickup.plane == piece.plane,
           !self[pickup.plane][pickup.point].isSolid {
            let destroyed = GameEvent.pickupDestroyed(
                id: pickup.id,
                plane: pickup.plane,
                point: pickup.point
            )
            apply(destroyed)
            events.append(destroyed)
        }

        let changedPlane = piece.plane != previousPlane && GameRules.relocatePickupOnPlaneChange
        let stranded = revealedPickup.map { $0.plane != piece.plane } ?? false
        let nothingAvailable = sparkles == nil && revealedPickup == nil

        guard changedPlane || stranded || nothingAvailable else { return events }

        let plane = piece.plane
        let board = self[plane]
        let point = piece.point
        let weighting = pickupWeighting()
        guard let spawn = Self.rollSparkles(
            on: plane,
            board: board,
            piecePoint: point,
            weighting: weighting,
            using: &rng
        ) else { return events }

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
        using generator: inout SeededRandom
    ) -> GameEvent? {
        guard let set = SparkleSet.spawn(
            on: plane,
            board: board,
            avoiding: piecePoint,
            using: &generator
        ) else { return nil }

        guard let pickup = PickupCatalog.rollPickup(
            sparklePoints: set.points,
            weighting: weighting,
            using: &generator
        ) else { return nil }
        return .sparklesSpawned(set: set, pickup: pickup)
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
            score: score,
            zodiactionMeter: zodiactionMeter,
            pickupPoint: revealedPickup.flatMap { $0.plane == piece.plane ? $0.point : nil },
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
            revealedPickup = RevealedPickup(id: id, plane: plane, point: point)
            // The tile pops up under it, and from here on the two are separate.
            raisedTile = RevealedPickup(id: id, plane: plane, point: point)
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

        case let .pieceTeleported(_, to, _, toPlane):
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

        case let .choiceRequested(id, kind):
            pendingChoice = (id, kind)

        case .choiceResolved:
            pendingChoice = nil

        case let .signStateChanged(state):
            signState = state

        case let .pieceFell(_, to, at):
            signState = signState.clearedForPlaneChange(atMove: moveCount)
            piece.plane = to
            piece.point = at

        case let .planeRestored(plane):
            for point in self[plane].allPoints where self[plane][point].kind == .normal {
                self[plane][point].health = .healthy
            }

        case let .pickupDestroyed(_, plane, point):
            // Only the square the coin actually went down on. If the sun had
            // dragged it elsewhere first, the tile it popped up from is still
            // standing and still has to be stamped flat by hand.
            if raisedTile?.plane == plane, raisedTile?.point == point {
                raisedTile = nil
            }
            revealedPickup = nil
            pendingPickup = nil
            sparkles = nil

        case let .pickupCollected(_, plane, point):
            if raisedTile?.plane == plane, raisedTile?.point == point {
                raisedTile = nil
            }
            revealedPickup = nil
            pendingPickup = nil
            sparkles = nil
            pickupsCollected += 1

        case let .pickupMoved(id, plane, _, to):
            // The coin alone. `raisedTile` is untouched on purpose.
            revealedPickup = RevealedPickup(id: id, plane: plane, point: to)

        case let .tileStamped(plane, point):
            if raisedTile?.plane == plane, raisedTile?.point == point {
                raisedTile = nil
            }

        case let .sparklesSpawned(set, pickup):
            sparkles = set
            pendingPickup = pickup
            revealedPickup = nil

        case let .nexysMoved(destination, carryingPiece):
            nexysPlane = destination
            applyNexysLayout()
            if carryingPiece {
                piece.plane = destination
                piece.point = GameRules.nexysPoint
            }

        case let .zodiactionMeterChanged(value):
            zodiactionMeter = value

        case .zodiactionFired:
            break // Marker; the super's own events follow.

        case let .scoreAwarded(points):
            score += points

        case let .gameOver(reason):
            gameOverReason = reason
        }
    }
}
