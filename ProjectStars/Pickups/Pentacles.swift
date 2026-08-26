//
//  Pentacles.swift
//  Project Stars
//
//  Every Pentacle: what it is, how often it turns up, and what it does.
//

import Foundation

//  ─────────────────────────────────────────────────────────────────────────
//  ADDING A PENTACLE
//
//  Everything needed lives in this file, on purpose. Three steps, in order:
//
//    1. A case in `PickupID`, under the rarity it belongs to.
//    2. A `PickupEffect` struct further down, in the same order.
//    3. A line in `PickupCatalog.allEffects`.
//
//  Miss step 3 and `PickupCatalog.effect(for:)` traps on first use rather than
//  failing quietly — the id exists but nothing implements it, and that is worth
//  finding immediately.
//
//  The protocol these conform to, and the context they are handed, are in
//  `PickupEffect.swift`. That file is the machinery; this one is the content.
//  ─────────────────────────────────────────────────────────────────────────

// MARK: - PickupID

/// Stable identifier for every Pentacle effect in the game.
///
/// State stores this rather than the effect object, which keeps the engine
/// `Equatable` and `Codable` and makes save/replay straightforward. Look the
/// behaviour up through `PickupCatalog.effect(for:)`.
///
/// - Note: Names marked provisional in the design are marked here too. Renaming
///   a case changes its `rawValue`, which is both the asset suffix and the
///   `PentacleCodex` storage key — so a rename also resets that effect's
///   first-encounter prompt. That is usually what you want during design.
enum PickupID: String, CaseIterable, Codable, Identifiable, Hashable {

    // MARK: Common

    /// *Provisional name.* Grants a flat amount of Zodiaction charge.
    case zCharge

    /// *Provisional name.* Fully repairs one random damaged tile on this plane.
    case restoreTile

    // MARK: Uncommon

    /// Astral Essence — Water. Slides you to the border, damaging as you go.
    case astralBrook

    /// Astral Essence — Air. Teleports you to a tile of your choosing.
    case astralBreeze

    /// Astral Essence — Fire. Damages the 3x3 around you, paying out charge.
    case astralBlaze

    /// Astral Essence — Earth. Repairs the 3x3 around you.
    case astralBlossom

    /// Astral Essence — the fifth. Storms your row and column, and fills the
    /// meter. See `AstralBoltEffect`.
    case astralBolt

    /// *Provisional name.* Teleports you to a random corner, safe or not.
    case cornerWarp

    /// Brings the island to your plane, or warps you onto it if it is already
    /// there.
    case nexysShift

    /// See `_Design/project-stars-pickups-backlog.md` for all five below.
    case stardar

    case nexyialBastion

    case matchShiftMiasma

    case stellunaSprite

    case polarityProngs

    // MARK: Rare

    /// Changes your piece to a random other sign, whether you like it or not.
    case forcedFate
    case zodaemoniteSkull

    /// Lets you choose a new sign — including the one you already have.
    case alignment

    /// A mist that drains a pip a step. Scorpio drinks it the other way up.
    case unknownEssence

    /// The same thing, right way up, and Astra's alone.
    case astralEssence

    /// A small earthquake. Terra only — there is no ground to crack above.
    case trivialTremor

    /// A large one.
    case seismicShakedown

    // MARK: Legendary

    /// Only ever spawns from a sparkle on the north-middle tile.
    case polaris

    /// Spawns a mirrored shadow of your piece.
    case shadowWork

    // MARK: Not a Pentacle

    /// A droplet from Pisces' Gaia Geyser. Never rolled — see
    /// `GaiaDropletEffect`.
    case gaiaDroplet

    /// A bubble of Pisces' own water, on Terra. Never rolled into the hunt —
    /// see `BubbleEffect` and `PiscesAridAquanaut`.
    case bubble

    /// Libra's slab of ground. Takes the Nexys Shift's place in the roll while
    /// she is playing — see `LibraJudicatorElevator` and `GaleforceGavelEffect`.
    case galeforceGavel

    /// The only thing Virgo's Regulated Reboot ever deals. Never rolled — see
    /// `VirgoVictorylapEffect`.
    case virgoVictorylap

    var id: String { rawValue }
}

/// What Virgo's Regulated Reboot deals, and the only thing it deals.
///
/// - TODO: **Not the final name.**
///
/// Mends the square it was sitting on and hands the whole meter back. Both
/// halves matter and neither is the reward on its own: the meter is what makes
/// guessing right worth the guess, and the mend is what lets the ring be thrown
/// over broken ground at all. Step onto the hole that held it and the hole is
/// gone before you can fall into it — coins are opened inside `settle`, ahead
/// of the ground check, which is the same ordering that lets an Astral Tear
/// save a landing.
///
/// Authored at zero because it is never rolled. It is *placed*, by
/// `GameEngine.drawPickup(at:on:)`, on any square of a `.ring` sparkle set —
/// and the ring is Virgo's alone. That is why this is a coin rather than a
/// clause inside the Zodiaction: the Reboot lights squares and walks away, and
/// what a square turns out to hold is a question the catalogue already answers
/// for everything else in the game.
struct VirgoVictorylapEffect: PickupEffect {

    let id: PickupID = .virgoVictorylap

    func plan(
        context: PickupContext,
        choice: PickupChoiceResult?,
        generator: inout SeededRandom
    ) -> [GameEvent] {
        var events: [GameEvent] = []

        // **Where the coin was**, which is where she is now standing.
        //
        // Healed unconditionally rather than through `repairablePoints`: that
        // list is about what a *repair* may touch, and it excludes nothing this
        // needs — but a hole is exactly the case this coin exists for, so it is
        // stated here rather than inherited from a rule written for a different
        // question.
        let here = context.piecePoint
        if context.currentBoard[here].health != .healthy {
            events.append(.tileHealed(plane: context.plane, point: here, to: .healthy))
        }

        // The whole thing, not a share of it. Guessing right is the hard part.
        let full = context.zodiactionMeterMax
        if context.zodiactionMeter != full {
            events.append(.zodiactionMeterChanged(to: full))
        }

        return events
    }
}

/// Grants a flat amount of Zodiaction charge.
///
/// The plainest effect in the game on purpose: it is the baseline the others are
/// measured against, and the one that makes a Pentacle worth taking even when
/// the board is in good shape.
struct ZChargeEffect: PickupEffect {

    let id: PickupID = .zCharge

    /// Commonest thing in the tier.
    func plan(
        context: PickupContext,
        choice: PickupChoiceResult?,
        generator: inout SeededRandom
    ) -> [GameEvent] {
        // The piece may value this differently — Pisces on Terra does.
        let amount = context.zodiac.definition.passives.chargeFromPickup(
            GameRules.zChargePentacleAmount,
            id: id,
            plane: context.plane
        )
        let target = context.meter(afterGaining: amount)
        guard target != context.zodiactionMeter else { return [] }
        return [.zodiactionMeterChanged(to: target)]
    }
}

/// One bubble of Pisces' own water, on Terra.
///
/// ## Why this is not a Pentacle
///
/// Because it is not part of the hunt. The hunt is one coin at a time, revealed
/// out of a sparkle phase that waits for it to be taken; bubbles appear
/// *alongside* that coin, several at once, and taking one leaves the rest — see
/// `PickupClass.scatter`. A Pentacle is a decision. A bubble is a errand.
///
/// ## Why Pisces needs them
///
/// Below, the fish charges from water and from nothing else: Z-Charge is struck
/// from the pool, ordinary steps pay nothing, and the meter is the only way back
/// to being gold — which is the only way to surf. So bubbles are the whole Terra
/// economy of the sign, and they are deliberately small: one pip each, three if
/// the bubble is the square you were already guessing at.
///
/// ## Why the snipe pays more
///
/// The sparkle phase asks one question — which of these squares is worth
/// reaching — and answering it correctly should pay whatever it turns out you
/// were reaching for. A bubble taken on the move it appeared is the same read as
/// a Pentacle taken that way, and the game already pays for that read.
///
/// ## The above is now a HIDDEN bonus
struct BubbleEffect: PickupEffect {

