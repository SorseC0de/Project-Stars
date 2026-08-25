//
//  Aquarius.swift
//  Project Stars
//
//  ♒ Aquarius — The Water-Bearer
//
//  Everything specific to this sign lives in this file. Aquarius is an air
//  sign, so it is stronger on **Astra** and weaker on **Terra**.
//

import SwiftUI

// MARK: - Definition

extension ZodiacCatalog {

    /// ♒ Aquarius — The Water-Bearer. Air, Jan 20 – Feb 18. Strong on Astra.
    static let aquarius = ZodiacDefinition(
        sign: .aquarius,
        displayName: "Aquarius",
        glyph: "♒",
        element: .air,
        accentColor: Color(hex: 0x5F_C2_A8),
        movement: .cardinalStep,
        passives: [
            AquariusWackyWhirlwind(),
            AquariusCrazyCurrent(),
            AquariusEolianEjection(),
        ],
        zodiaction: AquariusWaterbearerWipeout(),
        constellation: ZodiacCatalog.aquariusConstellation
    )

    /// ♒ Aquarius: the water-bearer's jar, and the stream falling from it.
    static let aquariusConstellation = Constellation(
        stars: [
            Constellation.Star(-1.00,  0.85,  0.15, 0.9),
            Constellation.Star(-0.35,  0.95,  0.00, 1.0),
            Constellation.Star( 0.20,  0.55, -0.15, 0.9),
            Constellation.Star( 0.80,  0.75, -0.25, 0.8),
            Constellation.Star( 0.05, -0.10,  0.10, 0.8),
            Constellation.Star(-0.45, -0.55,  0.25, 0.7),
            Constellation.Star( 0.35, -0.75, -0.10, 0.7),
            Constellation.Star(-0.10, -1.05,  0.00, 0.9),
        ],
        lines: [(0, 1), (1, 2), (2, 3), (2, 4), (4, 5), (4, 6), (5, 7), (6, 7)]
    )
}

// MARK: - Passive 1: Quirky Caper

/// Aquarius never lands hard enough to matter — the damage goes to the tile it
/// pushes off from.
///
/// The consequence worth understanding: arriving somewhere costs nothing, so a
/// wrecked board is far safer to cross than it is for anyone else, but the square
/// you are standing on is always the one about to break. Aquarius cannot loiter.
struct AquariusWackyWhirlwind: ZodiacPassive {

    let icon: String? = "aquarius_wacky"
    let displayName = "Wacky Whirlwind"
    let summary = "Astra & Terra: everything about the waterbearer runs backwards."

    func wearTiming(context: PassiveContext) -> WearTiming {
        .onExit
    }

    /// **Everything runs the other way.**
    ///
    /// The reversal is the sign, so it is not conditional on the storm: the pot
    /// on the floor is still Aquarius, and a control scheme that flipped as the
    /// meter moved would be a rule the player has to re-learn every few turns
    /// instead of once.
    func reversesControls(context: PassiveContext) -> Bool { true }

    /// And the charge with them. See `ZodiacPassive.reversesCharge`.
    func reversesCharge(context: PassiveContext) -> Bool { true }

    /// Blown rather than walking, for as long as there is a storm.
    ///
    /// A hop is a thing with feet deciding to leave the ground. Aquarius above
    /// zero has no feet on show and no say in it — the funnel moves and he goes
    /// with it, which is a slide. At zero the pot is on the floor and hops like
    /// anyone else.
    func adjustedMovement(base: MovementPattern, context: PassiveContext) -> MovementPattern {
        context.zodiactionMeter > 0 ? base.blown() : base
    }

    /// And a fall costs the ground nothing either.
    ///
    /// Quirky Caper charges every landing to the square being *left*, but a
    /// fall has no square being left — the piece arrives from the plane above,
    /// having paid up there. Without this Aquarius was the one sign that damaged
    /// on arrival, which is precisely what the passive says it never does.
    func modifyWear(_ proposal: WearProposal, context: PassiveContext) -> WearProposal {
        guard proposal.arrivedByFalling else { return proposal }
        var weightless = proposal
        weightless.stages = 0
        return weightless
    }
}

/// How the storm carries him.
///
/// With any storm at all he does not walk — he is **blown**, so a move is a
/// slide rather than a hop, and it trails wind behind it. Spent to nothing, the
/// statue walks like every other sign's.
///
/// It hangs off the meter rather than off a flag because the storm does: the
/// same number that decides how much funnel there is decides whether there is
/// enough of it to carry him. There is no state to keep in step.
extension MovementPattern {

