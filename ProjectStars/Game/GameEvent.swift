//
//  GameEvent.swift
//  Project Stars
//
//  The atomic state changes a move is decomposed into.
//

import SwiftUI
/// What is waiting on the player's answer.
///
/// Pentacles were the only thing that could ask a question, which is why the
/// machinery was named for them. Aquarius' Gone With the Gale picks its own
/// landing square, and Leo's Rallying Roar will offer a change of sign — so the
/// asker is now part of the question.
/// What did the damage, and therefore how much of it and what it looks like.
///
/// ## Why the event carries this
///
/// Wear used to be an anonymous change of state, and anything that needed to
/// look different had to work out *who was playing* to decide — the session
/// asked "is this Aries?" to draw the charge's fire, which was wrong on the day
/// Leo could borrow Aries' charge and wrong the day two things burned.
///
/// A cause is the honest answer: the fire belongs to Brazen Blaze, not to Aries,
/// and both the amount of damage and the effect drawn over it are properties of
/// the *cause*. Anything that can be caused by a phantom, an item or a sign at
/// once should describe itself here rather than be inferred.
enum WearCause: String, Equatable, Hashable, Codable {

    /// A piece arriving or leaving under its own weight. The overwhelming
    /// majority, and the only one that is not an effect.
    case landing

    /// Aries' charge. Burns twice as deep and leaves fire behind it.
    case brazenBlaze

    /// Taurus' hooves.
    ///
    /// One case rather than two, because it is one ability — it simply weighs
    /// differently depending on where the bull is standing, and the cause is the
    /// right place to know that. Astra takes it twice over; Terra takes it once,
    /// and the *first* footfall on a Terra square takes nothing at all, which
    /// the passive decides because only the passive remembers which squares have
    /// already been trodden.
    case hooves

    /// How many stages this takes out of a tile, here.
    func stages(on plane: Plane) -> Int {
        switch self {
        case .landing:
            GameRules.wearPerLanding
        case .brazenBlaze:
            GameRules.wearPerLanding * 2
        case .hooves:
            plane == .astra ? GameRules.wearPerLanding * 2 : GameRules.wearPerLanding
        }
    }

    /// The strip drawn over each square it touches, if any.
    var effect: EffectSprite? {
        switch self {
        case .landing, .hooves: nil
        case .brazenBlaze: .blazeTrail
        }
    }

    /// Smoke thrown up by the cause itself, and what colour it is.
    ///
    /// Green for the free footfall — which is why this asks whether anything
    /// actually changed. A hoof that scuffed a square and a hoof that broke one
    /// are the same cause, and only one of them is news.
    func smokeTint(changedAnything: Bool) -> Color? {
        self == .hooves && !changedAnything ? Palette.green : nil
    }

    /// Whether the board shudders under it.
    func shakes(on plane: Plane) -> Bool {
        self == .hooves && plane == .astra
    }

    /// True when this wants drawing even though it changed nothing.
    ///
    /// The free footfall is the whole reason this exists: "that step cost you
    /// nothing" is information, and before there was a cause to hang it on the
    /// rule was communicated by a tile conspicuously failing to change.
    var isVisibleWithoutChange: Bool { self == .hooves }
}

enum ChoiceSource: Equatable, Hashable {
    case pickup(PickupID)
    case zodiaction(Zodiac)

    /// An always-on ability that offers something on arrival — Aquarius' Corner
    /// Current. Distinct from `zodiaction` because the player did not press
    /// anything to be asked, which is exactly why these offers can be declined.
    case passive(Zodiac)
}


/// One indivisible change to the game state.
///
/// The engine never mutates itself directly in response to input. Instead it
/// *plans* a move into an ordered list of these, and then those same events are
/// applied one at a time. The UI replays the identical list with a delay
/// between each, which is what makes the animation and the simulation
/// impossible to desynchronise: there is only ever one description of what
/// happened.
///
/// Events carry concrete outcomes, never instructions to roll dice. All

/// How a piece got from one square to another without walking.
///
/// The engine knows and the view cannot work it out — the same reason
/// `MovementStyle` rides on `pieceStepped`. A warp and a rise share every field
/// an event has and look nothing alike.
enum TeleportStyle: String, Codable, Hashable, Sendable {

    /// Out here, in there. The default, and what every corner, arrow and Breeze
    /// does.
    case warp

