//
//  PolarisEffect.swift
//  Project Stars
//
//  Legendary Pentacle: the north star.
//

import Foundation

/// Polaris — pinned to the north-middle square, and nowhere else.
///
/// The spawn rule is the finished part: `requiredSpawnPoint` keeps it to
/// `(3, 0)`, so it is only ever eligible when a sparkle set happens to cover the
/// top-centre tile, and the reveal is forced there. The catalogue enforces both
/// halves.
///
/// - TODO: **The effect itself is not designed yet** — it was forgotten in the
///   spec. `weight` is `0` so Polaris cannot currently spawn; give it a real
///   `plan` body and raise the weight to put it in rotation. Everything else
///   about it, including the distinct on-board appearance, is already wired.
struct PolarisEffect: PickupEffect {

    let id: PickupID = .polaris
    let rarity: PickupRarity = .legendary
    let displayName = "Polaris"
    let summary = "Effect not yet designed."
    let glyph = "★"

    /// Bright and starlit rather than the anonymous gold coin — a legendary is
    /// rare enough that telegraphing it is the point.
    let appearance: PentacleAppearance = .radiant

    /// Out of rotation until it does something.
    let weight = 0

    /// The north-middle tile. Polaris appears here or not at all.
    let requiredSpawnPoint: GridPoint? = GridPoint(GameRules.gridSize / 2, 0)

    func plan(
        context: PickupContext,
        choice: PickupChoiceResult?,
        generator: inout SeededRandom
    ) -> [GameEvent] {
        []
    }
}
