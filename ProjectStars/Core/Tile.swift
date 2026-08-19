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
/// What is growing over a tile.
///
/// An **overlay**, not a shield. It takes exactly one stage of wear and is gone
/// — so a blow that would deal two still leaves the ground one worse off. That
/// is the whole difference between this and Cancer's Bastion, which negates.
///
/// Terra only: it is ground cover, and Astra is cloud.
///
/// The three cases are one rule and three drawings. Grass and its second
/// variant are dealt 2:1 purely so a field of it does not tile visibly;
/// flowers behave identically and exist because Taurus' Flop and the Bloom
/// should leave something prettier than a lawn behind.
enum GroundCover: String, Hashable, Codable, CaseIterable {
    case grass
    case tuft
    case flowers

    /// How much cover this is: bare ground is nothing, grass is one, flowers
    /// are two.
    ///
    /// The number exists so "did this square get better or worse" can be asked
    /// without a case list at every site that wants to know — the growing
    /// effects play on an increase and stay quiet on a step down.
    static func level(of cover: GroundCover?) -> Int {
        switch cover {
        case .none: 0
        case .grass, .tuft: 1
        case .flowers: 2
        }
    }

    /// What is left after this takes one hit. `nil` is bare ground.
    ///
    /// **Two levels, one drawing each way down.** Flowers step down to grass
    /// and grass steps down to nothing, so a flowered square is two free hits
    /// and a grassed one is a single. Neither absorbs more than one stage at a
    /// time: a blow of three takes flowers to grass to bare and still marks the
    /// ground, which keeps a multi-stage hit legible as a sequence rather than
    /// as arithmetic.
    func worn(at point: GridPoint, seed: Int) -> GroundCover? {
        switch self {
        case .flowers: GroundCover.ordinary(at: point, seed: seed)
        case .grass, .tuft: nil
        }
    }

    /// What water leaves here. Bare ground greens; grass flowers.
    ///
    /// Water does not wear cover away — it feeds it. The Brook and a fish's
    /// wake are the only things in the game that improve the ground they cross,
    /// which is worth the exception because it makes the water signs read as
    /// *nourishing* rather than as another way to break tiles.
    static func watered(_ cover: GroundCover?, at point: GridPoint, seed: Int) -> GroundCover {
        switch cover {
        case .none: GroundCover.ordinary(at: point, seed: seed)
        case .grass, .tuft: .flowers
        case .flowers: .flowers
        }
    }

    /// A patch of ordinary ground cover: two parts grass to one part tuft.
    ///
    /// The mix exists so a field of it does not read as one drawing repeated
    /// forty-nine times. Flowers are never dealt here — they are placed
    /// deliberately by whatever wanted something prettier than a lawn.
    static func ordinary(using generator: inout SeededRandom) -> GroundCover {
        generator.next() % 3 == 0 ? .tuft : .grass
    }

    /// The same 2:1 mix, decided from the square rather than from a generator.
    ///
    /// A wave is planned inside `amend`, which has no RNG to draw on — and
    /// threading one through would mean every passive that reacts to anything
    /// carrying a generator it does not use. Hashing the point gives the same
    /// mix, holds still under a redraw, and varies between waves through
    /// `seed`.
    static func ordinary(at point: GridPoint, seed: Int) -> GroundCover {
        let hashed = (point.x &* 73_856_093) ^ (point.y &* 19_349_663) ^ (seed &* 83_492_791)
        return abs(hashed) % 3 == 0 ? .tuft : .grass
    }
}

struct Tile: Hashable, Codable {

    var kind: TileKind = .normal
    var health: TileHealth = .healthy

    /// Whether anything can grow here at all.
    ///
    /// A hole has no ground to grow on. Asked wherever cover is planted, and
    /// enforced when health changes — see `Tile.settled()`.
    var canHoldCover: Bool { !health.isHole && kind == .normal }

    /// This tile with anything impossible about it removed.
    ///
    /// One rule today: **cover cannot sit over a hole**. A blow of two steps the
    /// flowers down to grass *and* breaks the ground under them, which left a
    /// hole with a lawn drawn across it that you could walk onto and fall
    /// through. Applied at the point health changes rather than at each thing
    /// that changes it, so no future source can reintroduce it.
    func settled() -> Tile {
        guard !canHoldCover, cover != nil else { return self }
        var fixed = self
        fixed.cover = nil
        return fixed
    }

    /// What is growing here, if anything. See `GroundCover`.
    ///
    /// On the tile rather than in a set beside the board, so it cannot drift
    /// out of step with the ground it is covering: a tile that is copied,
    /// healed, broken or serialised carries its cover with it by construction.
    var cover: GroundCover? = nil

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

    /// **No square at all.**
    ///
    /// What reading off the board gives back. A chasm because that is already
    /// the game's word for *there is nothing here to stand on* — so every rule
    /// written against a tile answers correctly for the rim without being told
    /// about it: nothing can be worn, mended, sparkled on, or stood upon.
    static let nowhere = Tile(kind: .chasm, health: .healthy)
}