    /// Straight up through the ceiling, surfacing on the plane above. Pisces
    /// swimming Upstream — the only piece in the game that climbs under its own
    /// power.
    case rise
}

/// randomness is resolved during planning.
enum GameEvent: Equatable {

    /// The swipe had no legal destination. Purely a cue for the UI to nudge;
    /// applying it changes nothing.
    case moveBlocked(direction: SwipeDirection)

    /// **The sparkle phase ended and the pickup appeared.**
    ///
    /// One event because the two happen together: the sparkles vanish and the
    /// pickup materialises on one of the tiles they occupied, as the piece
    /// begins its hop and before it lands. Applying this clears the sparkle set.
    /// - Parameter thrownFrom: The square this was flung from, when it did not
    ///   simply appear. Only a spill sets it — a coin surfacing out of the glow
    ///   phase was always there to be found and has nowhere to have come from.
    ///   Without this the view had to guess, and guessed that *every* bubble was
    ///   a spilled one, so the whole board re-threw itself on every step.
    case pickupRevealed(
        id: PickupID,
        plane: Plane,
        point: GridPoint,
        thrownFrom: GridPoint? = nil
    )

    /// The move was committed: it counts toward the move total and turns the
    /// piece to face `direction`.
    ///
    /// Separate from the movement itself because a slide is several squares but
    /// only ever one move, and because facing changes the instant the player
    /// commits — not once per square crossed.
    case moveCommitted(direction: SwipeDirection)

    /// The piece turned on the spot, without moving.
    ///
    /// Separate from `moveCommitted`, which also counts a move and spends a turn.
    /// An effect that sweeps the piece somewhere — Astral Brook rebounding off a
    /// wall — has to leave it facing the way it actually travelled, and this is
    /// how it says so without inventing a move that never happened.
    case pieceTurned(to: SwipeDirection)

    /// The piece entered one square. A jump emits one of these; a charge emits
    /// one per square it crosses.
    ///
    /// `style` is how it got there, and it travels on the event because
    /// everything downstream needs it and nothing downstream can work it out. A
    /// charge's steps and a hop's step are the same case, and the difference —
    /// the pace, whether the sprite arcs, whether the ground gives on arrival,
    /// whether the squares crossed press down — is the entire question the view
    /// layer is asking. Left off, it had to be guessed from whose super was
    /// running, which is a rule about Aries standing in for a rule about
    /// movement.
    case pieceStepped(from: GridPoint, to: GridPoint, plane: Plane, style: MovementStyle)

    /// A tile took wear and is now in state `to`.
    case tileDamaged(plane: Plane, point: GridPoint, to: TileHealth)

    /// Several tiles changed at once, as one beat.
    ///
    /// Area effects — Astral Blaze and Blossom, Taurus' Flowering Flop, Libra's
    /// Balancing Breeze, Gemini's Mirrored Mandate — are a single event rather
    /// than a stream
    /// of `tileDamaged`, because they are *simultaneous*. Emitted one at a time
    /// they read as a slow sweep across the board, which misrepresents what the
    /// rule actually does.
    case tilesChanged(plane: Plane, changes: [GridPoint: TileHealth])

    /// What a landing did to the board, as one event.
    ///
    /// **Batched deliberately, and this is a fairness rule rather than a
    /// cosmetic one.** A move used to cost a beat per tile it damaged, so Libra
    /// — which strikes two flanking tiles instead of one underfoot — and Taurus
    /// on Astra — which takes two stages at once — both moved visibly slower
    /// than everyone else. A sign should not be penalised in tempo for what its
    /// passive does to the floor.
    ///
    /// One landing, one event, one beat. `changes` carries each tile's *final*
    /// state, so several stages of wear resolve together.
    ///
    /// A repair can appear here too: Sagittarius' Variable Voyager mends a tile
    /// rather than breaking it, and that is still something the landing did.
    case tilesWorn(plane: Plane, changes: [GridPoint: TileHealth], cause: WearCause = .landing)

    /// The same, for wear charged to the tile being **left** rather than
    /// entered.
    ///
    /// Separate only so it can be paced differently: exit wear is emitted before
    /// the hop, so holding on it delays the move itself.
    case tilesWornOnExit(
        plane: Plane,
        changes: [GridPoint: TileHealth],
        cause: WearCause = .landing
    )

