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

    let displayName = "Searing Stride"
    let summary = "Astra & Terra: +1 charge for each consecutive move in the same direction after the second."

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

    let displayName = "Six Singe"
    let summary = "Astra & Terra: crossing the board in a straight line tops your meter up to full."

    func meterBonus(from move: MoveSummary, context: PassiveContext) -> Int {
        guard context.signState.streakLength == GameRules.sixSingeLength else { return 0 }
        return GameRules.sixSingeBonus
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
                let scorched = leaving.health.damaged.damaged
                board[from].health = scorched
                events.append(
                    .tilesWornOnExit(plane: context.plane, changes: [from: scorched])
                )
            }

            events.append(
                .pieceStepped(from: from, to: square, plane: context.plane)
            )
            from = square
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
