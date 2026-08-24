//
//  Aries.swift
//  Project Stars
//
//  ♈ Aries — The Ram
//
//  Everything specific to this sign lives in this file. Aries is a fire
//  sign, so it is stronger on **Terra** and weaker on **Astra**.
//

import SwiftUI

// MARK: - Definition

extension ZodiacCatalog {

    /// ♈ Aries — The Ram. Fire, Mar 21 – Apr 19. Strong on Terra.
    static let aries = ZodiacDefinition(
        sign: .aries,
        displayName: "Aries",
        glyph: "♈",
        element: .fire,
        accentColor: Color(hex: 0xE0_53_3F),
        movement: .cardinalStep,
        passives: [
            AriesSearingStride(),
            AriesSixSinge(),
            AriesReboundingRam(),
        ],
        zodiaction: AriesBrazenBlaze(),
        constellation: ZodiacCatalog.ariesConstellation
    )

    /// ♈ Aries: the short hooked line of Hamal, Sheratan and Mesarthim.
    static let ariesConstellation = Constellation(
        stars: [
            Constellation.Star(-1.05, -0.45, -0.30, 0.7),
            Constellation.Star(-0.25, -0.10,  0.10, 0.9),
            Constellation.Star( 0.55,  0.35,  0.25, 1.4),
            Constellation.Star( 1.05,  0.70, -0.15, 1.0),
        ],
        lines: [(0, 1), (1, 2), (2, 3)]
    )
}

// MARK: - Passive: Searing Stride

/// One pip of charge for every move that continues a straight line, from the
/// third onward.
///
/// Reads the streak the engine already keeps in `SignState`, so it costs nothing
/// to maintain and resets the instant the player turns — which is the whole
/// tension of it, since a board decays fastest along the line you keep running.
///
/// ## Why the third and not the second
///
/// Paying from the second move meant a single repeat was already a straight
/// line, and two moves is not a commitment — you can change your mind every
/// other turn and still be charging the whole time. Requiring three makes the
/// player hold a direction long enough for the tile decay to catch up with
/// them, which is the cost the charge is supposed to be paid for.
struct AriesSearingStride: ZodiacPassive {

    /// How long the streak must run before it pays.
    ///
    /// Counts the move being priced, so `3` is "two repeats after the first".
    static let requiredStreak = 3

    /// The visit's one free tile, spent on the first move made on a plane.
    static let freshTileKey = "aries.freshTile"

    let displayName = "Searing Stride"
    let icon: String? = "aries_stride"
    let summary = "Astra & Terra: +1 ZC for each consecutive move in the same direction after the second. The first tile you touch on a plane takes no damage, and Pentacles you charge through break for +2 ZC."

    /// **A coin in the way of a charging ram is debris.**
    ///
    /// Anything that moves him across the ground — his own Blaze, the Brook,
    /// a current — breaks what it crosses rather than pocketing it, and pays
    /// two charge for the wreckage. That is a genuine trade rather than a
    /// straight loss: he gives up an unknown coin and gets a known step toward
    /// the next Zodiaction, which for the sign with the easiest meter in the
    /// game is the thing he was going to do with it anyway.
    ///
    /// It also spares him the specific indignity of an automatic movement
    /// firing the instant he has finished automatically moving across the whole
    /// board.
    ///
    /// Filed with the Stride rather than with the Ram because it is a rule
    /// about **travelling**, and the Ram is a rule about stopping.
    func tramplesPickups(context: PassiveContext) -> Bool { true }


    /// **The first tile of a visit is free.**
    ///
    /// Aries commits to a direction harder than anyone — both his passives pay
    /// for an unbroken line and his Zodiaction ends only at a wall or a hole —
    /// and the board he is committing across is usually one he wrecked himself.
    /// One tile of grace per plane is the smallest possible cushion for that,
    /// and it lands where it is most useful: the move you make before you know
    /// what the plane looks like.
    ///
    /// **Not falls.** Arriving from the plane above is not a step, and a sign
    /// that spares the ground he walks on has not agreed to spare the ground he
    /// lands on — see `afterFalling`. It is also why the flag can be spent on
    /// the first *move*: a fall neither uses it nor wastes it, so dropping onto
    /// Terra still leaves the grace intact for the step that follows.
    func causesWear(
        on tile: Tile,
        at point: GridPoint,
        plane: Plane,
        afterFalling: Bool,
        context: PassiveContext
    ) -> Bool {
        guard !afterFalling else { return true }
        return context.signState.planeFlags.contains(Self.freshTileKey)
    }

