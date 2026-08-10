//
//  ZChargeEffect.swift
//  Project Stars
//
//  Common Pentacle: a flat lump of Zodiaction charge.
//

import Foundation

/// Grants a flat amount of Zodiaction charge.
///
/// The plainest effect in the game on purpose: it is the baseline the others are
/// measured against, and the one that makes a Pentacle worth taking even when
/// the board is in good shape.
struct ZChargeEffect: PickupEffect {

    let id: PickupID = .zCharge
    let rarity: PickupRarity = .common
    let displayName = "Z-Charge"
    let summary = "Gain \(GameRules.zChargePentacleAmount) Zodiaction charge."
    let glyph = "⚡"

    /// Commonest thing in the tier.
    let weight = 3

    func plan(
        context: PickupContext,
        choice: PickupChoiceResult?,
        generator: inout SeededRandom
    ) -> [GameEvent] {
        let target = context.meter(afterGaining: GameRules.zChargePentacleAmount)
        guard target != context.zodiactionMeter else { return [] }
        return [.zodiactionMeterChanged(to: target)]
    }
}
