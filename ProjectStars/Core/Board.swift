//
//  Board.swift
//  Project Stars
//
//  One plane's worth of tiles.
//

import Foundation

/// A square grid of tiles representing a single plane.
///
/// Stored as a flat array in reading order (row 0 left-to-right, then row 1…).
/// Subscript by `GridPoint` rather than indexing directly.
struct Board: Codable, Equatable {
    /// Edge length in tiles. Always `GameRules.gridSize` in normal play; kept as
    /// a stored property so tests and future modes can use other sizes.
    let size: Int

    private var tiles: [Tile]

    /// A fresh board with every tile normal and healthy.
    ///
    /// The Nexys and its chasm are *not* placed here — `GameEngine` owns which
    /// plane the island is on and stamps it in, because that is a property of
    /// the pair of boards rather than of either one alone.
    init(size: Int = GameRules.gridSize) {
        self.size = size
        self.tiles = Array(repeating: Tile(), count: size * size)
    }

    // MARK: - Access

    /// The tile at `point`, or `nil` when there is no square there.
    ///
    /// The board's rim is a real place for one sign — see
    /// `ZodiacPassive.mayLeaveTheBoard` — so "where is the piece standing" now
    /// has an answer that is off the board, and every reader of it has to cope.
    /// A trapping subscript was right while that could not happen and is a crash
    /// waiting to be found now.
    func tile(at point: GridPoint) -> Tile? {
        contains(point) ? tiles[index(of: point)] : nil
    }

    /// The tile at `point` — or `Tile.nowhere` if there is no square there.
    ///
    /// ## Why reading off the board is no longer a programmer error
    ///
    /// It was, for as long as nothing could be outside the board. Aquarius
    /// above zero can, for the instant between being carried past the rim and
    /// the run ending, and during that instant *everything* asks what he is
    /// standing on: the view for a hover bob, the session for a surface bounce,
    /// the engine for wear. Each of those trapped, and patching them one at a
    /// time found three before this.
    ///
    /// So the question has an answer now, and it is the honest one — there is
    /// nothing there. `Tile.nowhere` is a chasm, so every rule written against
    /// a tile already handles it: not solid, not worn, not mended, not
    /// sparkled on.
    ///
    /// **Writing** off the board is still a programmer error and still traps.
    /// Asking about a square that does not exist is reasonable; changing one is
    /// not.
    subscript(point: GridPoint) -> Tile {
        get {
            contains(point) ? tiles[index(of: point)] : .nowhere
        }
        set {
            precondition(contains(point), "GridPoint \(point) is off the board")
            tiles[index(of: point)] = newValue
        }
    }

    /// Bounds check against *this* board's size.
    func contains(_ point: GridPoint) -> Bool {
        point.isInBounds(size: size)
    }

    /// Every square, in reading order.
    var allPoints: [GridPoint] { GridPoint.allPoints(size: size) }

    private func index(of point: GridPoint) -> Int {
        point.y * size + point.x
    }

    // MARK: - Queries

    /// True for a square exactly one step outside the board.
    ///
    /// The ring, and only the ring: two out is nowhere at all. What makes it a
    /// place rather than an error is that something can stand there for the
    /// instant it takes to fall — see `ZodiacPassive.mayLeaveTheBoard`.
    func isJustOutside(_ point: GridPoint) -> Bool {
        guard !contains(point) else { return false }
        return point.x >= -1 && point.x <= size
            && point.y >= -1 && point.y <= size
    }

    /// Points whose tile satisfies `predicate`.
    func points(where predicate: (Tile) -> Bool) -> [GridPoint] {
        allPoints.filter { predicate(self[$0]) }
    }

    /// Points a repair effect could improve. Excludes the Nexys and its chasm,
    /// which are structural and must never be patched.
    var repairablePoints: [GridPoint] {
        points(where: \.canBeRepaired)
    }

    /// Points a sparkle may appear on.
    var sparkleHostPoints: [GridPoint] {
        points(where: \.canHostSparkle)
    }

