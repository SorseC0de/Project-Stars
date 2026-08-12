//
//  Tile.swift
//  Project Stars
//
//  A single square of a board.
//

import Foundation

// MARK: - TileKind

/// What sort of square this is, structurally.
///
/// Kind is separate from wear because the two special squares are not "very
/// worn" or "very healthy" — they sit outside the wear cycle entirely and must
/// never be damaged, repaired, or sparkled.
enum TileKind: String, CaseIterable, Codable, Hashable {

    /// An ordinary floor tile. The only kind that wears, repairs, or sparkles.
    case normal

    /// The **Nexys**: the floating island at the centre of the board.
    ///
    /// Always solid, never damaged, never hosts a sparkle. Exists on exactly one
    /// plane at a time — see `GameEngine.nexysPlane`.
    case nexys

    /// The gap the Nexys leaves behind on the plane it is *not* on.
    ///
    /// Reads and behaves as a permanent hole: never solid, never repairable.
    /// Distinct from `.normal` at `.hole` because a healing effect must not be
    /// able to patch it.
    case chasm

    /// A **pool**: standing water Pisces leaves where it comes down.
    ///
    /// Structural like the island, and for the same reason — it is not ground in
    /// a state of repair, it is a different thing sitting where ground was. It
    /// cannot be worn, healed or sparkled, and it pays a pip of charge to
    /// whoever steps into it.
    ///
    /// It is not permanent. Changing plane or changing sign evaporates it, and
    /// so does anything hot enough — see `GameEngine.evaporatePools(...)`.
    case pool
}

// MARK: - Tile

/// One square on one plane.
///
/// Deliberately thin: a tile knows its own kind and wear and nothing else.
/// Sparkles, the pickup, and the piece are tracked separately by `GameEngine`
/// so a tile never has to be kept in sync with them.
struct Tile: Hashable, Codable {

    var kind: TileKind = .normal
    var health: TileHealth = .healthy

    // MARK: Queries

    /// True when a piece can rest here rather than dropping through.
    var isSolid: Bool {
        switch kind {
        case .normal: !health.isHole
        case .nexys: true
        case .chasm: false
        // Shallow enough to stand in. A pool that dropped the piece would be a
        // hole with a colour, and this is meant to be somewhere to go.
        case .pool: true
        }
    }

    /// True when a landing can wear this tile.
    var canBeWorn: Bool {
        kind == .normal && !health.isHole
    }

    /// True when a repair effect can improve this tile.
    var canBeRepaired: Bool {
        kind == .normal && health != .healthy
    }

    /// True when a sparkle may appear here.
    ///
    /// Holes are excluded so the hidden pickup is always reachable; the Nexys
    /// and its chasm are excluded because they are structural.
    var canHostSparkle: Bool {
        kind == .normal && !health.isHole
    }

    // MARK: Mutation

    /// Advances wear by one step. Returns `true` if the state actually changed.
    ///
    /// No-ops on the Nexys and on chasms, which sit outside the wear cycle.
    @discardableResult
    mutating func damage() -> Bool {
        guard canBeWorn else { return false }
        let previous = health
        health = health.damaged
        return health != previous
    }

    /// Repairs one step of wear. Returns `true` if the state actually changed.
    @discardableResult
    mutating func heal() -> Bool {
        guard canBeRepaired else { return false }
        let previous = health
        health = health.healed
        return health != previous
    }

    // MARK: Presets

    /// The Nexys island.
    static let nexys = Tile(kind: .nexys, health: .healthy)

    /// The gap the Nexys leaves on the other plane.
    static let chasm = Tile(kind: .chasm, health: .hole)

    /// Standing water. Healthy because a pool is not damaged ground — it is not
    /// ground at all.
    static let pool = Tile(kind: .pool, health: .healthy)
}
