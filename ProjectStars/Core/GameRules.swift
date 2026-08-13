//
//  GameRules.swift
//  Project Stars
//
//  Every tunable number and rule toggle in one place.
//

import CoreGraphics
import Foundation

/// Central balance and presentation constants.
///
/// Anything a designer might want to change during tuning lives here rather
/// than being buried in the engine or a view. Nothing in this file depends on
/// SwiftUI, so the rules are safe to use from tests.
///
/// - Important: **The game is move-based, not time-based.** No game state ever
///   changes on a timer — every mutation is the consequence of a committed
///   move. The `TimeInterval` values at the bottom of this file pace the
///   *replay* of a move that has already been fully decided; deleting them all
///   would change how the game looks and nothing about how it plays. Do not add
///   a rule that fires on a clock.
enum GameRules {

    // ──────────────────────────────────────────────────────────────────────
    // MARK: - Game mode
    //
    // Some rules cannot be the same in a one-player run and a two-player match.
    // The obvious one is Astra healing itself on every descent: in solo that is
    // what makes long runs possible, and in versus it is a reset button on the
    // work your opponent did up there.

    /// Which game this is.
    enum Mode {
        /// One player against the board. Everything shipped so far.
        case solo

        /// Two players on one board, alternating turns.
        ///
        /// - Note: Nothing selects this yet. It exists so that values which will
        ///   differ can be *written down as they are discovered* during solo
        ///   testing, rather than being reconstructed from memory later.
        case versus
    }

    /// The mode the current run is being played under.
    ///
    /// ## Why this is a `var` when nothing else here is
    ///
    /// Every other value in this file is a constant, deliberately. This one is
    /// not a tuning knob but a statement about which game is being played, set
    /// once before a run begins and never touched during it.
    ///
    /// - Important: It is process-wide. That is fine while one device plays one
    ///   game at a time, and is the thing to revisit if a versus match is ever
    ///   verified server-side by simulating both players in one process.
    static var mode: Mode = .solo

    /// Picks the value for the mode in play.
    ///
    /// Written this way so that converting a constant costs nothing at its call
    /// sites — `static let x = 3` becomes `static var x: Int { tuned(solo: 3,
    /// versus: 5) }` and every `GameRules.x` in the codebase is unchanged.
    ///
    /// Only convert a value once versus genuinely needs it to differ. A value
    /// that reads the same in both modes is clearer as a plain constant.
    static func tuned<Value>(solo: Value, versus: Value) -> Value {
        switch mode {
        case .solo: solo
        case .versus: versus
        }
    }

    // ──────────────────────────────────────────────────────────────────────
    // MARK: - Board
    //
    // The shape of the world. These change what the game *is*, not how it
    // feels.

    /// Edge length of each plane, in tiles.
    static let gridSize = 7

    /// Native pixel size of one tile's art. Drives integer sprite scaling.
    static let tilePixelSize = 16

    /// Native pixel size of one imported effect frame.
    ///
    /// Four tiles across, which is why they are drawn scaled down — see
    /// `GameRules.effectSpan`.
    static let effectPixelSize = 64

    /// The centre square, where the Nexys island sits.
    static let nexysPoint = GridPoint(gridSize / 2, gridSize / 2)

    /// The plane the Nexys starts on. Also where a run begins, since the piece
    /// always starts standing on the island.
    static let startingNexysPlane: Plane = .astra

    /// The square a run begins on — always the Nexys.
    static var startingPoint: GridPoint { nexysPoint }

    /// The plane a run begins on — always the one holding the Nexys.
    static var startingPlane: Plane { startingNexysPlane }

    /// Which way the piece looks before it has moved.
    static let startingFacing: SwipeDirection = .down

    // ──────────────────────────────────────────────────────────────────────
    // MARK: - Rules — landing and wear
    //
    // What a landing costs.

    /// How much wear a normal landing inflicts on the tile landed on.
    ///
    /// Applied the moment the piece comes down. If the tile reaches `hole` as a
    /// result, the piece **cannot stand on it** and falls through in the same
    /// move — a tile that breaks under you breaks immediately.
    static let wearPerLanding = 1

    /// When `true`, a piece that falls onto a tile also wears that tile, so a
    /// drop can chain through several floors. When `false`, falling is "free"
    /// and only the tile you jumped to wears.
    static let fallingLandingCausesWear = true

    // ──────────────────────────────────────────────────────────────────────
    // MARK: - Rules — planes
    //
    // How the two boards relate: what survives a descent, and how you get
    // back up.

    /// When `true`, **Astra fully repairs itself the moment the player leaves it
    /// for Terra**.
    ///
    /// This is what makes long runs possible. Descending is not purely a loss:
    /// it resets the upper plane, so a player who can find their way back up
    /// arrives on fresh ground and can keep going. Without it every descent
    /// would be one-way and a run would be bounded by how fast Astra wore out.
    ///
    /// Only ordinary tiles are restored — the Nexys and its chasm are structural
    /// and unaffected.
    /// **Versus: off.** With two players the heal stops being a mercy and
    /// becomes a weapon — descend, undo everything your opponent built up there,
    /// climb back. Both planes decaying permanently is what makes a match a race
    /// to ruin the *other* player's ground rather than to outlast your own.
    static var astraRestoresOnDescent: Bool { tuned(solo: true, versus: false) }

    /// When `true`, coming to rest on the Nexys **while it is on Terra** rides it
    /// straight back up to Astra.
    ///
    /// This is the whole ascent mechanic, and it is one-way on purpose. Landing
    /// on the island in Astra does nothing — it is simply safe ground. Landing on
    /// it in Terra is the reward for navigating a decaying lower plane to reach
    /// it, and pairs with `astraRestoresOnDescent`: the Astra you rise to is the
    /// one your own descent repaired.
    static let nexysAscendsFromTerra = true

    /// When `true`, changing plane discards a pickup stranded on the plane the
    /// piece just left and starts a fresh sparkle phase on the new one.
    ///
    /// Without this a fall would leave the pickup somewhere the piece may not
    /// be able to return to, breaking the guarantee that one is always
    /// available.
    static let relocatePickupOnPlaneChange = true

    // ──────────────────────────────────────────────────────────────────────
    // MARK: - Rules — sparkles and Pentacle spawning
    //
    // Where the coin hides and how the hunt is shaped. How sparkles *look* is
    // under Sparkles.

    /// How many tiles sparkle at once, at most.
    ///
    /// A shaped pattern that overlaps holes or the Nexys produces *fewer* than
    /// this — the shape forms as best it can and the missing members simply are
    /// not there, which is the player's read on where the board is broken.
    static let sparkleCount = 5

    /// The fewest tiles a sparkle set may consist of.
    ///
    /// A shaped pattern with fewer surviving members than this is rejected and
    /// another placement is tried, so a `+` never degrades into a single lonely
    /// tile that reads as a scatter.
    static let minimumSparklePoints = 2

    /// Relative likelihood of each sparkle shape. Scattered is the rare one.
    static let sparklePatternWeights: [SparklePattern: Int] = [
        .plus: 40,
        .cross: 40,
        .scattered: 20,
    ]

    /// When `true`, sparkles refuse to appear under the piece's current square.
    ///
    /// Holes, the Nexys, and the Nexys chasm are excluded structurally by
    /// `Tile.canHostSparkle` and are not optional.
    static let sparklesAvoidPiece = true

    // ──────────────────────────────────────────────────────────────────────
    // MARK: - Rules — Zodiactions
    //
    // Meter cost and the fallback charge rule. Per-sign charging lives in
    // each sign's own file.

    /// Pips needed to fill a Zodiaction meter, unless a sign overrides
    /// `meterMax`. The meter is drawn as discrete ticks, not a smooth bar.
    ///
    /// Popping empties it to zero; short of that, a full meter stays full for
    /// as long as the player wants to sit on it.
    static let defaultZodiactionMeterMax = 10

    /// Charge granted per committed move by the **interim** per-sign rules.
    ///
    /// - Important: This is not a universal charge rate and must not become
    ///   one. Every sign builds its meter differently; each currently returns
    ///   this value from its own `meterGain(from:context:)` purely as a
    ///   placeholder, and each will be replaced independently.
    static let placeholderZodiactionMeterGain = 1

