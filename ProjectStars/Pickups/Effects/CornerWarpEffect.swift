//
//  CornerWarpEffect.swift
//  Project Stars
//
//  Uncommon Pentacle: thrown to a corner, ready or not.
//

import Foundation

/// Teleports the piece to a random corner of the current plane.
///
/// Deliberately indiscriminate — it does not check what is there. A corner that
/// has already broken is a perfectly legal destination and you will drop through
/// it. That gamble is the effect.
struct CornerWarpEffect: PickupEffect {

    let id: PickupID = .cornerWarp
    let rarity: PickupRarity = .uncommon
    let displayName = "Corner Warp"
    let summary = "Teleport to a random corner. It does not care what is waiting there."
    let glyph = "⟀"

    func plan(
        context: PickupContext,
        choice: PickupChoiceResult?,
        generator: inout SeededRandom
    ) -> [GameEvent] {
        let last = context.currentBoard.size - 1
        let corners = [
            GridPoint(0, 0),
            GridPoint(last, 0),
            GridPoint(0, last),
            GridPoint(last, last),
        ]

        guard let destination = corners.randomElement(using: &generator) else { return [] }
        guard destination != context.piecePoint else { return [] }

        return [
            .pieceTeleported(
                from: context.piecePoint,
                to: destination,
                fromPlane: context.plane,
                toPlane: context.plane
            )
        ]
    }
}
