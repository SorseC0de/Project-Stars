//
//  Virgo.swift
//  Project Stars
//
//  ♍ Virgo — The Maiden
//
//  Everything specific to this sign lives in this file. Virgo is an earth
//  sign, so it is stronger on **Terra** and weaker on **Astra**.
//

import SwiftUI

// MARK: - Definition

extension ZodiacCatalog {

    /// ♍ Virgo — The Maiden. Earth, Aug 23 – Sep 22. Strong on Terra.
    static let virgo = ZodiacDefinition(
        sign: .virgo,
        displayName: "Virgo",
        glyph: "♍",
        element: .earth,
        accentColor: Color(hex: 0x9A_AF_6B),
        movement: .scrupulousStep,
        passives: [
            VirgoControlledCompensation(),
            VirgoScrupulousStep(),
            VirgoPoisedPlummet(),
            VirgoRebootPayout(),
        ],
        zodiaction: VirgoRegulatedReboot(),
        constellation: ZodiacCatalog.virgoConstellation
    )

    /// ♍ Virgo: the long kite running down to Spica.
    static let virgoConstellation = Constellation(
        stars: [
            Constellation.Star(-0.95,  0.95,  0.15, 0.8),
            Constellation.Star(-0.25,  0.70, -0.10, 0.9),
            Constellation.Star( 0.55,  0.85,  0.20, 0.8),
            Constellation.Star( 0.15,  0.05,  0.00, 1.0),
            Constellation.Star(-0.60, -0.35,  0.20, 0.7),
            Constellation.Star( 0.35, -0.95, -0.20, 1.5),
        ],
        lines: [(0, 1), (1, 2), (1, 3), (3, 4), (3, 5)]
    )
}

// MARK: - Passive 1: Controlled Compensation

/// The Pentacle appears on whichever sparkling tile Virgo is already heading for.
///
/// It does not guarantee a Pentacle every move — the sparkle phase still has to
/// be running, and the destination still has to be one of the sparkles. What it
/// removes is the guess: for Virgo, aiming at a sparkle *is* opening it.
struct VirgoControlledCompensation: ZodiacPassive {

    /// Key this sign owns in `SignState.buffs` — set by Regulated Reboot.
    static let silencedKey = "virgo.compensationSilenced"

    let displayName = "Controlled Compensation"
    let summary = "Astra & Terra: the Pentacle always appears on the sparkling tile you are moving onto. Silent for a turn after Regulated Reboot."

    func preferredRevealPoint(
        among candidates: [GridPoint],
        destination: GridPoint,
        context: PassiveContext
    ) -> GridPoint? {
        // The ring is a gamble, and a gamble you can steer is not one. Without
        // this, Regulated Reboot would deal the coin straight into whichever
        // neighbour Virgo was already walking to, every single time.
        guard !context.signState.isActive(Self.silencedKey) else { return nil }
        return candidates.contains(destination) ? destination : nil
    }
}

// MARK: - Passive 2: Scrupulous Step

/// Virgo steps like a queen, and treads on ruined ground without finishing it.
///
/// ## The step
///
/// One square in any of the eight directions. That is a large amount of reach
/// for a single tile of wear — a diagonal covers what would otherwise be two
/// moves — and it is the reason the rest of this sign can afford to be careful
/// rather than fast.
///
/// ## The scruple
///
/// Landing on a badly cracked tile never breaks it *on arrival*. The tile is
/// charged when Virgo **leaves** instead, which is not a reprieve so much as a
/// deferral: the square still goes, but it goes behind her rather than under
/// her.
///
/// This replaces a once-every-three-moves save. A cooldown on a rule about the
/// ground is a rule the player cannot see — you had to remember when you last
/// used it to know whether the square you were about to step on was safe. Always
/// true is a rule you can plan around, and deferring rather than cancelling
/// keeps the board's decay honest.
struct VirgoScrupulousStep: ZodiacPassive {

    let displayName = "Scrupulous Step"
    let summary = "Astra & Terra: step one square in any direction, diagonals included. A badly cracked tile breaks as you leave it, never as you arrive."

    func wearTiming(context: PassiveContext) -> WearTiming {
        // Only over ground that is one landing from gone. Everywhere else Virgo
        // wears on arrival like anyone else, so this cannot be turned into a
        // general "damage happens behind me" by standing on a healthy tile.
        context.currentBoard[context.piecePoint].health == .badlyCracked
            ? .onExit
            : .onEntry
    }
}

// MARK: - Passive 3: Poised Plummet

/// Falling from Astra fully restores the Terra tile Virgo comes down on.
///
/// Never fills a hole — a hole is what was fallen *into*, not what was landed on.
/// The engine enforces that; this hook only ever sees a tile the piece can stand
/// on.
struct VirgoPoisedPlummet: ZodiacPassive {

