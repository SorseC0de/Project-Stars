//
//  Virgo.swift
//  Project Stars
//
//  ♍ Virgo — The Maiden
//
//  Everything specific to this sign lives in this file. Virgo is an earth
//  sign, so it is stronger on **Terra** and weaker on **Astra**.
//

import SwiftUI

// MARK: - Definition

extension ZodiacCatalog {

    /// ♍ Virgo — The Maiden. Earth, Aug 23 – Sep 22. Strong on Terra.
    static let virgo = ZodiacDefinition(
        sign: .virgo,
        displayName: "Virgo",
        glyph: "♍",
        element: .earth,
        accentColor: Color(hex: 0x9A_AF_6B),
        movement: .cardinalStep,
        passives: [
            VirgoControlledLanding(),
            VirgoProtectiveStep(),
            VirgoSoftLanding(),
        ],
        zodiaction: VirgoRecalibrate()
    )
}

// MARK: - Passive 1: Controlled Landing

/// The Pentacle appears on whichever sparkling tile Virgo is already heading for.
///
/// It does not guarantee a Pentacle every move — the sparkle phase still has to
/// be running, and the destination still has to be one of the sparkles. What it
/// removes is the guess: for Virgo, aiming at a sparkle *is* opening it.
struct VirgoControlledLanding: ZodiacPassive {

    let displayName = "Controlled Landing"
    let summary = "Astra & Terra: the Pentacle always appears on the sparkling tile you are moving onto."

    func preferredRevealPoint(
        among candidates: [GridPoint],
        destination: GridPoint,
        context: PassiveContext
    ) -> GridPoint? {
        candidates.contains(destination) ? destination : nil
    }
}

// MARK: - Passive 2: Protective Step

/// A badly cracked tile does not break under Virgo — once every three moves.
///
/// The cooldown is what keeps it from being a licence to camp on ruined ground:
/// it saves the step you happen to take, then makes you find real footing again.
struct VirgoProtectiveStep: ZodiacPassive {

    /// Key this sign owns in `SignState.cooldowns`.
    static let cooldownKey = "virgo.protectiveStep"

    /// Committed moves before it is available again.
    static let cooldownMoves = 3

    let displayName = "Protective Step"
    let summary = "Astra & Terra: landing on a badly cracked tile does not break it. 3-move cooldown."

    func modifyWear(_ proposal: WearProposal, context: PassiveContext) -> WearProposal {
        guard proposal.tile.health == .badlyCracked,
              proposal.wouldBreak,
              proposal.signState.isReady(Self.cooldownKey)
        else { return proposal }

        var spared = proposal
        spared.stages = 0
        spared.signState.startCooldown(Self.cooldownKey, moves: Self.cooldownMoves)
        return spared
    }
}

// MARK: - Passive 3: Soft Landing

/// Falling from Astra fully restores the Terra tile Virgo comes down on.
///
/// Never fills a hole — a hole is what was fallen *into*, not what was landed on.
/// The engine enforces that; this hook only ever sees a tile the piece can stand
/// on.
struct VirgoSoftLanding: ZodiacPassive {

    let displayName = "Soft Landing"
    let summary = "Astra: falling to Terra fully restores the tile you land on."

    func restoresTileOnFallArrival(
        tile: Tile,
        at point: GridPoint,
        plane: Plane,
        context: PassiveContext
    ) -> Bool {
        true
    }
}

// MARK: - Zodiaction: Recalibrate

/// *Provisional name.* Forces a fresh sparkle phase immediately.
///
/// If a Pentacle is already sitting on the board, this discards it and starts the
/// hunt over; if a sparkle phase is running, it is re-rolled into a new shape
/// somewhere else. Either way Virgo decides where the next opportunity is,
/// instead of waiting for one.
///
/// Pairs with Controlled Landing: re-roll until the shape falls somewhere
/// convenient, then walk onto the sparkle you want.
struct VirgoRecalibrate: Zodiaction {

    let displayName = "Recalibrate"
    let summary = "Astra & Terra: immediately start a new sparkle phase, replacing any current one."

    /// Virgo's charge comes from its passives and from Pentacles.
    func meterGain(from move: MoveSummary, context: PassiveContext) -> Int { 0 }

    func activate(context: PassiveContext, generator: inout SeededRandom) -> [GameEvent] {
        guard let set = SparkleSet.spawn(
            on: context.plane,
            board: context.currentBoard,
            avoiding: context.piecePoint,
            using: &generator
        ) else { return [] }

        guard let pickup = PickupCatalog.rollPickup(
            sparklePoints: set.points,
            using: &generator
        ) else { return [] }

        return [.sparklesSpawned(set: set, pickup: pickup)]
    }
}