    /// The same options, made into slides.
    func blown() -> MovementPattern {
        MovementPattern(
            name: name,
            options: options.map {
                var blown = $0
                blown.style = .blown
                return blown
            }
        )
    }
}

// MARK: - Passive 2: Wind Walker

/// A long move is made on the wind.
///
/// A slide settles on each square it crosses and can break through halfway; a
/// jump touches only the destination. So Weightless is what makes Aquarius'
/// longer moves safe to make across broken ground — it flies over the gaps
/// instead of testing each one.
///
/// Inert while Aquarius' movement is the shared single step, since a one-tile
/// move has nothing to cross.
struct AquariusCrazyCurrent: ZodiacPassive {

    let icon: String? = "aquarius_current"
    let displayName = "Crazy Current"
    let summary = "Astra & Terra: holes cannot hold you, and what is past the edge of the plane is not nothing."

    /// A hole is ground, for as long as there is a storm to float on.
    ///
    /// At zero the pot has nothing holding it up and falls like anyone else,
    /// which is what makes running dry dangerous rather than merely quiet.
    func walksOnHoles(context: PassiveContext) -> Bool {
        context.zodiactionMeter > 0
    }

    /// **And a fall on the storm is a descent, not a tumble.**
    ///
    /// The same condition as the holes, and for the same reason: something is
    /// holding him up. A piece that is floating has not lost control of what is
    /// happening to it, and the spin is the part of a fall that says it has —
    /// see `ZodiacPassive.fallIsControlled(to:context:)`. At zero the storm is
    /// gone and he drops like anyone else, spin and all, which is the whole
    /// danger of running dry.
    func fallIsControlled(to plane: Plane, context: PassiveContext) -> Bool {
        context.zodiactionMeter > 0
    }

    /// And the edge stops being a wall — **at every phase, storm or not.**
    ///
    /// Unlike the holes, which need something holding him up. Floating explains
    /// why a hole is ground; nothing explains why the edge of the board would
    /// come back just because the wind died, and a rule that appears and
    /// disappears with the meter is one the player has to re-check every turn.
    ///
    /// So what counts as death stays fixed, the same way the reversed controls
    /// do, and only the hole rule moves. One thing to learn instead of two.
    func mayLeaveTheBoard(context: PassiveContext) -> Bool { true }

    /// **The current takes hold of a coin the moment it appears.**
    ///
    /// It is dragged one square toward her in the same turn it surfaces, and if
    /// that puts it under her feet she has sniped it. Folded in here rather than
    /// given a passive of its own because it is the same sentence Crazy Current
    /// already says — *the wind moves what is near her* — pointed at coins
    /// instead of at holes.
    /// No storm, no current. At phase zero there is nothing blowing, so a coin
    /// surfacing next to her is just a coin surfacing.
    func drawsPickupsIn(context: PassiveContext) -> Bool {
        context.zodiactionMeter < context.zodiactionMeterMax
    }

    /// **Arriving on Terra costs her the storm.**
    ///
    /// The wind is spent bracing for the ground — the meter goes to max, which
    /// for the sign that fires at empty means *nothing left* and a full climb
    /// back to firing. See `AquariusWaterbearerWipeout.firesAtEmpty`.
    ///
    /// It is a nerf that pays for itself: with no storm she is not floating,
    /// and a piece that is not floating cannot take a second hole on the way
    /// down. Landing hard is what stops the fall from continuing.
    ///
    /// Any arrival, not only a drop — riding the island down is still arriving,
    /// and a rule that asked *how* she got here would be a rule the player has
    /// to learn twice.
    func amend(_ events: [GameEvent], context: PassiveContext) -> [GameEvent] {
        guard context.zodiactionMeter != context.zodiactionMeterMax else { return [] }

        let landed = events.contains { event in
            switch event {
            case let .pieceFell(_, to, _):
                return to == .terra
            case let .pieceMoved(_, _, fromPlane, toPlane, _, _, _):
                return toPlane == .terra && fromPlane != .terra
            default:
                return false
            }
        }
        guard landed else { return [] }

        return [.zodiactionMeterChanged(to: context.zodiactionMeterMax)]
    }

    func walksOnAir(during option: MovementPattern.MoveOption, context: PassiveContext) -> Bool {
        option.distance > 1
    }
}

// MARK: - Passive 3: Corner Current

