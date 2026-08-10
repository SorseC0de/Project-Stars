//
//  Aquarius.swift
//  Project Stars
//
//  ♒ Aquarius — The Water-Bearer
//
//  Everything specific to this sign lives in this file. Aquarius is an air
//  sign, so it is stronger on **Astra** and weaker on **Terra**.
//

import SwiftUI

// MARK: - Definition

extension ZodiacCatalog {

    /// ♒ Aquarius — The Water-Bearer. Air, Jan 20 – Feb 18. Strong on Astra.
    static let aquarius = ZodiacDefinition(
        sign: .aquarius,
        displayName: "Aquarius",
        glyph: "♒",
        element: .air,
        accentColor: Color(hex: 0x4E_7F_D4),
        movement: .cardinalStep,
        passives: [
            AquariusQuirkyCaper(),
            AquariusLitheLeaper(),
            AquariusCornerCurrent(),
        ],
        zodiaction: AquariusGoneWithTheGale(),
        constellation: ZodiacCatalog.aquariusConstellation
    )

    /// ♒ Aquarius: the water-bearer's jar, and the stream falling from it.
    static let aquariusConstellation = Constellation(
        stars: [
            Constellation.Star(-1.00,  0.85,  0.15, 0.9),
            Constellation.Star(-0.35,  0.95,  0.00, 1.0),
            Constellation.Star( 0.20,  0.55, -0.15, 0.9),
            Constellation.Star( 0.80,  0.75, -0.25, 0.8),
            Constellation.Star( 0.05, -0.10,  0.10, 0.8),
            Constellation.Star(-0.45, -0.55,  0.25, 0.7),
            Constellation.Star( 0.35, -0.75, -0.10, 0.7),
            Constellation.Star(-0.10, -1.05,  0.00, 0.9),
        ],
        lines: [(0, 1), (1, 2), (2, 3), (2, 4), (4, 5), (4, 6), (5, 7), (6, 7)]
    )
}

// MARK: - Passive 1: Quirky Caper

/// Aquarius never lands hard enough to matter — the damage goes to the tile it
/// pushes off from.
///
/// The consequence worth understanding: arriving somewhere costs nothing, so a
/// wrecked board is far safer to cross than it is for anyone else, but the square
/// you are standing on is always the one about to break. Aquarius cannot loiter.
struct AquariusQuirkyCaper: ZodiacPassive {

    let displayName = "Quirky Caper"
    let summary = "Astra & Terra: damage the tile you leave, never the one you land on."

    func wearTiming(context: PassiveContext) -> WearTiming {
        .onExit
    }
}

// MARK: - Passive 2: Lithe Leaper

/// Every multi-tile move is a jump, never a slide.
///
/// A slide settles on each square it crosses and can break through halfway; a
/// jump touches only the destination. So Weightless is what makes Aquarius'
/// longer moves safe to make across broken ground — it flies over the gaps
/// instead of testing each one.
///
/// Inert while Aquarius' movement is the shared single step, since a one-tile
/// move has nothing to cross.
struct AquariusLitheLeaper: ZodiacPassive {

    let displayName = "Lithe Leaper"
    let summary = "Astra & Terra: multi-tile moves are jumps, crossing holes instead of settling on them."

    func adjustedMovement(base: MovementPattern, context: PassiveContext) -> MovementPattern {
        // Every option becomes a jump. A single-square option is unaffected in
        // practice — there is nothing between adjacent squares — so this only
        // bites once Aquarius has a longer move to make.
        var airborne = base
        airborne.options = base.options.map { option in
            var lifted = option
            lifted.style = .jump
            return lifted
        }
        return airborne
    }
}

// MARK: - Passive 3: Corner Current

/// Once per plane visit, landing on a corner offers a flight
/// to another one — the diagonal opposite on Terra, any corner on Astra.
///
/// - TODO: **Not implemented — needs an optional prompt**, the same
///   suspend-and-ask machinery as Capricorn's Pentacle Platform. The Astra variant also
///   needs a *choice between corners*, which `PickupChoice.tile` already models;
///   it would just be offered with the candidate set restricted to three squares.
///
///   The once-per-visit limit is already covered by `SignState.planeFlags`.
struct AquariusCornerCurrent: ZodiacPassive {

    /// Key this sign owns in `SignState.planeFlags`.
    static let usedThisVisitKey = "aquarius.cornerCurrent"

    let displayName = "Corner Current"
    let summary = "Once per plane visit, landing on a corner can fly you to another. (Not yet implemented.)"
}

// MARK: - Zodiaction: Gone With the Gale

/// Scatters Aquarius to a random square it can stand on, anywhere on the plane —
/// the Nexys included.
///
/// Only solid squares are candidates, so this can never be a disguised suicide.
/// It is an escape, not a gamble: the value is getting *out* of a corner of the
/// board that has decayed past use.
struct AquariusGoneWithTheGale: Zodiaction {

    let displayName = "Gone With the Gale"
    let summary = "Astra & Terra: teleport to a random tile you can stand on, the Nexys included."

    /// - TODO: Aquarius has no charge rule specified. It currently fills only
    ///   from Pentacles.
    func meterGain(from move: MoveSummary, context: PassiveContext) -> Int { 0 }

    func activate(context: PassiveContext, generator: inout SeededRandom) -> [GameEvent] {
        let candidates = context.currentBoard.solidPoints.filter { $0 != context.piecePoint }
        guard let target = candidates.randomElement(using: &generator) else { return [] }

        return [
            .pieceTeleported(
                from: context.piecePoint,
                to: target,
                fromPlane: context.plane,
                toPlane: context.plane
            )
        ]
    }
}
