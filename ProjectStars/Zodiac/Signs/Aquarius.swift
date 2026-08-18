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

    let displayName = "Crazy Current"
    let summary = "Astra & Terra: holes cannot hold you, and what is past the edge of the plane is not nothing."

    /// A hole is ground, for as long as there is a storm to float on.
    ///
    /// At zero the pot has nothing holding it up and falls like anyone else,
    /// which is what makes running dry dangerous rather than merely quiet.
    func walksOnHoles(context: PassiveContext) -> Bool {
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
    let summary = "Astra & Terra: go to any square you choose — open ground included — and walk on air for \(GameRules.galeMoves) moves after."

    /// - TODO: Aquarius has no charge rule specified. It currently fills only
    ///   from Pentacles.
    func meterGain(from move: MoveSummary, context: PassiveContext) -> Int { 0 }

    /// Suspends on a tile the player picks — the same question Astral Breeze
    /// asks, now asked by a sign.
    func activate(context: PassiveContext, generator: inout SeededRandom) -> [GameEvent] {
        [.choiceRequested(source: .zodiaction(.aquarius), kind: .tile)]
    }

    func resolve(
        choice: PickupChoiceResult,
        context: PassiveContext,
        generator: inout SeededRandom
    ) -> [GameEvent] {
        guard case let .tile(destination) = choice else { return [] }

        // The gale is granted *before* the piece arrives, which is the whole
        // reason a hole is a legal destination: by the time the landing is
        // resolved, there is already nothing that can drop it.
        var state = context.signState
        state.galeMoves = GameRules.galeMoves

        return [
            .signStateChanged(state),
            .pieceTeleported(
                from: context.piecePoint,
                to: destination,
                fromPlane: context.plane,
                toPlane: context.plane
            ),
        ]
    }
}
