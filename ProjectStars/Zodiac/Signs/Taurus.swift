//
//  Taurus.swift
//  Project Stars
//
//  ♉ Taurus — The Bull
//
//  Everything specific to this sign lives in this file. Taurus is an earth
//  sign, so it is stronger on **Terra** and weaker on **Astra**.
//

import SwiftUI

// MARK: - Definition

extension ZodiacCatalog {

    /// ♉ Taurus — The Bull. Earth, Apr 20 – May 20. Strong on Terra.
    static let taurus = ZodiacDefinition(
        sign: .taurus,
        displayName: "Taurus",
        glyph: "♉",
        element: .earth,
        accentColor: Color(hex: 0x7A_9E_4C),
        movement: .cardinalStep,
        passives: [
            TaurusHooves(),
        ],
        zodiaction: TaurusHeavyFlop()
    )
}

// MARK: - Passive: Heavy Hooves / Hasty Hooves

/// The same weight, read two ways depending on what is underfoot.
///
/// On Astra the bull is far too heavy for cloud: every landing takes two stages
/// instead of one, so Taurus wrecks the upper board twice as fast as anyone.
/// On Terra — solid ground it belongs on — it takes two footfalls to move a tile
/// one stage, making it the most durable sign down there.
///
/// The Terra half needs memory, since "two footfalls" spans moves. The first
/// footfall is recorded in `SignState.partialWear` and the second spends it.
///
/// - Note: The design names this differently per plane — Heavy Hooves above,
///   Hasty Hooves below. `displayName` is one string, so it carries both; if the
///   panel should show only the current one, that is a UI change, not a rules
///   change.
struct TaurusHooves: ZodiacPassive {

    let displayName = "Heavy / Hasty Hooves"
    let summary = "Astra: landings damage 2 stages. Terra: two landings to damage 1 stage."

    func modifyWear(_ proposal: WearProposal, context: PassiveContext) -> WearProposal {
        var hooves = proposal

        switch proposal.plane {
        case .astra:
            hooves.stages = proposal.stages * 2

        case .terra:
            if proposal.signState.hasPartialWear(at: proposal.point, on: .terra) {
                // Second footfall: the tile finally gives.
                hooves.signState.clearPartialWear(at: proposal.point, on: .terra)
            } else {
                // First footfall only scuffs it.
                hooves.signState.addPartialWear(at: proposal.point, on: .terra)
                hooves.stages = 0
            }
        }

        return hooves
    }
}

// MARK: - Zodiaction: Heavy Flop

/// Drops the bull's full weight through the floor, and mends what it lands on.
///
/// - **On Astra** it stops pretending the clouds can hold it: Taurus punches
///   straight down to Terra, and the tile it comes down on is fully restored by
///   the impact. If the square below is already open, nothing catches the fall
///   and the run ends — this is a committed, unrecoverable move.
/// - **On Terra**, with nowhere left to fall, the impact spreads instead:
///   everything in the 3x3 around Taurus is fully restored, holes included. That
///   is the only effect in the game that closes several holes at once.
struct TaurusHeavyFlop: Zodiaction {

    let displayName = "Heavy Flop"
    let summary = "Astra: crash to Terra, fully mending the tile below (fatal if it is open). Terra: fully mend the 3x3 around you."

    /// Taurus has no charge rule of its own — by design it fills its meter only
    /// from Pentacles, which makes every pop a deliberate resource decision.
    func meterGain(from move: MoveSummary, context: PassiveContext) -> Int { 0 }

    func activate(context: PassiveContext, generator: inout SeededRandom) -> [GameEvent] {
        switch context.plane {
        case .astra: return flopThroughAstra(context)
        case .terra: return flopOnTerra(context)
        }
    }

    // MARK: Astra

    private func flopThroughAstra(_ context: PassiveContext) -> [GameEvent] {
        guard let below = context.boardBelow else { return [] }
        let point = context.piecePoint

        var events: [GameEvent] = [
            .pieceFell(from: .astra, to: .terra, at: point)
        ]

        // Leaving Astra restores it, exactly as an ordinary descent does.
        if GameRules.astraRestoresOnDescent {
            events.append(.planeRestored(plane: .astra))
        }

        // Nothing below to mend and nothing to stand on: the flop is fatal.
        guard below[point].kind == .normal else {
            events.append(.gameOver(reason: .fellThroughTerra))
            return events
        }

        if below[point].health != .healthy {
            events.append(.tileHealed(plane: .terra, point: point, to: .healthy))
        }
        return events
    }

    // MARK: Terra

    private func flopOnTerra(_ context: PassiveContext) -> [GameEvent] {
        // One impact, so one event — see `GameEvent.tilesChanged`.
        let changes = context.piecePoint.neighbourhood(includingSelf: true)
            .filter { context.currentBoard.contains($0) }
            .filter { context.currentBoard[$0].kind == .normal }
            .filter { context.currentBoard[$0].health != .healthy }
            .reduce(into: [GridPoint: TileHealth]()) { $0[$1] = .healthy }

        return changes.isEmpty ? [] : [.tilesChanged(plane: .terra, changes: changes)]
    }
}