    let displayName = "Poised Plummet"
    let summary = "Astra: falling to Terra fully restores the tile you land on."

    /// Poised is the word. The repair is certain, not a roll, so this qualifies
    /// on the same rule Leo and Pisces do — see
    /// `ZodiacPassive.fallIsControlled(to:context:)`.
    func fallIsControlled(to plane: Plane, context: PassiveContext) -> Bool {
        plane == .terra
    }

    func restoresTileOnFallArrival(
        tile: Tile,
        at point: GridPoint,
        plane: Plane,
        context: PassiveContext
    ) -> Bool {
        true
    }
}

// MARK: - Zodiaction: Regulated Reboot

/// Deals a fresh sparkle phase as a ring around Virgo — one of her eight
/// neighbours is hiding a Pentacle, and every one of them is a single step away.
///
/// ## Why it is a ring and not a re-roll
///
/// The old version started the hunt over somewhere else on the board, which is
/// only worth doing if the shape lands somewhere convenient — so the ability was
/// really "press this until you like the answer". A ring makes the answer
/// immediate: the coin is *here*, one step in some direction, and the whole of
/// the ability is deciding which.
///
/// Virgo's diagonals are what make that a real question rather than a
/// four-way guess: all eight are reachable, so every square in the ring is a
/// live option and the choice is between eight, not four.
///
/// ## Why the ring may hang over holes
///
/// Because a guaranteed safe Pentacle every time the meter fills is not a
/// decision. Sparkles normally refuse broken ground; this one does not, so the
/// coin may be sitting over nothing — and stepping onto it anyway is rewarded
/// rather than punished: the hole mends to badly cracked and the meter comes
/// **all** the way back. Landing on a coin standing on solid ground refunds
/// half. The gamble pays better than the safe play, which is the only way a
/// gamble is ever worth taking.
///
/// ## Why it refuses to fire near a wall
///
/// A partial ring is a worse offer wearing the same costume — fewer squares, the
/// same price. Refusing outright tells the player to step off the edge first,
/// which is information; charging them a full meter for five squares instead of
/// eight would not be.
struct VirgoRegulatedReboot: Zodiaction {

    let displayName = "Regulated Reboot"
    let summary = "Astra & Terra: ring yourself with sparkles, holes included. Step onto the coin for half your meter back — or onto the hole that held it to mend it and get all of it."

    /// Virgo's charge comes from its passives and from Pentacles.
    func meterGain(from move: MoveSummary, context: PassiveContext) -> Int { 0 }

    /// Needs eight neighbours, all of them ordinary ground.
    func canActivate(context: PassiveContext) -> Bool {
        SparkleSet.ring(
            around: context.piecePoint,
            on: context.plane,
            board: context.currentBoard
        ) != nil
    }

    func activate(context: PassiveContext, generator: inout SeededRandom) -> [GameEvent] {
        guard let set = SparkleSet.ring(
            around: context.piecePoint,
            on: context.plane,
            board: context.currentBoard
        ) else { return [] }

        guard let pickup = PickupCatalog.rollPickup(
            sparklePoints: set.points,
            using: &generator
        ) else { return [] }

        var state = context.signState
        // Two, because timers tick down at the end of the turn that set them —
        // and this pop is a turn.
        state.startBuff(VirgoControlledCompensation.silencedKey, moves: 2)

        return [
            .signStateChanged(state),
            .sparklesSpawned(set: set, pickup: pickup),
        ]
    }
}

// MARK: - Passive: Regulated Reboot's payouts

/// The half of Regulated Reboot that happens when Virgo arrives.
///
/// A Zodiaction fires and is gone; what it promised has to be collected by
/// something that is still listening when the coin is opened. See
/// `ZodiacPassive.collected(_:at:on:wasSolid:context:)`.
struct VirgoRebootPayout: ZodiacPassive {

    let displayName = "Regulated Reboot (arrival)"
    let summary = "Astra & Terra: a Pentacle from your own ring refunds half your meter, or mends the hole it stood on and refunds all of it."

    func collected(
        _ id: PickupID,
        at point: GridPoint,
        on plane: Plane,
        wasSolid: Bool,
        context: PassiveContext
    ) -> [GameEvent] {
        // Only a coin from Virgo's own ring pays. The silence is the marker:
        // it is set by the pop and lasts exactly as long as the ring does.
        guard context.signState.isActive(VirgoControlledCompensation.silencedKey) else {
            return []
        }

        let cap = context.zodiac.zodiaction.meterMax(on: plane)

        guard wasSolid else {
            // Stepped onto nothing and got away with it. Mended only to badly
            // cracked: the ground remembers, and one more landing still takes
            // it.
            return [
                .tileHealed(plane: plane, point: point, to: .badlyCracked),
                .zodiactionMeterChanged(to: cap),
            ]
        }

        return [.zodiactionMeterChanged(to: cap / 2)]
    }
}
