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
            LibraCarefulCurrent(),
            LibraStellarScales(),
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
}

// MARK: - Passive 2: Careful Current

/// A row or column that levels out — every square on it at the same wear — is
/// fully restored. Libra must alternate between the two, never the same axis
/// twice running.
///
/// The alternation is what keeps it from being a repair engine: once a row pays
/// out, the next payout has to come from a column, so Libra has to keep damage
/// spread evenly across both axes. Equitable Impact's twin trenches are exactly
/// the tool for that, which is why the two passives belong together.
///
/// Rows and columns containing the Nexys or its chasm are skipped — a structural
/// square has no wear state to match, so those lines can never be uniform.
struct LibraCarefulCurrent: ZodiacPassive {

    /// Key this sign owns in `SignState.counters`. `0` row, `1` column.
    static let lastAxisKey = "libra.lastCarefulAxis"

    private static let rowAxis = 0
    private static let columnAxis = 1

    let displayName = "Careful Current"
    let summary = "Astra & Terra: a row or column at one uniform wear is fully restored, alternating axes."

    func amend(_ events: [GameEvent], context: PassiveContext) -> [GameEvent] {
        let board = context.currentBoard
        let lastAxis = context.signState.counters[Self.lastAxisKey]

        // Whichever axis did not pay out last time gets first refusal.
        let order = lastAxis == Self.rowAxis
            ? [Self.columnAxis, Self.rowAxis]
            : [Self.rowAxis, Self.columnAxis]

        for axis in order where axis != lastAxis {
            guard let line = uniformLine(axis: axis, board: board) else { continue }

            let changes = line.reduce(into: [GridPoint: TileHealth]()) { $0[$1] = .healthy }

            var state = context.signState
            state.counters[Self.lastAxisKey] = axis

            return [
                .tilesChanged(plane: context.plane, changes: changes),
                .signStateChanged(state),
            ]
        }

        return []
    }

    /// The first line on `axis` whose squares all share one damaged state.
    ///
    /// A line already at full health is ignored — restoring it would be a no-op
    /// that still burned the alternation.
    private func uniformLine(axis: Int, board: Board) -> [GridPoint]? {
        for index in 0..<board.size {
            let line = (0..<board.size).map { other in
                axis == Self.rowAxis ? GridPoint(other, index) : GridPoint(index, other)
            }

            // Structural squares have no wear state, so their line cannot level.
            guard line.allSatisfy({ board[$0].kind == .normal }) else { continue }

            let health = board[line[0]].health
            guard health != .healthy else { continue }
            guard line.allSatisfy({ board[$0].health == health }) else { continue }

            return line
        }
        return nil
    }
}

// MARK: - Passive 3: Stellar Scales

/// The sparkle phase sometimes comes up mirrored — the same shape again, folded
/// across the board's middle.
///
/// Up to ten sparkles instead of five, which is not simply twice the odds: a
/// mirrored set covers both halves of the board, so wherever the piece happens
/// to be standing there is something worth walking to. The scales balance the
/// hunt as well as the ground.
///
/// Commoner on Astra, where Libra is at home, and rare below.
struct LibraStellarScales: ZodiacPassive {

    let displayName = "Stellar Scales"
    let summary = "Astra: 5% chance the sparkle phase appears mirrored across the board. Terra: 1%."

    func mirroredSparkleChance(context: PassiveContext) -> Double {
        switch context.plane {
        case .astra: GameRules.stellarScalesChanceAstra
        case .terra: GameRules.stellarScalesChanceTerra
        }
    }
}

// MARK: - Zodiaction: Balancing Breeze

/// Rewrites every tile's state according to the plane's own
/// logic — mercy below, symmetry above.
///
/// - **Terra** resolves everything toward its extreme: cracked tiles mend
///   completely, badly cracked tiles collapse into holes. A cleaner board with
///   sharper edges.
/// - **Astra** swaps opposites instead: cracked and badly cracked trade places,
///   and — the reason to hold it — every hole becomes healthy while every healthy
///   tile becomes a hole. On a wrecked Astra board that is a full reprieve; on a
///   fresh one it is a catastrophe. Timing is the whole card.
struct LibraBalancingBreeze: Zodiaction {

    let displayName = "Balancing Breeze"
    let summary = "Terra: cracked mend, badly cracked collapse. Astra: cracked ↔ badly cracked, holes ↔ healthy."

    /// - TODO: Libra has no charge rule specified. It currently fills only from
    ///   Pentacles.
    func meterGain(from move: MoveSummary, context: PassiveContext) -> Int { 0 }

    func activate(context: PassiveContext, generator: inout SeededRandom) -> [GameEvent] {
        let board = context.currentBoard

        // The scales tip in one motion, so the whole board travels as a single
        // `tilesChanged`.
        var changes: [GridPoint: TileHealth] = [:]
        for point in board.allPoints {
            let tile = board[point]
            // Structural squares sit outside the scales.
            guard tile.kind == .normal else { continue }

            // So does the square the Pentacle is on. Popping this on a fresh
            // Astra board turns every healthy tile into a hole; if the coin's
            // tile went with them the coin would be destroyed and there would be
            // nowhere left to spawn its replacement, ending the hunt for good.
            // The scales weigh the ground, not what is standing on it.
            guard !context.pickupPoints.contains(point) else { continue }
            guard let target = swapped(tile.health, on: context.plane),
                  target != tile.health else { continue }
            changes[point] = target
        }

        return changes.isEmpty ? [] : [.tilesChanged(plane: context.plane, changes: changes)]
    }

    /// The state a tile is rewritten to, or `nil` to leave it alone.
    private func swapped(_ health: TileHealth, on plane: Plane) -> TileHealth? {
        switch plane {
        case .terra:
            switch health {
            case .cracked: return .healthy
            case .badlyCracked: return .hole
            case .healthy, .hole: return nil
            }
        case .astra:
            switch health {
            case .cracked: return .badlyCracked
            case .badlyCracked: return .cracked
            case .hole: return .healthy
            case .healthy: return .hole
            }
        }
    }
}