    let id: PickupID = .bubble

    /// Water settling on a square does not break it.
    let arrivalWearsTile = false

    func plan(
        context: PickupContext,
        choice: PickupChoiceResult?,
        generator: inout SeededRandom
    ) -> [GameEvent] {
        // One pip, and only one.
        //
        // The bonus for reaching a coin on the turn it appeared is **already a
        // rule of the game** — `GameRules.revealTileCharge`, paid by
        // `resolvePickupCollection` to any sign on any pickup. A second bonus
        // here was the same mechanic implemented twice, and the two stacked: a
        // sniped bubble paid its own three plus the house's one.
        let target = context.meter(afterGaining: GameRules.bubbleCharge)
        guard target != context.zodiactionMeter else { return [] }
        return [.zodiactionMeterChanged(to: target)]
    }
}

/// Fully repairs one randomly-chosen damaged tile on the plane the piece is on.
///
/// **Fully**, not by one step — a hole goes straight back to healthy. That makes
/// it worth taking on a board that has already broken rather than only on one
/// that is starting to.
///
/// On a plane with nothing left to fix it does not fizzle: it pays out a point
/// of Zodiaction charge instead, so a well-kept board never makes a Pentacle
/// feel wasted.
///
/// ## Hidden Fallback: if all Tiles are healthy on activation, gain 10 ZC instead
struct AstralTearEffect: PickupEffect {

    let id: PickupID = .restoreTile

    /// Two tiles: **here**, and one elsewhere.
    ///
    /// The one under your feet answers a real complaint. Testers kept being
    /// forced onto a crumbling tile because that is where the coin was, and
    /// then punished for it by falling — the board made them take a risk and
    /// then charged them for taking it. Healing where you stand means the tile
    /// you had to reach is the tile the coin repairs.
    ///
    /// It is also simply a bigger board than the one this borrows from. Knight
    /// Move had a single item, a one-tile repair, on a smaller grid; the same
    /// coin on a seven-square board mends a proportionally smaller share of it,
    /// so paying out twice keeps it worth what it used to be.
    ///
    /// The random half stays because a coin whose whole value you can see before
    /// taking it is a coin with no reason to be a surprise.
    ///
    /// The random one must be a **different** tile, or a coin taken while
    /// standing on the only damaged square would spend both halves on it and
    /// read as having done nothing. The Nexys and its chasm are structural and
    /// were never candidates — `repairablePoints` excludes them already.
    func plan(
        context: PickupContext,
        choice: PickupChoiceResult?,
        generator: inout SeededRandom
    ) -> [GameEvent] {
        let here = context.piecePoint
        var events: [GameEvent] = []

        if context.currentBoard.repairablePoints.contains(here) {
            events.append(.tileHealed(plane: context.plane, point: here, to: .healthy))
        }

        let elsewhere = context.currentBoard.repairablePoints.filter { $0 != here }
        if let target = elsewhere.randomElement(using: &generator) {
            events.append(.tileHealed(plane: context.plane, point: target, to: .healthy))
        }

        // Nothing left to mend anywhere: pay out as charge instead, which is
        // what it did before when the board was whole.
        guard events.isEmpty else { return events }

        let meter = context.meter(afterGaining: GameRules.defaultZodiactionMeterMax)
        guard meter != context.zodiactionMeter else { return [] }
        return [.zodiactionMeterChanged(to: meter)]
    }
}

/// Sweeps the piece along its facing to the far edge of the board, wearing every
/// tile it crosses.
///
/// The water essence: it *flows*. Holes do not stop it — the piece passes
/// straight over them — so the slide only ends at the border. But it is not
/// free: the square it comes to rest on is landed on like any other, so a border
/// tile that is already a hole drops the piece exactly as it would normally.
///
/// This is the one effect that lays down a line of damage across a whole rank or
/// file, which makes it a strong charge-builder for signs that pay out on wear
/// and a serious liability for anyone who needs the board intact.
struct AstralBrookEffect: PickupEffect {

    let id: PickupID = .astralBrook

    /// The slide applies its own wear square by square, so the engine must not
    /// charge the destination a second time on arrival.
    let arrivalWearsTile = false

    func plan(
        context: PickupContext,
        choice: PickupChoiceResult?,
        generator: inout SeededRandom
    ) -> [GameEvent] {
        Self.slide(
            on: context.currentBoard,
            plane: context.plane,
            from: context.piecePoint,
            facing: context.facing,
            floats: context.floatsOverHoles
        )
    }

    /// The slide itself, as its own function.
    ///
    /// Shared with Pisces' Downstream, which *is* this effect — one body rather
    /// than two that would drift apart the first time either was retuned.
    /// - Parameter floats: True for a piece that holes cannot drop and walls
    ///   cannot stop — Aquarius above zero. The current then reads the board
    ///   exactly the other way round: it **halts at the first hole** and runs
    ///   **past the border**.
    ///
    ///   Which turns the Brook from a free ride into the sign's most dangerous
    ///   coin, and is balanced by what the two stopping points cost. The border
    ///   is always there and always fatal; a hole is something you had to break
    ///   the board to make, and stopping short of one hands control back. So the
    ///   coin is a gamble whose odds you improve by wrecking the ground, which
    ///   is the one bargain this sign is built to want.
    static func slide(
        on board: Board,
        plane: Plane,
        from origin: GridPoint,
        facing: SwipeDirection,
        floats: Bool = false
    ) -> [GameEvent] {
        // Facing a wall, the water simply flows the other way. Without this the
        // effect is a dud whenever it is used on a border tile facing out —
        // which is common, since the border is where sliding tends to strand you.
        var heading = facing
        // A floating piece is never facing a wall — the border is somewhere it
        // can go — so the turn-around is for everyone else.
        if !floats, !board.contains(origin.offset(by: heading.unitOffset)) {
            heading = facing.opposite
        }
        let step = heading.unitOffset

        var events: [GameEvent] = []

        // Turn to face the way the water actually carries you. Without this the
        // piece arrives at the far wall still looking back the way it came, and
        // every facing-dependent thing that follows — the cursor, Libra's flanks,
        // Sagittarius' forward stride — reads the wrong direction.
        if heading != facing {
            events.append(.pieceTurned(to: heading))
        }

        var from = origin
        var point = from.offset(by: step)

        // Walk to the border, wearing **nothing on the way**.
        //
        // A slide touches its two ends and crosses everything between them —
        // `GameRules.slideWearsEndsOnly`, the same rule the engine's own
        // `travel` follows. This function is the one slide the engine does not
        // drive, so it has to keep that rule by hand or the Brook is the one
        // move in the game that still ploughs a furrow.
        if floats {
            // Carried until the ground opens. A hole is the only thing that
            // stops this, and there may not be one.
            while board.contains(point), board[point].isSolid {
                events.append(.pieceSlid(from: from, to: point, plane: plane))
                from = point
                point = point.offset(by: step)
            }

            // Either a hole caught them, or the board ran out and they go one
            // square past it — which the landing turns into the end of the run.
            events.append(.pieceSlid(from: from, to: point, plane: plane))
            return events
        }

        while board.contains(point) {
            events.append(.pieceSlid(from: from, to: point, plane: plane))
            from = point
            point = point.offset(by: step)
        }

        // Arriving at the wall is an arrival, and it should land like one.
        //
        // The water carries you until there is no more board, which is a stop
        // rather than a destination — the same thing walking into a wall is, and
        // it reads as a bug when one of them thumps and the other does not.
        events.append(.moveBlocked(direction: heading))

        // The two ends. `from` is where the water finally set the piece down.
        for square in [origin, from] {
            events += board.wearEvents(at: square, on: plane, cause: .water)
        }

        return events
    }
}

