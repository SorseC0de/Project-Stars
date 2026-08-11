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
            AriesSixSinge(),
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

// MARK: - Passive: Six Singe

/// Crossing the whole board in one direction fills the meter.
///
/// Six moves is edge to edge on a seven-wide board, so this cannot be done twice
/// without turning — and turning is the one thing Searing Stride already
/// punishes. It is the same idea taken to its end: the ram commits, and the
/// reward for committing completely is everything.
///
/// ## Why the bonus is a fixed number
///
/// It pays six, which alongside Searing Stride's four fills the meter under
/// ordinary conditions. It is deliberately *not* "however much is missing":
/// computed that way it would erase anything that had just drained the meter —
/// open a Pentacle that zeroes your charge, then walk a straight line, and the
/// loss never happened. The promise is a full meter for crossing the board, not
/// a full meter whatever else occurred.
struct AriesSixSinge: ZodiacPassive {

    let displayName = "Six Singe"
    let summary = "Astra & Terra: crossing the board in a straight line tops your meter up to full."

    func meterBonus(from move: MoveSummary, context: PassiveContext) -> Int {
        guard context.signState.streakLength == GameRules.sixSingeLength else { return 0 }
        return GameRules.sixSingeBonus
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
    let summary = "While Brazen Blaze burns: damage lands on the tile you leave — doubled on Astra."

    func wearTiming(context: PassiveContext) -> WearTiming {
        context.signState.isActive(Self.buffKey) ? .onExit : .onEntry
    }

    func modifyWear(_ proposal: WearProposal, context: PassiveContext) -> WearProposal {
        guard context.signState.isActive(Self.buffKey) else { return proposal }

        // Doubled on Astra only.
        //
        // Damage is the cost, not the payoff — the run ends when the board runs
        // out, so tearing through it twice as fast is what Blaze charges for
        // moving the damage behind you. That cost belongs on the plane where
        // Aries is weak, which for a fire sign is Astra. On Terra, where it is
        // strong, it gets the deferral at ordinary rates.
        guard context.plane == .astra else { return proposal }

        var burned = proposal
        burned.stages = proposal.stages * 2
        return burned
    }
}

// MARK: - Zodiaction: Brazen Blaze

/// For the next several moves, wear is charged to the tile being left rather
/// than the one being entered — and at double strength.
///
/// ## Why the duration is also the drawback
///
/// Lengthening it does not straightforwardly buff the sign. More moves under
/// Blaze is more ground you survive now and more of the board gone later, since
/// every one of those moves is doubled damage charged to somewhere you have
/// already been. The knob buys short-term safety with long-term board — which is
/// about as Aries as a mechanic gets, and the reason it can be raised without
/// much fear.
///
/// Trading entry damage for exit damage is not a straight upgrade: it means the
/// square you are standing on is the one that breaks, so a burning Aries leaves a
/// trail of holes behind it and has to keep moving forward over ground it has not
/// yet touched.
struct AriesBrazenBlaze: Zodiaction {

    let displayName = "Brazen Blaze"
    let summary = "\(GameRules.brazenBlazeMoves) moves: damage the tile you leave instead of the one you land on. Doubled on Astra."

    /// All of Aries' charge comes from Searing Stride, so the Zodiaction itself
    /// adds nothing. There is deliberately no universal charge rule.
    func meterGain(from move: MoveSummary, context: PassiveContext) -> Int { 0 }

    func activate(context: PassiveContext, generator: inout SeededRandom) -> [GameEvent] {
        var state = context.signState
        state.startBuff(AriesBrazenBlazeCarrier.buffKey, moves: GameRules.brazenBlazeMoves)
        return [.signStateChanged(state)]
    }
}