/// Scatters Aquarius to a random square it can stand on, anywhere on the plane —
/// the Nexys included.
///
/// Only solid squares are candidates, so this can never be a disguised suicide.
/// It is an escape, not a gamble: the value is getting *out* of a corner of the
/// board that has decayed past use.
/// Aquarius' meter, which runs down rather than up.
///
/// ## Why this is a starting value and a fired-at value, and nothing else
///
/// The temptation is to store *readiness* and show `max - readiness`, so no
/// charge source has to know this sign exists. That is the right shape and it is
/// what the design calls for — but it is a change to every place charge is
/// granted, and this sign needs to be playable now.
///
/// So the meter is the meter: it starts at ten, every gain elsewhere is a loss
/// here, and the Zodiaction fires at zero. Three facts in three places rather
/// than one abstraction across forty.
///
/// - TODO: Move to stored readiness with a display inversion. See the Aquarius

struct AquariusWaterbearerWipeout: Zodiaction {

    /// Backwards, both ends of it.
    let firesAtEmpty = true

    let displayName = "Waterbearer Wipeout"
    let summary = "(Unfinished) Astra & Terra: tear the ground open around you and turn the hunt into a squall of storm clouds."

    /// - TODO: Aquarius has no charge rule specified. It currently fills only
    ///   from Pentacles.
    func meterGain(from move: MoveSummary, context: PassiveContext) -> Int { 0 }

    /// **The placeholder.** Three things happen at once, and the storm does all
    /// of them without asking a question.
    ///
    /// 1. The sparkle phase is blown apart into a **squall**: one of the lit
    ///    squares turns up the real Pentacle, and every other one becomes a
    ///    storm cloud carrying a rolled effect of its own. The hunt resolves
    ///    exactly as it would have — the coin is the coin — and the clouds are
    ///    the weather it arrived in, which can be picked at leisure and hang
    ///    over holes because they are not sitting on anything.
    /// 2. Then the ground gives way in a ring around her. She is the one sign a
    ///    board full of holes does not frighten — she walks on them from phase
    ///    one — so wrecking her own surroundings is a threat to everybody else
    ///    and a corridor for her.
    /// 3. Any Pentacle caught in that ring is blown a square further out, rather
    ///    than dropped. The coins survive the storm; they are just not where
    ///    they were.
    ///
    /// - TODO: This is a stand-in for a Zodiaction that has not been designed.
    ///   It is deliberately made of parts the sign already owns — holes she can
    ///   walk on, a hunt she reads backwards — so that replacing it costs
    ///   nothing but this function.
    func activate(context: PassiveContext, generator: inout SeededRandom) -> [GameEvent] {
        var events: [GameEvent] = []

        let ring = context.piecePoint.surrounding().filter {
            context.currentBoard.contains($0) && context.currentBoard[$0].kind == .normal
        }

        // 1. **The squall first, the ruin second.**
        //
        //    Order of operations, and it is not cosmetic. Opening the ring
        //    before converting the phase meant any sparkle standing in the ring
        //    was on broken ground by the time the conversion looked at it — the
        //    set was invalidated, the phase re-rolled, and nothing became a
        //    cloud at all. Since a cloud is precisely the thing that does not
        //    care whether there is ground under it, the conversion has to happen
        //    while the phase is still whole.
        if let sparkles = context.sparkles, sparkles.plane == context.plane,
           !sparkles.points.isEmpty {

            // The real coin prefers a square that will still be standing. It is
            // an ordinary Pentacle and the ordinary rules apply to it — a coin
            // over a hole is destroyed — so putting it in the ring would be
            // handing the player a Pentacle and taking it back in the same
            // instant.
            let footing = sparkles.points.filter { !ring.contains($0) }
            let real = (footing.isEmpty ? sparkles.points : footing)
                .randomElement(using: &generator)

            if let real, let id = PickupCatalog.rollPickup(using: &generator) {
                events.append(.pickupRevealed(id: id, plane: sparkles.plane, point: real))
            }

            for point in sparkles.points where point != real {
                guard let id = PickupCatalog.rollPickup(using: &generator) else { continue }
                events.append(.pickupRevealed(
                    id: id, plane: sparkles.plane, point: point, asCloud: true
                ))
            }
        }

        // 2. Now the ground gives way. She is the one sign a hole does not
        //    frighten — she walks on them from phase one — so wrecking her
        //    surroundings is a corridor for her and a threat to everybody else.
        if !ring.isEmpty {
            events.append(.tilesChanged(
                plane: context.plane,
                changes: Dictionary(uniqueKeysWithValues: ring.map { ($0, TileHealth.hole) })
            ))
        }

        // 3. Coins caught in the ring are blown a square further out, if there
        //    is anywhere to push them. One with nowhere to go stays where it is
        //    rather than being destroyed — the storm moves things, it does not
        //    eat them.
        for coin in context.pickups where ring.contains(coin.point) {
            let away = GridOffset(
                (coin.point.x - context.piecePoint.x).signum(),
                (coin.point.y - context.piecePoint.y).signum()
            )
            let blown = coin.point.offset(by: away)

            guard context.currentBoard.contains(blown),
                  !context.pickups.contains(where: { $0.point == blown })
            else { continue }

            events.append(.pickupMoved(
                id: coin.id, plane: coin.plane, from: coin.point, to: blown
            ))
        }

        // The meter goes home. Hers runs backwards, so a spent Zodiaction is a
        // full one — see `firesAtEmpty`.
        events.append(.zodiactionMeterChanged(to: context.zodiactionMeterMax))

        return events
    }
}
// MARK: - Passive 3: Eolian Ejection

