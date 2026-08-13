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
    let summary = "Astra: surf to the far wall on any turn, and charge \(GameRules.starstreamCharge) for doing it — ordinary steps give nothing. Terra: −1 charge for every square you leave."

    /// Terra has no current to ride.
    ///
    /// Arid Aquanaut *replaces* this below — that is the whole shape of the
    /// sign, rich and mobile up top and stranded down here — so the surf has to
    /// actually be gone rather than merely unrewarded. It was still offered on
    /// Terra, which handed the fish its best move on the plane it is supposed to
    /// be desperate to leave.
    func adjustedMovement(base: MovementPattern, context: PassiveContext) -> MovementPattern {
        guard context.plane == .terra else { return base }
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
            let surfed = move.origin.manhattanDistance(to: move.destination) > 1
            return pool + (surfed ? GameRules.starstreamCharge : 0)
        }

        // The drain does not apply to a move that ends in water.
        //
        // Otherwise the pool pays one and the plane takes it straight back, and
        // a foothold that nets zero is not a foothold — it is a square that
        // *isn't costing you*, which nobody walks across a dry board for. The
        // spec is 0 to 1: the pool is worth a pip after the toll, not instead
        // of a pip.
        if inPool { return pool }
        return move.startingPlane == .terra ? -1 : 0
    }
}

// MARK: - Passive 2: Gaia Geyser

/// Coming down on Terra brings the water with you: eight droplets ring the fish
/// where it lands, and every square one settles on is mended a stage — holes
/// included.
///
/// ## Why droplets rather than a number
///
/// The old version simply filled the meter on arrival, which was correct as
/// balance and dead as a moment: the most dramatic thing Pisces does produced a
/// bar going up. The ring puts the same value on the board as eight places to
/// stand, and taking one dismisses the other seven — so arriving on Terra is now
/// a decision about *where*, made at exactly the moment the fish has the most to
/// spend and the least time to spend it.
///
/// ## The arithmetic is unchanged
///
/// A droplet is a full meter and the move that collects it drains one on the way
/// out, so the fish stands up on nine. That is precisely where the old
/// fill-on-arrival left it after its first step, which is the number everything
/// downstream was tuned against.
///
/// ## Why the mending reaches holes
///
/// Water finds the low ground. A hole mended to badly cracked is still a bad
/// square, but it is a square — and it means a fall into a wrecked corner of
/// Terra leaves the fish with somewhere to go rather than nowhere.
struct PiscesGaiaGeyser: ZodiacPassive {

    let displayName = "Gaia Geyser"
    let summary = "Astra → Terra: arriving rings you with droplets, mending each square they land on. Take one for a full meter; the rest dry up."

    /// The fish dives. See `ZodiacPassive.fallIsControlled(to:context:)`.
    func fallIsControlled(to plane: Plane, context: PassiveContext) -> Bool {
        plane == .terra
    }

    func amend(_ events: [GameEvent], context: PassiveContext) -> [GameEvent] {
        guard arrived(in: events, context: context) else { return [] }

        let board = context.currentBoard
        let ring = GridOffset.cardinals + GridOffset.diagonals

        var produced: [GameEvent] = []
        for square in ring.map({ context.piecePoint.offset(by: $0) })
        where board.contains(square) && board[square].kind == .normal {

            // The water mends as it lands, one stage, holes included.
            if board[square].health != .healthy {
                produced.append(
                    .tileHealed(plane: context.plane, point: square, to: board[square].health.healed)
                )
            }
            produced.append(
                .pickupRevealed(id: .gaiaDroplet, plane: context.plane, point: square)
            )
        }
        return produced
    }

