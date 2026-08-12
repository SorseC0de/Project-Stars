//
//  Aquarius.swift
//  Project Stars
//
//  ♒ Aquarius — The Water-Bearer
//
//  Everything specific to this sign lives in this file. Aquarius is an air
//  sign, so it is stronger on **Astra** and weaker on **Terra**.
//

import SwiftUI

// MARK: - Definition

extension ZodiacCatalog {

    /// ♒ Aquarius — The Water-Bearer. Air, Jan 20 – Feb 18. Strong on Astra.
    static let aquarius = ZodiacDefinition(
        sign: .aquarius,
        displayName: "Aquarius",
        glyph: "♒",
        element: .air,
        accentColor: Color(hex: 0x5F_C2_A8),
        movement: .cardinalStep,
        passives: [
            AquariusQuirkyCaper(),
            AquariusWindWalker(),
            AquariusCornerCurrent(),
        ],
        zodiaction: AquariusGoneWithTheGale(),
        constellation: ZodiacCatalog.aquariusConstellation
    )

    /// ♒ Aquarius: the water-bearer's jar, and the stream falling from it.
    static let aquariusConstellation = Constellation(
        stars: [
            Constellation.Star(-1.00,  0.85,  0.15, 0.9),
            Constellation.Star(-0.35,  0.95,  0.00, 1.0),
            Constellation.Star( 0.20,  0.55, -0.15, 0.9),
            Constellation.Star( 0.80,  0.75, -0.25, 0.8),
            Constellation.Star( 0.05, -0.10,  0.10, 0.8),
            Constellation.Star(-0.45, -0.55,  0.25, 0.7),
            Constellation.Star( 0.35, -0.75, -0.10, 0.7),
            Constellation.Star(-0.10, -1.05,  0.00, 0.9),
        ],
        lines: [(0, 1), (1, 2), (2, 3), (2, 4), (4, 5), (4, 6), (5, 7), (6, 7)]
    )
}

// MARK: - Passive 1: Quirky Caper

/// Aquarius never lands hard enough to matter — the damage goes to the tile it
/// pushes off from.
///
/// The consequence worth understanding: arriving somewhere costs nothing, so a
/// wrecked board is far safer to cross than it is for anyone else, but the square
/// you are standing on is always the one about to break. Aquarius cannot loiter.
struct AquariusQuirkyCaper: ZodiacPassive {

    let displayName = "Quirky Caper"
    let summary = "Astra & Terra: damage the tile you leave, never the one you land on."

    func wearTiming(context: PassiveContext) -> WearTiming {
        .onExit
    }

    /// And a fall costs the ground nothing either.
    ///
    /// Quirky Caper charges every landing to the square being *left*, but a
    /// fall has no square being left — the piece arrives from the plane above,
    /// having paid up there. Without this Aquarius was the one sign that damaged
    /// on arrival, which is precisely what the passive says it never does.
    func modifyWear(_ proposal: WearProposal, context: PassiveContext) -> WearProposal {
        guard proposal.arrivedByFalling else { return proposal }
        var weightless = proposal
        weightless.stages = 0
        return weightless
    }
}

// MARK: - Passive 2: Wind Walker

/// A long move is made on the wind.
///
/// A slide settles on each square it crosses and can break through halfway; a
/// jump touches only the destination. So Weightless is what makes Aquarius'
/// longer moves safe to make across broken ground — it flies over the gaps
/// instead of testing each one.
///
/// Inert while Aquarius' movement is the shared single step, since a one-tile
/// move has nothing to cross.
struct AquariusWindWalker: ZodiacPassive {

    let displayName = "Wind Walker"
    let summary = "Astra & Terra: a move of more than one square is made on the wind — holes are crossed rather than fallen into."

    func walksOnAir(during option: MovementPattern.MoveOption, context: PassiveContext) -> Bool {
        option.distance > 1
    }
}

// MARK: - Passive 3: Corner Current

/// Once per plane visit, landing on a corner offers a flight to another one —
/// the diagonal opposite on Terra, any corner at all on Astra.
///
/// ## Why it is an offer rather than a rule
///
/// Corners are where a board dies. They are reached from two directions instead
/// of four, so their traffic concentrates, and a sign that has to leave a corner
/// the way it came in wears the same two squares to nothing. This is the escape
/// hatch — but it is only an escape if it can be refused, because sometimes the
/// corner is exactly where you meant to be.
///
/// That is the whole reason `PickupChoice.among` exists: an offer the player can
/// walk away from. Everything else the game asks must be answered.
///
/// ## Why Astra gets all three
///
/// The empowered plane gets the choice; Terra gets the reflex. One diagonal
/// flight is still an escape, but it is a *fixed* one, so on the plane where
/// Aquarius is weak the ability plays itself rather than being played.
struct AquariusCornerCurrent: ZodiacPassive {

