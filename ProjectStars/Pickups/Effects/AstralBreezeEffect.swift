//
//  AstralBreezeEffect.swift
//  Project Stars
//
//  Uncommon Pentacle — Astral Essence (Air).
//

import Foundation

/// Teleports the piece to any square on the current plane, chosen by the player.
///
/// The air essence: it *goes anywhere*. No restrictions at all — holes, the
/// Nexys, the chasm are all legal destinations, which makes this both the most
/// flexible escape in the game and a way to deliberately drop yourself to Terra
/// on your own terms.
///
/// Arriving is landing, so the destination is worn and every landing check runs:
/// pick a hole and you fall through it, pick the Terra Nexys and you ride it up.
struct AstralBreezeEffect: PickupEffect {

    let id: PickupID = .astralBreeze
    let rarity: PickupRarity = .uncommon
    let displayName = "Astral Breeze"
    let summary = "Teleport to any square on this plane — holes and the Nexys included."
    let glyph = "❁"

    /// The player picks the destination, so this effect suspends the move.
    let element: ZodiacElement? = .air
    let choice: PickupChoice = .tile

    func plan(
        context: PickupContext,
        choice: PickupChoiceResult?,
        generator: inout SeededRandom
    ) -> [GameEvent] {
        guard case let .tile(destination) = choice,
              context.currentBoard.contains(destination)
        else { return [] }

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
