//
//  GameEvent.swift
//  Project Stars
//
//  The atomic state changes a move is decomposed into.
//

import Foundation

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
    case pickupRevealed(id: PickupID, plane: Plane, point: GridPoint)

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

    /// The piece entered one square. A jump emits one of these; a slide emits
    /// one per square it crosses.
    case pieceStepped(from: GridPoint, to: GridPoint, plane: Plane)

    /// A tile took wear and is now in state `to`.
    case tileDamaged(plane: Plane, point: GridPoint, to: TileHealth)

    /// Several tiles changed at once, as one beat.
    ///
    /// Area effects — Astral Blaze and Blossom, Taurus' Heavy Flop, Libra's
    /// Rebalance, Gemini's Reflection — are a single event rather than a stream
    /// of `tileDamaged`, because they are *simultaneous*. Emitted one at a time
    /// they read as a slow sweep across the board, which misrepresents what the
    /// rule actually does.
    case tilesChanged(plane: Plane, changes: [GridPoint: TileHealth])

    /// A tile took wear from the piece **leaving** it, and is now in state `to`.
    ///
    /// Identical to `tileDamaged` in every way that matters to the rules — the
    /// engine applies both the same. It exists purely so the replay can pace it
    /// differently: exit wear is emitted before the hop, so holding on it delays
    /// the move itself.
    case tileWornOnExit(plane: Plane, point: GridPoint, to: TileHealth)

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
    case pieceTeleported(from: GridPoint, to: GridPoint, fromPlane: Plane, toPlane: Plane)

    /// The piece became a different sign, keeping its square, plane and facing.
    ///
    /// Zodiaction charge is deliberately *not* reset — see `apply(_:)`.
    case pieceChanged(to: Zodiac)

    /// A Pentacle needs an answer from the player before it can resolve.
    ///
    /// Applying this parks the effect; the session collects the answer and asks
    /// the engine to plan the rest.
    case choiceRequested(id: PickupID, kind: PickupChoice)

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

    /// A fresh sparkle set appeared, hiding `pickup`. Starts a new sparkle
    /// phase and replaces any previous set.
    case sparklesSpawned(set: SparkleSet, pickup: PickupID)

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

    /// Points were added to the score.
    case scoreAwarded(Int)

    /// The run ended.
    case gameOver(reason: GameOverReason)

    // MARK: - Presentation

    /// How long the UI should hold on this event before applying the next one.
    ///
    /// Pure presentation — the engine ignores these entirely, and the game is
    /// move-based, so nothing here gates a rule.
    var displayDuration: TimeInterval {
        switch self {
        case .moveBlocked: 0.18
        case .pickupRevealed: GameRules.pickupRevealDuration
        case .moveCommitted: 0
        case .pieceTurned: 0.06
        case .pieceStepped: GameRules.hopDuration
        case .tilesChanged: GameRules.areaEffectDuration
        case .tileDamaged: GameRules.tileDamageDuration
        case .tileWornOnExit: GameRules.tileDamageOnExitDuration
        case .tileHealed: GameRules.tileHealDuration
        case .pieceFell: GameRules.fallDuration
        case .planeRestored: GameRules.planeRestoreDuration
        case .pieceTeleported: GameRules.teleportDuration
        case .pieceChanged: GameRules.pieceChangeDuration
        case .choiceRequested: 0
        case .choiceResolved: 0
        case .signStateChanged: 0
        case .pickupCollected: GameRules.pickupCollectDuration
        case .pickupDestroyed: GameRules.pickupCollectDuration
        case .sparklesSpawned: 0.10
        case .nexysMoved: GameRules.nexysShiftDuration
        case .zodiactionMeterChanged: 0
        case .zodiactionFired: GameRules.zodiactionDuration
        case .scoreAwarded: 0
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
