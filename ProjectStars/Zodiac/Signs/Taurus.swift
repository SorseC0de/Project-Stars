//
//  Taurus.swift
//  Project Stars
//
//  ♉ Taurus — The Bull
//
//  Everything specific to this sign lives in this file. Taurus is an earth
//  sign, so it is stronger on **Terra** and weaker on **Astra**.
//

import SwiftUI

// MARK: - Definition

extension ZodiacCatalog {

    /// ♉ Taurus — The Bull. Earth, Apr 20 – May 20. Strong on Terra.
    static let taurus = ZodiacDefinition(
        sign: .taurus,
        displayName: "Taurus",
        glyph: "♉",
        element: .earth,
        accentColor: Color(hex: 0x7A_9E_4C),
        movement: .cardinalStep,
        passives: [
            TaurusHooves(),
            TaureanTear(),
            TaurusStubbornStatue(),
        ],
        zodiaction: TaurusFloweringFlop(),
        constellation: ZodiacCatalog.taurusConstellation
    )

    /// ♉ Taurus: the V of the Hyades, with the horns running off it.
    static let taurusConstellation = Constellation(
        stars: [
            Constellation.Star(-1.10,  0.85,  0.10, 0.8),
            Constellation.Star(-0.55,  0.25,  0.20, 0.9),
            Constellation.Star( 0.00, -0.35,  0.00, 1.5),
            Constellation.Star( 0.55,  0.20, -0.20, 0.9),
            Constellation.Star( 1.10,  0.80, -0.10, 1.1),
            Constellation.Star(-0.30, -0.95,  0.30, 0.7),
            Constellation.Star( 0.35, -0.90, -0.25, 0.7),
        ],
        lines: [(0, 1), (1, 2), (2, 3), (3, 4), (2, 5), (2, 6)]
    )
}

// MARK: - Passive: Heavy Hooves / Hydroponic Hooves

/// The same weight, read two ways depending on what is underfoot.
///
/// On Astra the bull is far too heavy for cloud: every landing takes two stages
/// instead of one, so Taurus wrecks the upper board twice as fast as anyone.
/// On Terra — solid ground it belongs on — it takes two footfalls to move a tile
/// one stage, making it the most durable sign down there.
///
/// The Terra half needs memory, since "two footfalls" spans moves. The first
/// footfall is recorded in `SignState.partialWear` and the second spends it.
///
/// - Note: The design names this differently per plane — Heavy Hooves above,
///   Hydroponic Hooves below. `displayName` is one string, so it carries both; if
///   panel should show only the current one, that is a UI change, not a rules
///   change.
struct TaurusHooves: ZodiacPassive {

    let displayName = "Heavy / Hydroponic Hooves"
    let icon: String? = "taurus_heavy_hooves"

    /// Heavy above, Hydroponic below — the two halves of the note on this struct.
    func icon(on plane: Plane) -> String? {
        plane == .astra ? "taurus_heavy_hooves" : "taurus_hydro"
    }
    let summary = "Astra: landings damage 2 stages. Terra: arriving greens the whole board, and grass takes a hit before the ground does."

    /// **The invisible counter became the grass.**
    ///
    /// Terra used to run a hidden per-tile tally — the first landing scuffed a
    /// square and dealt nothing, the second damaged it — and nothing on screen
    /// said which squares were already scuffed. `GroundCover` is that rule made
    /// of pixels: cover takes the first hit and disperses, so the free footfall
    /// is a thing you can see and count.
    ///
    /// Which is why there is no Terra branch here any more. The halving is not
    /// Taurus' private arrangement with the engine, it is a property of grass,
    /// and it now works for anyone standing on some.
    ///
    /// The trade is real. The old counter renewed itself on every tile forever;
    /// grass is spent when it is used, so she is protected only where something
    /// is actually growing — which is what the rest of her kit is now for.
    func modifyWear(_ proposal: WearProposal, context: PassiveContext) -> WearProposal {
        var hooves = proposal
        // One cause; it knows what it weighs on each plane.
        hooves.caused(by: .hooves)
        return hooves
    }

    /// Greens Terra on arrival, outward from where she lands.
    ///
    /// Two ways to arrive, and they are deliberately not the same moment:
    ///
    /// - **Falling** from Astra. The wave starts where she lands.
    /// - **Stepping off the Nexys.** Riding the island down is not arriving —
    ///   she is still standing on it, above the ground — so the field waits for
    ///   the first square she actually puts a hoof on.
    ///
    /// Holes are skipped: there is nothing there to grow on. Flowers are left
    /// alone — the Flop and the Bloom leave something prettier behind and it is
    /// worth exactly the same, so overwriting it would be a downgrade with no
    /// upside.
    /// She grows things out of Astral water, and is charged for it — see
    /// `GameEngine.hydroponicCost()`.
    func growsOnWater(context: PassiveContext) -> Bool { true }

