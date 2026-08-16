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

    /// Blown rather than walking, for as long as there is a storm.
    ///
    /// A hop is a thing with feet deciding to leave the ground. Aquarius above
    /// zero has no feet on show and no say in it — the funnel moves and he goes
    /// with it, which is a slide. At zero the pot is on the floor and hops like
    /// anyone else.
    func adjustedMovement(base: MovementPattern, context: PassiveContext) -> MovementPattern {
        context.zodiactionMeter > 0 ? base.blown() : base
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

/// How the storm carries him.
///
/// With any storm at all he does not walk — he is **blown**, so a move is a
/// slide rather than a hop, and it trails wind behind it. Spent to nothing, the
/// statue walks like every other sign's.
///
/// It hangs off the meter rather than off a flag because the storm does: the
/// same number that decides how much funnel there is decides whether there is
/// enough of it to carry him. There is no state to keep in step.
extension MovementPattern {

    /// The same options, made into slides.
    func blown() -> MovementPattern {
        MovementPattern(
            name: name,
            options: options.map {
                var blown = $0
                blown.style = .slide
                return blown
            }
        )
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

/// From a corner, the wind carries Aquarius diagonally across the board.
///
/// ## What it is
///
/// Standing on any corner opens a **diagonal slide** — the purple option on the
/// stick, the same extra stop Virgo has — running toward the opposite corner
/// until the board runs out. On Astra it can be used as often as the player can
/// reach a corner. On Terra each corner offers it **once**.
///
/// ## Why it stopped being a warp
///
/// The old version was an offer made *on arrival*, which meant a button on the
/// upper screen — and the upper screen is a display, not a control surface. That
/// alone was enough to retire it, but it was also the least interesting version
/// of the idea: a free teleport with no cost either way, where the empowered
/// plane got a choice between three destinations that never mattered because
/// none of them cost anything.
///
/// A slide costs. It wears the corner it leaves and the square it lands on, and
/// Quirky Caper doubles what Aquarius owes on departure — so on Terra the corners
/// wear out under exactly the sign that keeps using them. That decay *is* the
/// once-per-corner limit made physical, which is why the limit can be generous.
///
/// ## Why the corner and not the edge
///
/// A diagonal from anywhere is Virgo's ability. From a corner there is only one
/// diagonal that goes anywhere at all, so it is a route rather than a choice —
/// the corner stops being the dead end it is for everybody else, and Aquarius is
/// the sign that treats the edges of the board as somewhere to be.
struct AquariusCornerCurrent: ZodiacPassive {

    /// Prefix of the keys this sign owns in `SignState.planeFlags`. One per
    /// corner, so Terra's limit is per corner rather than per visit.
    static let usedKeyPrefix = "aquarius.cornerCurrent."

    static func usedKey(for corner: GridPoint) -> String {
        "\(usedKeyPrefix)\(corner.x),\(corner.y)"
    }

    let displayName = "Corner Current"
    let summary = "Astra: from any corner, ride the diagonal across the board. Terra: once per corner."

    func adjustedMovement(base: MovementPattern, context: PassiveContext) -> MovementPattern {
        guard Self.corners(size: context.currentBoard.size).contains(context.piecePoint) else {
            return base
        }
        guard context.isEmpowered
            || !context.signState.planeFlags.contains(Self.usedKey(for: context.piecePoint))
        else { return base }

        // Sorted by `MovementPattern.init`, so the diagonal lands after the
        // ordinary step and the reach selector offers it second.
        return MovementPattern(
            name: base.name,
            options: base.options + [
                MovementPattern.MoveOption(
                    .diagonal,
                    distance: context.currentBoard.size,
                    style: .slide,
                    reachesWall: true
                )
            ]
        )
    }

    /// Only the diagonal that leads *into* the board.
    ///
    /// Three of the four run straight off the edge, and `pathToWall` returns
    /// nothing for those — so the illegal ones refuse themselves and the reach
    /// selector never offers a stop that goes nowhere.
    func allows(
        _ option: MovementPattern.MoveOption,
        direction: SwipeDirection,
        path: [GridPoint],
        context: PassiveContext
    ) -> Bool {
        guard option.reachesWall else { return true }
        return !path.isEmpty
    }

    /// Terra spends the corner it just used.
    func stateAfterMove(
        option: MovementPattern.MoveOption,
        direction: SwipeDirection,
        context: PassiveContext
    ) -> SignState? {
        guard option.reachesWall, !direction.isCardinal else { return nil }
        guard context.plane == .terra else { return nil }

        // `piecePoint` is where the slide *ended* by the time this is asked, so
        // the corner it started from is recovered from the direction it took.
        let step = direction.unitOffset
        var corner = context.piecePoint
        while context.currentBoard.contains(corner.offset(by: GridOffset(-step.dx, -step.dy))) {
            corner = corner.offset(by: GridOffset(-step.dx, -step.dy))
        }

        var state = context.signState
        state.planeFlags.insert(Self.usedKey(for: corner))
        return state
    }

    /// The four corners of a board this size.
    static func corners(size: Int) -> [GridPoint] {
        let last = size - 1
        return [
            GridPoint(0, 0), GridPoint(last, 0),
            GridPoint(0, last), GridPoint(last, last),
        ]
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
