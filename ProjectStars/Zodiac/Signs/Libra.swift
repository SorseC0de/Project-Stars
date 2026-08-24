//
//  Libra.swift
//  Project Stars
//
//  ♎ Libra — The Scales
//
//  Everything specific to this sign lives in this file. Libra is an air
//  sign, so it is stronger on **Astra** and weaker on **Terra**.
//

import SwiftUI

// MARK: - Definition

extension ZodiacCatalog {

    /// ♎ Libra — The Scales. Air, Sep 23 – Oct 22. Strong on Astra.
    static let libra = ZodiacDefinition(
        sign: .libra,
        displayName: "Libra",
        glyph: "♎",
        element: .air,
        accentColor: Color(hex: 0xC9_A6_E0),
        movement: .cardinalStep,
        passives: [
            LibraEquitableImpact(),
            LibraAxialAdjudication(),
            LibraJudicatorElevator(),
        ],
        zodiaction: LibraBalancingBreeze(),
        constellation: ZodiacCatalog.libraConstellation
    )

    /// ♎ Libra: the beam and its two pans.
    static let libraConstellation = Constellation(
        stars: [
            Constellation.Star(-0.95,  0.35,  0.20, 1.2),
            Constellation.Star( 0.00,  0.85,  0.00, 1.0),
            Constellation.Star( 0.95,  0.30, -0.20, 1.2),
            Constellation.Star(-0.75, -0.65,  0.25, 0.8),
            Constellation.Star( 0.80, -0.70, -0.25, 0.8),
        ],
        lines: [(0, 1), (1, 2), (0, 3), (2, 4), (0, 2)]
    )
}

// MARK: - Passive 1: Equitable Impact

/// Libra never damages what it lands on. The force goes sideways instead, into
/// the two squares flanking its facing.
///
/// The square underfoot is always spared, so Libra can stand anywhere
/// indefinitely; what it cannot do is move without breaking ground either side
/// of it. Running a straight line down the middle of the board carves two
/// parallel trenches, which is a very different kind of damage from everyone
/// else's single trail.
///
/// Flanks off the edge of the board simply do not exist — moving along a border
/// wears only the inward side, making the rim the safest place for Libra to
/// travel.
struct LibraEquitableImpact: ZodiacPassive {

    let icon: String? = "libra_impact"
    let displayName = "Equitable Impact"
    let summary = "Astra & Terra: damage the two tiles flanking your facing instead of the one you land on."

    /// Spare the landing square outright.
    func modifyWear(_ proposal: WearProposal, context: PassiveContext) -> WearProposal {
        var balanced = proposal
        balanced.stages = 0
        return balanced
    }

    /// …and put the force into the flanks instead.
    func additionalWear(from proposal: WearProposal, context: PassiveContext) -> [GridPoint] {
        // Not on a fall. The trenches are what the scales do to ground they are
        // *carried across*; dropping out of the sky is not a stride, and putting
        // three holes in Terra on arrival made every descent a disaster the sign
        // could not answer for.
        guard !proposal.arrivedByFalling else { return [] }

        return context.facing.perpendicular.map { proposal.point.offset(by: $0.unitOffset) }
    }

    /// And the dust with it.
    ///
    /// Nothing under the body: she comes down on the pans, and a puff between
    /// them says the wrong thing about what just broke. Two smaller clouds
    /// instead, one on each square the scales trench — the same two squares
    /// `additionalWear` names, worked out the same way so they cannot drift.
    func landingDust(at point: GridPoint, context: PassiveContext) -> [LandingDust]? {
        context.facing.perpendicular.map {
            LandingDust(
                point: point.offset(by: $0.unitOffset),
                magnitude: GameRules.libraPanDustMagnitude
            )
        }
    }
}

// MARK: - Passive 2: Axial Adjudication

