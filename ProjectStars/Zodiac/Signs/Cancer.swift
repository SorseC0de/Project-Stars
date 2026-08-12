//
//  Cancer.swift
//  Project Stars
//
//  ♋ Cancer — The Crab
//
//  Everything specific to this sign lives in this file, its Bastion
//  included. Cancer is a water sign, so it is stronger on **Astra** and
//  weaker on **Terra**.
//

import SwiftUI

// MARK: - Definition

extension ZodiacCatalog {

    /// ♋ Cancer — The Crab. Water, Jun 21 – Jul 22. Strong on Astra.
    static let cancer = ZodiacDefinition(
        sign: .cancer,
        displayName: "Cancer",
        glyph: "♋",
        element: .water,
        accentColor: Color(hex: 0x6F_B7_D4),

        // Sidestep: an ordinary step in any direction, but up to two squares
        // to whichever side it is facing across. Drag further to take the full
        // two — see `MovementPattern.option(for:facing:reach:)`.
        movement: .sidestep,

        passives: [
            CancerCrabtitude(),
            CancerSeafoamScuttle(),
            CancerHomeboundHarvest(),
            CancerHeavenlyHoarder(),
        ],
        zodiaction: CancerBubbleBastion(),
        constellation: ZodiacCatalog.cancerConstellation
    )

    /// ♋ Cancer: the faint upturned Y of Asellus and Acubens.
    static let cancerConstellation = Constellation(
        stars: [
            Constellation.Star( 0.00, -0.20,  0.00, 1.0),
            Constellation.Star(-0.15,  0.55,  0.20, 0.8),
            Constellation.Star(-0.95,  1.00, -0.10, 0.7),
            Constellation.Star( 0.75,  0.95,  0.15, 0.7),
            Constellation.Star( 0.35, -1.00, -0.20, 0.9),
        ],
        lines: [(4, 0), (0, 1), (1, 2), (1, 3)]
    )
}

// MARK: - Passive 1: Crabtitude

/// Charge for moving laterally.
///
/// On Terra only the full two-square sidestep pays; on Astra — Cancer's own
/// plane — either distance does. So the crab is rewarded for committing to range
/// down below, and simply for scuttling up above.
struct CancerCrabtitude: ZodiacPassive {

    let displayName = "Crabtitude"
    let summary = "Astra: +1 charge for a seafoam scuttle. Terra: none."

    func meterBonus(from move: MoveSummary, context: PassiveContext) -> Int {
        // Sideways is measured against the facing the piece had *before* the
        // move, which is what `MoveSummary.direction` versus the facing it
        // turned to would confuse — so compare the travelled axis to the axis of
        // the square it started on instead.
        guard move.wasSideways, move.origin.manhattanDistance(to: move.destination) >= 2 else {
            return 0
        }

        // Astra only. The scuttle is a slide now and covers two squares for one
        // turn's wear, which is payment enough on the plane Cancer is weak on.
        return move.endingPlane == .astra ? 1 : 0
    }
}

/// The crab does not turn to walk.
///
/// Scuttling the full two squares sideways leaves Cancer looking exactly where
/// it was looking. Not decoration: facing decides where Leo's sun hangs, which
/// way Libra's arms reach, and what counts as sideways next move — so keeping it
/// is a real advantage, and the reason it is restricted to the committed
/// two-square walk rather than every step.
struct CancerSeafoamScuttle: ZodiacPassive {

    let displayName = "Seafoam Scuttle"
    let summary = "Astra & Terra: a full 2-tile sidestep does not change the way you are facing."

    func retainsFacing(
        direction: SwipeDirection,
        option: MovementPattern.MoveOption,
        context: PassiveContext
    ) -> Bool {
        // Keyed on the option being *the sidestep* rather than on its distance.
        // The two-square walk is the only sideways-only option Cancer has, and
        // asking the question that way cannot drift if the pattern is retuned.
        option.applies == .relative(.sideways)
    }
}

// MARK: - Passive 2: Homebound Harvest

/// Three pips for getting back to the Nexys by any means other than walking.
///
/// The exclusion is the point: strolling onto the island from an adjacent square
/// is not an achievement, but being flung there by a Pentacle, a Zodiaction or a
/// fall is. `MoveSummary.arrivedAtNexysByEffect` draws exactly that line.
struct CancerHomeboundHarvest: ZodiacPassive {

    let displayName = "Homebound Harvest"
    let summary = "Astra & Terra: +3 charge when you reach the Nexys by anything other than ordinary movement."

    func meterBonus(from move: MoveSummary, context: PassiveContext) -> Int {
        move.arrivedAtNexysByEffect ? 3 : 0
    }
}

// MARK: - Passive 3: Heavenly Hoarder

