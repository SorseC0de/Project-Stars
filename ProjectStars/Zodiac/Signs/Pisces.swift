//
//  Pisces.swift
//  Project Stars
//
//  ♓ Pisces — The Fishes
//
//  Everything specific to this sign lives in this file. Pisces is a water
//  sign, so it is stronger on **Astra** and weaker on **Terra**.
//

import SwiftUI

// MARK: - Definition

extension ZodiacCatalog {

    /// ♓ Pisces — The Fishes. Water, Feb 19 – Mar 20. Strong on Astra.
    static let pisces = ZodiacDefinition(
        sign: .pisces,
        displayName: "Pisces",
        glyph: "♓",
        element: .water,
        accentColor: Color(hex: 0x4E_7F_D4),
        movement: .starstream,
        passives: [
            PiscesStarstreamSurfer(),
            PiscesGaiaGeyser(),
            PiscesAridAquanaut(),
        ],
        zodiaction: PiscesSurgingStream(),
        constellation: ZodiacCatalog.piscesConstellation
    )

    /// ♓ Pisces: two fish on a cord, meeting at Alrescha.
    static let piscesConstellation = Constellation(
        stars: [
            Constellation.Star(-1.10,  0.90,  0.20, 0.8),
            Constellation.Star(-0.85,  0.30,  0.10, 0.7),
            Constellation.Star(-0.40, -0.20,  0.00, 0.8),
            Constellation.Star( 0.05, -0.75, -0.10, 1.2),
            Constellation.Star( 0.55, -0.25, -0.20, 0.8),
            Constellation.Star( 0.95,  0.35, -0.10, 0.7),
            Constellation.Star( 1.05,  0.95,  0.15, 0.9),
        ],
        lines: [(0, 1), (1, 2), (2, 3), (3, 4), (4, 5), (5, 6)]
    )
}

// MARK: - Passive 1: Starstream Surfer

/// The fish does not walk. It rides the current — any turn it likes — and that
/// ride is the only thing that charges it on Astra.
///
/// ## What changed and why
///
/// Astral Attunement paid a pip for every move made on Astra, which made the
/// correct play "take as many small steps up here as possible". That is not a
/// water sign, it is a metronome. The surf — what used to be half of Surging
/// Stream — is now ordinary movement, and the meter fills from *using* it.
///
/// So charging is a decision with a shape: a surf crosses the board, wears the
/// tile it left and the tile it stopped on, and puts Pisces against a wall. It
/// is the best thing the sign can do and it costs position every single time.
///
/// ## Terra is unchanged
///
/// A pip drains for every square left, exactly as before. Billed on departure
/// rather than arrival so the move that reaches a Pentacle does not pay the toll
/// and collect in the same breath — land on a Z-Charge at zero and you finish on
/// three, which is what the coin says it gives.
struct PiscesStarstreamSurfer: ZodiacPassive {

    let displayName = "Starstream Surfer"
    let icon: String? = "pisces_surfer"
    let summary = "Flow along the plane using the power of the Astral Current while fully charged with ZC."

    /// The current is not a property of the plane. It is a property of *you*.
    ///
    /// ## Why the surf is now gated
    ///
    /// Because the sign had a resource with nothing to want. Steps paid nothing,
    /// the surf paid three, and the only thing the meter *bought* was a
    /// Zodiaction that drops the fish on Terra — the worst place it can be. So
    /// the correct play was to never fill it, which makes a charging passive
    /// into decoration.
    ///
    /// Inverting it gives the meter a second job. Ordinary steps fill it, and a
    /// full meter is what unlocks the surf — so the fish spends its charge
    /// *riding* rather than banking, and the decision each turn is whether to
    /// keep the meter full for another crossing or spend it going down. Being
    /// full is now a state Pisces wants to be in and to stay in, and the descent
    /// is the escape hatch pulled deliberately, after as much of Astra has been
    /// crossed as the player dares.
    ///
    /// ## Why the plane is not part of the test
    ///
    /// It was: the surf was struck off on Terra outright, on the reasoning that
    /// a dry plane has no current to ride. But a full meter is what turns *any*
    /// piece gold, and gold is the state this is really asking about — so the
    /// rule is one line for both boards, and Terra's dryness shows up as the
    /// difference in how hard it is to *get* gold rather than as a second rule
    /// about where you may surf.
    ///
    /// That is still the shape of the sign — rich and mobile up top, stranded
    /// down below — because on Astra the meter fills off ordinary steps and
    /// below it fills off water and nothing else. Being earthbound does not stop
    /// Pisces surfing; it stops Pisces charging, and the surf follows.
    func adjustedMovement(base: MovementPattern, context: PassiveContext) -> MovementPattern {
        guard context.zodiactionMeter < context.zodiactionMeterMax else { return base }
        return MovementPattern(
            name: base.name,
            options: base.options.filter { !$0.reachesWall }
        )
    }

