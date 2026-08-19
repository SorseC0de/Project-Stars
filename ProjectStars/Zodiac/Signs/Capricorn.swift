//
//  Capricorn.swift
//  Project Stars
//
//  ♑ Capricorn — The Sea-Goat
//
//  Everything specific to this sign lives in this file. Capricorn is an earth
//  sign, so it is stronger on **Terra** and weaker on **Astra**.
//

import SwiftUI

// MARK: - Definition

extension ZodiacCatalog {

    /// ♑ Capricorn — The Sea-Goat. Earth, Dec 22 – Jan 19. Strong on Terra.
    static let capricorn = ZodiacDefinition(
        sign: .capricorn,
        displayName: "Capricorn",
        glyph: "♑",
        element: .earth,
        accentColor: Color(hex: 0x6B_7A_8F),

        // Capable Climber. The northward vault is offered by
        // `CapricornCapableClimber` only while it is off cooldown, and charged
        // for by the same passive once taken.
        movement: .cardinalStep,

        passives: [
            CapricornCapableClimber(),
            CapricornHeavenlyHooves(),
            CapricornCelestialCommerce(),
        ],
        zodiaction: CapricornCosmicCashIn(),
        constellation: ZodiacCatalog.capricornConstellation
    )

    /// ♑ Capricorn: the long shallow triangle of the sea-goat.
    static let capricornConstellation = Constellation(
        stars: [
            Constellation.Star(-1.10,  0.75,  0.20, 1.1),
            Constellation.Star(-0.30,  0.20,  0.05, 0.8),
            Constellation.Star( 0.55,  0.60, -0.15, 0.9),
            Constellation.Star( 1.10,  0.05, -0.25, 1.0),
            Constellation.Star( 0.25, -0.85,  0.10, 0.9),
            Constellation.Star(-0.70, -0.45,  0.25, 0.8),
        ],
        lines: [(0, 1), (1, 2), (2, 3), (3, 4), (4, 5), (5, 0)]
    )
}

// MARK: - Passive 1: Capable Climber

/// Northward, the goat may vault two squares instead of stepping one — then must
/// take a turn before it can do it again.
///
/// North only, and absolutely so: it does not follow the facing. Climbing is a
/// direction on the board, not a direction relative to the climber.
///
/// The goat climbs. There is no cost and no waiting.
///
/// The cooldown is gone: it existed to price a two-square move when every square
/// crossed was a square worn, and a slide's ends carry that now. A vault touches
/// only where it lands, which is already less ground than two steps would cost.
struct CapricornCapableClimber: ZodiacPassive {

    let icon: String? = "capricorn_climber"
    let displayName = "Capable Climber"
    let summary = "Astra & Terra: northward moves may vault 2 tiles instead of stepping 1."

    func adjustedMovement(base: MovementPattern, context: PassiveContext) -> MovementPattern {
        .mountainClimber
    }
}

// MARK: - Passive 2: Heavenly Hooves

/// The goat does not fall while it is climbing.
///
/// Standing over a hole is survivable so long as Capricorn is *facing north*.
/// A blanket rule rather than a charge or a cooldown: it is always true, it is
/// easy to hold in your head, and it turns the vault into a real route — climb
/// onto a hole and stay there, so long as you keep looking up.
///
/// It is also the whole reason the vault lost its cooldown. The two are one
/// idea: north is where this sign is going, and north is where it is safe.
struct CapricornHeavenlyHooves: ZodiacPassive {

    let icon: String? = "capricorn_hooves"
    let displayName = "Heavenly Hooves"
    let summary = "Astra & Terra: while facing north, you stand on holes instead of falling through them."

    func preventsFall(from plane: Plane, at point: GridPoint, context: PassiveContext) -> Bool {
        context.facing == .up
    }

    /// **Hidden: soft ground to push off from.**
    ///
    /// Standing on grass or flowers, the goat can leap two squares in *any* of
    /// the eight directions rather than only climbing north — and the tile pays
    /// on the way out instead of on the way in, because the wear is him
    /// shoving off it.
    ///
    /// Not in the summary. The goat is the sign that climbs, and finding out
    /// that a meadow lets him bound anywhere is the kind of thing worth
    /// discovering rather than reading. It also gives Taurus' fields a meaning
    /// for somebody who is not Taurus, which is the point of cover being a
    /// property of the *board* rather than of the bull.
    func adjustedMovement(base: MovementPattern, context: PassiveContext) -> MovementPattern {
        guard standsOnCover(context) else { return base }

        return MovementPattern(
            name: base.name,
            options: base.options + [
                .init(.everyWay, distance: 2, style: .superJump)
            ]
        )
    }

    /// The push-off is what wears the ground, so it is charged on exit.
    func wearTiming(context: PassiveContext) -> WearTiming {
        standsOnCover(context) ? .onExit : .onEntry
    }

    private func standsOnCover(_ context: PassiveContext) -> Bool {
        let board = context.currentBoard
        guard board.contains(context.piecePoint) else { return false }
        return board[context.piecePoint].cover != nil
    }
}