    /// **The Brook waters the square she is standing on.**
    ///
    /// She cannot be carried by it — `TaurusStubbornStatue` sees to that — but
    /// she still pulled the coin, and water is water: bare ground greens and
    /// grass flowers under her. It is the only water she has access to, which
    /// is what makes the hydroponic name mean something rather than being a
    /// flavour word.
    private func drink(from events: [GameEvent], context: PassiveContext) -> [GameEvent] {
        let pulled = events.contains { event in
            if case let .pickupCollected(id, _, _) = event { return id == .astralBrook }
            return false
        }
        guard pulled, context.plane == .terra else { return [] }

        let point = context.piecePoint
        let board = context.currentBoard
        guard board.contains(point), !board[point].health.isHole else { return [] }

        let fed = GroundCover.watered(
            board[point].cover, at: point, seed: context.moveCount
        )
        guard fed != board[point].cover else { return [] }

        return [.tileCoverChanged(plane: .terra, point: point, to: fed)]
    }

    func amend(_ events: [GameEvent], context: PassiveContext) -> [GameEvent] {
        let drank = drink(from: events, context: context)
        guard drank.isEmpty else { return drank }

        guard let landing = Self.arrivalOnTerra(in: events) else { return [] }

        return GroundWave(
            origin: landing,
            plane: .terra,
            touches: { tile, _ in !tile.health.isHole },
            cover: { tile, point in
                tile.cover == .flowers
                    ? nil
                    : GroundCover.ordinary(at: point, seed: landing.x &* 31 &+ landing.y)
            }
        )
        .plan(on: context.currentBoard)
    }

    /// Where she just set foot on Terra, if this move is an arrival.
    private static func arrivalOnTerra(in events: [GameEvent]) -> GridPoint? {
        for event in events {
            switch event {
            case let .pieceFell(_, to, at) where to == .terra:
                return at
            // Off the island and onto the ground. `nexysPoint` is where the
            // island always stands, so leaving that square for another one on
            // Terra is the step this waits for.
            case let .pieceMoved(from, to, _, toPlane, _, _, _)
                where toPlane == .terra && from == GameRules.nexysPoint && to != from:
                return to
            default:
                continue
            }
        }
        return nil
    }
}

// MARK: - Passive 2: Taurean Tear

/// An Astral Tear mends a second tile as well.
///
/// Named for the coin it doubles, and for the animal: the bull is the earth
/// sign that *keeps* ground rather than crossing it, and the commonest coin in
/// the game being worth twice as much is a quiet, permanent advantage rather
/// than a burst of one.
///
/// ## Why only the Tear
///
/// Not every heal. Astral Blossom already repairs a 3x3 and Polaris mends a
/// whole plane; doubling those would be doubling an area effect, which is a
/// different and much larger thing. The Tear repairs exactly one tile, and this
/// makes it two — the smallest heal in the game, made the second smallest.
///
/// ## Why it is `amend` rather than part of the coin
///
/// The coin knows nothing about who opened it, and should not. This watches the
/// move for a Tear being collected and adds its own repair afterwards, which is
/// the same hook Gemini mirrors with. Its output is not itself amended, so it
/// cannot chain.
struct TaureanTear: ZodiacPassive {

    let icon: String? = "taurus_tear"
    let displayName = "Taurean Tear"
    let summary = "Astra & Terra: an Astral Tear leaves grass growing where it mended."

    /// **Grass, not a third tile.**
    ///
    /// It used to mend an extra square, and it was gated twice over: a coin
    /// flip, *and* there still being a third damaged tile left after the Tear
    /// had already fixed two. Both conditions were invisible, and two invisible
    /// gates in series is why it read as never firing at all.
    ///
    /// One thing that always happens beats two things that sometimes do. The
    /// Tear mends what it mends and the bull leaves the ground green behind
    /// her — worth a stage the next time anything stands there, and it folds
    /// her into the kit the rest of her passives now share rather than being a
    /// private arrangement with one coin.
    func amend(_ events: [GameEvent], context: PassiveContext) -> [GameEvent] {
        for event in events {
            guard case let .pickupCollected(id, plane, point) = event,
                  id == .restoreTile
            else { continue }

            // Where the coin was taken, which is the square the Tear is
            // guaranteed to have mended. The other one it picks is random and
            // is not hers to decorate.
            guard context.currentBoard.contains(point),
                  !context.currentBoard[point].health.isHole,
                  context.currentBoard[point].cover == nil
            else { return [] }

            return [
                .tileCoverChanged(
                    plane: plane,
                    point: point,
                    to: GroundCover.ordinary(at: point, seed: context.moveCount)
                )
            ]
        }
        return []
    }
}

// MARK: - Passive 3: Greedy Gather

/// Charge for finding the coin on the first square you tried.
///
/// The bull does not hunt so much as *arrive*, and being right first time is
/// worth something. `collectedOnRevealTile` is the exact distinction: the
/// sparkle you landed on turned out to be the one hiding it, rather than the
/// coin being somewhere else in the set and walked to afterwards.
struct TaurusStubbornStatue: ZodiacPassive {

    let icon: String? = "taurus_statue"
    let displayName = "Stubborn Statue"
    let summary = "Astra & Terra: nothing moves you but you. A coin that would carry you plants ground cover instead, and costs 1 ZC."