    // ──────────────────────────────────────────────────────────────────────
    // ──────────────────────────────────────────────────────────────────────
    // MARK: - Rules — sanctuary
    //
    // Cancer's Bubble Bastion: ground that refuses to get any worse. See
    // `SignState.Sanctuary`.

    /// How big the bubble drawn on each sheltered square is, in tiles.
    ///
    /// Smaller than a standard effect: this is one per square across the whole
    /// patch, and at full size nine of them would be a wall of water rather than
    /// nine protected tiles.
    static let sanctuaryTileSpan: CGFloat = 1.1

    /// How far it reaches from the square it is raised on.
    ///
    /// `1` gives the 3x3. Drop it to `0` for a single square if the ability
    /// proves too strong — the region is derived from this, so that is the only
    /// change needed.
    static let sanctuaryRadius = 1

    /// How many committed moves it stands for.
    static let sanctuaryMoves = 5

    /// How far the Bastion's lower bubble lags its upper one, in seconds.
    ///
    /// The two strips are near enough identical, so a difference in rate alone
    /// is hard to see — they still line up at the start of every cycle. Offsetting
    /// where one *begins* is what makes the pair read as two bodies of water
    /// rather than one drawn twice.
    static let sanctuaryLayerStagger: TimeInterval = 0.22

    /// Bonus charge for opening a Pentacle inside it.
    static let sanctuaryPickupCharge = 3

    /// How brightly the protected floor is lit, and how heavy its edge is in art
    /// pixels. See `SanctuaryView`.
    static let sanctuaryFieldOpacity: Double = 0.22
    static let sanctuaryBorderWidth: CGFloat = 1

    /// Seconds per pulse, and the quicker one it switches to on its final move
    /// so the player can see it about to lapse.
    static let sanctuaryPulsePeriod: TimeInterval = 2.4
    static let sanctuaryFinalPulsePeriod: TimeInterval = 1.1

    // ──────────────────────────────────────────────────────────────────────
    // ──────────────────────────────────────────────────────────────────────
    // MARK: - Rules — elemental affinity

    /// What a Z-Charge is worth to Pisces on Terra.
    ///
    /// Above the ordinary grant because Terra is where Pisces is on a timer:
    /// Gaia Geyser fills the meter on arrival, Astral Attunement drains it every
    /// square, and Upstream costs the lot. Finding charge has to be able to
    /// outrun the leak, or crossing the board to a coin is a net loss.
    static let aridAquanautCharge = 5

    /// How often an Astral Essence turns out to be the fifth one.
    ///
    /// Rolled *inside* the Essence result rather than beside it, so the Bolt
    /// cannot dilute anything else: the odds of getting "an Essence" are
    /// unchanged, and this decides which one you got.
    ///
    /// Deliberately tiny. At the Essences' combined 17% this is about one coin
    /// in four hundred — many complete games between sightings. That is the
    /// design: it is supposed to be a thing players tell each other about, and
    /// something seen every few games is not that.
    static let astralBoltChance = 0.015

    /// How many committed moves the Bolt's charge lasts.
    ///
    /// **Versus: shorter, provisionally.** Ten moves of walking on holes and
    /// taking no wear is strong against the board; against a person it is ten
    /// moves they cannot touch you while you wreck the ground they need. Written
    /// down as a starting guess, not a tested number.
    static var starMoves: Int { tuned(solo: 10, versus: 6) }

    /// Charge gained per move while it runs, whatever the sign.
    static let starChargePerMove = 1

    /// How far the star's orbiting sparks sit above the piece's square, in art
    /// pixels. They ring the figure, not the tile it is standing on.
    static let starSparkLift: CGFloat = 8

    /// How many committed moves Aquarius walks on air after a gale.
    static let galeMoves = 3

    /// How far the gale's particles blow sideways as they rise, in art pixels.
    static let galeDrift: CGFloat = 14

    // ── A carried Pentacle ────────────────────────────────────────────────

    /// How big the coin riding above a sliding piece is, and how far above its
    /// square it sits, in art pixels.
    static let carriedSize: CGFloat = 7
    static let carriedLift: CGFloat = 30

    /// How far it bobs, and how long one rise and fall takes.
    static let carriedBob: CGFloat = 1.5
    static let carriedBobPeriod: TimeInterval = 0.9

    // ── Sagittarius' arrow ────────────────────────────────────────────────

    /// How many committed moves an arrow stands before it rots.
    ///
    /// A backstop, not a timer. The player is meant to experience the arrow as
    /// lasting until they use it; this only exists so that forgetting one on a
    /// plane you cannot reach does not lock you out of charging for the rest of
    /// the run.
    static let arrowMoves = 50

    /// Charge returned when the arrow finds a hole instead of ground.
    static let arrowHoleRefund = 1

    /// Charge returned when it falls through Terra's floor, bringing a cloud's
    /// worth of astral energy down with it.
    static let arrowCloudRefund = 3

    /// How the planted arrow is drawn, in art pixels — see `ArrowView`.
    static let arrowLength: CGFloat = 13
    static let arrowThickness: CGFloat = 1.4
    static let arrowHead: CGFloat = 4

    /// How far above its square it stands, and how far it leans off vertical.
    ///
    /// Straight up reads as a post; a few degrees says thrown.
    static let arrowRise: CGFloat = 5
    static let arrowLean: Double = 12

    /// Its glow, and how long one breath of it takes.
    static let arrowGlowRadius: CGFloat = 1.6
    static let arrowPulsePeriod: TimeInterval = 1.4

    /// How long the flight takes: up out of sight, and down onto its square.
    ///
    /// The descent accelerates — see `FallingCloudView` — so most of the travel
    /// happens in the back half of this, and at half a second the whole arrival
    /// went past as a flicker. A second gives the cloud time to be seen coming
    /// down, which is the only part of the shot's journey that is on screen at
    /// all.
    static let arrowFlightDuration: TimeInterval = 1.0

    /// How long a straight line has to be for Aries' Six Singe to pay.
    ///
    /// Six moves crosses a seven-wide board end to end, so it cannot be done
    /// twice in a row without turning — which is the point.
    static let sixSingeLength = 6

    /// What completing one pays.
    ///
    /// Fixed, not "however much tops the meter up". Computed, it would undo any
    /// event that had just *drained* the meter — open a Pentacle that zeroes
    /// your charge, then walk a straight line and the loss never happened. Six
    /// is what fills the meter alongside Searing Stride's four under ordinary
    /// conditions, and that is the promise: a full meter for crossing the board,
    /// not a full meter regardless of what else went on.
    static let sixSingeBonus = 6

    /// How often Leo's Magnetic Mane drags the Pentacle a square closer, by
    /// plane. Rolled once per ordinary step.
    static let magneticManeChanceAstra = 0.01
    static let magneticManeChanceTerra = 0.05

    /// How far it drags, and how far it drags while an Aten is burning.
    static let magneticManeSteps = 1
    static let magneticManeStepsWithSun = 2

    /// How often Sagittarius' Fortunate Find turns up a second Pentacle, by
    /// plane.
    ///
    /// Better below, where the hunt is more dangerous and the board does not
    /// mend itself. Drop these to 0.10 and 0.25 if two coins turn out to be too
    /// much of the game.
    static let secondPickupChanceAstra = 0.25
    static let secondPickupChanceTerra = 0.33

    /// How often Taurus' Taurean Tear fires on an Astral Tear.
    ///
    /// At `1` the bull practically does not decay on Terra: Hasty Hooves already
    /// halves what it does to the ground, and mending two tiles a coin outran
    /// even that. Half the time is still the most reliable repair in the game.
    static let taureanTearChance = 0.5


    // ── Embers ────────────────────────────────────────────────────────────
    //
    // The fire coming off a piece under Aries' Brazen Blaze. See `EmberView`.

    /// How many are in the air at once.
    static let emberCount = 7

    /// Seconds for one ember to rise and go out. Each varies around this.
    static let emberPeriod: TimeInterval = 1.1

    /// Where they start relative to the piece's centre, and how far they climb,
    /// in art pixels. The foot is positive because they begin at the feet.
    static let emberFoot: Double = 2
    static let emberRise: CGFloat = 22

    /// How far one wanders sideways as it rises, and how big it starts.
    static let emberSway: CGFloat = 3
    static let emberSize: CGFloat = 1.6

