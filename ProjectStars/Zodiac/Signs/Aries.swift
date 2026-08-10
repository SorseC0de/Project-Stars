//
//  Aries.swift
//  Project Stars
//
//  ♈ Aries — The Ram
//
//  Everything specific to this sign lives in this file. Aries is a fire
//  sign, so it is stronger on **Terra** and weaker on **Astra**.
//

import SwiftUI

// MARK: - Definition

extension ZodiacCatalog {

    /// ♈ Aries — The Ram. Fire, Mar 21 – Apr 19. Strong on Terra.
    static let aries = ZodiacDefinition(
        sign: .aries,
        displayName: "Aries",
        glyph: "♈",
        element: .fire,
        accentColor: Color(hex: 0xE0_53_3F),
        movement: .cardinalStep,
        passives: [
            AriesChargingRam(),
            AriesBlazePathCarrier(),
        ],
        zodiaction: AriesBlazePath()
    )
}

// MARK: - Passive: Charging Ram

/// *Provisional name.* One pip of charge for every move that continues a
/// straight line, from the second onward.
///
/// Reads the streak the engine already keeps in `SignState`, so it costs nothing
/// to maintain and resets the instant the player turns — which is the whole
/// tension of it, since a board decays fastest along the line you keep running.
struct AriesChargingRam: ZodiacPassive {

    let displayName = "Charging Ram"
    let summary = "Astra & Terra: +1 charge for each consecutive move in the same direction after the first."

    func meterBonus(from move: MoveSummary, context: PassiveContext) -> Int {
        // `signState` is updated before charging, so the streak already counts
        // the move being priced. Length 1 is a fresh direction and pays nothing.
        context.signState.streakLength >= 2 ? 1 : 0
    }
}

// MARK: - Passive: Blaze Path carrier

/// The half of Blaze Path that has to live in a passive.
///
/// A Zodiaction fires once and is gone, but Blaze Path changes how the next five
/// moves *behave*. The Zodiaction sets a timer in `SignState`; this reads it.
/// Splitting it that way keeps the buff on exactly the hooks it needs and out of
/// the engine.
struct AriesBlazePathCarrier: ZodiacPassive {

    /// Key this sign owns in `SignState.buffs`.
    static let buffKey = "aries.blazePath"

    let displayName = "Blaze Path (active)"
    let summary = "While Blaze Path burns: damage lands on the tile you leave, at double strength."

    func wearTiming(context: PassiveContext) -> WearTiming {
        context.signState.isActive(Self.buffKey) ? .onExit : .onEntry
    }

    func modifyWear(_ proposal: WearProposal, context: PassiveContext) -> WearProposal {
        guard context.signState.isActive(Self.buffKey) else { return proposal }
        var burned = proposal
        burned.stages = proposal.stages * 2
        return burned
    }
}

// MARK: - Zodiaction: Blaze Path

/// For the next five moves, wear is charged to the tile being left rather than
/// the one being entered — and at double strength.
///
/// Trading entry damage for exit damage is not a straight upgrade: it means the
/// square you are standing on is the one that breaks, so a burning Aries leaves a
/// trail of holes behind it and has to keep moving forward over ground it has not
/// yet touched.
struct AriesBlazePath: Zodiaction {

    let displayName = "Blaze Path"
    let summary = "5 moves: damage the tile you leave instead of the one you land on, doubled."

    /// All of Aries' charge comes from Charging Ram, so the Zodiaction itself
    /// adds nothing. There is deliberately no universal charge rule.
    func meterGain(from move: MoveSummary, context: PassiveContext) -> Int { 0 }

    func activate(context: PassiveContext, generator: inout SeededRandom) -> [GameEvent] {
        var state = context.signState
        state.startBuff(AriesBlazePathCarrier.buffKey, moves: 5)
        return [.signStateChanged(state)]
    }
}