    /// Points a piece can currently stand on.
    var solidPoints: [GridPoint] {
        points(where: \.isSolid)
    }

    /// Squares a piece would fall through, counting both worn-out tiles and the
    /// Nexys chasm.
    var openPointCount: Int {
        points { !$0.isSolid }.count
    }

    // MARK: - Mutation

    /// Wears one tile. Returns `true` if the tile's state changed.
    @discardableResult
    mutating func damageTile(at point: GridPoint) -> Bool {
        self[point].damage()
    }

    /// Repairs one tile. Returns `true` if the tile's state changed.
    @discardableResult
    mutating func healTile(at point: GridPoint) -> Bool {
        self[point].heal()
    }
}

// MARK: - GroundWave

/// Something crossing the board outward from a square, changing what it passes
/// over.
///
/// One description for every sweep in the game. Taurus greening Terra on
/// arrival, Polaris waking the ground, the Wipeout's ring of holes — they
/// differ only in *which* tiles they touch and *what* they leave behind, so
/// those are the closures and everything else is shared.
///
/// **Health and cover in the same pass.** A wave that both mends the ground and
/// plants something on it walks each tile once, which is the difference between
/// one rule and two that have to agree about which tiles were in range.
///
/// It plans from a board rather than from the engine, so a passive holding only
/// a `PassiveContext` can raise one — which is how Taurus' arrival works.
struct GroundWave {

    /// Where it starts. Ring zero is this square alone.
    let origin: GridPoint
    let plane: Plane

    /// Whether the wave affects this tile at all.
    var touches: (Tile, GridPoint) -> Bool = { _, _ in true }

    /// What the ground becomes, or `nil` to leave it as it is.
    var health: (Tile, GridPoint) -> TileHealth? = { _, _ in nil }

    /// What is left growing, or `nil` to leave that alone too.
    var cover: (Tile, GridPoint) -> GroundCover? = { _, _ in nil }

    /// The wave as events, ring by ring from `origin` outward.
    ///
    /// Rings are **Manhattan** distance — a diamond rather than a square —
    /// because that is how the board is walked, so a wave spreading a square at
    /// a time reads as something travelling along the ground rather than as a
    /// box being drawn.
    func plan(on board: Board) -> [GameEvent] {
        var rings: [Int: [GridPoint]] = [:]
        for point in board.allPoints {
            let distance = abs(point.x - origin.x) + abs(point.y - origin.y)
            rings[distance, default: []].append(point)
        }

        var events: [GameEvent] = [.groundWaveBegan(plane: plane, origin: origin)]

        for distance in rings.keys.sorted() {
            var changedHealth: [GridPoint: TileHealth] = [:]
            var changedCover: [GridPoint: GroundCover?] = [:]

            for point in rings[distance, default: []] {
                let tile = board[point]
                guard touches(tile, point) else { continue }

                if let value = health(tile, point), value != tile.health {
                    changedHealth[point] = value
                }
                if let value = cover(tile, point), value != tile.cover {
                    changedCover[point] = value
                }
            }

            guard !changedHealth.isEmpty || !changedCover.isEmpty else { continue }
            events.append(
                .groundSwept(plane: plane, health: changedHealth, cover: changedCover)
            )
        }

        return events
    }
}

// MARK: - Wearing a tile down

extension Board {

