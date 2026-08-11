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
            AriesSearingStride(),
            AriesBrazenBlazeCarrier(),
        ],
        zodiaction: AriesBrazenBlaze(),
        constellation: ZodiacCatalog.ariesConstellation
    )

    /// ♈ Aries: the short hooked line of Hamal, Sheratan and Mesarthim.
    static let ariesConstellation = Constellation(
        stars: [
            Constellation.Star(-1.05, -0.45, -0.30, 0.7),
            Constellation.Star(-0.25, -0.10,  0.10, 0.9),
            Constellation.Star( 0.55,  0.35,  0.25, 1.4),
            Constellation.Star( 1.05,  0.70, -0.15, 1.0),
        ],
        lines: [(0, 1), (1, 2), (2, 3)]
    )
}

// MARK: - Passive: Searing Stride

/// One pip of charge for every move that continues a straight line, from the
/// third onward.
///
/// Reads the streak the engine already keeps in `SignState`, so it costs nothing
/// to maintain and resets the instant the player turns — which is the whole
/// tension of it, since a board decays fastest along the line you keep running.
///
/// ## Why the third and not the second
///
/// Paying from the second move meant a single repeat was already a straight
/// line, and two moves is not a commitment — you can change your mind every
/// other turn and still be charging the whole time. Requiring three makes the
/// player hold a direction long enough for the tile decay to catch up with
/// them, which is the cost the charge is supposed to be paid for.
struct AriesSearingStride: ZodiacPassive {

    /// How long the streak must run before it pays.
    ///
    /// Counts the move being priced, so `3` is "two repeats after the first".
    static let requiredStreak = 3

    let displayName = "Searing Stride"
    let summary = "Astra & Terra: +1 charge for each consecutive move in the same direction after the second. Silent while Brazen Blaze burns."

    func meterBonus(from move: MoveSummary, context: PassiveContext) -> Int {
        // Not while Brazen Blaze burns.
        //
        // The two make a loop otherwise: Blaze defers damage to the tile being
        // left, so a burning Aries can run a straight line over ground it has
        // not touched yet, taking no wear on arrival and charging a pip a move
        // for doing it — which pays for the next Blaze. An ability should not
        // fund its own repeat.
        guard !context.signState.isActive(AriesBrazenBlazeCarrier.buffKey) else { return 0 }

        // `signState` is updated before charging, so the streak already counts
        // the move being priced. Length 1 is a fresh direction and pays nothing.
        return context.signState.streakLength >= Self.requiredStreak ? 1 : 0
    }
}

// MARK: - Passive: Brazen Blaze carrier

/// The half of Brazen Blaze that has to live in a passive.
///
/// A Zodiaction fires once and is gone, but Brazen Blaze changes how the next
/// five moves *behave*. The Zodiaction sets a timer in `SignState`; this reads it.
/// Splitting it that way keeps the buff on exactly the hooks it needs and out of
/// the engine.
struct AriesBrazenBlazeCarrier: ZodiacPassive {

    /// Key this sign owns in `SignState.buffs`.
    static let buffKey = "aries.brazenBlaze"

    let displayName = "Brazen Blaze (active)"
    let summary = "While Brazen Blaze burns: damage lands on the tile you leave, at double strength."

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

// MARK: - Zodiaction: Brazen Blaze

/// For the next five moves, wear is charged to the tile being left rather than
/// the one being entered — and at double strength.
///
/// Trading entry damage for exit damage is not a straight upgrade: it means the
/// square you are standing on is the one that breaks, so a burning Aries leaves a
/// trail of holes behind it and has to keep moving forward over ground it has not
/// yet touched.
struct AriesBrazenBlaze: Zodiaction {

    let displayName = "Brazen Blaze"
    let summary = "5 moves: damage the tile you leave instead of the one you land on, doubled."

    /// All of Aries' charge comes from Searing Stride, so the Zodiaction itself
    /// adds nothing. There is deliberately no universal charge rule.
    func meterGain(from move: MoveSummary, context: PassiveContext) -> Int { 0 }

    func activate(context: PassiveContext, generator: inout SeededRandom) -> [GameEvent] {
        var state = context.signState
        state.startBuff(AriesBrazenBlazeCarrier.buffKey, moves: 5)
        return [.signStateChanged(state)]
    }
}
