//
//  ForcedFateEffect.swift
//  Project Stars
//
//  Rare Pentacle: the stars decide for you.
//

import Foundation

/// Swaps the piece for a randomly chosen *different* sign.
///
/// One of only two things in the game that changes your sign mid-run, and the
/// one that does not ask. Always a genuine change — it never rolls the sign you
/// already have, because "nothing happened" is not a rare Pentacle.
struct ForcedFateEffect: PickupEffect {

    let id: PickupID = .forcedFate
    let rarity: PickupRarity = .rare
    let displayName = "Forced Fate"
    let summary = "Your sign changes at random. You do not get a say."
    let glyph = "✦"

    func plan(
        context: PickupContext,
        choice: PickupChoiceResult?,
        generator: inout SeededRandom
    ) -> [GameEvent] {
        let others = Zodiac.allCases.filter { $0 != context.zodiac }
        guard let replacement = others.randomElement(using: &generator) else { return [] }
        return [.pieceChanged(to: replacement)]
    }
}
