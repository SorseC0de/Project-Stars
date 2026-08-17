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
