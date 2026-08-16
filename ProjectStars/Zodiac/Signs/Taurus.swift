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
            TaureanTear(),
            TaurusGreedyGather(),
        ],
        zodiaction: TaurusFloweringFlop(),
        constellation: ZodiacCatalog.taurusConstellation
    )

    /// ♉ Taurus: the V of the Hyades, with the horns running off it.
    static let taurusConstellation = Constellation(
        stars: [
            Constellation.Star(-1.10,  0.85,  0.10, 0.8),
            Constellation.Star(-0.55,  0.25,  0.20, 0.9),
            Constellation.Star( 0.00, -0.35,  0.00, 1.5),
            Constellation.Star( 0.55,  0.20, -0.20, 0.9),
            Constellation.Star( 1.10,  0.80, -0.10, 1.1),
            Constellation.Star(-0.30, -0.95,  0.30, 0.7),
            Constellation.Star( 0.35, -0.90, -0.25, 0.7),
        ],
        lines: [(0, 1), (1, 2), (2, 3), (3, 4), (2, 5), (2, 6)]
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
    let icon: String? = "taurus_heavy_hooves"
    let summary = "Astra: landings damage 2 stages. Terra: two landings to damage 1 stage."

    func modifyWear(_ proposal: WearProposal, context: PassiveContext) -> WearProposal {
        var hooves = proposal

        // One cause; it knows what it weighs on each plane.
        hooves.caused(by: .hooves)

        if proposal.plane == .terra {
            if proposal.signState.hasPartialWear(at: proposal.point, on: .terra) {
                // Second footfall: the tile finally gives.
                hooves.signState.clearPartialWear(at: proposal.point, on: .terra)
            } else {
                // First footfall only scuffs it. The cause stays the same — this
                // is still hooves — and taking nothing is what marks it as the
                // free one.
                hooves.signState.addPartialWear(at: proposal.point, on: .terra)
                hooves.stages = 0
            }
        }

        return hooves
    }
}

// MARK: - Passive 2: Taurean Tear

/// An Astral Tear mends a second tile as well.
///
/// Named for the coin it doubles, and for the animal: the bull is the earth
/// sign that *keeps* ground rather than crossing it, and the commonest coin in
/// the game being worth twice as much is a quiet, permanent advantage rather
/// than a burst of one.
///
/// ## Why only the Tear
///
/// Not every heal. Astral Blossom already repairs a 3x3 and Polaris mends a
/// whole plane; doubling those would be doubling an area effect, which is a
/// different and much larger thing. The Tear repairs exactly one tile, and this
/// makes it two — the smallest heal in the game, made the second smallest.
///
/// ## Why it is `amend` rather than part of the coin
///
/// The coin knows nothing about who opened it, and should not. This watches the
/// move for a Tear being collected and adds its own repair afterwards, which is
/// the same hook Gemini mirrors with. Its output is not itself amended, so it
/// cannot chain.
struct TaureanTear: ZodiacPassive {

    let displayName = "Taurean Tear"
    let summary = "Astra & Terra: an Astral Tear has a \(Int(GameRules.taureanTearChance * 100))% chance to repair a second tile too."

    func amend(_ events: [GameEvent], context: PassiveContext) -> [GameEvent] {
        let openedTear = events.contains { event in
            if case let .pickupCollected(id, _, _) = event { return id == .restoreTile }
            return false
        }
        guard openedTear else { return [] }

        // Rolled against `luckAlt` rather than `luck`, which is already spoken
        // for below: sharing one roll would tie *whether* this fires to *which*
        // tile it would have picked.
        guard context.luckAlt < GameRules.taureanTearChance else { return [] }

        // The board as it stands *after* the coin's own repair, so the tile it
        // just mended cannot be picked again.
        let board = context.currentBoard
        let damaged = board.allPoints.filter {
            board[$0].kind == .normal && board[$0].canBeRepaired
        }
        guard !damaged.isEmpty else { return [] }

        // Drawn from the move's own roll rather than a fresh one, so a seeded
        // run stays reproducible — the same reason chance-based passives are
        // handed `luck` instead of a generator.
        let index = min(Int(context.luck * Double(damaged.count)), damaged.count - 1)

        // Fully, like the coin it follows: a hole goes straight back to healthy.
        return [.tileHealed(plane: context.plane, point: damaged[index], to: .healthy)]
    }
}

// MARK: - Passive 3: Greedy Gather

/// Charge for finding the coin on the first square you tried.
///
/// The bull does not hunt so much as *arrive*, and being right first time is
/// worth something. `collectedOnRevealTile` is the exact distinction: the
/// sparkle you landed on turned out to be the one hiding it, rather than the
/// coin being somewhere else in the set and walked to afterwards.
struct TaurusGreedyGather: ZodiacPassive {

    let displayName = "Greedy Gather"
    let summary = "Astra & Terra: +3 ZC when the sparkle you land on is the one holding the Pentacle."

    func meterBonus(from move: MoveSummary, context: PassiveContext) -> Int {
        move.collectedOnRevealTile ? 3 : 0
    }
}

// MARK: - Zodiaction: Flowering Flop

/// Drops the bull's full weight through the floor, and mends what it lands on.
///
/// - **On Astra** it stops pretending the clouds can hold it: Taurus punches
///   straight down to Terra, and the tile it comes down on is fully restored by
///   the impact. If the square below is already open, nothing catches the fall
///   and the run ends — this is a committed, unrecoverable move.
/// - **On Terra**, with nowhere left to fall, the impact spreads instead:
///   everything in the 3x3 around Taurus is fully restored, holes included. That
///   is the only effect in the game that closes several holes at once.
struct TaurusFloweringFlop: Zodiaction {

    let displayName = "Flowering Flop"
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