    /// **The bull does not get carried.**
    ///
    /// Corner Warp, Astral Breeze, the Brook — every coin whose whole idea is
    /// putting the piece somewhere else simply does not, and roots her where
    /// she stands instead. It replaced Greedy Gather, which paid for guessing
    /// the sparkle right and was three quarters of Virgo's snipe wearing a
    /// different hat.
    ///
    /// It is a trade, not an immunity: she loses the free rides — a Breeze
    /// across the board is real distance — and pays a pip for refusing. What
    /// she buys is a board that cannot be rearranged around her, which for the
    /// sign whose entire identity is *keeping* ground is the characterisation
    /// doing the mechanical work.
    func resistsBeingMoved(context: PassiveContext) -> Bool { true }
}

// MARK: - Zodiaction: Flowering Flop

/// Drops the bull's full weight through the floor, and mends what it lands on.
///
/// - **On Astra** it stops pretending the clouds can hold it: Taurus punches
///   straight down to Terra, and the tile it comes down on is fully restored by
///   the impact. If the square below is already open, nothing catches the fall
///   and the run ends — this is a committed, unrecoverable move.
/// - **On Terra**, with nowhere left to fall, the impact spreads instead:
///   everything in the 3x3 around Taurus is fully restored, holes included. That
///   is the only effect in the game that closes several holes at once.
struct TaurusFloweringFlop: Zodiaction {

    let displayName = "Flowering Flop"
    let summary = "Astra: crash to Terra, fully mending the tile below (fatal if it is open). Terra: fully mend the 3x3 around you."

    /// Taurus has no charge rule of its own — by design it fills its meter only
    /// from Pentacles, which makes every pop a deliberate resource decision.
    func meterGain(from move: MoveSummary, context: PassiveContext) -> Int { 0 }

    func activate(context: PassiveContext, generator: inout SeededRandom) -> [GameEvent] {
        switch context.plane {
        case .astra: return flopThroughAstra(context)
        case .terra: return flopOnTerra(context)
        }
    }

    // MARK: Astra

    private func flopThroughAstra(_ context: PassiveContext) -> [GameEvent] {
        guard let below = context.boardBelow else { return [] }
        let point = context.piecePoint

        var events: [GameEvent] = [
            .pieceFell(from: .astra, to: .terra, at: point)
        ]

        // Leaving Astra restores it, exactly as an ordinary descent does.
        if GameRules.astraRestoresOnDescent {
            events.append(.planeRestored(plane: .astra))
        }

        // Nothing below to mend and nothing to stand on: the flop is fatal.
        guard below[point].kind == .normal else {
            events.append(.gameOver(reason: .fellThroughTerra))
            return events
        }

        // **Falling the whole way hits harder: the 3x3 and the ring around it.**
        //
        // Twenty-five squares against Terra's nine. She has fallen through a
        // plane to get here, and the Astra flop was mending exactly one tile —
        // the version you would never choose. Everything it reaches is mended
        // and flowered in the same breath, as one `groundSwept`.
        var health: [GridPoint: TileHealth] = [:]
        var flowers: [GridPoint: GroundCover?] = [:]

        for square in point.surrounding(radius: 2, includingSelf: true)
        where below.contains(square) && below[square].kind == .normal {
            if below[square].health != .healthy { health[square] = .healthy }
            flowers[square] = .flowers
        }

        if !health.isEmpty || !flowers.isEmpty {
            events.append(.groundSwept(plane: .terra, health: health, cover: flowers))
        }

        // **The Essence, not the coin.**
        //
        // She has fallen the whole way through Astra and the energy she passed
        // through is still on her, so the buff and its icon are simply *set* —
        // firing the Pentacle instead would throw its splash and its banner
        // across the screen and announce a coin nobody picked up.
        var state = context.signState
        state.astralEssenceMoves = max(
            state.astralEssenceMoves, GameRules.essenceMoves
        )
        events.append(.signStateChanged(state))

        return events
    }

    // MARK: Terra

    private func flopOnTerra(_ context: PassiveContext) -> [GameEvent] {
        let touched = context.piecePoint.neighbourhood(includingSelf: true)
            .filter { context.currentBoard.contains($0) }
            .filter { context.currentBoard[$0].kind == .normal }

        // One impact, so one event — see `GameEvent.tilesChanged`.
        let changes = touched
            .filter { context.currentBoard[$0].health != .healthy }
            .reduce(into: [GridPoint: TileHealth]()) { $0[$1] = .healthy }

        // **One event: the ground and what grows on it, together.**
        //
        // Emitting the heal and then a flower per square played the bloom a
        // beat late, because every event in a plan is animated in turn and the
        // heal holds the board for its own duration first. `groundSwept` is the
        // pair — the same event a wave uses — so the impact lands as one thing.
        //
        // Flowers reach every square it touched, mended or not: the heal only
        // reaches damaged ground, and a bare healthy tile in the middle of a
        // flowered patch reads as having been missed.
        let flowers = touched.reduce(into: [GridPoint: GroundCover?]()) {
            $0[$1] = .flowers
        }

        guard !changes.isEmpty || !flowers.isEmpty else { return [] }
        return [.groundSwept(plane: .terra, health: changes, cover: flowers)]
    }
}
