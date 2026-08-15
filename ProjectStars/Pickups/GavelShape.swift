//
//  GavelShape.swift
//  Project Stars
//
//  The piece of ground Libra's Galeforce Gavel drops onto the board.
//

import Foundation

/// A slab of ground waiting to be placed.
///
/// Six silhouettes, each in every orientation it has. Tetrominoes, more or less,
/// and deliberately so: everybody already knows how to read them, and the whole
/// pleasure of the Gavel is fitting an awkward shape into a gap you have been
/// looking at for three turns.
///
/// ## Why the single square is the commonest
///
/// It is the one that always fits. A shape that cannot be placed anywhere useful
/// is a wasted Pentacle, and on a board that has decayed into scattered holes
/// the single is often the only thing that patches one — so it is the floor the
/// rest of the table stands on. The four-square shapes are rare because when
/// they do fit they are enormous.
enum GavelShape: String, CaseIterable, Codable, Identifiable {

    /// One square.
    case single

    /// Two in a line.
    case line2

    /// Three in a line.
    case line3

    /// A 2x2 block.
    case square

    /// Three squares in an L.
    case elbow3

    /// Four squares in an L.
    case elbow4

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .single: "Single"
        case .line2: "Pair"
        case .line3: "Triple"
        case .square: "Block"
        case .elbow3: "Elbow"
        case .elbow4: "Long Elbow"
        }
    }

    /// How often this shape comes up.
    ///
    /// Single heaviest, then the two straight lines, then the shapes that turn
    /// a corner.
    ///
    /// ## Why the lines sit second
    ///
    /// Because a line is the shape Libra can actually aim. Her trenches land on
    /// the two squares flanking her facing, so the damage she deals is a line
    /// and the ground she wants back is a line — a pair or a triple drops
    /// straight onto the pattern the sign spends every turn making. An elbow or
    /// a block has to be fitted around what happens to be broken, which is a
    /// puzzle about the board rather than about her.
    ///
    /// Both orientations of each line share one weight, since the roll picks a
    /// shape and turns it afterwards.
    var weight: Int {
        switch self {
        case .single: 40
        case .line2: 22
        case .line3: 18
        case .elbow3: 8
        case .square: 7
        case .elbow4: 5
        }
    }

    /// Every orientation of this shape, as offsets from its anchor square.
    ///
    /// The anchor is always `(0, 0)` and is always part of the shape, so the
    /// square under the player's finger is always one that will be filled — a
    /// cursor that could sit on a square the slab does not cover would be
    /// pointing at nothing.
    var orientations: [[GridOffset]] {
        switch self {
        case .single:
            [[GridOffset(0, 0)]]

        case .line2:
            [
                [GridOffset(0, 0), GridOffset(1, 0)],
                [GridOffset(0, 0), GridOffset(0, 1)],
            ]

        case .line3:
            [
                [GridOffset(0, 0), GridOffset(1, 0), GridOffset(2, 0)],
                [GridOffset(0, 0), GridOffset(0, 1), GridOffset(0, 2)],
            ]

        case .square:
            // One orientation: a block turned is the same block.
            [[GridOffset(0, 0), GridOffset(1, 0), GridOffset(0, 1), GridOffset(1, 1)]]

        case .elbow3:
            [
                [GridOffset(0, 0), GridOffset(1, 0), GridOffset(0, 1)],
                [GridOffset(0, 0), GridOffset(1, 0), GridOffset(1, 1)],
                [GridOffset(0, 0), GridOffset(0, 1), GridOffset(1, 1)],
                [GridOffset(1, 0), GridOffset(0, 1), GridOffset(0, 0)],
            ]

        case .elbow4:
            [
                [GridOffset(0, 0), GridOffset(0, 1), GridOffset(0, 2), GridOffset(1, 2)],
                [GridOffset(0, 0), GridOffset(1, 0), GridOffset(2, 0), GridOffset(0, 1)],
                [GridOffset(0, 0), GridOffset(1, 0), GridOffset(1, 1), GridOffset(1, 2)],
                [GridOffset(0, 0), GridOffset(1, 0), GridOffset(2, 0), GridOffset(2, 1)],
            ]
        }
    }

    static var weightedChoices: [(value: GavelShape, weight: Int)] {
        allCases.map { ($0, $0.weight) }
    }
}

// MARK: - GavelSlab

/// One rolled slab: a silhouette, an orientation of it, and the state the ground
/// arrives in.
///
/// ## Why the health is rolled too
///
/// All four states are on the table, holes included. A Gavel that only ever
/// dropped healthy ground would be a repair Pentacle with extra steps, and Libra
/// is not a repair sign — she is a sign that decides *where things are*. Being
/// handed a hole-shaped slab and having to find somewhere it does the least harm
/// is as much the ability as being handed a healthy one.
struct GavelSlab: Equatable, Codable {

    let shape: GavelShape

    /// Which of `shape.orientations` this slab is in.
    let rotation: Int

    /// What the ground arrives as.
    let health: TileHealth

    /// The squares this slab covers when anchored at `point`.
    func squares(anchoredAt point: GridPoint) -> [GridPoint] {
        let offsets = shape.orientations[rotation % shape.orientations.count]
        return offsets.map { point.offset(by: $0) }
    }

    /// Whether this slab may be dropped with its anchor here.
    ///
    /// Refuses a slab that would hang off the board — a partial placement would
    /// let the player buy a big shape and use a corner of it, which makes the
    /// rarity of the big shapes meaningless — and refuses to pave over anything
    /// structural, the island above all.
    func canBePlaced(anchoredAt point: GridPoint, on board: Board) -> Bool {
        let squares = squares(anchoredAt: point)
        guard squares.allSatisfy({ board.contains($0) }) else { return false }
        return squares.allSatisfy { board[$0].kind == .normal }
    }

    /// Rolls a slab.
    static func roll(using generator: inout SeededRandom) -> GavelSlab {
        let shape = generator.pick(weighted: GavelShape.weightedChoices) ?? .single
        let rotation = Int.random(in: 0..<shape.orientations.count, using: &generator)
        let health = TileHealth.allCases.randomElement(using: &generator) ?? .healthy
        return GavelSlab(shape: shape, rotation: rotation, health: health)
    }
}
