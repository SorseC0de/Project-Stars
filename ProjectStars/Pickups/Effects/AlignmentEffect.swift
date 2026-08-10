//
//  AlignmentEffect.swift
//  Project Stars
//
//  Rare Pentacle: choose your own sign.
//

import Foundation

/// Lets the player choose any sign, including the one they already control.
///
/// The counterpart to `ForcedFateEffect`, and the reason keeping the same sign
/// is an explicit option rather than a wasted pickup: sometimes the right answer
/// really is "stay as I am", and the effect should let you say so rather than
/// punishing you for opening it.
struct AlignmentEffect: PickupEffect {

    let id: PickupID = .alignment
    let rarity: PickupRarity = .rare
    let displayName = "Alignment"
    let summary = "Choose any sign to become — including the one you already are."
    let glyph = "✧"

    /// The player picks, so this effect suspends the move.
    let choice: PickupChoice = .piece

    func plan(
        context: PickupContext,
        choice: PickupChoiceResult?,
        generator: inout SeededRandom
    ) -> [GameEvent] {
        guard case let .piece(chosen) = choice else { return [] }
        guard chosen != context.zodiac else { return [] }
        return [.pieceChanged(to: chosen)]
    }
}
