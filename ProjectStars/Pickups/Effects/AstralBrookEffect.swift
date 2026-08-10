//
//  AstralBrookEffect.swift
//  Project Stars
//
//  Uncommon Pentacle — Astral Essence (Water).
//

import Foundation

/// Sweeps the piece along its facing to the far edge of the board, wearing every
/// tile it crosses.
///
/// The water essence: it *flows*. Holes do not stop it — the piece passes
/// straight over them — so the slide only ends at the border. But it is not
/// free: the square it comes to rest on is landed on like any other, so a border
/// tile that is already a hole drops the piece exactly as it would normally.
///
/// This is the one effect that lays down a line of damage across a whole rank or
/// file, which makes it a strong charge-builder for signs that pay out on wear
/// and a serious liability for anyone who needs the board intact.
struct AstralBrookEffect: PickupEffect {

    let id: PickupID = .astralBrook
    let rarity: PickupRarity = .uncommon
    let displayName = "Astral Brook"
    let summary = "Slide to the far edge along your facing, damaging every tile you cross and passing over holes."
    let glyph = "≈"
    let element: ZodiacElement? = .water

    /// The slide applies its own wear square by square, so the engine must not
    /// charge the destination a second time on arrival.
    let arrivalWearsTile = false

    func plan(
        context: PickupContext,
        choice: PickupChoiceResult?,
        generator: inout SeededRandom
    ) -> [GameEvent] {
        // Facing a wall, the water simply flows the other way. Without this the
        // Pentacle is a dud whenever it is opened on a border tile facing out —
        // which is common, since the border is where sliding tends to strand you.
        var heading = context.facing
        if !context.currentBoard.contains(context.piecePoint.offset(by: heading.unitOffset)) {
            heading = context.facing.opposite
        }
        let step = heading.unitOffset

        var events: [GameEvent] = []

        // Turn to face the way the water actually carries you. Without this the
        // piece arrives at the far wall still looking back the way it came, and
        // every facing-dependent thing that follows — the cursor, Libra's flanks,
        // Sagittarius' forward stride — reads the wrong direction.
        if heading != context.facing {
            events.append(.pieceTurned(to: heading))
        }

        var from = context.piecePoint
        var point = from.offset(by: step)

        // Walk to the border. Damage is computed against the board as the effect
        // finds it, tile by tile, because the same square is never crossed twice
        // in a straight line.
        while context.currentBoard.contains(point) {
            events.append(.pieceStepped(from: from, to: point, plane: context.plane))

            let tile = context.currentBoard[point]
            if tile.canBeWorn {
                events.append(
                    .tileDamaged(plane: context.plane, point: point, to: tile.health.damaged)
                )
            }

            from = point
            point = point.offset(by: step)
        }

        return events
    }
}
