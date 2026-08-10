//
//  AstralBlazeEffect.swift
//  Project Stars
//
//  Uncommon Pentacle — Astral Essence (Fire).
//

import Foundation

/// Burns the ring of tiles around the piece, paying out Zodiaction charge for
/// the damage.
///
/// The square underfoot is deliberately **not** included. Burning your own tile
/// out from under you was not an interesting risk — it was a way to end the run
/// while standing still, with no decision attached.
///
/// The fire essence: it *destroys, and you profit*. Every tile it wears is worth
/// a point of charge, and every tile it breaks outright is worth two — so it
/// pays best on a board that was already half gone, and turns a collapsing plane
/// into a full meter.
///
/// The square under the piece burns too. Fire does not spare its caster.
struct AstralBlazeEffect: PickupEffect {

    let id: PickupID = .astralBlaze
    let rarity: PickupRarity = .uncommon
    let displayName = "Astral Blaze"
    let summary = "The ring of tiles around you loses one stage. Gain 1 charge per tile damaged, 2 per tile broken."
    let glyph = "✷"
    let element: ZodiacElement? = .fire

    func plan(
        context: PickupContext,
        choice: PickupChoiceResult?,
        generator: inout SeededRandom
    ) -> [GameEvent] {
        // The blaze goes up all at once, so the whole ring travels as one
        // `tilesChanged` rather than nine separate hits.
        var changes: [GridPoint: TileHealth] = [:]
        var charge = 0

        for point in context.piecePoint.surrounding(includingSelf: false) {
            guard context.currentBoard.contains(point) else { continue }

            let tile = context.currentBoard[point]
            guard tile.canBeWorn else { continue }

            let health = tile.health.damaged
            changes[point] = health

            // Breaking a tile outright is worth double.
            charge += health.isHole
                ? GameRules.astralBlazeChargePerBreak
                : GameRules.astralBlazeChargePerDamage
        }

        var events: [GameEvent] = []
        if !changes.isEmpty {
            events.append(.tilesChanged(plane: context.plane, changes: changes))
        }

        let meter = context.meter(afterGaining: charge)
        if meter != context.zodiactionMeter {
            events.append(.zodiactionMeterChanged(to: meter))
        }

        return events
    }
}