/// Astral Bolt — the fifth Essence, and the one nothing is attuned to.
///
/// Lightning strikes the piece and it comes up invulnerable. For
/// `GameRules.starMoves` moves it wears no tile it lands on, falls through
/// nothing, and gains a pip of charge for every square it moves — and it walks
/// the whole time in gold, flickering between all four elemental colours with
/// Polaris' sparks around it.
///
/// ## Why it is purely positive
///
/// Because of how rare it is. An effect a player meets twice a year cannot ask
/// them to make a judgement call: they will not have the experience to make it,
/// and a rare thing that turns out to be a trap is a rare thing nobody wants to
/// find. This one is unambiguously the best moment in a run, which is the point
/// — it is meant to be the thing people tell each other about.
///
/// ## Why it lasts in moves rather than seconds
///
/// Everything in this game is move-based, but it matters more here: ten moves is
/// ten *decisions*, and the player spends them deliberately — crossing ground
/// they could not otherwise cross, standing where they could not otherwise
/// stand. On a clock it would be ten seconds of hurrying.
///
/// ## Why the star survives a piece change
///
/// It is a state of the player, not of the sign — see `SignState.starMoves`.
/// Take a Forced Fate mid-star and the star comes with you.
///
/// ## How it is rolled
///
/// Not by weight. `weight` is `0`, so it never appears in the ordinary draw;
/// the catalogue rolls it *inside* an Essence result — see
/// `PickupCatalog.rollPickup`. So the odds of drawing "an Essence" are exactly
/// what they were, and this only decides which one turned up. At
/// `GameRules.astralBoltChance` that is roughly one coin in four hundred: many
/// full games between sightings, which is the intent.
struct AstralBoltEffect: PickupEffect {

    let id: PickupID = .astralBolt

    /// Nothing is worn while the star runs anyway, but the coin's own square is
    /// the first thing that would have been.
    let arrivalWearsTile = false

    func plan(
        context: PickupContext,
        choice: PickupChoiceResult?,
        generator: inout SeededRandom
    ) -> [GameEvent] {
        var state = context.signState
        state.starMoves = GameRules.starMoves
        return [.signStateChanged(state)]
    }
}

/// Teleports the piece to any square on the current plane, chosen by the player.
///
/// The air essence: it *goes anywhere*. No restrictions at all — holes, the
/// Nexys, the chasm are all legal destinations, which makes this both the most
/// flexible escape in the game and a way to deliberately drop yourself to Terra
/// on your own terms.
///
/// Arriving is landing, so the destination is worn and every landing check runs:
/// pick a hole and you fall through it, pick the Terra Nexys and you ride it up.
struct AstralBreezeEffect: PickupEffect {

    let id: PickupID = .astralBreeze

    let choice: PickupChoice = .tile

    func plan(
        context: PickupContext,
        choice: PickupChoiceResult?,
        generator: inout SeededRandom
    ) -> [GameEvent] {
        guard case let .tile(destination) = choice,
              context.currentBoard.contains(destination)
        else { return [] }

        return [
            // Carried. The type is the Pentacle's to choose — nothing about
            // the sign being blown changes what a wind looks like.
            //
            // No `effect`: the gusts are the *presentation* of a long carry and
            // live in `GameSession.animateBlown`, which throws several staggered
            // copies rather than the one this would add on top.
            .pieceMoved(
                from: context.piecePoint,
                to: destination,
                fromPlane: context.plane,
                toPlane: context.plane,
                type: .blown
            )
        ]
    }
}

// MARK: - Stardar

/// Marks the sparkle that is holding the Pentacle, next glow phase.
///
/// The promise is kept the cheap way — the coin is *forced* onto the sparkle
/// that is wearing the marker, rather than the glow phase being rewritten to
/// pick its winner in advance. Both produce the same fact for the player: the
/// shining one is the one worth taking. See the note in
/// `_Design/project-stars-pickups-backlog.md`, which sanctions this.
/// - TODO: **Rebuild this.** As it stands it marks the next glow phase, which
///   is a phase you were going to get anyway — so it tells you nothing you
///   were not about to be told and the coin is effectively a blank.
///
///   What it should do: put the sparkles **where the Pentacle will actually
///   be**, and keep doing it outside the glow phase, for the next ten turns.
///   That turns it from a restatement of the hunt into a reason to change
///   route, which is what a coin at this rarity has to be worth.
struct StardarEffect: PickupEffect {

    let id: PickupID = .stardar

    func plan(
        context: PickupContext,
        choice: PickupChoiceResult?,
        generator: inout SeededRandom
    ) -> [GameEvent] {
        guard !context.signState.stardarPending else { return [] }

        var state = context.signState
        state.stardarPending = true
        return [.signStateChanged(state)]
    }
}

// MARK: - Nexyial Bastion

/// Astral energy leaves the island and shields one tile from its next blow.
///
/// **It negates rather than absorbs.** Ground cover takes one stage and steps
/// down; this refuses the whole hit however large it was, and is spent doing
/// so. Two different rules living in one engine on purpose — do not let either
/// borrow from the other.
///
/// With the island on the other plane there is nothing to emit from, so the
/// energy comes out of the hole it left behind and pays a pip instead.
struct NexyialBastionEffect: PickupEffect {

    let id: PickupID = .nexyialBastion

    func summary(in context: PickupSummaryContext) -> String {
        context.nexysPlane == context.plane
            ? summary
            : "Dregs of Astral Energy emit from where the Nexys once was and may someday be again."
    }

    func plan(
        context: PickupContext,
        choice: PickupChoiceResult?,
        generator: inout SeededRandom
    ) -> [GameEvent] {
        // The island is elsewhere: the dregs reach the player instead.
        guard context.nexysPlane == context.plane else {
            let paid = context.meter(afterGaining: GameRules.bastionConsolationCharge)
            return paid == context.zodiactionMeter
                ? []
                : [.zodiactionMeterChanged(to: paid)]
        }

        // Anywhere solid, the square underfoot included — it is as good a tile
        // to protect as any, and often the one that matters.
        let candidates = context.currentBoard.allPoints.filter {
            !context.currentBoard[$0].health.isHole
                && context.currentBoard[$0].kind == .normal
        }
        guard let target = candidates.randomElement(using: &generator) else { return [] }

        var state = context.signState
        state.bastion = target
        state.bastionPlane = context.plane
        return [.signStateChanged(state)]
    }
}

// MARK: - Match-shift Miasma

/// Two halves of one coin: the first marks a square, the second takes you to it.
///
/// The colour is the tell. A mark is sky or orange at random and the coin that
/// *answers* it is always the other one, so a player holding one can see at a
/// glance which half they are looking at.
///
/// Holes are legal targets — a marked hole may be mended before the second
/// half arrives, and if it is not, going there is exactly as fatal as it
/// sounds. **A mark on a tile that later becomes a hole breaks**, which is the
/// - TODO: When Pentacles persist across planes, this gets a free plane change
///   with it. The sigils are plane-independent by nature — a mark that means
///   "the coin that answers this wears the other colour" is a statement about
///   the coin, not about the ground it is standing on — so once a coin can be
///   carried between planes, answering a mark from the other one is the buff
///   that falls out of it rather than a rule anybody has to write.
/// one case where the board takes the promise back.
struct MatchShiftMiasmaEffect: PickupEffect {

    let id: PickupID = .matchShiftMiasma

    func summary(in context: PickupSummaryContext) -> String {
        context.signState.miasmaMarks.count < GameRules.miasmaMarkLimit
            ? summary
            : "A strange sigil forms be— woah!"
    }

    func plan(
        context: PickupContext,
        choice: PickupChoiceResult?,
        generator: inout SeededRandom
    ) -> [GameEvent] {
        var state = context.signState

        // **Somewhere else, every time.**
        //
        // Never the square being stood on — a doorway under your own feet is a
        // doorway you cannot choose to walk to — never the Nexys, and never a
        // square already marked. Holes are fair game: a sigil over one is a way
        // across it.
        let taken = Set(state.miasmaMarks.map(\.point))
        let candidates = context.currentBoard.allPoints.filter {
            $0 != GameRules.nexysPoint
                && context.currentBoard[$0].kind != .nexys
                && $0 != context.piecePoint
                && !taken.contains($0)
        }
        guard let mark = candidates.randomElement(using: &generator) else { return [] }

        state.miasmaMarks.append(
            SignState.MiasmaMark(
                point: mark,
                plane: context.plane,
                isWarm: generator.next() % 2 == 0
            )
        )
        return [.signStateChanged(state)]
    }
}