    /// The events for dealing `stages` of damage at `point` — **cover first**.
    ///
    /// The one place that answers "what happens when something damages this
    /// square", so every source gets the same answer: a landing, a Tremor, a
    /// Blaze, a phantom's footfall. Cover used to be checked inside the wear
    /// that moves cause, which meant anything that damaged the ground *without*
    /// a piece standing on it — a coin going off across the board — cracked
    /// straight through the grass it should have burnt off first.
    ///
    /// Cover takes exactly one stage and disperses. It does not negate: two
    /// stages strip the grass and still mark the ground underneath.
    ///
    /// `burningCover` is fire, which takes the cover **and** deals its damage
    /// in full — see `WearCause.burnsCover`.
    ///
    /// Returns both events when both apply, so a caller physically cannot take
    /// the health change and forget the cover.
    /// What damaging a square would do to it, without saying it in events.
    ///
    /// The same rules as `wearEvents` — cover first, water past it, fire
    /// through it — for callers that hit **several squares at once** and must
    /// land them as one event. The Blaze burns nine tiles in one flash, and
    /// emitting them one at a time made the ring arrive in sequence purely
    /// because grass was involved, which is exactly the kind of inconsistency
    /// that shows up as "why does this coin behave differently on Tuesdays".
    func wearOutcome(
        at point: GridPoint,
        stages: Int = 1,
        cause: WearCause = .landing,
        seed: Int = 0
    ) -> WearOutcome {
        guard contains(point), stages > 0 else { return WearOutcome() }

        let tile = self[point]
        var outcome = WearOutcome()
        var remaining = stages

        if cause.sparesCover {
            // Water feeds what it runs over. The ground below still takes what
            // the effect deals — this is about the cover, not about mercy.
            let fed = GroundCover.watered(tile.cover, at: point, seed: seed)
            if fed != tile.cover { outcome.cover = .became(fed) }
        } else if let cover = tile.cover {
            if cause.burnsCover {
                // Fire goes through **both** levels and still deals in full:
                // flowers, grass and the ground underneath all answer to it.
                outcome.cover = .became(nil)
            } else {
                outcome.cover = .became(cover.worn(at: point, seed: seed))
                outcome.absorbed = true
                remaining -= 1
            }
        }

        guard remaining > 0, tile.canBeWorn else { return outcome }

        let health = tile.health.worn(by: remaining)
        if health != tile.health { outcome.health = health }

        // The ground it was growing on has gone: so has the cover, whatever the
        // step-down said a moment ago. `Tile.settled()` enforces this on the
        // board itself; saying it here keeps the *events* honest so the view
        // never draws a meadow over a hole even for a frame.
        if health.isHole { outcome.cover = .became(nil) }
        return outcome
    }

    func wearEvents(
        at point: GridPoint,
        on plane: Plane,
        stages: Int = 1,
        cause: WearCause = .landing,
        seed: Int = 0
    ) -> [GameEvent] {
        guard contains(point), stages > 0 else { return [] }

        let tile = self[point]
        var events: [GameEvent] = []
        var remaining = stages

        // Water runs straight past: it damages the ground and leaves what is
        // growing on it standing. See `WearCause.sparesCover`.
        let outcome = wearOutcome(at: point, stages: stages, cause: cause, seed: seed)

        if case let .became(cover) = outcome.cover {
            events.append(
                .tileCoverChanged(
                    plane: plane, point: point, to: cover, burnt: cause.singesCover
                )
            )
        }
        if outcome.absorbed { remaining -= 1 }

        guard remaining > 0, tile.canBeWorn else { return events }

        let health = tile.health.worn(by: remaining)
        guard health != tile.health else { return events }

        events.append(.tileDamaged(plane: plane, point: point, to: health))
        return events
    }
}


/// What damaging a square would do to it.
///
/// A little type rather than a tuple of optionals, because "the cover did not
/// change" and "the cover became nothing" are different answers and a plain
/// `GroundCover?` cannot tell them apart.
struct WearOutcome {
    enum CoverChange: Equatable {
        case unchanged
        case became(GroundCover?)
    }

    var health: TileHealth?
    var cover: CoverChange = .unchanged

    /// Whether cover **took a stage** of this blow.
    ///
    /// Separate from `cover` moving at all, and the distinction is not
    /// academic: cover is also reported as going when the ground under it
    /// breaks, and when water plants some. Callers that subtract a stage for
    /// being absorbed must ask this — reading it off `cover` instead meant
    /// every blow that would open a hole had its final stage eaten by a piece
    /// of grass that was not there, and nothing in the game could break a tile.
    var absorbed = false

    /// True when the cover moved at all — planted, stepped down or burnt off.
    var coverChanged: Bool { cover != .unchanged }
}
