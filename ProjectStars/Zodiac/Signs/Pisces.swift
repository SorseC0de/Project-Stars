//
//  Pisces.swift
//  Project Stars
//
//  ♓ Pisces — The Fishes
//
//  Everything specific to this sign lives in this file. Pisces is a water
//  sign, so it is stronger on **Astra** and weaker on **Terra**.
//

import SwiftUI

// MARK: - Definition

extension ZodiacCatalog {

    /// ♓ Pisces — The Fishes. Water, Feb 19 – Mar 20. Strong on Astra.
    static let pisces = ZodiacDefinition(
        sign: .pisces,
        displayName: "Pisces",
        glyph: "♓",
        element: .water,
        accentColor: Color(hex: 0x5F_C2_A8),
        movement: .cardinalStep,
        passives: [
            PiscesAstralAttunement(),
            PiscesGaiaGeyser(),
        ],
        zodiaction: PiscesSurgingStream(),
        constellation: ZodiacCatalog.piscesConstellation
    )

    /// ♓ Pisces: two fish on a cord, meeting at Alrescha.
    static let piscesConstellation = Constellation(
        stars: [
            Constellation.Star(-1.10,  0.90,  0.20, 0.8),
            Constellation.Star(-0.85,  0.30,  0.10, 0.7),
            Constellation.Star(-0.40, -0.20,  0.00, 0.8),
            Constellation.Star( 0.05, -0.75, -0.10, 1.2),
            Constellation.Star( 0.55, -0.25, -0.20, 0.8),
            Constellation.Star( 0.95,  0.35, -0.10, 0.7),
            Constellation.Star( 1.05,  0.95,  0.15, 0.9),
        ],
        lines: [(0, 1), (1, 2), (2, 3), (3, 4), (4, 5), (5, 6)]
    )
}

// MARK: - Passive 1: Astral Attunement

/// The tide runs one way: every move on Astra charges, every move on Terra
/// drains.
///
/// It makes Pisces the only sign with a reason to *stay* on Astra rather than
/// treat it as a floor to fall through — and the only one whose meter is a
/// countdown once it goes down.
///
/// ## Astra pays on arrival, Terra charges on departure
///
/// Not symmetry for its own sake. Charging Terra's drain on *arrival* meant the
/// move that reached a Pentacle paid the toll and collected in the same breath:
/// land on a Z-Charge at zero and you finished on two, not three, which reads as
/// the coin having shortchanged you. Billing the drain to the square you *leave*
/// puts the toll on the move that spends the ground, and lets a coin be worth
/// exactly what it says.
///
/// It also means the descent itself is free — a move that starts on Astra never
/// drains — which is right, since Gaia Geyser is filling the meter on that very
/// move.
struct PiscesAstralAttunement: ZodiacPassive {

    let displayName = "Astral Attunement"
    let summary = "Astra: +1 charge on arrival. Terra: −1 charge for every square you leave."

    func meterBonus(from move: MoveSummary, context: PassiveContext) -> Int {
        if move.endingPlane == .astra { return 1 }
        return move.startingPlane == .terra ? -1 : 0
    }
}

// MARK: - Passive 2: Gaia Geyser

/// Arriving on Terra fills the meter completely.
///
/// Which is what keeps Astral Attunement from being a straight punishment: the descent
/// hands Pisces a full meter, and Terra then spends it a pip at a time. The fish
/// arrives rich and leaks.
///
/// Fires on the move that *arrives* — started on Astra, ended on Terra — rather
/// than on any move spent there, so it cannot be farmed by bouncing.
struct PiscesGaiaGeyser: ZodiacPassive {

    let displayName = "Gaia Geyser"
    let summary = "Astra → Terra: arriving on Terra fully restores your charge."

    func meterBonus(from move: MoveSummary, context: PassiveContext) -> Int {
        guard move.startingPlane == .astra, move.endingPlane == .terra else { return 0 }
        // Returned as a top-up rather than an absolute, since the engine sums
        // every contribution and then clamps to the meter's maximum.
        return context.zodiac.zodiaction.meterMax
    }
}

// MARK: - Zodiaction: Current

/// *Provisional name for the pair.* Two entirely different effects sharing one
/// meter, split by plane.
///
/// - **Terra — Upstream:** swim back up to Astra. The only self-sufficient ascent
///   in the game; every other route needs the Nexys. It cannot be used on the
///   same turn as the fall that brought you down, so a descent always costs at
///   least one turn on Terra.
/// - **Astra — Downstream:** the Astral Brook, run from the meter instead of
///   from a coin. Sweeps to the far edge along the facing, wearing every tile
///   crossed and passing over holes.
struct PiscesSurgingStream: Zodiaction {

    let displayName = "Surging Stream"

    /// The two halves, by plane.
    ///
    /// Kept apart from `displayName` rather than folded into it: they are what
    /// the ability *is* on each plane, and the panel will want them set smaller
    /// under the name once the bottom display is revamped for larger text.
    let subtitle = "Upstream / Downstream"
    let summary = "Terra: swim back up to Astra. Astra: sweep to the far edge, damaging every tile you cross."

    /// Pisces' charge comes entirely from Astral Attunement and Gaia Geyser.
    func meterGain(from move: MoveSummary, context: PassiveContext) -> Int { 0 }

    /// Upstream refuses on the turn the fall brought Pisces down: a descent has
    /// to cost at least one turn on Terra. Downstream has no such condition.
    func canActivate(context: PassiveContext) -> Bool {
        guard context.plane == .terra else { return true }
        return context.moveCount > context.signState.planeArrivalMove
    }

    func activate(context: PassiveContext, generator: inout SeededRandom) -> [GameEvent] {
        switch context.plane {
        case .terra: return upstream(context)
        case .astra: return downstream(context)
        }
    }

    // MARK: Terra — Upstream

    private func upstream(_ context: PassiveContext) -> [GameEvent] {
        [
            .pieceTeleported(
                from: context.piecePoint,
                to: context.piecePoint,
                fromPlane: .terra,
                toPlane: .astra
            )
        ]
    }

    // MARK: Astra — Downstream

    /// The Astral Brook, run as a Zodiaction rather than out of a coin.
    ///
    /// Literally that effect — the same function, not a copy of it — so the two
    /// cannot drift apart. Pisces is the water sign; the Brook is the water
    /// Essence; there is no reason for them to be different things.
    private func downstream(_ context: PassiveContext) -> [GameEvent] {
        AstralBrookEffect.slide(
            on: context.currentBoard,
            plane: context.plane,
            from: context.piecePoint,
            facing: context.facing
        )
    }
}