// MARK: - Stelluna Sprite

/// A fairy that lets you stand on the next hole you would have fallen into.
///
/// No clock. It waits for as long as it takes and is spent the moment it is
/// needed, which is why `BuffsView` draws it without a number — see the note
/// there on buffs that end on a condition rather than on a count.
struct StellunaSpriteEffect: PickupEffect {

    let id: PickupID = .stellunaSprite

    func plan(
        context: PickupContext,
        choice: PickupChoiceResult?,
        generator: inout SeededRandom
    ) -> [GameEvent] {
        guard !context.signState.hasSprite else { return [] }

        var state = context.signState
        state.hasSprite = true
        return [.signStateChanged(state)]
    }
}

// MARK: - Polarity Prongs

/// Four shards fall on the poles and drag you toward one of them for four turns.
///
/// Each shard breaks the tile it lands on, and those holes are permanent — the
/// shards shatter after four turns and the damage stays. The **active** pole is
/// visible before it pulls, so the next forced move is always something you can
/// plan around rather than something that happens to you.
///
/// Re-rolled every turn with no lockout: the same pole may come up all four
/// times, and a run of one direction is a legitimate outcome rather than a bug.
struct PolarityProngsEffect: PickupEffect {

    let id: PickupID = .polarityProngs

    func plan(
        context: PickupContext,
        choice: PickupChoiceResult?,
        generator: inout SeededRandom
    ) -> [GameEvent] {
        let board = context.currentBoard
        let last = board.size - 1

        // One at each cardinal pole of the board, which never moves — and a
        // shuffled element on each, which never repeats.
        //
        // All four elements are always out, so the board still offers every
        // charge there is; what is rolled is which direction pays which. A
        // straight per-shard roll would have let three of them come up fire.
        let middle = board.size / 2
        let elements = ZodiacElement.allCases.shuffled(using: &generator)
        let poles = zip(
            [
                (SwipeDirection.up, GridPoint(middle, 0)),
                (.down, GridPoint(middle, last)),
                (.left, GridPoint(0, middle)),
                (.right, GridPoint(last, middle)),
            ],
            elements
        ).map { place, element in
            SignState.Prongs.Pole(
                direction: place.0, point: place.1, element: element
            )
        }

        var events: [GameEvent] = []
        var changes: [GridPoint: TileHealth] = [:]

        // **Out from under the falling shard first.**
        //
        // Four squares break at once, and one of them can be the square you are
        // standing on — which killed you outright for the crime of picking the
        // coin up there. A step back the way you came is the cheapest honest
        // answer: the shard lands where you were, and you are beside it.
        if poles.contains(where: { $0.point == context.piecePoint }) {
            let back = context.piecePoint.offset(by: context.facing.opposite.unitOffset)
            let clear = board.contains(back) && !board[back].health.isHole
                ? back
                // Backing into the wall or a hole is no rescue; anywhere solid
                // beside the shard will do.
                : context.piecePoint.surrounding().first { spot in
                    board.contains(spot)
                        && board[spot].kind == .normal
                        && !board[spot].health.isHole
                        && !poles.contains { $0.point == spot }
                }

            if let clear {
                events.append(
                    .pieceMoved(
                        from: context.piecePoint,
                        to: clear,
                        fromPlane: context.plane,
                        toPlane: context.plane,
                        type: .blown
                    )
                )
            }
        }

        for point in poles.map(\.point) where board[point].kind == .normal {
            // The shard breaks what it lands on, and the hole outlives it.
            if board[point].health != .hole { changes[point] = .hole }
        }
        // **The shards land, and then the ground gives.**
        //
        // The state change comes first because it is what puts them on the
        // board — the session watches for it and holds everything still while
        // they come down. Breaking the tiles first meant four holes opened out
        // of nowhere and the crystals turned up afterwards to explain it.
        var state = context.signState
        state.prongs = SignState.Prongs(
            plane: context.plane,
            movesRemaining: GameRules.prongMoves,
            active: poles.randomElement(using: &generator)?.direction ?? .up,
            poles: poles
        )
        events.append(.signStateChanged(state))

        if !changes.isEmpty {
            events.append(.tilesChanged(plane: context.plane, changes: changes))
        }
        return events
    }
}

/// A murky mist that costs a pip of charge on every step for three moves.
///
/// Foreshadowing, and named for what it will become: the coin that Umbra's
/// Pentacles are made of. Meeting it up here as a small unpleasant thing is
/// what makes finding a plane full of them mean something later.
///
/// **Scorpio is the exception, and gains instead.** He is the sign the
/// underworld is being built around — his Zodiaction is the way in — so the
/// substance the place is made of reading as *familiar* rather than as poison
/// is the whole characterisation. It costs nothing to state now and pays off
/// when Umbra lands.
struct UnknownEssenceEffect: PickupEffect {

    let id: PickupID = .unknownEssence

    /// Scorpio reads a different line, because he gets a different effect.
    func summary(in context: PickupSummaryContext) -> String {
        guard context.zodiac == .scorpio else { return summary }
        return "A strange black mist that seeps into your Zodea, invigorating movement for the next "
            + "\(GameRules.essenceMoves) turns. It feels oddly familiar."
    }

    func plan(
        context: PickupContext,
        choice: PickupChoiceResult?,
        generator: inout SeededRandom
    ) -> [GameEvent] {
        var state = context.signState
        if context.zodiac == .scorpio {
            state.astralEssenceMoves = GameRules.essenceMoves
        } else {
            state.unknownEssenceMoves = GameRules.essenceMoves
        }
        return [.signStateChanged(state)]
    }
}

/// The same mist, right way up: a pip of charge on every step for three moves.
///
/// Astra's alone. Down below the air is thin and what you find in it is the
/// murk; the bright version is a property of being up among the stars, which is
/// also why it is the more common of the two.
struct AstralEssenceEffect: PickupEffect {

    let id: PickupID = .astralEssence

    func plan(
        context: PickupContext,
        choice: PickupChoiceResult?,
        generator: inout SeededRandom
    ) -> [GameEvent] {
        var state = context.signState
        state.astralEssenceMoves = GameRules.essenceMoves
        return [.signStateChanged(state)]
    }
}

/// One point of wear on a tile chosen at random.
///
/// The mirror of the Astral Tear, and deliberately as small: it is the coin
/// that makes an unopened Pentacle a *question* rather than a formality. A hunt
/// where every coin is good is a hunt with no tension in it, and one where the
/// bad ones are catastrophic is a hunt nobody takes. This one is neither — it
/// costs a tile a third of its life, somewhere you may never stand.
///
/// Your own square is a candidate. Excluding it would make standing still safe
/// in a way nothing else in the game is.
struct TrivialTremorEffect: PickupEffect {

    let id: PickupID = .trivialTremor

    func plan(
        context: PickupContext,
        choice: PickupChoiceResult?,
        generator: inout SeededRandom
    ) -> [GameEvent] {
        Self.shake(context: context, points: 1, generator: &generator)
    }