    /// How long one afterimage lasts before it is gone.
    ///
    /// Short. It is a record of where the piece just was, not a decoration that
    /// hangs around behind a piece standing still.
    static let afterimageLife: TimeInterval = 0.45

    /// How many afterimages a piece drags behind it.
    ///
    /// Drawn by a full meter and by the star, in elemental colour either way —
    /// see `AfterimageView`.
    static let afterimageCount = 3

    /// Seconds of spring response per step of lag.
    ///
    /// This is the dial for how far the trail stretches: each ghost's spring is
    /// this times its distance back, so raising it makes every one of them
    /// arrive later and the tail longer.
    static let afterimageLag: TimeInterval = 0.26

    /// What fraction of the previous ghost's opacity each one keeps.
    static let afterimageFalloff: Double = 0.82

    // ── Hovering ──────────────────────────────────────────────────────────

    /// How far a piece standing on nothing drifts up and down, in art pixels,
    /// and how long one rise and fall takes.
    ///
    /// Small and slow. A piece over a hole should look *unsupported*, which is a
    /// stillness with a drift in it rather than a bounce.
    static let hoverBob: CGFloat = 1.6
    static let hoverBobPeriod: TimeInterval = 1.6

    /// How far the shadow shrinks while hovering.
    ///
    /// Not to nothing: something is still up there, and a piece with no shadow
    /// at all reads as having been deleted rather than as floating.
    static let hoverShadowScale: CGFloat = 0.45

    // ── The strike ────────────────────────────────────────────────────────
    //
    // Every other effect's rate, size and offset lives on `EffectSprite`, since
    // those are facts about a particular strip of art. The Bolt's are here
    // because they are the ones actually being tuned, and this is where anybody
    // looks first.

    /// How fast the bolt plays.
    static let lightningRate = SpriteRate.fps15

    /// How wide it is drawn, in tiles. Height follows from the frame's own
    /// proportions — the art is 64x160, so this times two and a half.
    static let lightningSpan: CGFloat = 2

    /// How far it rides up from the middle of its square, in art pixels.
    ///
    /// The base that puts the bolt's foot on the tile is `span × 20 − 8`, so 32
    /// at the current size; anything above that lifts the strike clear of the
    /// piece's head rather than through it.
    static let lightningLift: CGFloat = 44

    /// Seconds for the piece to cycle once through all four elemental colours.
    static let starCyclePeriod: TimeInterval = 0.9

    /// How hard the cycling recolour is applied.
    static let starFlashStrength: Double = 0.9

    /// Extra charge for opening an Astral Essence that matches your element.
    ///
    /// Undocumented in the coin's own summary on purpose: it is a reward for
    /// knowing the game rather than a rule the game has to explain, and every
    /// Essence would otherwise need a sentence about eleven other signs.
    static let elementAffinityCharge = 3

    // MARK: - Rules — Leo's sun
    //
    // See `SignState.Sun` and `LeoSolarPull`.

    /// How many committed moves the sun burns for.
    static let sunMoves = 5

    /// Whether raising it mends the square underneath. Never fills a hole — a
    /// hole is not damage to the tile, it is the absence of one.
    static let sunHealsItsTile = true

    /// How many squares the Pentacle is dragged each move the sun burns.
    static let sunPullPerMove = 1

    /// How bright the sun is on its final move, so its last turn is visible as
    /// its last turn.
    static let sunGuttering: Double = 0.55

    // MARK: - Rules — Pentacle effects
    //
    // What individual Pentacles are worth. The effects themselves are in
    // Pickups/Effects/.

    /// Charge granted by the Z-Charge Pentacle.
    static let zChargePentacleAmount = 3

    /// Charge granted by Astral Tear when there is nothing left to repair.
    static let restoreTileBonusCharge = 1

    /// Charge Astral Blaze pays per tile it wears.
    static let astralBlazeChargePerDamage = 1

    /// Charge Astral Blaze pays per tile it breaks outright. Worth more than
    /// mere damage, so the effect scales with how ruined the board already is.
    static let astralBlazeChargePerBreak = 2

    // ──────────────────────────────────────────────────────────────────────
    // MARK: - Panel
    //
    // Only the two choices that change what the panel *is*. Everything about how
    // it looks — sizes, spacing, type, depth — lives in `PanelStyle`, next to
    // the views that draw it, because styling a screen means changing ten
    // numbers and looking at the result.

    /// How the player moves the piece.
    ///
    /// **Joystick** is drag-and-tap: the whole panel is the surface, the stick
    /// shows where the drag points, and a tap advances forward.
    /// **Buttons** is a keyboard cross, with a sign's special moves appearing as
    /// smaller arrows beside the direction they apply to.
    enum ControlScheme: CaseIterable { case joystick, buttons, grid }

    /// A `var` so a debug button can flip it. It becomes a stored preference
    /// once the selection screen exists.
    static var controlScheme: ControlScheme = .joystick


    // ──────────────────────────────────────────────────────────────────────
    // MARK: - Input
    //
    // How a drag becomes a move.

    /// How far the piece lunges at a move it cannot make, in art pixels, and
    /// how long the whole attempt takes.
    ///
    /// Small and quick. It is a flinch toward the wall, not a hop — the piece
    /// should look like it started and thought better of it.
    static let balkDistance: CGFloat = 3
    static let balkDuration: TimeInterval = 0.22

    /// Minimum drag length, in points, before a swipe counts as a move.
    static let minimumSwipeDistance: CGFloat = 24

    /// Extra drag length, in points, that selects each successive distance for
    /// signs whose movement offers more than one.
    ///
    /// Deliberately generous: mistaking a two-square vault for a one-square step
    /// is a much worse error than having to drag a little further.
    static let swipeReachStep: CGFloat = 78

    // ──────────────────────────────────────────────────────────────────────
    // MARK: - Sprite frame rates
    //
    // One rate per animated sprite. See `SpriteRate` for what each rate
    // suits.

    /// The clock every rate is measured against.
    static let spriteFramesPerSecond = 60

    /// What an animation runs at when it has not asked for a rate.
    static let defaultSpriteRate = SpriteRate.fps12

    // ──────────────────────────────────────────────────────────────────────
    // MARK: - Tiles
    //
    // The board's surface: how a tile lifts for a coin, how it wears, how its
    // edge is seated.

    /// How far a tile lifts when a Pentacle sits on it, revealing the edge
    /// strip drawn underneath.
    static let tilePopLift: CGFloat = 4

    /// Spring response for a tile rising as a Pentacle appears on it.
    static let tilePopRiseResponse: Double = 0.26

    /// Spring response for a tile slamming back flat once the coin is taken.
    ///
    /// Deliberately much faster than the rise: the coin lifting a tile is a
    /// flourish, the tile dropping is a consequence.
    static let tilePopFallResponse: Double = 0.11

    /// Spring response for a tile popping up and dropping back.
    ///
    /// Was much snappier when Astra's squares were stone like Terra's. A cloud
    /// rising is not a slab shoving upward, and at 0.14 the move was over before
    /// the eye could follow the colour change riding on it.
    static let tilePopResponse: Double = 0.45

    /// How much the pop overshoots. Near 1 barely bounces at all.
    ///
    /// High on purpose: the wobble that made a stone tile feel struck reads as
    /// a wobble in the cloud itself, which is the one thing it should not do.
    static let tilePopDamping: Double = 0.92

    /// How far a tile's edge strip is pushed down so its visible sliver lands
    /// at the bottom of the square.
    ///
    /// The strip occupies the top 4 rows of its cell, so 12 seats it flush with
    /// the cell's bottom edge — exactly the band a lifted face uncovers.
    ///
    /// Do not "fix" the 1px dark line visible along the bottom of every tile by
    /// changing this. That line is row 15 of the *face* sprite, painted the same
    /// colour as the edge; at any value up to 12 this layer is completely hidden
    /// behind the face, and below 12 a lifted tile exposes backdrop instead of
    /// edge.
    static let tileEdgeDrop: CGFloat = 12

    /// How far the *front* of the board's bottom row hangs below it, in art
    /// pixels.
    ///
    /// The ordinary edge pass drops each strip far enough that the row below
    /// covers it — which is right everywhere except the last row, where there is
    /// no row below and the board simply stopped, flat, like a decal. Four
    /// pixels puts the sliver flush under the bottom edge and gives the whole
    /// plane a front face, so Terra reads as a slab rather than a picture of
    /// one.
    static let tileFrontEdgeDrop: CGFloat = 4

