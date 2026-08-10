//
//  Capricorn.swift
//  Project Stars
//
//  ♑ Capricorn — The Sea-Goat
//
//  Everything specific to this sign lives in this file. Capricorn is an earth
//  sign, so it is stronger on **Terra** and weaker on **Astra**.
//

import SwiftUI

// MARK: - Definition

extension ZodiacCatalog {

    /// ♑ Capricorn — The Sea-Goat. Earth, Dec 22 – Jan 19. Strong on Terra.
    static let capricorn = ZodiacDefinition(
        sign: .capricorn,
        displayName: "Capricorn",
        glyph: "♑",
        element: .earth,
        accentColor: Color(hex: 0x6B_7A_8F),

        // Mountain Climber. The northward vault is offered by
        // `CapricornMountainClimber` only while it is off cooldown, and charged
        // for by the same passive once taken.
        movement: .cardinalStep,

        passives: [
            CapricornMountainClimber(),
            CapricornSpringboard(),
            CapricornSurefootedAura(),
        ],
        zodiaction: CapricornSurefooted()
    )
}

// MARK: - Passive 1: Mountain Climber

/// Northward, the goat may vault two squares instead of stepping one — then must
/// take a turn before it can do it again.
///
/// North only, and absolutely so: it does not follow the facing. Climbing is a
/// direction on the board, not a direction relative to the climber.
///
/// The two halves are deliberately split across two hooks. `adjustedMovement`
/// only *offers* the vault, and only while the cooldown is clear; `stateAfterMove`
/// charges for it, and only when it was actually taken. Offering and charging in
/// one place would put the cooldown on every northward step, vault or not.
struct CapricornMountainClimber: ZodiacPassive {

    /// Key this sign owns in `SignState.cooldowns`.
    static let cooldownKey = "capricorn.mountainClimber"

    /// Committed moves before another vault is available.
    static let cooldownMoves = 1

    let displayName = "Mountain Climber"
    let summary = "Astra & Terra: northward moves may vault 2 tiles instead of 1. One turn between vaults."

    func adjustedMovement(base: MovementPattern, context: PassiveContext) -> MovementPattern {
        guard context.signState.isReady(Self.cooldownKey) else { return base }
        return .mountainClimber
    }

    func stateAfterMove(
        option: MovementPattern.MoveOption,
        direction: SwipeDirection,
        context: PassiveContext
    ) -> SignState? {
        // Only the vault itself costs anything.
        guard direction == .up, option.distance == 2, option.style == .jump else { return nil }

        var climbed = context.signState
        climbed.startCooldown(Self.cooldownKey, moves: Self.cooldownMoves)
        return climbed
    }
}

// MARK: - Passive 2: Springboard

/// *Provisional name.* Trade a Pentacle for a launch up to the Nexys.
///
/// - **Terra:** opening a Pentacle on a tile adjacent to the centre lets you
///   spring up to the Nexys in Astra instead of taking the Pentacle.
/// - **Astra:** the same trade, but from any Pentacle collected south of the
///   centre row — and only once per visit to Astra.
///
/// - TODO: **Not implemented — needs an optional prompt.** "You *can* opt to"
///   makes this a player decision at collection time, which is the same
///   suspend-and-ask machinery `PickupChoice` already provides for Astral Breeze
///   and Alignment; it just has to be triggerable by a passive rather than only
///   by an effect.
///
///   The per-visit limit needs no new machinery: `SignState.planeFlags` is
///   cleared on every plane arrival, which is exactly "once per Astra visit".
struct CapricornSpringboard: ZodiacPassive {

    /// Key this sign owns in `SignState.planeFlags`.
    static let usedThisVisitKey = "capricorn.springboard"

    let displayName = "Springboard"
    let summary = "Trade a Pentacle near the centre for a launch to the Nexys. (Not yet implemented.)"
}

// MARK: - Passive 3: Surefooted aura

/// The half of the Zodiaction that has to persist: while the aura holds,
/// Capricorn does not fall.
///
/// The guard spends itself the moment it actually catches the piece rather than
/// decaying on a timer — `stateAfterPreventingFall` is called only when
/// `preventsFall` returned `true`, so an aura granted and never needed is still
/// there next turn.
struct CapricornSurefootedAura: ZodiacPassive {

    /// Key this sign owns in `SignState.buffs`.
    static let auraKey = "capricorn.surefooted"

    /// Long enough to be a standing promise rather than a countdown. It is spent
    /// by use, not by time.
    static let auraMoves = 999

    let displayName = "Surefooted (active)"
    let summary = "While the aura holds, the next hole you would fall into is hopped instead."

    func preventsFall(from plane: Plane, at point: GridPoint, context: PassiveContext) -> Bool {
        context.signState.isActive(Self.auraKey)
    }

    func stateAfterPreventingFall(context: PassiveContext) -> SignState? {
        guard context.signState.isActive(Self.auraKey) else { return nil }
        var spent = context.signState
        spent.buffs.removeValue(forKey: Self.auraKey)
        return spent
    }
}

// MARK: - Zodiaction: Surefooted

/// Grants an aura that carries Capricorn over the next hole it would drop into.
///
/// - TODO: **Only the Astra behaviour is implemented.** On Terra the design calls
///   for the goat to keep hopping hole after hole until it reaches solid ground
///   or the board edge — a continuing movement, not a single save.
///   `preventsFall` can only answer "do you fall here"; it cannot propel the
///   piece onward. That needs a hook returning a follow-up path, which is the
///   same requirement as Astral Brook's slide, so the two should share it.
struct CapricornSurefooted: Zodiaction {

    let displayName = "Surefooted"
    let summary = "Astra: hop the next hole you would fall into. Terra: keep hopping to solid ground. (Terra half not yet implemented.)"

    /// - TODO: Capricorn has no charge rule specified. It currently fills only
    ///   from Pentacles.
    func meterGain(from move: MoveSummary, context: PassiveContext) -> Int { 0 }

    func activate(context: PassiveContext, generator: inout SeededRandom) -> [GameEvent] {
        var state = context.signState
        state.startBuff(CapricornSurefootedAura.auraKey, moves: CapricornSurefootedAura.auraMoves)
        return [.signStateChanged(state)]
    }
}
