//
//  Scorpio.swift
//  Project Stars
//
//  ♏ Scorpio — The Scorpion
//
//  Everything specific to this sign lives in this file. Scorpio is a water
//  sign, so it is stronger on **Astra** and weaker on **Terra**.
//

import SwiftUI

// MARK: - Definition

extension ZodiacCatalog {

    /// ♏ Scorpio — The Scorpion. Water, Oct 23 – Nov 21. Strong on Astra.
    static let scorpio = ZodiacDefinition(
        sign: .scorpio,
        displayName: "Scorpio",
        glyph: "♏",
        element: .water,
        accentColor: Color(hex: 0x8E_4A_6E),

        // One square walked, or two vaulted. The vault clears whatever lies
        // between — which is precisely what Void Culling below pays out on, so
        // the movement and the passive are one design.
        movement: .slideOrVault,

        passives: [
            ScorpioVoidCulling(),
            ScorpioDeathDream(),
            ScorpioSamsaricShed(),
        ],
        zodiaction: ScorpioSnatchingSting(),
        constellation: ZodiacCatalog.scorpioConstellation
    )

    /// ♏ Scorpio: the claws, Antares at the heart, and the curling tail.
    static let scorpioConstellation = Constellation(
        stars: [
            Constellation.Star(-1.05,  0.95,  0.20, 0.8),
            Constellation.Star(-0.45,  0.80,  0.05, 0.9),
            Constellation.Star(-0.10,  0.25,  0.00, 1.5),
            Constellation.Star( 0.10, -0.35, -0.10, 0.9),
            Constellation.Star( 0.45, -0.80, -0.20, 0.8),
            Constellation.Star( 0.95, -0.95, -0.10, 0.8),
            Constellation.Star( 1.15, -0.40,  0.15, 0.9),
            Constellation.Star( 0.85,  0.05,  0.30, 1.0),
        ],
        lines: [(0, 1), (1, 2), (2, 3), (3, 4), (4, 5), (5, 6), (6, 7)]
    )
}

// MARK: - Passive 1: Void Culling

/// Charge for clearing holes, escalating while the streak holds.
///
/// One pip for a move that jumps a hole, two for the next consecutive one, three
/// for the one after, and so on. A move that clears nothing resets it — so the
/// payout rewards a deliberate run across broken ground rather than an
/// occasional lucky hop.
///
/// The streak lives in `SignState.holeJumpStreak`, counted by the engine, because
/// `meterBonus` can price a streak but cannot count one.
struct ScorpioVoidCulling: ZodiacPassive {

    let displayName = "Void Culling"
    let summary = "Astra & Terra: charge for jumping over holes, +1 more for each consecutive move that does."

    func meterBonus(from move: MoveSummary, context: PassiveContext) -> Int {
        guard move.holesJumped > 0 else { return 0 }
        // `holeJumpStreak` already counts this move: 1 on the first, 2 next.
        return max(context.signState.holeJumpStreak, 1)
    }
}

// MARK: - Passive 2: Death Dream

/// Dropping through an Astra hole *straight into* a Terra hole does not kill
/// Scorpio. It wakes back up on Astra where it fell, and the hole it fell
/// through is mended behind it.
///
/// Free, unlimited, and the reason Scorpio can treat a broken Astra board as
/// something to fall through rather than something to fear — but only when the
/// square below is also open. Falling onto solid Terra is an ordinary landing
/// and Death Dream never comes up.
///
/// Declared before Shed so it always gets first refusal: it is the cheaper
/// rescue and costs nothing, where Shed costs the way home.
struct ScorpioDeathDream: ZodiacPassive {

    let displayName = "Death Dream"
    let summary = "Astra: falling through a hole into a Terra hole returns you to Astra and mends the hole you fell through."

    func survivesFatalFall(
        at point: GridPoint,
        from plane: Plane,
        context: PassiveContext
    ) -> [GameEvent]? {
        // Only the through-and-through case. Dying on Terra without having come
        // from an Astra hole is Shed's business.
        guard plane == .terra, context.signState.planeArrivalMove == context.moveCount else {
            return nil
        }

        return [
            .tileHealed(plane: .astra, point: point, to: .healthy),
            .pieceTeleported(from: point, to: point, fromPlane: .terra, toPlane: .astra),
        ]
    }
}

// MARK: - Passive 3: Shed

/// The first death on Terra is not a death. Scorpio sheds its skin and reappears
/// on the Nexys in Astra — but from then on it can never ascend again, so the
/// next trip down is final.
///
/// Once per run, and the only thing that refreshes it is becoming a different
/// sign, which is why the flag lives in `runFlags` — the one scope a piece change
/// wipes.
///
/// The lockout is enforced at both places a piece can go up: coming to rest on
/// the island in Terra, and the Nexys Shift Pentacle.
struct ScorpioSamsaricShed: ZodiacPassive {

    /// Keys this sign owns in `SignState.runFlags`.
    static let usedKey = "scorpio.samsaricShed.used"
    static let ascentLockedKey = "scorpio.samsaricShed.ascentLocked"

    let displayName = "Samsaric Shed"
    let summary = "Terra: once per run, dying returns you to the Nexys in Astra — but you can never ascend again."

    func survivesFatalFall(
        at point: GridPoint,
        from plane: Plane,
        context: PassiveContext
    ) -> [GameEvent]? {
        guard plane == .terra else { return nil }
        guard !context.signState.runFlags.contains(Self.usedKey) else { return nil }

        var state = context.signState
        state.runFlags.insert(Self.usedKey)
        state.runFlags.insert(Self.ascentLockedKey)

        return [
            // Carries the piece: the island is where the shed skin is left.
            .nexysMoved(to: .astra, carryingPiece: true),
            .signStateChanged(state),
        ]
    }

    func blocksAscent(context: PassiveContext) -> Bool {
        context.signState.runFlags.contains(Self.ascentLockedKey)
    }
}

// MARK: - Zodiaction: Snatching Sting

/// A phantasmal tail lunges along Scorpio's facing, collecting any Pentacle it
/// pierces — three tiles on Terra, the entire row or column on Astra.
///
/// - TODO: **Not implemented.** The reach and the line are trivial to compute;
///   what is missing is "collect a Pentacle at range". Collection is currently
///   welded to the piece coming to rest on the coin
///   (`resolvePickupCollection`), including the first-encounter splash and the
///   effect's own `PickupContext`, which assumes the piece is standing where the
///   Pentacle was.
///
///   Extracting a `collect(at:)` that does not assume the piece is there unblocks
///   this and Shadow Work's "collide it into a Pentacle" rule at the same time.
struct ScorpioSnatchingSting: Zodiaction {

    let displayName = "Snatching Sting"
    let summary = "Terra: strike 3 tiles ahead. Astra: strike the full row or column. Collects any Pentacle hit. (Not yet implemented.)"

    /// Scorpio's charge comes from Void Culling.
    func meterGain(from move: MoveSummary, context: PassiveContext) -> Int { 0 }
}