    /// A tile visibly cracking.
    static let tileDamageDuration: TimeInterval = 0.16

    /// A tile cracking under a piece that is *leaving* it.
    ///
    /// Near-instant, unlike wear on arrival. Exit damage is emitted before the
    /// hop, so any pause here is a pause before the piece moves at all — which
    /// reads as the game hanging rather than as the tile breaking. It cracks
    /// while the piece is already on its way.
    static let tileDamageOnExitDuration: TimeInterval = 0.02

    /// A tile visibly repairing.
    static let tileHealDuration: TimeInterval = 0.22

    /// A whole area changing state at once. Longer than a single tile, because
    /// there is more to read.
    static let areaEffectDuration: TimeInterval = 0.42

    /// A whole plane repairing itself behind a descending player.
    static let planeRestoreDuration: TimeInterval = 0.30

    // ──────────────────────────────────────────────────────────────────────
    // MARK: - Astra clouds
    //
    // Astra has no tiles. Its squares are clusters of small clouds, drawn rather
    // than sprited, and wear is expressed as the cluster shrinking rather than
    // as cracks appearing. A cloud cannot crack.

    /// How wide a cluster is at each wear state, as a fraction of a cell.
    ///
    /// `badlyCracked` is deliberately about the width of a piece's base: at a
    /// glance you can see there is only just enough cloud left to stand on.
    /// A hole is nothing at all.
    static func cloudScale(_ health: TileHealth) -> CGFloat {
        switch health {
        case .healthy: 1.0
        case .cracked: 0.8
        case .badlyCracked: 0.55
        case .hole: 0
        }
    }

    // ──────────────────────────────────────────────────────────────────────
    // MARK: - Astra's cloud sprite
    //
    // The drawn replacement for the generated clusters — see `CloudSpriteField`.
    // Everything below this line is about the sheet; everything under "Astra
    // clouds" above it belongs to the archived programmatic version.

    /// Edge length of one cloud frame, in art pixels. Three board cells.
    static let cloudSpritePixelSize = 48

    /// Frames in the strip, and how fast it plays.
    static let cloudSpriteFrames = 3
    static let cloudSpriteRate = SpriteRate.fps15

    /// How far a cloud drifts from its square, as a fraction of a cell.
    ///
    /// Per-cloud and on its own phase, so the field never pulses in unison.
    static let cloudSpriteShift: CGFloat = 0.16
    static let cloudSpriteShiftPeriod: TimeInterval = 5.4

    /// How much a cloud stretches, as a fraction either side of its true size.
    ///
    /// Horizontal and vertical run on different periods on purpose: matched,
    /// they read as a single throb, and the point is that a cloud has no fixed
    /// shape.
    static let cloudSpriteStretch: CGFloat = 0.09
    static let cloudSpriteStretchPeriodH: TimeInterval = 3.7
    static let cloudSpriteStretchPeriodV: TimeInterval = 4.9

    /// How much opacity a cloud loses per stage of wear.
    ///
    /// The shrink alone was not reading as damage — the first outside tester
    /// did not realise Astra decayed at all, and could not tell why he was
    /// falling. Fading is the second, blunter signal: a square you can see
    /// through is a square about to go.
    static let cloudSpriteWearFade: Double = 0.10

    /// How high the cloud under a Pentacle floats, in art pixels, and how hard
    /// its glow breathes.
    static let cloudSpriteRaiseLift: CGFloat = 3
    static let cloudSpriteGlowPeriod: TimeInterval = 1.5
    static let cloudSpriteGlowMin: Double = 0.18
    static let cloudSpriteGlowMax: Double = 0.55
    static let cloudSpriteGlowRadius: CGFloat = 3

    /// Puffs in one cluster.
    static let cloudPuffCount = 13

    /// Flecks of light scattered through each cloud, and how big they are in
    /// art pixels. They twinkle on their own clocks, like the sparks.
    static let cloudSpeckleCount = 18
    static let cloudSpeckleSize: CGFloat = 1.25

    /// The range a speckle's size is drawn from, as a fraction of that. Wide, so
    /// a scatter of them reads as depth rather than as a dotted texture.
    static let cloudSpeckleMinScale: CGFloat = 0.55
    static let cloudSpeckleMaxScale: CGFloat = 1.6
    /// **This is the knob that decides how bunched they look.** It is the
    /// radius of the disc they are scattered on, in art pixels — the cluster
    /// itself reaches about 8, so anything much under that keeps them huddled
    /// in the middle of the cloud no matter how random the scatter is.
    static let cloudSpeckleSpread: CGFloat = 7.8

    /// Overall brightness of the flecks, on top of their own twinkle.
    static let cloudSpeckleOpacity: Double = 0.25

    /// Little curls of light lying across the upper half of each cloud —
    /// bigger than a speckle, smaller than a puff, so they read as something
    /// caught in the cloudstuff rather than as more scattered dust.
    static let cloudGlintCount = 5

    /// Curls drawn *beneath* the lit crown, in the cloud's own magenta tones
    /// rather than in light. These are meant to look like part of the material,
    /// half-buried in it, not like something sitting on the surface.
    static let cloudGlintBuriedCount = 4

    /// Curls drawn over the crown but still in the crown's own tone.
    ///
    /// These are the stitching between the two sets: an opaque curl in cloud
    /// colour crossing over the buried ones interrupts them, so the alt-coloured
    /// spirals read as woven through the cluster rather than as a layer sitting
    /// under a layer.
    static let cloudGlintMaskCount = 2

    /// How much smaller the lit blue-and-gold curls are than the cloud-toned
    /// ones, and how far out from the centre they are allowed to sit.
    ///
    /// They are held inside the cluster rather than scattered across the square
    /// like the cloud-toned curls: those are cloudstuff and can run off the
    /// edge, but a fleck of light hanging in empty sky has nothing to be caught
    /// in. Same reach the speckles use, for the same reason.
    /// How far from the square's centre curls are scattered, in art pixels
    /// across the full span.
    ///
    /// Wider than the cluster's own radius on purpose: drawn from the middle
    /// they bunch, because a centred random spread puts most of its samples
    /// near the centre.
    static let cloudGlintSpread: CGFloat = 13

    /// Width of a curl's bounding box, in art pixels, and the weight of the
    /// line it is drawn with.
    static let cloudGlintLength: CGFloat = 5.2
    static let cloudGlintThickness: CGFloat = 1.1

    /// The range a curl's size is drawn from, as a fraction of that box.
    ///
    /// Wide, because a set of curls all the same size reads as a pattern
    /// stamped on the cloud rather than as things caught in it.
    static let cloudGlintMinScale: CGFloat = 0.55
    static let cloudGlintMaxScale: CGFloat = 1.55

    /// Seconds for a curl to turn once, slowest and fastest. Direction is
    /// chosen per curl, so the cluster has some winding each way.
    static let cloudGlintSpinSlowest: TimeInterval = 26
    static let cloudGlintSpinFastest: TimeInterval = 11

    /// How many times a curl winds around itself.
    ///
    /// Deliberately low — much past one and a half and it stops reading as a
    /// gesture and starts reading as a target. Fractional turns are the point:
    /// a whole number closes the shape back on its own tail.
    static let cloudGlintTurns: Double = 1.35

    /// The range a curl's tilt is drawn from, in degrees. Signed at random, so
    /// they lean both ways; never near flat and never near upright.
    static let cloudGlintMinAngle: Double = 20
    static let cloudGlintMaxAngle: Double = 80

    /// How far a puff swells and shrinks, as a fraction of its size.
    ///
    /// Small on purpose: this is a cloud breathing, not a balloon. The life
    /// comes from every puff doing it on its own clock, not from the amount.
    static let cloudPulseSwing: CGFloat = 0.18

    /// Seconds for the slowest and fastest puff. Each picks its own from the
    /// range, so a cluster never pulses in unison.
    static let cloudPulseSlowest: TimeInterval = 4.6
    static let cloudPulseFastest: TimeInterval = 2.1

    /// How long a cloud takes to change colour as it is raised under a
    /// Pentacle. Matched to `tilePopResponse` so the tint and the lift land
    /// together.
    static let cloudRaiseTintDuration: TimeInterval = 0.45