/// Any line at one uniform wear is fully restored — rows and columns, on both
/// planes.
///
/// ## Why it is not one axis per plane
///
/// It was, and before that it alternated. Alternating is a rule about *history*,
/// which is the one thing a board cannot show you. Fixing an axis to each plane
/// fixed that but cost something worse: half of every board became scenery, and
/// the player carried "which grain am I on" around while doing the real work of
/// levelling seven squares.
///
/// Both axes everywhere is one rule rather than two, it reads off the board
/// without being remembered, and it makes the good move possible — a pair of
/// trenches that finishes a row and a column in the same breath.
///
/// A structural square in the line is a **gap**, not a disqualification: the
/// Nexys has no wear state to match, and treating that as "this line can never
/// level" exempted a seventh of the board from the ability on whichever plane
/// the island was sitting on.
struct LibraAxialAdjudication: ZodiacPassive {

    let displayName = "Axial Adjudication"
    let icon: String? = "libra_axial"
    let summary = "Astra & Terra: any row or column at one uniform wear is fully restored."

    func amend(_ events: [GameEvent], context: PassiveContext) -> [GameEvent] {
        let board = context.currentBoard
        let restored = uniformLines(board: board).flatMap { $0 }
        guard !restored.isEmpty else { return [] }

        let changes = restored.reduce(into: [GridPoint: TileHealth]()) { $0[$1] = .healthy }
        return [
            .tilesChanged(plane: context.plane, changes: changes),
            .passiveFired(name: displayName, refused: false),
        ]
    }

    /// **Every** line that has levelled out, not the first one found.
    ///
    /// One at a time was an artificial cap that only showed up in play: level
    /// two lines with a single move — which Equitable Impact's twin trenches
    /// make an ordinary thing to do — and one of them silently did not pay.
    /// Nothing about the design wanted that; it was where the loop happened to
    /// `return`.
    ///
    /// A line already at full health is skipped, since restoring it is a no-op.
    private func uniformLines(board: Board) -> [[GridPoint]] {
        // Rows *and* columns, on both planes.
        //
        // One axis per plane was a nice idea that played badly: it meant half of
        // every board was scenery, and the player had to hold "which grain am I
        // on" in their head while doing the actual arithmetic of levelling seven
        // squares. Both axes everywhere is one rule instead of two, and it makes
        // the good move — a trench that finishes a row and a column at once —
        // possible rather than theoretical.
        let lines: [[GridPoint]] = (0..<board.size).flatMap { index in
            [
                (0..<board.size).map { GridPoint($0, index) },
                (0..<board.size).map { GridPoint(index, $0) },
            ]
        }

        return lines.compactMap { line in

            // Structural squares are **skipped, not disqualifying**.
            //
            // The Nexys has no wear state, so a line through it could never be
            // uniform — which quietly exempted the middle row and column from
            // the ability, and on the plane the island is sitting on that is a
            // seventh of the board dead to it. It reads as a gap in the line
            // now: the rest still has to agree, and the rest is what mends.
            let ground = line.filter { board[$0].kind == .normal }
            guard !ground.isEmpty else { return nil }

            let health = board[ground[0]].health
            guard health != .healthy else { return nil }
            guard ground.allSatisfy({ board[$0].health == health }) else { return nil }

            return ground
        }
    }
}

// MARK: - Passive 3: Judicator Elevator

/// The island is Libra's lift, and Astra does not tidy itself up behind her.
///
/// ## Two boards, not one board and a floor
///
/// Every other sign treats Astra as somewhere to survive and Terra as what
/// happens when they fail. Libra is the exception: standing on the Nexys carries
/// her whichever way she is not, freely and as often as she likes, so both
/// planes are live at once.
///
/// The price is that Astra stops regenerating. For everyone else, leaving Astra
/// repairs it — that is the mechanism that makes long runs possible at all — and
/// for a sign that can leave and come back at will it would be an infinite
/// board. So Libra's Astra decays and stays decayed, and keeping it habitable is
/// her job rather than the game's.
///
/// That is what turns the rest of the kit into a management game: Axial
/// Adjudication mends a line on whichever plane she is standing on, the Gavel
/// drops ground where she needs it, and Balancing Breeze copies one board over
/// the other. None of those are worth much with one board to look after.
struct LibraJudicatorElevator: ZodiacPassive {