/// Dying on Terra with a full storm throws her back up to Astra instead.
///
/// The storm is already wound to firing when the ground gives out, and rather
/// than spend it on the board she spends it on herself: the transformation goes
/// off downward, the wind takes her up through the cloud, and she comes out of
/// it on the plane she belongs to.
///
/// ## Why an empty meter is the full one
///
/// Hers counts down — see `AquariusWaterbearerWipeout.firesAtEmpty`. Zero is a
/// storm at its largest and one press away from going off, which is exactly the
/// state that has something to spend. The save costs her all of it: the meter
/// goes to max, which for her is *nothing*, and the animation of the storm
/// coming apart is the transformation she already plays whenever a phase
/// changes. Nothing new is drawn for this.
///
/// ## Where she comes out
///
/// One square along her heading, like Pisces surfacing — and the cloud she
/// breaks through is left as a hole, for the same reason his is: something came
/// up through it.
struct AquariusEolianEjection: ZodiacPassive {

    let icon: String? = "aquarius_ejection"
    let displayName = "Eolian Ejection"

    /// Only while it can actually fire — see `ZodiacPassive.icon(in:)`.
    /// Shown only while it could actually fire — see `survivesFatalFall`.
    func icon(in context: PassiveContext) -> String? {
        context.zodiactionMeter <= 0 ? icon : nil
    }
    let summary = "Terra: falling with a full storm spends it to throw you back up to Astra."

    func survivesFatalFall(
        at point: GridPoint,
        from plane: Plane,
        context: PassiveContext
    ) -> [GameEvent]? {
        // Terra only: falling off Astra lands you on Terra, which is a fall
        // rather than an ending, and there is nothing above Astra to eject to.
        guard plane == .terra else { return nil }

        // **A wound storm, and nothing less.**
        //
        // Zero is a full meter for the sign that fires at empty, so this is the
        // one moment she has something to spend — and spending it is what the
        // save costs.
        //
        // It read `>= max` before, which is a meter with *nothing* in it, and
        // is exactly the state arriving on Terra leaves her in — so every fall
        // was survived and she could not die at all. See the arrival brace in
        // `AquariusWackyWhirlwind`.
        guard context.zodiactionMeter <= 0 else { return nil }

        // Away from the way she came, and back the other way if that is off the
        // board — the same rule the fish surfaces by.
        var heading = context.facing
        if !context.currentBoard.contains(point.offset(by: heading.unitOffset)) {
            heading = context.facing.opposite
        }
        let surface = point.offset(by: heading.unitOffset)
        guard context.currentBoard.contains(surface) else { return nil }

        var events: [GameEvent] = []
        if heading != context.facing { events.append(.pieceTurned(to: heading)) }

        // **Spent, not filled.**
        //
        // Zero is a *full* storm for the sign that fires at empty, so setting
        // it to zero handed the save back for free — she was ejected to Astra
        // still holding everything she was supposed to have paid. What spending
        // looks like for her is the meter at its maximum, which is the empty
        // end of her backwards bar.
        //
        // The summary has said "spends it" the whole time; only the arithmetic
        // disagreed.
        events.append(.zodiactionMeterChanged(to: context.zodiactionMeterMax))

        // Out through the cloud, which does not survive being come through.
        if surface != GameRules.nexysPoint {
            events.append(.tileDamaged(plane: .astra, point: surface, to: .hole))
        }

        events.append(
            .pieceMoved(
                from: point,
                to: surface,
                fromPlane: .terra,
                toPlane: .astra,
                type: .rise
            )
        )
        events.append(.passiveFired(name: displayName, refused: false))
        return events
    }
}

