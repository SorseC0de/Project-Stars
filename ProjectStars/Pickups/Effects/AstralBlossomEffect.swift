//
//  AstralBlossomEffect.swift
//  Project Stars
//
//  Uncommon Pentacle — Astral Essence (Earth).
//

import Foundation

/// Repairs the ring of tiles around the piece by one stage each.
///
/// Matched to Astral Blaze's footprint — the square underfoot is excluded — so
/// the two elemental area effects read as a pair.
///
/// The earth essence: it *mends what can still be mended*. Holes are past
/// saving and are skipped entirely — this shores up a board that is wearing
/// thin, it does not resurrect one that has already collapsed. Compare
/// `RestoreTileEffect`, which fixes one square completely no matter how far gone.
struct AstralBlossomEffect: PickupEffect {

    let id: PickupID = .astralBlossom
    let rarity: PickupRarity = .uncommon
    let displayName = "Astral Blossom"
    let summary = "The ring of tiles around you recovers one stage. Holes are beyond help."
    let glyph = "✽"

    func plan(
        context: PickupContext,
        choice: PickupChoiceResult?,
        generator: inout SeededRandom
    ) -> [GameEvent] {
        // Everything blooms together — one `tilesChanged`, not a ripple.
        var changes: [GridPoint: TileHealth] = [:]

        for point in context.piecePoint.surrounding(includingSelf: false) {
            guard context.currentBoard.contains(point) else { continue }

            let tile = context.currentBoard[point]
            // Holes are past saving: the blossom mends damage, it does not
            // rebuild what has already fallen through.
            guard tile.canBeRepaired, !tile.health.isHole else { continue }

            changes[point] = tile.health.healed
        }

        guard !changes.isEmpty else { return [] }
        return [.tilesChanged(plane: context.plane, changes: changes)]
    }
}
