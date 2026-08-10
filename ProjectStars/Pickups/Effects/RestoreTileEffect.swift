//
//  RestoreTileEffect.swift
//  Project Stars
//
//  Common Pentacle: fully repair one damaged tile.
//

import Foundation

/// Fully repairs one randomly-chosen damaged tile on the plane the piece is on.
///
/// **Fully**, not by one step — a hole goes straight back to healthy. That makes
/// it worth taking on a board that has already broken rather than only on one
/// that is starting to.
///
/// On a plane with nothing left to fix it does not fizzle: it pays out a point
/// of Zodiaction charge instead, so a well-kept board never makes a Pentacle
/// feel wasted.
struct RestoreTileEffect: PickupEffect {

    let id: PickupID = .restoreTile
    let rarity: PickupRarity = .common
    let displayName = "Restore Tile"
    let summary = "Fully repairs one damaged tile here. If none are damaged, gain 1 Zodiaction charge instead."
    let glyph = "✚"

    let weight = 3

    func plan(
        context: PickupContext,
        choice: PickupChoiceResult?,
        generator: inout SeededRandom
    ) -> [GameEvent] {
        // The Nexys and its chasm are structural and never candidates —
        // `repairablePoints` already excludes them.
        let candidates = context.currentBoard.repairablePoints

        guard let target = candidates.randomElement(using: &generator) else {
            let meter = context.meter(afterGaining: GameRules.restoreTileBonusCharge)
            guard meter != context.zodiactionMeter else { return [] }
            return [.zodiactionMeterChanged(to: meter)]
        }

        return [.tileHealed(plane: context.plane, point: target, to: .healthy)]
    }
}