    func meterBonus(from move: MoveSummary, context: PassiveContext) -> Int {
        // Standing water pays whoever is standing in it, on either plane. Only
        // Pisces can be — pools evaporate the moment the sign changes — but the
        // rule is written where it can be *read* rather than left implied by
        // that.
        let inPool = context.currentBoard[move.restingPoint].kind == .pool
        let pool = inPool ? GameRules.poolCharge : 0

        if move.endingPlane == .astra {
            // A surf is any move that covered more ground than a step. Nothing
            // else in this pattern can.
            //
            // It pays nothing now: the meter is what *allows* the surf, so
            // paying for taking it would refund the price of the thing being
            // bought. The steps are what fill it — see `adjustedMovement`.
            let surfed = move.origin.manhattanDistance(to: move.destination) > 1
            return pool + (surfed ? 0 : GameRules.starstreamStepCharge)
        }

        // Terra pays nothing for moving, and charges nothing for it either.
        //
        // The pip-per-move toll is gone. It made the fish poorer the more it
        // did, which meant the correct play below was to move as little as
        // possible — on the plane the sign is supposed to be desperate to
        // *leave*. Terra takes Pisces' mobility instead: no multi-tile movement
        // without a full meter, and no way to fill one but water. See
        // `PiscesAridAquanaut` and `adjustedMovement`.
        return pool
    }
}

// MARK: - Passive 2: Gaia Geyser

/// Coming down on Terra brings your water with you — as your own charge, spilled
/// across the board.
///
/// ## Why a scatter rather than a gift
///
/// It used to ring the fish with eight droplets, one of which filled the meter
/// outright. That put the sign's most dramatic moment somewhere good: eight
/// places to stand, and taking one dismissed the other seven.
///
/// The trouble was what it made the *fall* mean. Arriving on Terra was the best
/// thing that could happen to Pisces — a full meter and a mended ring — on the
/// plane the whole sign is written to be desperate to leave. The scatter says
/// the opposite with the same drama: the charge you had is still yours, it is
/// simply all over the board now, and getting it back is the first thing you
/// have to do down here. Rings, deliberately.
///
/// It is also a real loss rather than a relocation. A pip whose square turns out
/// to be a hole is gone, so the more broken the ground below, the more the drop
/// actually costs — which is the shape the rest of the sign already has.
struct PiscesGaiaGeyser: ZodiacPassive {

    /// Lit for the whole time he is down there.
    ///
    /// The spill is one moment; what it *does* — no charge to be had on Terra —
    /// lasts as long as he stands on it, and that is the thing the mark is
    /// telling you about. Lighting it on the spill alone would light it once,
    /// for a frame, and never again while the rule it names was in force.
    func isLit(in context: PassiveContext) -> Bool { context.plane == .terra }

    let displayName = "Delta Distillation"
    let icon: String? = "pisces_distillation"
    let summary = "Draw Astral Energy from the surrounding plane. Your current ZC, however, is spilled upon landing on Terra, and Distillation requires greater effort there than on Astra."

    /// A dive is something the fish *did*. See
    /// `ZodiacPassive.fallIsControlled(to:context:)`.
    ///
    /// Only when it went down on purpose. Dropping through a floor that gave way
    /// is not a dive however good a swimmer you are, and the serene descent
    /// belonged to both until it had to sit next to a fish shedding its charge
    /// across the board like rings — which is not a picture of composure.
    func fallIsControlled(to plane: Plane, context: PassiveContext) -> Bool {
        plane == .terra && context.duringZodiaction
    }

    /// And the water goes everywhere when it wasn't.
    ///
    /// The two are one question asked twice: a controlled descent keeps its
    /// meter and its dignity, and an uncontrolled one loses both. See
    /// `GameEngine.scatterMeterAsBubbles(landingOn:clearOf:)`.
    func spillsMeterOnDescent(context: PassiveContext) -> Bool {
        !context.duringZodiaction
    }

    // The geyser's droplets are gone.
    //
    // Gaia Geyser is the spill now — the meter comes down as bubbles and that
    // is the whole passive. A second, unrelated payout for holes made this move
    // was the old design still running underneath the new one, which is how a
    // sign ends up with two things called the same name doing different jobs.

}

// MARK: - Passive 3: Arid Aquanaut

