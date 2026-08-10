//
//  Sagittarius.swift
//  Project Stars
//
//  ♐ Sagittarius — The Archer
//
//  Everything specific to this sign lives in this file. Sagittarius is a fire
//  sign, so it is stronger on **Terra** and weaker on **Astra**.
//

import SwiftUI

// MARK: - Definition

extension ZodiacCatalog {

    /// ♐ Sagittarius — The Archer. Fire, Nov 22 – Dec 21. Strong on Terra.
    static let sagittarius = ZodiacDefinition(
        sign: .sagittarius,
        displayName: "Sagittarius",
        glyph: "♐",
        element: .fire,
        accentColor: Color(hex: 0xB5_48_2E),

        // Ordinary in every direction but forward, where the archer can stride
        // one or two squares or loose itself three — the three-square shot being
        // a jump, so it clears whatever lies between.
        movement: .archer,

        passives: [
            SagittariusLuckyReveal(),
            SagittariusSafeLanding(),
            SagittariusLuckyLanding(),
        ],
        zodiaction: SagittariusGoldenArrow()
    )
}

// MARK: - Passive 1: Lucky Reveal

/// Three pips when the sparkle you were already walking onto turns out to be the
/// one hiding the Pentacle.
///
/// Pure luck by design — it pays for guessing right, not for playing well, which
/// is exactly the archer's character. Note this is narrower than "opened a
/// Pentacle": it only fires when the coin revealed itself on the very move that
/// took it, which `MoveSummary.collectedOnRevealTile` isolates.
struct SagittariusLuckyReveal: ZodiacPassive {

    let displayName = "Lucky Reveal"
    let summary = "Astra & Terra: +3 charge when the sparkle you land on is the one holding the Pentacle."

    func meterBonus(from move: MoveSummary, context: PassiveContext) -> Int {
        move.collectedOnRevealTile ? 3 : 0
    }
}

// MARK: - Passive 2: Safe Landing

/// A small chance that a badly cracked tile refuses to break — and on Terra, that
/// it mends a stage instead.
///
/// Rolls against `context.luck`, drawn once per move by the engine, so the hook
/// stays a pure function and a seeded run stays reproducible.
struct SagittariusSafeLanding: ZodiacPassive {

    /// Chance of triggering, in `0..<1`.
    ///
    /// - TODO: Untuned. "Very small" in the design; start low and raise it.
    static let chance = 0.12

    let displayName = "Safe Landing"
    let summary = "Small chance a badly cracked tile does not break. On Terra it mends a stage instead."

    func modifyWear(_ proposal: WearProposal, context: PassiveContext) -> WearProposal {
        guard proposal.tile.health == .badlyCracked,
              proposal.wouldBreak,
              context.luck < Self.chance
        else { return proposal }

        var lucky = proposal
        // On Terra — the archer's own plane — it does better than hold: negative
        // stages repair. See `WearProposal.stages`.
        lucky.stages = proposal.plane == .terra ? -1 : 0
        return lucky
    }
}

// MARK: - Passive 3: Lucky Landing

/// A small chance that falling to Terra fully restores the tile landed on.
///
/// Rolls against `luckAlt` rather than `luck` so it is independent of Safe
/// Landing — two chance passives on one sign should not share a coin flip.
struct SagittariusLuckyLanding: ZodiacPassive {

    /// Chance of triggering, in `0..<1`.
    ///
    /// - TODO: Untuned, as with Safe Landing.
    static let chance = 0.12

    let displayName = "Lucky Landing"
    let summary = "Astra: small chance that falling to Terra fully restores the tile you land on."

    func restoresTileOnFallArrival(
        tile: Tile,
        at point: GridPoint,
        plane: Plane,
        context: PassiveContext
    ) -> Bool {
        context.luckAlt < Self.chance
    }
}

// MARK: - Zodiaction: Golden Arrow

/// *Provisional name.* Fires an arrow into the sky; it comes down on a random
/// tile and waits. Pop the Zodiaction again to warp to wherever it landed.
///
/// - TODO: **Not implemented — needs a persistent world object.** The arrow is a
///   marker with a lifetime that survives across moves, and a second activation
///   that consumes it. Nothing in the engine holds board-level objects other than
///   the Pentacle, which is special-cased.
///
///   Three requirements, in order of difficulty:
///   1. A `markers` collection in `GameEngine` plus its events, so an arrow can
///      exist, be drawn, and be spent. Shared with Leo's sun.
///   2. A Zodiaction that means "spend the marker" when one exists rather than
///      "place one" — i.e. `activate` branching on world state, which it already
///      can, since it receives the context.
///   3. The Terra variant's extra clause: warping from Terra also drags the Astra
///      tile at those coordinates down, restoring the Terra tile with it — and if
///      the roll picks the centre, that pulls the Nexys itself down.
///
///   The arrow can land on the Nexys, and can be wasted by landing on a hole.
///   Both fall out of the warp being an ordinary landing.
struct SagittariusGoldenArrow: Zodiaction {

    let displayName = "Golden Arrow"
    let summary = "Fire an arrow to a random tile; pop again to warp to it. (Not yet implemented.)"

    /// Sagittarius' charge comes from Lucky Reveal.
    func meterGain(from move: MoveSummary, context: PassiveContext) -> Int { 0 }
}
