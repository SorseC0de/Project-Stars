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

    // MARK: Rare

    /// Changes your piece to a random other sign, whether you like it or not.
    case forcedFate

    /// Lets you choose a new sign — including the one you already have.
    case alignment

    // MARK: Legendary

    /// Only ever spawns from a sparkle on the north-middle tile.
    case polaris

    /// Spawns a mirrored shadow of your piece.
    case shadowWork

    // MARK: Not a Pentacle

    /// A droplet from Pisces' Gaia Geyser. Never rolled — see
    /// `GaiaDropletEffect`.
    case gaiaDroplet

    /// Libra's slab of ground. Takes the Nexys Shift's place in the roll while
    /// she is playing — see `LibraJudicatorElevator` and `GaleforceGavelEffect`.
    case galeforceGavel

    var id: String { rawValue }
}

/// Grants a flat amount of Zodiaction charge.
///
/// The plainest effect in the game on purpose: it is the baseline the others are
/// measured against, and the one that makes a Pentacle worth taking even when
/// the board is in good shape.
struct ZChargeEffect: PickupEffect {

    let id: PickupID = .zCharge
    let rarity: PickupRarity = .common

    /// One against the Tear's three. Charge is the consolation prize for a
    /// coin that was not a repair, not the other way round.
    let weight = 1
    let displayName = "Z-Charge"
    let summary = "Gain \(GameRules.zChargePentacleAmount) Zodiaction charge."
    let glyph = "⚡"

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

/// Fully repairs one randomly-chosen damaged tile on the plane the piece is on.
///
/// **Fully**, not by one step — a hole goes straight back to healthy. That makes
/// it worth taking on a board that has already broken rather than only on one
/// that is starting to.
///
/// On a plane with nothing left to fix it does not fizzle: it pays out a point
/// of Zodiaction charge instead, so a well-kept board never makes a Pentacle
/// feel wasted.
struct AstralTearEffect: PickupEffect {

    let id: PickupID = .restoreTile
    let rarity: PickupRarity = .common

    /// Three against Z-Charge's one, which with the common tier at 75 makes this
    /// a little over half of every coin opened — three grabs in five, near
    /// enough. It is the floor the whole economy sits on: a coin that mends one
    /// tile is small enough to be the ordinary case and still worth crossing the
    /// board for.
    let weight = 3
    let displayName = "Astral Tear"
    let summary = "Fully repairs one damaged tile here. If none are damaged, gain 1 Zodiaction charge instead."
    let glyph = "✚"

    func plan(
        context: PickupContext,
        choice: PickupChoiceResult?,
        generator: inout SeededRandom
    ) -> [GameEvent] {
        // The Nexys and its chasm are structural and never candidates —
        // `repairablePoints` already excludes them.
        let candidates = context.currentBoard.repairablePoints

        guard let target = candidates.randomElement(using: &generator) else {
            let meter = context.meter(afterGaining: GameRules.restoreTileBonusCharge)
            guard meter != context.zodiactionMeter else { return [] }
            return [.zodiactionMeterChanged(to: meter)]
        }

        return [.tileHealed(plane: context.plane, point: target, to: .healthy)]
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
    let rarity: PickupRarity = .uncommon

    /// The four Essences are what the uncommon tier is *for*, and their current
    /// rate plays well — three each keeps it where it was while the warps come
    /// down around them.
    let weight = 3
    let displayName = "Astral Brook"
    let summary = "Slide to the far edge along your facing, damaging every tile you cross and passing over holes."
    let glyph = "≈"
    let element: ZodiacElement? = .water

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
            facing: context.facing
        )
    }

