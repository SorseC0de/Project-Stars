//
//  PentacleCodex.swift
//  Project Stars
//
//  Remembers which Pentacles the player has already had explained to them.
//

import Observation
import SwiftUI

/// Tracks which Pentacle effects the player has seen before.
///
/// Every Pentacle looks the same on the board — a gold coin — so the player only
/// learns what one does by opening it. The **first** time a given effect turns
/// up, the game stops and explains it; after that it is silent.
///
/// Persisted, because "first ever time" means across launches, not per run.
///
/// - TODO: The planned encyclopedia mode reads from exactly this list — it is
///   the set of effects the player is allowed to look up. Building it needs no
///   new storage, only a screen.
@MainActor
@Observable
final class PentacleCodex {

    /// Shared instance. A single store because "have I seen this?" is a property
    /// of the player, not of a run.
    static let shared = PentacleCodex()

    /// Effects the player has had explained.
    private(set) var seen: Set<PickupID>

    private let defaults: UserDefaults
    private let storageKey = "pentacle.seenEffects"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = defaults.stringArray(forKey: storageKey) ?? []
        self.seen = Set(stored.compactMap(PickupID.init(rawValue:)))
    }

    /// True when opening this Pentacle should stop the game and explain itself.
    func needsIntroduction(_ id: PickupID) -> Bool {
        !seen.contains(id)
    }

    /// Records that the player has now been shown `id`.
    func markSeen(_ id: PickupID) {
        guard !seen.contains(id) else { return }
        seen.insert(id)
        persist()
    }

    /// Forgets everything, so every effect introduces itself again.
    ///
    /// This is the "reset all Pentacle prompts" settings action.
    func resetAll() {
        guard !seen.isEmpty else { return }
        seen.removeAll()
        persist()
    }

    private func persist() {
        defaults.set(seen.map(\.rawValue).sorted(), forKey: storageKey)
    }
}
