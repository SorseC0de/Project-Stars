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

/// *Provisional name.* A small sun that drags the Pentacle toward Leo.
///
/// - TODO: **Not implemented, and the design is openly unsettled.** Two readings
///   were sketched:
///
///   1. *Instant tug* — the Pentacle jumps one square closer on Astra, two on
///      Terra.
///   2. *Persistent sun* — a sun is placed on the square Leo faces and stays for
///      several turns, pulling the Pentacle one square toward **it** each move.
///
///   Reading 2 is the stronger one and fits the rest of the game better: it is
///   move-driven rather than instant, it uses facing (which Leo otherwise
///   ignores), and it creates a place on the board the player has to think about
///   for several turns rather than a one-off nudge.
///
///   Either way it needs machinery that does not exist: the revealed Pentacle is
///   fixed at `RevealedPickup.point` with no event that moves it. Add
///   `.pickupMoved(from:to:)` and the instant version is a few lines; the
///   persistent version additionally needs a world object with a lifetime, which
///   is the same requirement as Sagittarius' Golden Arrow and Shadow Work's
///   stalking coin. Worth building once, for all three.
struct LeoSolarPull: Zodiaction {

    let displayName = "Solar Pull"
    let summary = "Draw the Pentacle toward you — 1 tile on Astra, 2 on Terra. (Not yet implemented.)"

    /// Leo's charge comes from Prideful Fall.
    func meterGain(from move: MoveSummary, context: PassiveContext) -> Int { 0 }
}
