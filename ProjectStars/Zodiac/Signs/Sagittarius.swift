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
            SagittariusFortunateFind(),
            SagittariusVulcanVault(),
            SagittariusLuckyLanding(),
        ],
        zodiaction: SagittariusAstralArrow(),
        constellation: ZodiacCatalog.sagittariusConstellation
    )

    /// ♐ Sagittarius: the Teapot, with the bow drawn across it.
    static let sagittariusConstellation = Constellation(
        stars: [
            Constellation.Star(-0.95, -0.55,  0.20, 0.9),
            Constellation.Star(-0.70,  0.30,  0.10, 1.0),
            Constellation.Star( 0.00,  0.75,  0.00, 1.2),
            Constellation.Star( 0.70,  0.30, -0.15, 1.0),
            Constellation.Star( 0.95, -0.55, -0.20, 0.9),
            Constellation.Star( 0.00, -0.85,  0.00, 0.8),
            Constellation.Star( 1.15,  0.85, -0.30, 0.7),
        ],
        lines: [(0, 1), (1, 2), (2, 3), (3, 4), (4, 5), (5, 0), (3, 6)]
    )
}

// MARK: - Passive 1: Fortunate Find

/// Three pips when the sparkle you were already walking onto turns out to be the
/// one hiding the Pentacle.
///
/// Pure luck by design — it pays for guessing right, not for playing well, which
/// is exactly the archer's character. Note this is narrower than "opened a
/// Pentacle": it only fires when the coin revealed itself on the very move that
/// took it, which `MoveSummary.collectedOnRevealTile` isolates.
struct SagittariusFortunateFind: ZodiacPassive {

    let displayName = "Fortunate Find"
    let summary = "Astra & Terra: a sparkle phase sometimes reveals a second Pentacle as well — take either, and the other shatters."

    func secondPickupChance(context: PassiveContext) -> Double {
        switch context.plane {
        case .astra: GameRules.secondPickupChanceAstra
        case .terra: GameRules.secondPickupChanceTerra
        }
    }
}

// MARK: - Passive 2: Variable Voyager

/// A small chance that a badly cracked tile refuses to break — and on Terra, that
/// it mends a stage instead.
///
/// Rolls against `context.luck`, drawn once per move by the engine, so the hook
/// stays a pure function and a seeded run stays reproducible.
struct SagittariusVulcanVault: ZodiacPassive {

    /// Chance of triggering, in `0..<1`.
    ///
    /// - TODO: Untuned. "Very small" in the design; start low and raise it.
    static let chance = 0.12

    /// Key this sign owns in `SignState.cooldowns`.
    static let strideKey = "sagittarius.stride"

    /// Set for the duration of a vault, so the wear lands on the launch square.
    static let vaultingKey = "sagittarius.vaulting"

    let displayName = "Vulcan Vault"
    let summary = "Astra & Terra: leap two squares in any direction, wearing the tile you push off from. Not twice in a row, and a landing sometimes spares a badly cracked tile."

    /// The archer draws before it looses.
    ///
    /// Both long forward moves are leaps now, which is a real buff: the archer
    /// crosses its own line without wearing it. This is the price. A sign that
    /// could leap forward every single turn simply moves at twice everyone
    /// else's speed in the direction it cares about, and the whole tension of
    /// this game is that ground is spent by crossing it — a piece that never
    /// touches down is a piece playing a different game.
    ///
    /// One turn is enough. It does not stop the archer going far; it stops the
    /// archer going far *without ever stopping*.
    func allows(
        _ option: MovementPattern.MoveOption,
        direction: SwipeDirection,
        path: [GridPoint],
        context: PassiveContext
    ) -> Bool {
        guard option.distance > 1 else { return true }
        return context.signState.isReady(Self.strideKey)
    }

    /// Charged only when a long move was actually taken — see
    /// `ZodiacPassive.stateAfterMove(option:direction:context:)`.
    func stateAfterMove(
        option: MovementPattern.MoveOption,
        direction: SwipeDirection,
        context: PassiveContext
    ) -> SignState? {
        guard option.distance > 1 else { return nil }
        var state = context.signState
        // Marks the move as a vault while it resolves, which is what moves the
        // wear to the square being pushed off. One move long: it is a property
        // of this leap, not a stance.
        state.startBuff(Self.vaultingKey, moves: 1)
        // Two, because timers tick down at the end of the move that set them:
        // one would be spent before the next move is even offered.
        state.startCooldown(Self.strideKey, moves: 2)
        return state
    }