    /// A tile was repaired and is now in state `to`.
    case tileHealed(plane: Plane, point: GridPoint, to: TileHealth)

    /// The piece dropped through a hole to the plane below, keeping its square.
    case pieceFell(from: Plane, to: Plane, at: GridPoint)

    /// The piece was moved somewhere without travelling there.
    ///
    /// Distinct from `pieceStepped` because nothing between origin and
    /// destination is touched, and because it may cross planes. Arriving is
    /// still landing: the engine settles the destination afterwards, so every
    /// landing check runs exactly as it would after an ordinary move.
    case pieceTeleported(
        from: GridPoint,
        to: GridPoint,
        fromPlane: Plane,
        toPlane: Plane,
        style: TeleportStyle = .warp
    )

    /// The piece became a different sign, keeping its square, plane and facing.
    ///
    /// Zodiaction charge is deliberately *not* reset — see `apply(_:)`.
    case pieceChanged(to: Zodiac)

    /// A Pentacle was taken on the move it appeared. Presentation only — the
    /// charge rides on the `zodiactionMeterChanged` beside it.
    case caughtOnReveal(plane: Plane, point: GridPoint)

    /// One phantom is swapped for another, in place. Presentation only — the
    /// swap itself rides on the `signStateChanged` beside it.
    case retinueChanged(from: Zodiac, to: Zodiac)

    /// Shadow Work opens and the double appears.
    case shadowSpawned(at: GridPoint, plane: Plane, onShadowNexys: Bool)

    /// The double mirrors a move.
    case shadowStepped(from: GridPoint, to: GridPoint, plane: Plane)

    /// The double is gone, and what it paid.
    ///
    /// `caught` is a collision — the player walked into it, or it into them —
    /// which is worth the whole meter. Anything else is having driven it
    /// somewhere fatal, which is worth half.
    case shadowDestroyed(at: GridPoint, plane: Plane, caught: Bool)

    /// Gemini comes apart: one half stays where it is, the other appears at
    /// `strandedAt` on the plane it fell from.
    ///
    /// The piece taking the *next* turn is the one that fell, because a fall is
    /// the thing that just happened and the player should be looking at it.
    ///
    /// `faller` is which twin went down, rolled here rather than decided by the
    /// renderer: it is a coin flip, and a coin flip that is not in the event is
    /// a coin flip that lands differently every time the run is replayed.
    case pieceSplit(strandedAt: GridPoint, plane: Plane, faller: GeminiHalf)

    /// The two halves exchange places. Emitted at the end of every turn while
    /// split, so alternation replays like everything else rather than being a
    /// property of whoever happens to be asking.
    case turnPassed

    /// Both halves are standing on the same square, and are one piece again.
    case piecesRejoined

    /// One half is gone — fallen out of Terra — and its soul has gone into the
    /// other. See Gemini's Sibling Soul.
    case halfLost(at: GridPoint, plane: Plane)

    /// A Pentacle needs an answer from the player before it can resolve.
    ///
    /// Applying this parks the effect; the session collects the answer and asks
    /// the engine to plan the rest.
    case choiceRequested(source: ChoiceSource, kind: PickupChoice)

    /// The sign's memory changed — a streak advanced, a cooldown started or
    /// ticked, a per-visit charge was spent.
    ///
    /// Carries the whole `SignState` rather than a delta. Coarse deliberately:
    /// whole-value replacement cannot drift, and applying it twice means the
    /// same as applying it once.
    case signStateChanged(SignState)

    /// The player answered a parked Pentacle, un-parking it.
    ///
    /// Its own event rather than a direct assignment because `planChoice(_:)`
    /// plans on a private copy — anything it changes that is not an event never
    /// reaches the real engine, and a Pentacle left parked stalls the sparkle
    /// cycle for the rest of the run.
    case choiceResolved

    /// Every ordinary tile on `plane` was returned to healthy.
    ///
    /// Fires when the player descends from Astra, which repairs the plane they
    /// just left — see `GameRules.astraRestoresOnDescent`. The Nexys and its
    /// chasm are untouched.
    case planeRestored(plane: Plane)

    /// The piece landed on the revealed pickup and consumed it. Any events the
    /// pickup produces follow immediately after this one.
    case pickupCollected(id: PickupID, plane: Plane, point: GridPoint)