    /// How long the cluster takes to shrink when the square wears.
    static let cloudWearDuration: TimeInterval = 0.34

    /// Whether that change steps through palette entries or blends continuously.
    ///
    /// Stepped keeps every frame inside the 47-entry palette; blended does not,
    /// though both ends of the ramp are palette colours either way and the
    /// off-palette values only exist for a fraction of a second.
    ///
    /// Blended, having looked at both: three hard cuts over half a second read
    /// as the cloud glitching, not as it changing.
    static let cloudRaiseSteps = false

    /// How far a cluster drifts, in art pixels, and how long one cycle takes.
    ///
    /// Small and slow. Clouds that visibly wandered would fight the grid the
    /// player is counting squares on.
    static let cloudDriftAmount: CGFloat = 0.6
    static let cloudDriftPeriod: TimeInterval = 5.5

    /// How many times a second the cloud field redraws.
    ///
    /// Deliberately below the display's refresh. `TimelineView(.animation)` runs
    /// at whatever the screen does — 120Hz on a ProMotion device — and Astra is
    /// two thousand primitives a pass against Terra's handful of sprites, so it
    /// was paying four times over for motion nothing can see. The clouds drift
    /// on a five-second period and the puffs breathe over seconds; thirty is
    /// more than they need, and pixel art has never wanted more.
    static let cloudFrameRate: Double = 30

    /// How long the piece takes to pick up its cloud's sway after landing.
    ///
    /// The sway belongs to standing still — mid-hop the piece is off the cloud
    /// and doing its own thing. Easing it back in rather than switching it on
    /// keeps the handover from showing.
    static let cloudSwayEaseIn: TimeInterval = 0.35

    /// Seconds a cluster takes to disperse when its square becomes a hole.
    static let cloudPoofDuration: TimeInterval = 0.5

    /// How much bigger than an ordinary puff a dispersing cloud is.
    ///
    /// A square giving way is a bigger event than a footfall and has a whole
    /// cell to vacate, so it wants more smoke than a landing does.
    static let cloudPoofMagnitude: CGFloat = 1.5

    /// How far the puffs of a dispersing cluster travel, in art pixels.
    static let cloudPoofSpread: CGFloat = 7

    // ──────────────────────────────────────────────────────────────────────
    // MARK: - Piece
    //
    // Where it sits on its tile, how it hops, how it falls.

    /// Extra lift applied to a piece on top of resting its 16x32 box on the
    /// tile. Positive is up.
    static let pieceLift: CGFloat = 1

    /// How far the shadow sits below a piece's own centre.
    ///
    /// At `0` it lands dead centre of the tile, where the sprite covers it
    /// completely — which is how it went missing. The piece's opaque pixels end
    /// about two art pixels below the tile's centre, so the shadow has to clear
    /// that to be seen at all.
    static let pieceShadowDrop: CGFloat = 2

    /// How much smaller the piece's shadow gets at the top of a hop, as a
    /// fraction of its resting size.
    ///
    /// The same trick the Pentacle's glow uses: a shadow narrowing as its caster
    /// rises says "height" far more clearly than the rise itself does, because
    /// the shadow stays on the ground where the eye can measure it against
    /// something fixed.
    static let pieceShadowLiftSwing: CGFloat = 0.4

    /// Roughly how much of a stone piece's lower half is overgrown.
    static let pieceMossCoverage: Float = 0.32

    /// How far a charged piece's gem blooms, in art pixels.
    static let gemGlowRadius: CGFloat = 2

    /// Copies drawn behind a charged gem. Zero is a plain halo.
    static let gemGlowTrail = 2

    /// How many lagging after-images a charged piece's gems leave — see
    /// `GemTrailView`. Zero switches the streak off entirely.
    static let gemTrailCount = 7

    /// How soft each after-image is, in art pixels. Widens further back.
    static let gemTrailRadius: CGFloat = 2.4

    /// What fraction of the previous copy's brightness each one keeps.
    static let gemTrailFalloff: Double = 0.88

    /// Seconds of spring response per step of lag.
    ///
    /// This is the knob that decides whether the gems streak or merely smear:
    /// raise it and the tail stretches further behind the piece.
    static let gemTrailLag: TimeInterval = 0.22

    /// How many times each after-image is drawn on top of itself.
    ///
    /// A gem is three or four pixels; blurred once it is barely there. Additive
    /// blending means restacking the same copy is simply brighter, which is the
    /// cheapest way to make a small light carry across a whole square.
    static let gemTrailBoost = 3

    /// A single hop between tiles.
    static let hopDuration: TimeInterval = 0.20

    /// Peak height of a hop's arc, above the straight line between squares.
    static let hopArcHeight: CGFloat = 6

    /// Extra arc height per tile travelled beyond the first, as a fraction of
    /// `hopArcHeight`.
    ///
    /// A two-tile vault clearing the same height as a one-tile step reads as
    /// the piece being *dragged* across rather than jumping — the eye reads
    /// distance covered against height reached, and a flat long jump looks
    /// weightless. At `0.6`, a Scorpio vault arcs 1.6x and a Sagittarius shot
    /// 2.2x.
    ///
    /// Applies to jumps *and* to long slides, though a slide is emitted one
    /// square at a time so in practice only jumps ever see a distance above one.
    static let hopArcHeightPerExtraTile: CGFloat = 0.6

    /// Extra hop time per tile travelled beyond the first, as a fraction of
    /// `hopDuration`.
    ///
    /// Zero by default, so every move takes the same time however far it goes —
    /// which is the stated intent. Worth knowing it is here: a jump three times
    /// as long and twice as high in the same time is moving very fast
    /// vertically, and if a Sagittarius shot ever reads as snapping rather than
    /// arcing, this is the knob. Try `0.25`.
    static let hopDurationPerExtraTile: Double = 0

    /// Widest and flattest the piece gets, winding up and on impact.
    static let hopSquashX: CGFloat = 1.28

    static let hopSquashY: CGFloat = 0.76

    /// Tallest and thinnest the piece gets, at the top of the arc.
    static let hopStretchX: CGFloat = 0.80

    static let hopStretchY: CGFloat = 1.24

    /// A drop from Astra down to Terra.
    static let fallDuration: TimeInterval = 0.72

    /// How far the piece spins as it drops between planes.
    ///
    /// Negative is counter-clockwise. Applied as a running total rather than a
    /// target angle, so the spin always turns the same way instead of unwinding
    /// on the way back.
    static let fallSpinDegrees: Double = -1080

    /// Seconds the piece takes to fall in from off-screen onto the lower plane.
    static let fallArrivalDuration: TimeInterval = 0.42

    /// How far above the board the piece starts its arrival, as a multiple of
    /// the board's own height. Above 1 it begins genuinely off-screen.
    static let fallArrivalHeight: CGFloat = 1.15

    /// How small the destination tile's shadow starts, before the piece nears
    /// it. Growing this shadow is what telegraphs the incoming landing.
    static let fallArrivalShadowMin: CGFloat = 0.15

    /// A teleport: the piece vanishing and reappearing elsewhere.
    static let teleportDuration: TimeInterval = 0.28

    /// The piece transforming into another sign.
    static let pieceChangeDuration: TimeInterval = 0.40

    // ──────────────────────────────────────────────────────────────────────
    // MARK: - Nexys
    //
    // The island: where it rests, how it drifts, how it carries and travels.

    /// How far the Nexys island's *art* sits above where an ordinary tile would.
    ///
    /// Derived, not eyeballed. The 48x48 sprite's opaque content runs rows 8–39,
    /// so it is 32 art pixels tall inside a box that is centred on it. Drawing
    /// that box on the tile puts the content's top edge 8px above the tile top.
    /// The island's travel is specified by its extremes:
    ///
    /// - at its lowest, the bottom-most pixel reaches the centre tile's bottom
    ///   edge — content top edge at `tileTop - 16`;
    /// - at its highest, the top-most pixel reaches 4px into the bottom of the
    ///   tile two cells north — content top edge at `tileTop - 20`.
    ///
    /// So the midpoint is `tileTop - 18`, which is 10px above where centring
    /// alone would put it, and the whole drift is 4px — hence an amplitude of 2.
    /// Change either number and the other has to move with it.
    static let nexysRaise: CGFloat = 10

