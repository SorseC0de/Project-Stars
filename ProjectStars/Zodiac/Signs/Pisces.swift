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
            PiscesAstralFlow(),
            PiscesEarthlyDrift(),
        ],
        zodiaction: PiscesCurrent()
    )
}

// MARK: - Passive 1: Astral Flow

/// The tide runs one way: every move on Astra charges, every move on Terra
/// drains.
///
/// It makes Pisces the only sign with a reason to *stay* on Astra rather than
/// treat it as a floor to fall through — and the only one whose meter is a
/// countdown once it goes down.
struct PiscesAstralFlow: ZodiacPassive {

    let displayName = "Astral Flow"
    let summary = "Astra: +1 charge per move. Terra: −1 charge per move."

    func meterBonus(from move: MoveSummary, context: PassiveContext) -> Int {
        move.endingPlane == .astra ? 1 : -1
    }
}

// MARK: - Passive 2: Earthly Drift

/// *Provisional name.* Arriving on Terra fills the meter completely.
///
/// Which is what keeps Astral Flow from being a straight punishment: the descent
/// hands Pisces a full meter, and Terra then spends it a pip at a time. The fish
/// arrives rich and leaks.
///
/// Fires on the move that *arrives* — started on Astra, ended on Terra — rather
/// than on any move spent there, so it cannot be farmed by bouncing.
struct PiscesEarthlyDrift: ZodiacPassive {

    let displayName = "Earthly Drift"
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
/// - **Astra — Downstream:** ride your current tile three squares forward,
///   carrying it — and whatever state it is in — along with you.
struct PiscesCurrent: Zodiaction {

    let displayName = "Upstream / Downstream"
    let summary = "Terra: swim back up to Astra. Astra: ride your tile 3 squares forward. (Downstream not yet implemented.)"

    /// Pisces' charge comes entirely from Astral Flow and Earthly Drift.
    func meterGain(from move: MoveSummary, context: PassiveContext) -> Int { 0 }

    func activate(context: PassiveContext, generator: inout SeededRandom) -> [GameEvent] {
        switch context.plane {
        case .terra: return upstream(context)
        case .astra: return downstream(context)
        }
    }

    // MARK: Terra — Upstream

    private func upstream(_ context: PassiveContext) -> [GameEvent] {
        // Not on the turn you arrived: the fall has to cost something.
        guard context.moveCount > context.signState.planeArrivalMove else { return [] }

        return [
            .pieceTeleported(
                from: context.piecePoint,
                to: context.piecePoint,
                fromPlane: .terra,
                toPlane: .astra
            )
        ]
    }

    // MARK: Astra — Downstream

    private func downstream(_ context: PassiveContext) -> [GameEvent] {
        // TODO: **Not implemented.** Riding the tile means the square travels
        // with the piece, carrying its damage state — the board itself changes
        // shape, which nothing in the game does yet. It needs a
        // `.tilesShifted(from:to:plane:)` event and a decision about what is left
        // behind: a hole, or whatever the destination used to be. The latter is
        // really a swap, and is probably the right reading.
        []
    }
}