    /// The Pentacle fell into a hole opened underneath it.
    ///
    /// Distinct from `pickupCollected`: nobody got it. The coin is destroyed and
    /// the hunt restarts, which is why a fresh sparkle set always follows.
    case pickupDestroyed(id: PickupID, plane: Plane, point: GridPoint)

    /// Water settled on a square and became a pool. See `TileKind.pool`.
    case poolFormed(plane: Plane, point: GridPoint)

    /// A pool dried up, leaving the square as ordinary healthy ground.
    ///
    /// Whether a droplet is left behind is the caller's business — burning one
    /// off leaves a pickup, changing plane simply loses it.
    case poolEvaporated(plane: Plane, point: GridPoint)

    /// Scorpio's tail lashed out along a line.
    ///
    /// Presentation only — anything it caught follows as its own
    /// `pickupGathered`. Its own event so the strike has something to draw off,
    /// and so a miss still plays.
    case stingStruck(plane: Plane, from: GridPoint, along: [GridPoint])

    /// Capricorn banked a Pentacle rather than opening it.
    ///
    /// Follows `pickupCollected` and stands in for the effect's own events: the
    /// coin came up and nothing went off. The arc of green light from the tile
    /// to the shop strip is drawn off this.
    case pickupBanked(id: PickupID, plane: Plane, point: GridPoint)

    /// A banked Pentacle was taken back out of the purse and set off.
    ///
    /// Its effect's events follow immediately, exactly as they would have
    /// followed `pickupCollected` had it never been banked.
    case pickupSpent(id: PickupID)

    /// A Pentacle was swept up mid-journey and is riding with the piece.
    ///
    /// Not the same as collecting it. The coin leaves the board here and its
    /// effect does **not** run — that waits until the piece stops. A slide that
    /// stopped dead to open a coin halfway across the board would break the one
    /// thing a slide is: one continuous movement.
    case pickupGathered(id: PickupID, plane: Plane, point: GridPoint)

    /// An arrow was planted in a square, and stays there until spent.
    ///
    /// Its own event rather than a `signStateChanged` because the flight is
    /// worth animating — up off the top of the screen, then down onto the square
    /// it chose — and the replay needs something to hang that on.
    case arrowPlanted(plane: Plane, point: GridPoint)

    /// The arrow is gone: warped to, walked into, or rotted away.
    case arrowCleared

    /// The piece slid one square, without leaving the ground.
    ///
    /// Distinct from `pieceStepped`, which is a *hop*: it squashes, arcs, kicks
    /// up dust on landing and takes a full beat. Water carrying you along does
    /// none of that, and a chain of hops across seven squares reads as a rabbit
    /// rather than a current. Same effect on the board, different motion.
    case pieceSlid(from: GridPoint, to: GridPoint, plane: Plane)

    /// The Pentacle was dragged one square by something — Leo's sun so far.
    ///
    /// Moves the *coin only*. The tile it was sitting on stays raised where it
    /// is; see `tileStamped` for why those are two different things.
    case pickupMoved(id: PickupID, plane: Plane, from: GridPoint, to: GridPoint)

    /// A raised tile was flattened by the piece landing on it.
    ///
    /// Separate from `pickupCollected` because a raised tile outlives its coin:
    /// the Pentacle can be taken, destroyed, or dragged away, and the square it
    /// popped up on stays popped until somebody stands on it. Landing on an
    /// empty raised tile does nothing but flatten it.
    case tileStamped(plane: Plane, point: GridPoint)

    /// A fresh sparkle set appeared, hiding `pickup`. Starts a new sparkle
    /// phase and replaces any previous set.
    /// A sparkle phase begins.
    ///
    /// Carries no `PickupID`. What the coin turns out to be is decided when a
    /// square is chosen, not when the squares light up — see
    /// `GameEngine.rollPickupReveal(destination:)`. Deciding it here tied every
    /// rule about a *square* to the *set* instead, which is how a Pentacle
    /// pinned to one tile ended up being common: "is that tile among the five"
    /// is a much easier condition to meet than "is the coin on that tile".
    case sparklesSpawned(set: SparkleSet)

    /// The Nexys island travelled to another plane, taking its chasm with it.
    ///
    /// - Parameter carryingPiece: True when the piece was standing on the island
    ///   and rode along, which also changes the piece's plane.
    case nexysMoved(to: Plane, carryingPiece: Bool)

