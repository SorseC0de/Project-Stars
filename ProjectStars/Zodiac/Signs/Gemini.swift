//
//  Gemini.swift
//  Project Stars
//
//  ♊ Gemini — The Twins
//
//  Everything specific to this sign lives in this file. Gemini is an air
//  sign, so it is stronger on **Astra** and weaker on **Terra**.
//

import SwiftUI

// MARK: - Definition

extension ZodiacCatalog {

    /// ♊ Gemini — The Twins. Air, May 21 – Jun 20. Strong on Astra.
    static let gemini = ZodiacDefinition(
        sign: .gemini,
        displayName: "Gemini",
        glyph: "♊",
        element: .air,
        accentColor: Color(hex: 0xE8_C1_5A),
        movement: .cardinalStep,
        passives: [
            GeminiMirroredHealing(),
            GeminiMirrors(),
            GeminiSplitSoul(),
        ],
        zodiaction: GeminiReflection()
    )
}

// MARK: - Passive 1: Mirrored Healing

/// Every repair made to an Astra tile is echoed onto the Terra tile directly
/// beneath it.
///
/// One-way and one-plane: repairs made *on* Terra do not travel upward. So
/// Gemini banks its Terra board while it is still up in the sky, and the reward
/// for staying on Astra is arriving below to ground someone else would have had
/// to mend by hand.
///
/// Reads the events the move actually produced rather than trying to predict
/// them, so it mirrors repairs from any source — a Pentacle, a landing, a
/// Zodiaction — without needing to know which.
struct GeminiMirroredHealing: ZodiacPassive {

    let displayName = "Mirrored Healing"
    let summary = "Astra: any repair to an Astra tile also repairs the Terra tile beneath it."

    func amend(_ events: [GameEvent], context: PassiveContext) -> [GameEvent] {
        guard let below = context.boardBelow else { return [] }

        // Gather every Astra square this move repaired, from both the single and
        // the batched forms.
        var repaired: [GridPoint: TileHealth] = [:]

        for event in events {
            switch event {
            case let .tileHealed(plane, point, health) where plane == .astra:
                repaired[point] = health

            case let .tilesChanged(plane, changes) where plane == .astra:
                for (point, health) in changes {
                    // A batch carries damage and repair together; only the
                    // improvements mirror.
                    if health < context.currentBoard[point].health || health == .healthy {
                        repaired[point] = health
                    }
                }

            default:
                break
            }
        }

        // Mirror downward, but never past what the Terra tile already is: this
        // heals, it cannot wear.
        var changes: [GridPoint: TileHealth] = [:]
        for (point, health) in repaired {
            guard below.contains(point) else { continue }
            let target = below[point]
            guard target.kind == .normal, target.health > health else { continue }
            changes[point] = health
        }

        guard !changes.isEmpty else { return [] }
        return [.tilesChanged(plane: .terra, changes: changes)]
    }
}

// MARK: - Passive 2: Mirrors

/// Four mirrors hang in the sky beyond the middle of each edge. Stepping out
/// through one puts Gemini at the opposite edge.
///
/// **Astra only.** They are made of the same stuff as the clouds; on Terra there
/// is nothing above the ground to hang them from, and Gemini is bounded by the
/// board like everyone else down there.
///
/// Only those four squares are doorways — every other border tile is still a
/// wall — so the mirrors are a route Gemini has to navigate *to*, not a general
/// immunity to edges. Passing through is a jump, so nothing is crossed on the
/// way and only the arrival square takes wear.
struct GeminiMirrors: ZodiacPassive {

    let displayName = "Mirrors"
    let summary = "Astra: step out through the middle of any edge to reappear at the opposite edge."

    /// The four squares a mirror hangs beyond, and where each one leads.
    ///
    /// Shared with `MirrorsView`, which draws them, so the visual can never drift
    /// from the rule.
    static func portals(size: Int) -> [(edge: SwipeDirection, from: GridPoint, to: GridPoint)] {
        let middle = size / 2
        let last = size - 1
        return [
            (.up, GridPoint(middle, 0), GridPoint(middle, last)),
            (.down, GridPoint(middle, last), GridPoint(middle, 0)),
            (.left, GridPoint(0, middle), GridPoint(last, middle)),
            (.right, GridPoint(last, middle), GridPoint(0, middle)),
        ]
    }

    func wrappedMove(
        from origin: GridPoint,
        direction: SwipeDirection,
        context: PassiveContext
    ) -> [GridPoint]? {
        guard context.plane == .astra else { return nil }

        return Self.portals(size: context.currentBoard.size)
            .first { $0.edge == direction && $0.from == origin }
            .map { [$0.to] }
    }
}

// MARK: - Passive 3: Split Soul

/// Falling from Astra splits Gemini in two: half drops to Terra, half stays
/// above, and the player controls them on alternating turns.
///
/// - TODO: **Not implemented — the largest single gap in the game.** Everything
///   from `Piece` up assumes exactly one controlled piece: one position, one
///   plane, one facing, one cursor, one set of landing checks per move.
///
///   What it needs, in order:
///   1. `GameEngine.piece` becomes a small collection plus an active index, and
///      `apply` routes every piece-affecting event through that index.
///   2. A `.turnPassed` event so alternation is replayable like everything else.
///   3. The board view draws the inactive half dimmed on the other plane.
///   4. Rejoining — both halves on one square — emits full charge.
///
///   Sub-passive **Sibling Soul** rides on the same machinery: when one half
///   falls from Astra straight into a Terra hole, it does not die. The soul
///   rises, is absorbed by the half still on Astra, and grants half a meter.
struct GeminiSplitSoul: ZodiacPassive {
    let displayName = "Split Soul"
    let summary = "Falling from Astra splits you in two, controlled on alternating turns. (Not yet implemented.)"
}

// MARK: - Zodiaction: Reflection

/// *Provisional name.* Stamps the left half of the board onto the right.
///
/// Column by column, the right side becomes whatever the left side is — damage,
/// repair and holes alike. The centre column is the axis and is untouched, and
/// the Nexys and its chasm are structural so they are skipped.
///
/// Identical on both planes, which is deliberate: it is the one Gemini effect
/// that does not care which twin, or which plane, you are on.
struct GeminiReflection: Zodiaction {

    let displayName = "Reflection"
    let summary = "Astra & Terra: the right half of the board becomes a mirror of the left."

    /// - TODO: Gemini's charge is specified to come from rejoining the two
    ///   halves of Split Soul, which does not exist yet. Until it does, Gemini
    ///   can only charge from Pentacles.
    func meterGain(from move: MoveSummary, context: PassiveContext) -> Int { 0 }

    func activate(context: PassiveContext, generator: inout SeededRandom) -> [GameEvent] {
        let board = context.currentBoard
        let size = board.size
        var changes: [GridPoint: TileHealth] = [:]

        for y in 0..<size {
            for x in 0..<(size / 2) {
                let source = GridPoint(x, y)
                let target = GridPoint(size - 1 - x, y)

                let from = board[source]
                let to = board[target]

                // Structural squares are not part of the reflection.
                guard from.kind == .normal, to.kind == .normal else { continue }
                guard from.health != to.health else { continue }

                changes[target] = from.health
            }
        }

        // The reflection appears all at once, not column by column.
        return changes.isEmpty ? [] : [.tilesChanged(plane: context.plane, changes: changes)]
    }
}