    /// Spends the visit's free tile on the first move made here.
    func stateAfterMove(
        option: MovementPattern.MoveOption,
        direction: SwipeDirection,
        context: PassiveContext
    ) -> SignState? {
        guard !context.signState.planeFlags.contains(Self.freshTileKey) else { return nil }
        var state = context.signState
        state.planeFlags.insert(Self.freshTileKey)
        return state
    }

    func meterBonus(from move: MoveSummary, context: PassiveContext) -> Int {
        // The charge itself pays nothing. Brazen Blaze crosses several squares
        // in one direction in a single turn, and counting that as a streak would
        // have the ability funding its own repeat.
        guard context.signState.streakDirection != nil else { return 0 }

        // `signState` is updated before charging, so the streak already counts
        // the move being priced. Length 1 is a fresh direction and pays nothing.
        return context.signState.streakLength >= Self.requiredStreak ? 1 : 0
    }
}

// MARK: - Passive: Rebounding Ram

/// Bouncing off a wall turns the ram around.
///
/// **Tied to the bonk, not to standing near a wall.** It fires when a move is
/// actually attempted and refused — the balk animation every sign plays and no
/// sign has ever done anything with. So it triggers off whatever tried to move
/// him: the player's own swipe, a current, the Brook, the end of his own
/// charge. Standing beside the edge does nothing at all, because nothing has
/// happened yet.
///
/// ## Why turning is the reward
///
/// Both of Aries' other passives pay for an unbroken line, and running out of
/// board is how every line ends. Without this, the turn costs him a move *and*
/// resets the streak he was building — the sign that commits hardest to a
/// direction is punished worst for reaching the end of one. Now the wall sends
/// him back down the lane already facing the right way.
///
/// The ram hits the thing, and the thing hits back. That is the entire animal.
struct AriesReboundingRam: ZodiacPassive {

    let displayName = "Rebounding Ram"
    let icon: String? = "aries_rebounding"
    let summary = "Astra & Terra: bouncing off a wall turns you to face back the way you came."

    /// Answers the balk. See `GameEngine.plan(_:reach:)`, which hands a refused
    /// move to the passives exactly as it hands them a completed one.
    func amend(_ events: [GameEvent], context: PassiveContext) -> [GameEvent] {
        for event in events {
            if case let .moveBlocked(direction) = event {
                return [
                    .pieceTurned(to: direction.opposite),
                    .passiveFired(name: displayName, refused: false),
                ]
            }
        }
        return []
    }
}

// MARK: - Passive: Six Singe

/// Crossing the whole board in one direction fills the meter.
///
/// Six moves is edge to edge on a seven-wide board, so this cannot be done twice
/// without turning — and turning is the one thing Searing Stride already
/// punishes. It is the same idea taken to its end: the ram commits, and the
/// reward for committing completely is everything.
///
/// ## Why the bonus is a fixed number
///
/// It pays six, which alongside Searing Stride's four fills the meter under
/// ordinary conditions. It is deliberately *not* "however much is missing":
/// computed that way it would erase anything that had just drained the meter —
/// open a Pentacle that zeroes your charge, then walk a straight line, and the
/// loss never happened. The promise is a full meter for crossing the board, not
/// a full meter whatever else occurred.
struct AriesSixSinge: ZodiacPassive {

    /// Key this sign owns in `SignState.planeFlags`.
    static let usedThisVisitKey = "aries.sixSinge"

    let icon: String? = "aries_singe"
    let displayName = "Six Singe"
    let summary = "Astra & Terra: crossing the board in a straight line tops your meter up to full. Once per visit to a plane."

    /// ## Why it is capped per visit
    ///
    /// A seven-wide board means crossing it costs six moves — but the edges are
    /// a loop, and walking the rim pays out again every time a side is finished.
    /// The ram was arriving at four supers a minute by playing ring-a-roses
    /// around the border, which is the *opposite* of the commitment this is
    /// meant to reward: it is the one route where a straight line never has to
    /// take you anywhere new.
    ///
    /// A plane visit is the right window because leaving is already expensive.
    func meterBonus(from move: MoveSummary, context: PassiveContext) -> Int {
        guard context.signState.streakLength == GameRules.sixSingeLength else { return 0 }
        guard !context.signState.planeFlags.contains(Self.usedThisVisitKey) else { return 0 }
        return GameRules.sixSingeBonus
    }

