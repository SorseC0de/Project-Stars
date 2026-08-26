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
    ///
    /// **South to begin with**, and south again on every restart and every ride
    /// between planes. A piece looking away from the player is a piece whose
    /// face they cannot see, and the first thing a run should show is who they
    /// are playing. It is a real direction rather than a pose, so signs that
    /// read the facing — Capricorn stands on holes while facing north — start
    /// from a known answer instead of whichever way the last run ended.
    var facing: SwipeDirection = .down

    /// Which of Gemini's twins this is, once they have come apart.
    ///
    /// `nil` for every whole piece, including Gemini before the split — there is
    /// no gold twin until there is a silver one to be gold *against*.
    ///
    /// Real state rather than something the view works out from position,
    /// because which twin fell is a coin flip and the drawings differ: worked
    /// out from position it would be whichever half the renderer happened to
    /// reach first, which is how both of them came to be drawn as gold.
    var twin: GeminiHalf?
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

    /// The move this coin appeared on.
    ///
    /// Nothing may drag a Pentacle on the turn it is revealed — see
    /// `GameEngine.planMagneticPull()`.
    var revealedOnMove = 0

    /// True when this is one of Aquarius' storm clouds rather than a Pentacle.
    ///
    /// A cloud carries a rolled effect exactly as a coin does, and differs in
    /// what the **hunt** thinks of it: it is not what the sparkle phase is
    /// waiting on, and it does not fall when the ground under it goes. Both of
    /// those fall out of `revealedPentacles` skipping it, which is the one list
    /// every rule of the Pentacle economy is written against.
    var isCloud = false

    /// True when this coin was dealt by a **ring** — Virgo's Regulated Reboot.
    ///
    /// The reward for taking it belongs to the ring, not to Virgo. A phantom
    /// Virgo can be spent the same turn the sparkles appear, and a promise that
    /// evaporated with the sign that made it would be a trap; the pink sparkles
    /// are on the board, so what they are worth is on the board too.
    var fromRing = false

    /// True when this coin is on the board but not *in* the hunt.
    ///
    /// One question with two answers, asked in every place the Pentacle economy
    /// counts coins: a storm cloud and a ring's coin are both things an ability
    /// put down, and neither is what a sparkle phase is waiting on. The phase
    /// does not end because of them, the next phase does not sweep them away,
    /// and nothing re-rolls around them.
    ///
    /// Written once because the two lists that care were already drifting —
    /// `revealedPentacles` skipped clouds and the spawn wipe did not, so a new
    /// phase quietly deleted coins that were supposed to outlive it.
    var standsOutsideTheHunt: Bool { isCloud || fromRing }
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

    /// Turns the piece to face a direction without it having moved.
    ///
    /// For presentation only, and only for travel between planes — see
    /// `GameSession.facesTheFall`. No event, because nothing happened that a
    /// rule should hear about: the piece is in the air, and which way it is
    /// pointing while it is up there is a drawing question.
    mutating func turnPiece(to direction: SwipeDirection) {
        piece.facing = direction
    }

    /// Puts the piece down somewhere without it having travelled there.
    ///
    /// For the seamless restart, and nothing else. A fresh run seats its piece
    /// on the Nexys; a restart that is still falling needs it seated where the
    /// *last* piece fell from instead, or it slides across the board half way
    /// down its own drop. No event, because nothing happened — this is the new
    /// run being lined up with a fall already in progress. See
    /// `GameSession.restartRunSeamlessly`.
    mutating func seatPiece(at point: GridPoint) {
        piece.point = point
    }

    /// The half of Gemini that is *not* taking this turn.
    ///
    /// ## Why this is not an array and an index
    ///
    /// Because `piece` means "the piece whose turn it is", and every rule in
    /// this game is written against that meaning — landing checks, passives,
    /// the cursor, facing, wear. Turning it into `pieces[active]` would have
    /// rewritten several hundred call sites to say the same thing in more
    /// words, and each of those is a chance to change behaviour by accident.
    ///
    /// A split is exactly two halves alternating, so alternation is a **swap**:
    /// at the end of a turn the two exchange places and every existing rule
    /// carries on reading `piece` and being right. See `GameEvent.turnPassed`.
    private(set) var otherHalf: Piece?

    /// True while Gemini is in two places.
    var isSplit: Bool { otherHalf != nil }

    /// The mirrored double Shadow Work leaves on the board, if one is out.
    private(set) var shadow: Shadow?

    /// A shadow of the player's piece, moving opposite to it.
    struct Shadow: Equatable {
        var point: GridPoint
        var plane: Plane

        /// True when it spawned on a *shadow* island — the real Nexys was on the
        /// other plane, so a phantom one was drawn for it to stand on.
        ///
        /// Which is why the centre chasm cannot be used to dispose of it: the
        /// chasm is a guaranteed hole on every board, and one guaranteed hole
        /// would make getting rid of the shadow a formality rather than a plan.
        var onShadowNexys: Bool
    }

    /// The sparkling tiles currently telegraphing a pickup, if any.
    ///
    /// Non-nil only during a **sparkle phase**, which ends the moment the player
    /// commits a move.
    private(set) var sparkles: SparkleSet?

    /// The pickup hiding in the current sparkle set.
    ///
    /// The engine knows *which* pickup from the moment the sparkles appear, but
    /// its square is not decided until the player commits a move.
    /// True while a sparkle phase is open and no coin has been revealed yet.
    ///
    /// Was the coin itself, back when one was drawn as the squares lit up. It is
    /// only ever asked as a yes/no, and holding an identity here is what made a
    /// rule about a square look like a rule about a set.
    private(set) var pendingPickup = false

    /// The pickup once it has appeared on the board, during a **pickup phase**.
    /// Every Pentacle currently out on the board.
    ///
    /// Usually one. Sagittarius' Fortunate Find can put a second one up, so the
    /// rest of the engine has to cope with a set rather than a single coin —
    /// taking either shatters the other, so it is never more than briefly two.
    private(set) var revealedPickups: [RevealedPickup] = []

    /// Settles Astra's outstanding repair when the sign suppressing it leaves.
    ///
    /// ## The bug this exists for
    ///
    /// Astra repairs when you *descend* — that is the mechanism that makes long
    /// runs possible — and Libra suppresses it, because keeping two boards is
    /// the whole of that sign. But the repair only ever had one moment to
    /// happen in. Wreck Astra as Libra, go down, swap to somebody else, ride
    /// back up, and the sky is still in ruins: the descent that would have
    /// mended it happened while it was suppressed, and no later descent is
    /// coming, because you are already down here.
    ///
    /// So the suppression is a *debt* rather than a veto. When the sign holding
    /// it stops being the sign, the repair it was withholding falls due.
    ///
    /// Only from Terra. Standing on Astra means you have not left it, and
    /// mending the ground under your own feet is the one thing this rule has
    /// never done for anybody.
    private mutating func settleAstraRepair() -> GameEvent? {
        guard piece.plane == .terra,
              activePassives.restoresPlaneOnDescent(context: passiveContext),
              self[.astra].allPoints.contains(where: {
                  self[.astra][$0].kind == .normal && self[.astra][$0].health != .healthy
              })
        else { return nil }

        return .planeRestored(plane: .astra)
    }

    /// Where the phantom `step` places back in the line is standing.
    ///
    /// On the engine rather than in the view, because the board draws it *and*
    /// the ground has to be worn under it. Two answers to that would be two
    /// phantoms — one you can see and one that does the damage.
    func retinueSquare(step: Int) -> GridPoint {
        let trail = signState.trail

        // `trail[0]` is where the piece was when this turn began: the turn stamp
        // is emitted before it moves. So the first follower belongs on it.
        if step < trail.count { return trail[step] }

        // The queue is short for a turn or two after a summon. Behind the facing
        // is right for exactly those turns — and never `trail.last`, which is
        // where the piece is standing now.
        let back = piece.facing.opposite.unitOffset
        let size = currentBoard.size
        return GridPoint(
            min(max(piece.point.x + back.dx * (step + 1), 0), size - 1),
            min(max(piece.point.y + back.dy * (step + 1), 0), size - 1)
        )
    }

    /// Wears the ground under every phantom, by that phantom's own rules.
    ///
    /// ## Why this exists
    ///
    /// Attracting Aten is otherwise pure profit: a set of passives for nothing
    /// and a Zodiaction for nothing, immediately. The cost is that a phantom is
    /// a *body* — it stands on the board and the board knows it, so a lion with
    /// two followers ruins the ground three times as fast.
    ///
    /// ## Why each one wears in its own way
    ///
    /// Because that is what makes a summon a decision rather than a number.
    /// Libra digs trenches either side of where it stands instead of under
    /// itself; Taurus hits twice on Astra and scuffs the first time on Terra;
    /// Aquarius charges the square it leaves. A follower that wore ground
    /// generically would be the same follower every time, and the sign it
    /// happened to be would only matter for its super.
    ///
    /// Asked of the follower's own passives, not of `activePassives` — those are
    /// the ones in force for *Leo*, and running the retinue's damage through
    /// them would have every phantom wear like every other.
    private mutating func applyRetinueWear() -> [GameEvent] {
        guard !signState.retinue.isEmpty, !isGameOver else { return [] }

        // Gathered by cause rather than emitted one follower at a time.
        //
        // The phantoms all come down on the same instant — the beat between them
        // is a *drawn* stagger, scheduled by the view — so a separate event each
        // meant the replay stopped and waited once per follower for damage that
        // had already happened together. With a full line that was most of a
        // Leo turn spent on nothing, which is why the lion felt sluggish when
        // nobody else did.
        //
        // Still keyed by cause, because the cause decides how the wear is drawn
        // and two phantoms need not break the ground the same way.
        // Order kept alongside the grouping, because a dictionary has none and
        // this list is a *replay*. Two causes emitted in whichever order the
        // hashing happened to produce would make the same seed draw a different
        // sequence of events on different runs, which is the one thing the
        // event log exists to rule out.
        var merged: [WearCause: [GridPoint: TileHealth]] = [:]
        var order: [WearCause] = []

        for (step, follower) in signState.retinue.enumerated() {
            let point = retinueSquare(step: step)
            guard currentBoard.contains(point) else { continue }

            let tile = currentBoard[point]
            let passives = follower.definition.passives

            guard passives.causesWear(
                on: tile, at: point, plane: piece.plane, context: passiveContext
            ) else { continue }

            var proposal = WearProposal(
                tile: tile,
                point: point,
                plane: piece.plane,
                arrivedByFalling: false,
                stages: GameRules.wearPerLanding,
                signState: signState
            )
            proposal = passives.modifyWear(proposal, context: passiveContext)

            var changes: [GridPoint: TileHealth] = [:]

            // The flanks first, so a passive that spares what it lands on still
            // gets its extras — the same order `applyWear` uses.
            for extra in passives.additionalWear(from: proposal, context: passiveContext) {
                guard currentBoard.contains(extra), currentBoard[extra].canBeWorn else { continue }
                changes[extra] = currentBoard[extra].health.damaged
            }

            if proposal.stages > 0, tile.canBeWorn {
                var health = tile.health
                for _ in 0..<proposal.stages where health != .hole {
                    health = health.damaged
                }
                if health != tile.health { changes[point] = health }
            }

            guard !changes.isEmpty else { continue }
            let allowedEvents = shelteredEvents(
                .tilesWorn(plane: piece.plane, changes: changes, cause: proposal.cause)
            )
            guard let allowed = allowedEvents.first else { continue }

            // Applied as we go, so the next phantom reads a board this one has
            // already broken — two of them on the same square must cost that
            // square two stages, which a batch computed against one snapshot
            // would quietly reduce to one.
            apply(allowed)

            guard case let .tilesWorn(_, allowedChanges, cause) = allowed else { continue }
            if merged[cause] == nil { order.append(cause) }
            merged[cause, default: [:]].merge(allowedChanges) { _, newer in newer }
        }

        // Whole-value replacements, so replaying the merged event over a board
        // these changes were already applied to lands on the same numbers. See
        // the note on `GameEvent.tilesWorn`.
        return order.compactMap { cause in
            merged[cause].map {
                .tilesWorn(plane: piece.plane, changes: $0, cause: cause)
            }
        }
    }

    /// Records a square Leo has occupied, for the retinue to walk through.
    ///
    /// ## Why every kind of movement calls this
    ///
    /// It was only called from the turn stamp, which is emitted before the piece
    /// moves — so it recorded ordinary steps correctly and nothing else. A slide
    /// crossed five squares and the queue heard about none of them, and a warp
    /// left the phantoms standing where the turn had started, on the far side of
    /// the board, forever.
    ///
    /// A queue of *squares the leader was on* only works if everything that puts
    /// the leader on a square says so.
    private mutating func rememberStep(_ point: GridPoint) {
        guard !signState.retinue.isEmpty || !signState.trail.isEmpty else { return }

        // Standing still is not a step. A slide's first square is the one the
        // turn stamp already recorded, and a duplicate would hold the whole line
        // back a turn.
        guard signState.trail.first != point else { return }

        signState.trail.insert(point, at: 0)

        let keep = SignState.retinueLimit(on: piece.plane) + 2
        if signState.trail.count > keep {
            signState.trail.removeLast(signState.trail.count - keep)
        }
    }

    /// Drops the queue and starts it here.
    ///
    /// For the movements that are not walking: a warp, a fall, a ride on the
    /// island. There is no route to follow through those — the leader did not
    /// cross the ground between, so neither can anybody behind him.
    ///
    /// The phantoms end up stacked on Leo for a turn, which is what almost every
    /// game does with a party that teleports, and it sorts itself out the moment
    /// he takes a step.
    /// Advances the retinue's queue however this movement wants it advanced.
    ///
    /// One question asked of the style instead of four sites each deciding for
    /// themselves. A style that crossed the ground leaves a route to walk; one
    /// that did not leaves nowhere to be but on top of the leader.
    ///
    /// This is what the styles are for: the rule is "did the leader cross the
    /// squares between", and before there was a name for that, every caller
    /// answered it from whichever event it happened to be handling.
    /// Records where the piece has been, for whoever is following it.
    ///
    /// **Anything that came from somewhere leaves a trail.** The test used to be
    /// `travelsTheGround`, which is a question about *the ground* — so a hop,
    /// which is most of the moves in the game, restarted the trail at the
    /// destination and put the whole retinue on the square the piece was
    /// standing on. That is one bug wearing three costumes: the phantom drawn
    /// on top of the lion and floating, its pose stuck at rest because it never
    /// changed square, and the tile taking a second helping of wear from a
    /// follower standing exactly where he was.
    ///
    /// Only a move with no journey — a teleport — has nothing to remember, and
    /// that is when the trail starts again from where it arrived.
    private mutating func advanceTrail(_ type: MoveType, from: GridPoint, to: GridPoint) {
        if type.isInstant {
            restartTrail(at: to)
        } else {
            rememberStep(from)
        }
    }

    private mutating func restartTrail(at point: GridPoint) {
        guard !signState.retinue.isEmpty || !signState.trail.isEmpty else { return }
        signState.trail = [point]
    }

    /// Pays back whatever a change of plane is about to cost in phantoms.
    ///
    /// Applied directly rather than as an event, because it happens *inside*
    /// applying one — the plane change and the loss are the same instant, and a
    /// second event describing the same moment could be replayed out of order
    /// with it.
    private mutating func refundLostRetinue() {
        guard GameRules.retinueRefund > 0, !signState.retinue.isEmpty else { return }

        let owed = GameRules.retinueRefund * signState.retinue.count
        zodiactionMeter = min(zodiactionMeter + owed, zodiactionMeterMax)
    }

    /// Every passive in force right now: the piece's own, and any phantom's.
    ///
    /// Leo's retinue is not a summon that acts on its own — it is a set of
    /// abilities on loan. A phantom Taurus mends what Leo lands on; a phantom
    /// Libra puts Libra's trenches in the flanks. That falls out for free by
    /// asking the whole company instead of the piece, which is why every rule in
    /// this file reads this rather than `activePassives`.
    ///
    /// Order matters: the piece's own come first, so where a hook takes the
    /// *first* answer rather than combining them, the sign being played wins.
    var activePassives: [any ZodiacPassive] {
        // `piece.zodiac.passives`, spelled out. A rename swept the whole file
        // and rewrote this getter into a call to itself — which builds, warns,
        // and hangs the moment anything asks a passive a question.
        #if DEBUG
        RenderTally.count("psv")
        #endif
        let own = piece.zodiac.passives
        guard !signState.retinue.isEmpty else { return own }
        return own + signState.retinue.flatMap(\.passives)
    }

    /// The piece's movement plus anything its retinue lends it.
    ///
    /// Every borrowed option is stamped with the phantom it came from, so taking
    /// one can spend it — see `MovementPattern.MoveOption.owner`. The ordinary
    /// single step every sign has is dropped from the loan: it would be a
    /// duplicate of a move Leo already has, and spending a phantom on it would
    /// be a trap rather than a choice.
    var activeMovement: MovementPattern {
        guard !signState.retinue.isEmpty else { return piece.zodiac.movement }

        let base = piece.zodiac.movement
        let borrowed = signState.retinue.flatMap { follower in
            follower.movement.options
                .filter { $0.distance > 1 || $0.style == .hop || $0.reachesWall }
                .map { option -> MovementPattern.MoveOption in
                    var lent = option
                    lent.owner = follower
                    return lent
                }
        }

        return MovementPattern(name: base.name, options: base.options + borrowed)
    }

    /// Just the ones the hunt is about.
    ///
    /// Every rule governing the Pentacle economy — the sparkle phase waiting for
    /// a clear board, a coin over a hole being destroyed, a stranded coin
    /// forcing a re-roll — is written against this rather than against
    /// `revealedPickups`, because a boon left lying about by an ability is not
    /// part of that economy and must not stall it. See `PickupClass`.

    /// True while a Zodiaction is resolving. Set for the length of the plan, as
    /// `pickupRevealedThisMove` and `arrivalWasChosen` are.
    private(set) var isFiringZodiaction = false

    var revealedPentacles: [RevealedPickup] {
        revealedPickups.filter {
            // A storm cloud holds a Pentacle's effect but is not one of the
            // hunt's coins: the phase does not wait on it, nothing re-rolls
            // because of it, and it hangs where it was put whatever happens to
            // the ground. See `RevealedPickup.isCloud`.
            //
            // **A ring's coin is the same kind of thing.** Virgo pays a full
            // meter for eight lit squares, and if that coin were the hunt's one
            // coin then popping the Reboot would only ever move the coin she
            // was already going to get — a super that costs a meter and gives
            // back the thing you had. Standing outside this list is what lets
            // the two exist at once, so the ring is always *additional*.
            !$0.standsOutsideTheHunt
                && PickupCatalog.effect(for: $0.id).pickupClass == .pentacle
        }
    }

    #if DEBUG
    /// Forces the next Pentacle to be this one, whatever the roll says.
    ///
    /// Cleared as soon as it is used, so it stages exactly one coin. Debug
    /// builds only — the Astral Bolt is one draw in four hundred, which is the
    /// whole design and completely impractical to test against.
    var debugNextPickup: PickupID?

    /// Puts the next reveal on the square the move is heading for, so the
    /// Shine-snipe can be produced on demand.
    ///
    /// The snipe is the rarest thing to reproduce by playing — the phase has to
    /// end on the move you happen to be landing on its coin — which is exactly
    /// why it went unnoticed that its window could never open. A lever for it is
    /// worth keeping.
    var debugSnipesNext = false
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

    /// True when the square being resolved was **already** open on arrival,
    /// rather than having broken underfoot.
    ///
    /// Leo's Courageous Charge is a reward for walking into a hole on purpose.
    /// Without this it also fired on a tile that gave way as it was landed on,
    /// which is the opposite situation — nothing was chosen and nothing was
    /// braved.
    private var arrivedOnOpenGround = false

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

    /// True when the meter is full — or does not apply.
    ///
    /// **What the piece looks like, not what it may do.** The gold and the gem
    /// glow say the sign is charged; whether the square it happens to be
    /// standing on will accept the Zodiaction is a different question, asked by
    /// `isZodiactionReady`. Tying the two together meant a statue lost its gold
    /// by walking somewhere the ability could not be aimed, which reads as the
    /// charge being spent rather than as the target being wrong.
    var isZodiactionCharged: Bool {
        guard !isGameOver else { return false }
        let zodiaction = piece.zodiac.zodiaction
        return zodiaction.ignoresMeter(context: passiveContext) || meterIsAtFiring
    }

    /// True when the meter is standing where this sign fires from.
    ///
    /// Full for everyone except Aquarius, who runs the other way and fires at
    /// **zero** — see `Zodiaction.firesAtEmpty`. Asked in one place so the two
    /// readiness questions cannot disagree about it, which is what a second
    /// comparison spelled out at each site would eventually do.
    /// The meter after a **gain** of `amount`, in whichever direction this sign
    /// counts.
    ///
    /// Charge is granted from a dozen places — reveal pips, element affinity,
    /// passives, Pentacles — and every one of them means *this brings you closer
    /// to firing*. For Aquarius that is downward. Putting the direction here
    /// means none of those has to know, which is the whole reason the reversal
    /// is affordable.
    func meter(afterGaining amount: Int) -> Int {
        // Asked of the passives, so a phantom carrying Aquarius' kit charges
        // backwards too — which is what makes borrowing him a real trade rather
        // than a way around his drawback.
        let backwards = activePassives.reversesCharge(context: passiveContext)
        let signed = backwards ? -amount : amount
        return min(max(zodiactionMeter + signed, 0), zodiactionMeterMax)
    }

    /// True when the player's directions are turned around.
    /// True when holes hold this piece up.
    var floatsOverHoles: Bool {
        activePassives.walksOnHoles(context: passiveContext)
    }

    /// True when a single step in some direction would leave the board.
    ///
    /// Only meaningful for a piece that may leave — everyone else is refused
    /// the move, so being beside the rim says nothing about them.
    var isAgainstTheEdge: Bool {
        guard floatsOverBoardEdge else { return false }
        return GridOffset.cardinals.contains {
            !currentBoard.contains(piece.point.offset(by: $0))
        }
    }

    /// True when this piece can step off the board — and die doing it.
    var floatsOverBoardEdge: Bool {
        activePassives.mayLeaveTheBoard(context: passiveContext)
    }

    var controlsAreReversed: Bool {
        activePassives.reversesControls(context: passiveContext)
    }

    var meterIsAtFiring: Bool {
        piece.zodiac.zodiaction.firesAtEmpty
            ? zodiactionMeter <= 0
            : zodiactionMeter >= zodiactionMeterMax
    }

    /// True when the Zodiaction can be popped right now.
    var isZodiactionReady: Bool {
        guard !isGameOver else { return false }

        let zodiaction = piece.zodiac.zodiaction
        let context = passiveContext

        // A free pop needs no meter — see `Zodiaction.ignoresMeter`.
        guard zodiaction.ignoresMeter(context: context) || meterIsAtFiring
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
        self.pendingPickup = false
        self.revealedPickups = []
        self.raisedTiles = []
        self.carriedPickups = []
        self.pendingChoice = nil
        self.moveCount = 0
        self.pickupsCollected = 0
        // Aquarius starts **full**.
        //
        // Asked of the Zodiaction rather than tested against the sign: a meter
        // that runs backwards starts full, and that is a fact about the ability
        // rather than about who is holding it. See `Zodiaction.startingMeter`.
        self.zodiactionMeter = zodiac.zodiaction.startingMeter
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
        let mirrorChance = activePassives.mirroredSparkleChance(context: passiveContext)
        if let opening = Self.rollSparkles(
            on: openingPlane,
            board: openingBoard,
            piecePoint: openingPoint,
            weighting: openingWeighting,
            mirrorChance: mirrorChance,
            stardarPending: signState.stardarPending,
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
            // A direction the sign can *never* go is not a refused move, it is
            // not a move at all.
            //
            // `moveBlocked` plays a balk — the piece leans at the wall and comes
            // back — which says "you tried that and the board said no". For a
            // cardinal into a wall that is exactly right. For a diagonal on a
            // sign that has no diagonals it is a lie: it implies the direction
            // is ordinarily available and merely obstructed here, and every
            // non-Virgo piece was nodding at corners it can never use.
            guard sim.canEverMove(direction) else { return [] }

            // **A balk goes through the passives like any other outcome.**
            //
            // It used to return here, which meant the one thing that happens to
            // every sign constantly — running into the edge of the world — was
            // the one thing no ability could answer. Aries turning around when
            // he bonks is exactly that, and it could not have been written
            // without reaching into the engine for a special case.
            //
            // `amend` rather than a hook of its own: it is already "react to
            // what the move did", and a move that did nothing did something.
            let balk: [GameEvent] = [.moveBlocked(direction: direction)]
            return balk + sim.activePassives.amend(balk, context: sim.passiveContext)
        }

        // Some signs cross a long move on the wind — see
        // `ZodiacPassive.walksOnAir(during:context:)`. Scoped to this move, and
        // cleared however it ends.
        sim.airborneThisMove = sim.activePassives.walksOnAir(
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
        // Mirrored onto the engine for the length of the plan, so an effect
        // opened later in this same move can see it — a bubble pays triple for
        // being guessed and is handed a `PickupContext`, not a `MoveSummary`.
        // Arriving through a rift closes the doorway behind you — that pair
        // only. The other axis was never entered and stays open for a second
        // crossing.
        let crossed = SignState.RiftAxes.crossed(by: direction)
        if move.usedRift, !sim.signState.terraRifts.intersection(crossed).isEmpty {
            var closed = sim.signState
            closed.terraRifts.subtract(crossed)
            commit(.signStateChanged(closed))
        }

        // 2. Commit: the move counts, and the piece turns to face the way it is
        //    going, before it has gone anywhere.
        // …unless a passive says the piece keeps watching where it was.
        // Cancer's Seafoam Scuttle does exactly that.
        let keepsFacing = sim.activePassives.retainsFacing(
            direction: direction,
            option: move.option,
            context: sim.passiveContext
        )
        commit(.moveCommitted(direction: keepsFacing ? facingBefore : direction))

        // 2a. The sparkle phase resolves — **after the move is counted**.
        //
        //     `moveCount` is the number of moves *committed*, and a reveal
        //     records the move it happened on. Rolled before the commit, it
        //     recorded the number of the **previous** move, so every question
        //     asked later in the same plan compared M against M+1:
        //
        //     - The Shine-snipe pays for taking a coin on the move it appeared,
        //       and its window was therefore never open. That is why the
        //       flourish never played — the art, the strip and the event were
        //       all fine.
        //     - Magnetic Mane refuses to drag a coin "on the turn it appears",
        //       and by the same off-by-one it was allowed to.
        //
        //     Nothing about the presentation moves: `moveCommitted` turns the
        //     piece and counts the move without drawing anything, so the coin
        //     still appears as the hop begins.
        var revealedThisMove = false
        for reveal in sim.rollPickupReveal(destination: move.destination) {
            commit(reveal)
            revealedThisMove = true
        }

        // 2b. Airborne signs pay their wear to the tile they are pushing off
        //     from, not the one they are about to reach. Charged here, while the
        //     piece is still standing on it.
        // A slide charges the tile it pushes off from as well as the one it
        // reaches — those two ends are the only ground it touches, so between
        // them they carry the whole move's wear. The arrival end is charged by
        // the `settle` at the end of `travel`; this is the departure end.
        //
        // A one-square move is not a sweep and must not be treated as one: it
        // has no crossed middle to be spared, so charging its exit *as well as*
        // its arrival is simply double damage on every ordinary step.
        // Asked of the style rather than tested against one.
        //
        // `wear` is where the rule lives, so a future style that also charges
        // its ends gets this without being named here — and the two places that
        // used to test `== .slide` independently cannot drift apart again.
        let sweeps = move.style.wear == .both && move.path.count > 1
        // **Decided once, on the square being left.**
        //
        // `wearTiming` is a question about the tile the piece is standing on,
        // and it was being asked twice — once here with the origin underfoot,
        // and again on arrival with the destination underfoot. Virgo leaving a
        // badly cracked tile answered `.onExit` and then, standing on healthy
        // ground, answered `.onEntry` — so the move charged both ends and every
        // step cost two.
        //
        // A move wears one tile. Which end it lands on is a property of where
        // the move *started*, so the answer travels with the move.
        sim.moveWearTiming = sim.activePassives.wearTiming(context: sim.passiveContext)

        let departure = sim.departCurrentTile(force: sweeps)
        events += departure.events

        // 2b. Age the timers this move **began** with.
        //
        // Ahead of travel and collection rather than after them, because a
        // timer granted by a coin opened on this move would otherwise be aged
        // by the very move that granted it — the pickup step spends one of its
        // own moves before the player has taken any. That was invisible on the
        // Astral Bolt at ten moves and glaring on an Essence at three.
        //
        // "A move ages what was already running" is also the only version that
        // can be stated in one sentence. The alternative — everything except
        // whatever was granted midway — needs a list of exceptions that grows
        // every time a coin is added.
        var aging = sim.signState
        aging.tickTimers()
        if aging != sim.signState {
            sim.signState = aging
            events.append(.signStateChanged(aging))
        }

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
        var landing = sim.travel(move.path, type: move.style)
        events += landing.events
        // Fold the departure's tallies in (its events already went out above) so
        // the move summary counts wear dealt on exit as wear dealt.
        landing.tilesWorn += departure.tilesWorn
        landing.tilesBroken += departure.tilesBroken

        var collectedPickup: PickupID?

        // An always-on ability may have stopped the move to ask something — see
        // `ZodiacPassive.offersChoice`. Nothing below may run while it waits:
        // `planChoice` finishes the move, and a second `choiceRequested` raised
        // from here would overwrite the one still outstanding.
        if sim.pendingChoice != nil { return events }

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
            // moving — Leo's Magnetic Mane does exactly that.
            if !pulled.isEmpty {
                let gathered = sim.resolvePickupCollection()
                events += gathered.events
                landing.collectedPickup = landing.collectedPickup ?? gathered.pickup
            }

            // 4b-ii. The company wears the ground it is standing on.
            //
            //        After the piece has settled, so each phantom is charged for
            //        where it actually ended up rather than where it set off.
            events += sim.applyRetinueWear()

            // 4c. Anything still riding the piece opens now.
            //
            //     A slide opens what it swept as it stops, but a coin can also
            //     be gathered by an effect that ran mid-move, and nothing else
            //     in an ordinary move ever emptied the pouch — so one picked up
            //     that way hung over the piece's head for the rest of the run.
            events += sim.openCarriedPickups()

            // 5. Keep a Pentacle reachable. See `ensurePentacleAvailable`.
            events += sim.ensurePentacleAvailable(previousPlane: startingPlane, after: events)

            // The poles take their turn last, after the board has settled: the
            // pull is the *consequence* of the move, not part of it.
            events += sim.planProngPull()
        }

        // 5a-i. A borrowed move spends the phantom that lent it.
        //
        //       Leo's retinue is a set of abilities on loan, and the loan is for
        //       one use — taking the move is the use. Emitted before the sign's
        //       own `stateAfterMove` so a phantom cannot both be spent and leave
        //       a cooldown behind on the way out.
        if let lender = move.option.owner, sim.signState.retinue.contains(lender) {
            var released = sim.signState
            released.retinue.removeAll { $0 == lender }
            // A borrowed Capricorn takes its takings with it.
            if lender == .capricorn { released.purse = [] }
            commit(.signStateChanged(released))
        }

        // 5a. Some options cost something to have taken — Capricorn's climb puts
        //     itself on cooldown. Asked after the move so a climb that never
        //     happened is never charged for.
        // Asked of each in turn, not of the array.
        //
        // The array's own combinator takes the **first** non-nil answer, which
        // was correct while only one sign was ever in play and silently wrong
        // the moment Leo could carry two more. Two passives that each want to
        // record something — a phantom Sagittarius' stride cooldown and a
        // phantom Aquarius' spent corner — would have had one of them dropped,
        // and the dropped one is a limit that then never applies.
        //
        // Committing between them is what makes it safe: each is handed a
        // context built from the state the last one left, so they amend rather
        // than overwrite.
        for passive in sim.activePassives {
            guard let spent = passive.stateAfterMove(
                option: move.option,
                direction: direction,
                context: sim.passiveContext
            ), spent != sim.signState else { continue }

            commit(.signStateChanged(spent))

            // **Vulcan Vault, told at the one hook that only ever answers when
            // a vault was actually taken.**
            //
            // Its `stateAfterMove` returns non-nil exactly when
            // `option.distance > 1` — the same guard `allows` used to permit
            // the leap in the first place — so reaching this line already means
            // the vault happened. Checked by identity rather than by
            // re-deriving the condition, since the condition already ran to
            // produce `spent`.
            if passive is SagittariusVulcanVault {
                commit(.passiveFired(
                    name: SagittariusVulcanVault().displayName, refused: false
                ))
            }
        }

        // 5b. Passives that react to what the move did rather than to what it
        //     was doing — Gemini mirroring repairs downward, Libra levelling a
        //     row that has just gone uniform. Their output is not itself
        //     amended, so a reaction cannot retrigger itself.
        let reactions = sim.activePassives.amend(events, context: sim.passiveContext)
        for reaction in reactions {
            for allowed in sim.shelteredEvents(reaction) { commit(allowed) }
        }

        // 6. Fold the move into the sign's memory: advance the direction
        //    streak. Done before charging so a streak pays out on the move that
        //    extended it. The timers were aged back at 2b, before anything this
        //    move could grant one.
        // **Counted before it is recorded.**
        //
        // The streak was advanced here and the holes were counted twenty lines
        // below it, so what went into `holeJumpStreak` was whatever the landing
        // happened to be carrying rather than what this move cleared. Scorpio
        // is the sign paid per hole crossed, so an ordinary walk could arrive
        // holding a streak it had not earned.
        let nexysPoint = GameRules.nexysPoint
        let walkedToNexys = move.path.last == nexysPoint && !landing.fell

        // A jump flies over the squares between origin and destination; any of
        // those that were open are holes it cleared. A slide settles on every
        // square it crosses, so it can never clear one.
        if move.style == .hop, !landing.fell {
            landing.holesJumped = Self.squaresBetween(origin, move.destination)
                // The Nexys' chasm is not a hole anybody made and not one that
                // can ever be mended, so clearing it is not an achievement —
                // it is a free, permanent pip sitting in the middle of the
                // board. Scorpio's Void Culling is paid for *ruin*.
                .filter { !sim[startingPlane][$0].isSolid && sim[startingPlane][$0].kind == .normal }
                .count

            // **The vault itself, not the charge it earns.**
            //
            // Gated on Scorpio explicitly: this same hop branch is also where
            // Sagittarius' two- and three-square shots and Capricorn's climb
            // land, and a shot of hers clearing a hole would otherwise read as
            // Void Culling firing for the wrong sign. Told before the streak
            // below folds the count away, so this is the one place that still
            // knows the jump was singular rather than the Nth of a run.
            if sim.piece.zodiac == .scorpio, landing.holesJumped > 0 {
                commit(.passiveFired(name: ScorpioVoidCulling().displayName, refused: false))
            }

            // **Capable Climber, told at her only hop.**
            //
            // The mountain pattern has exactly one jump — north, two squares —
            // so reaching this branch as Capricorn already means the climb was
            // taken. No cooldown to check: the passive's own doc says there is
            // none.
            if sim.piece.zodiac == .capricorn {
                commit(.passiveFired(name: CapricornCapableClimber().displayName, refused: false))
            }
        } else {
            // Anything that is not a jump cleared nothing, whatever the landing
            // was carrying when it got here.
            landing.holesJumped = 0
        }

        // 6. Fold the move into the sign's memory: advance the direction streak
        //    and the hole-jump streak. Done before charging so a streak pays out
        //    on the move that extended it. The timers were aged back at 2b,
        //    before anything this move could grant one.
        var updatedState = sim.signState
        updatedState.recordMove(direction: direction)
        updatedState.recordHoleJumps(landing.holesJumped)
        if updatedState != sim.signState {
            commit(.signStateChanged(updatedState))
        }

        // 7. Charge the Zodiaction off what the move amounted to. Built before
        //    the call so the summary is not read while `sim` is being mutated.
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

        // The double answers the move, and then the unopened coin closes in.
        //
        // After the charge rather than before it: what the shadow wrecks is not
        // the player's doing, and a sign that pays for broken ground would
        // otherwise be paid for damage it did not cause.
        events += sim.moveShadow(mirroring: (
            dx: sim.piece.point.x - origin.x,
            dy: sim.piece.point.y - origin.y
        ))
        events += sim.advanceShadowCoin()

        // And the halves change over. Last, so everything above resolved for the
        // half that actually took the turn.
        events += sim.passTheTurn()

        // TODO: `ZodiacPassive.bonusMoves` and the forced-movement pickups both
        // need a follow-up move appended here. Deferred until those designs are
        // specified — the hook exists but nothing returns a non-zero value yet.

        return events
    }

    /// Fires a **phantom's** Zodiaction, free, and dismisses it.
    ///
    /// The borrowed super costs no meter — the meter was already spent calling
    /// the phantom — and using it is what the loan was for, so the phantom goes
    /// with it. Otherwise identical to an ordinary pop: it counts as a turn, it
    /// settles where it leaves the piece, and it may ask the player a question.
    mutating func planRetinueZodiaction(_ follower: Zodiac) -> [GameEvent] {
        guard !isGameOver, signState.retinue.contains(follower) else { return [] }
        guard canFireRetinueZodiaction(follower) else { return [] }

        var sim = self
        defer { self.rng = sim.rng }

        var events: [GameEvent] = []
        func commit(_ event: GameEvent) {
            events.append(event)
            sim.apply(event)
        }

        let planeBefore = sim.piece.plane
        let pointBefore = sim.piece.point

        // Borrowed or your own, a super is a thing you *did* — see
        // `PassiveContext.duringZodiaction`. A phantom Pisces taking you down
        // dives; it does not drop you.
        sim.isFiringZodiaction = true
        defer { sim.isFiringZodiaction = false }

        // Stamped at the tail, not here — a borrowed super answers to the same
        // rule as your own. See `actionWasATurn(from:)`.
        let startedAt = (point: pointBefore, plane: planeBefore)

        commit(.zodiactionFired(zodiac: follower, plane: sim.piece.plane))

        // Spent first, so anything the super does — including asking a question
        // and suspending — cannot leave the phantom hanging around afterwards.
        //
        // The purse is the exception: a borrowed Capricorn has to keep its coins
        // until the purchase it was popped for has actually resolved, so it is
        // emptied on the way out of `planChoice` instead.
        var released = sim.signState
        released.retinue.removeAll { $0 == follower }
        commit(.signStateChanged(released))

        let context = sim.passiveContext
        for event in follower.zodiaction.activate(context: context, generator: &sim.rng) {
            for allowed in sim.shelteredEvents(event) {
                commit(allowed)
                for sweep in sim.gatherIfCrossed(allowed) { commit(sweep) }
            }
        }

        events += sim.openCarriedPickups()

        if sim.pendingChoice != nil {
            events += sim.tickForTurn()
            return events
        }

        let moved = sim.piece.plane != planeBefore || sim.piece.point != pointBefore
        let groundGone = !sim[sim.piece.plane][sim.piece.point].isSolid
        if !sim.isGameOver, moved || groundGone {
            events += sim.settle(arrivedByFalling: false, wearsOnArrival: false).events
        }

        let reactions = sim.activePassives.amend(events, context: sim.passiveContext)
        for reaction in reactions {
            for allowed in sim.shelteredEvents(reaction) { commit(allowed) }
        }

        if sim.actionWasATurn(from: startedAt) {
            for reveal in sim.rollPickupReveal(destination: sim.piece.point) {
                commit(reveal)
            }
            commit(.moveCommitted(direction: sim.piece.facing))
            events += sim.tickForTurn()
        }

        // The double answers the move, then the unopened coin closes in. Both
        // after the player has settled, so they react to where the player
        // actually ended up rather than where the move was aimed.
        events += sim.moveShadow(mirroring: (
            dx: sim.piece.point.x - pointBefore.x,
            dy: sim.piece.point.y - pointBefore.y
        ))
        events += sim.advanceShadowCoin()

        events += sim.ensurePentacleAvailable(previousPlane: planeBefore, after: events)
        events += sim.passTheTurn()
        return events
    }


    /// Moves the shadow opposite to the move just taken, and resolves what it
    /// ran into.
    ///
    /// Called after the player's own travel has settled, so the shadow reacts to
    /// where they actually ended up rather than to where they aimed.
    ///
    /// ## Order of the checks
    ///
    /// Collision first, because walking into the shadow is a *choice* and has to
    /// beat everything else — including the case where both would be standing on
    /// a hole. Then the ground it landed on. Then a Pentacle, which it destroys
    /// by arriving on.
    private mutating func moveShadow(mirroring offset: (dx: Int, dy: Int)) -> [GameEvent] {
        guard let current = shadow, !isGameOver else { return [] }

        var events: [GameEvent] = []
        func commit(_ event: GameEvent) {
            events.append(event)
            apply(event)
        }

        // Mirrored: the player went one way, it goes the other.
        let target = GridPoint(current.point.x - offset.dx, current.point.y - offset.dy)

        // Into a wall is simply nowhere. It stays put and the turn passes — a
        // shadow that could be parked against an edge for ever would be a
        // shadow you never had to deal with.
        guard self[current.plane].contains(target) else { return events }

        commit(.shadowStepped(from: current.point, to: target, plane: current.plane))

        // Caught: standing where the player is standing.
        if current.plane == piece.plane, target == piece.point {
            commit(.shadowDestroyed(at: target, plane: current.plane, caught: true))
            return events
        }

        // Onto a coin, which it snuffs out by arriving.
        if revealedPickups.contains(where: { $0.plane == current.plane && $0.point == target }) {
            for coin in revealedPickups
            where coin.plane == current.plane && coin.point == target {
                commit(.pickupDestroyed(id: coin.id, plane: coin.plane, point: coin.point))
            }
            commit(.shadowDestroyed(at: target, plane: current.plane, caught: false))
            return events
        }

        let tile = self[current.plane][target]

        // Its own island holds it up. See `Shadow.onShadowNexys`.
        let sheltered = current.onShadowNexys && target == GameRules.nexysPoint

        if !tile.isSolid, !sheltered {
            commit(.shadowDestroyed(at: target, plane: current.plane, caught: false))
            return events
        }

        // It wears the ground exactly as the player does, which is the whole
        // cost of leaving it alive.
        if tile.canBeWorn {
            commit(.tileDamaged(
                plane: current.plane, point: target, to: tile.health.damaged
            ))
        }

        return events
    }

    /// Walks an unopened Shadow Work coin one square toward the player.
    ///
    /// The only Pentacle in the game that comes to you. Diagonals included, so
    /// it closes on the shortest path rather than tracing the grid — being
    /// chased by something that has to turn corners is not being chased.
    private mutating func advanceShadowCoin() -> [GameEvent] {
        guard let coin = revealedPickups.first(where: { $0.id == .shadowWork }),
              coin.plane == piece.plane,
              !isGameOver
        else { return [] }

        let step = GridPoint(
            coin.point.x + (piece.point.x - coin.point.x).signum(),
            coin.point.y + (piece.point.y - coin.point.y).signum()
        )

        var events: [GameEvent] = []

        if step != coin.point, self[coin.plane].contains(step) {
            let moved = GameEvent.pickupMoved(
                id: coin.id, plane: coin.plane, from: coin.point, to: step
            )
            apply(moved)
            events.append(moved)
        }

        // Caught, when it is the coin that did the catching.
        //
        // Every other Pentacle in the game is collected by the piece arriving on
        // it, which is checked when the piece moves — so a coin that walks onto
        // a stationary player was never checked by anything. It simply sat on
        // top of the piece and kept trying to close a distance of nothing, which
        // is the one outcome Shadow Work is built to reach.
        //
        // Run through the ordinary collection so it opens exactly as it would
        // have if it had been walked onto: same event, same effect, same charge
        // for taking it.
        let collection = resolvePickupCollection()
        events += collection.events

        return events
    }

    /// Ends a turn for a split Gemini: rejoin if the halves have met, otherwise
    /// hand control to the other one.
    ///
    /// Checked in one place and appended by every planner that finishes a turn,
    /// so a move, a Zodiaction and a lift all alternate — a rule that held for
    /// ordinary moves alone would be a rule the player could not trust.
    private mutating func passTheTurn() -> [GameEvent] {
        guard isSplit, !isGameOver, let waiting = otherHalf else { return [] }

        var events: [GameEvent] = []
        func commit(_ event: GameEvent) {
            events.append(event)
            apply(event)
        }

        // Standing in the same place on the same plane is being one piece
        // again. Checked before the swap, because after it the question is the
        // same but the answer is written from the other side.
        if waiting.plane == piece.plane, waiting.point == piece.point {
            commit(.piecesRejoined)
            return events
        }

        commit(.turnPassed)
        return events
    }

    /// Calls the island, or rides it.
    ///
    /// Libra's Judicator Elevator, as a button rather than as a thing that
    /// happens when you stand somewhere. Two states and no third:
    ///
    /// - The island is on the **other** plane: it comes here. Nothing else
    ///   moves.
    /// - Libra is standing **on** it: it goes, and takes her with it.
    ///
    /// Deliberately not a toggle. An island on this plane that Libra is not
    /// standing on does nothing at all when the button is pressed — otherwise
    /// the sensible play is to sit still and flap it back and forth, which is
    /// neither a decision nor something anybody enjoys watching.
    ///
    /// Both count as a turn, for the same reason a Zodiaction does: the board
    /// changed because the player asked it to.
    /// Wakes a dormant Polaris if these events exposed it to astral energy.
    ///
    /// Three ways, and they are the same way three times: **a Zodiaction fired**,
    /// **arriving on Astra**, or **an Astral Essence opened**. All three are the
    /// player putting raw astral energy through the piece, which is what a cold
    /// fragment of Old Astra needs and cannot get by being carried around Terra.
    ///
    /// Read off the events rather than asked as a condition, because two of the
    /// three are *moments* rather than states — a pop is over by the time
    /// anything could check for it.
    private mutating func chargePolaris(after events: [GameEvent]) -> [GameEvent] {
        guard signState.polaris == .dormant else { return [] }

        let exposed = events.contains { event in
            switch event {
            case .zodiactionFired:
                true
            case let .pickupCollected(id, _, _):
                PickupCatalog.essences.contains(id)
            case let .pieceFell(_, to, _):
                to == .astra
            case let .pieceMoved(_, _, from, to, _, _, _):
                from != .astra && to == .astra
            case let .nexysMoved(to, carrying):
                to == .astra && carrying
            default:
                false
            }
        }

        guard exposed else { return [] }

        var lit = signState
        lit.polaris = .charged
        return [.signStateChanged(lit)]
    }

    /// True when the fragment is lit and the player may spend it.
    var canFirePolaris: Bool {
        !isGameOver && signState.polaris == .charged
    }

    /// Spends it: the plane you are standing on comes back whole.
    ///
    /// ## Why it falls back rather than refusing
    ///
    /// A repair on an undamaged board is a legendary that does nothing, and a
    /// button that does nothing is worse than no button. The fragment is a piece
    /// of Old Astra either way, so on a board with nothing to mend it does the
    /// other thing Old Astra does — it moves the island. Nobody is ever punished
    /// for holding it until the board looked bad enough.
    mutating func planPolaris() -> [GameEvent] {
        guard canFirePolaris else { return [] }

        var sim = self
        defer { self.rng = sim.rng }

        var events: [GameEvent] = []
        func commit(_ event: GameEvent) {
            events.append(event)
            sim.apply(event)
        }

        var spent = sim.signState
        spent.polaris = nil
        commit(.signStateChanged(spent))

        let plane = sim.piece.plane
        let broken = sim[plane].allPoints.contains {
            sim[plane][$0].kind == .normal && sim[plane][$0].health != .healthy
        }

        if broken {
            commit(.planeRestored(plane: plane))
        } else if sim.nexysPlane != plane {
            commit(.nexysMoved(to: plane, carryingPiece: false))
        } else {
            // Facing the camera for the ride, the same as for a fall.
            commit(.pieceTurned(to: .down))
            commit(.nexysMoved(to: plane.opposite, carryingPiece: true))
        }

        if !sim.isGameOver {
            events += sim.settle(arrivedByFalling: false, wearsOnArrival: false).events
        }

        events += sim.ensurePentacleAvailable(previousPlane: plane, after: events)
        return events
    }

    /// True once a fragment of Old Astra has been picked up this run.
    ///
    /// ## Why the run and not the carry
    ///
    /// Blocking the spawn only while one is *carried* would make Polaris a thing
    /// you farm: spend it, walk back to the north-middle tile, and wait for the
    /// next one. It is a full board repair held until the player decides the
    /// moment is right, which is only a decision if there is exactly one.
    ///
    /// ## Why it is not in `SignState`
    ///
    /// Because that is the sign's scratchpad, and every scope in it is cleared
    /// by either a plane change or a piece change — `runFlags` included, which
    /// a piece change wipes on purpose for Scorpio's sake. "This run has already
    /// produced its Polaris" outlives both. It is a fact about the *run*, so it
    /// lives on the run.
    private(set) var polarisTaken = false

    /// True while there is an arrow in the ground for whoever holds the board.
    ///
    /// Not gated on being Sagittarius. An arrow is a hole punched in the world
    /// and it stays punched — the same rule Gemini's rifts follow.
    var canRecallArrow: Bool { !isGameOver && signState.arrow != nil }

    /// Answering it: out of the world here, back in where the arrow is.
    ///
    /// Free, because the shot was paid for when it was fired, and always a turn,
    /// because the arrow is never in the square you are standing in.
    mutating func planArrowRecall() -> [GameEvent] {
        guard canRecallArrow, let arrow = signState.arrow else { return [] }

        var sim = self
        defer { self.rng = sim.rng }

        var events: [GameEvent] = []
        func commit(_ event: GameEvent) {
            events.append(event)
            sim.apply(event)
        }

        let planeBefore = sim.piece.plane
        let startedAt = (point: sim.piece.point, plane: sim.piece.plane)

        for event in SagittariusAstralArrow.recall(arrow, context: sim.passiveContext) {
            for allowed in sim.shelteredEvents(event) {
                commit(allowed)
                for sweep in sim.gatherIfCrossed(allowed) { commit(sweep) }
            }
        }

        events += sim.openCarriedPickups()

        if !sim.isGameOver {
            events += sim.settle(arrivedByFalling: false, wearsOnArrival: false).events
        }

        if sim.actionWasATurn(from: startedAt) {
            for reveal in sim.rollPickupReveal(destination: sim.piece.point) { commit(reveal) }
            commit(.moveCommitted(direction: sim.piece.facing))
            events += sim.tickForTurn()
            events += sim.ensurePentacleAvailable(previousPlane: planeBefore, after: events)
            events += sim.passTheTurn()
        }

        return events
    }

    mutating func planNexysCall() -> [GameEvent] {
        guard !isGameOver, canCallNexys else { return [] }

        var sim = self
        defer { self.rng = sim.rng }

        var events: [GameEvent] = []
        func commit(_ event: GameEvent) {
            events.append(event)
            sim.apply(event)
        }

        let planeBefore = sim.piece.plane
        let startedAt = (point: sim.piece.point, plane: sim.piece.plane)

        if sim.nexysPlane != sim.piece.plane {
            commit(.nexysMoved(to: sim.piece.plane, carryingPiece: false))
        } else {
            // Facing the camera for the ride, the same as for a fall.
            commit(.pieceTurned(to: .down))
            commit(.nexysMoved(to: sim.piece.plane.opposite, carryingPiece: true))
        }

        // **The button, not the ordinary ride.**
        //
        // Every sign can stand on the Nexys and go up with it; only Libra has a
        // button that calls it or rides it on demand, which is the ability
        // being announced. Told here rather than at `ridesNexysDown` itself —
        // that hook also governs the ordinary walk-onto-the-square case, where
        // nothing about pressing an elevator button is true.
        commit(.passiveFired(name: LibraJudicatorElevator().displayName, refused: false))

        if !sim.isGameOver {
            events += sim.settle(arrivedByFalling: false, wearsOnArrival: false).events
        }

        // Calling the lift is only a turn if you rode it.
        //
        // It used to be one either way, which made summoning the island from the
        // other plane cost a glow phase, a coin roll, every timer on the board
        // and — while split — Gemini's go. Pressing a button to bring the lift to
        // you is not a move, and `actionWasATurn` is the one place that question
        // is answered for everybody. See its note on the third special case.
        if sim.actionWasATurn(from: startedAt) {
            for reveal in sim.rollPickupReveal(destination: sim.piece.point) { commit(reveal) }
            commit(.moveCommitted(direction: sim.piece.facing))
            events += sim.tickForTurn()
            events += sim.ensurePentacleAvailable(previousPlane: planeBefore, after: events)
            events += sim.passTheTurn()
        }

        return events
    }

    /// Whether an action that has just resolved counted as a **turn**.
    ///
    /// ## The rule
    ///
    /// A turn is a *movement of the piece* — a step, a slide, a leap, a fall, a
    /// teleport, a ride. Everything the board does between turns hangs off that:
    /// the glow phase advances, a Pentacle is revealed, buffs and cooldowns
    /// count down, Gemini's other half gets its go.
    ///
    /// ## Why this exists as one function
    ///
    /// Because it was three copies of the same three lines, and they disagreed.
    /// Every Zodiaction claimed a turn whether or not it moved anybody, so
    /// popping Bubble Bastion where you stood advanced the glow phase, ticked
    /// every timer down and rolled the next coin — for an ability whose entire
    /// point is that you do not go anywhere.
    ///
    /// "Treat a Zodiaction as a turn" was the instruction and it was right about
    /// the thing it was aimed at: a super that carries you somewhere is a turn
    /// and used to not be. Applying it to every super was the overcorrection,
    /// and the fix is not a fourth special case — it is asking the question in
    /// the one place the answer is known.
    ///
    /// - Parameter from: Where the piece was before the action ran.
    func actionWasATurn(from: (point: GridPoint, plane: Plane)) -> Bool {
        piece.point != from.point || piece.plane != from.plane
    }

    /// Whether this sign has *any* move in this direction, board aside.
    ///
    /// Asked of the pattern rather than of the position, because the question is
    /// about the piece's repertoire and not about what is in the way. Virgo can
    /// always go diagonally, even when a diagonal happens to be blocked; nobody
    /// else ever can.
    func canEverMove(_ direction: SwipeDirection) -> Bool {
        let movement = activePassives.adjustedMovement(
            base: piece.zodiac.movement,
            context: passiveContext
        )
        return !movement.options(for: direction, facing: piece.facing).isEmpty
    }

    /// The largest reach currently legal this way, or `0` if only a step is.
    ///
    /// Asked of the engine so it goes through `moveOptions(for:)` and therefore
    /// through every passive that can refuse — the vault's own cooldown above
    /// all. A badge that lit whenever the *pattern* had a long move would be
    /// lying about the one thing it exists to report.
    func longestReach(for direction: SwipeDirection) -> Int {
        let options = moveOptions(for: direction)
        guard let longest = options.map(\.distance).max(), longest > 1 else { return 0 }
        return longest - 1
    }

    /// Whether the lift will answer right now.
    var canCallNexys: Bool {
        guard !isGameOver else { return false }
        guard activePassives.ridesNexysDown(context: passiveContext) else { return false }

        // Either it is elsewhere and can be summoned, or it is here and being
        // stood on. An island sitting on this plane with nobody on it is the one
        // case the button ignores.
        return nexysPlane != piece.plane || isOnNexys
    }

    /// Whether a borrowed Zodiaction will actually do anything right now.
    ///
    /// Every super has conditions and they come with it. Virgo's ring refuses
    /// against a wall; Cosmic Cash-in refuses on an empty purse. Leo was firing
    /// them regardless — spending the phantom, playing the summon, and producing
    /// nothing. Cash-in was worse than nothing: with no coins to buy, the shop
    /// opened on an empty belt and the game could not be advanced.
    ///
    /// The context is **Leo's**, which is what `passiveContext` already is.
    /// Leo is the one acting: the ring is dealt around where Leo is standing,
    /// the shop is opened by Leo, and the phantom is the source of the ability
    /// rather than the thing performing it. Rebuilding the context as the
    /// follower would ask where a piece that is only a projection happens to be
    /// standing, which decides nothing.
    func canFireRetinueZodiaction(_ follower: Zodiac) -> Bool {
        guard signState.retinue.contains(follower) else { return false }
        return follower.definition.zodiaction.canActivate(context: passiveContext)
    }

    /// Fills the Zodiaction meter outright.
    ///
    /// Returns an event rather than assigning, so it travels the same path as
    /// every other state change and cannot desync a replay — the rule this
    /// project has broken twice by taking the shortcut.
    ///
    /// Exposed for the debug key. Nothing in play grants a full meter directly;
    /// signs charge through `meterBonus` and `meterGain`.
    /// Brings the meter to **whatever ready means for this sign**.
    ///
    /// Not "fill it": Aquarius is ready at nothing and full is her furthest from
    /// firing, so charging her to the cap is the one state the key must not
    /// leave her in. That is why the debug pop could never fire her — it filled
    /// the meter and then asked a sign who reads it backwards to spend it.
    /// `meterIsAtFiring` already owns the question; this asks it.
    mutating func planFillZodiaction() -> [GameEvent] {
        guard !isGameOver, !meterIsAtFiring else { return [] }
        return [.zodiactionMeterChanged(
            to: piece.zodiac.zodiaction.firesAtEmpty ? 0 : zodiactionMeterMax
        )]
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
    /// Puts `id` on `point` of the plane the piece is on. Debug builds only.
    ///
    /// Places rather than stages — the point of a spawner is to get a coin onto
    /// a named square without waiting for the hunt to offer one. It still goes
    /// out as the ordinary reveal event, so the view animates it in like any
    /// other coin and nothing downstream has to know it was conjured.
    func debugPlacePickup(_ id: PickupID, at point: GridPoint) -> [GameEvent] {
        [.pickupRevealed(id: id, plane: piece.plane, point: point)]
    }

    /// Replaces whatever Pentacle is on the board with `id`, where it stands.
    ///
    /// **The fast version of the spawner.** Naming a square meant choosing one
    /// before every test, when what is actually wanted is nearly always "make
    /// the coin I can already see be *this* coin, so I can walk into it".
    ///
    /// Falls back to placing beside the piece when there is no coin out, so the
    /// button always does something rather than silently doing nothing on the
    /// turns between hunts.
    func debugReplacePickup(_ id: PickupID) -> [GameEvent] {
        if let existing = revealedPentacles.first(where: { $0.plane == piece.plane }) {
            return [
                .pickupDestroyed(
                    id: existing.id, plane: existing.plane, point: existing.point
                ),
                .pickupRevealed(id: id, plane: existing.plane, point: existing.point),
            ]
        }

        // Nothing out: put it on the nearest square that can hold it.
        let candidates = currentBoard.allPoints.filter {
            $0 != piece.point
                && currentBoard[$0].kind == .normal
                && !currentBoard[$0].health.isHole
        }
        let nearest = candidates.min {
            $0.manhattanDistance(to: piece.point) < $1.manhattanDistance(to: piece.point)
        }
        guard let point = nearest else { return [] }
        return [.pickupRevealed(id: id, plane: piece.plane, point: point)]
    }

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

        events += sim.ensurePentacleAvailable(previousPlane: previousPlane, after: events)
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

        // Marked for the length of the plan, so anything that happens *inside* a
        // super knows it was deliberate. A descent is the case that needs it —
        // see `PassiveContext.duringZodiaction`.
        sim.isFiringZodiaction = true
        defer { sim.isFiringZodiaction = false }

        var events: [GameEvent] = []
        func commit(_ event: GameEvent) {
            events.append(event)
            sim.apply(event)
        }

        let planeBefore = sim.piece.plane
        let pointBefore = sim.piece.point
        let startedAt = (point: pointBefore, plane: planeBefore)

        // Deliberately *not* stamped as a turn yet.
        //
        // A pop used to be the one thing in the game that happened outside of
        // time — no move counted, no cooldown ticked, the glow phase sat there
        // refusing to become a Pentacle — and stamping it up front fixed that
        // and overshot: a super that goes off where you stand became a turn too.
        //
        // Whether this is a turn depends on where the piece ends up, which is
        // not known until the super has run. So the stamp and the reveal both
        // wait for the tail, where `actionWasATurn(from:)` is asked once.
        commit(.zodiactionFired(zodiac: sim.piece.zodiac, plane: sim.piece.plane))

        // Context read into a local first: it reads `sim`, and passing `&sim.rng`
        // in the same call would be overlapping access to the same value.
        let zodiactionContext = sim.passiveContext
        for event in sim.piece.zodiac.zodiaction.activate(
            context: zodiactionContext,
            generator: &sim.rng
        ) {
            for allowed in sim.shelteredEvents(event) {
                commit(allowed)
                for sweep in sim.gatherIfCrossed(allowed) { commit(sweep) }
            }
        }

        // A Zodiaction that carried the piece across coins opens them here, for
        // the same reason a Pentacle's slide does: once it has stopped.
        events += sim.openCarriedPickups()

        // Asked the player something? Then nothing below can be decided yet —
        // the meter is still spent, because the ability was used, but where the
        // piece ends up is the player's to say. `planChoice` resumes it.
        if sim.pendingChoice != nil {
            if !sim.piece.zodiac.zodiaction.ignoresMeter(context: sim.passiveContext) {
                commit(.zodiactionMeterChanged(to: sim.piece.zodiac.zodiaction.startingMeter))
            }
            // **The fragment wakes on the firing, not on the finishing.**
            //
            // A Zodiaction that asks a question leaves here and comes back
            // through `planChoice`, which never sees the `zodiactionFired` that
            // started it — so a Zodiaction with a choice in it woke no Polaris
            // at all. Capricorn's is the whole of his: on Terra, where the
            // fragment has no other way to be lit, the shop was a dead end for
            // it. Exposure is a moment, and this is the moment.
            events += sim.chargePolaris(after: events)
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

        // Spent means "back to idle", which is empty for eleven signs and
        // **full** for the one whose meter runs the other way. Zero would leave
        // Aquarius able to fire again immediately, since zero is where he fires
        // from.
        if !sim.piece.zodiac.zodiaction.ignoresMeter(context: sim.passiveContext) {
            commit(.zodiactionMeterChanged(to: sim.piece.zodiac.zodiaction.startingMeter))
        }

        // Passives that react to what just happened get to see a Zodiaction
        // too. They only ever saw ordinary moves, which is why Pisces' geyser
        // fired on a fall it *walked* into and not on the one its own super
        // caused — the dive emits exactly the same `pieceFell`, and nothing was
        // listening.
        let reactions = sim.activePassives.amend(events, context: sim.passiveContext)
        for reaction in reactions {
            for allowed in sim.shelteredEvents(reaction) { commit(allowed) }
        }

        // Everything below happens *because a turn happened*, so it is asked
        // once, here — see `actionWasATurn(from:)`. A super that put the piece
        // somewhere else is a turn; one that went off where you stand is not,
        // and Bubble Bastion should not advance the glow phase or age every
        // cooldown on the board for the privilege of not moving you.
        if sim.actionWasATurn(from: startedAt) {
            for reveal in sim.rollPickupReveal(destination: sim.piece.point) {
                commit(reveal)
            }
            commit(.moveCommitted(direction: sim.piece.facing))
            events += sim.tickForTurn()
        }

        // A Zodiaction can change plane too — Taurus flops through Astra, Pisces
        // swims back up — so it owes the same guarantee a move does. Unconditional
        // because it is a guarantee about the *board*, not about the turn: a
        // plane with no reachable coin is broken however it got that way.
        events += sim.ensurePentacleAvailable(previousPlane: planeBefore, after: events)
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
        let style: MoveType

        /// The pattern option this came from, so a passive can be asked whether
        /// taking it costs anything.
        let option: MovementPattern.MoveOption

        /// Where it ends up if nothing interrupts it.
        var destination: GridPoint

        /// True when this move goes through one of Gemini's rifts.
        var usedRift = false

        init(path: [GridPoint], style: MoveType, option: MovementPattern.MoveOption, origin: GridPoint) {
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
    /// The move a direction resolves to, **after** any reversal.
    ///
    /// ## Why the turn-around lives here and nowhere else
    ///
    /// Because everything that asks a question about a direction comes through
    /// this one function: planning a move, projecting the cursor, listing the
    /// legal directions for the pad. Reversing at the input instead meant every
    /// one of those had to be found and turned around separately — and the two
    /// that were, the keyboard and the cursor, then disagreed with the one that
    /// was not, which is how the piece came to hop one way while the cursor
    /// pointed the other.
    ///
    /// One place also means it cannot be applied twice. A control scheme that
    /// previews a direction and then submits what it previewed would otherwise
    /// reverse it on the way in and again on the way out, arriving back where
    /// it started.
    func resolvedMove(for direction: SwipeDirection, reach: Int = 0) -> ResolvedMove? {
        let movement = activePassives.adjustedMovement(
            base: activeMovement,
            context: passiveContext
        )
        guard let option = movement.option(
            for: direction,
            facing: piece.facing,
            reach: reach
        ) else { return nil }

        // A wall-runner is measured against the board rather than declared, so
        // it is built here and skips the bounds check below — it is in bounds by
        // construction, and empty when there is nowhere to go.
        if option.reachesWall {
            let path = pathToWall(from: piece.point, direction: direction)
            guard !path.isEmpty else { return nil }
            guard activePassives.allows(
                option, direction: direction, path: path, context: passiveContext
            ) else { return nil }
            return ResolvedMove(
                path: path, style: option.style, option: option, origin: piece.point
            )
        }

        let path = movement.path(from: piece.point, direction: direction, option: option)

        // **A shard is a thing standing there, not a hole to fall into.**
        //
        // The four squares the Polarity Prongs break stay occupied for as long
        // as the shards are in them, so they are as unenterable as the Nexys.
        // Tested across the whole path rather than the landing square, so a
        // slide stops at a shard instead of passing through one.
        if path.contains(where: { isProngSquare($0) }) { return nil }

        // **The ring outside the board is a legal square, for whoever can use
        // it.**
        //
        // Aquarius above zero floats over every hole, which removes all of the
        // ways this game kills you *inside* the board — so the rim has to become
        // one, and it cannot do that while the move is refused. One square out
        // in any direction is allowed, and standing there is what ends the run.
        //
        // Checked here rather than per movement type so it holds for the slide,
        // the leap, the brook and the breeze alike: they all come through this.
        if activePassives.mayLeaveTheBoard(context: passiveContext),
           let last = path.last,
           !currentBoard.contains(last),
           path.dropLast().allSatisfy({ currentBoard.contains($0) }),
           currentBoard.isJustOutside(last) {
            return ResolvedMove(
                path: path, style: option.style, option: option, origin: piece.point
            )
        }

        // The whole path has to fit on the board, not just its end: a slide
        // cannot run off the edge and come back.
        if path.isEmpty || !path.allSatisfy({ currentBoard.contains($0) }) {
            // Unless a passive owns that edge. Gemini's mirrors turn the four
            // centre-edge squares into doorways rather than walls, so an
            // otherwise illegal move becomes a jump to the opposite side.
            // Asked of the rifts too when they have been left standing, since
            // the sign holding the board no longer has the passive that owns
            // them.
            let wrap = activePassives.wrappedMove(
                from: piece.point,
                direction: direction,
                context: passiveContext
            ) ?? lingeringRift(from: piece.point, direction: direction)

            if let wrapped = wrap,
               wrapped.allSatisfy({ currentBoard.contains($0) }) {
                var through = ResolvedMove(
                    path: wrapped,
                    style: .hop,
                    option: MovementPattern.MoveOption(.any, distance: 1, style: .hop),
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
        guard activePassives.allows(
            option, direction: direction, path: path, context: passiveContext
        ) else { return nil }

        return ResolvedMove(path: path, style: option.style, option: option, origin: piece.point)
    }

    /// Blown off the edge of the world.
    ///
    /// The meter is emptied **first**, and that is not bookkeeping: at zero the
    /// storm is gone and what is left is the little pot, which is the thing that
    /// should be seen tumbling. Falling as the funnel would be the sign dying in
    /// the form that cannot die.
    private mutating func blowAway(at point: GridPoint, on plane: Plane) -> [GameEvent] {
        var events: [GameEvent] = []

        // **Off Astra is a fall, not a death.**
        //
        // There is a whole plane underneath — the same one a hole drops you
        // onto — and dying in mid-air above it would be the one place in the
        // game where having somewhere to land does not help.
        //
        // **Wrapped**, not clamped.
        //
        // The landing is the opposite edge, so leaving to the east arrives in
        // the west — and carrying on the way you were pointed now walks you
        // back across the board instead of straight off it again.
        //
        // That second fall is the reason. A player holding a direction does not
        // stop holding it because the plane changed, and clamping to the near
        // edge put them one input away from the rim with nothing to say so. The
        // wrap turns a committed direction into a crossing rather than a
        // repeat, and it is the sign's own logic: everything about the
        // waterbearer comes out the other side.
        //
        // The centre tile was the other candidate and is worse in a way that
        // only shows up sometimes — it is the Nexys point, so whenever the
        // island is up, the "safe" square is the chasm.
        if let below = plane.planeBelow {
            let size = self[below].size
            let landing = GridPoint(
                (point.x % size + size) % size,
                (point.y % size + size) % size
            )
            // Facing the camera on the way down — see the other fall site.
            let turn = GameEvent.pieceTurned(to: .down)
            events.append(turn)
            apply(turn)

            let fell = GameEvent.pieceFell(from: plane, to: below, at: landing)
            events.append(fell)
            apply(fell)
            events += settle(arrivedByFalling: true).events
            return events
        }

        // **The rescue is asked before the meter is touched.**
        //
        // This is how Aquarius actually dies — blown off the rim of Terra, not
        // dropped through it — so a passive that saves her from dying has to be
        // consulted here as well as at the fall. And it has to be consulted
        // *first*: the drain below sets the meter to zero, which for the one
        // sign that fires at empty is indistinguishable from being fully
        // charged. Asked afterwards, Eolian Ejection would have been free and
        // automatic; asked here, it costs the storm it is spending.
        //
        // The square handed over is the last one she stood on. `point` is off
        // the board by definition, and nothing can surface from nowhere.
        let size = currentBoard.size
        let edge = GridPoint(
            min(max(point.x, 0), size - 1),
            min(max(point.y, 0), size - 1)
        )
        if let rescue = activePassives.survivesFatalFall(
            at: edge, from: plane, context: passiveContext
        ) {
            for event in rescue {
                events.append(event)
                apply(event)
            }
            return events
        }

        if zodiactionMeter != 0 {
            let drained = GameEvent.zodiactionMeterChanged(to: 0)
            events.append(drained)
            apply(drained)
        }

        let over = GameEvent.gameOver(reason: .blownOffTheBoard)
        events.append(over)
        apply(over)
        return events
    }

    /// Dries up any pool that has no business still being there.
    ///
    /// Water belongs to the fish that brought it. Leave the plane and it is
    /// behind you; stop being Pisces and it was never yours. Both cases are
    /// handled by asking, at the end of every planner, whether each pool is
    /// still standing where the current piece can see it.
    ///
    /// ## The water is not lost, only the pool
    ///
    /// Every evaporation leaves a droplet where the pool was, whether it dried
    /// because the fish left or because something burned it off. A droplet is a
    /// `PickupClass.boon`, so it sits there indefinitely and the Pentacle hunt
    /// carries on around it — which means one left on a plane Pisces has walked
    /// away from is still there when she comes back, rather than being swept up
    /// as a stranded coin.
    private mutating func evaporateStalePools() -> [GameEvent] {
        let stillOwned = piece.zodiac == .pisces
        var stale: [Plane: [GridPoint]] = [:]

        for plane in Plane.allCases {
            for point in self[plane].allPoints where self[plane][point].kind == .pool {
                if stillOwned, plane == piece.plane { continue }
                stale[plane, default: []].append(point)
            }
        }

        return stale.flatMap { plane, points in dryUp(points, on: plane) }
    }

    /// Boils off any pool that something just tried to damage.
    ///
    /// ## Why "tried"
    ///
    /// A pool is structural — `Tile.canBeWorn` is false for it — so nothing can
    /// wear it and ordinary movement never names it. What *does* name it is an
    /// area effect that paints a region without looking: an Astral Blaze across
    /// the 3x3, Leo's sun overhead, a charge burning a line. Those are the hot
    /// things, and this is how they reach the water without any of them needing
    /// to know pools exist.
    ///
    /// So the rule is not "fire evaporates pools" written out in a list of fire
    /// sources — it is *anything that would have damaged this square, had it
    /// been ground*. New effects get the interaction for free.
    ///
    /// Each one leaves a droplet, since the player is standing there to take it.
    private mutating func burnOffPools(namedBy events: [GameEvent]) -> [GameEvent] {
        var struck: [Plane: Set<GridPoint>] = [:]

        for event in events {
            switch event {
            case let .tileDamaged(plane, point, _):
                struck[plane, default: []].insert(point)
            case let .tilesChanged(plane, changes),
                 let .tilesWorn(plane, changes, _),
                 let .tilesWornOnExit(plane, changes, _):
                struck[plane, default: []].formUnion(changes.keys)
            default:
                break
            }
        }

        return struck.flatMap { plane, points in
            dryUp(Array(points), on: plane) + popBubbles(Array(points), on: plane)
        }
    }

    /// Bursts any bubbles on squares that were just struck.
    ///
    /// Same rule as the pools and for the same reason: a bubble is water sitting
    /// on the board, and anything that would have damaged the square it is on
    /// evaporates it. Written here rather than in a list of fire sources so
    /// nothing new has to know bubbles exist.
    ///
    /// Nothing is left behind. A pool leaves a droplet because a pool is a
    /// standing body of water; a bubble is already the smallest piece of it.
    private mutating func popBubbles(_ points: [GridPoint], on plane: Plane) -> [GameEvent] {
        var produced: [GameEvent] = []
        for coin in revealedPickups
        where coin.id == .bubble && coin.plane == plane && points.contains(coin.point) {
            let event = GameEvent.pickupDestroyed(id: coin.id, plane: plane, point: coin.point)
            produced.append(event)
            apply(event)
        }
        return produced
    }

    /// Turns pools into droplets, one for one.
    ///
    /// The single place a pool ever becomes anything else, so the water can
    /// never be lost by one path and preserved by another.
    private mutating func dryUp(_ points: [GridPoint], on plane: Plane) -> [GameEvent] {
        var produced: [GameEvent] = []
        for point in points where self[plane][point].kind == .pool {
            for event in [
                GameEvent.poolEvaporated(plane: plane, point: point),
                GameEvent.pickupRevealed(id: .gaiaDroplet, plane: plane, point: point),
            ] {
                produced.append(event)
                apply(event)
            }
            produced += waterFalls(at: point, on: plane)
        }
        return produced
    }

    /// Every square from the one ahead to the far edge, in order.
    private func pathToWall(from origin: GridPoint, direction: SwipeDirection) -> [GridPoint] {
        let step = direction.unitOffset
        var path: [GridPoint] = []
        var point = origin.offset(by: step)
        while currentBoard.contains(point) {
            path.append(point)
            point = point.offset(by: step)
        }
        return path
    }

    /// Every distance available in `direction` right now, nearest first.
    ///
    /// Drives the on-screen reach selector. Goes through `adjustedMovement` so a
    /// passive that withholds an option — Capricorn's climb on cooldown — is
    /// reflected in what the player is offered, rather than being shown a move
    /// that will not happen.
    func moveOptions(for direction: SwipeDirection) -> [MovementPattern.MoveOption] {
        let movement = activePassives
            .adjustedMovement(base: activeMovement, context: passiveContext)

        return movement.options(for: direction, facing: piece.facing).filter { option in
            let path = movement.path(from: piece.point, direction: direction, option: option)
            return activePassives.allows(
                option, direction: direction, path: path, context: passiveContext
            )
        }
    }

    /// True when one of the Polarity Prongs' shards is standing on `point`.
    func isProngSquare(_ point: GridPoint) -> Bool {
        guard let prongs = signState.prongs, prongs.plane == piece.plane else { return false }
        return prongs.poles.contains { $0.point == point }
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

        /// Aimed at an answer rather than at a move.
        ///
        /// Its own state because it means something different from all of the
        /// others: those report what the ground *is*, and this reports whether
        /// the square is an answer the question will accept. A warp onto a hole
        /// is a real play — green — where a slab hanging off the board is not,
        /// and colouring the first of those by its wear would be the cursor
        /// arguing with a decision it has no stake in.
        case targeting(legal: Bool)
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
        // **The cursor shows where the move lands. It does not work it out.**
        //
        // It used to project its own point from a direction, which meant every
        // rule that decides where a move actually ends — reversed controls, a
        // wall-runner's true stopping square, a passive that refuses — had to
        // be repeated here and kept in step by hand. It never was: the piece
        // and the cursor disagreed the moment either changed.
        //
        // So the engine is asked for the move, and the cursor is given a square
        // like any other object on the board. `resolvedMove` already answers
        // reversal, distance and legality in one place.
        //
        // The projection below survives for the one case a resolved move cannot
        // describe: there is no legal move that way, and the cursor still has to
        // sit somewhere so the player can see *why*.
        let travel = direction ?? piece.facing

        // The pattern used to be consulted here to work out how far the cursor
        // should reach. `resolvedMove` answers that now — and answers it the
        // same way the move itself will, which is the whole point of there
        // being one owner. What is left below is the fallback for when there is
        // no legal move at all.
        let step = travel.unitOffset

        let point: GridPoint = {
            if let landing = resolvedMove(for: travel, reach: reach)?.destination {
                return landing
            }

            // **The reach the piece actually has, not the one the pattern
            // lists.**
            //
            // The fallback took the option the swipe selected and projected it
            // whole — so Scorpio's cursor sat two squares out whenever the
            // vault was picked, including every time Void Culling refuses it
            // for want of a hole. Two squares of cursor followed by a refusal
            // nudge is the game saying *there* and then *no*.
            //
            // `moveOptions` is the list a passive has already filtered, which
            // is the same list `resolvedMove` will consult. Off the end of it
            // — no option available in this direction at all — one square is
            // the right place to point, because that is where the wall is.
            let available = moveOptions(for: travel)
            let distance = available.last(where: { $0.distance <= max(reach, 1) })?.distance
                ?? available.first?.distance
                ?? 1
            return GridPoint(
                piece.point.x + step.dx * distance,
                piece.point.y + step.dy * distance
            )
        }()

        guard currentBoard.contains(point) else {
            // **Off the board is a real square for whoever may leave it** — and
            // a lethal one, so it reads as open ground rather than as a refused
            // move. `impossible` says "this will not happen"; here it will, and
            // it is the last thing that does.
            let lethal = activePassives.mayLeaveTheBoard(context: passiveContext)
                && currentBoard.isJustOutside(point)
            return Cursor(point: point, status: lethal ? .open : .impossible)
        }

        let tile = currentBoard[point]
        var status: CursorStatus = switch tile.kind {
        case .chasm: .open
        // Standing water is somewhere to stand.
        case .nexys, .pool: .clear
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
        // A held Sprite is a hole you can stand on, and the cursor has to say so
        // — a square the board will let you survive must not be drawn as fatal.
        if signState.hasSprite { return true }
        // A hole is ground for anything that floats over it — which is what
        // keeps the cursor white inside the board while the ring outside it
        // stays red. Those are the two things the cursor has to tell apart for
        // this sign, and they are the same colour without this.
        if activePassives.walksOnHoles(context: passiveContext) { return true }
        return activePassives.preventsFall(
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
        guard revealedPentacles.isEmpty, let sparkles else { return [] }

        let board = self[sparkles.plane]
        // A set that was allowed over broken ground keeps every square it has.
        // Filtering here would quietly undo Virgo's ring, whose whole offer is
        // that the coin might be hanging over nothing.
        let usable = sparkles.overBrokenGround
            ? sparkles.points
            : sparkles.points.filter { board[$0].canHostSparkle }

        // A passive may steer the reveal — Virgo's Controlled Compensation puts the
        // coin on the square the move is already heading for. Otherwise it is a
        // straight roll among the surviving sparkles.
        var steered = activePassives.preferredRevealPoint(
            among: usable,
            destination: destination,
            context: passiveContext
        )

        #if DEBUG
        // Straight onto the destination, past the sparkle set — the point is to
        // land on the coin as it appears, and whether that square happened to
        // be lit is the part being skipped.
        if debugSnipesNext, board[destination].canHostSparkle {
            steered = destination
            debugSnipesNext = false
        }
        #endif
        // **The Stardar's square, if one is shining.**
        //
        // Ahead of the steer and the roll both: the marker is a promise made
        // last turn and shown on the board since, and anything that overrode it
        // would be the game breaking its own word in front of the player.
        let promised = signState.stardarPending ? sparkles.marked : nil

        guard let point = promised ?? steered ?? usable.randomElement(using: &rng)
        else { return [] }

        // **Did the coin land on the square being walked to?**
        //
        // For Virgo's ring that is the whole question — the guess. Her steering
        // is silenced while the ring is up, so the coin goes somewhere random
        // among the eight, and stepping onto the one that got it is the thing
        // being rewarded. Everywhere else this is simply true whenever her
        // Controlled Compensation steered the coin, which is why the ring is
        // also required before it pays.
        let sniped = point == destination
        guard let pickup = drawPickup(
            at: point, on: sparkles.plane, sniped: sniped
        ) else { return [] }

        var events = [GameEvent.pickupRevealed(id: pickup, plane: sparkles.plane, point: point)]

        // **Controlled Compensation, told only when it is the reason.**
        //
        // `steered == point` is true whenever her steering supplied the answer
        // — but so is a Stardar mark that happens to agree with it, and the
        // mark's promise takes priority over her aim. `promised == nil` is what
        // rules that coincidence out.
        if promised == nil, let steer = steered, steer == point {
            let named = GameEvent.passiveFired(
                name: VirgoControlledCompensation().displayName, refused: false
            )
            events.append(named)
        }

        events += hydroponicSnipe(sniped: sniped, at: point, on: sparkles.plane)
        events += secondReveal(among: usable, excluding: point, on: sparkles.plane)

        // Bubbles are rolled last and take no square the hunt wanted.
        //
        // They are not a second chance at the coin — they sit *beside* it, on
        // sparkles it did not use, which is why a phase can end with two of each.
        events += revealBubbles(
            among: usable,
            excluding: events.compactMap(\.revealedPoint),
            on: sparkles.plane
        )
        return events
    }

    /// The bubbles that appear alongside a reveal, if any.
    ///
    /// Rolled per bubble rather than as one draw with a count, so the chance
    /// means the same thing however many are allowed, and so the run's luck —
    /// Sagittarius' Fortunate Find — scales them without knowing they exist.
    /// **Hidden: what the bull's hooves do to a square she called right.**
    ///
    /// Hitting the sparkle that held the coin waters it — the tile comes back
    /// whole and flowers over — and the watering costs her a pip, the same pip
    /// every other thing her hooves grow costs. So a snipe pays one and spends
    /// one: her reward is the ground rather than the charge, which is the trade
    /// the whole kit is built on.
    ///
    /// Holes are left alone. There is nothing there to grow in, and a coin
    /// found over one is already a strange enough gift.
    private mutating func hydroponicSnipe(
        sniped: Bool,
        at point: GridPoint,
        on plane: Plane
    ) -> [GameEvent] {
        guard sniped,
              activePassives.growsOnWater(context: passiveContext),
              self[plane].contains(point),
              !self[plane][point].health.isHole
        else { return [] }

        var events: [GameEvent] = []
        if self[plane][point].health != .healthy {
            events.append(.tileHealed(plane: plane, point: point, to: .healthy))
        }
        events.append(.tileCoverChanged(plane: plane, point: point, to: .flowers))
        events += hydroponicCost()
        return events
    }

    /// Water landing on a square, and what it leaves growing.
    ///
    /// Every drop in the game comes through here: a bubble surfacing, a droplet
    /// left where a pool dried, the Brook washing past. Cover is *fed* rather
    /// than worn — bare ground greens, grass flowers — which is the rule
    /// `WearCause.water` states for damage and this states for arrival.
    ///
    /// Terra only, since Astra is cloud and nothing grows on it, and never on a
    /// hole: there is nothing there to soak.
    private mutating func waterFalls(at point: GridPoint, on plane: Plane) -> [GameEvent] {
        guard plane == .terra, self[plane].contains(point) else { return [] }

        let tile = self[plane][point]
        guard !tile.health.isHole else { return [] }

        // **Water feeds what is growing. It does not plant.**
        //
        // Bare ground stayed bare: a droplet landing on stone made grass out of
        // nothing, which is Taurus' whole job being done for free by anyone
        // carrying water. Feeding is grass to flowers — an upgrade to something
        // already there.
        guard tile.cover != nil else { return [] }

        let fed = GroundCover.watered(tile.cover, at: point, seed: moveCount)
        guard fed != tile.cover else { return [] }

        let event = GameEvent.tileCoverChanged(plane: plane, point: point, to: fed)
        apply(event)
        return [event]
    }

    /// The pip a hydroponic growth costs, wherever it was raised from.
    ///
    /// One rule, one place. It was being charged for some growths and not
    /// others depending on which passive happened to plant them, which is the
    /// kind of inconsistency that reads as a bug even when each half is
    /// deliberate. Tapping Astral water is not free for a sign that is not a
    /// water sign.
    private func hydroponicCost() -> [GameEvent] {
        let paid = max(zodiactionMeter - GameRules.hydroponicCost, 0)
        return paid == zodiactionMeter ? [] : [.zodiactionMeterChanged(to: paid)]
    }

    private mutating func revealBubbles(
        among usable: [GridPoint],
        excluding taken: [GridPoint],
        on plane: Plane
    ) -> [GameEvent] {
        let chance = activePassives.bubbleChance(context: passiveContext)
        guard chance > 0 else { return [] }

        var free = usable.filter { !taken.contains($0) }
        var events: [GameEvent] = []

        for _ in 0..<GameRules.bubbleMaxPerPhase {
            guard !free.isEmpty else { break }
            let roll = Double(rng.next() % 10_000) / 10_000
            guard roll < min(chance * luck, 1) else { continue }

            guard let index = free.indices.randomElement(using: &rng) else { break }
            let point = free.remove(at: index)
            let event = GameEvent.pickupRevealed(id: .bubble, plane: plane, point: point)
            apply(event)
            events.append(event)
            // A bubble is water arriving, so the ground it lands on drinks.
            events += waterFalls(at: point, on: plane)
        }

        return events
    }

    /// What the coin on `point` turns out to be.
    ///
    /// ## Why the square is an input
    ///
    /// Because several rules are about the square and none of them can be
    /// expressed before it is known. Polaris is the clear case — one tile in
    /// forty-nine, a third of the time — but "is that tile among the five
    /// sparkles" was the only question a set-time roll could ask, and that is a
    /// far easier condition than the one the design wanted. Two special cases
    /// grew on top of it before the placement itself was reconsidered.
    ///
    /// Everything a coin's identity depends on is available here, so this is
    /// where the draw belongs.
    private mutating func drawPickup(
        at point: GridPoint,
        on plane: Plane,
        sniped: Bool = false
    ) -> PickupID? {
        #if DEBUG
        // **Read, not consumed.**
        //
        // Every move is planned on a copy of the engine and only the *events*
        // are applied to the real one, so clearing the flag here cleared it on
        // the copy and threw the copy away. The staged coin then came back on
        // every draw for the rest of the run — which is exactly what a restart
        // appeared to fix, because a restart builds an engine that never had
        // the flag set. It is cleared where it is really spent: on applying the
        // reveal that carries it.
        if let forced = debugNextPickup { return forced }
        #endif

        // **Virgo's ring pays for a guess, not for a walk.**
        //
        // Two conditions, and the second one was missing: the set has to be the
        // ring — `.ring` carries no weight in `sparklePatternWeights`, so it is
        // hers alone and the sign never has to be named — *and* the coin has to
        // have landed on the square being stepped onto.
        //
        // Without the second, the ring simply handed it over. The coin is
        // revealed on the move after the Zodiaction, by which time the silence
        // on her steering has lifted, so Controlled Compensation put the coin
        // wherever she happened to be walking and the guess never happened.
        // Every pink coin was a Victorylap.
        if sparkles?.pattern == .ring, sniped {
            return .virgoVictorylap
        }

        // A Stardar promised this reveal. The promise is kept by the *reveal
        // point* rather than here — see `stardarSquare` — so all this has to do
        // is let the promise expire once it is paid.
        if signState.stardarPending, sparkles != nil {
            var state = signState
            state.stardarPending = false
            signState = state
        }

        // The star's own square, and only a third of the time even then.
        if point == GameRules.polarisPoint,
           !polarisTaken,
           Double(rng.next() % 10_000) / 10_000 < GameRules.polarisSpawnChance {
            return .polaris
        }

        return PickupCatalog.rollPickup(
            weighting: pickupWeighting(),
            affinity: piece.zodiac.element,
            using: &rng
        )
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
        let chance = activePassives.secondPickupChance(context: passiveContext)
        guard chance > 0 else { return [] }

        let roll = Double(rng.next() % 10_000) / 10_000
        guard roll < chance else { return [] }

        let leftovers = usable.filter { $0 != taken }
        guard let point = leftovers.randomElement(using: &rng),
              let pickup = drawPickup(at: point, on: plane)
        else { return [] }

        // Sagittarius is the only sign this hook answers for today, so the name
        // is not conditional on who is playing — it does not need to be until a
        // second sign shares the hook.
        return [
            .pickupRevealed(id: pickup, plane: plane, point: point),
            .passiveFired(name: SagittariusFortunateFind().displayName, refused: false),
        ]
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
    /// Which way the last step of a path went, if it went anywhere.
    ///
    /// Derived from the path rather than passed down from the input, because it
    /// has to be the direction actually travelled: a wrap through Gemini's rifts
    /// or a warp arrives facing somewhere the player never asked for, and a
    /// current that continued the *asked* direction would carry the piece the
    /// wrong way out of one.
    private func heading(of path: [GridPoint], from origin: GridPoint) -> SwipeDirection? {
        let last = path.last ?? origin
        let previous = path.count >= 2 ? path[path.count - 2] : origin
        let step = GridOffset(last.x - previous.x, last.y - previous.y)
        return SwipeDirection.allCases.first { $0.unitOffset == step }
    }

    /// **Move the piece. The only way anything does.**
    ///
    /// Everything a move can differ in is an argument here, so a caller states
    /// what it wants and nothing downstream has to work out who asked. That is
    /// the whole design: a Pentacle that wants the piece carried three squares
    /// with a splash at both ends and no damage says exactly that, and the sign
    /// standing on the square has no say in how it looks or what it costs.
    ///
    /// Before this, movement was assembled at each call site out of paths,
    /// styles and hand-written events, and the gaps were filled in by asking
    /// *which sign is this* — which is how an archer teleported by a gust
    /// launched himself after an arrow he had not fired, and how a Breeze could
    /// pick up a sign's vault animation by standing too close to it.
    ///
    /// - Parameters:
    ///   - destination: Where the piece ends up.
    ///   - plane: The plane it ends up on. Defaults to the one it is on;
    ///     only `MoveType.mayChangePlane` types may name a different one.
    ///   - type: How it travels — which decides the pace, the arc, the sound of
    ///     it, and what the ground pays unless `damagesOn` overrules.
    ///   - effect: A sprite to play, or `nil`. **The caller's**, not the sign's.
    ///   - effectPlaysOn: Where that sprite plays.
    ///   - damageMod: A multiplier on the wear this move deals. `0` costs the
    ///     ground nothing, `2` bites twice as deep, and a negative repairs —
    ///     `-2` mends two stages, which is how a healing move is written.
    ///   - damagesOn: Which end of the move pays, overriding what the type
    ///     implies. `nil` takes the type's own answer.
    @discardableResult
    mutating func move(
        to destination: GridPoint,
        on plane: Plane? = nil,
        as type: MoveType,
        effect: EffectSprite? = nil,
        effectPlaysOn: MoveMoment = .never,
        damageMod: Int = 1,
        damagesOn: MoveMoment? = nil
    ) -> [GameEvent] {
        let landing = travel(
            path(to: destination, as: type),
            type: type,
            toPlane: type.mayChangePlane ? (plane ?? piece.plane) : piece.plane,
            effect: effect,
            effectPlaysOn: effectPlaysOn,
            damageMod: damageMod,
            damagesOn: damagesOn
        )
        return landing.events
    }

    /// The squares a move of this type actually visits.
    ///
    /// A type that travels the ground walks the line; one that leaves it, or
    /// never crosses it at all, has only a destination. Worked out here so no
    /// caller builds a path by hand and gets the two rules confused.
    private func path(to destination: GridPoint, as type: MoveType) -> [GridPoint] {
        guard type.travelsTheGround, destination != piece.point else { return [destination] }

        let dx = destination.x - piece.point.x
        let dy = destination.y - piece.point.y
        let steps = max(abs(dx), abs(dy))
        guard steps > 0 else { return [destination] }

        // Only straight lines and true diagonals can be walked. Anything else
        // is not a path — it is two moves — so it arrives as one.
        guard dx == 0 || dy == 0 || abs(dx) == abs(dy) else { return [destination] }

        let stepX = dx == 0 ? 0 : dx / abs(dx)
        let stepY = dy == 0 ? 0 : dy / abs(dy)
        return (1...steps).map {
            GridPoint(piece.point.x + stepX * $0, piece.point.y + stepY * $0)
        }
    }

    private mutating func travel(
        _ path: [GridPoint],
        type: MoveType,
        toPlane: Plane? = nil,
        effect: EffectSprite? = nil,
        effectPlaysOn: MoveMoment = .never,
        damageMod: Int = 1,
        damagesOn: MoveMoment? = nil
    ) -> LandingResult {
        // What this move costs the ground, held for its length. Same shape as
        // `moveWearTiming` and for the same reason: the question is asked at
        // several moments and the answer must not change between them.
        moveDamageMod = damageMod
        moveDamageMoment = damagesOn ?? type.wear
        moveTravelType = type
        defer {
            moveDamageMod = 1
            moveDamageMoment = nil
            moveTravelType = .hop
        }
        let style = type
        let arrivalPlane = toPlane ?? piece.plane

        // Worked out **before** the piece moves.
        //
        // `heading(of:from:)` measures the last step against where the piece is
        // standing, so asking after travel has run compares the destination with
        // itself and yields nothing. That is why the current never started: the
        // hole had no direction to carry the piece in.
        let travelled = heading(of: path, from: piece.point)

        var result = LandingResult()
        guard !isGameOver else { return result }

        // One square is a step, whatever the pattern calls it.
        //
        // Almost every movement in the game is declared `.slide`, because that
        // was the harmless default back when a slide simply meant "walk each
        // square in turn". It means something specific now — two ends worn and
        // the middle merely crossed, one turn however far it goes — and none of
        // that is true of a move with no middle. Left alone, every ordinary step
        // in the game charged its exit tile, pressed the ground, and swept
        // coins over the piece's head.
        // `.blown` is exempt: it is the one type that *means* something at one
        // square, because it is a statement about who is doing the moving. See
        // `MoveType.blown`. So is anything that does not walk at all — a
        // teleport of one square is still a teleport.
        let effective: MoveType = (path.count > 1 || !style.travelsTheGround || style == .blown)
            ? style
            : .hop

        switch effective {
        case .charge:
            // Every square, and each one charged as it is left — the difference
            // between running across ground and being carried over it.
            for square in path {
                let departure = departCurrentTile(force: true, cause: .brazenBlaze)
                result.absorb(departure)

                let step = GameEvent.pieceMoved(
                    from: piece.point, to: square,
                    fromPlane: piece.plane, toPlane: piece.plane,
                    type: .charge,
                    effect: effect,
                    effectPlaysOn: effectPlaysOn
                )
                result.events.append(step)
                result.covered.append(square)
                apply(step)

                // Swept up as it is passed, exactly as a slide does.
                //
                // Left out when the charge was split off from the slide, which
                // meant the one movement in the game that crosses the most
                // ground was the one that picked nothing up off it. Anything
                // `travelsTheGround` collects what it runs over — the styles
                // differ in what they do *to* the ground, not in whether they
                // are on it.
                for gathered in gatherIfCrossed(step) { result.events.append(gathered) }

                if isGameOver { return result }
            }

            // The last moment a coin can change what the arrival does — see the
            // same call in the slide.
            result.events += openCarriedPickups()

            result.absorb(settle(arrivedByFalling: false, heading: travelled))

        case .hop, .superJump:
            // Airborne: touches only where it lands.
            guard let destination = path.last else { return result }

            let hop = GameEvent.pieceMoved(
                from: piece.point,
                to: destination,
                fromPlane: piece.plane,
                toPlane: piece.plane,
                type: effective,
                effect: effect,
                effectPlaysOn: effectPlaysOn
            )
            result.events.append(hop)
            result.covered.append(destination)
            apply(hop)

            result.absorb(settle(arrivedByFalling: false, heading: travelled))

        case .teleport, .rise:
            // Arrives, and that is all. No push-off, nothing crossed.
            guard let destination = path.last else { return result }

            let jump = GameEvent.pieceMoved(
                from: piece.point, to: destination,
                fromPlane: piece.plane, toPlane: arrivalPlane,
                type: effective,
                effect: effect,
                effectPlaysOn: effectPlaysOn
            )
            result.events.append(jump)
            result.covered.append(destination)
            apply(jump)
            result.absorb(settle(arrivedByFalling: false, heading: travelled))

        case .blown:
            // Carried. One square, on the ground, and the ground pays nothing —
            // the wind is doing the moving. It goes out as an ordinary step so
            // everything downstream treats it as one; the style rides along and
            // decides how it is drawn and what it costs.
            guard let destination = path.last else { return result }

            let carried = GameEvent.pieceMoved(
                from: piece.point,
                to: destination,
                fromPlane: piece.plane,
                toPlane: piece.plane,
                type: .blown,
                effect: effect,
                effectPlaysOn: effectPlaysOn
            )
            result.events.append(carried)
            result.covered.append(destination)
            apply(carried)

            result.events += openCarriedPickups()
            result.absorb(settle(arrivedByFalling: false, heading: travelled))

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

                // Swept up *as it is passed*, not tallied for afterwards.
                //
                // The sweep used to happen back in `plan`, once the move was
                // over — which meant a slide that ended by breaking through the
                // floor never collected anything, because the piece was already
                // falling and that whole step was skipped. A coin crossed on the
                // way is exactly the coin that might have saved the run.
                for gathered in gatherIfCrossed(step) { result.events.append(gathered) }
            }

            // Opened **before** the landing is resolved.
            //
            // The piece has already arrived — every `pieceSlid` was applied — so
            // this is "once it has stopped" in every sense that matters, and it
            // is the last moment a coin can do anything about what the landing
            // is going to do. A Breeze swept up on the way is exactly the coin
            // that saves a slide into a badly cracked tile, and opening it after
            // the fall meant it never got the chance.
            result.events += openCarriedPickups()

            result.absorb(settle(arrivedByFalling: false, heading: travelled))
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
        wearsOnArrival: Bool = true,
        heading: SwipeDirection? = nil
    ) -> LandingResult {
        var result = LandingResult()
        var fellAlready = arrivedByFalling

        // Crazy Current speaks once per chain, not once per hole — see where
        // it is read below.
        var crazyCurrentAnnounced = false

        func commit(_ event: GameEvent) {
            result.events.append(event)
            apply(event)
        }

        while !isGameOver {
            let plane = piece.plane
            let point = piece.point

            // 0. **Is there even a square here?**
            //
            // First, before anything reads a tile. The ring outside the board
            // has no tile at all, so every line below this one traps on it —
            // which is what crashed rather than ended the run. Only a sign that
            // may leave can be standing here; reaching it means the run is over.
            if !self[plane].contains(point) {
                result.events += blowAway(at: point, on: plane)
                return result
            }

            // 0b. **A sigil under your feet is a doorway.**
            //
            //     Walk onto either end of a pair and it puts you out at the
            //     other. Both are spent by the trip — a doorway that stayed
            //     open would be a free shuttle rather than a coin — and a lone
            //     sigil does nothing at all, because it has nowhere to lead
            //     until its partner is found.
            if signState.miasmaMarks.count >= GameRules.miasmaMarkLimit,
               let entered = signState.miasmaMarks.firstIndex(
                   where: { $0.point == point && $0.plane == plane }
               ) {
                let exit = signState.miasmaMarks[(entered + 1) % signState.miasmaMarks.count]
                var state = signState
                state.miasmaMarks = []
                commit(.signStateChanged(state))
                commit(
                    .pieceMoved(
                        from: point,
                        to: exit.point,
                        fromPlane: plane,
                        toPlane: exit.plane,
                        type: .teleport
                    )
                )
                continue
            }

            // 1. Wear the tile the piece is on. Skipped for tiles that are
            //    already open, for the Nexys, and when a passive or the
            //    free-fall rule says this landing is weightless.
            let landed = self[plane][point]
            // Recorded before wear, so a passive can tell "I stepped onto a
            // hole" from "the tile I stepped onto became one under me".
            arrivedOnOpenGround = !landed.isSolid
            let earnsWear = wearsOnArrival
                && (!fellAlready || GameRules.fallingLandingCausesWear)
            let passiveAllows = activePassives.causesWear(
                on: landed,
                at: point,
                plane: plane,
                afterFalling: fellAlready,
                context: passiveContext
            )

            // Airborne signs charge their wear to the tile they push off from
            // instead, which `departCurrentTile()` handles at the other end of
            // the move. Nothing is owed on arrival.
            // The answer from the start of the move — see where it is set.
            let timing = moveWearTiming

            // `landed.canBeWorn` is deliberately **not** a condition here.
            //
            // It asks whether *this* square can take damage, and for a sign that
            // redirects its damage elsewhere that is the wrong question: Libra
            // stepping onto the Nexys owes the flanks a trench either way. The
            // island's own immunity is enforced inside `applyWear`, where it
            // belongs.
            if earnsWear, passiveAllows, timing == .onEntry {
                result.absorb(applyWear(to: point, on: plane, arrivedByFalling: fellAlready))
            } else if earnsWear, !passiveAllows, timing == .onEntry,
                      piece.zodiac == .aries,
                      !signState.planeFlags.contains(AriesSearingStride.freshTileKey) {
                // **Searing Stride's one free tile, told rather than left to be
                // noticed.** `causesWear` only answers *whether*; this is the
                // one place the engine acts on that answer, so it is the one
                // place that can say *why* wear did not happen. Guarded on the
                // flag being still unset, because every later tile on the same
                // visit answers the same "no" for the ordinary reason — the
                // tile just does not want to wear — and only the first is the
                // passive actually doing something.
                result.events.append(.passiveFired(name: AriesSearingStride().displayName, refused: false))
                apply(result.events.last!)
            }

            // A fall can be softened into a full repair — Virgo always, and
            // Sagittarius on a lucky one. Never fills a hole: a hole is what was
            // fallen into, not what was landed on.
            if fellAlready, landed.canBeRepaired || landed.health == .healthy,
               !landed.health.isHole,
               activePassives.restoresTileOnFallArrival(
                   tile: landed, at: point, plane: plane, context: passiveContext
               ),
               self[plane][point].health != .healthy {
                commit(.tileHealed(plane: plane, point: point, to: .healthy))

                // **Shared by two signs, so named by whoever is playing.**
                //
                // Virgo's Poised Plummet is certain; Sagittarius' Lucky Landing
                // is a roll that only gets here when it hits. Either way, the
                // mend just happened, which is what the aggregate `contains`
                // above already established — this only has to say whose.
                switch piece.zodiac {
                case .virgo:
                    commit(.passiveFired(name: VirgoPoisedPlummet().displayName, refused: false))
                case .sagittarius:
                    commit(.passiveFired(name: SagittariusLuckyLanding().displayName, refused: false))
                default:
                    break
                }
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
            var hovers = activePassives.preventsFall(
                from: plane,
                at: point,
                context: passiveContext
            )
            // Captured before the fairy can flip it, so a save can still be
            // told apart from a rescue further down.
            let passiveCaught = hovers

            // **The fairy takes the first hole you would have gone down.**
            //
            // Spent here rather than at the moment it was picked up, because it
            // has no clock — it waits for however many turns it takes. Checked
            // after the passives so a sign that floats anyway never wastes it.
            if !hovers, !remaining.isSolid, signState.hasSprite {
                hovers = true
                var state = signState
                state.hasSprite = false
                commit(.signStateChanged(state))
            }

            if hovers, !remaining.isSolid {
                if let spent = activePassives
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
                for event in activePassives.eventsOnPreventingFall(
                    at: point, on: plane, context: passiveContext
                ) {
                    commit(event)
                }

                // **Heavenly Hooves, told at the save rather than at the facing.**
                //
                // `preventsFall` only says the goat is looking north; whether
                // that mattered is whether there was a hole here to matter for,
                // which this block already is. `passiveCaught` rather than
                // `hovers` so a fairy's rescue on a move she was not facing
                // north for is never mistaken for the hooves catching her.
                if passiveCaught, piece.zodiac == .capricorn {
                    commit(.passiveFired(
                        name: CapricornHeavenlyHooves().displayName, refused: false
                    ))
                }
            }

            // Walking on air: holes hold the piece up, and so does the chasm.
            //
            // `walksOnHoles` joins them, and differs from both: it is a standing
            // property of the sign rather than something granted for one move,
            // and it is what turns every hole on the board into a current — see
            // `carriedOn`.
            let airborne = signState.walksOnAir
                || airborneThisMove
                || activePassives.walksOnHoles(context: passiveContext)

            // **A hole is a current.**
            //
            // Standing on one while floating is not standing: the wind takes you
            // on, one square at a time, in the direction you were already going,
            // for as long as the next square is also a hole.
            //
            // Straight, never bending. That is not simplicity for its own sake —
            // it makes the rule *total*. "Keep going while the next square is a
            // hole" has an answer for every board, including a blob or a branch,
            // where following the chain needs a tiebreaker the moment two holes
            // are adjacent — and any tiebreaker is a rule the player must learn
            // that is nowhere on the board. Straight can be traced by eye from
            // where you stand, which is what makes stepping in a commitment
            // rather than a gamble.
            if !remaining.isSolid,
               airborne,
               activePassives.walksOnHoles(context: passiveContext),
               let heading {
                // **Once per chain, at its start.**
                //
                // `walksOnHoles` is exclusive to Aquarius, so reaching here at
                // all already means Crazy Current — the only question is
                // whether this is the first hole of a run or the fifth. The
                // flag is local to this call of `settle`, and a chain can never
                // outlive one: it ends the moment the piece reaches solid
                // ground, which is also every path out of this loop.
                if !crazyCurrentAnnounced {
                    crazyCurrentAnnounced = true
                    commit(.passiveFired(
                        name: AquariusCrazyCurrent().displayName, refused: false
                    ))
                }

                let next = point.offset(by: heading.unitOffset)
                commit(.pieceSlid(from: point, to: next, plane: plane))

                // Round the loop again, at the new square. Every hole asks the
                // same question of the one in front of it, so the current runs
                // itself out with no special case for how long it is — and the
                // off-board check at the top of the loop is what ends one that
                // reaches the rim.
                continue
            }

            if remaining.isSolid || hovers || airborne {
                // Coming to rest on somebody else's work claims it.
                result.events += claimAbandonedWorks()

                // An always-on ability with something to offer asks here — at
                // rest, so it is looking at where the piece ended up rather than
                // where it was aimed. The move suspends exactly as a Pentacle's
                // question does; `planChoice` resumes it.
                if let offer = activePassives.offersChoice(context: passiveContext) {
                    commit(.choiceRequested(source: .passive(piece.zodiac), kind: offer))
                    return result
                }

                // Coming to rest on the island while it sits on Terra rides it
                // back up. Checked here — at rest — rather than on entering the
                // square, so a slide that merely crosses the island keeps going.
                // A sign with a call button is never carried off by simply
                // standing somewhere. The island is Libra's lift, and a lift
                // that departs the moment you step in — in whichever direction
                // it feels like — is a trapdoor again. Everyone else still gets
                // the free ride home.
                if GameRules.nexysAscendsFromTerra,
                   plane == .terra,
                   self[plane][point].kind == .nexys,
                   !activePassives.ridesNexysDown(context: passiveContext) {
                    if activePassives.blocksAscent(context: passiveContext) {
                        // **Samsaric Shed, spent.** The ride that would have
                        // happened for anyone else is the thing being refused
                        // — pure restriction, nothing handed back — so this is
                        // the one place in the roll call that earns red.
                        commit(.passiveFired(
                            name: ScorpioSamsaricShed().displayName, refused: true
                        ))
                    } else {
                        // Facing the camera for the ride, the same as for a fall.
                        commit(.pieceTurned(to: .down))
                        commit(.nexysMoved(to: .astra, carryingPiece: true))
                        result.ascended = true
                    }
                }

                return result
            }

            // 3b. Walked into the double, which is a kill and worth the meter.
            //
            //     Checked here rather than in `moveShadow` because the player
            //     arriving at the shadow and the shadow arriving at the player
            //     are the same event with two authors, and only one of them
            //     happens before the ground is tested. Catching it must beat
            //     falling: a square that gives way under both of you is still a
            //     square where you caught it.
            if let double = shadow, double.plane == plane, double.point == point {
                commit(.shadowDestroyed(at: point, plane: plane, caught: true))
            }

            // 4. The phantoms go first.
            //
            //    They are dismissed the instant the piece is *committed* to the
            //    hole, before anything is asked about surviving it — so a
            //    borrowed passive can never answer for a fall. That is one rule
            //    covering every case: an ordinary drop, a fatal one, and the
            //    rescues that would otherwise have had to be special-cased,
            //    Death Dream and Samsaric Shed above all. A loan cannot leave a
            //    permanent ascent lockout on the sign that took it out.
            //
            //    It also reads correctly: they wink out as you go over the edge,
            //    which is when the player expects to lose them.
            if !signState.retinue.isEmpty {
                refundLostRetinue()
                var alone = signState
                alone.retinue = []
                alone = alone.emptyingPurseIfLent(from: signState)
                commit(.signStateChanged(alone))
            }

            // 4a. Down it goes — unless a passive can pull the piece back from
            //     it. Scorpio is the only sign that can, and only twice: once by
            //     dreaming its way back up, once by shedding.
            guard let below = plane.planeBelow else {
                // Sibling Soul. One half going through Terra's floor is not a
                // death while the other is still standing: the soul rises, the
                // survivor absorbs it, and the run carries on with one piece.
                if isSplit {
                    commit(.halfLost(at: point, plane: plane))
                    return result
                }

                if let rescue = activePassives.survivesFatalFall(
                    at: point, from: plane, context: passiveContext
                ) {
                    for event in rescue { commit(event) }
                    return result
                }
            // **Turned to face the camera before it leaves.**
            //
            // Decided here rather than drawn later: a piece in the air is not
            // walking anywhere, so the sprite it was wearing to say which way it
            // was headed is the one thing it should not still be wearing. Its
            // facing is a real thing the rest of the game reads, so this is a
            // real turn — emitted into the event stream ahead of the fall, which
            // means it lands facing this way rather than snapping back to
            // whatever it was doing before it fell.
                commit(.pieceTurned(to: .down))
                commit(.gameOver(reason: .fellThroughTerra))
                return result
            }
            // Gemini comes apart on the way down.
            //
            // Emitted *before* the fall so the half left behind is recorded at
            // the square that gave way — which is where it was standing, since
            // only one of them fell.
            if piece.zodiac == .gemini, plane == .astra, !isSplit,
               piece.zodiac.passives.splitsOnDescent(context: passiveContext) {
                commit(.pieceSplit(
                    strandedAt: point,
                    plane: .astra,
                    // Which twin falls is a coin flip. Neither of them is the
                    // real one, so nothing should be able to predict which of
                    // the two the player is about to be holding.
                    faller: GeminiHalf.allCases.randomElement(using: &rng) ?? .gold
                ))
            }

            // **Turned to face the camera before it leaves.**
            //
            // Decided here rather than drawn later: a piece in the air is not
            // walking anywhere, so the sprite it was wearing to say which way it
            // was headed is the one thing it should not still be wearing. Its
            // facing is a real thing the rest of the game reads, so this is a
            // real turn — emitted into the event stream ahead of the fall, which
            // means it lands facing this way rather than snapping back to
            // whatever it was doing before it fell.
            commit(.pieceTurned(to: .down))
            commit(.pieceFell(from: plane, to: below, at: point))
            result.fell = true
            fellAlready = true

            // Whatever charge was in the meter comes down as water — *after* the
            // fall, not before it.
            //
            // Committed first, the bubbles were already lying all over Terra
            // while the fish was still in the air, so the player arrived at a
            // board that had somehow anticipated them. Rings do not work that
            // way: you hit the ground, and then everything you were carrying
            // leaves you. The impact has to come first for the scatter to read
            // as a consequence of it.
            for spill in scatterMeterAsBubbles(landingOn: below, clearOf: point) {
                commit(spill)
            }

            // Leaving Astra repairs it, so a player who can climb back up finds
            // fresh ground waiting. This is the mechanism that makes long runs
            // possible at all.
            if activePassives.restoresPlaneOnDescent(context: passiveContext),
               plane == .astra {
                commit(.planeRestored(plane: .astra))
            }
        }

        return result
    }

    /// Spills the meter across the plane below as bubbles, one per pip.
    ///
    /// ## Why a fall does not simply cost you the meter
    ///
    /// Because it already costs everything else. Pisces arrives on Terra unable
    /// to cross the board and unable to charge from anything but water, and
    /// wiping the meter on the way down makes the worst moment of the run into a
    /// blank one. Scattering it puts the same value back on the board as *a
    /// layout* — the charge is still there, it is simply somewhere else, and
    /// getting it back is the first thing the fish has to do.
    ///
    /// Like rings, deliberately: they fly out, some of them are lost, and you
    /// spend the next while collecting what you can reach.
    ///
    /// Only for a sign that charges from water. For everybody else a fall is a
    /// fall, and a board full of somebody else's bubbles would be a gift nobody
    /// asked for.
    /// - Parameter landing: The square the piece is about to come down on. Kept
    ///   clear, because a bubble there is one the fall hands you for nothing —
    ///   and the whole point of the scatter is that the charge is somewhere
    ///   *else* now.
    private mutating func scatterMeterAsBubbles(
        landingOn plane: Plane,
        clearOf landing: GridPoint
    ) -> [GameEvent] {
        guard zodiactionMeter > 0,
              activePassives.spillsMeterOnDescent(context: passiveContext)
        else { return [] }

        // Read before the meter is emptied: one bubble per pip, and the pips are
        // about to be gone.
        let pips = zodiactionMeter

        let board = self[plane]

        // One square each, and never the one being landed on. Squares are taken
        // out of `free` as they are used, so two bubbles can never pick the
        // same tile — and anything already holding a pickup is out from the
        // start, so they cannot land on a coin either.
        var free = board.allPoints.filter { point in
            point != landing
                && !revealedPickups.contains { $0.plane == plane && $0.point == point }
        }
        guard !free.isEmpty else { return [] }

        var events: [GameEvent] = [.zodiactionMeterChanged(to: 0)]
        apply(events[0])

        for _ in 0..<min(pips, free.count) where !free.isEmpty {
            guard let index = free.indices.randomElement(using: &rng) else { break }
            let point = free.remove(at: index)

            // A bubble that lands over nothing is gone. It fell into the hole
            // with everything else — which is the cost of the drop, and the
            // reason the scatter is a loss as well as a layout.
            //
            // The Nexys' square is the exception, and it is not a special case
            // so much as the truth about that square: the chasm reads as a hole
            // only while the island is elsewhere. With the island sitting in it
            // there is ground there, and a bubble lands on it like anywhere
            // else.
            let onTheIsland = plane == nexysPlane && point == GameRules.nexysPoint
            guard board[point].isSolid || onTheIsland else { continue }

            let event = GameEvent.pickupRevealed(
                id: .bubble, plane: plane, point: point, thrownFrom: landing
            )
            apply(event)
            events.append(event)
        }

        // The only implementer of `spillsMeterOnDescent` today, so reaching
        // this far already means Delta Distillation. Told once for the spill,
        // not once per bubble it scattered.
        let named = GameEvent.passiveFired(name: PiscesGaiaGeyser().displayName, refused: false)
        apply(named)
        events.append(named)

        return events
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
    /// The Polarity Prongs dragging the piece toward the pole that was lit.
    ///
    /// **The pole that acts is the one the player has been looking at**, and
    /// the next one is rolled immediately after, so the board always shows the
    /// pull you are about to take rather than the one you just did. Four turns,
    /// then the shards shatter — the holes they punched stay, which is the
    /// price of having taken the coin.
    ///
    /// No lockout on the roll. The same pole may come up all four times, and a
    /// run of one direction is a real outcome rather than a fault.
    mutating func planProngPull() -> [GameEvent] {
        guard var prongs = signState.prongs, prongs.plane == piece.plane else { return [] }

        var events: [GameEvent] = []

        // **They land on this move and pull from the next.**
        //
        // The shards arrive as the consequence of a move — the same move that
        // opened the coin — so pulling on it too made picking the Pentacle up
        // cost you a square before anything about it was visible. The board is
        // held still while they come down; this is the same beat, in the rules
        // rather than in the animation.
        if prongs.isArriving {
            prongs.isArriving = false
            var state = signState
            state.prongs = prongs
            let landed = GameEvent.signStateChanged(state)
            apply(landed)
            return [landed]
        }

        // Pulled one square, if there is board that way and ground to hold it.
        let landing = piece.point.offset(by: prongs.active.unitOffset)
        if currentBoard.contains(landing) {
            let carried = GameEvent.pieceMoved(
                from: piece.point,
                to: landing,
                fromPlane: piece.plane,
                toPlane: piece.plane,
                type: .blown
            )
            events.append(carried)
            apply(carried)

            // A pole of your own element pays for the trouble.
            //
            // The shard's element, not the direction's — they are dealt fresh
            // every time the coin is taken, so which way pays is part of what
            // you have to read off the board rather than something you learn
            // once.
            let pulling = prongs.poles.first { $0.direction == prongs.active }
            if pulling?.element == piece.zodiac.element {
                let paid = meter(afterGaining: GameRules.prongMatchCharge)
                if paid != zodiactionMeter {
                    let gained = GameEvent.zodiactionMeterChanged(to: paid)
                    events.append(gained)
                    apply(gained)
                }
            }

            events += settle(arrivedByFalling: false).events
        }

        prongs.movesRemaining -= 1

        var state = signState
        if prongs.movesRemaining <= 0 {
            // Shattered. The holes are not repaired by their going.
            state.prongs = nil
        } else {
            prongs.active = SwipeDirection.cardinals.randomElement(using: &rng) ?? prongs.active
            state.prongs = prongs
        }

        let changed = GameEvent.signStateChanged(state)
        events.append(changed)
        apply(changed)
        return events
    }

    mutating func planPickupPull() -> [GameEvent] {
        // **One puller.**
        //
        // The sun used to drag coins on its own, from back when the magnetism
        // belonged to the Aten rather than to the mane. When it moved to the
        // mane the old path was left standing, so a lion with a sun out pulled
        // twice over — once on the mane's roll and once unconditionally, every
        // move, whatever the mane's odds were. Turning the mane off did not
        // stop it, which is how it was found.
        //
        // What the sun is worth is stated in one place now:
        // `GameRules.magneticManeStepsWithSun`, an extra square on the mane's
        // own pull. It costs a `pickupMoved` per move to be wrong about this —
        // and that event is animated, which is why the lion moved slower than
        // everyone else exactly while his sun was burning.
        if let current = planCurrentDraw() { return current }
        return planMagneticPull() ?? []
    }

    /// Leo's Magnetic Mane: the coin drifts toward the *piece*.
    ///
    /// Returns `nil` when it does not fire, which is what lets the sun take the
    /// turn instead.
    /// The storm dragging a coin that has just surfaced one square toward it.
    ///
    /// **Here rather than at the reveal**, which is where it was and where it
    /// could never work: the coin is planned into existence there and does not
    /// reach the board until the caller commits the event, so a pull that read
    /// the board found nothing to pull. This runs with the other pulls, after
    /// travel, when the coin is real.
    ///
    /// Only coins that surfaced **this move** — the current takes hold as
    /// something appears in it, which is a different idea from Leo's mane
    /// hunting coins down every turn.
    ///
    /// A coin dragged onto her square is collected by the rule that already
    /// follows every pull, and paid as a snipe: she did not call the square,
    /// the wind brought the coin, and that is her version of hitting the shot.
    private mutating func planCurrentDraw() -> [GameEvent]? {
        guard activePassives.drawsPickupsIn(context: passiveContext) else { return nil }

        // **On the reveal, and only on the reveal.**
        //
        // `revealedOnMove == moveCount` is the engine's existing test for "this
        // move" — the loose `>=` it replaces would have let a coin that had been
        // sitting there qualify, which turns walking up to any old Pentacle into
        // a free snipe. The current takes hold of something *surfacing* in it;
        // a coin already on the board is just a coin.
        //
        // Anywhere on her plane. Distance is not the guard — **the reveal is**:
        // it can only ever fire on the turn a coin surfaces, so a coin dragged
        // one square from across the board is a single free nudge on the hunt
        // rather than a way to walk coins in. Leo's mane reaches the whole map
        // *every move*, which is the difference that matters.
        let fresh = revealedPentacles.filter {
            $0.plane == piece.plane && $0.revealedOnMove == moveCount
        }
        guard !fresh.isEmpty else { return nil }

        let drawn = pullCoins(toward: piece.point, on: piece.plane, steps: 1)
        guard !drawn.isEmpty else { return nil }

        // Landed under her: pay what a called shot pays.
        let arrived = drawn.contains { event in
            if case let .pickupMoved(_, _, _, to) = event { return to == piece.point }
            return false
        }
        guard arrived else { return drawn }

        let paid = meter(afterGaining: GameRules.revealTileCharge)
        return paid == zodiactionMeter ? drawn : drawn + [.zodiactionMeterChanged(to: paid)]
    }

    private mutating func planMagneticPull() -> [GameEvent]? {
        let chance = activePassives.magneticPullChance(context: passiveContext)
        guard chance > 0 else { return nil }

        // Never on the turn a coin appears.
        //
        // A Pentacle that slides the instant it is revealed is not a Pentacle
        // the player got to look at, and it breaks any ability that *placed* it
        // somewhere on purpose — Virgo's ring above all, where every square in
        // the ring means something and one of them is the answer. It also
        // removes a whole class of ordering question from everything else that
        // deals a coin.
        guard revealedPickups.allSatisfy({ $0.revealedOnMove < moveCount }) else {
            return nil
        }

        let roll = Double(rng.next() % 10_000) / 10_000
        guard roll < chance else { return nil }

        // An Aten burning is worth an extra square, rather than a second puller.
        let steps = signState.sun == nil
            ? GameRules.magneticManeSteps
            : GameRules.magneticManeStepsWithSun

        return pullCoins(toward: piece.point, on: piece.plane, steps: steps)
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
    /// - Parameter chosen: Pull just this coin and leave the rest where they
    ///   are. Aquarius' current takes hold of the one that surfaced beside her;
    ///   the manes and suns that reel in *everything* leave it `nil`.
    private mutating func pullCoins(
        toward target: GridPoint,
        on plane: Plane,
        steps: Int,
        only chosen: PickupID? = nil
    ) -> [GameEvent] {
        var events: [GameEvent] = []

        // Coins only: a droplet is water lying on a square, not something a
        // sun can reel in.
        for coin in revealedPentacles
        where coin.plane == plane && (chosen == nil || coin.id == chosen) {
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
    /// Whether the Bastion's aura would take this blow, and the state that
    /// remains once it has.
    ///
    /// **Spent by the hit it stops, whatever the hit was worth.** Unlike ground
    /// cover, which soaks one stage and steps down, and unlike a Sanctuary,
    /// which refuses everything for a number of moves, this is one tile and one
    /// blow of any size — see `_Design/project-stars-pickups-backlog.md`.
    ///
    /// Returned rather than applied so the caller can commit the state change
    /// alongside the damage it filtered; `plan` works on a copy of the engine
    /// and only events travel back out of it.
    private func bastionAbsorbing(
        _ changes: [GridPoint: TileHealth],
        on plane: Plane
    ) -> GameEvent? {
        guard let tile = signState.bastion,
              signState.bastionPlane == plane,
              let proposed = changes[tile],
              proposed != self[plane][tile].health
        else { return nil }

        var state = signState
        state.bastion = nil
        state.bastionPlane = nil
        return .signStateChanged(state)
    }

    /// The event as it survives shelter, plus any shield spent stopping it.
    ///
    /// Callers commit the whole array in order — the damage first where it
    /// survived, then the state change — so the aura is seen to be used rather
    /// than simply vanishing between moves.
    func shelteredEvents(_ event: GameEvent) -> [GameEvent] {
        var spent: GameEvent?
        switch event {
        case let .tilesWorn(plane, changes, _),
             let .tilesWornOnExit(plane, changes, _),
             let .tilesChanged(plane, changes):
            spent = bastionAbsorbing(changes, on: plane)
        default:
            break
        }

        return [sheltered(event), spent].compactMap { $0 }
    }

    func sheltered(_ event: GameEvent) -> GameEvent? {
        guard signState.sanctuary != nil
                || signState.arrow != nil
                || signState.bastion != nil
        else { return event }

        switch event {
        // The cause is carried across. Rebuilding the event without it silently
        // demotes a charge or a hoof to an ordinary landing, and the damage then
        // draws itself wrong for the rest of its life.
        case let .tilesWorn(plane, changes, cause):
            let kept = permitted(changes, on: plane)
            return kept.isEmpty
                ? nil
                : .tilesWorn(plane: plane, changes: kept, cause: cause)

        case let .tilesWornOnExit(plane, changes, cause):
            let kept = permitted(changes, on: plane)
            return kept.isEmpty
                ? nil
                : .tilesWornOnExit(plane: plane, changes: kept, cause: cause)

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

            // The Bastion's one tile, which refuses this blow outright.
            if signState.bastion == point, signState.bastionPlane == plane {
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
        onExit: Bool = false,
        cause: WearCause = .landing
    ) -> LandingResult {
        var result = LandingResult()

        // **The one place a move costs the ground.** Every landing, every push
        // off, every hoof and charge multiplier arrives here — so switching it
        // off is one guard rather than a flag threaded through the passives.
        // See `debugDamagesTiles` at the top of `GameScreen`.
        guard GameRules.damagesTiles else { return result }

        func commit(_ event: GameEvent) {
            result.events.append(event)
            apply(event)
        }

        let tile = self[plane][point]

        let proposal = WearProposal(
            tile: tile,
            point: point,
            plane: plane,
            arrivedByFalling: arrivedByFalling,
            stages: cause.stages(on: plane),
            signState: signState
        )
        var seeded = proposal
        seeded.cause = cause
        seeded.moveType = moveTravelType
        // What the move itself asked for, before any passive is consulted: a
        // caller that said `damageMod: 0` wants a move that costs the ground
        // nothing, and a passive that would have deepened it has nothing to
        // deepen. Negative multipliers repair, which `stages` already means.
        seeded.stages *= moveDamageMod

        // And whether this end of the move pays at all.
        if let moment = moveDamageMoment {
            let paid = onExit ? moment.includesExit : moment.includesLanding
            if !paid { seeded.stages = 0 }
        }

        let final = activePassives.modifyWear(seeded, context: passiveContext)

        if final.signState != signState {
            commit(.signStateChanged(final.signState))
        }

        // Everything this landing does to the board, gathered before anything
        // is emitted — see `GameEvent.tilesWorn` for why it leaves as one event.
        var changes: [GridPoint: TileHealth] = [:]

        // Redirected impact: Libra spares what it lands on and hits the flanks
        // instead. Gathered first so a passive that zeroes `stages` still gets
        // its extras.
        for extra in activePassives.additionalWear(from: final, context: passiveContext) {
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
        // **Cover takes one stage and disperses — it does not negate.**
        //
        // Here rather than inside `TileHealth.worn(by:)`, because it is not a
        // property of health: the cover is a separate thing standing on the
        // tile and what happens to it is an event of its own. A blow of two
        // strips the grass *and* still marks the ground, which is the whole
        // distinction from Bastion.
        //
        // Fire is the exception and burns it off without being slowed — the
        // grass is gone and the flame does its full damage to what was under it.
        // **The star wears nothing at all — cover included.**
        //
        // Checked here rather than at each caller because this is the one
        // funnel every landing's damage goes through. It used to sit further
        // down, past the point where the ground had been worked out, which was
        // harmless while wear only meant health: cover is stripped on the way
        // through, so a starred piece was mowing the grass it is supposed to be
        // sailing over.
        guard !signState.isStarred else { return result }

        // **Through the board's own answer, like everything else.**
        //
        // This block used to strip cover to nothing outright, which predates
        // there being two levels of it — so a landing took flowers straight to
        // bare while every other source stepped them down to grass. The rule
        // lives in `Board.wearOutcome` and this asks it rather than keeping a
        // second copy that has to be remembered.
        var stages = final.stages
        let coverOutcome = self[plane].wearOutcome(
            at: point, stages: stages, cause: final.cause, seed: moveCount
        )
        if case let .became(left) = coverOutcome.cover {
            commit(.tileCoverChanged(
                plane: plane, point: point, to: left, burnt: final.cause.singesCover
            ))
        }
        // Only a stage that was actually *soaked up* is a stage spent — see
        // `WearOutcome.absorbed`.
        if coverOutcome.absorbed { stages -= 1 }

        if stages > 0, tile.canBeWorn {
            let health = tile.health.worn(by: stages)
            if health != tile.health {
                changes[point] = health
                result.tilesWorn += 1
                if health.isHole { result.tilesBroken += 1 }
            }
        } else if final.stages < 0, tile.canBeRepaired {
            // Negative stages repair — see `WearProposal.stages`.
            var health = tile.health
            for _ in 0..<(-final.stages) where health != .healthy {
                health = health.healed
            }
            if health != tile.health {
                changes[point] = health
            }
        }



        // A cause may want saying even when it took nothing — Taurus' free
        // footfall is the point of the whole mechanism. The square goes in at
        // the health it already has, so applying the event is a no-op and the
        // presentation still has somewhere to put the smoke.
        if changes.isEmpty, final.cause.isVisibleWithoutChange, tile.kind == .normal {
            changes[point] = tile.health
        }

        guard !changes.isEmpty else { return result }
        // Same rule as everywhere else: a sanctuary refuses the damage, and the
        // event never claims it happened.
        let survived = shelteredEvents(onExit
            ? .tilesWornOnExit(plane: plane, changes: changes, cause: final.cause)
            : .tilesWorn(plane: plane, changes: changes, cause: final.cause))
        guard !survived.isEmpty else { return result }
        for event in survived { commit(event) }

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
    /// - Parameter cause: What is charging the tile, for anything that wears
    ///   differently or draws differently — a charge burns twice as deep and
    ///   leaves fire. See `WearCause`.
    /// Which end of the move pays for the ground, decided as the move begins.
    ///
    /// Held for the length of one move rather than asked twice, because the
    /// question reads the square underfoot and the square underfoot changes
    /// halfway through. See where it is set in `plan`.
    private var moveWearTiming: WearTiming = .onEntry

    /// What this move multiplies its wear by, and which end of it pays.
    ///
    /// Both are arguments to `move` — see it for what the numbers mean — held
    /// for the length of one move because the wear is charged at two different
    /// moments and both have to be answering the same question.
    private var moveDamageMod: Int = 1

    /// How the move being resolved is travelling, for passives that care.
    ///
    /// The water signs read it: being carried along the ground is water doing
    /// the work, and a hop is not.
    private var moveTravelType: MoveType = .hop
    private var moveDamageMoment: MoveMoment?

    private mutating func departCurrentTile(
        force: Bool = false,
        cause: WearCause = .landing
    ) -> LandingResult {
        guard force || moveWearTiming == .onExit else {
            return LandingResult()
        }
        let point = piece.point
        let plane = piece.plane
        guard activePassives.causesWear(
            on: self[plane][point], at: point, plane: plane, context: passiveContext
        ) else { return LandingResult() }

        // **Scrupulous Step's deferral, told at the square that was spared.**
        //
        // Read before `applyWear` mutates it: a tile that was already badly
        // cracked when she stepped off it is the one square where "breaks as
        // you leave it, never as you arrive" is a save rather than a
        // description — anything healthier than that was never in danger of
        // going on this move at all.
        let sparedOnArrival = piece.zodiac == .virgo && self[plane][point].health == .badlyCracked

        var result = applyWear(
            to: point, on: plane,
            arrivedByFalling: false, onExit: true, cause: cause
        )

        if sparedOnArrival {
            let named = GameEvent.passiveFired(name: VirgoScrupulousStep().displayName, refused: false)
            apply(named)
            result.events.append(named)
        }

        return result
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

        // Taking a coin on the very move it appeared is worth a pip, to anyone.
        //
        // ## Why it is a rule rather than a sign's ability
        //
        // Because it rewards the one decision the sparkle phase is actually
        // asking about: five squares light up, one of them is the coin, and
        // reaching the right one first is a guess worth paying for. Handing that
        // to a single sign would make eleven others play the phase as though it
        // were a formality.
        //
        // Virgo is out. Regulated Reboot already pays for landing on a ring's
        // coin, and paying twice for the same step would make her sparkle phase
        // worth more than her Zodiaction.
        //
        // - TODO: Give this its own collection sound — it is a different event
        //   from an ordinary pickup and currently sounds identical.
        for event in snipeReward(for: pickup) { commit(event) }

        // A ring's coin pays whoever takes it, whatever sign that is by then.
        if pickup.fromRing {
            // **No meter here.** Guessing right is what pays, and it pays in
            // Virgo Victorylap — the forced coin on the sniped square, which
            // mends the ground and hands the whole meter back. A refund for
            // missing as well made the Reboot a re-roll button: pop, take
            // whatever turned up, pop again.
            //
            // What a miss gets instead is that the coin is *additional*. A ring
            // coin stands outside `revealedPentacles`, so the ordinary hunt
            // carries on beside it and a spent meter is never nothing. The two
            // changes together are a sidegrade, not a nerf.
            //
            // What a miss does get is the single ZC the coin would have paid if
            // her auto-snipe had not been silenced for the ring — the charge
            // she gave up by taking the gamble, rather than a share of the
            // meter she spent on it. Asked through `meter(afterGaining:)` so a
            // phantom carrying a backwards meter is charged the right way.
            //
            // Paid on any ring coin. A sniped one is already full from the
            // Victorylap, so this only ever moves the needle on a miss.
            let gained = meter(afterGaining: 1)
            if gained != zodiactionMeter { commit(.zodiactionMeterChanged(to: gained)) }

            // **Nothing rescues a missed coin over a hole.**
            //
            // It used to come back to badly cracked whether you had guessed
            // right or not, which took the stakes out of the one decision the
            // Reboot is made of: the ring is dealt over holes on purpose, and
            // if the ground returns either way then reaching over nothing costs
            // nothing. Guess right and the Victorylap mends it to full and
            // hands the meter back; guess wrong over a hole and you go down it.
            // Same shape as Leo's gamble, and the stakes are the point.
        }

        // What the *sign* makes of having opened one, before the ground under
        // the piece is consulted — a coin over a hole is only rescuable here.
        for event in activePassives.collected(
            pickup.id,
            at: pickup.point,
            on: pickup.plane,
            wasSolid: wasSolid,
            context: passiveContext
        ) {
            commit(event)
        }

        // Taking one shatters the others **of its own kind**. Two coins are a
        // choice, not a haul, and so are eight droplets — but a coin and a
        // droplet are two different offers, and taking one has never been a
        // reason to lose the other.
        //
        // Scattered things are the exception, and the one class that really is
        // a haul: bubbles are gathered over as many turns as it takes, so
        // reaching one has nothing to say about the rest.
        let taken = PickupCatalog.effect(for: pickup.id).pickupClass
        for other in revealedPickups
        where taken != .scatter
            && (other.id != pickup.id || other.point != pickup.point)
            && PickupCatalog.effect(for: other.id).pickupClass == taken {
            commit(.pickupDestroyed(id: other.id, plane: other.plane, point: other.point))
        }

        // Capricorn does not open coins, it banks them — the effect never runs
        // and the contents are spent later through Cosmic Cash-in. Z-Charge is
        // the exception the design names: charge cannot be stored as charge, so
        // it goes off like anyone else's.
        if pickup.id != .zCharge,
           activePassives.banksPickups(pickup.id, context: passiveContext) {
            // Kept, always. The purse does not fill up.
            //
            // Quantities stack — two Tears banked are one slot reading two — so
            // there is no ceiling to bump against and nothing is ever lost for
            // being rich. The only Pentacle that never reaches the purse is
            // Z-Charge, which cannot be stored as charge and so goes off where
            // it stands.
            //
            // The ten and eight are the *meter's* size, not the purse's. See
            // `GameRules.purseCapacity(on:)`.
            var state = signState
            state.purse.append(pickup.id)
            commit(.signStateChanged(state))
            commit(.pickupBanked(id: pickup.id, plane: pickup.plane, point: pickup.point))

            // **The deliberate exception to the quiet rule.**
            //
            // Every other passive here speaks only when it bends something;
            // this speaks on every single coin, because it is the only thing
            // that explains why the coin did not do what a coin usually does.
            // See the roll call.
            commit(.passiveFired(
                name: CapricornCelestialCommerce().displayName, refused: false
            ))
            return (true, pickup.id, events)
        }

        let effect = PickupCatalog.effect(for: pickup.id)

        // Effects that need an answer park here. The session collects it and
        // calls `planChoice(_:)`, which resumes from exactly this point.
        guard effect.choice == .none || pointless(effect.choice) else {
            // Asked through `rolledChoice`, so anything random inside the
            // question is decided now and travels with it.
            commit(.choiceRequested(
                source: .pickup(pickup.id),
                kind: effect.rolledChoice(using: &rng)
            ))
            return (true, pickup.id, events)
        }

        // Passed through. It was not, and that was the two-stage fall: opening
        // a coin from inside `settle` ran the effect with its *own* settle still
        // switched on, so a tile that broke underfoot was resolved twice — once
        // by the effect's landing, which dropped the piece and wore the square
        // it arrived on, and again by the loop out here, which found the piece
        // somewhere new and charged it for arriving a second time.
        events += applyEffect(effect, choice: nil, settleAfter: settleAfterEffect)
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
            floatsOverHoles: activePassives.walksOnHoles(context: passiveContext),
            signState: signState
        )

        var plan = effect.plan(context: context, choice: choice, generator: &rng)

        // **Nothing moves her but her.**
        //
        // A coin that would carry the piece somewhere is refused outright, and
        // the whole plan goes with it: the Brook's plan *is* a journey — its
        // wear lands on the ends of a slide that no longer happens — so keeping
        // the remainder would mean damage arriving from a trip nobody took.
        // See `ZodiacPassive.resistsBeingMoved`.
        if activePassives.resistsBeingMoved(context: passiveContext),
           plan.contains(where: \.movesThePiece) {
            plan = plantedInstead()
        }

        for event in plan {
            for allowed in shelteredEvents(event) {
                commit(allowed)
                for sweep in gatherIfCrossed(allowed) { commit(sweep) }
            }
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

        // Being carried breaks a straight line.
        //
        // Aries' Six Singe pays for crossing the board under your own power, and
        // an Astral Brook that sweeps you the width of it is the opposite of
        // that — it is the board doing the crossing. Worse, the Brook reverses
        // at a wall, so the ride could arrive pointing the way the streak was
        // going and quietly finish it off.
        if moved, piece.plane == planeBefore {
            signState.streakDirection = nil
            signState.streakLength = 0
        }
        if settleAfter, moved || groundGone, !isGameOver {
            let landing = settle(
                arrivedByFalling: false,
                wearsOnArrival: effect.arrivalWearsTile
            )
            events += landing.events
        }

        // Leaving Astra repairs it however you left, not only by falling.
        if activePassives.restoresPlaneOnDescent(context: passiveContext),
           planeBefore == .astra,
           piece.plane == .terra,
           !events.contains(.planeRestored(plane: .astra)) {
            commit(.planeRestored(plane: .astra))
        }

        // A sign that was holding Astra's repair back has just stopped being the
        // sign. See `settleAstraRepair`.
        if let owed = settleAstraRepair() { commit(owed) }

        // An Essence opened by its own element pays a little charge on top.
        // Applied here rather than in the four effects: it is a rule about the
        // *piece*, not about any one coin, and adding a fifth Essence should not
        // mean remembering to write this again.
        //
        // ## Why only the hunt pays it
        //
        // Because this rewards *finding your own element out there* — one of the
        // four Essences turning out to match the sign you are holding. A thing
        // you put on the board yourself is not a find. Pisces' bubbles are water
        // and Pisces is a water sign, so every bubble was quietly paying an
        // affinity bonus on top of its own pip, which is the sign being paid
        // twice for its own charge. Gaia droplets had the same problem.
        //
        // Asked of the class rather than by naming the two: anything scattered
        // or left lying about is not the hunt, and the next one will not need
        // remembering either.
        if effect.pickupClass == .pentacle,
           let element = effect.element, element == piece.zodiac.element {
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

            for closing in sim.closingTheShop() { commit(closing) }

            let effect = PickupCatalog.effect(for: id)
            // A banked coin that still owes a question asks it now, through the
            // ordinary pickup path — buying an Astral Breeze should feel like
            // opening one.
            if effect.choice != .none {
                commit(.choiceRequested(
                    source: .pickup(id),
                    kind: effect.rolledChoice(using: &sim.rng)
                ))
                return events
            }
            events += sim.applyEffect(effect, choice: nil)
            events += sim.ensurePentacleAvailable(previousPlane: planeBefore, after: events)
            return events
        }

        // A shop that closes without a sale ends the loan just the same.
        //
        // This only ran on the purchase, so declining the strip left a borrowed
        // purse sitting on the run for ever: the phantom was already spent, the
        // coins were still there, and the next Cash-in found somebody else's
        // takings waiting for it. The loan ends when the shop closes — whether
        // the player bought anything is not the question.
        if pending.kind == .shop {
            for closing in sim.closingTheShop() { commit(closing) }
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
                for allowed in sim.shelteredEvents(event) { commit(allowed) }
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
                for allowed in sim.shelteredEvents(event) { commit(allowed) }
            }
            if !sim.isGameOver {
                events += sim.settle(arrivedByFalling: false, wearsOnArrival: false).events
            }
        }

        events += sim.ensurePentacleAvailable(previousPlane: planeBefore, after: events)
        return events
    }

    /// Hands back whatever is left of a borrowed purse when the shop shuts.
    ///
    /// Asked of the *piece*, not of the retinue: the phantom is already gone by
    /// this point — a borrowed super is spent before it runs — so "is Capricorn
    /// still following" answers false for a lent purse and a real one alike. It
    /// wiped the goat's own savings after every purchase and left Leo's borrowed
    /// coins lying about, which is both directions of the same wrong question.
    private func closingTheShop() -> [GameEvent] {
        guard !signState.purse.isEmpty, piece.zodiac != .capricorn else { return [] }
        var emptied = signState
        emptied.purse = []
        return [.signStateChanged(emptied)]
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

        // And the Essences, which are the same idea at a smaller size: one pip
        // a step, in whichever direction. Summed here with everything else so a
        // step that earns nothing can still *cost* — the clamp below is what
        // stops a drain going past empty.
        let gain = piece.zodiac.zodiaction.meterGain(from: move, context: passiveContext)
            + activePassives.meterBonus(from: move, context: passiveContext)
            + starCharge
            + signState.essenceCharge
        guard gain != 0 else { return [] }

        let capped = min(max(zodiactionMeter + gain, 0), zodiactionMeterMax)
        guard capped != zodiactionMeter else { return [] }

        var events: [GameEvent] = []

        // **Starstream Surfer, named at the crossing rather than the meter.**
        //
        // The same test `meterBonus` uses for a surf — ending on Astra having
        // covered more than one square — except the surf pays *nothing*, so
        // there is no bonus to attach this to. Told directly instead.
        if piece.zodiac == .pisces, move.endingPlane == .astra,
           move.origin.manhattanDistance(to: move.destination) > 1 {
            let named = GameEvent.passiveFired(
                name: PiscesStarstreamSurfer().displayName, refused: false
            )
            apply(named)
            events.append(named)
        }

        // **Prideful Plant, named before the number that pays it.**
        //
        // Same shape as Six Singe below: checked against exactly the condition
        // `LeoPridefulPlant.meterBonus` used to earn its share of `gain`, so
        // this speaks on the fall that paid out and nothing else.
        if piece.zodiac == .leo, move.fell {
            let named = GameEvent.passiveFired(name: LeoPridefulPlant().displayName, refused: false)
            apply(named)
            events.append(named)
        }

        // **Six Singe, named before the number that pays it.**
        //
        // Checked against the same condition `AriesSixSinge.meterBonus` used to
        // earn its share of `gain` — a streak of six not yet spent this visit —
        // so this only speaks on the move that actually crossed the board, not
        // on every later top-up the meter happens to receive.
        if piece.zodiac == .aries,
           signState.streakLength == GameRules.sixSingeLength,
           !signState.planeFlags.contains(AriesSixSinge.usedThisVisitKey) {
            let named = GameEvent.passiveFired(name: AriesSixSinge().displayName, refused: false)
            apply(named)
            events.append(named)
        }

        let event = GameEvent.zodiactionMeterChanged(to: capped)
        apply(event)
        events.append(event)
        return events
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
    private mutating func ensurePentacleAvailable(
        previousPlane: Plane,
        after played: [GameEvent] = []
    ) -> [GameEvent] {
        guard !isGameOver, pendingChoice == nil else { return [] }

        // Every planner ends here, which makes it the one place guaranteed to
        // notice that the piece has changed plane or changed sign — and the one
        // place holding the whole move, which is what the water has to be
        // checked against.
        // A dormant fragment wakes here for the same reason everything else
        // does: this is the one function every planner ends with, so a rule
        // about the end of a turn belongs here rather than in a list of nine
        // call sites somebody has to remember to keep in step.
        var events: [GameEvent] = chargePolaris(after: played)
        events += evaporateStalePools()
        events += burnOffPools(namedBy: played)

        // A coin whose tile has broken underneath it goes down with it. Area
        // effects and board-wide Zodiactions can open a hole anywhere, the
        // Pentacle's own square included — and a coin left hovering over a hole
        // is not just odd to look at, it is unreachable, since landing there
        // drops the piece straight through.
        //
        // Checked here rather than at each place a tile can break: this is
        // already the one function every planner ends with, and every one of
        // them can break a tile.
        for pickup in revealedPentacles
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
        let stranded = !revealedPentacles.isEmpty
            && revealedPentacles.allSatisfy { $0.plane != piece.plane }
        let nothingAvailable = sparkles == nil && revealedPentacles.isEmpty

        guard changedPlane || stranded || nothingAvailable else { return events }

        let plane = piece.plane
        let board = self[plane]
        let point = piece.point
        let weighting = pickupWeighting()
        let mirrorChance = activePassives.mirroredSparkleChance(context: passiveContext)
        guard let spawn = Self.rollSparkles(
            on: plane,
            board: board,
            piecePoint: point,
            weighting: weighting,
            mirrorChance: mirrorChance,
            stardarPending: signState.stardarPending,
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
        stardarPending: Bool,
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

        // **A Stardar shines on the winner from the moment the phase opens.**
        //
        // Decided here, with the phase, rather than when it resolves — the coin
        // promised you would be able to *see* which sparkle is worth taking,
        // and a promise settled at the last instant is not visible at all. The
        // reveal reads this back and hands the Pentacle to the marked square.
        if stardarPending {
            set.marked = set.points.randomElement(using: &generator)
        }

        return .sparklesSpawned(set: set)
    }

    /// The coin the piece has just crossed, swept up rather than opened.
    ///
    /// ## Which movements sweep
    ///
    /// The ones that `travelsTheGround` — a slide and a charge. This tested for
    /// `.pieceSlid` alone, which was the same answer back when a slide was the
    /// only thing that crossed squares at all; once the charge was split off it
    /// silently stopped sweeping, so the movement that covers the most ground in
    /// the game was the one that picked nothing up off it.
    ///
    /// Airborne styles are deliberately excluded rather than forgotten. A hop
    /// touches only where it lands, and what it lands on is collected by the
    /// landing itself — sweeping it here would open the same coin twice.
    private mutating func gatherIfCrossed(_ event: GameEvent) -> [GameEvent] {
        let crossing: (point: GridPoint, plane: Plane)? = switch event {
        case let .pieceSlid(_, to, plane):
            (to, plane)
        case let .pieceMoved(_, to, _, plane, type, _, _) where type.travelsTheGround:
            (to, plane)
        default:
            nil
        }

        guard let crossing,
              let coin = revealedPickups.first(where: {
                  $0.plane == crossing.plane && $0.point == crossing.point
              })
        else { return [] }

        let to = crossing.point
        let plane = crossing.plane

        // **Some pieces do not pocket what they run through.**
        //
        // Aries charging is a body at speed, and a coin in the way of one is
        // debris rather than treasure — see `AriesReboundingRam`. He is paid in
        // charge instead, which is the point: the ram that just crossed the
        // board on a Zodiaction is already most of the way to the next one, and
        // is not stopping to pick anything up on the way.
        if activePassives.tramplesPickups(context: passiveContext) {
            let broken = GameEvent.pickupDestroyed(id: coin.id, plane: plane, point: to)
            apply(broken)

            let paid = GameEvent.zodiactionMeterChanged(
                to: meter(afterGaining: GameRules.trampleCharge)
            )
            apply(paid)

            // Named at the coin, not at the charge: what a player needs
            // explained is why a Pentacle they ran straight through did not
            // open, and the ZC that came out of it is the reward, not the news.
            let named = GameEvent.passiveFired(name: AriesSearingStride().displayName, refused: false)
            apply(named)

            return [broken, paid, named]
        }

        let gathered = GameEvent.pickupGathered(id: coin.id, plane: plane, point: to)
        apply(gathered)
        return [gathered]
    }

    /// Opens everything the piece swept up on its way, now that it has stopped.
    ///
    /// Each one runs its full effect, so a coin caught mid-slide behaves exactly
    /// as it would have if walked onto — including moving the piece again, which
    /// it could not safely have done while the piece was still travelling.
    /// What taking a coin **on the move it appeared** is worth.
    ///
    /// The Shine-snipe — alternatively the Sparkle-snipe: the sparkle phase
    /// lights five squares, one of them turns out to be the coin, and reaching
    /// it first is a guess worth paying for. A pip to anyone, and the overhead
    /// flourish that says it happened.
    ///
    /// ## Why this is a function rather than a block inside one collector
    ///
    /// Because there are two collectors. A coin you land on is opened where it
    /// stands; a coin you *cross* is carried and opened when the move stops —
    /// and only the first of the two knew this rule. So a snipe made by sliding
    /// over the coin paid nothing and played nothing, which read exactly like
    /// the flourish being broken. A slide is one move, so sniping on one is a
    /// snipe.
    ///
    /// Pentacles only. A scatter is *several* things appearing at once and
    /// taking one leaves the rest — Pisces' spilled bubbles are revealed by the
    /// fall that dropped them, so collecting one on the way past counted as
    /// sniping a coin nobody was hunting.
    ///
    /// **Virgo included.** Steering the reveal onto the square she is heading
    /// for is her way of charging by hand, so the pip is the reward for doing
    /// it rather than a second helping of one she already had.
    private mutating func snipeReward(for pickup: RevealedPickup) -> [GameEvent] {
        guard pickup.revealedOnMove == moveCount,
              PickupCatalog.effect(for: pickup.id).pickupClass == .pentacle
        else { return [] }

        var events: [GameEvent] = []

        // **Everybody, Virgo included.**
        //
        // She was excluded on the theory that Regulated Reboot already pays her
        // for landing on a ring's coin and that two rewards for one step would
        // make her phase worth more than her Zodiaction. That reads the sign
        // backwards: steering the reveal onto the square she is already heading
        // for *is* her way of charging by hand, and taking the pip away removed
        // the point of doing it. It also meant the one sign that can snipe on
        // demand was the one sign that could never see the flourish — which is
        // why this looked broken from the outside for so long.
        let target = meter(afterGaining: GameRules.revealTileCharge)
        if target != zodiactionMeter {
            events.append(.zodiactionMeterChanged(to: target))
        }

        events.append(.caughtOnReveal(plane: pickup.plane, point: pickup.point))
        return events
    }

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

            // Crossed on the move it appeared is still a snipe — see
            // `snipeReward(for:)`. This path never asked, which is why sniping
            // by sliding over a coin paid nothing.
            for reward in snipeReward(for: coin) {
                apply(reward)
                events.append(reward)
            }

            let effect = PickupCatalog.effect(for: coin.id)

            // A coin that needs an answer parks exactly as it would have.
            guard effect.choice == .none || pointless(effect.choice) else {
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
        // Nothing to stage here any more: the coin is drawn at reveal, so the
        // override is held and applied there instead.
        return event
        #else
        return event
        #endif
    }

    /// The piece's opinion on what should turn up in a sparkle set.
    ///
    /// Built as a closure over a *snapshot* of the context rather than reading
    /// the engine as it runs: the roll happens with `&rng` already borrowed, and
    /// touching `self` inside it would be overlapping access to the same value.
    /// Whether asking this question would be asking for nothing.
    ///
    /// "Where would you like to be carried" has no answer worth giving to a
    /// piece that cannot be carried — see `ZodiacPassive.resistsBeingMoved`. It
    /// was still being asked, and the answer was still being thrown away, which
    /// is worse than either refusing or obeying: the player picks a square, the
    /// board dims for it, and then nothing happens.
    ///
    /// Asked of the *question*, not of the coin, so anything that ever asks
    /// where to put the piece is covered by the same sentence.
    private func pointless(_ choice: PickupChoice) -> Bool {
        choice == .tile && activePassives.resistsBeingMoved(context: passiveContext)
    }

    /// What a refused journey leaves behind: ground cover, and the bill.
    ///
    /// She does not simply ignore the coin — she puts down roots where she is
    /// standing and pays a pip for it. That is what makes the refusal a
    /// *decision the board made about her* rather than an immunity: the coin is
    /// still spent and the meter still moves.
    private func plantedInstead() -> [GameEvent] {
        // The balk, first. It is the same statement a wall makes — *you are not
        // going that way* — and the board already knows how to shove for it, so
        // the refusal is felt rather than merely not happening.
        var events: [GameEvent] = [
            .moveBlocked(direction: piece.facing),
            .passiveFired(name: TaurusStubbornStatue().displayName, refused: false),
        ]
        let point = piece.point

        if self[piece.plane][point].cover == nil,
           !self[piece.plane][point].health.isHole {
            events.append(
                .tileCoverChanged(
                    plane: piece.plane,
                    point: point,
                    to: GroundCover.ordinary(at: point, seed: moveCount)
                )
            )
        }

        let paid = max(zodiactionMeter - GameRules.stubbornStatueCost, 0)
        if paid != zodiactionMeter {
            events.append(.zodiactionMeterChanged(to: paid))
        }
        return events
    }

    #if DEBUG
    /// Rolls `count` coins through the **real** draw and tallies what came up.
    ///
    /// The engine's own weighting, so the sample includes everything that
    /// actually shapes a run's luck: the plane filter, the sign's passives, the
    /// lot. A table read off the source is the authored answer; this is the
    /// played one, and the gap between them is the interesting number.
    mutating func debugPickupSample(_ count: Int) -> [(PickupID, Int)] {
        var tally: [PickupID: Int] = [:]

        // **The engine's own generator, through the engine's own draw.**
        //
        // The first version of this made a fresh `SeededRandom` and called
        // `PickupCatalog.rollPickup` — which proved the catalogue's arithmetic
        // and nothing about what a run actually deals. Everything interesting
        // sits between the two: the plane filter, the sign's passives, the
        // star's square, and whatever state `rng` is in by the time a coin is
        // drawn. Sampling anywhere but here is sampling a different game.
        //
        // Away from Polaris' square, since that one is decided before the table
        // is consulted at all.
        let elsewhere = GridPoint(0, 0) == GameRules.polarisPoint
            ? GridPoint(1, 1)
            : GridPoint(0, 0)

        for _ in 0..<count {
            guard let drawn = drawPickup(at: elsewhere, on: piece.plane) else { continue }
            tally[drawn, default: 0] += 1
        }
        return tally.sorted { $0.value > $1.value }.map { ($0.key, $0.value) }
    }
    #endif

    private func pickupWeighting() -> (PickupID, Int) -> Int {
        let context = passiveContext
        let passives = activePassives
        return { id, base in
            // Off the table entirely on the wrong plane — see
            // `PickupEffect.spawnPlane`. Ahead of the passives, so nothing can
            // weight up a coin that cannot exist here.
            let home = PickupCatalog.effect(for: id).spawnPlane
            guard home == nil || home == context.plane else { return 0 }
            return passives.pickupChance(base, for: id, context: context)
        }
    }

    /// The read-only snapshot handed to passive and Zodiaction hooks.
    /// The same snapshot, for anything outside the engine that has to ask a
    /// passive a question — the panel, deciding which buttons to offer.
    var passiveSnapshot: PassiveContext { passiveContext }

    /// The snapshot every passive is asked against.
    ///
    /// Not private: the session asks one question of the passives before the
    /// engine is involved at all — whether the controls are reversed — because
    /// that has to happen at the input boundary rather than inside a move.
    var passiveContext: PassiveContext {
        #if DEBUG
        // Built fresh on every read, and read from seventy-nine places in this
        // file. Whether that matters is a number, not an opinion.
        RenderTally.count("ctx")
        #endif
        return PassiveContext(
            zodiac: piece.zodiac,
            currentBoard: self[piece.plane],
            boardBelow: piece.plane.planeBelow.map { self[$0] },
            plane: piece.plane,
            nexysPlane: nexysPlane,
            piecePoint: piece.point,
            facing: piece.facing,
            moveCount: moveCount,
            zodiactionMeter: zodiactionMeter,
            zodiactionMeterMax: zodiactionMeterMax,
            duringZodiaction: isFiringZodiaction,
            arrivalWasChosen: arrivalWasChosen,
            arrivedOnOpenGround: arrivedOnOpenGround,
            pickupPoints: revealedPickups.filter { $0.plane == piece.plane }.map(\.point),
            pickups: revealedPickups.filter { $0.plane == piece.plane },
            sparkles: sparkles,
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

        case .passiveFired:
            break // Presentation only: the rule has already acted.

        case let .pickupRevealed(id, plane, point, _, asCloud):
            #if DEBUG
            // A staged coin is spent by the reveal that carries it, and only on
            // the engine that really reveals it. See `drawPickup(at:on:)`.
            if debugNextPickup == id { debugNextPickup = nil }
            #endif

            // The sparkle phase ends here: the shimmer goes out as the pickup
            // appears.
            pickupSerial += 1
            revealedPickups.append(
                RevealedPickup(
                    id: id, plane: plane, point: point,
                    serial: pickupSerial,
                    revealedOnMove: moveCount,
                    isCloud: asCloud,
                    fromRing: sparkles?.pattern == .ring
                )
            )
            // A cloud takes no tile with it and ends no phase: the sparkles it
            // was made from are cleared by the one real coin among them.
            guard !asCloud,
                  PickupCatalog.effect(for: id).pickupClass == .pentacle
            else { break }
            // The tile pops up under it, and from here on the two are separate.
            raisedTiles.append(
                RevealedPickup(id: id, plane: plane, point: point, serial: pickupSerial)
            )
            sparkles = nil
            pendingPickup = false

        case let .moveCommitted(direction):
            // The queue the retinue walks. See `rememberStep(_:)`.
            rememberStep(piece.point)

            // The Aten travels with the lion.
            //
            // Kept here rather than in the passive because it is not a decision,
            // it is a fact about where the sun is — and a passive that has to be
            // consulted every move to restate an unchanged rule is a passive
            // waiting to be forgotten on the move somebody adds next.
            if signState.sun != nil, piece.zodiac == .leo {
                signState.sun?.point = piece.point
                signState.sun?.plane = piece.plane
            }

            // A diagonal does not turn you to face diagonally — see
            // `SwipeDirection.facing(from:)`.
            piece.facing = direction.facing(from: piece.facing)
            moveCount += 1

        case let .pieceTurned(direction):
            piece.facing = direction.facing(from: piece.facing)

        case let .pieceSlid(from, to, _):
            // A slide restarts the queue rather than filling it.
            //
            // Not merely because six squares of follow-through outlasts the turn
            // that caused it — because the engine's own rule is that a slide's
            // middle squares are **crossed, not stood on**: no wear, no landing
            // checks, no chance to fall in halfway. A retinue walking them as if
            // they were steps would be the one thing on the board treating those
            // squares as ground.
            //
            // So the line arrives stacked on Leo, exactly as it does through a
            // warp, and sorts itself out on his next step. A slide has far more
            // in common with a warp than with walking.
            advanceTrail(.slide, from: from, to: to)
            piece.point = to


        case let .tilesChanged(plane, changes):
            for (point, health) in changes {
                self[plane][point].health = health
                self[plane][point] = self[plane][point].settled()
            }

        case let .tilesWorn(plane, changes, _), let .tilesWornOnExit(plane, changes, _):
            for (point, health) in changes {
                self[plane][point].health = health
                self[plane][point] = self[plane][point].settled()
            }

        case let .tileDamaged(plane, point, health):
            self[plane][point].health = health
            self[plane][point] = self[plane][point].settled()

        case let .tileHealed(plane, point, health):
            self[plane][point].health = health
            self[plane][point] = self[plane][point].settled()

        case let .tileCoverChanged(plane, point, cover, _):
            guard self[plane].contains(point) else { break }
            // Through `covered(by:)`, so a square that loses its cover draws a
            // fresh straw for the next thing that grows on it.
            self[plane][point] = self[plane][point].covered(by: cover)

        case .groundWaveBegan:
            break

        case let .groundSwept(plane, health, cover):
            for (point, value) in health where self[plane].contains(point) {
                self[plane][point].health = value
                self[plane][point] = self[plane][point].settled()
            }
            for (point, value) in cover where self[plane].contains(point) {
                self[plane][point] = self[plane][point].covered(by: value)
            }

        case let .pieceMoved(_, to, fromPlane, toPlane, type, _, _):
            // A move that crossed the ground leaves the retinue strung out
            // behind it; one that did not arrives with them stacked on top.
            // `advanceTrail` asks the type, so nothing here needs to know which
            // kind of move this was.
            advanceTrail(type, from: piece.point, to: to)
            piece.point = to

            // Arriving anywhere without walking closes every torn doorway, and
            // leaving the plane closes everything.
            //
            // All of them rather than a pair, because a teleport does not go
            // *through* a rift — it is a hole torn somewhere else, and the
            // mirrors do not survive the board being folded around them.
            guard type.mayChangePlane else { break }
            signState.terraRifts = []
            if toPlane != fromPlane {
                // The third way to change plane, and it costs the retinue like
                // the other two. One rule, no exceptions — which is the whole
                // reason the rule is "any change of plane" rather than "a fall".
                refundLostRetinue()
                signState.closeRifts()
                signState = signState.clearedForPlaneChange(atMove: moveCount)
            }
            piece.plane = toPlane

        case .caughtOnReveal:
            // Presentation only; the charge is its own event.
            break

        case .retinueChanged:
            // Presentation only. The swap itself rides on the `signStateChanged`
            // emitted beside it, so the state has one owner.
            break

        case let .shadowSpawned(at, plane, onShadowNexys):
            shadow = Shadow(point: at, plane: plane, onShadowNexys: onShadowNexys)

        case let .shadowStepped(_, to, plane):
            shadow?.point = to
            shadow?.plane = plane
            // Off its island the moment it steps away from it, so the chasm
            // exception cannot be carried around the board.
            if to != GameRules.nexysPoint { shadow?.onShadowNexys = false }

        case let .shadowDestroyed(_, _, caught):
            shadow = nil
            let reward = caught
                ? zodiactionMeterMax
                : Int(Double(zodiactionMeterMax) * GameRules.shadowDriveOffFraction)
            zodiactionMeter = min(zodiactionMeter + reward, zodiactionMeterMax)

        case let .pieceSplit(strandedAt, plane, faller):
            // The half left behind. The faller keeps control, because the fall
            // is what just happened and is where the player is looking.
            piece.twin = faller
            otherHalf = Piece(
                zodiac: piece.zodiac,
                plane: plane,
                point: strandedAt,
                facing: piece.facing,
                twin: faller.sibling
            )

        case .turnPassed:
            guard var waiting = otherHalf else { break }
            let acting = piece
            piece = waiting
            waiting = acting
            otherHalf = waiting

        case .piecesRejoined:
            // One piece again, so neither half is a half any more.
            piece.twin = nil
            otherHalf = nil
            zodiactionMeter = zodiactionMeterMax

        case .halfLost:
            // The survivor takes over, and takes the soul with it.
            guard let survivor = otherHalf else { break }
            piece = survivor
            piece.twin = nil
            otherHalf = nil
            zodiactionMeter = min(
                zodiactionMeter
                    + Int(Double(zodiactionMeterMax) * GameRules.siblingSoulFraction),
                zodiactionMeterMax
            )

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
            let wasBackwards = piece.zodiac.zodiaction.firesAtEmpty
            piece.zodiac = zodiac
            // Only Gemini has twins, so becoming anything else ends being one.
            if zodiac != .gemini { piece.twin = nil }
            zodiactionMeter = min(zodiactionMeter, zodiactionMeterMax)

            // **Crossing into or out of a backwards meter re-reads it.**
            //
            // Charge belongs to the run rather than the piece, so it survives a
            // change — but "eight pips" means nearly ready to one sign and
            // nearly spent to the other, and carrying the *number* across turns
            // a full meter into an empty one. Becoming Aquarius with nothing
            // banked would hand him a Zodiaction ready to fire; leaving him with
            // ten would hand the next sign a full one.
            //
            // So the meter is mirrored when the direction changes, which keeps
            // what the player *earned* rather than what it was written as.
            if zodiac.zodiaction.firesAtEmpty != wasBackwards {
                zodiactionMeter = max(zodiactionMeterMax - zodiactionMeter, 0)
            }

            // Becoming Capricorn turns the charge you were carrying into coins.
            //
            // Capricorn's meter *is* its purse, so arriving with a full one and
            // an empty belt gives a sign whose Zodiaction is "spend a coin" no
            // coin to spend — a full, unusable super, which reads as broken
            // rather than as unlucky. The charge is not lost, it is converted at
            // one Pentacle a pip.
            //
            // The top-up is the part worth explaining. A conversion that lands
            // exactly on a full meter would be the same dead end one step later,
            // so a full purse is seeded with Astral Blossoms and anything short
            // of it with Tears: the first pop always does something, and
            // which something depends on how much was brought across. None of
            // this is player-facing — it is the seam being hidden.
            // Only when *becoming* Capricorn. A summoned one gets nothing: Leo
            // can go and collect Pentacles the moment the phantom appears, so
            // the empty-purse dead end the seeding exists to prevent is not a
            // dead end at all — it is a turn's work.
            if zodiac == .capricorn, signState.purse.isEmpty, zodiactionMeter > 0 {
                let coins = min(zodiactionMeter, zodiactionMeterMax)
                let full = coins >= zodiactionMeterMax

                signState.purse = Array(
                    repeating: full ? .astralBlossom : .restoreTile,
                    count: max(coins, 1)
                )
            }

        case let .choiceRequested(source, kind):
            pendingChoice = (source, kind)

        case .choiceResolved:
            pendingChoice = nil

        case let .signStateChanged(state):
            signState = state

        case let .pieceFell(_, to, at):
            advanceTrail(.teleport, from: at, to: at)
            refundLostRetinue()
            signState = signState.clearedForPlaneChange(atMove: moveCount)
            signState.closeRifts()
            piece.plane = to
            piece.point = at

        case let .planeRestored(plane):
            for point in self[plane].allPoints where self[plane][point].kind == .normal {
                self[plane][point].health = .healthy
                self[plane][point] = self[plane][point].settled()
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
            if revealedPentacles.isEmpty {
                pendingPickup = false
                sparkles = nil
            }

        case let .poolFormed(plane, point):
            self[plane][point] = .pool

        case let .poolEvaporated(plane, point):
            // Back to ordinary ground, whole. The water was standing *on* the
            // square, not eating it, so there is nothing to have worn out.
            self[plane][point] = Tile(kind: .normal, health: .healthy)

        // Presentation only: what the tail caught arrives as its own
        // `pickupGathered`, and a miss changes nothing by definition.
        case .stingStruck:
            break

        // The purse itself moves through `signStateChanged`; these two are
        // announcements, so the strip and the arc of light have something to
        // animate off.
        case .pickupBanked, .pickupSpent:
            break

        case let .pickupCollected(id, plane, point):
            // One to a run, whether or not it is still being carried. See
            // `polarisTaken`.
            if id == .polaris { polarisTaken = true }

            raisedTiles.removeAll { $0.plane == plane && $0.point == point }
            revealedPickups.removeAll { $0.plane == plane && $0.point == point }

            // And out of the pouch.
            //
            // `openCarriedPickups` empties it on the simulation copy, which is
            // thrown away — only events reach the real engine. So a coin swept
            // up by the sting stayed in the pouch forever and was re-opened by
            // every later sweep: pick one Astral Breeze, warp, and be asked to
            // warp again, endlessly. State the events do not carry is state the
            // engine does not have.
            carriedPickups.removeAll { $0.id == id }
            if revealedPentacles.isEmpty {
                pendingPickup = false
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

        case let .sparklesSpawned(set):
            sparkles = set
            pendingPickup = true
            // Only the hunt's own leftovers. A boon is somewhere an ability put
            // it and stays there across any number of hunts — and so is a coin
            // that stands outside the hunt, which is why this asks the same
            // question `revealedPentacles` does rather than its own.
            //
            // This wipe is also the Reboot's whole flavour. Virgo says *I want
            // a Pentacle, near me, now*: whatever phase was in progress ends,
            // wherever its coin was going stops mattering, and eight squares
            // light up around her. What it must not do is sweep away the coin
            // the *last* ring left standing.
            revealedPickups.removeAll {
                !$0.standsOutsideTheHunt
                    && PickupCatalog.effect(for: $0.id).pickupClass == .pentacle
            }
            // A raised square with no coin on it is stampable, not permanent.
            raisedTiles = []

        case let .nexysMoved(destination, carryingPiece):
            nexysPlane = destination
            applyNexysLayout()
            if carryingPiece {
                if piece.plane != destination {
                    // Riding the island is a change of plane like any other, so
                    // it costs the retinue like any other — see
                    // `SignState.clearedForPlaneChange`.
                    refundLostRetinue()
                    signState.closeRifts()
                    signState = signState.clearedForPlaneChange(atMove: moveCount)
                }
                piece.plane = destination
                piece.point = GameRules.nexysPoint

                // Turned to face the player before the island moves, for the
                // same reason a run opens that way: arriving somewhere new
                // showing your back is the one moment the piece has nothing to
                // say for itself.
                piece.facing = .down
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