    /// The Zodiaction meter changed to an absolute value.
    ///
    /// Absolute rather than a delta so that replaying a plan can never
    /// accumulate a rounding or ordering error in the meter.
    case zodiactionMeterChanged(to: Int)

    /// A Zodiaction was popped. Any events it produces follow immediately after.
    case zodiactionFired(zodiac: Zodiac, plane: Plane)


    /// The run ended.
    case gameOver(reason: GameOverReason)

    // MARK: - Presentation

    /// How long the UI should hold on this event before applying the next one.
    ///
    /// Pure presentation — the engine ignores these entirely, and the game is
    /// move-based, so nothing here gates a rule.
    /// The square a reveal put something on, or `nil` for anything else.
    ///
    /// Used to keep two reveals in the same phase off each other's squares
    /// without the caller having to remember which shapes carry a point.
    var revealedPoint: GridPoint? {
        if case let .pickupRevealed(_, _, point, _) = self { return point }
        return nil
    }

    var displayDuration: TimeInterval {
        switch self {
        case .moveBlocked: 0.18
        case .pickupRevealed: GameRules.pickupRevealDuration
        // Instant: it happens *during* a slide, and a beat here would be the
        // stop the whole arrangement exists to avoid.
        case .pickupGathered: 0
        case .arrowPlanted: GameRules.arrowFlightDuration
        case .arrowCleared: 0.12
        case .pieceSlid: GameRules.slideStepDuration
        case .pickupMoved: GameRules.hopDuration
        case .tileStamped: GameRules.tilePopResponse
        case .moveCommitted: 0
        // Instant. The facing swings on a spring that carries on under whatever
        // follows, so holding the turn open for it only delayed the step the
        // player actually asked for.
        case .pieceTurned: 0
        case .pieceStepped: GameRules.hopDuration
        case .tilesChanged: GameRules.areaEffectDuration
        case .tileDamaged: GameRules.tileDamageDuration
        case .tilesWorn: GameRules.tileDamageHold
        case .tilesWornOnExit: GameRules.tileDamageOnExitDuration
        case .tileHealed: GameRules.tileHealDuration
        case .pieceFell: GameRules.fallDuration
        case .planeRestored: GameRules.planeRestoreDuration
        case .pieceTeleported: GameRules.teleportDuration
        case .pieceChanged: GameRules.pieceChangeDuration
        case .caughtOnReveal: 0
        case .retinueChanged: GameRules.soulSplitDuration
        case .shadowSpawned: GameRules.soulSplitDuration
        case .shadowStepped: GameRules.hopDuration
        case .shadowDestroyed: GameRules.soulRiseDuration
        case .pieceSplit: GameRules.soulSplitDuration
        case .piecesRejoined: GameRules.soulSplitDuration
        case .halfLost: GameRules.soulRiseDuration
        // Instant: the swap is bookkeeping, and the *arrival* of control is
        // already announced by the cursor moving to the other half.
        case .turnPassed: 0
        case .choiceRequested: 0
        case .choiceResolved: 0
        case .signStateChanged: 0
        case .pickupCollected: GameRules.pickupCollectDuration
        case .poolFormed: GameRules.poolFormDuration
        case .poolEvaporated: GameRules.poolFormDuration
        case .stingStruck: GameRules.stingDuration
        case .pickupBanked: GameRules.pickupBankDuration
        // Instant: the purchase is the beat, and it has already been paid for
        // by the time the player picks the coin out of the strip.
        case .pickupSpent: 0
        case .pickupDestroyed: GameRules.pickupCollectDuration
        // Instant. The sparkles animate themselves once they exist, so holding
        // the turn open for a tenth of a second first bought nothing and was
        // pure dead time on the end of every single move — see the note on
        // buffering in `GameSession.submit(_:reach:)`.
        case .sparklesSpawned: 0
        case .nexysMoved: GameRules.nexysShiftDuration
        case .zodiactionMeterChanged: 0
        case .zodiactionFired: GameRules.zodiactionDuration
        case .gameOver: GameRules.gameOverDelay
        }
    }
}

// MARK: - GameOverReason

/// Why a run ended.
enum GameOverReason: String, Codable, Equatable {
    /// Fell through Terra — a hole, or the Nexys chasm, with nothing below it.
    case fellThroughTerra

    var displayText: String {
        switch self {
        case .fellThroughTerra: "You fell through Terra."
        }
    }
}