    /// The slide itself, as its own function.
    ///
    /// Shared with Pisces' Downstream, which *is* this effect — one body rather
    /// than two that would drift apart the first time either was retuned.
    static func slide(
        on board: Board,
        plane: Plane,
        from origin: GridPoint,
        facing: SwipeDirection
    ) -> [GameEvent] {
        // Facing a wall, the water simply flows the other way. Without this the
        // effect is a dud whenever it is used on a border tile facing out —
        // which is common, since the border is where sliding tends to strand you.
        var heading = facing
        if !board.contains(origin.offset(by: heading.unitOffset)) {
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
        for square in [origin, from] where board[square].canBeWorn {
            events.append(
                .tileDamaged(plane: plane, point: square, to: board[square].health.damaged)
            )
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
    let rarity: PickupRarity = .uncommon

    /// Never drawn directly — see the note above.
    let weight = 0

    let displayName = "Astral Bolt"
    let summary = "Struck by lightning: for \(GameRules.starMoves) moves you damage nothing, fall through nothing, and charge as you walk."
    let glyph = "⚡︎"

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
    let rarity: PickupRarity = .uncommon

    /// The four Essences are what the uncommon tier is *for*, and their current
    /// rate plays well — three each keeps it where it was while the warps come
    /// down around them.
    let weight = 3
    let displayName = "Astral Breeze"
    let summary = "Teleport to any square on this plane — holes and the Nexys included."
    let glyph = "❁"

    /// The player picks the destination, so this effect suspends the move.
    let element: ZodiacElement? = .air
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
            .pieceTeleported(
                from: context.piecePoint,
                to: destination,
                fromPlane: context.plane,
                toPlane: context.plane
            )
        ]
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
    let rarity: PickupRarity = .uncommon

    /// The four Essences are what the uncommon tier is *for*, and their current
    /// rate plays well — three each keeps it where it was while the warps come
    /// down around them.
    let weight = 3
    let displayName = "Astral Blaze"
    let summary = "The ring of tiles around you loses one stage. Gain 1 charge per tile damaged, 2 per tile broken."
    let glyph = "✷"
    let element: ZodiacElement? = .fire

    func plan(
        context: PickupContext,
        choice: PickupChoiceResult?,
        generator: inout SeededRandom
    ) -> [GameEvent] {
        // The blaze goes up all at once, so the whole ring travels as one
        // `tilesChanged` rather than nine separate hits.
        var changes: [GridPoint: TileHealth] = [:]
        var charge = 0

        for point in context.piecePoint.surrounding(includingSelf: false) {
            guard context.currentBoard.contains(point) else { continue }

            let tile = context.currentBoard[point]
            guard tile.canBeWorn else { continue }

            let health = tile.health.damaged
            changes[point] = health

            // Breaking a tile outright is worth double.
            charge += health.isHole
                ? GameRules.astralBlazeChargePerBreak
                : GameRules.astralBlazeChargePerDamage
        }

        var events: [GameEvent] = []
        if !changes.isEmpty {
            events.append(.tilesChanged(plane: context.plane, changes: changes))
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
    let rarity: PickupRarity = .uncommon

    /// The four Essences are what the uncommon tier is *for*, and their current
    /// rate plays well — three each keeps it where it was while the warps come
    /// down around them.
    let weight = 3
    let displayName = "Astral Blossom"
    let summary = "The ring of tiles around you recovers one stage. Holes are beyond help."
    let glyph = "✽"

    func plan(
        context: PickupContext,
        choice: PickupChoiceResult?,
        generator: inout SeededRandom
    ) -> [GameEvent] {
        // Everything blooms together — one `tilesChanged`, not a ripple.
        var changes: [GridPoint: TileHealth] = [:]

        for point in context.piecePoint.surrounding(includingSelf: false) {
            guard context.currentBoard.contains(point) else { continue }

            let tile = context.currentBoard[point]
            // Holes are past saving: the blossom mends damage, it does not
            // rebuild what has already fallen through.
            guard tile.canBeRepaired, !tile.health.isHole else { continue }

            // Fully, not by a stage. The Blaze it mirrors takes a tile most of
            // the way to a hole in one go, and a repair worth crossing the board
            // for has to answer that rather than nudge it.
            changes[point] = .healthy
        }

        guard !changes.isEmpty else { return [] }
        return [.tilesChanged(plane: context.plane, changes: changes)]
    }
}

/// Teleports the piece to a random corner of the current plane.
///
/// Deliberately indiscriminate — it does not check what is there. A corner that
/// has already broken is a perfectly legal destination and you will drop through
/// it. That gamble is the effect.
struct CornerWarpEffect: PickupEffect {

    let id: PickupID = .cornerWarp
    let rarity: PickupRarity = .uncommon

    /// Below the Essences: a warp rearranges where the whole run is happening,
    /// which is a bigger event than any single tile changing.
    let weight = 2
    let displayName = "Corner Warp"
    let summary = "Teleport to a random corner. It does not care what is waiting there."
    let glyph = "⟀"

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
            .pieceTeleported(
                from: context.piecePoint,
                to: destination,
                fromPlane: context.plane,
                toPlane: context.plane
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
    let rarity: PickupRarity = .uncommon

    /// The rarest uncommon. Moving the island moves the one fixed landmark on
    /// the board, and at its old rate it was turning up often enough that the
    /// Nexys stopped feeling fixed at all.
    let weight = 1
    let displayName = "Nexys Shift"
    let summary = "Brings the Nexys island to your plane, or warps you onto it if it is already here."
    let glyph = "◈"

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

        // Island here: go to it.
        guard context.piecePoint != GameRules.nexysPoint else { return [] }

        return [
            .pieceTeleported(
                from: context.piecePoint,
                to: GameRules.nexysPoint,
                fromPlane: context.plane,
                toPlane: context.plane
            )
        ]
    }
}

/// Swaps the piece for a randomly chosen *different* sign.
///
/// One of only two things in the game that changes your sign mid-run, and the
/// one that does not ask. Always a genuine change — it never rolls the sign you
/// already have, because "nothing happened" is not a rare Pentacle.
struct ForcedFateEffect: PickupEffect {

    let id: PickupID = .forcedFate
    let rarity: PickupRarity = .rare

    /// Three against Alignment's one. Being *given* a sign is the lesser of the
    /// two, because it is luck rather than a decision.
    let weight = 3
    let displayName = "Forced Fate"
    let summary = "Your sign changes at random. You do not get a say. With a phantom out, it changes the phantom instead."
    let glyph = "✦"

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
    let rarity: PickupRarity = .rare

    /// The rarest thing that is not pinned to a single square. Choosing your
    /// own sign is the strongest effect in the game — it converts a bad run into
    /// whichever run you wanted — so it has to be the one you almost never see.
    let weight = 1
    let displayName = "Alignment"
    let summary = "Choose any sign to become — including the one you already are."
    let glyph = "✧"

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
    let rarity: PickupRarity = .legendary
    let displayName = "Polaris"
    let summary = "Mend the whole of Terra, holes included. Taken from Astra, also fills your meter."
    let glyph = "★"

    /// Bright and starlit rather than the anonymous gold coin — a legendary is
    /// rare enough that telegraphing it is the point.
    let appearance: PentacleAppearance = .radiant

    /// Rolled among the commons, not the legendaries.
    ///
    /// Being pinned to one square already makes it rare: a sparkle set has to
    /// cover the top-centre tile before Polaris is even a candidate. Charging it
    /// legendary odds *as well* is two gates on the same door, and it is why it
    /// was never seen.
    let rollsAsRarity: PickupRarity = .common

    /// Well under the Astral Tear's three.
    ///
    /// Being pinned to one square is a weaker gate than it looks: a sparkle set
    /// covers five of forty-nine squares, so the top-centre tile is in play
    /// roughly one phase in ten — and at parity with the Tear that made Polaris
    /// something like one coin in forty. Several a run, which is not a legendary.
    let weight = 1

    /// The north-middle tile. Polaris appears here or not at all.
    let requiredSpawnPoint: GridPoint? = GridPoint(GameRules.gridSize / 2, 0)

    func plan(
        context: PickupContext,
        choice: PickupChoiceResult?,
        generator: inout SeededRandom
    ) -> [GameEvent] {
        // `planeRestored` already returns every ordinary tile to healthy, holes
        // among them. The Nexys and its chasm are structural and stay as they
        // are, which is correct: the island is not damage.
        var events: [GameEvent] = [.planeRestored(plane: .terra)]

        // From Astra the repair is for later, so the charge is for now.
        if context.plane == .astra, context.zodiactionMeter < context.zodiactionMeterMax {
            events.append(.zodiactionMeterChanged(to: context.zodiactionMeterMax))
        }

        return events
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
    let rarity: PickupRarity = .legendary
    let displayName = "Shadow Work"
    let summary = "A mirrored shadow of your piece appears and copies every move you make."
    let glyph = "☾"

    /// Desaturated and dark, so it is recognisable on sight.
    let appearance: PentacleAppearance = .shadow

    /// As rare as Polaris. It is the other legendary, and the only coin in the
    /// game that makes the board *worse* on purpose.
    let weight = GameRules.shadowWorkWeight

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

        return [.shadowSpawned(
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
    let appearance: PentacleAppearance = .gavel
    let rarity: PickupRarity = .uncommon

    /// Zero, so it is never rolled by anyone. Libra swaps it into the Nexys
    /// Shift's place through `ZodiacPassive.pickupWeight` — the same idiom
    /// Pisces uses to trade Z-Charge against the Tear.
    let weight = 0
    let displayName = "Galeforce Gavel"
    let summary = "Place a slab of ground anywhere it fits."
    let glyph = "⚖"
    let element: ZodiacElement? = .air

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
    let rarity: PickupRarity = .common

    /// Never rolled. Placed by `PiscesGaiaGeyser` and by a pool burning off.
    let weight = 0
    let displayName = "Gaia Droplet"
    let summary = "Gain \(GameRules.gaiaDropletCharge) Zodiaction charge."
    let glyph = "💧"
    let element: ZodiacElement? = .water
    let appearance: PentacleAppearance = .droplet

    /// Not part of the hunt — see `PickupClass`. Droplets are put on the board
    /// deliberately and are meant to stay there, so the sparkle phase carries on
    /// around them and taking a Pentacle does not shatter them.
    let pickupClass: PickupClass = .boon

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

    /// Every implemented effect, keyed by id.
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

        .forcedFate: ForcedFateEffect(),
        .alignment: AlignmentEffect(),

        .polaris: PolarisEffect(),
        .shadowWork: ShadowWorkEffect(),

        .gaiaDroplet: GaiaDropletEffect(),
        .galeforceGavel: GaleforceGavelEffect(),
    ]

    /// The effect for an id. Traps on an unregistered id, which can only happen
    /// if a `PickupID` case was added without its implementation.
    /// The four Essences that can turn out to be the fifth.
    static let essences: Set<PickupID> = [
        .astralBrook, .astralBreeze, .astralBlaze, .astralBlossom,
    ]

    static func effect(for id: PickupID) -> any PickupEffect {
        guard let effect = allEffects[id] else {
            preconditionFailure("No PickupEffect registered for \(id.rawValue)")
        }
        return effect
    }

    /// Rolls the Pentacle to hide in a sparkle set.
    ///
    /// Two stages — tier, then effect within the tier — so the odds of a
    /// legendary do not shift every time a common one is added.
    ///
    /// - Parameter sparklePoints: Squares the set covers. Effects with a
    ///   `requiredSpawnPoint` are only eligible when the set includes it, which
    ///   is how Polaris stays pinned to the north-middle tile.
    /// - Parameter weighting: Lets the piece reweight the roll — see
    ///   `ZodiacPassive.pickupWeight`. Defaults to leaving every weight alone.
    static func rollPickup(
        sparklePoints: [GridPoint],
        weighting: (PickupID, Int) -> Int = { _, weight in weight },
        using generator: inout SeededRandom
    ) -> PickupID? {
        let covered = Set(sparklePoints)

        /// Effects in `rarity` that could legally appear in this set.
        func eligible(in rarity: PickupRarity) -> [(value: PickupID, weight: Int)] {
            allEffects.values
                .filter { effect in
                    // `rollsAsRarity`, not `rarity`: see `PickupEffect`.
                    //
                    // Deliberately **not** filtered on the effect's own weight
                    // here. A passive may weight something *in* as well as out —
                    // Libra's Gavel is authored at zero and swapped up into the
                    // Nexys Shift's place — and testing the raw number first
                    // threw it away before the sign ever got a say. It is why
                    // the Gavel never appeared in a single session.
                    guard effect.rollsAsRarity == rarity else { return false }
                    guard let required = effect.requiredSpawnPoint else { return true }
                    return covered.contains(required)
                }
                .map { (value: $0.id, weight: weighting($0.id, $0.weight)) }
                // The one weight that decides: zero here is out, whether it was
                // authored that way or a passive put it there.
                .filter { $0.weight > 0 }
        }

        // Only offer tiers that actually have something to give, so an empty
        // legendary tier cannot swallow a roll.
        let tiers = PickupRarity.allCases
            .filter { !eligible(in: $0).isEmpty }
            .map { (value: $0, weight: $0.weight) }

        guard let tier = generator.pick(weighted: tiers) else { return nil }
        guard let drawn = generator.pick(weighted: eligible(in: tier)) else { return nil }

        // The fifth Essence is rolled *inside* the result, not beside it: the
        // odds of drawing an Essence at all are untouched, and this only decides
        // which one it turned out to be. Rolled from the same generator, so a
        // seeded run still replays exactly.
        if Self.essences.contains(drawn) {
            let roll = Double(generator.next() % 10_000) / 10_000
            if roll < GameRules.astralBoltChance { return .astralBolt }
        }

        return drawn
    }
}