    /// How far a piece standing on the island is lifted.
    ///
    /// Kept apart from `nexysRaise` because the two answer different questions —
    /// where the island *looks* right, and where a piece has to sit to look like
    /// it is standing on it. Tying them together means fixing one breaks the
    /// other.
    ///
    /// The island floats *above* where a tile sits, so a piece standing on it
    /// stands higher than ground level by roughly that same amount. Centring the
    /// piece on the island's artwork was the wrong target — it put the piece at
    /// ground height while the island hovered around it.
    static let nexysRideLift: CGFloat = 11

    /// How far the island drifts either side of its resting height.
    ///
    /// Half the 4px total travel described on `nexysRaise`.
    static let nexysFloatAmplitude: CGFloat = 2

    /// Seconds for one full up-and-down of the island.
    static let nexysFloatPeriod: TimeInterval = 3.4

    /// Island opacity while the piece stands on one of the three squares
    /// directly north of it, so it never hides the piece.
    static let nexysFadedOpacity: Double = 0.33

    /// The Nexys island travelling between planes.
    static let nexysShiftDuration: TimeInterval = 0.40

    /// Seconds the island takes to leave a plane.
    static let nexysTravelDepartDuration: TimeInterval = 0.34

    /// Seconds it takes to swell back in on the other plane.
    static let nexysTravelArriveDuration: TimeInterval = 0.34

    /// How far the island drifts as it leaves, as a fraction of the board's
    /// height. Small — it shrinks away rather than flying off.
    static let nexysTravelDrift: CGFloat = 0.18

    /// Seconds the island takes to carry the piece up out of Terra.
    static let ascentRiseDuration: TimeInterval = 0.55

    /// Seconds the island and piece take to swell back in on Astra.
    static let ascentGrowDuration: TimeInterval = 0.40

    /// How far above the board the pair travel before the plane swaps, as a
    /// multiple of the board's height. Above 1 they leave the screen entirely.
    static let ascentRiseHeight: CGFloat = 1.2

    /// Peak whiteout at the moment the planes swap. Zero disables the flash.
    static let ascentFlashOpacity: Double = 0.55

    // ──────────────────────────────────────────────────────────────────────
    // MARK: - Pentacle
    //
    // The coin, and the pool of light under it.

    /// The Pentacle coin's glint.
    static let pentacleRate = SpriteRate.fps12

    /// A Pentacle is drawn 48x48 — coin in the middle cell, sparkle ring
    /// spilling a full cell in every direction — then halved.
    ///
    /// Three cells at half scale is 1.5, so the coin itself lands at half a tile.
    /// Halving happens by shrinking the frame, not by resampling: `PixelSprite`
    /// draws with nearest-neighbour and no antialiasing, so the art stays hard-
    /// edged rather than turning to mush.
    static let pentacleCellSpan: CGFloat = 1.5

    /// How far the coin itself floats above its shadow, in art pixels.
    static let pentacleLift: CGFloat = 8

    /// How far a Pentacle drifts either side of its resting height.
    static let pentacleFloatAmplitude: CGFloat = 1.5

    /// Seconds for one full up-and-down of a Pentacle.
    static let pentacleFloatPeriod: TimeInterval = 1.6

    /// How far the coin's shadow sits below the tile centre, in art pixels.
    /// Negative is up.
    static let pentacleShadowDrop: CGFloat = 0

    /// Opacity of the pool of light under the coin, at its brightest.
    static let pentacleShadowOpacity: Double = 0.3

    /// How much smaller the pool gets at the top of the coin's float, as a
    /// fraction of its resting size. Shrinking as the coin rises is what sells
    /// the height rather than a flat drift.
    static let pentacleShadowScaleSwing: CGFloat = 0.3

    /// How far the coin's glow orbits the tile centre, in art pixels.
    ///
    /// The coin circles as it hovers; its light circles with it. Zero pins the
    /// pool to the centre.
    static let pentacleOrbitRadius: CGFloat = 2.5

    /// Seconds for one full orbit.
    static let pentacleOrbitPeriod: TimeInterval = 3.1

    /// How far the coin's bright entries bloom, in art pixels.
    static let pentacleGlowRadius: CGFloat = 1.2

    /// Seconds Polaris takes to turn once. Negative is counter-clockwise.
    static let polarisSpinPeriod: TimeInterval = -6.5

    /// How strongly the coin's highlights bloom. Below 1 the glow is thinner
    /// than the mask it is drawn from.
    static let pentacleGlowIntensity: Double = 0.26

    /// Polaris' own bloom. Separate from the gold coin's: the star is already
    /// the brightest thing on the board before anything is added to it.
    static let polarisGlowIntensity: Double = 0.3

    /// Sparks orbiting Polaris.
    ///
    /// Split evenly between those passing behind the star and those in front —
    /// a ring drawn entirely on one side reads as a flat halo stuck to it.
    static let polarisSparkCount = 10

    /// How far a spark swings between its smallest and largest, as a fraction
    /// of its base size.
    ///
    /// Large on purpose: a twinkle that only changes brightness reads as a
    /// flicker, and it is the *size* changing that makes it a star.
    static let polarisTwinkleSwing: CGFloat = 0.85

    /// Seconds for the slowest and fastest twinkle. Each spark picks its own
    /// from the range, so they never pulse together.
    static let polarisTwinkleSlowest: TimeInterval = 1.5
    static let polarisTwinkleFastest: TimeInterval = 0.45

    /// How far they sit from the star, in art pixels.
    static let polarisSparkRadius: CGFloat = 9

    /// Seconds they take to circle it.
    static let polarisSparkPeriod: TimeInterval = 4.2

    /// The pickup appearing and the sparkles vanishing.
    ///
    /// Zero because both happen *as the piece starts moving* — they are one
    /// beat with the hop, not a step before it.
    static let pickupRevealDuration: TimeInterval = 0

    /// Beat held after collecting a pickup, before new sparkles appear.
    static let pickupCollectDuration: TimeInterval = 0.20

    // ──────────────────────────────────────────────────────────────────────
    // MARK: - Capricorn's purse
    //
    // Celestial Commerce banks a Pentacle instead of opening it, and Cosmic
    // Cash-in spends it. See `CapricornCelestialCommerce` and `ShopBarView`.

    /// How long the coin takes to travel from its tile down to the shop strip.
    ///
    /// Long enough to be followed by eye — the arc is the only thing that says
    /// *where the coin went*, and a bank that happened instantly would read as a
    /// Pentacle that fizzled.
    static let pickupBankDuration: TimeInterval = 0.42

    /// How many motes of earth-light ride the arc.
    static let bankSparkCount = 7

    /// How high the arc bows above the straight line between tile and strip,
    /// as a fraction of the distance travelled.
    static let bankArcHeight: CGFloat = 0.28

    /// Radius of one mote, in tiles.
    static let bankSparkSize: CGFloat = 0.09

    // ──────────────────────────────────────────────────────────────────────
    // MARK: - Healing
    //
    // Every mend throws the same motes, whatever mended it. See
    // `HealSparkleView`.

    /// How long a tile shimmers after being repaired.
    static let healSparkleDuration: TimeInterval = 0.55

    /// Motes thrown per tile healed.
    static let healSparkleCount = 9

    /// Radius of one mote, in tiles.
    static let healSparkleSize: CGFloat = 0.055

    /// Most tiles that may shimmer at once.
    ///
    /// Libra's Balancing Breeze can mend an entire board in one event, and one
    /// `Canvas` per square all ticking every frame is a real cost for a moment
    /// that is over in half a second. Past this the mend still happens, it is
    /// simply not individually sparkled — nobody counts motes on forty-nine
    /// squares, and the whole-board change is legible on its own.
    static let healSparkleMaxTiles = 14

    // ──────────────────────────────────────────────────────────────────────
    // MARK: - Pisces' water
    //
    // The pool Surging Stream leaves, and the droplets Gaia Geyser throws up.

    /// How long water takes to gather or dry up.
    static let poolFormDuration: TimeInterval = 0.30

    /// Charge for one surf. See `PiscesStarstreamSurfer`.
    ///
    /// Three, against the one pip a step used to pay. A surf costs position and
    /// wears two tiles, and it has to be worth more than the three ordinary
    /// steps it replaces or nobody would ever take it.
    static let starstreamCharge = 3