/// On Terra, charge is water and movement is a full meter.
///
/// Two halves of one idea. Z-Charge is struck from the pool outright — below,
/// the fish cannot pull charge out of dry air — and **bubbles** surface
/// alongside the Pentacle instead, several a phase, worth a pip each. That is
/// the whole of the sign's economy down here.
///
/// The other half is what the meter is *for*. Multi-tile movement wants a full
/// one — see `PiscesStarstreamSurfer` — so on Terra, where filling it means
/// gathering water a pip at a time, Pisces is locked to single steps until it
/// has. Being earthbound does not stop the fish surfing; it stops the fish
/// charging, and the surf follows.
///
/// ## Why this replaces a drain
///
/// The plane used to bill a pip for every move. That made the fish poorer the
/// more it did, so the correct play below was to sit still — on the plane the
/// sign is written to be desperate to leave. Taking mobility instead points the
/// player at the exit rather than away from it: every bubble gathered is a step
/// closer to crossing the board again.
struct PiscesAridAquanaut: ZodiacPassive {

    /// Same span as Distillation, and for the same reason: dry ground is the
    /// condition, not an event on it.
    func isLit(in context: PassiveContext) -> Bool { context.plane == .terra }

    let displayName = "Arid Aquanaut"
    let icon: String? = "pisces_aquanaut"

    /// Terra only. Up in the current there is no drought to show.
    func icon(on plane: Plane) -> String? { plane == .terra ? icon : nil }
    let summary = "Pisces struggles to flow as freely on Terra, preventing multi-tile movement unless charged with ZC"

    /// Z-Charge does not exist down here.
    ///
    /// Not made rarer — **removed**. Charge on Terra comes from water and from
    /// nothing else, and a coin that hands you a meter would be the fish pulling
    /// it out of dry air, which is the exact thing this plane takes away. The
    /// Tear takes the weight it leaves behind, so the pool stays the same size.
    func pickupChance(_ base: Int, for id: PickupID, context: PassiveContext) -> Int {
        guard context.plane == .terra else { return base }

        switch id {
        case .zCharge: return 0
        case .restoreTile: return base + PickupCatalog.effect(for: .zCharge).chance
        default: return base
        }
    }

    /// Bubbles surface wherever the sparkles were.
    ///
    /// This is the whole of Pisces' charge below, so it is generous per phase
    /// and small per bubble — the sign's problem on Terra is a long errand
    /// rather than a lucky break. Scaled by the run's luck in the engine, which
    /// is how Sagittarius' Fortunate Find reaches them.
    func bubbleChance(context: PassiveContext) -> Double {
        context.plane == .terra ? GameRules.bubbleSpawnChance : 0
    }

    /// **The fish is wet, so the ground it crosses is watered rather than worn.**
    ///
    /// Cover is fed by him instead of being spent — see `WearCause.water`. The
    /// tile underneath still takes what his weight deals; what changes is that
    /// grass survives him and flowers where he has been.
    func modifyWear(_ proposal: WearProposal, context: PassiveContext) -> WearProposal {
        // **Only when the water is doing the moving, and a slide is what that
        // means.**
        //
        // `travelsTheGround` also covers a charge and being blown, neither of
        // which is water — so a water sign shoved by the wind was still sparing
        // the grass. The three abilities this is for are the scuttle, the surf
        // and the Brook, and all three are slides. An ordinary hop is the animal
        // landing with its whole weight, and that wears cover like anyone
        // else's.
        guard proposal.moveType == .slide else { return proposal }

        var wet = proposal
        wet.caused(by: .water)
        return wet
    }


}

// MARK: - Zodiaction: Current

/// *Provisional name for the pair.* Two entirely different effects sharing one
/// meter, split by plane.
///
/// - **Terra — Upstream:** swim back up to Astra, punching through the cloud
///   directly overhead and surfacing one square along from it. The only
///   self-sufficient ascent in the game; every other route needs the Nexys.
///   It cannot be used on the same turn as the fall that brought you down, so a
///   descent always costs at least one turn on Terra — and the hole it leaves
///   means Pisces never returns to an unbroken Astra.
///
///   That the meter is no longer full by the time the turn passes is
///   **deliberate**, not an oversight: Gaia Geyser fills it on the descent and
///   Astral Attunement immediately starts draining, so Upstream is not simply
///   there for the taking. The way back to full is Z-Charge, which nets +2 on
///   Terra — three collected against the one pip the move costs. Do not "fix"
///   this by exempting a move from the drain.
/// - **Astra — Surging Stream:** the fish leaps, comes down *through* the cloud,
///   and lands on Terra — setting off Gaia Geyser on the way — leaving a pool of
///   standing water on the square it hits.
///
///   The old Astra half was the Astral Brook run from the meter, which is now
///   ordinary movement (`PiscesStarstreamSurfer`) and had nothing left to be a
///   super. This is the other thing water does: it goes down, and it stays.
struct PiscesSurgingStream: Zodiaction {