    /// Wears one random tile by `points`.
    ///
    /// Shared with the Shakedown because the two differ only in how hard they
    /// hit — and writing that difference as a number rather than as a second
    /// copy of the search means the rules about *which* tiles are eligible can
    /// only ever be stated once.
    ///
    /// Holes are excluded because they cannot be worn further, and the Nexys
    /// because it is structural. `canBeWorn` already says both.
    static func shake(
        context: PickupContext,
        points: Int,
        generator: inout SeededRandom
    ) -> [GameEvent] {
        let candidates = context.currentBoard.points(where: \.canBeWorn)
        guard let target = candidates.randomElement(using: &generator) else { return [] }

        // Counted as **damage**, landed as **one hit**.
        //
        // Both halves matter and they pull in different directions. Counting in
        // points rather than assigning `.hole` keeps wear a single verb, so
        // anything that ever wants to sit between the source and the tile has a
        // number to work with. But it has to arrive as one event, because a
        // shield that nullifies *the next damage* has to know what "next" is —
        // three events would let a Nexyial Bastion eat a third of a Shakedown
        // and pass the rest through, which is not what absorbing a hit means.
        // Through the board's own wear, which is where cover is answered — see
        // `Board.wearEvents`. It still arrives as one hit: cover coming off and
        // the ground being marked are two events describing one blow, and
        // anything counting "the next damage" sees the pair together.
        return context.currentBoard.wearEvents(
            at: target, on: context.plane, stages: max(points, 1)
        )
    }
}

/// Three points of wear on one tile: healthy ground becomes a hole.
///
/// Coded as three points of damage rather than as "make a hole" on purpose. The
/// two are the same today and stop being the same the moment anything can
/// reduce incoming damage — a shielded tile should survive this at one crack
/// left, not shrug off a state change.
struct SeismicShakedownEffect: PickupEffect {

    let id: PickupID = .seismicShakedown

    func plan(
        context: PickupContext,
        choice: PickupChoiceResult?,
        generator: inout SeededRandom
    ) -> [GameEvent] {
        TrivialTremorEffect.shake(context: context, points: 3, generator: &generator)
    }
}

/// Burns the ring of tiles around the piece, paying out Zodiaction charge for
/// the damage.
///
/// The square underfoot is deliberately **not** included. Burning your own tile
/// out from under you was not an interesting risk — it was a way to end the run
/// while standing still, with no decision attached.
///
/// The fire essence: it *destroys, and you profit*. Every tile it wears is worth
/// a point of charge, and every tile it breaks outright is worth two — so it
/// pays best on a board that was already half gone, and turns a collapsing plane
/// into a full meter.
///
/// The square under the piece burns too. Fire does not spare its caster.
struct AstralBlazeEffect: PickupEffect {

    let id: PickupID = .astralBlaze

    func plan(
        context: PickupContext,
        choice: PickupChoiceResult?,
        generator: inout SeededRandom
    ) -> [GameEvent] {
        // **Fire, so it burns the grass off rather than being slowed by it.**
        //
        // Everything goes through `Board.wearEvents`, which is the one place
        // that knows cover takes a hit before the ground does. The Blaze is the
        // exception it also knows about: a square with a flame drawn on it
        // loses whatever was growing there *and* takes the damage in full.
        var health: [GridPoint: TileHealth] = [:]
        var cover: [GridPoint: GroundCover?] = [:]
        var charge = 0

        for point in context.piecePoint.surrounding(includingSelf: false) {
            guard context.currentBoard.contains(point) else { continue }

            // One flash, so one event. `wearOutcome` answers what would happen
            // without committing to how it is announced, which is what lets the
            // whole ring arrive together whether or not grass was in the way.
            let outcome = context.currentBoard.wearOutcome(
                at: point, stages: 1, cause: .brazenBlaze, seed: point.x &* 31 &+ point.y
            )
            if case let .became(left) = outcome.cover { cover[point] = left }
            guard let damage = outcome.health else { continue }
            health[point] = damage

            // Paid on what the fire actually did: a square that only lost its
            // cover has not been damaged and does not pay.
            charge += damage.isHole
                ? GameRules.astralBlazeChargePerBreak
                : GameRules.astralBlazeChargePerDamage
        }

        var events: [GameEvent] = []
        if !health.isEmpty || !cover.isEmpty {
            events.append(.groundSwept(plane: context.plane, health: health, cover: cover))
        }

        let meter = context.meter(afterGaining: charge)
        if meter != context.zodiactionMeter {
            events.append(.zodiactionMeterChanged(to: meter))
        }

        return events
    }
}

/// Repairs the ring of tiles around the piece by one stage each.
///
/// Matched to Astral Blaze's footprint — the square underfoot is excluded — so
/// the two elemental area effects read as a pair.
///
/// The earth essence: it *mends what can still be mended*. Holes are past
/// saving and are skipped entirely — this shores up a board that is wearing
/// thin, it does not resurrect one that has already collapsed. Compare
/// `AstralTearEffect`, which fixes one square completely no matter how far gone.
struct AstralBlossomEffect: PickupEffect {

    let id: PickupID = .astralBlossom

    func plan(
        context: PickupContext,
        choice: PickupChoiceResult?,
        generator: inout SeededRandom
    ) -> [GameEvent] {
        // Everything blooms together — one `tilesChanged`, not a ripple.
        var changes: [GridPoint: TileHealth] = [:]
        var planted: [GameEvent] = []

        // **The same coin means different things on the two planes.**
        //
        // On Astra it heals the ring outright, which is what it has always
        // done. On Terra it mends a single stage and leaves **flowers** over
        // what it touched — less repair, but the cover is worth a stage of its
        // own the next time something stands there, and it reaches ground the
        // full heal never could: a hole comes back as crumbling with flowers
        // growing out of it.
        //
        // The plane split is the point rather than a balance patch. Terra is
        // where things grow.
        let onEarth = context.plane == .terra

        for point in context.piecePoint.surrounding(includingSelf: false) {
            guard context.currentBoard.contains(point) else { continue }

            let tile = context.currentBoard[point]

            if onEarth {
                // **Every square in the ring, healthy or not.**
                //
                // The guard here used to be `canBeRepaired`, which is false for
                // healthy ground — so a ring that was in good shape got nothing
                // at all and the coin looked like it had fired backwards. The
                // heal is for damage; the *flowers* are for everyone, and on
                // Terra the flowers are the point.
                //
                // A hole is not past saving either: the bloom reaches into it
                // and brings the ground back a stage, which is the one thing in
                // the game besides a Nexys that undoes one.
                guard tile.kind == .normal else { continue }

                let mended = tile.health.healed
                if mended != tile.health { changes[point] = mended }

                // Flowers only where there is ground to hold them. A hole that
                // could not be mended stays a hole, and drawing a meadow over
                // one is how you walk onto a square that is not there.
                guard !mended.isHole else { continue }
                planted.append(
                    .tileCoverChanged(plane: context.plane, point: point, to: .flowers)
                )
            } else {
                // Holes are past saving up here: the blossom mends damage, it
                // does not rebuild what has already fallen through.
                guard tile.canBeRepaired, !tile.health.isHole else { continue }

                // Fully, not by a stage. The Blaze it mirrors takes a tile most
                // of the way to a hole in one go, and a repair worth crossing
                // the board for has to answer that rather than nudge it.
                changes[point] = .healthy
            }
        }

        guard !changes.isEmpty || !planted.isEmpty else { return [] }

        var events: [GameEvent] = []
        if !changes.isEmpty {
            events.append(.tilesChanged(plane: context.plane, changes: changes))
        }
        return events + planted
    }
}

/// Teleports the piece to a random corner of the current plane.
///
/// Deliberately indiscriminate — it does not check what is there. A corner that
/// has already broken is a perfectly legal destination and you will drop through
/// it. That gamble is the effect.
struct CornerWarpEffect: PickupEffect {

    let id: PickupID = .cornerWarp

    func plan(
        context: PickupContext,
        choice: PickupChoiceResult?,
        generator: inout SeededRandom
    ) -> [GameEvent] {
        let last = context.currentBoard.size - 1
        let corners = [
            GridPoint(0, 0),
            GridPoint(last, 0),
            GridPoint(0, last),
            GridPoint(last, last),
        ]

        guard let destination = corners.randomElement(using: &generator) else { return [] }
        guard destination != context.piecePoint else { return [] }

        return [
            .pieceMoved(
                from: context.piecePoint,
                to: destination,
                fromPlane: context.plane,
                toPlane: context.plane,
                type: .teleport
            )
        ]
    }
}

