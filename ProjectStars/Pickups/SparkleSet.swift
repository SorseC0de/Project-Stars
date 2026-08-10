//
//  SparkleSet.swift
//  Project Stars
//
//  The candidate tiles a pickup will appear on, and how they are chosen.
//

import Foundation

/// The set of sparkling tiles currently on the board.
///
/// At most one set exists at a time, and it lives only until the player's next
/// move: committing a move ends the sparkle phase, spawning the pickup on one
/// of these tiles and clearing the rest.
///
/// The set is bound to a specific plane, because sparkles on Astra are
/// meaningless once the piece has dropped to Terra.
struct SparkleSet: Equatable, Codable {
    /// Which plane the sparkles are on.
    let plane: Plane

    /// The shape that produced them.
    let pattern: SparklePattern

    /// The sparkling tiles, in no particular order.
    ///
    /// May contain **fewer** than `GameRules.sparkleCount` points: a shaped
    /// pattern overlapping a hole or the Nexys simply loses that member rather
    /// than moving elsewhere.
    let points: [GridPoint]

    func contains(_ point: GridPoint) -> Bool {
        points.contains(point)
    }

    /// True when the shape lost members to holes or the Nexys. The gaps are
    /// information the player can read — and, with care, engineer.
    var isPartial: Bool {
        pattern != .scattered && points.count < GameRules.sparkleCount
    }
}

// MARK: - Generation

extension SparkleSet {

    /// Rolls a new sparkle set on `plane`.
    ///
    /// Sparkles may only sit on ordinary, unbroken tiles — `Tile.canHostSparkle`
    /// rules out holes, the Nexys island, and the Nexys chasm. That constraint
    /// is what makes the shapes informative:
    ///
    /// - A **shaped** pattern (`+` or `×`) still forms wherever it is placed,
    ///   but any member landing on an illegal tile is simply absent. A `+` with
    ///   a missing arm tells the player exactly where the board is broken.
    /// - A **scattered** set takes up to five legal tiles from anywhere.
    ///
    /// A shaped placement is only accepted if at least
    /// `GameRules.minimumSparklePoints` members survive, so a `+` never decays
    /// into something unreadable. If no placement clears that bar the roll falls
    /// back to scattered.
    ///
    /// - Returns: `nil` only when the board has no legal tile at all.
    static func spawn(
        on plane: Plane,
        board: Board,
        avoiding piecePoint: GridPoint?,
        using generator: inout SeededRandom
    ) -> SparkleSet? {

        let hosts = legalPoints(board: board, piecePoint: piecePoint)
        guard !hosts.isEmpty else { return nil }
        let hostSet = Set(hosts)

        // Roll a shape. A shaped roll that cannot be placed falls back to
        // scattered rather than re-rolling, so the weights stay honest.
        let pattern = generator.pick(weighted: SparklePattern.weightedChoices) ?? .scattered

        if let offsets = pattern.offsetsFromCentre {
            if let points = placeShape(
                offsets: offsets,
                board: board,
                hostSet: hostSet,
                using: &generator
            ) {
                return SparkleSet(plane: plane, pattern: pattern, points: points)
            }
        }

        // Scattered: up to five legal tiles from anywhere on the board.
        let scattered = Array(hosts.shuffled(using: &generator).prefix(GameRules.sparkleCount))
        return SparkleSet(plane: plane, pattern: .scattered, points: scattered)
    }

    /// Tiles a sparkle is allowed to sit on.
    private static func legalPoints(board: Board, piecePoint: GridPoint?) -> [GridPoint] {
        board.sparkleHostPoints.filter { point in
            !(GameRules.sparklesAvoidPiece && point == piecePoint)
        }
    }

    /// Places a shaped pattern, keeping only the members that land legally.
    ///
    /// Every centre on the board is considered, including centres that are
    /// themselves illegal — a `+` centred on a hole still shows its four arms,
    /// which is exactly the "shape forms as best it can" behaviour.
    private static func placeShape(
        offsets: [GridOffset],
        board: Board,
        hostSet: Set<GridPoint>,
        using generator: inout SeededRandom
    ) -> [GridPoint]? {

        let placements = board.allPoints.compactMap { centre -> [GridPoint]? in
            let members = offsets
                .map { centre.offset(by: $0) }
                .filter { board.contains($0) && hostSet.contains($0) }

            return members.count >= GameRules.minimumSparklePoints ? members : nil
        }

        return placements.randomElement(using: &generator)
    }
}
