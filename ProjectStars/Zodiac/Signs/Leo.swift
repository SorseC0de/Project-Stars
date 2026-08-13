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
            LeoMagneticMane(),
            LeoCourageousCharge(),
        ],
        zodiaction: LeoAttractingAten(),
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

    /// The lion drops on purpose. See `ZodiacPassive.fallIsControlled(to:context:)`.
    func fallIsControlled(to plane: Plane, context: PassiveContext) -> Bool {
        plane == .terra
    }

    func meterBonus(from move: MoveSummary, context: PassiveContext) -> Int {
        move.fell ? 3 : 0
    }
}

// MARK: - Passive: Magnetic Mane

/// The Pentacle sometimes drifts a square toward the lion, unprompted.
///
/// Rare on purpose — one step in a hundred up top, one in twenty below. It is
/// not a way to fetch a coin, it is the occasional sense that the board is
/// paying attention to you, which is what a lion should feel like.
///
/// ## What happens when an Aten is up
///
/// The coin comes *to the piece*, not to the sun, and travels an extra square
/// for the trouble. Leo's sun already drags the coin toward itself every move;
/// this overrides that for the turn it fires, so a sun on the far side of the
/// board never pulls a coin away from a lion the coin was just drawn to. The
/// reward for having a sun out is the extra distance, not a tug of war.
struct LeoMagneticMane: ZodiacPassive {

    let displayName = "Magnetic Mane"
    let summary = "Astra & Terra: a small chance each step that the Pentacle drifts a square toward you — two while an Aten burns."

    func magneticPullChance(context: PassiveContext) -> Double {
        switch context.plane {
        case .astra: GameRules.magneticManeChanceAstra
        case .terra: GameRules.magneticManeChanceTerra
        }
    }
}

// MARK: - Passive: Courageous Charge

/// Walking onto a hole on purpose sometimes works.
///
/// A one-in-four chance on Astra and one-in-two on Terra that the hole Leo steps
/// into closes under it instead — mended outright — and the meter fills.
///
/// ## Why it only counts when the square was chosen
///
/// The whole idea is nerve. Being swept into a hole by Astral Brook, dropped
/// into one by a collapsing tile, or scattered onto one by a Zodiaction is not
/// bravery, it is weather — and paying out for it would make Leo the sign that
/// is rewarded for losing control of the board. So it fires only where the
/// player picked the square: an ordinary step, or an effect that stopped to ask.
/// See `PassiveContext.arrivalWasChosen`.
///
/// ## Why it is stronger below
///
/// Terra is the lion's plane, and Terra is also where a hole is fatal rather
/// than merely a descent. Doubling the odds exactly where the stake is highest
/// is what makes this an *option* down there instead of a novelty.
///
/// ## Why the payout is the full meter
///
/// A partial refund would make this a small bonus attached to a coin-flip on
/// your life, which nobody would ever take deliberately. Filling the meter makes
/// the gamble a plan: Leo can walk into a hole *because* it wants the Zodiaction,
/// and half the time it gets both that and the ground back.
struct LeoCourageousCharge: ZodiacPassive {

    /// Chance of the ground holding, per plane.
    static let chanceAstra = 0.25
    static let chanceTerra = 0.50

    let displayName = "Courageous Charge"
    let summary = "Astra: a quarter chance that a hole you step into on purpose mends and fills your meter. Terra: half."

    func preventsFall(
        from plane: Plane,
        at point: GridPoint,
        context: PassiveContext
    ) -> Bool {
        // Both halves matter. `arrivalWasChosen` rules out being swept or
        // dropped into a hole; `arrivedOnOpenGround` rules out a tile that broke
        // under the landing, which is not a hole anybody charged into.
        guard context.arrivalWasChosen, context.arrivedOnOpenGround else { return false }
        return context.luck < (plane == .terra ? Self.chanceTerra : Self.chanceAstra)
    }

    func eventsOnPreventingFall(
        at point: GridPoint,
        on plane: Plane,
        context: PassiveContext
    ) -> [GameEvent] {
        // Asked again rather than trusted: the engine calls this whenever *any*
        // passive caught the piece, and Leo must not pay out for somebody else's
        // save. The roll is `context.luck`, drawn once for the whole move, so
        // asking twice gives the same answer.
        guard preventsFall(from: plane, at: point, context: context) else { return [] }

        return [
            .tileHealed(plane: plane, point: point, to: .healthy),
            .zodiactionMeterChanged(to: context.zodiac.zodiaction.meterMax(on: plane)),
        ]
    }
}

// MARK: - Hidden: Rallying Roar

/// On Terra, the island offers a change of sign instead of a ride.
///
/// - TODO: **Not implemented.** The rule is settled and the engine is most of
///   the way there; what is missing is the choice itself. Stepping onto the
///   Nexys while it sits on Terra currently rides it straight back up — see
///   `GameRules.nexysAscendsFromTerra`. This would offer the player a piece
///   change instead, via the same `PickupChoice.piece` machinery Alignment
///   already uses, and then let the island leave *without* them the moment they
///   step off it in any direction.
///
///   It needs: a way for a landing to raise a choice (today only a Pentacle
///   can), and a flag on `SignState` for an island that has been dismissed and
///   is waiting to go. Both are small; neither exists yet.
///
///   The intent is Leo as the leadership sign — the one piece that commands the
///   Nexys rather than merely catching a lift on it.
///
/// ## Why it is not in `passives`
///
/// It is meant to be **found**, not read. A player who steps onto the island and
/// is offered a choice they were never promised has discovered something; the
/// same player told about it on the selection screen has merely been given an
/// instruction. Leo's three listed abilities are the ones you pick the sign for,
/// and this is the one you tell other people about.
///
/// Kept as a type so the design does not evaporate, and so wiring it up later is
/// a matter of adding it back to the list — or, better, of the engine consulting
/// it directly without the panel ever naming it.
struct LeoRallyingRoar: ZodiacPassive {

    let displayName = "Rallying Roar"
    let summary = "Terra: step onto the Nexys to change sign instead of riding up. (Not yet implemented.)"
}

// MARK: - Zodiaction: Attracting Aten

/// Hangs a small sun over the square Leo faces.
///
/// It mends that square outright, then burns for five moves, dragging the
/// Pentacle one square toward itself every move — shortest path, diagonals
/// included, so the coin cuts across the board rather than walking it.
///
/// ## The name
///
/// > The word aten originally meant "disk," "orb," or "sphere" in the ancient
/// > Egyptian language.
///
/// An object, in other words, and only later the name of a sun god. Disk, orb
/// and sphere are all exactly what this places on the board, which is why the
/// name is not a deity reference and should not be "corrected" into one.
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
struct LeoAttractingAten: Zodiaction {

    /// Key this sign owns in `SignState.runFlags`.
    static let nexysPullKey = "leo.attractingAten"

    let displayName = "Attracting Aten"
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

/// The sun Leo's Attracting Aten hangs over a square.
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
