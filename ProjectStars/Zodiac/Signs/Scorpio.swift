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
    let summary = "Astra & Terra: you may vault two squares only to clear a hole, and gain ZC for doing it — +1 more for each consecutive move that does."

    func meterBonus(from move: MoveSummary, context: PassiveContext) -> Int {
        guard move.holesJumped > 0 else { return 0 }
        // `holeJumpStreak` already counts this move: 1 on the first, 2 next.
        return max(context.signState.holeJumpStreak, 1)
    }

    /// The vault is for clearing holes and nothing else.
    ///
    /// ## Why this is a nerf worth making
    ///
    /// A free two-square jump in any direction is simply better movement than
    /// anyone else's — it halves the board and skips a landing, and the sign
    /// that had it was also the sign paid for using it. Tying it to holes makes
    /// the two halves of this passive one design: you vault *because* the ground
    /// has gone, and the charge is for having crossed what was left.
    ///
    /// The hole has to lie on the path, not in front of the scorpion. Requiring
    /// it to be faced first would cost a turn to line up, and a turn spent
    /// standing beside a hole is exactly the turn this ability exists to avoid.
    func allows(
        _ option: MovementPattern.MoveOption,
        direction: SwipeDirection,
        path: [GridPoint],
        context: PassiveContext
    ) -> Bool {
        guard option.style == .hop, option.distance > 1 else { return true }

        // Derived from the origin rather than read off `path`, because a jump's
        // path is its destination alone — the squares it flies over are exactly
        // what a leap does *not* record. A vault over solid ground is just a
        // longer step, and Scorpio does not get one.
        let step = direction.unitOffset
        let crossed = (1..<option.distance).map { index in
            GridPoint(
                context.piecePoint.x + step.dx * index,
                context.piecePoint.y + step.dy * index
            )
        }

        return crossed.contains { square in
            context.currentBoard.contains(square) && !context.currentBoard[square].isSolid
        }
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
            .pieceMoved(
                from: point, to: point,
                fromPlane: .terra, toPlane: .astra,
                type: .teleport
            ),
        ]
    }
}

// MARK: - Passive 3: Samsaric Shed

/// The first death on Terra is not a death. Scorpio leaves its skin behind and
/// reappears on the Nexys — but from then on it can never ascend again, so the
/// next trip down is final.
///
/// Once per run, and the only thing that refreshes it is becoming a different
/// sign, which is why the flag lives in `runFlags` — the one scope a piece change
/// wipes.
///
/// ## The island is wherever the island is
///
/// The rescue does not move the Nexys and does not choose a plane. It puts
/// Scorpio *on the island*, and if the island is down on Terra then Terra is
/// where you wake up. That is not a downgrade, it is the honest version of the
/// rule: a rescue that could conjure a way back to Astra whenever you needed one
/// made the ascent lockout meaningless, since the shed itself was the ascent.
///
/// So sending the island away before you die is now a real decision with a real
/// cost, and dying on Terra with the island on Terra is survivable but goes
/// nowhere.
///
/// ## The skin stays
///
/// A translucent copy of the piece is left standing on the square where it
/// died, for the rest of the run. It is not an obstacle and it does nothing; it
/// is a receipt. Once-per-run abilities are invisible after they fire — the
/// player is left to remember whether they still have it — and a mark on the
/// board answers that without a counter in the panel.
struct ScorpioSamsaricShed: ZodiacPassive {

    /// Keys this sign owns in `SignState.runFlags`.
    static let usedKey = "scorpio.samsaricShed.used"
    static let ascentLockedKey = "scorpio.samsaricShed.ascentLocked"

    let displayName = "Samsaric Shed"
    let summary = "Terra: once per run, dying puts you on the Nexys wherever it is — but you can never ascend again."

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
        state.shedSkin = SignState.ShedSkin(point: point, plane: plane)

        return [
            .signStateChanged(state),
            // Not `nexysMoved`: the island does not come for you. The piece
            // travels to it, on whichever plane it is already sitting.
            .pieceMoved(
                from: point,
                to: GameRules.nexysPoint,
                fromPlane: plane,
                toPlane: context.nexysPlane,
                type: .teleport
            ),
        ]
    }

    func blocksAscent(context: PassiveContext) -> Bool {
        context.signState.runFlags.contains(Self.ascentLockedKey)
    }
}

// MARK: - Zodiaction: Snatching Sting

/// A phantasmal tail lunges along Scorpio's facing and drags back any Pentacle
/// it pierces — three tiles on Terra, the whole row or column on Astra.
///
/// ## Why it does not touch the ground
///
/// The sting takes the coin and nothing else: no wear, no repair, no movement.
/// Scorpio's whole game is that the board is *already* broken and it does not
/// care, so a super that rearranged the ground would be playing somebody else's
/// game. What it buys is reach — a Pentacle across the room, without walking
/// the room.
///
/// ## How the coin comes back
///
/// As `pickupGathered`, the event a slide already uses when it sweeps a coin up
/// mid-journey: the coin leaves the board here and opens once the action stops,
/// which `GameEngine.planZodiaction` does for it. So the effect runs with
/// Scorpio standing where Scorpio is — the coin was dragged back, not walked to
/// — and the whole first-encounter splash comes along for free.
struct ScorpioSnatchingSting: Zodiaction {

    let displayName = "Snatching Sting"
    let summary = "Terra: strike \(GameRules.stingReachTerra) tiles ahead. Astra: strike the full row or column. Any Pentacle in the line is dragged back and opened."

    /// Scorpio's charge comes from Void Culling.
    func meterGain(from move: MoveSummary, context: PassiveContext) -> Int { 0 }

    func activate(context: PassiveContext, generator: inout SeededRandom) -> [GameEvent] {
        let struck = line(context: context)

        // The strike itself always plays, hit or miss — a super that did nothing
        // visible when it missed would read as a bug rather than as a miss.
        var events: [GameEvent] = [
            .stingStruck(plane: context.plane, from: context.piecePoint, along: struck)
        ]

        for pickup in context.pickups where struck.contains(pickup.point) {
            events.append(
                .pickupGathered(id: pickup.id, plane: pickup.plane, point: pickup.point)
            )
        }
        return events
    }

    /// The squares the tail passes through, nearest first.
    ///
    /// Holes and the Nexys included: the tail is over the board, not on it, and
    /// a coin sitting on the island is exactly the coin worth reaching for.
    private func line(context: PassiveContext) -> [GridPoint] {
        let step = context.facing.unitOffset
        let reach = context.isEmpowered
            ? context.currentBoard.size
            : GameRules.stingReachTerra

        return (1...reach)
            .map { index in
                GridPoint(
                    context.piecePoint.x + step.dx * index,
                    context.piecePoint.y + step.dy * index
                )
            }
            .filter { context.currentBoard.contains($0) }
    }
}