    /// The vault charges the tile it pushes off from.
    ///
    /// A leap that costs nothing is free distance, and free distance in a game
    /// about spending ground is not a move, it is an exemption. Charging the
    /// launch square rather than the landing keeps the *shape* of the ability —
    /// you still cross two squares without touching the one between — while
    /// making it cost exactly what a step costs. Which is also how it reads:
    /// something has to be pushed against, hard, to go that far.
    func wearTiming(context: PassiveContext) -> WearTiming {
        context.signState.isActive(Self.vaultingKey) ? .onExit : .onEntry
    }

    /// The luck now applies to **landing**, not to standing.
    ///
    /// It used to fire wherever the archer happened to be taking damage, which
    /// made it a passive about wear in general and left the vault filed under a
    /// rule it had nothing to do with. Tied to arrivals it says something about
    /// the sign: this is a piece that throws itself across the board and
    /// sometimes gets away with the landing.
    func modifyWear(_ proposal: WearProposal, context: PassiveContext) -> WearProposal {
        guard !proposal.arrivedByFalling,
              proposal.cause == .landing,
              proposal.tile.health == .badlyCracked,
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
    /// - TODO: Untuned, as with Variable Voyager.
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

// MARK: - Zodiaction: Astral Arrow

/// Fires an arrow into the sky; it comes down on a random
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
struct SagittariusAstralArrow: Zodiaction {

    let displayName = "Astral Arrow"
    let summary = "Fire an arrow to a random square, then pop again — free — to warp to it. No charge accrues while it is out."

    /// The archer's charge comes from the passives.
    func meterGain(from move: MoveSummary, context: PassiveContext) -> Int { 0 }

    /// Recalling costs nothing: the shot was paid for when it was fired.
    func ignoresMeter(context: PassiveContext) -> Bool {
        context.signState.arrow != nil
    }

    func activate(context: PassiveContext, generator: inout SeededRandom) -> [GameEvent] {
        if let arrow = context.signState.arrow { return recall(arrow, context: context) }
        return fire(context: context, generator: &generator)
    }

    // MARK: Firing

    /// Picks a square, sends the arrow up and over, and sees what it finds.
    private func fire(
        context: PassiveContext,
        generator: inout SeededRandom
    ) -> [GameEvent] {
        // Anywhere but where the archer is standing. The island is fair game —
        // an arrow in the Nexys is a promise to come home.
        let candidates = context.currentBoard.allPoints.filter { $0 != context.piecePoint }
        guard let target = candidates.randomElement(using: &generator) else { return [] }

        let plane = context.plane
        let tile = context.currentBoard[target]

        // The centre of Terra with the island overhead: the arrow catches it on
        // the way down and brings it with it, which is the same journey the
        // Nexys Pentacle sends it on.
        if plane == .terra,
           target == GameRules.nexysPoint,
           context.nexysPlane == .astra {
            return [
                .nexysMoved(to: .terra, carryingPiece: false),
                .arrowPlanted(plane: plane, point: target),
            ]
        }

        // Fired from Terra the arrow has gone up over Astra to get here, and it
        // brings a cloud down with it. That the cloud is *torn out* of Astra is
        // presentation only — Astra mends itself on every descent, so holing it
        // here would be undone before the player could ever act on it.
        let broughtCloud = plane == .terra

        // Open ground is not ground: the shot is lost. On Terra it is lost
        // *through* the floor, and the cloud that came with it gives up its
        // energy on the way down — which is worth more than the shaft alone.
        guard tile.isSolid else {
            let amount = broughtCloud
                ? GameRules.arrowCloudRefund
                : GameRules.arrowHoleRefund
            return [refund(amount, context: context)].compactMap { $0 }
        }

        var events: [GameEvent] = []

        // Landing on ground, the cloud spends itself mending what it lands on.
        if broughtCloud, tile.health != .healthy {
            events.append(.tileHealed(plane: .terra, point: target, to: .healthy))
        }

        // Planted last, so the square it pins is the square as the cloud left
        // it — an arrow freezes what is under it, and that should be the mended
        // tile rather than the broken one.
        events.append(.arrowPlanted(plane: plane, point: target))
        return events
    }

    /// A little of the shot back when it finds nothing to stick in.
    private func refund(_ amount: Int, context: PassiveContext) -> GameEvent? {
        let target = min(context.zodiactionMeter + amount, context.zodiac.zodiaction.meterMax)
        guard target != context.zodiactionMeter else { return nil }
        return .zodiactionMeterChanged(to: target)
    }

    // MARK: Recalling

    /// The second pop: step out of the world and back in where the arrow is.
    private func recall(
        _ arrow: SignState.Arrow,
        context: PassiveContext
    ) -> [GameEvent] {
        [
            .arrowCleared,
            .pieceTeleported(
                from: context.piecePoint,
                to: arrow.point,
                fromPlane: context.plane,
                toPlane: arrow.plane
            ),
        ]
    }
}