    let displayName = "Judicator Elevator"
    let icon: String? = "libra_judicator"
    let summary = "Astra & Terra: stand on the Nexys to travel between planes at will. In exchange, Astra never repairs itself for you."

    func ridesNexysDown(context: PassiveContext) -> Bool { true }

    func restoresPlaneOnDescent(context: PassiveContext) -> Bool { false }

    /// The Nexys Shift becomes the Galeforce Gavel in her hands.
    ///
    /// A trade rather than an extra entry: the Shift is worth nothing to Libra —
    /// it moves the island to her plane, and she can call it herself — so its
    /// slot is spent on something she can use.
    ///
    /// The Gavel does **not** inherit the Shift's rate. The Shift is the rarest
    /// thing in its tier because for everyone else it is a rescue; the Gavel is
    /// the tool this sign is built around, and at the Shift's weight of one it
    /// went whole sessions without appearing.
    func pickupChance(_ base: Int, for id: PickupID, context: PassiveContext) -> Int {
        switch id {
        case .nexysShift: 0
        case .galeforceGavel: GameRules.galeforceGavelChance
        default: base
        }
    }
}

// MARK: - Zodiaction: Balancing Breeze

/// Copies the plane Libra is standing on over the top of the other one.
///
/// ## Why a copy rather than a transformation
///
/// The old Breeze rewrote the current board by a table — cracked becomes
/// healthy, healthy becomes a hole, and so on — which was a card you held for
/// one specific board state and otherwise never played. Copying is the move that
/// belongs to a sign with two boards: whichever one you have been keeping tidy
/// becomes the one you were neglecting.
///
/// It is symmetrical and it is brutal in both directions. Stand on a repaired
/// Astra and Terra is repaired with it; stand on a wrecked Terra with the meter
/// full and you have just wrecked Astra as well. The scales do not care which
/// way they tip, which is the whole of the sign.
///
/// ## What it does not copy
///
/// Structural squares — the island and the chasm it leaves — are skipped in both
/// directions. They sit on opposite planes by definition, and a copy that moved
/// them would put two islands on one board or none on either.
///
/// The square a Pentacle is standing on is skipped as well, for the reason it
/// always was: a coin over a hole is destroyed, and destroying the coin at the
/// same moment the board loses everywhere a new one could spawn ends the hunt
/// for good.
struct LibraBalancingBreeze: Zodiaction {

    let displayName = "Balancing Breeze"
    let summary = "Astra & Terra: copy the board you are standing on over the top of the other one."

    /// - TODO: Libra has no charge rule specified. It currently fills only from
    ///   Pentacles.
    func meterGain(from move: MoveSummary, context: PassiveContext) -> Int { 0 }

    /// There is nothing to copy onto from a plane with nothing under it.
    func canActivate(context: PassiveContext) -> Bool {
        context.boardBelow != nil || context.plane == .terra
    }

    func activate(context: PassiveContext, generator: inout SeededRandom) -> [GameEvent] {
        let source = context.currentBoard
        let target: Plane = context.plane == .astra ? .terra : .astra

        var changes: [GridPoint: TileHealth] = [:]
        for point in source.allPoints {
            // Structural on either side is left alone: the island belongs to
            // whichever plane it is on, and the chasm is its shadow.
            guard source[point].kind == .normal else { continue }
            guard !context.pickupPoints.contains(point) else { continue }
            changes[point] = source[point].health
        }

        return changes.isEmpty ? [] : [.tilesChanged(plane: target, changes: changes)]
    }
}
