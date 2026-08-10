//
//  GridPoint.swift
//  Project Stars
//
//  Board coordinates and the offsets used to describe movement.
//

import Foundation

// MARK: - GridPoint

/// A square on the 7x7 board.
///
/// The coordinate system is **screen-space**: `(0, 0)` is the top-left square,
/// `x` grows to the right, `y` grows *downward*. Keeping y-down means view code
/// never has to flip anything when positioning sprites.
struct GridPoint: Hashable, Codable, CustomStringConvertible {
    var x: Int
    var y: Int

    init(_ x: Int, _ y: Int) {
        self.x = x
        self.y = y
    }

    /// True when this point lies inside a board of `size` x `size` squares.
    func isInBounds(size: Int = GameRules.gridSize) -> Bool {
        (0..<size).contains(x) && (0..<size).contains(y)
    }

    /// This point shifted by `offset`. Does not bounds-check.
    func offset(by offset: GridOffset) -> GridPoint {
        GridPoint(x + offset.dx, y + offset.dy)
    }

    /// The eight squares around this one, optionally including it.
    ///
    /// Not bounds-checked — callers filter against the board, because "the 3x3
    /// around you" legitimately runs off the edge near a wall.
    func surrounding(includingSelf: Bool = false) -> [GridPoint] {
        var points: [GridPoint] = []
        for dy in -1...1 {
            for dx in -1...1 {
                if dx == 0, dy == 0, !includingSelf { continue }
                points.append(GridPoint(x + dx, y + dy))
            }
        }
        return points
    }

    /// The eight squares touching this one, optionally including itself.
    ///
    /// Does not bounds-check — callers filter against the board they care about.
    /// The 3x3 shape several abilities work over (Taurus' Heavy Flop, Astral
    /// Blaze and Blossom) is `neighbourhood(includingSelf: true)`.
    /// Every square from here to `end` inclusive, in order.
    ///
    /// Straight lines and diagonals only — one step per square, taken along both
    /// axes at once where they differ. Anything else returns just the two ends,
    /// since there is no single path between them to name.
    func line(to end: GridPoint) -> [GridPoint] {
        let dx = end.x - x, dy = end.y - y
        let steps = Swift.max(abs(dx), abs(dy))
        guard steps > 0 else { return [self] }
        guard dx == 0 || dy == 0 || abs(dx) == abs(dy) else { return [self, end] }

        return (0...steps).map {
            GridPoint(x + dx.signum() * $0, y + dy.signum() * $0)
        }
    }

    func neighbourhood(includingSelf: Bool = false) -> [GridPoint] {
        var points: [GridPoint] = []
        for dy in -1...1 {
            for dx in -1...1 {
                if dx == 0 && dy == 0 && !includingSelf { continue }
                points.append(GridPoint(x + dx, y + dy))
            }
        }
        return points
    }

    /// True when the two squares touch, diagonals included, excluding identity.
    func isAdjacent(to other: GridPoint) -> Bool {
        guard self != other else { return false }
        return abs(x - other.x) <= 1 && abs(y - other.y) <= 1
    }

    /// Manhattan (taxicab) distance — the natural metric for cardinal movement.
    func manhattanDistance(to other: GridPoint) -> Int {
        abs(x - other.x) + abs(y - other.y)
    }

    var description: String { "(\(x), \(y))" }

    /// Every square on a `size` x `size` board, in reading order.
    static func allPoints(size: Int = GameRules.gridSize) -> [GridPoint] {
        (0..<size).flatMap { y in (0..<size).map { x in GridPoint(x, y) } }
    }
}

// MARK: - GridOffset

/// A relative step on the board — the building block of every movement pattern.
///
/// A zodiac's movement is just a list of these. Today every sign uses the four
/// cardinal steps, but knight-style, diagonal, and long-range patterns all fall
/// out of the same type without any engine changes.
struct GridOffset: Hashable, Codable, CustomStringConvertible {
    var dx: Int
    var dy: Int

    init(_ dx: Int, _ dy: Int) {
        self.dx = dx
        self.dy = dy
    }

    var description: String { "(\(dx), \(dy))" }

    /// How far this offset travels, used to prefer short hops over long ones
    /// when several offsets point the same way.
    var magnitude: Int { abs(dx) + abs(dy) }

    // MARK: Common offsets

    static let up = GridOffset(0, -1)
    static let down = GridOffset(0, 1)
    static let left = GridOffset(-1, 0)
    static let right = GridOffset(1, 0)

    /// The four orthogonal single steps.
    static let cardinals: [GridOffset] = [.up, .down, .left, .right]

    /// The four single steps on the diagonals.
    static let diagonals: [GridOffset] = [
        GridOffset(-1, -1), GridOffset(1, -1),
        GridOffset(-1, 1), GridOffset(1, 1),
    ]

    /// The eight classic knight offsets, kept here for the signs that will
    /// eventually use them.
    static let knight: [GridOffset] = [
        GridOffset(1, -2), GridOffset(2, -1),
        GridOffset(2, 1), GridOffset(1, 2),
        GridOffset(-1, 2), GridOffset(-2, 1),
        GridOffset(-2, -1), GridOffset(-1, -2),
    ]
}