    /// Charge for stepping into a pool. Paid every time, not once.
    ///
    /// One, and deliberately small. The pool is a place worth walking back to on
    /// a plane that drains a pip for every square you leave — it is break-even
    /// plus nothing, which makes it a foothold rather than an engine.
    static let poolCharge = 1

    /// Charge from one of Gaia Geyser's droplets.
    ///
    /// A full meter. The move that takes it drains one on the way out, so the
    /// fish stands up from the geyser on nine — exactly where the old
    /// fill-on-arrival left it after its first step, which is the number this
    /// was tuned against.
    static let gaiaDropletCharge = defaultZodiactionMeterMax

    // ──────────────────────────────────────────────────────────────────────
    // MARK: - Scorpio's sting

    /// How far the tail reaches on Terra. Astra strikes the whole line.
    static let stingReachTerra = 3

    /// The beat held on the square where Scorpio shed, before it is carried to
    /// the island.
    ///
    /// A rescue that happened instantly read as the fall having been cancelled.
    /// The pause is what makes it a *death* that was survived: the piece stops,
    /// the husk appears, and only then does the warp take it.
    static let shedPauseDuration: TimeInterval = 0.75

    /// How translucent the abandoned skin is, once it settles.
    static let shedSkinOpacity: Double = 0.28

    /// How long the strike is on screen, out and back.
    static let stingDuration: TimeInterval = 0.34

    /// How solid the lance is. Low: it is a phantasm, and the board it crosses
    /// has to stay readable underneath it.
    static let stingOpacity: Double = 0.55

    /// Capricorn's purse, in Pentacles, on each plane.
    ///
    /// Lower on Terra: the earth sign is at home down there, so the price of
    /// being at home is a smaller ceiling. Costing the cap rather than the fill
    /// rate keeps every individual coin worth the same.
    static let capricornPurseAstra = 10
    static let capricornPurseTerra = 8

    // ──────────────────────────────────────────────────────────────────────
    // MARK: - Sparkles
    //
    // The shimmer on candidate tiles. Drawn rather than sprited — see
    // `SparkleView`.

    /// Opacity of the sparkles marking candidate Pentacle tiles, at their
    /// brightest.
    static let sparkleOpacity: Double = 1.0

    /// Shortest and longest time a sparkle takes to complete one pulse.
    ///
    /// Each sparkle picks its own period from this range. A single shared period
    /// makes five sparkles read as one blinking object however you stagger their
    /// phases — it is the *rate* differing that makes them look independent.
    static let sparklePulseFastest: TimeInterval = 0.7

    static let sparklePulseSlowest: TimeInterval = 1.6

    /// Nudge applied to sparkles so they sit dead centre in their square.
    ///
    /// **In points, not art pixels** — the sparkle is drawn rather than
    /// sprited, so it has no pixel grid to align to.
    /// The bloom around a glow-phase sparkle.
    ///
    /// Stacked additive copies rather than a `.shadow`: a shadow tints what is
    /// behind it, which on a dark board barely registers, while two on-palette
    /// colours summed are genuinely brighter than either and still on-palette.
    ///
    /// `sparkleGlowRadius` is a fraction of a tile. Each layer is wider and
    /// fainter than the last, so the falloff reads as light rather than as a
    /// hard-edged halo.
    /// Size of the white core relative to the glyph the bloom is drawn from.
    ///
    /// Under 1, so the colour is never entirely covered by the hot centre.
    static let sparkleCoreScale: CGFloat = 0.72

    static let sparkleGlowRadius: CGFloat = 0.085
    static let sparkleGlowLayers = 3
    static let sparkleGlowIntensity: Double = 0.9

    /// How much of the bloom Terra keeps.
    ///
    /// Additive light needs dark ground. Astra's clouds are deep magenta and a
    /// blue bloom stays legible on them, but Terra's tiles are bright warm
    /// earth — gold added on top of that saturates, and the star's points are
    /// the first thing to go. Same effect, less of it, so the shape survives.
    static let sparkleGlowTerraDamping: Double = 0.45

    static let sparkleNudge = CGSize(width: 2, height: 0)

    /// The wash of light a sparkle throws onto the square it is marking.
    ///
    /// A sparkle floating above a tile says *something is here*; the tile
    /// itself catching that light says *this tile*. On Astra it also reads as
    /// the cloud glowing from within, which is what the plane wants to be doing.
    ///
    /// Faint by design — it is a hint under the sparkle, not a second sparkle.
    /// Size and blur are fractions of a tile.
    static let sparkleTileGlowSize: CGFloat = 0.78
    static let sparkleTileGlowBlur: CGFloat = 0.15
    static let sparkleTileGlowOpacity: Double = 0.22

    // ──────────────────────────────────────────────────────────────────────
    // MARK: - Smoke
    //
    // Dust from a landing. Sprite for footfalls, procedural scatter for heavy
    // ones.

    /// Landing dust. Matches the GameMaker build.
    static let smokeRate = SpriteRate.fps12

    /// Frames in a landing puff's sheet.
    static let smokeFrameCount = 5

    /// Seconds a puff takes to play through.
    ///
    /// Derived from the rate rather than set independently, so the sprite and
    /// the scatter that stands in for it always last exactly as long.
    static var smokeDuration: TimeInterval {
        smokeRate.duration(frames: smokeFrameCount)
    }

    /// How far below the tile's centre the puff sits, in art pixels.
    ///
    /// Dust rises from where a foot met the ground, not from the middle of the
    /// piece — but the sprite is two cells tall and centred, so most of it is
    /// above the contact point already. This only needs to nudge it clear.
    static let smokeDrop: CGFloat = 0.5

    /// Scale the smoke sprite is drawn at, relative to its natural two cells.
    static let smokeSpriteScale: CGFloat = 0.75

    /// Above this magnitude the drawn scatter is used instead of the sprite.
    ///
    /// The sprite is one fixed puff — right for a footfall, too small and too
    /// tidy for a body hitting the ground after falling a whole plane. Heavy
    /// landings keep the procedural scatter, which can be thrown as wide as it
    /// needs to be.
    static let smokeSpriteMaxMagnitude: CGFloat = 1.2

    /// How far into its own animation a puff begins, `0`…`1`.
    ///
    /// A puff spends its first frames small and thin, so even when it is fired
    /// on exactly the same event as the thing it belongs to — a tile slamming
    /// flat, a coin bursting — it reads as arriving late. Starting partway in
    /// skips the ramp and lands the dust *with* the impact.
    ///
    /// Raise it to make dust hit harder and sooner; `0` restores the full
    /// ramp-in.
    static let smokeLeadIn: Double = 0.15

    /// How solid a puff is at its densest.
    static let smokeOpacity: Double = 0.95

    /// Size multiplier for the puff thrown up by taking a Pentacle.
    static let smokeCollectMagnitude: CGFloat = 1.5

    /// Size multiplier for the cloud thrown up by landing after a fall, as
    /// against an ordinary hop.
    static let smokeFallMagnitude: CGFloat = 2.1

    /// Puffs kicked up by a landing.
    static let smokePuffCount = 7

    /// Diameter of a puff at its largest, in art pixels.
    static let smokePuffSize: CGFloat = 4

    /// How far a puff drifts from the landing point, in art pixels.
    static let smokeSpread: CGFloat = 9

    /// Astra's landings throw curls of cloudstuff rather than dust — see
    /// `SmokeBurstView`. Turns are low for the same reason the cloud's are: much
    /// past one and a half stops reading as a gesture.
    static let smokeSwirlTurns: Double = 1.25
    static let smokeSwirlThickness: CGFloat = 1.1

    /// How much bigger a swirl is than a dust puff, and how far it winds over
    /// its life, in degrees. Signed per swirl, so a burst unwinds both ways.
    static let smokeSwirlScale: CGFloat = 2.2
    static let smokeSwirlSpin: Double = 200

    // ──────────────────────────────────────────────────────────────────────
    // MARK: - Cursor
    //
    // The four brackets marking where a move lands.

    /// How far the cursor sits above the centre of the square it marks.
    static let cursorLift: CGFloat = 2

    /// How far the cursor's brackets sit from their tight resting position at
    /// the peak of a flare.
    static let cursorFlareOutset: CGFloat = 2

    /// Where the brackets rest. Negative tucks them inside the tile.
    static let cursorFlareInset: CGFloat = 0

    /// Seconds for one flare-and-settle of the cursor.
    static let cursorFlarePeriod: TimeInterval = 0.75//1.1

