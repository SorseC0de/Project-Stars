//
//  PickupSpawnRule.swift
//  Project Stars
//
//  Narrowing what the board is allowed to offer, for testing.
//

import Foundation

/// What the hunt is allowed to turn up.
///
/// ## Why this exists
///
/// Testing one Pentacle used to mean playing until it appeared — at two percent
/// that is a long wait for a coin you are trying to look at ten times in a row.
/// The alternative was editing the table, which changes the thing being tested.
///
/// This narrows the *draw* without touching a single authored chance: the odds
/// inside whatever is allowed stay exactly as written, so a filtered run is
/// still a fair sample of the coins it can see.
///
/// Set `PickupSpawnRule.current` and play. It is one line, and it is the only
/// line — see the note on `current`.
enum PickupSpawnRule: Equatable {

    /// The whole catalogue, as authored. What the game ships with.
    case any

    /// Only the coins a sign brings with it — the Gavel, the storm's clouds,
    /// Virgo's pink coin, the Delta Droplet.
    case signSpecific

    /// Only the ordinary ones: whatever is authored at ten percent or better.
    case common

    /// Exactly these, and nothing else.
    case only([PickupID])

    /// **The one line to edit.**
    ///
    /// Debug builds only. In a shipped build this is a `let` bound to `any`, so
    /// a stray write is a compile error rather than a narrowed release.
    #if DEBUG
    nonisolated(unsafe) static var current: PickupSpawnRule = .any//.only([.polarityProngs])
    #else
    static let current: PickupSpawnRule = .any
    #endif

    /// What `effect` is worth in the draw, once the piece has had its say.
    ///
    /// Authored chances, untouched — with one exception. A rule that *names*
    /// what it wants (`only`, and `signSpecific`, which names the coins written
    /// at zero) is asking for coins the ordinary table cannot produce; naming
    /// one is the authorisation. Those are floored at one so they can appear at
    /// all, and keep their authored chance where they have one, so a rule
    /// naming several still draws them in the ratio they were written in.
    func weight(
        of effect: any PickupEffect,
        after weighting: (PickupID, Int) -> Int
    ) -> Int {
        let chance = weighting(effect.id, effect.chance)
        switch self {
        case .any, .common:
            return chance
        case .signSpecific, .only:
            return max(chance, 1)
        }
    }

    /// Whether `id` may be drawn under this rule.
    func allows(_ id: PickupID) -> Bool {
        let effect = PickupCatalog.effect(for: id)

        switch self {
        case .any:
            return true
        case .signSpecific:
            // Authored at zero: it exists, but only a sign can bring it out.
            return effect.chance == 0
        case .common:
            return effect.chance >= GameRules.commonPickupChance
        case let .only(ids):
            return ids.contains(id)
        }
    }
}
