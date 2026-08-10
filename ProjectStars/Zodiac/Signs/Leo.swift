//
//  Leo.swift
//  Project Stars
//
//  ♌ Leo — The Lion
//
//  Everything specific to this sign lives in this file, its sun included.
//  Leo is a fire sign, so it is stronger on **Terra** and weaker on
//  **Astra**.
//

import SwiftUI

// MARK: - Definition

extension ZodiacCatalog {

    /// ♌ Leo — The Lion. Fire, Jul 23 – Aug 22. Strong on Terra.
    static let leo = ZodiacDefinition(
        sign: .leo,
        displayName: "Leo",
        glyph: "♌",
        element: .fire,
        accentColor: Color(hex: 0xF0_8A_2E),
        movement: .cardinalStep,
        passives: [
            LeoPridefulPlant(),
        ],
        zodiaction: LeoHeliocentricHearth(),
        constellation: ZodiacCatalog.leoConstellation
    )

    /// ♌ Leo: the Sickle at the head, the triangle of the haunch behind it.
    static let leoConstellation = Constellation(
        stars: [
            Constellation.Star(-1.15,  0.15,  0.25, 0.8),
            Constellation.Star(-1.00,  0.75,  0.15, 0.9),
            Constellation.Star(-0.55,  1.00,  0.00, 0.8),
            Constellation.Star(-0.20,  0.55, -0.10, 1.0),
            Constellation.Star(-0.35, -0.25,  0.10, 1.5),
            Constellation.Star( 0.60, -0.30, -0.20, 0.9),
            Constellation.Star( 1.10,  0.45, -0.15, 1.2),
            Constellation.Star( 1.00, -0.55, -0.30, 0.8),
        ],
        lines: [(0, 1), (1, 2), (2, 3), (3, 4), (4, 5), (5, 6), (6, 7), (7, 5)]
    )
}

// MARK: - Passive: Prideful Plant

/// Three pips for hitting the ground.
///
/// Falling is a loss for every other sign; for Leo it is the descent to the
/// plane it is strong on, and it charges for the privilege.
struct LeoPridefulPlant: ZodiacPassive {

    let displayName = "Prideful Plant"
    let summary = "Astra: +3 charge on landing after a fall to Terra."

    func meterBonus(from move: MoveSummary, context: PassiveContext) -> Int {
        move.fell ? 3 : 0
    }
}

// MARK: - Zodiaction: Heliocentric Hearth

/// Hangs a small sun over the square Leo faces.
///
/// It mends that square outright, then burns for five moves, dragging the
/// Pentacle one square toward itself every move — shortest path, diagonals
/// included, so the coin cuts across the board rather than walking it.
///
/// ## What it does not do
///
/// It never fills a hole. A hole is not damage to a tile, it is the absence of
/// one, and letting the sun paper over holes would make Leo the sign that undoes
/// the board's decay — which is the pressure the whole game runs on.
///
/// A coin dragged onto a hole is destroyed and the hunt restarts. That is not a
/// special case here: `ensurePentacleAvailable` already governs any coin left
/// standing on nothing, and the sun's pull is planned before it runs.
///
/// ## The Nexys
///
/// Raise a sun over the Nexys' own chasm while the island is up on Astra and it
/// drags the island down to Terra instead — and goes out immediately, having
/// spent itself on the one thing it cannot do twice. Once per run, refreshed by
/// changing pieces, which is exactly the rule Scorpio's Samsaric Shed uses.
///
/// The sun is not placed at all in that case: it did its work in one move, and
/// leaving it burning would give the pull five free moves on top of the island.
struct LeoHeliocentricHearth: Zodiaction {

    /// Key this sign owns in `SignState.runFlags`.
    static let nexysPullKey = "leo.heliocentricHearth"

    let displayName = "Heliocentric Hearth"
    let summary = "Spawn a small sun on the tile ahead for 5 moves: it mends that tile and drags the Pentacle one square toward it each move."

    /// Leo's charge comes from Prideful Plant.
    func meterGain(from move: MoveSummary, context: PassiveContext) -> Int { 0 }

    func activate(context: PassiveContext, generator: inout SeededRandom) -> [GameEvent] {
        let target = context.piecePoint.offset(by: context.facing.unitOffset)

        // Facing off the board, the sun has nowhere to hang.
        guard context.currentBoard.contains(target) else { return [] }

        if let pull = nexysPull(to: target, context: context) { return pull }

        var events: [GameEvent] = []
        let tile = context.currentBoard[target]

        if GameRules.sunHealsItsTile, tile.kind == .normal,
           !tile.health.isHole, tile.health != .healthy {
            events.append(.tileHealed(plane: context.plane, point: target, to: TileHealth.healthy))
        }

        var state = context.signState
        state.sun = SignState.Sun(
            point: target,
            plane: context.plane,
            movesRemaining: GameRules.sunMoves
        )
        events.append(.signStateChanged(state))

        return events
    }

    /// The island coming down, if this is that move.
    ///
    /// Returns `nil` when it is an ordinary sun, so the caller reads as one
    /// path with one exception rather than as two branches.
    private func nexysPull(to target: GridPoint, context: PassiveContext) -> [GameEvent]? {
        guard target == GameRules.nexysPoint,
              context.plane == .terra,
              context.nexysPlane == .astra,
              !context.signState.runFlags.contains(Self.nexysPullKey)
        else { return nil }

        var state = context.signState
        state.runFlags.insert(Self.nexysPullKey)

        return [
            .nexysMoved(to: .terra, carryingPiece: false),
            .signStateChanged(state),
        ]
    }
}

/// The sun Leo's Heliocentric Hearth hangs over a square.
///
/// ## Why this is not an `EffectSpriteView`
///
/// Those play once and stop, which is right for an event. A sun is not an
/// event — it is a thing on the board with a lifetime measured in moves, and it
/// has to still be there five turns later. So all three of its strips loop, on
/// one clock, for as long as the engine says it is burning.
///
/// ## Why the summon is in the stack
///
/// It was drawn as a third layer of the same thing, not as a preamble to it.
/// Played first and then dropped, the sun visibly lost a layer a second in;
/// looped alongside the other two it is simply part of what a sun looks like.
struct SunView: View {

    let sun: SignState.Sun

    /// Size of a board cell, in points.
    let tileSize: CGFloat

    /// Every strip the sun is made of, bottom first.
    private var layers: [EffectSprite] {
        EffectSprite.leoSun + [.leoZodiactionSummon]
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            let now = timeline.date.timeIntervalSinceReferenceDate

            ZStack {
                ForEach(layers, id: \.self) { layer in
                    let frame = Int(now / layer.rate.frameDuration) % layer.frames

                    PixelSprite(id: .effect(layer), frame: frame) { EmptyView() }
                        .frame(width: side(layer), height: side(layer))
                }
            }
            // Dims on its final move, so the last turn under it is visibly the
            // last one — the same warning the Bastion gives by pulsing faster.
            .opacity(sun.movesRemaining <= 1 ? GameRules.sunGuttering : 1)
        }
        .allowsHitTesting(false)
    }

    private func side(_ layer: EffectSprite) -> CGFloat {
        tileSize * layer.span
    }
}