    /// True when this move is the one that brought the fish down.
    ///
    /// Read off the events rather than from a `MoveSummary`, because `amend` is
    /// the only hook that runs late enough to place things on the board and it
    /// is handed the events instead. A fall to Terra is the one that counts;
    /// bouncing around down there is not.
    private func arrived(in events: [GameEvent], context: PassiveContext) -> Bool {
        guard context.plane == .terra else { return false }
        return events.contains { event in
            switch event {
            case let .pieceFell(_, to, _): to == .terra
            case let .pieceTeleported(_, _, from, to): from == .astra && to == .terra
            case let .nexysMoved(to, carrying): to == .terra && carrying
            default: false
            }
        }
    }
}

// MARK: - Passive 3: Arid Aquanaut

/// On Terra, charge is what the board offers up.
///
/// Z-Charge and the Astral Tear trade places in the roll, so the commonest find
/// below is the one that fills the meter rather than the one that mends a tile.
///
/// ## Why this completes the sign
///
/// Everything else about Pisces on Terra is a countdown: Gaia Geyser hands it a
/// full meter on arrival and Astral Attunement drains a pip for every square it
/// leaves. Upstream costs the whole meter, so the way home is only ever reached
/// by finding charge — and a fish that has to go looking for it in a dry place is
/// the whole picture of the sign down there.
///
/// It mends nothing extra. Pisces on Terra is not supposed to be comfortable; it
/// is supposed to be leaving.
///
/// ## How the swap is written
///
/// By reading each other's weights rather than naming numbers, so retuning
/// either one keeps the swap honest.
struct PiscesAridAquanaut: ZodiacPassive {

    let displayName = "Arid Aquanaut"
    let summary = "Terra: Z-Charge and Astral Tear trade drop rates, and Z-Charge grants \(GameRules.aridAquanautCharge) instead of \(GameRules.zChargePentacleAmount)."

    func pickupWeight(_ base: Int, for id: PickupID, context: PassiveContext) -> Int {
        guard context.plane == .terra else { return base }

        switch id {
        case .zCharge: return PickupCatalog.effect(for: .restoreTile).weight
        case .restoreTile: return PickupCatalog.effect(for: .zCharge).weight
        default: return base
        }
    }

    /// And a Z-Charge found down there is worth more than it is to anyone else.
    ///
    /// Making it *common* was not enough on its own. A coin can spawn across the
    /// board, and the walk to it costs a pip a square — so an ordinary grant can
    /// arrive having already paid for itself, and a run of distant spawns leaves
    /// the meter falling however many coins are opened. The larger grant is what
    /// makes the trip worth taking.
    func chargeFromPickup(_ base: Int, id: PickupID, plane: Plane) -> Int {
        guard plane == .terra, id == .zCharge else { return base }
        return GameRules.aridAquanautCharge
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
            .pieceTeleported(from: origin, to: surface, fromPlane: .terra, toPlane: .astra)
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
    /// Gaia Geyser fires off the arrival like any other descent, so the ring of
    /// droplets is waiting when the fish lands.
    ///
    /// ## The pool
    ///
    /// The water the fish came down in stays where it hit. It is not ground and
    /// cannot be worn or mended, it pays a pip to anything standing in it, and
    /// it lasts until Pisces leaves the plane, stops being Pisces, or something
    /// burns it off. On a plane that drains a pip for every square you leave,
    /// somewhere that pays one back is a place worth walking to.
    private func downstream(_ context: PassiveContext) -> [GameEvent] {
        let landing = context.piecePoint

        // Refuses over the chasm: there is no Terra square under the island's
        // gap to come down on, and water cannot pool in a hole that is not
        // there.
        guard let below = context.boardBelow, below.contains(landing) else { return [] }
        guard below[landing].kind == .normal || below[landing].kind == .pool else { return [] }

        return [
            // The descent proper. `pieceFell` rather than a teleport, so
            // everything that watches for an arrival on Terra — Gaia Geyser
            // above all — sees exactly what it expects.
            .pieceFell(from: .astra, to: .terra, at: landing),
            .poolFormed(plane: .terra, point: landing),
        ]
    }
}
