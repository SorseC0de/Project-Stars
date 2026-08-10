//
//  Leo.swift
//  Project Stars
//
//  ♌ Leo — The Lion
//
//  Everything specific to this sign lives in this file. Leo is a fire
//  sign, so it is stronger on **Terra** and weaker on **Astra**.
//

import SwiftUI

// MARK: - Definition

extension ZodiacCatalog {

    /// ♌ Leo — The Lion. Fire, Jul 23 – Aug 22. Strong on Terra.
    static let leo = ZodiacDefinition(
        sign: .leo,
        displayName: "Leo",
        glyph: "♌",
        element: .fire,
        accentColor: Color(hex: 0xF0_8A_2E),
        movement: .cardinalStep,
        passives: [
            LeoPridefulFall(),
        ],
        zodiaction: LeoSolarPull()
    )
}

// MARK: - Passive: Prideful Fall

/// Three pips for hitting the ground.
///
/// Falling is a loss for every other sign; for Leo it is the descent to the
/// plane it is strong on, and it charges for the privilege.
struct LeoPridefulFall: ZodiacPassive {

    let displayName = "Prideful Fall"
    let summary = "Astra: +3 charge on landing after a fall to Terra."

    func meterBonus(from move: MoveSummary, context: PassiveContext) -> Int {
        move.fell ? 3 : 0
    }
}

// MARK: - Zodiaction: Solar Pull

/// Hangs a small sun over the square Leo faces.
///
/// It mends that square outright, then burns for five moves, dragging the
/// Pentacle one square toward itself every move — shortest path, diagonals
/// included, so the coin cuts across the board rather than walking it.
///
/// ## What it does not do
///
/// It never fills a hole. A hole is not damage to a tile, it is the absence of
/// one, and letting the sun paper over holes would make Leo the sign that undoes
/// the board's decay — which is the pressure the whole game runs on.
///
/// A coin dragged onto a hole is destroyed and the hunt restarts. That is not a
/// special case here: `ensurePentacleAvailable` already governs any coin left
/// standing on nothing, and the sun's pull is planned before it runs.
///
/// ## The Nexys
///
/// Raise a sun over the Nexys' own chasm while the island is up on Astra and it
/// drags the island down to Terra instead — and goes out immediately, having
/// spent itself on the one thing it cannot do twice. Once per run, refreshed by
/// changing pieces, which is exactly the rule Scorpio's Shed uses.
///
/// The sun is not placed at all in that case: it did its work in one move, and
/// leaving it burning would give the pull five free moves on top of the island.
struct LeoSolarPull: Zodiaction {

    /// Key this sign owns in `SignState.runFlags`.
    static let nexysPullKey = "leo.nexysPull"

    let displayName = "Solar Pull"
    let summary = "Hang a sun on the tile ahead for 5 moves: it mends that tile and drags the Pentacle one square toward it each move."

    /// Leo's charge comes from Prideful Fall.
    func meterGain(from move: MoveSummary, context: PassiveContext) -> Int { 0 }

    func activate(context: PassiveContext, generator: inout SeededRandom) -> [GameEvent] {
        let target = context.piecePoint.offset(by: context.facing.unitOffset)

        // Facing off the board, the sun has nowhere to hang.
        guard context.currentBoard.contains(target) else { return [] }

        if let pull = nexysPull(to: target, context: context) { return pull }

        var events: [GameEvent] = []
        let tile = context.currentBoard[target]

        if GameRules.sunHealsItsTile, tile.kind == .normal,
           !tile.health.isHole, tile.health != .healthy {
            events.append(.tileHealed(plane: context.plane, point: target, to: TileHealth.healthy))
        }

        var state = context.signState
        state.sun = SignState.Sun(
            point: target,
            plane: context.plane,
            movesRemaining: GameRules.sunMoves
        )
        events.append(.signStateChanged(state))

        return events
    }

    /// The island coming down, if this is that move.
    ///
    /// Returns `nil` when it is an ordinary sun, so the caller reads as one
    /// path with one exception rather than as two branches.
    private func nexysPull(to target: GridPoint, context: PassiveContext) -> [GameEvent]? {
        guard target == GameRules.nexysPoint,
              context.plane == .terra,
              context.nexysPlane == .astra,
              !context.signState.runFlags.contains(Self.nexysPullKey)
        else { return nil }

        var state = context.signState
        state.runFlags.insert(Self.nexysPullKey)

        return [
            .nexysMoved(to: .terra, carryingPiece: false),
            .signStateChanged(state),
        ]
    }
}