    let displayName = "Surging Stream"

    /// The two halves, by plane.
    ///
    /// Kept apart from `displayName` rather than folded into it: they are what
    /// the ability *is* on each plane, and the panel will want them set smaller
    /// under the name once the bottom display is revamped for larger text.
    let subtitle = "Upstream / Downstream"
    let summary = "Terra: surface on Astra one square along, holing the cloud you came through. Astra: dive through the cloud to Terra, leaving a pool where you land."

    /// Pisces' charge comes entirely from Starstream Surfer and Gaia Geyser.
    func meterGain(from move: MoveSummary, context: PassiveContext) -> Int { 0 }

    /// A deeper meter below, and the number is the sign's own.
    ///
    /// Twelve rather than ten, on Terra alone. Everything down there is paid for
    /// in bubbles a pip at a time, and the meter is not just the super any more
    /// — it is the surf, and the way home. Making it two pips deeper is the
    /// difference between a short errand and a real one, without touching what
    /// a bubble is worth.
    ///
    /// Twelve because there are twelve signs. Fifteen would have done the same
    /// job and meant nothing.
    func meterMax(on plane: Plane) -> Int {
        plane == .terra ? GameRules.piscesTerraMeterMax : meterMax
    }

    /// Upstream refuses on the turn the fall brought Pisces down: a descent has
    /// to cost at least one turn on Terra. Downstream has no such condition.
    func canActivate(context: PassiveContext) -> Bool {
        guard context.plane == .terra else { return true }
        return context.moveCount > context.signState.planeArrivalMove
    }

    func activate(context: PassiveContext, generator: inout SeededRandom) -> [GameEvent] {
        switch context.plane {
        case .terra: return upstream(context)
        case .astra: return downstream(context)
        }
    }

    // MARK: Terra — Upstream

    private func upstream(_ context: PassiveContext) -> [GameEvent] {
        let origin = context.piecePoint

        // Brook rules at a wall: surfacing forward would put the fish off the
        // board, so it comes up the other way instead — still one square, never
        // straight up.
        var heading = context.facing
        if !context.currentBoard.contains(origin.offset(by: heading.unitOffset)) {
            heading = context.facing.opposite
        }
        let surface = origin.offset(by: heading.unitOffset)
        guard context.currentBoard.contains(surface) else { return [] }

        var events: [GameEvent] = []
        if heading != context.facing {
            events.append(.pieceTurned(to: heading))
        }

        // Punch through the cloud directly overhead. That hole is the price:
        // Pisces never returns to an unbroken Astra, and the way back up is
        // always visible in the board afterwards.
        //
        // Skipped over the island, which is not cloud and cannot be swum
        // through — there the fish simply surfaces beside it.
        if origin != GameRules.nexysPoint {
            events.append(.tileDamaged(plane: .astra, point: origin, to: .hole))
        }

        // Then up and one square along, so the piece emerges next to the hole it
        // just made rather than hovering over it.
        events.append(
            .pieceMoved(
                from: origin,
                to: surface,
                fromPlane: .terra,
                toPlane: .astra,
                // Not a warp. The fish swims up and breaks the surface, which is
                // a different picture from blinking out and in — and the one
                // ascent in the game nobody needs the island for.
                type: .rise
            )
        )

        return events
    }

    // MARK: Astra — Downstream

    /// Up, through the cloud, and down onto Terra — leaving water behind.
    ///
    /// ## Why it is a dive rather than a fall
    ///
    /// Falling through Astra is what happens to Pisces when a tile gives out.
    /// This is the same journey made on purpose, and the difference has to be
    /// visible: the fish hops *up* first and comes down through its own square,
    /// which stays whole. Nothing is broken to get down there.
    ///
    /// Gaia Geyser fires off the arrival like any other descent, so the spill
    /// is waiting when the fish lands.
    ///
    private func downstream(_ context: PassiveContext) -> [GameEvent] {
        let landing = context.piecePoint

        // Refuses over the chasm: there is no Terra square under the island's
        // gap to come down on, and water cannot pool in a hole that is not
        // there.
        guard let below = context.boardBelow, below.contains(landing) else { return [] }
        guard below[landing].kind == .normal else { return [] }

        return [
            // The descent proper. `pieceFell` rather than a teleport, so
            // everything that watches for an arrival on Terra — Gaia Geyser
            // above all — sees exactly what it expects.
            // No pool. The rework left Pisces with bubbles and nothing else,
            // and standing water was the last piece of the version before it.
            .pieceFell(from: .astra, to: .terra, at: landing),
        ]
    }
}