// MARK: - Passive 3: Celestial Commerce

/// Pentacles are money. Opening one banks what was inside it.
///
/// ## What it changes
///
/// A coin does not go off when Capricorn opens it. Whatever it held is put in a
/// purse, and the coin itself is worth one charge — so the meter counts
/// *Pentacles collected* rather than deeds done, which is why it is drawn as
/// coins instead of pips.
///
/// Z-Charge is the one exception: charge cannot be stored as charge, so it is
/// simply gained.
///
/// ## Why a hoard is not a problem
///
/// Seven Astral Tears in the purse is a perfectly reachable state and it is
/// fine, because the meter is the rate limit rather than the purse. Every one of
/// those Tears was a Pentacle walked to, and each one *spent* costs a full meter
/// — eight or ten more Pentacles, and all the ground it takes to reach them.
/// Capricorn pays for its stockpile in the only currency this game has, which is
/// board.
///
/// ## Why the cap is lower below
///
/// Ten on Astra, eight on Terra. Capricorn is an earth sign and belongs down
/// there, so the cheaper purse is the price of being at home — a smaller cap
/// bites less than a slower fill would, because it costs the *ceiling* rather
/// than every coin along the way.
struct CapricornCelestialCommerce: ZodiacPassive {

    let icon: String? = "capricorn_commerce"
    let displayName = "Celestial Commerce"
    let summary = "Astra & Terra: Pentacles are banked instead of opened, and each is worth 1 ZC. Spend them with Cosmic Cash-in."

    /// A Pentacle is worth a coin. Nothing else is.
    ///
    /// Deliberately tied to having *collected* one rather than to charge in
    /// general. Capricorn's meter is drawn as coins because it counts coins —
    /// and once Leo can borrow this, any charge-granting ability in the game
    /// would otherwise fill the purse without a Pentacle ever being picked up,
    /// which makes the display a lie and the ability a loophole.
    ///
    /// Charge from elsewhere still charges the meter. It simply is not a coin.
    func meterBonus(from move: MoveSummary, context: PassiveContext) -> Int {
        move.collectedPickup == nil ? 0 : 1
    }

    /// Every Pentacle goes in the purse instead of going off.
    ///
    /// The hook this whole passive is named for, and it was never answered —
    /// the engine asked, got the protocol's default of `false`, and Capricorn
    /// spent the day opening coins on touch with an empty belt. Z-Charge is
    /// excluded by the engine rather than here, because "charge cannot be stored
    /// as charge" is a fact about charge, not about this sign.
    /// Everything but Polaris.
    ///
    /// Polaris already **is** a carried decision — it goes dormant or charged
    /// and waits for your word, which is the same shape as the purse. Banking
    /// it gives one item two carrying systems, and the player two different
    /// places to look for the same thing. Whichever fires first makes the other
    /// a dead end.
    ///
    /// It keeps its own, because it is the one the item was written with and it
    /// works for all twelve signs rather than for one.
    func banksPickups(_ id: PickupID, context: PassiveContext) -> Bool { id != .polaris }
}

// MARK: - Zodiaction: Cosmic Cash-in

/// The purse, spent one coin at a time.
///
/// ## Why a full meter buys exactly one thing
///
/// Everything in the shop costs the same because everything in the shop was
/// already paid for once — by finding it. A Polaris in the purse is rare because
/// Polaris is rare, not because it is priced higher, and pricing it twice would
/// punish the luck that put it there.
///
/// ## Why it does not take over the screen
///
/// The shop is a strip under the board, not a page over it: Capricorn is
/// choosing what to do *with* the board, and hiding the board to decide is the
/// wrong way round. See `ShopBarView`.
struct CapricornCosmicCashIn: Zodiaction {

    let displayName = "Cosmic Cash-in"
    let summary = "Spend a full purse to set off any one Pentacle you have banked."

    /// The purse fills from Celestial Commerce.
    func meterGain(from move: MoveSummary, context: PassiveContext) -> Int { 0 }

    /// Ten coins on Astra, eight on Terra.
    ///
    /// Capricorn's meter and its purse are the same thing seen twice, so this
    /// reads the purse's capacity rather than keeping a second copy of the
    /// numbers. A sign that merely *borrows* Commerce keeps its own meter and
    /// only inherits the purse — see `GameRules.purseCapacity(on:)`.
    func meterMax(on plane: Plane) -> Int {
        GameRules.purseCapacity(on: plane)
    }

    /// Nothing to spend it on is not a Zodiaction that can fire.
    func canActivate(context: PassiveContext) -> Bool {
        !context.signState.purse.isEmpty
    }

    /// Opening the shop is the whole of it. What is bought, and the events that
    /// follow, are `GameEngine.planChoice(_:)` — the same shape as a Pentacle
    /// that waits on an answer.
    func activate(context: PassiveContext, generator: inout SeededRandom) -> [GameEvent] {
        [.choiceRequested(source: .zodiaction(.capricorn), kind: .shop)]
    }
}