    /// Key this sign owns in `SignState.planeFlags`.
    static let usedThisVisitKey = "aquarius.cornerCurrent"

    let displayName = "Corner Current"
    let summary = "Astra: landing on a corner offers a flight to any other corner. Terra: to the opposite corner only. Once per visit to a plane."

    func offersChoice(context: PassiveContext) -> PickupChoice? {
        guard !context.signState.planeFlags.contains(Self.usedThisVisitKey) else { return nil }

        let corners = Self.corners(size: context.currentBoard.size)
        guard corners.contains(context.piecePoint) else { return nil }

        let destinations = Self.destinations(from: context.piecePoint, context: context)
        guard !destinations.isEmpty else { return nil }
        return .among(destinations)
    }

    func resolveChoice(
        _ choice: PickupChoiceResult,
        context: PassiveContext
    ) -> [GameEvent] {
        // Declining costs nothing — not the flight, and not the use. The player
        // stayed in the corner on purpose, and charging them for the offer would
        // make landing on a corner a thing to avoid.
        guard case let .tile(destination) = choice else { return [] }
        guard Self.destinations(from: context.piecePoint, context: context)
            .contains(destination) else { return [] }

        var state = context.signState
        state.planeFlags.insert(Self.usedThisVisitKey)

        return [
            .signStateChanged(state),
            .pieceTeleported(
                from: context.piecePoint,
                to: destination,
                fromPlane: context.plane,
                toPlane: context.plane
            ),
        ]
    }

    /// The four corners of a board this size.
    static func corners(size: Int) -> [GridPoint] {
        let last = size - 1
        return [
            GridPoint(0, 0), GridPoint(last, 0),
            GridPoint(0, last), GridPoint(last, last),
        ]
    }

    /// Where this corner may fly to, on this plane.
    ///
    /// Filtered to squares the piece can actually stand on. A current that
    /// offered a hole would be a disguised suicide, and this ability is an
    /// escape — the same reasoning behind Gone With the Gale's candidate set.
    private static func destinations(
        from corner: GridPoint,
        context: PassiveContext
    ) -> [GridPoint] {
        let board = context.currentBoard
        let last = board.size - 1
        let opposite = GridPoint(last - corner.x, last - corner.y)

        let candidates = context.isEmpowered
            ? corners(size: board.size).filter { $0 != corner }
            : [opposite]

        return candidates.filter { board[$0].isSolid }
    }
}

// MARK: - Zodiaction: Gone With the Gale

/// Scatters Aquarius to a random square it can stand on, anywhere on the plane —
/// the Nexys included.
///
/// Only solid squares are candidates, so this can never be a disguised suicide.
/// It is an escape, not a gamble: the value is getting *out* of a corner of the
/// board that has decayed past use.
struct AquariusGoneWithTheGale: Zodiaction {

    let displayName = "Gone With the Gale"
    let summary = "Astra & Terra: go to any square you choose — open ground included — and walk on air for \(GameRules.galeMoves) moves after."

    /// - TODO: Aquarius has no charge rule specified. It currently fills only
    ///   from Pentacles.
    func meterGain(from move: MoveSummary, context: PassiveContext) -> Int { 0 }

    /// Suspends on a tile the player picks — the same question Astral Breeze
    /// asks, now asked by a sign.
    func activate(context: PassiveContext, generator: inout SeededRandom) -> [GameEvent] {
        [.choiceRequested(source: .zodiaction(.aquarius), kind: .tile)]
    }

    func resolve(
        choice: PickupChoiceResult,
        context: PassiveContext,
        generator: inout SeededRandom
    ) -> [GameEvent] {
        guard case let .tile(destination) = choice else { return [] }

        // The gale is granted *before* the piece arrives, which is the whole
        // reason a hole is a legal destination: by the time the landing is
        // resolved, there is already nothing that can drop it.
        var state = context.signState
        state.galeMoves = GameRules.galeMoves

        return [
            .signStateChanged(state),
            .pieceTeleported(
                from: context.piecePoint,
                to: destination,
                fromPlane: context.plane,
                toPlane: context.plane
            ),
        ]
    }
}