    /// Fraction of the period spent flaring outward; the rest is the settle.
    static let cursorFlareAttack: Double = 0.1//0.18

    /// Opacity of the cursor when the move is off the board entirely.
    static let cursorImpossibleOpacity: Double = 0.5//0.35

    // ──────────────────────────────────────────────────────────────────────
    // MARK: - Warp beams
    //
    // The pillar of light at each end of a teleport.

    /// Seconds a pillar of light lasts at each end of a warp.
    static let warpBeamDuration: TimeInterval = 0.30

    /// How far past the tile the pillar reaches, as a multiple of a cell.
    static let warpBeamHeight: CGFloat = 3.2

    /// Motes riding each pillar of light.
    static let warpSparkCount = 9

    // ──────────────────────────────────────────────────────────────────────
    // MARK: - Collect burst
    //
    // Sparks off an opened — or destroyed — Pentacle.

    /// Seconds the burst of sparkles from an opened Pentacle lasts.
    static let collectBurstDuration: TimeInterval = 0.55

    /// How many sparkles fly out of an opened Pentacle.
    static let collectBurstCount = 10

    /// How far they travel, in art pixels.
    static let collectBurstSpread: CGFloat = 16

    // ──────────────────────────────────────────────────────────────────────
    // ──────────────────────────────────────────────────────────────────────
    // MARK: - Constellations
    //
    // The sign drawn in the air when a Zodiaction fires. See
    // `ConstellationView`. Replaced the low-poly spectral heads: twelve animal
    // heads is a modelling problem, twelve star patterns is a list.

    /// How long the replay pauses on the pop itself.
    ///
    /// Short, because it no longer needs to cover anything: the constellation,
    /// the effect strips and Leo's sun all run on their own timestamps and keep
    /// playing while the Zodiaction's consequences resolve underneath them. A
    /// long hold here only delayed those consequences — Leo's Nexys visibly sat
    /// still for a third of a second before starting down.
    static let zodiactionDuration: TimeInterval = 0.08

    /// How long the whole summon lasts, from first star to gone.
    static let constellationDuration: TimeInterval = 3.2

    /// Seconds per line while the figure traces itself.
    ///
    /// The figures run from three lines to eight, so this paces the *drawing*
    /// rather than fixing a total — a busier sign takes longer to write, which
    /// is correct.
    static let constellationTracePerLine: TimeInterval = 0.17

    /// The fraction of its life after which it starts going out.
    static let constellationFadeStart: Double = 0.62

    /// Size of the box it is drawn in, in tiles, and points per unit within it.
    ///
    /// The box has to stay ahead of the scale or the figure clips its own
    /// corners as it turns.
    static let constellationSpan: CGFloat = 9
    static let constellationScale: CGFloat = 2.3

    /// How far above the piece it hangs, in art pixels.
    static let constellationRise: CGFloat = 24

    /// Radians per second about the vertical axis, and the fixed tilt.
    ///
    /// Slow: the turn is there to give the figure depth through parallax, not to
    /// spin it. Anything faster and the pattern stops being legible as a shape.
    static let constellationSpin: Float = 0.34
    static let constellationPitch: Float = -0.20

    /// Star size in art pixels, before magnitude and perspective.
    static let constellationStarSize: CGFloat = 1.05

    /// How much bigger a star is at the instant it lights, as a fraction.
    static let constellationPop: CGFloat = 1.4

    /// The threads between stars.
    static let constellationLineWidth: CGFloat = 0.5
    static let constellationLineOpacity: Double = 0.95

    /// How brightly a star's soft body burns under its hard core.
    static let constellationHaloOpacity: Double = 0.55

    // ──────────────────────────────────────────────────────────────────────
    // MARK: - Elemental bursts
    //
    // The Metal-shaded flourish an Astral Essence plays.

    /// How long an elemental burst plays for. Purely cosmetic; the rule it
    /// illustrates has already resolved.
    /// How wide a drawn effect strip is drawn, in tiles.
    ///
    /// The art is four tiles across at native size, which would swallow the
    /// board. At one and a half it reads as something happening *to* a square
    /// rather than as a picture laid over the plane. Overridable per effect —
    /// see `EffectSprite.span`.
    static let effectSpan: CGFloat = 1.5

    /// How long the piece stays recoloured after gaining charge, and how far
    /// the recolour goes at its peak.
    ///
    /// Short: this fires on most moves, and anything that fires that often has
    /// to be felt rather than watched.
    static let chargeFlashDuration: TimeInterval = 0.3
    static let chargeFlashStrength: Double = 0.85

    /// How long each square of a seafoam scuttle waits before its bubbles come up.
    ///
    /// Paced against the hop rather than the art: the three should be underway
    /// by the time the piece has finished crossing them.
    static let crabWalkStagger: TimeInterval = 0.08

    /// How long the piece takes to cross one square while being carried by
    /// water — the Astral Brook, and Pisces' Downstream.
    ///
    /// Much shorter than a hop: the squares run together into one movement
    /// rather than reading as separate steps, which is the whole difference
    /// between sliding and hopping.
    static let slideStepDuration: TimeInterval = 0.055

    /// How far each square's movement runs past the beat it is given.
    ///
    /// Above 1 the squares *overlap*: the piece is still travelling toward one
    /// when the next begins, so a seven-square sweep is one continuous movement
    /// rather than seven short ones with a stop between each. Linear animation
    /// makes the overlap seamless — two linear runs at the same speed meeting
    /// mid-square are indistinguishable from one.
    /// How long a square stays pressed after the piece has passed over it.
    ///
    /// Longer than one step, on purpose: the presses overlap into a wave
    /// travelling behind the piece rather than a single square bobbing under it.
    static let slidePressLinger: TimeInterval = 0.18

    /// How far a pressed square gives, in art pixels.
    static let slidePressDepth: CGFloat = 1.5

    static let slideOverlap: Double = 2.2

    /// A slide wears the tile it leaves and the tile it reaches, and nothing in
    /// between.
    ///
    /// The squares between the ends are crossed rather than stood on — one turn,
    /// however far it goes. Recorded here because several signs' moves became
    /// slides on the strength of it, and because "how much ground a move costs"
    /// is the question the whole game is balanced around.
    static let slideWearsEndsOnly = true

    /// How far the board darkens while a move plays out.
    ///
    /// A long slide or a leap is one turn, and without this it reads as several
    /// — the eye counts squares. Dimming the ground for the duration says the
    /// board is mid-thought, and leaving the piece, the coins and the move's own
    /// effects undimmed says which part of it is the thought.
    static let actionDim: Double = 0.10

    /// How many squares a hop must cover to count as a leap worth drawing —
    /// Sagittarius' full bound rather than any long step.
    static let longJumpDistance = 3

    /// The bloom thrown by a drawn effect: blur radius in art pixels, and how
    /// bright the additive copy is.
    ///
    /// The strips are lit art already; this is the light they cast on the board
    /// around them, which is what stops them reading as decals.
    static let effectGlowRadius: CGFloat = 2.5
    static let effectGlowIntensity: Double = 0.55

    /// Fire needs considerably more than water does — see
    /// `EffectSprite.glowIntensity`.
    static let effectGlowFireIntensity: Double = 1.35

    /// How far an on-the-ground effect rides up so its base sits on the tile
    /// rather than its middle. In art pixels.
    static let effectGroundLift: CGFloat = 8

    static let elementalBurstDuration: TimeInterval = 0.75

    // ──────────────────────────────────────────────────────────────────────
    // MARK: - Screen shake
    //
    // The jolt of a heavy landing.

    /// Seconds a shake takes to die away.
    static let shakeDuration: TimeInterval = 0.38

    /// Peak displacement of a shake, in art pixels.
    static let shakeAmplitude: CGFloat = 3

    /// Oscillations per second.
    static let shakeFrequency: Double = 17

    // ──────────────────────────────────────────────────────────────────────
    // MARK: - Backdrops
    //
    // What sits behind the board on each plane.

    /// Stars twinkling behind Astra.
    static let astraStarCount = 60

    /// Clouds drifting behind Terra.
    static let terraCloudCount = 7

    // ──────────────────────────────────────────────────────────────────────
    // MARK: - Game over

    /// Pause before the game-over overlay appears.
    static let gameOverDelay: TimeInterval = 0.35

}
