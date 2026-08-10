//
//  Cancer.swift
//  Project Stars
//
//  ♋ Cancer — The Crab
//
//  Everything specific to this sign lives in this file. Cancer is a water
//  sign, so it is stronger on **Astra** and weaker on **Terra**.
//

import SwiftUI

// MARK: - Definition

extension ZodiacCatalog {

    /// ♋ Cancer — The Crab. Water, Jun 21 – Jul 22. Strong on Astra.
    static let cancer = ZodiacDefinition(
        sign: .cancer,
        displayName: "Cancer",
        glyph: "♋",
        element: .water,
        accentColor: Color(hex: 0x6F_B7_D4),

        // Sidestep: an ordinary step in any direction, but up to two squares
        // to whichever side it is facing across. Drag further to take the full
        // two — see `MovementPattern.option(for:facing:reach:)`.
        movement: .sidestep,

        passives: [
            CancerSidestepInstinct(),
            CancerHomeboundSurge(),
            CancerHeavenlyHoarder(),
        ],
        zodiaction: CancerZodiaction()
    )
}

// MARK: - Passive 1: Sidestep Instinct

/// *Provisional name.* Charge for moving laterally.
///
/// On Terra only the full two-square sidestep pays; on Astra — Cancer's own
/// plane — either distance does. So the crab is rewarded for committing to range
/// down below, and simply for scuttling up above.
struct CancerSidestepInstinct: ZodiacPassive {

    let displayName = "Sidestep Instinct"
    let summary = "Terra: +1 charge for a full 2-tile sidestep. Astra: +1 for any sidestep."

    func meterBonus(from move: MoveSummary, context: PassiveContext) -> Int {
        // Sideways is measured against the facing the piece had *before* the
        // move, which is what `MoveSummary.direction` versus the facing it
        // turned to would confuse — so compare the travelled axis to the axis of
        // the square it started on instead.
        let travelled = move.origin.manhattanDistance(to: move.destination)
        guard move.wasSideways else { return 0 }

        switch move.endingPlane {
        case .astra: return travelled >= 1 ? 1 : 0
        case .terra: return travelled >= 2 ? 1 : 0
        }
    }
}

// MARK: - Passive 2: Homebound Surge

/// Three pips for getting back to the Nexys by any means other than walking.
///
/// The exclusion is the point: strolling onto the island from an adjacent square
/// is not an achievement, but being flung there by a Pentacle, a Zodiaction or a
/// fall is. `MoveSummary.arrivedAtNexysByEffect` draws exactly that line.
struct CancerHomeboundSurge: ZodiacPassive {

    let displayName = "Homebound Surge"
    let summary = "Astra & Terra: +3 charge when you reach the Nexys by anything other than ordinary movement."

    func meterBonus(from move: MoveSummary, context: PassiveContext) -> Int {
        move.arrivedAtNexysByEffect ? 3 : 0
    }
}

// MARK: - Passive 3: Heavenly Hoarder

/// Opening a Pentacle beside the Nexys pays out in charge — and pays double at
/// home in the sky.
///
/// Half a meter on Terra, a full meter on Astra. "Beside" means the eight squares
/// touching the island, not the island itself, which a Pentacle can never occupy
/// anyway since sparkles refuse to sit there.
struct CancerHeavenlyHoarder: ZodiacPassive {

    let displayName = "Heavenly Hoarder"
    let summary = "Open a Pentacle adjacent to the Nexys: +half meter on Terra, +full meter on Astra."

    func meterBonus(from move: MoveSummary, context: PassiveContext) -> Int {
        guard move.collectedPickup != nil else { return 0 }

        // The island has to be on this plane for "adjacent to the Nexys" to mean
        // anything — otherwise that square is the chasm.
        guard move.endingPlane == context.nexysPlane else { return 0 }
        guard move.restingPoint.isAdjacent(to: GameRules.nexysPoint) else { return 0 }

        let max = context.zodiac.zodiaction.meterMax
        return move.endingPlane == .astra ? max : max / 2
    }
}

// MARK: - Zodiaction

/// **Astral Bastion.** Consecrates the ground where the crab stands.
///
/// A 3x3 patch centred on the piece stops taking damage for three committed
/// moves, and lifts as the fourth begins. Nothing advances the wear of a
/// sheltered square: not footfalls, not a Pentacle's blast, not another sign's
/// Zodiaction, not a passive. Repair still works — this is protection, not
/// stasis.
///
/// ## Why the patch does not follow the piece
///
/// The crab consecrates *ground*, and ground stays where it is. A sanctuary
/// that travelled would be a three-move invulnerability, which is a different
/// and much duller ability; one that stays put is a place — somewhere to
/// retreat to, work outward from, and get back to before it lapses. It also
/// gives the three passives above something to point at, since all three
/// already pull Cancer toward holding a spot rather than roaming.
///
/// ## The Pentacle bonus
///
/// Opening a coin inside the patch pays `GameRules.sanctuaryPickupCharge`
/// straight back into the meter. The bonus lives here rather than in a fourth
/// passive because it only exists while the Bastion is standing — it is part of
/// the ability, not part of the sign.
///
/// - Note: Sized by `GameRules.sanctuaryRadius`. If a 3x3 proves too strong,
///   `0` gives a single square and nothing else needs touching.
struct CancerZodiaction: Zodiaction {

    let displayName = "Astral Bastion"
    let summary = "Consecrate a 3x3 around you for 3 moves: those tiles cannot be damaged by anything. Opening a Pentacle inside pays +3 charge."

    /// Charge comes from the three passives, plus coins opened under the
    /// Bastion's own roof.
    func meterGain(from move: MoveSummary, context: PassiveContext) -> Int {
        guard move.collectedPickup != nil else { return 0 }

        // The sanctuary as it stood when the coin was opened. Read from the
        // context rather than from the engine because by the time charge is
        // priced the move has already resolved — and a Bastion expiring on this
        // very move must still pay for the coin taken under it.
        guard context.signState.isSheltered(move.restingPoint, on: move.endingPlane)
        else { return 0 }

        return GameRules.sanctuaryPickupCharge
    }

    func activate(context: PassiveContext, generator: inout SeededRandom) -> [GameEvent] {
        var state = context.signState
        state.sanctuary = SignState.Sanctuary(
            centre: context.piecePoint,
            plane: context.plane,
            movesRemaining: GameRules.sanctuaryMoves,
            radius: GameRules.sanctuaryRadius
        )

        // Re-raising it on the same square is a refresh, not a second one:
        // `sanctuary` holds one region, and this replaces it outright.
        return [.signStateChanged(state)]
    }
}