/// Opening a Pentacle beside the Nexys pays out in charge — and pays double at
/// home in the sky.
///
/// Half a meter on Terra, a full meter on Astra. "Beside" means the eight squares
/// touching the island, not the island itself, which a Pentacle can never occupy
/// anyway since sparkles refuse to sit there.
struct CancerHeavenlyHoarder: ZodiacPassive {

    let displayName = "Heavenly Hoarder"
    let summary = "Open a Pentacle adjacent to the Nexys: +half meter on Terra, +full meter on Astra."

    func meterBonus(from move: MoveSummary, context: PassiveContext) -> Int {
        guard move.collectedPickup != nil else { return 0 }

        // The island has to be on this plane for "adjacent to the Nexys" to mean
        // anything — otherwise that square is the chasm.
        guard move.endingPlane == context.nexysPlane else { return 0 }
        guard move.restingPoint.isAdjacent(to: GameRules.nexysPoint) else { return 0 }

        let max = context.zodiac.zodiaction.meterMax
        return move.endingPlane == .astra ? max : max / 2
    }
}

// MARK: - Zodiaction

/// **Bubble Bastion.** Consecrates the ground where the crab stands.
///
/// A 3x3 patch centred on the piece stops taking damage for three committed
/// moves, and lifts as the fourth begins. Nothing advances the wear of a
/// sheltered square: not footfalls, not a Pentacle's blast, not another sign's
/// Zodiaction, not a passive. Repair still works — this is protection, not
/// stasis.
///
/// ## Why the patch does not follow the piece
///
/// The crab consecrates *ground*, and ground stays where it is. A sanctuary
/// that travelled would be a three-move invulnerability, which is a different
/// and much duller ability; one that stays put is a place — somewhere to
/// retreat to, work outward from, and get back to before it lapses. It also
/// gives the three passives above something to point at, since all three
/// already pull Cancer toward holding a spot rather than roaming.
///
/// ## The Pentacle bonus
///
/// Opening a coin inside the patch pays `GameRules.sanctuaryPickupCharge`
/// straight back into the meter. The bonus lives here rather than in a fourth
/// passive because it only exists while the Bastion is standing — it is part of
/// the ability, not part of the sign.
///
/// - Note: Sized by `GameRules.sanctuaryRadius`. If a 3x3 proves too strong,
///   `0` gives a single square and nothing else needs touching.
struct CancerBubbleBastion: Zodiaction {

    let displayName = "Bubble Bastion"
    let summary = "Consecrate a 3x3 around you for 3 moves: those tiles cannot be damaged by anything. Opening a Pentacle inside pays +3 charge."

    /// Charge comes from the three passives, plus coins opened under the
    /// Bastion's own roof.
    func meterGain(from move: MoveSummary, context: PassiveContext) -> Int {
        guard move.collectedPickup != nil else { return 0 }

        // The sanctuary as it stood when the coin was opened. Read from the
        // context rather than from the engine because by the time charge is
        // priced the move has already resolved — and a Bastion expiring on this
        // very move must still pay for the coin taken under it.
        guard context.signState.isSheltered(move.restingPoint, on: move.endingPlane)
        else { return 0 }

        return GameRules.sanctuaryPickupCharge
    }

    func activate(context: PassiveContext, generator: inout SeededRandom) -> [GameEvent] {
        var state = context.signState
        state.sanctuary = SignState.Sanctuary(
            centre: context.piecePoint,
            plane: context.plane,
            movesRemaining: GameRules.sanctuaryMoves,
            radius: GameRules.sanctuaryRadius
        )

        // Re-raising it on the same square is a refresh, not a second one:
        // `sanctuary` holds one region, and this replaces it outright.
        return [.signStateChanged(state)]
    }
}

/// Marks the squares a sanctuary is protecting, and how long it has left.
///
/// ## Why it reads as a floor and not as a wall
///
/// The Bastion protects *ground*. Drawn as a dome or a bubble it would suggest
/// the piece inside is safe, which is not what it does — a piece can still fall
/// through a hole that was already there, and can still walk out of it. A lit
/// floor with a hard edge says exactly what is true: these squares, not this
/// space.
///
/// ## Why the last move looks different
///
/// A three-move buff that vanishes without warning is a buff the player cannot
/// plan around, and planning around it is the entire ability. On its final move
/// the pulse roughly doubles in rate — read at a glance, without a number to
/// parse.
struct SanctuaryView: View {

    let sanctuary: SignState.Sanctuary
    let metrics: PixelArtMetrics