/// Closes the distance between the piece and the Nexys island, whichever way
/// round that happens to be.
///
/// One Pentacle, two behaviours, decided entirely by where the island already
/// is:
///
/// - **Island on the other plane** → it moves to yours. You are not carried; it
///   comes to you.
/// - **Island already on your plane** → you warp onto it.
///
/// That makes it self-sequencing rather than conditional-and-often-useless.
/// Stranded on a decaying Terra with the island above, the first one you open
/// calls it down and the second puts you on it — and landing on the island in
/// Terra rides it back up to a freshly restored Astra
/// (`GameRules.nexysAscendsFromTerra`). On Astra it is simply a free trip to the
/// safest square on the board.
///
/// Warping onto it is a landing like any other, so every landing check runs —
/// which is exactly what makes the second step ascend rather than needing a
/// special case here.
struct NexysShiftEffect: PickupEffect {

    let id: PickupID = .nexysShift

    /// Two different moves, depending on where the island is. "Summon it if on a
    /// different plane" asks the player to work out which half applies; the
    /// board already knows.
    func summary(in context: PickupSummaryContext) -> String {
        // Standing on it, the third case: it goes rather than you.
        context.nexysPlane == context.plane
            ? "Return to the Nexys, or dismiss it if you are already on it."
            : "Summon the Nexys to this plane."
    }

    func plan(
        context: PickupContext,
        choice: PickupChoiceResult?,
        generator: inout SeededRandom
    ) -> [GameEvent] {
        // Island elsewhere: call it down (or up) to you. `carryingPiece: false`
        // — the island travels alone, you are already where you are.
        guard context.nexysPlane == context.plane else {
            return [.nexysMoved(to: context.plane, carryingPiece: false)]
        }

        // **Standing on it: send it away.**
        //
        // The Node is the Shift, and the Shift's other half is dismissal — so
        // this case did nothing at all, which is the one outcome a Pentacle
        // must never have. It leaves the same way the button sends it, and the
        // ground you are left standing over is your problem, exactly as it is
        // when you dismiss it by hand.
        guard context.piecePoint != GameRules.nexysPoint else {
            return [.nexysMoved(to: context.plane.opposite, carryingPiece: false)]
        }

        // Island here, and you are elsewhere on this plane: go to it.

        return [
            .pieceMoved(
                from: context.piecePoint,
                to: GameRules.nexysPoint,
                fromPlane: context.plane,
                toPlane: context.plane,
                type: .teleport
            )
        ]
    }
}

/// Black ore out of Terra that drinks a Zodea's charge.
///
/// The one coin that takes the meter rather than filling it — and the reason it
/// reads as a find rather than as a punishment is Scorpio, for whom the same
/// stone does the opposite. He is made of the deep places it comes from.
struct ZodaemoniteSkullEffect: PickupEffect {

    let id: PickupID = .zodaemoniteSkull

    /// Scorpio reads a different line, because the stone does a different thing
    /// to him.
    func summary(in context: PickupSummaryContext) -> String {
        guard context.zodiac == .scorpio else { return summary }
        return "A strange skull made of Zodaemonite; a pitch-black ore from "
            + "deep beneath Terra. Your Zodea vibrates with power upon touch."
    }

    func plan(
        context: PickupContext,
        choice: PickupChoiceResult?,
        generator: inout SeededRandom
    ) -> [GameEvent] {
        let target = context.zodiac == .scorpio ? GameRules.zodaemoniteScorpioCharge : 0
        return [.zodiactionMeterChanged(to: target)]
    }
}

/// Swaps the piece for a randomly chosen *different* sign.
///
/// One of only two things in the game that changes your sign mid-run, and the
/// one that does not ask. Always a genuine change — it never rolls the sign you
/// already have, because "nothing happened" is not a rare Pentacle.
struct ForcedFateEffect: PickupEffect {

    let id: PickupID = .forcedFate

    /// ## Why company takes the hit
    ///
    /// Fate goes for the *newest* thing about you. A lion with somebody
    /// following has just made an arrangement, and this coin is the one that
    /// unmakes arrangements — taking Leo instead would dismiss the whole
    /// retinue as a side effect of changing sign, which is a far larger event
    /// than "your sign changes at random" describes.
    ///
    /// It re-rolls the **oldest** phantom, which is the one already nearest to
    /// being replaced by the next summon. That keeps the line a queue: things
    /// leave it from the front, whatever removes them.
    ///
    /// Alignment stays a Leo swapper. One of the two coins should still be able
    /// to take the lion himself, and Alignment is the one that lets you choose —
    /// changing sign on purpose is worth losing your company for.
    func plan(
        context: PickupContext,
        choice: PickupChoiceResult?,
        generator: inout SeededRandom
    ) -> [GameEvent] {
        if let oldest = context.signState.retinue.first {
            let taken = Set(context.signState.retinue)
            let pool = Zodiac.allCases.filter { $0 != context.zodiac && !taken.contains($0) }
            guard let replacement = pool.randomElement(using: &generator) else { return [] }

            var state = context.signState
            state.retinue[0] = replacement
            return [.signStateChanged(state), .retinueChanged(from: oldest, to: replacement)]
        }

        let others = Zodiac.allCases.filter { $0 != context.zodiac }
        guard let replacement = others.randomElement(using: &generator) else { return [] }
        return [.pieceChanged(to: replacement)]
    }
}

/// Lets the player choose any sign, including the one they already control.
///
/// The counterpart to `ForcedFateEffect`, and the reason keeping the same sign
/// is an explicit option rather than a wasted pickup: sometimes the right answer
/// really is "stay as I am", and the effect should let you say so rather than
/// punishing you for opening it.
struct AlignmentEffect: PickupEffect {

    let id: PickupID = .alignment

    /// The player picks, so this effect suspends the move.
    let choice: PickupChoice = .piece

    func plan(
        context: PickupContext,
        choice: PickupChoiceResult?,
        generator: inout SeededRandom
    ) -> [GameEvent] {
        guard case let .piece(chosen) = choice else { return [] }
        guard chosen != context.zodiac else { return [] }
        return [.pieceChanged(to: chosen)]
    }
}

/// Polaris — pinned to the north-middle square, and nowhere else.
///
/// Mends **all of Terra**, holes included, from wherever you are standing. Not
/// one tile and not one line: the entire lower plane comes back.
///
/// ## Why it mends the plane you are probably not on
///
/// Astra already repairs itself every time you leave it
/// (`GameRules.astraRestoresOnDescent`) — it is Terra that accumulates damage
/// with nothing to undo it, and a long run ends because the ground below has
/// run out. Polaris is the one answer to that, which is why it is worth the
/// walk to the top of the board.
///
/// Opened from Astra it also fills the Zodiaction meter outright. Mending a
/// plane you are not standing on is a promise rather than a rescue, and the
/// charge is what makes taking it *now* worth as much as taking it later.
///
/// ## Why it is not on the ordinary rarity ladder
///
/// `requiredSpawnPoint` keeps it to `(3, 0)` — it is only ever a candidate when
/// a sparkle set happens to cover the top-centre tile, and the reveal is forced
/// there. That restriction is its rarity, so it rolls as a common; see
/// `rollsAsRarity`. The catalogue enforces both halves.
struct PolarisEffect: PickupEffect {

    let id: PickupID = .polaris

    /// What it says when it is found cold.
    ///
    /// A different object to the player, and it should read like one: below, it
    /// is a rock with a story rather than a prize with a number. See
    /// `PickupEffect.summary(on:)`.
    func summary(on plane: Plane) -> String {
        plane == .terra
            ? "A fragment of Old Astra, dormant and cold. How did it get here and what is it for?"
            : summary
    }

    /// Cold on Terra, lit above. The coin on the board says which one it is
    /// before the player has touched it, which is most of why finding it down
    /// there is a question rather than a payout.
    func appearance(on plane: Plane) -> PentacleAppearance {
        plane == .terra ? .dormant : appearance
    }

