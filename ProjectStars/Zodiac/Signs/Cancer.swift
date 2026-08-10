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

/// - TODO: **Undesigned.** The one sign with no Zodiaction concept yet.
///
///   Shape worth considering, given the three passives above all pull toward the
///   Nexys: something that makes the island itself do work — moving it, or
///   turning the ring around it into safe ground. That would make Cancer the sign
///   that plays the centre, which nothing else currently does.
struct CancerZodiaction: Zodiaction {

    let displayName = "—"
    let summary = "Zodiaction not yet designed."

    /// Cancer's charge comes entirely from its passives.
    func meterGain(from move: MoveSummary, context: PassiveContext) -> Int { 0 }
}