    var body: some View {
        TimelineView(.animation) { timeline in
            let beat = pulse(at: timeline.date.timeIntervalSinceReferenceDate)

            ZStack {
                ForEach(points, id: \.self) { point in
                    Rectangle()
                        .fill(water.deep)
                        .frame(width: metrics.tileSize, height: metrics.tileSize)
                        .position(metrics.center(of: point))
                }
                .opacity(GameRules.sanctuaryFieldOpacity * (0.75 + 0.25 * beat))

                border(beat: beat)

                bubbles(at: timeline.date.timeIntervalSinceReferenceDate)
            }
            .blendMode(.plusLighter)
        }
        .frame(width: metrics.boardSize, height: metrics.boardSize)
        .allowsHitTesting(false)
    }

    /// The drawn water, one bubble per sheltered square, looping for as long as
    /// the Bastion stands.
    ///
    /// The lit floor says *which squares*; this says *what is happening to
    /// them*. Neither alone is enough — a floor tint is easy to miss under the
    /// board's own colour, and bubbles without an edge do not tell you where the
    /// protection stops.
    private func bubbles(at now: TimeInterval) -> some View {
        ZStack {
            ForEach(points, id: \.self) { point in
                // The dark bubble on dark squares, the light one on light.
                // Stacked, the two strips are near enough identical that the
                // pair read as one drawing at slightly wrong opacity; split
                // across the chequer they pick up the board's own alternation.
                let effect = EffectSprite.bastionBubble(on: .at(point))

                // Every square on its own phase: bubbles in lockstep read as one
                // animation stamped nine times.
                let lag = Self.offset(of: point) * effect.duration
                let frame = Int(max(now - lag, 0) / effect.rate.frameDuration) % effect.frames
                let side = metrics.tileSize * GameRules.sanctuaryTileSpan

                PixelSprite(id: .effect(effect), frame: frame) { EmptyView() }
                    .frame(width: side, height: side)
                    .offset(y: -effect.groundLift * metrics.scale)
                    .position(metrics.center(of: point))
            }
        }
    }

    /// How far into its own cycle a square's bubble sits, `0`…`1`.
    ///
    /// Hashed from the square so it is stable: a bubble that reshuffled its
    /// phase between frames would flicker rather than loop.
    private static func offset(of point: GridPoint) -> Double {
        var z = UInt64(bitPattern: Int64(point.x &* 73_856_093 &+ point.y &* 19_349_663))
        z = (z ^ (z >> 33)) &* 0xFF51_AFD7_ED55_8CCD
        z = (z ^ (z >> 33)) &* 0xC4CE_B9FE_1A85_EC53
        z ^= z >> 33
        return Double(z % 1_000) / 1_000
    }

    /// The edge, drawn around the whole patch rather than around each square —
    /// it is one place, not nine.
    private func border(beat: Double) -> some View {
        let bounds = self.bounds
        let width = CGFloat(bounds.maxX - bounds.minX + 1) * metrics.tileSize
        let height = CGFloat(bounds.maxY - bounds.minY + 1) * metrics.tileSize

        let middle = CGPoint(
            x: (CGFloat(bounds.minX + bounds.maxX) / 2 + 0.5) * metrics.tileSize,
            y: (CGFloat(bounds.minY + bounds.maxY) / 2 + 0.5) * metrics.tileSize
        )

        return Rectangle()
            .strokeBorder(
                water.bright,
                lineWidth: GameRules.sanctuaryBorderWidth * metrics.scale
            )
            .frame(width: width, height: height)
            .position(middle)
            .opacity(0.45 + 0.55 * beat)
    }

    // MARK: - Shape of the patch

    /// Every square inside it, clipped to the board.
    ///
    /// Clipped rather than clamped: raising the Bastion in a corner protects the
    /// four squares that exist there, it does not slide the patch inward to keep
    /// all nine.
    private var points: [GridPoint] {
        let bounds = self.bounds
        return (bounds.minY...bounds.maxY).flatMap { y in
            (bounds.minX...bounds.maxX).map { GridPoint($0, y) }
        }
    }

    private var bounds: (minX: Int, maxX: Int, minY: Int, maxY: Int) {
        let last = GameRules.gridSize - 1
        return (
            minX: max(sanctuary.centre.x - sanctuary.radius, 0),
            maxX: min(sanctuary.centre.x + sanctuary.radius, last),
            minY: max(sanctuary.centre.y - sanctuary.radius, 0),
            maxY: min(sanctuary.centre.y + sanctuary.radius, last)
        )
    }

    // MARK: - Clocks

    /// Cancer is water, so the Bastion is drawn from water's own ramp — the same
    /// one its bursts use.
    private var water: ElementFX { .ramp(for: .water) }

    /// `0`…`1`, quickening on the final move.
    private func pulse(at now: TimeInterval) -> Double {
        let period = sanctuary.movesRemaining <= 1
            ? GameRules.sanctuaryFinalPulsePeriod
            : GameRules.sanctuaryPulsePeriod

        return (sin(now / period * 2 * .pi) + 1) / 2
    }
}