    func plan(
        context: PickupContext,
        choice: PickupChoiceResult?,
        generator: inout SeededRandom
    ) -> [GameEvent] {
        // Picked up, not spent.
        //
        // ## Why it is carried now
        //
        // Restoring a plane the instant it is touched makes the best coin in the
        // game a thing that happens *to* you: it fires wherever you happened to
        // be standing, on whatever the board happened to look like, and the
        // player's only involvement was walking onto a square. For a legendary
        // that is a waste of the moment.
        //
        // Carried, it becomes a decision with a clock — you hold a full board
        // repair and choose when the board is bad enough to be worth it — and
        // finding it on Terra becomes a *question* rather than a payout, because
        // down there it arrives cold and has to be taken back into the light.
        //
        // No charge either way. It is not a battery for the meter; it is its own
        // thing, and paying out twice was the old version being unsure what it
        // was for.
        var state = context.signState
        state.polaris = context.plane == .astra ? .charged : .dormant
        return [.signStateChanged(state)]
    }
}

/// Shadow Work — spawns a mirrored double of your piece.
///
/// Unlike every other effect in the catalogue this one is not a single burst of
/// events: it introduces a second entity that persists and acts every turn. The
/// engine carries it as `GameEngine.shadow`, moves it from `plan` once the
/// player has settled, and resolves what it ran into there.
///
/// ## The Pentacle itself
///
/// Appears as a desaturated, dark coin (`appearance == .shadow`), spawning very
/// rarely *in place of* an ordinary Pentacle. Once it is on the board it does
/// not sit still: every move the player makes, it moves one square **toward**
/// them, until it is caught.
///
/// ## What opening it does
///
/// Spawns a shadow copy of the player's piece on the Nexys. If the Nexys is not
/// on the player's plane, it instead spawns a **visual-only** shadow duplicate of
/// the island at the centre — one the player cannot step on — and puts the
/// shadow piece there.
///
/// ## The shadow's behaviour
///
/// It mirrors the player exactly: move west one square, it moves east one. It
/// wears tiles on landing precisely as the player does, so it roughly doubles
/// the rate the board is destroyed.
///
/// ## Getting rid of it
///
/// - **Collide with it** → it vanishes and the Zodiaction meter fills completely.
/// - **Drive it into a hole**, or **into a Pentacle** → destroyed, half meter.
///
/// ## The one exception
///
/// If the shadow spawned on a *shadow* Nexys — i.e. the real island was on the
/// other plane — then driving it into the centre chasm does **not** work: it
/// lands safely on its shadow island instead. Deliberate. The chasm is a
/// guaranteed hole on every board, which would otherwise make disposing of the
/// shadow trivial.
///
/// ## What building it needs
///
/// 1. Engine state: shadow position/plane, and the shadow-Nexys marker.
/// 2. Events: shadow spawned, stepped, destroyed — plus reusing `.tileDamaged`
///    for the wear it causes.
/// 3. A hook in the move pipeline to mirror the player's committed offset and
///    settle the shadow, after the player's own travel resolves.
/// 4. A hook for the Pentacle's own pre-collection movement, which is the first
///    thing in the game that moves a revealed Pentacle.
struct ShadowWorkEffect: PickupEffect {

    let id: PickupID = .shadowWork

    func plan(
        context: PickupContext,
        choice: PickupChoiceResult?,
        generator: inout SeededRandom
    ) -> [GameEvent] {
        // It arrives on the island — or on a phantom of one, if the real island
        // is on the other plane.
        //
        // The phantom is not somewhere the player can stand. It exists so the
        // shadow has a floor of its own at the centre, which is what makes the
        // chasm useless for disposing of it: a guaranteed hole on every board
        // would turn "get rid of the shadow" into a formality.
        let onShadowNexys = context.nexysPlane != context.plane

        // And it takes your charge on the way in.
        //
        // Two things fall out of this that the coin was missing. It explains
        // what the shadow *wants* — it is here for your astral energy and it
        // takes a mouthful arriving — and it explains why catching it hands the
        // meter back full: that was your charge, and you are taking it back.
        //
        // Emptied before the spawn so the order reads correctly: it is drained
        // out of you, and then the thing that drained it appears.
        let drained: [GameEvent] = context.zodiactionMeter > 0
            ? [.zodiactionMeterChanged(to: 0)]
            : []

        return drained + [.shadowSpawned(
            at: GameRules.nexysPoint,
            plane: context.plane,
            onShadowNexys: onShadowNexys
        )]
    }
}

/// Libra drops a slab of ground wherever she decides it belongs.
///
/// ## Why this replaces the Nexys Shift
///
/// The Shift moves the island to your plane, which for every other sign is a way
/// home. Libra has a way home — the island is already her lift — so the coin was
/// worth nothing to her. Giving her the slot rather than adding a slot keeps the
/// odds of the uncommon tier exactly where they were.
///
/// ## What arrives is not up to her
///
/// A shape and a state, both rolled: one to four squares in some orientation, at
/// any of the four wear levels, holes included. Libra chooses **where**, and only
/// where. That is the sign — she does not decide what the world hands her, she
/// decides what to do with it — and it is what makes the ability a placement
/// puzzle instead of a repair.
///
/// The board draws the slab floating over the cursor while she aims, green where
/// it would land and red where it would hang off the edge or over the island. A
/// slab that does not fit entirely cannot be dropped at all: allowing a corner of
/// a four-square shape to be used would make the rarity of the big shapes
/// meaningless.
struct GaleforceGavelEffect: PickupEffect {

    let id: PickupID = .galeforceGavel

    /// The slab arrives as ground; the square Libra is standing on to place it
    /// is not part of the deal and should not be charged for the privilege.
    let arrivalWearsTile = false

    /// Rolled on opening, then asked about.
    ///
    /// `PickupChoice` is a static description of a question, so the roll cannot
    /// live there — it happens here, on the first call, and travels inside the
    /// question itself.
    let choice: PickupChoice = .place(
        GavelSlab(shape: .single, rotation: 0, health: .healthy)
    )

    /// The real question, with a freshly rolled slab in it.
    ///
    /// The engine asks the effect for its choice before suspending; this is
    /// where the dice are thrown, so a seeded run places the same slab every
    /// time.
    func rolledChoice(using generator: inout SeededRandom) -> PickupChoice {
        .place(GavelSlab.roll(using: &generator))
    }

    func plan(
        context: PickupContext,
        choice: PickupChoiceResult?,
        generator: inout SeededRandom
    ) -> [GameEvent] {
        guard case let .place(slab, anchor) = choice else { return [] }
        guard slab.canBePlaced(anchoredAt: anchor, on: context.currentBoard) else { return [] }

        let changes = slab.squares(anchoredAt: anchor)
            .reduce(into: [GridPoint: TileHealth]()) { $0[$1] = slab.health }

        return [.tilesChanged(plane: context.plane, changes: changes)]
    }
}

/// A droplet of the water Pisces brings up with it.
///
/// Eight of these ring the fish when it arrives on Terra, and taking any one
/// dismisses the rest — so the geyser is a full meter *and* a choice about which
/// square to be standing on when you have it.
///
/// ## Why it is a Pentacle at all
///
/// It reuses the coin machinery — reveal, collect, destroy-the-others — because
/// all of that already works and none of it is Pentacle-specific. What makes it
/// not a Pentacle is `weight = 0`: `PickupCatalog.rollPickup` filters those out,
/// so it can never turn up in an ordinary hunt however many tiers are added
/// later.
struct GaiaDropletEffect: PickupEffect {

    let id: PickupID = .gaiaDroplet

    /// The droplet mended its square when it appeared; landing on it must not
    /// then wear the square it just repaired.
    let arrivalWearsTile = false

    func plan(
        context: PickupContext,
        choice: PickupChoiceResult?,
        generator: inout SeededRandom
    ) -> [GameEvent] {
        let filled = min(
            context.zodiactionMeter + GameRules.gaiaDropletCharge,
            context.zodiactionMeterMax
        )
        guard filled != context.zodiactionMeter else { return [] }
        return [.zodiactionMeterChanged(to: filled)]
    }
}

