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

    subscript(point: GridPoint) -> Tile {
        get {
            precondition(contains(point), "GridPoint \(point) is off the board")
            return tiles[index(of: point)]
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
