//
//  PickupDescriptors.generated.swift
//  Project Stars
//
//  GENERATED FROM _Design/Pickups.xlsx — DO NOT EDIT.
//  Change the sheet and run: python3 Tools/generate_pickups.py
//

/// What every pickup is called, says, and how often it turns up.
///
/// One table rather than a property on each of twenty-seven structs,
/// because it is one kind of fact and it is authored somewhere else. The
/// structs keep `plan(...)`, which is the half a spreadsheet cannot hold.
enum PickupDescriptors {

    static let all: [PickupID: PickupDescriptor] = [
        // chance: The rarest thing that is not pinned to a single square. Choosing
        // your own sign is the strongest effect in the game — it converts a bad
        // run into whichever run you wanted — so it has to be the one you almost
        // never see.
        .alignment: PickupDescriptor(
            displayName: "Alignment",
            summary: "When fully aligned, even the stars reaarange to your will.",
            glyph: "✧",
            icon: "alignment",
            chance: 1,
            spawnPlane: nil,
            element: nil,
            appearance: .standard,
            pickupClass: .pentacle
        ),
        // chance: The four Essences are what the uncommon tier is *for*, and their
        // current rate plays well — three each keeps it where it was while the
        // warps come down around them.
        .astralBlaze: PickupDescriptor(
            displayName: "Astral Essence ✧ Blaze",
            summary: "The ring of tiles around you loses one stage. Gain 1 ZC per tile damaged, 2 per tile broken.",
            glyph: "✷",
            icon: "Element_Fire",
            chance: 5,
            spawnPlane: nil,
            element: .fire,
            appearance: .standard,
            pickupClass: .pentacle
        ),
        // chance: The four Essences are what the uncommon tier is *for*, and their
        // current rate plays well — three each keeps it where it was while the
        // warps come down around them.
        .astralBlossom: PickupDescriptor(
            displayName: "Astral Essence ✧ Blossom",
            summary: "A ring of Astral energy blooms around you. On Astra it fully heals the ring; on Terra it mends one stage and leaves flowers, even on holes.",
            glyph: "✽",
            icon: "Element_Earth",
            chance: 5,
            spawnPlane: nil,
            element: nil,
            appearance: .standard,
            pickupClass: .pentacle
        ),
        // chance: Never drawn directly — see the note above.
        .astralBolt: PickupDescriptor(
            displayName: "Astral Essence ✧ Bolt",
            summary: "Struck by Astral lightning, you are super-charged for \(GameRules.starMoves) turns. You do not damage tiles or fall in holes, and gain 1 ZC each turn.",
            glyph: "⚡︎",
            icon: "Element_Wind",
            chance: 0,
            spawnPlane: nil,
            element: nil,
            appearance: .standard,
            pickupClass: .pentacle
        ),
        // chance: The four Essences are what the uncommon tier is *for*, and their
        // current rate plays well — three each keeps it where it was while the
        // warps come down around them. | element: The player picks the
        // destination, so this effect suspends the move.
        .astralBreeze: PickupDescriptor(
            displayName: "Astral Essence ✧ Breeze",
            summary: "An Astral wind carries you to a tile of choice within this plane.",
            glyph: "❁",
            icon: "breeze",
            chance: 5,
            spawnPlane: nil,
            element: .air,
            appearance: .standard,
            pickupClass: .pentacle
        ),
        // chance: The four Essences are what the uncommon tier is *for*, and their
        // current rate plays well — three each keeps it where it was while the
        // warps come down around them. | summary: Says where it takes you and not
        // what it ignores on the way. The hole-crossing is the discovery: a player
        // learns the Brook passes over gaps by watching it pass over one, which is
        // worth more than being told. One line for both planes, because a coin
        // that describes itself differently depending on where you found it is a
        // coin the player has to read twice.
        .astralBrook: PickupDescriptor(
            displayName: "Astral Essence ✧ Brook",
            summary: "An Astral water current carries you forward to the edge of the plane.",
            glyph: "≈",
            icon: "Element_Water",
            chance: 5,
            spawnPlane: nil,
            element: .water,
            appearance: .standard,
            pickupClass: .pentacle
        ),
        // chance: A little more likely than Z-Charge, whose weight is 1. |
        // spawnPlane: Astra only.
        .astralEssence: PickupDescriptor(
            displayName: "Astral Essence",
            summary: "The power of the stars energizes your next \(GameRules.essenceMoves) steps.",
            glyph: "◎",
            icon: "soul",
            chance: 20,
            spawnPlane: .astra,
            element: nil,
            appearance: .standard,
            pickupClass: .pentacle
        ),
        // chance: Three against Z-Charge's one, which with the common tier at 75
        // makes this a little over half of every coin opened — three grabs in
        // five, near enough. It is the floor the whole economy sits on: a coin
        // that mends one tile is small enough to be the ordinary case and still
        // worth crossing the board for.
        .restoreTile: PickupDescriptor(
            displayName: "Astral Tears",
            summary: "Fully restores the tile you are standing on and one other at random.",
            glyph: "✚",
            icon: "heart_drop",
            chance: 33,
            spawnPlane: nil,
            element: nil,
            appearance: .standard,
            pickupClass: .pentacle
        ),
        // chance: Never rolled. Placed by `PiscesAridAquanaut` and by a fall — see
        // `GameEngine.scatterMeterAsBubbles(on:)`. | summary: Says what it is, not
        // what it pays. | pickupClass: Gathered, not chosen — several stand at
        // once and taking one leaves the others. See `PickupClass.scatter`.
        .bubble: PickupDescriptor(
            displayName: "Delta Droplet",
            summary: "A droplet of pure, distilled Astral energy.",
            glyph: "🫧",
            icon: "pisces_droplet",
            chance: 0,
            spawnPlane: nil,
            element: .water,
            appearance: .bubble,
            pickupClass: .scatter
        ),
        // chance: Below the Essences: a warp rearranges where the whole run is
        // happening, which is a bigger event than any single tile changing. |
        // displayName: Renamed off "Corner Current", which collided with Aquarius'
        // Crazy Current — one is a coin that moves you once, the other is the rule
        // that governs how that sign moves at all, and two things called *current*
        // in a game about being carried around is a word doing too much work.
        .cornerWarp: PickupDescriptor(
            displayName: "Corner-Cut",
            summary: "An Astral gust takes you to a random corner of the plane.",
            glyph: "⟀",
            icon: "corner_cut",
            chance: 5,
            spawnPlane: nil,
            element: nil,
            appearance: .standard,
            pickupClass: .pentacle
        ),
        // chance: One, down from three. Being *given* a Zodea is still the lesser
        // of the pair against Alignment, which is a decision — but three made it
        // the commonest rare in the game, and a coin that rewrites who you are
        // playing should read as an event rather than as a mechanic you plan
        // around.
        .forcedFate: PickupDescriptor(
            displayName: "Forced Fate",
            summary: "The stars have ordained your Zodea has changed.",
            glyph: "✦",
            icon: "forced_fate",
            chance: 2,
            spawnPlane: nil,
            element: nil,
            appearance: .standard,
            pickupClass: .pentacle
        ),
        // chance: Never rolled. Placed by `PiscesGaiaGeyser` and by a pool burning
        // off. | pickupClass: Not part of the hunt — see `PickupClass`. Droplets
        // are put on the board deliberately and are meant to stay there, so the
        // sparkle phase carries on around them and taking a Pentacle does not
        // shatter them.
        .gaiaDroplet: PickupDescriptor(
            displayName: "Gaia Droplet",
            summary: "Gain \(GameRules.gaiaDropletCharge) ZC.",
            glyph: "💧",
            icon: "bubbles2",
            chance: 0,
            spawnPlane: nil,
            element: .water,
            appearance: .droplet,
            pickupClass: .boon
        ),
        // chance: Zero, so it is never rolled by anyone. Libra swaps it into the
        // Nexys Shift's place through `ZodiacPassive.pickupWeight` — the same
        // idiom Pisces uses to trade Z-Charge against the Tear.
        .galeforceGavel: PickupDescriptor(
            displayName: "Galeforce Gavel",
            summary: "Tip the scales in your favor by placing tiles where you see fit.",
            glyph: "⚖",
            icon: "fluffy_swirl",
            chance: 0,
            spawnPlane: nil,
            element: .air,
            appearance: .gavel,
            pickupClass: .pentacle
        ),
        .matchShiftMiasma: PickupDescriptor(
            displayName: "Match-shift Miasma",
            summary: "A strange sigil forms below.",
            glyph: "≈",
            icon: "typhoon",
            chance: 4,
            spawnPlane: nil,
            element: nil,
            appearance: .standard,
            pickupClass: .pentacle
        ),
        .nexyialBastion: PickupDescriptor(
            displayName: "Nexyial Bastion",
            summary: "Astral energy emits from the Nexys, protecting a tile from its next damage.",
            glyph: "◇",
            icon: "shield_reflect",
            chance: 4,
            spawnPlane: nil,
            element: nil,
            appearance: .standard,
            pickupClass: .pentacle
        ),
        // chance: The rarest uncommon. Moving the island moves the one fixed
        // landmark on the board, and at its old rate it was turning up often
        // enough that the Nexys stopped feeling fixed at all.
        .nexysShift: PickupDescriptor(
            displayName: "Nexys Node",
            summary: "Return to the Nexys. Summon it if on a different plane.",
            glyph: "◈",
            icon: "nexys_node",
            chance: 5,
            spawnPlane: nil,
            element: nil,
            appearance: .standard,
            pickupClass: .pentacle
        ),
        // appearance: Bright and starlit rather than the anonymous gold coin — a
        // legendary is rare enough that telegraphing it is the point. |
        // rollsAsRarity: Rolled among the commons, not the legendaries. Being
        // pinned to one square already makes it rare: a sparkle set has to cover
        // the top-centre tile before Polaris is even a candidate. Charging it
        // legendary odds *as well* is two gates on the same door, and it is why it
        // was never seen. | chance: Zero: Polaris never wins an ordinary draw. It
        // is placed by `GameEngine.drawPickup(at:on:)`, which asks the only
        // question that decides it — whether this is the north-middle tile, and
        // whether the third came up. Being in the weighted roll as well would be
        // two lotteries for one prize.
        .polaris: PickupDescriptor(
            displayName: "Polaris",
            summary: "A fragment of Old Astra, radiating with power. Restores the current plane, on your word.",
            glyph: "★",
            icon: "eclipse_star",
            chance: 0,
            spawnPlane: nil,
            element: nil,
            appearance: .radiant,
            pickupClass: .pentacle
        ),
        .polarityProngs: PickupDescriptor(
            displayName: "Polarity Prongs",
            summary: "Shards of Astra rain down in an oddly specific pattern, emitting pulling pulses",
            glyph: "◈",
            icon: "crystal_shower",
            chance: 2,
            spawnPlane: .terra,
            element: nil,
            appearance: .standard,
            pickupClass: .pentacle
        ),
        .seismicShakedown: PickupDescriptor(
            displayName: "Seismic Shakedown",
            summary: "Worrying warranted.",
            glyph: "▰",
            icon: "groundbreaker",
            chance: 2,
            spawnPlane: .terra,
            element: nil,
            appearance: .standard,
            pickupClass: .pentacle
        ),
        // appearance: Desaturated and dark, so it is recognisable on sight. |
        // chance: As rare as Polaris. It is the other legendary, and the only coin
        // in the game that makes the board *worse* on purpose.
        .shadowWork: PickupDescriptor(
            displayName: "Shadow Work",
            summary: "Sometimes true power comes from conquering the darknesses avoided within self.",
            glyph: "☾",
            icon: "cross_flare",
            chance: GameRules.shadowWorkChance,
            spawnPlane: nil,
            element: nil,
            appearance: .shadow,
            pickupClass: .pentacle
        ),
        .stardar: PickupDescriptor(
            displayName: "Stardar",
            summary: "Trust the glimmer of the stars to guide you to fortune",
            glyph: "◎",
            icon: "radar",
            chance: 4,
            spawnPlane: nil,
            element: nil,
            appearance: .standard,
            pickupClass: .pentacle
        ),
        .stellunaSprite: PickupDescriptor(
            displayName: "Stelluna Sprite",
            summary: "A peculiar fairy whose sparkling wings make those it visits feel safe and protected.",
            glyph: "✧",
            icon: "fairy",
            chance: 3,
            spawnPlane: nil,
            element: nil,
            appearance: .standard,
            pickupClass: .pentacle
        ),
        // spawnPlane: Terra only. There is no ground to crack on Astra.
        .trivialTremor: PickupDescriptor(
            displayName: "Trivial Tremor",
            summary: "Nothing to worry about.",
            glyph: "▪︎",
            icon: "slab",
            chance: 10,
            spawnPlane: .terra,
            element: nil,
            appearance: .standard,
            pickupClass: .pentacle
        ),
        // chance: On the uncommon-rare cusp: the weight sits at the bottom of its
        // tier.
        .unknownEssence: PickupDescriptor(
            displayName: "Unknown Essence",
            summary: "A strange black mist that crystalizes into sharp blades on contact, sapping ZC for the next \(GameRules.essenceMoves) turns.",
            glyph: "◍",
            icon: "spiked_swirl",
            chance: 1,
            spawnPlane: nil,
            element: nil,
            appearance: .standard,
            pickupClass: .pentacle
        ),
        // chance: Never drawn from the table. See the type's note.
        .virgoVictorylap: PickupDescriptor(
            displayName: "Virgo Victorylap",
            summary: "Mends the tile it was on, hole or not, and fills your meter.",
            glyph: "✦",
            icon: nil,
            chance: 0,
            spawnPlane: nil,
            element: nil,
            appearance: .standard,
            pickupClass: .pentacle
        ),
        // chance: One against the Tear's three. Charge is the consolation prize
        // for a coin that was not a repair, not the other way round.
        .zCharge: PickupDescriptor(
            displayName: "Z-Charge",
            summary: "Gain \(GameRules.zChargePentacleAmount) ZC.",
            glyph: "⚡",
            icon: "charge",
            chance: 20,
            spawnPlane: nil,
            element: nil,
            appearance: .standard,
            pickupClass: .pentacle
        ),
        .zodaemoniteSkull: PickupDescriptor(
            displayName: "Zodaemonite Skull",
            summary: "A strange skull made of Zodaemonite; a pitch-black ore from deep beneath Terra. Your Zodea's Astral Essence is sapped upon touch.",
            glyph: "☠",
            icon: "skull_slices",
            chance: 2,
            spawnPlane: nil,
            element: nil,
            appearance: .standard,
            pickupClass: .pentacle
        ),
    ]
}