// MARK: - PickupCatalog

/// The registry of every Pentacle, and the roll that decides which one spawns.
enum PickupCatalog {

    static let allEffects: [PickupID: any PickupEffect] = [
        .zCharge: ZChargeEffect(),
        .restoreTile: AstralTearEffect(),

        .astralBrook: AstralBrookEffect(),
        .astralBreeze: AstralBreezeEffect(),
        .astralBlaze: AstralBlazeEffect(),
        .astralBlossom: AstralBlossomEffect(),
        .astralBolt: AstralBoltEffect(),
        .cornerWarp: CornerWarpEffect(),
        .nexysShift: NexysShiftEffect(),
        .stardar: StardarEffect(),
        .nexyialBastion: NexyialBastionEffect(),
        .matchShiftMiasma: MatchShiftMiasmaEffect(),
        .stellunaSprite: StellunaSpriteEffect(),
        .polarityProngs: PolarityProngsEffect(),

        .forcedFate: ForcedFateEffect(),
        .zodaemoniteSkull: ZodaemoniteSkullEffect(),
        .alignment: AlignmentEffect(),
        .unknownEssence: UnknownEssenceEffect(),
        .astralEssence: AstralEssenceEffect(),
        .trivialTremor: TrivialTremorEffect(),
        .seismicShakedown: SeismicShakedownEffect(),

        .virgoVictorylap: VirgoVictorylapEffect(),

        .polaris: PolarisEffect(),
        .shadowWork: ShadowWorkEffect(),

        .gaiaDroplet: GaiaDropletEffect(),
        .bubble: BubbleEffect(),
        .galeforceGavel: GaleforceGavelEffect(),
    ]

    /// The effect for an id. Traps on an unregistered id, which can only happen
    /// if a `PickupID` case was added without its implementation.
    /// The four Essences that can turn out to be the fifth.
    /// Which Essence an elemental result turns out to be, and whether it turns
    /// out to be the Bolt instead.
    ///
    /// ## Why the four are re-rolled after being drawn
    ///
    /// Because the table answers *how often an Essence comes up* and this
    /// answers *which one*, and only the second question knows about the sign
    /// holding the controls. Authoring four separate chances made them one
    /// question, so leaning the wheel toward a piece's own element would have
    /// meant rewriting four numbers every time the group's share moved.
    ///
    /// The group keeps whatever the four are authored at between them. Inside
    /// it: **thirty percent to your own element**, the remaining three sharing
    /// what is left, and the Bolt taking its five off the top — which is what
    /// keeps the fifth Essence a share of the other four's share rather than a
    /// number of its own. See `GameRules.astralBoltChance`.
    ///
    /// A piece with no element, or one whose element has no Essence, gets an
    /// even wheel — the skew is an affinity, and nothing to be affine to means
    /// no skew rather than a default favourite.
    private static func elemental(
        affinity: ZodiacElement?,
        using generator: inout SeededRandom
    ) -> PickupID {
        let roll = Double(generator.next() % 10_000) / 10_000
        if roll < GameRules.astralBoltChance { return .astralBolt }

        // Ordered, so a seeded run replays identically.
        let wheel = essences.sorted { $0.rawValue < $1.rawValue }
        let favoured = affinity.flatMap { element in
            wheel.first { effect(for: $0).element == element }
        }

        guard let favoured else {
            return wheel.randomElement(using: &generator) ?? .astralBrook
        }

        // Shares of what is left once the Bolt has taken its cut.
        let remaining = 1 - GameRules.astralBoltChance
        let mine = remaining * GameRules.elementAffinityShare
        let theirs = (remaining - mine) / Double(wheel.count - 1)

        var pick = roll - GameRules.astralBoltChance
        if pick < mine { return favoured }

        pick -= mine
        for essence in wheel where essence != favoured {
            if pick < theirs { return essence }
            pick -= theirs
        }
        return favoured
    }

    static let essences: Set<PickupID> = [
        .astralBrook, .astralBreeze, .astralBlaze, .astralBlossom,
    ]

    static func effect(for id: PickupID) -> any PickupEffect {
        guard let effect = allEffects[id] else {
            preconditionFailure("No PickupEffect registered for \(id.rawValue)")
        }
        return effect
    }

    /// Rolls a Pentacle.
    ///
    /// Two stages — tier, then effect within the tier — so the odds of a
    /// legendary do not shift every time a common one is added.
    ///
    /// Knows nothing about squares. It used to take the sparkle set so that
    /// effects pinned to a tile could be filtered in or out, which meant a rule
    /// about *where a coin is* was being asked as a rule about *which five
    /// squares lit up* — a far weaker question, and the reason Polaris was
    /// common. Square-dependent rules live in `GameEngine.drawPickup(at:on:)`,
    /// which is called once the square is known.
    ///
    /// - Parameter weighting: Lets the piece reweight the roll — see
    ///   `ZodiacPassive.pickupWeight`. Defaults to leaving every weight alone.
    /// The coin that takes whatever the others leave.
    ///
    /// See `rollPickup` — it is what makes every other coin's number its real
    /// rate rather than a weight.
    static let floor: PickupID = .restoreTile

    static func rollPickup(
        weighting: (PickupID, Int) -> Int = { _, chance in chance },
        affinity: ZodiacElement? = nil,
        using generator: inout SeededRandom
    ) -> PickupID? {

        // One roll out of a hundred, with the Tear taking the remainder.
        //
        // Every other coin's chance is its **actual** rate: written 5, it comes
        // up five hunts in a hundred. That only works because something absorbs
        // whatever is left over, and a hunt must always pay — fighting the
        // board's degradation is the loop — so the leftover cannot be nothing.
        // The Tear is the floor: it repairs, which is the one payout that is
        // never dead weight.
        //
        // It also means the table can be filtered without lying. On Astra the
        // Terra-only coins drop out, the others keep their exact rates, and the
        // Tear simply absorbs more.
        //
        // Filtered for testing, never in a shipped build — see
        // `PickupSpawnRule`.
        let rule = PickupSpawnRule.current
        let eligible = allEffects.values
            .filter { rule.allows($0.id) }
            .map { (value: $0.id, chance: rule.weight(of: $0, after: weighting)) }
            .filter { $0.chance > 0 }
            .sorted { $0.value.rawValue < $1.value.rawValue }

        guard !eligible.isEmpty else { return nil }

        let others = eligible.filter { $0.value != floor }
        let othersTotal = others.reduce(0) { $0 + $1.chance }
        let authoredFloor = eligible.first { $0.value == floor }?.chance ?? 0

        // Never below what it is authored at, so an over-subscribed table
        // degrades to plain weights instead of dropping the floor out entirely.
        let floorChance = max(authoredFloor, 100 - othersTotal)

        let table = eligible.contains { $0.value == floor }
            ? others + [(value: floor, chance: floorChance)]
            : others
        let total = table.reduce(0) { $0 + $1.chance }
        guard total > 0 else { return nil }

        var roll = Int(generator.next(upperBound: UInt64(total)))

        var drawn = table[0].value
        for entry in table {
            roll -= entry.chance
            if roll < 0 {
                drawn = entry.value
                break
            }
        }

        // **The fifth Essence, drawn out of the other four.**
        //
        // Authored at zero and rolled *inside* an elemental result rather than
        // beside it: the odds of drawing an Essence at all are untouched, and
        // this only decides which one it turned out to be. Rolled from the same
        // generator, so a seeded run still replays exactly.
        //
        // Its rate is therefore **a share of the elementals' share**, not a
        // number of its own — four coins at five percent make twenty, and one
        // in twenty of those is the Bolt at one percent overall. Move the
        // elementals and the Bolt moves with them, which is the point: it is
        // the rarest thing in the game *because* it is hiding inside the second
        // most ordinary, and that relationship should not need maintaining in
        // two places.
        if Self.essences.contains(drawn) {
            return elemental(affinity: affinity, using: &generator)
        }

        return drawn
    }
}