    /// Spends the visit's one payout.
    func stateAfterMove(
        option: MovementPattern.MoveOption,
        direction: SwipeDirection,
        context: PassiveContext
    ) -> SignState? {
        guard context.signState.streakLength == GameRules.sixSingeLength else { return nil }
        guard !context.signState.planeFlags.contains(Self.usedThisVisitKey) else { return nil }

        var state = context.signState
        state.planeFlags.insert(Self.usedThisVisitKey)
        return state
    }
}

// MARK: - Zodiaction: Brazen Blaze

/// The ram puts its head down and runs, burning every square it leaves.
///
/// It charges along its facing until the board runs out or a hole opens in front
/// of it, and every tile it pushes off takes **two** stages of wear instead of
/// one. One turn, however far it goes.
///
/// ## Why it is a move and not a buff
///
/// Brazen Blaze used to be five turns of deferred, doubled damage. That read as
/// a debuff you had inflicted on yourself: nothing visibly happened when it
/// fired, and for the next five moves the player was playing more carefully than
/// usual to manage it. A super should be the moment you were saving up for, and
/// for a fire sign that moment is obviously a charge.
///
/// ## Why it stops at holes rather than clearing them
///
/// Because the run ends when you fall, and nothing that fires on a button press
/// should be able to end it. Stopping short is also the more interesting rule:
/// the ram cannot cross broken ground, so the length of a charge is decided by
/// how wrecked the board already is — and Aries is the sign that wrecks it.
///
/// ## Why each square is checked on its own
///
/// A slide wears its two ends and crosses everything between them untouched —
/// see `GameRules.slideWearsEndsOnly`. That is the wrong shape entirely for
/// this: the whole point is the scorched line. So the charge is a run of
/// individual steps, each paying for the square it leaves, bundled into a single
/// turn.
struct AriesBrazenBlaze: Zodiaction {

    let displayName = "Brazen Blaze"
    let summary = "Astra & Terra: charge along your facing until a wall or a hole stops you, burning every tile you leave for double damage."

    /// All of Aries' charge comes from Searing Stride, so the Zodiaction itself
    /// adds nothing. There is deliberately no universal charge rule.
    func meterGain(from move: MoveSummary, context: PassiveContext) -> Int { 0 }

    /// Nowhere to run is not a Zodiaction that can fire. Refused rather than
    /// spent, so facing a wall costs nothing.
    func canActivate(context: PassiveContext) -> Bool {
        !Self.run(context: context).isEmpty
    }

    func activate(context: PassiveContext, generator: inout SeededRandom) -> [GameEvent] {
        let path = Self.run(context: context)
        guard !path.isEmpty else { return [] }

        var events: [GameEvent] = []
        var from = context.piecePoint
        var board = context.currentBoard

        for square in path {
            // The square being *left* burns, which is the whole shape of this
            // ability — the ram is already gone by the time the ground gives.
            let leaving = board[from]
            if leaving.canBeWorn {
                // The cause carries both the depth and the fire — see
                // `WearCause`. Writing "two stages" here and drawing the flame
                // somewhere else is how the trail ended up keyed to the sign
                // rather than to the charge.
                var scorched = leaving.health
                for _ in 0..<WearCause.brazenBlaze.stages(on: context.plane)
                where scorched != .hole {
                    scorched = scorched.damaged
                }

                board[from].health = scorched
                events.append(
                    .tilesWornOnExit(
                        plane: context.plane,
                        changes: [from: scorched],
                        cause: .brazenBlaze
                    )
                )
            }

            events.append(
                .pieceMoved(
                    from: from, to: square,
                    fromPlane: context.plane, toPlane: context.plane,
                    type: .charge
                )
            )
            from = square
        }

        // The charge ends by running out of board, which is a collision.
        //
        // A ram that sprints the length of the plane and comes to a polite halt
        // is a ram that did not arrive anywhere. The balk is the same one an
        // ordinary step into a wall plays, for the same reason: something
        // stopped you, and the stopping is the event.
        if !events.isEmpty {
            events.append(.moveBlocked(direction: context.facing))
        }

        return events
    }

    /// The squares the charge will cross, in order.
    ///
    /// Stops *before* a hole rather than on it, and before the edge. Computed
    /// against the board as it stands: nothing the charge does to a tile it has
    /// already left can open a hole in front of it, since a straight line never
    /// crosses the same square twice.
    private static func run(context: PassiveContext) -> [GridPoint] {
        let step = context.facing.unitOffset
        var path: [GridPoint] = []
        var point = context.piecePoint.offset(by: step)

        while context.currentBoard.contains(point),
              context.currentBoard[point].isSolid {
            path.append(point)
            point = point.offset(by: step)
        }
        return path
    }
}
