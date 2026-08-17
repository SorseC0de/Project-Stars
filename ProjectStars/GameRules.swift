//
//  GameRules.swift
//  Project Stars
//
//  Every tunable number and rule toggle in one place.
//

import SwiftUI
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
    /// How much of the arrow sprite is left above ground once it lands.
    ///
    /// The art is a whole arrow, because the same drawing is the thing that
    /// flies. What stands afterwards is masked rather than drawn separately, so
    /// there is one arrow in this game and not two that have to agree.
    /// How far the arrow art has to be turned to point the way it flies.
    ///
    /// The sprite is drawn horizontal, pointing right. Every use of it here is
    /// an arrow that has been fired *downward* — falling out of the sky, or
    /// already buried — so it turns clockwise to put the head at the bottom.
    /// Anticlockwise stood it on its tail.
    static let arrowArtRotation: Double = 90

    static let arrowBuriedFraction: CGFloat = 0.72

    /// How long the board shudders when the arrow lands.
    ///
    /// Longer than Taurus' step, which happens constantly, and shorter than a
    /// fall — this is one heavy thing arriving once.
    static let arrowLandShake: TimeInterval = 0.22

    /// How long the arrow takes to clear the top of the board on its way up.
    ///
    /// Slower than it looks like it should be. The shot is the whole of this
    /// Zodiaction's first half and it was over before the eye found it — a
    /// vertical streak needs longer than a horizontal one to register, because
    /// there is nothing beside it to measure against.
    static let arrowRiseDuration: TimeInterval = 0.45

    static let arrowLean: Double = 12

    /// Its glow, and how long one breath of it takes.
    /// The planted arrow's bloom: how far it spreads, and how hard it burns.
    ///
    /// Brightness rather than reach. The arrow is the only thing on the board
    /// *waiting* for the player — Sagittarius' whole second half is going back
    /// to it — so it has to carry across a plane it does not belong to, and a
    /// wider blur only makes a dim thing larger.
    static let arrowGlowRadius: CGFloat = 1.6
    static let arrowGlowIntensity: Double = 1.6

    /// How bright a pixel of the arrow has to be to glow.
    ///
    /// Well under `glowLuminanceThreshold`, because the arrow's own highlights
    /// are darker than most sprites' shadows.
    static let arrowGlowThreshold: Double = 0.22
    static let arrowGlowPasses = 3
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
    static let magneticManeChanceAstra = 0.10
    static let magneticManeChanceTerra = 0.25

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
    /// Charge for taking a Pentacle on the move it was revealed.
    ///
    /// One, for everybody but Virgo. See `GameEngine.resolvePickupCollection`.
    static let revealTileCharge = 1

    static let elementAffinityCharge = 3

    /// How often the Galeforce Gavel turns up for Libra.
    ///
    /// Its own number rather than the Nexys Shift's, which it replaces. The
    /// Shift is weighted **1** — the rarest thing in the uncommon tier, because
    /// for everyone else it is a rescue rather than a tool — and inheriting that
    /// meant Libra went whole sessions without seeing her own signature coin.
    ///
    /// Three times an Essence, and unapologetically.
    ///
    /// An Essence's rate was the right instinct and the wrong number: the
    /// uncommon tier holds a dozen entries, so matching one of them still meant
    /// going most of a session without the coin the sign is built around. It
    /// also does not need rationing — the slab is rolled, and one in four
    /// arrives as a set of holes, so a player who takes it often has decided
    /// that gamble is worth making. It rations itself.
    static let galeforceGavelWeight = 9

    // MARK: - Rules — Leo's sun
    //
    // See `SignState.Sun` and `LeoSolarPull`.

    /// How many committed moves the sun burns for.
    static let sunMoves = 5

    /// How far above the piece's head the Aten floats, in art pixels.
    static let sunHeadroom: CGFloat = 6

    /// The Aten's own light.
    static let sunGlowPasses = 3
    static let sunGlowRadius: CGFloat = 5
    static let sunGlowIntensity: Double = 0.55
    static let sunGlowPeriod: TimeInterval = 2
    static let sunGlowMin: Double = 0.6

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

    /// Charge Astral Blaze pays per tile it merely wears.
    ///
    /// **Nothing.** Cracking eight squares around you is what the coin does
    /// anyway; being paid for it as well turned a 3x3 of healthy ground into
    /// eight charge for free, and on a board with anything already worn it paid
    /// out twice over. A full meter inside two turns.
    static let astralBlazeChargePerDamage = 0

    /// Charge Astral Blaze pays per tile it breaks outright.
    ///
    /// One, and only for a break. The payout should track what the fire
    /// genuinely cost the board — a hole is ground gone for good, where a crack
    /// is ground you can still stand on. It also means the coin is worth *less*
    /// on a fresh board and more on a ruined one, which is the right way round:
    /// it rewards taking it when the run is already going badly.
    static let astralBlazeChargePerBreak = 1

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
    /// How long a drag must be held before it asks for anything beyond a step.
    ///
    /// Reach is a matter of *time* rather than distance. The panel is not tall
    /// enough to express three options as three lengths of drag, and asking the
    /// same finger to carry both the aim and the magnitude made both worse.
    ///
    /// This first stretch is dead: a quick flick is a step, and without a delay
    /// every flick would collect a longer move on its way past.
    static let swipeReachDelay: TimeInterval = 0.25

    /// And how much longer for each option after that.
    static let swipeReachHold: TimeInterval = 0.3

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
    /// covers it — right everywhere except the last row, which has no row below
    /// and so ended flat, like a decal. This one drops a **whole cell**, which
    /// puts the sliver immediately under the board and gives the plane a front
    /// face.
    ///
    /// A full cell because the edge sprite's four pixels of art sit at the
    /// **top** of their frame and every bit of the push is applied from outside
    /// — `tileEdgeDrop` of 12 is what lands them at the bottom of their own
    /// square. Anything less than 16 leaves them inside the cell, behind the
    /// face, which is exactly where a first guess of 4 put them: drawn every
    /// frame and never once visible.
    static let tileFrontEdgeDrop = CGFloat(tilePixelSize)

    /// A tile visibly cracking.
    static let tileDamageDuration: TimeInterval = 0.16

    /// How long a turn waits on a wear flash before moving on.
    ///
    /// Far shorter than the flash itself, which finishes in its own time — see
    /// `GameSession.clearFlashLater(_:)`. This is only the beat that says
    /// *something broke*, and at the pace people actually play, a beat is all
    /// there is room for.
    static let tileDamageHold: TimeInterval = 0.04

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
    ///
    /// Very slow on purpose, and slower than a sprite rate usually goes.
    ///
    /// The three frames are three genuinely different cloud shapes rather than
    /// small inbetweens, so the eye reads a change of frame as an *event*. At
    /// anything approaching an animation rate forty-nine of those events going
    /// off across the board is a strobe. Three a second — a frame held a third
    /// of a second, the whole ping-pong taking well over a second — is slow
    /// enough that a cloud looks like it is turning over rather than blinking.
    static let cloudSpriteFrames = 3
    static let cloudSpriteRate = SpriteRate(3)

    /// How big a cloud is drawn against the size it was authored at.
    ///
    /// The art is three cells across, which at full size buries the grid the
    /// player is counting squares on. Two-thirds keeps the overlap that makes
    /// the field read as weather and lets the squares be counted again.
    static let cloudSpriteScale: CGFloat = 0.66

    /// How far a cloud drifts from its square, as a fraction of **its own
    /// size** rather than of a cell.
    ///
    /// Measured against the cloud on purpose. Against the cell, shrinking the
    /// art left the sway at its old absolute distance — so the smaller the
    /// clouds got the further they wandered in proportion, and the grid stopped
    /// being legible underneath them.
    ///
    /// Per-cloud and on its own phase, so the field never pulses in unison.
    ///
    /// In **art pixels**, not as a fraction of anything, because that is the
    /// unit this is judged in: the answer to "how far does it wander" is a
    /// number of pixels you can see, and expressing it as a proportion of a
    /// cloud that is itself scaled made every adjustment a division sum.
    static let cloudSpriteShift: CGFloat = 1.5
    static let cloudSpriteShiftPeriod: TimeInterval = 13

    /// How much a cloud stretches, as a fraction either side of its true size.
    ///
    /// Horizontal and vertical run on different periods on purpose: matched,
    /// they read as a single throb, and the point is that a cloud has no fixed
    /// shape.
    static let cloudSpriteStretch: CGFloat = 0.13
    static let cloudSpriteStretchPeriodH: TimeInterval = 6.1
    static let cloudSpriteStretchPeriodV: TimeInterval = 7.9

    /// How a cloud is drained of colour as it wears.
    ///
    /// The shrink alone was not reading as damage — the first outside tester did
    /// not realise Astra decayed at all, and could not work out why he kept
    /// falling. This is the second signal.
    ///
    /// ## Why not opacity
    ///
    /// Because a faded cloud is a cloud you can see the sky through, and Astra's
    /// sky is nearly black — so fading reads as *dimming the lights*, and the
    /// square goes quiet exactly when it should be shouting. Draining the colour
    /// out of it says something different and much closer to the truth: the
    /// square is losing what it is made of. A grey cloud in a magenta field is
    /// conspicuous rather than faint.
    ///
    /// ## Why hue and not only saturation
    ///
    /// Draining the colour made both damaged states grey, and greys are hard to
    /// rank: cracked and badly cracked looked like each other, and a cracked
    /// cloud looked like one of the dark healthy ones on the chequerboard. Three
    /// states were being told apart by *how much* of one thing, which is the
    /// hardest comparison to make at a glance and the easiest to get wrong when
    /// the neighbouring square is a different shade to begin with.
    ///
    /// Warm hues make it a comparison between *different* things instead. The
    /// sky is magenta, so nothing healthy is ever orange, and red reads as worse
    /// than orange without anybody being taught. Saturation goes back up because
    /// a washed-out orange is a brown — the colour has to be vivid to be the
    /// signal.
    ///
    /// Luminance still drops on the last step, so badly cracked is darker as
    /// well as redder. Two signals agreeing is what makes the state before the
    /// hole unmistakable.
    ///
    /// ## The cost
    ///
    /// Desaturating leaves the fixed palette. That is the one place in this
    /// project where that is worth doing: these are two states out of four, they
    /// are meant to look wrong, and the alternative is authoring a second and
    /// third cloud by hand for something a filter says exactly.
    static func cloudWear(
        _ health: TileHealth
    ) -> (saturation: Double, luminance: Double) {
        switch health {
        // Nothing, at any wear state. The colour is doing all of it — see
        // `cloudWearSwaps`.
        //
        // Kept as a function rather than deleted because a hole still needs to
        // be nothing, and because the *shrink* is a separate rule that has not
        // changed. Filters on top of a palette swap would only push the result
        // back off the palette the swap was chosen to stay on.
        case .healthy, .cracked, .badlyCracked: (1.00, 1.00)
        case .hole: (0, 0)
        }
    }

    /// The palette entries a worn cloud is repainted in.
    ///
    /// ## Why this takes the shade
    ///
    /// Because the two rows of the sheet are *different ramps*, not the same
    /// drawing at two brightnesses. The light cloud runs darkMagenta → magenta →
    /// pink; the dark one runs purple → darkMagenta → magenta. `magenta` is the
    /// **shadow** on one row and the **highlight** on the other.
    ///
    /// One swap table for both therefore had to be wrong somewhere, and it was:
    /// whatever `magenta` mapped to landed as a highlight on one row and a
    /// shadow on the other, so half the board came out with its shading inside
    /// out. That is the bug, and it is not fixable by choosing nicer colours.
    ///
    /// ## The rule
    ///
    /// Ordered outline → shadow → highlight, matching each row's own ramp in its
    /// own order. A target ramp that is not sorted the same way as its source
    /// turns a rounded puff inside out — the note on `SmokeSpriteView.cloudSwaps`
    /// says the same thing, and this is the second time it has had to be learned.
    static func cloudWearSwaps(_ health: TileHealth, shade: Palette.TileShade) -> [PaletteSwap] {
        // The three body tones of each row, outline → shadow → highlight.
        // Confirmed against the art rather than inferred: the perimeter pixels
        // really are the darkest tone on both rows.
        let source: [Color] = shade == .light
            ? [Palette.darkMagenta, Palette.magenta, Palette.pink]
            : [Palette.purple, Palette.darkMagenta, Palette.magenta]

        let target: [Color]
        switch health {
        case .cracked:
            // Warm and earthy, and the *shadow is left alone* on both rows.
            //
            // That is the part I would not have arrived at. Changing all three
            // tones makes a different cloud; holding the middle one and moving
            // the outline and the highlight makes the same cloud going bad —
            // there is still magenta in there, so the eye reads it as the sky
            // souring rather than as a new object.
            target = shade == .light
                ? [Palette.maroon, Palette.magenta, Palette.brown]
                : [Palette.dusk, Palette.darkMagenta, Palette.darkBrown]

        case .badlyCracked:
            // *Now* the colour drains out, which is the right way round: the
            // last state before a hole is the one with nothing left in it, and
            // it reads as worse precisely because the warm stage came first.
            target = shade == .light
                ? [Palette.dusk, Palette.pewter, Palette.lavender]
                : [Palette.mocha, Palette.dusk, Palette.pewter]

        default:
            return []
        }

        return zip(source, target).map(PaletteSwap.init)
    }

    /// How far a cloud is shoved aside when something falls past it, in art
    /// pixels, and how long the shove takes to play out.
    ///
    /// Cloud is the one material on the board that should *react*. Terra's tiles
    /// are stone and stay where they are put; a hole in the sky with a piece
    /// dropping through it, or the whole island rising up out of it, ought to
    /// push the sky around. It is the cheapest possible way to say the planes
    /// are made of different stuff.
    ///
    /// Out and back rather than a displacement that decays: the clouds are
    /// pushed and then settle, which reads as air moving rather than as the
    /// board rearranging itself.
    /// ## Why the duration is so short
    ///
    /// It has to finish before the board does. A fall spends
    /// `fallDuration / 2` on Astra and then the planes swap — so at half a
    /// second the shove was still on its way *out* when the view cut to Terra,
    /// and the settle nobody ever saw was most of the effect. It now completes
    /// inside the departure, with room to spare.
    static let cloudWakePush: CGFloat = 22
    static let cloudWakeDuration: TimeInterval = 0.3

    /// How much of the wake is spent getting *out*, as a fraction of its life.
    ///
    /// A quarter. Something dropping through the sky displaces it at once and
    /// the air takes its time closing back in — a symmetric curve spends half
    /// its life drifting outward, which reads as the clouds deciding to move
    /// rather than as being shoved.
    static let cloudWakeAttack: Double = 0.25

    /// How far a surface gives under a landing, in art pixels, and how long it
    /// takes to come back.
    ///
    /// Cloud and the island only. Terra is stone: it cracks under a landing
    /// rather than yielding to one, and a stone floor that bounced would read as
    /// a trampoline. Up here the ground is weather and rock hanging in the air,
    /// and both should be visibly *held up* by something.
    ///
    /// Short and shallow. The piece already squashes on landing; this is the
    /// other half of that impact, and if it lasts long enough to be watched it
    /// stops being an impact and becomes a wobble.
    static let surfaceBounceDepth: CGFloat = 3
    static let surfaceBounceDuration: TimeInterval = 0.19

    /// How far every cloud sits below the centre of its square, in art pixels.
    ///
    /// The art is drawn with its mass in the upper part of the cell, so centring
    /// it on the square left the field riding high above the ground the piece
    /// stands on. Four pixels puts the cloud under its own square.
    static let cloudSpriteDrop: CGFloat = 4

    /// How high the cloud under a Pentacle floats, in art pixels, and how hard
    /// its glow breathes.
    /// Deliberately faint.
    ///
    /// The lifted cloud is recoloured to blue outright — see
    /// `CloudSpriteView.raisedSwaps` — and an entirely different colour in a
    /// field of magenta is already unmissable. The glow was pushed hard back
    /// when the plan was for that square to look like every other one, and it
    /// never came back down after the recolour took over the job. All it has to
    /// do now is say the square is *lit from within*, which is a suggestion, not
    /// an announcement.
    static let cloudSpriteRaiseLift: CGFloat = 3
    static let cloudSpriteGlowPeriod: TimeInterval = 1.5
    static let cloudSpriteGlowMin: Double = 0.10
    static let cloudSpriteGlowMax: Double = 0.24
    static let cloudSpriteGlowRadius: CGFloat = 3

    /// How many times the bloom is stacked.
    ///
    /// Two: a tight core and one soft halo. A third pass is how you make a light
    /// *bright*, which is no longer what this is for.
    static let cloudSpriteGlowPasses = 2

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

    /// How often the sky redraws itself, in frames a second.
    ///
    /// Slow on purpose. A star twinkles over seconds and a cloud drifts over
    /// several, so drawing either at the display's rate is spending a hundred
    /// and twenty frames to show twelve frames' worth of change. On a still
    /// board these are the only things moving, and they were setting the whole
    /// game's frame rate.
    static let ambientFrameRate: Double = 12

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
    /// A dispersing cloud's smoke, in cells across the standard two.
    ///
    /// It was half again bigger, which on Astra — where Libra opens two squares
    /// a move — put three-tile clouds over a third of the board and hid what had
    /// happened. A shade over standard: a square coming apart *should* be the
    /// biggest puff on the board, it simply should not be the only thing on it.
    static let cloudPoofMagnitude: CGFloat = 1.15

    /// How hard a struck cloud flares. See `CloudSpriteField.drawCloud`.
    ///
    /// This is the marker for damage that did not destroy the square, which on
    /// Astra is otherwise only a cloud getting slightly smaller — easy to miss,
    /// and the whole thing Libra's trenches need to say.
    /// How many additive passes it takes to blow a struck cloud out to white.
    ///
    /// Four. Three left the darkest tones still tinted, which on a magenta cloud
    /// reads as "slightly brighter" — and slightly brighter is exactly what this
    /// has failed to communicate through three previous attempts.
    static let cloudStrikePasses = 4

    static let cloudStrikeFlash: Double = 1.0

    /// How long a struck cloud stays white.
    ///
    /// Very short. It is a flashbulb, not a state — long enough to catch the eye
    /// and gone before it can be mistaken for the square's condition.
    static let cloudStrikeFlashDuration: TimeInterval = 0.09

    /// How far the puffs of a dispersing cluster travel, in art pixels.
    static let cloudPoofSpread: CGFloat = 7

    // ──────────────────────────────────────────────────────────────────────
    // MARK: - Piece
    //
    // Where it sits on its tile, how it hops, how it falls.

    /// Extra lift applied to a piece on top of resting its 16x32 box on the
    /// tile. Positive is up.
    static let pieceLift: CGFloat = 1

    // ──────────────────────────────────────────────────────────────────────
    // MARK: - Libra's scales
    //
    // The only piece assembled from parts rather than drawn as one sprite. All
    // of these are in **art pixels**, measured from the body's own bottom edge,
    // because that is how the art was authored: an arm's lowest pixel sits at
    // the same height in its cell as Libra's does in his, so aligning the cells
    // aligns the drawings and every number below is a deliberate departure from
    // that. See `LibraPieceView`.

    /// How far above Libra's feet an arm hangs, facing toward or away.
    static let libraArmLiftNS: CGFloat = 16

    /// And in profile, where the near arm sits much lower.
    static let libraArmLiftEW: CGFloat = 3

    /// How far the far arm sits from the near one, in profile.
    ///
    /// Far higher than the near one, and not for depth's sake.
    ///
    /// The pans have to land on the squares the scales actually damage, and in
    /// profile those are the tiles ahead of and behind Libra — a whole tile
    /// apart up the screen. So the far arm is lifted most of a tile above the
    /// near one, which is what puts its pan over the right ground rather than
    /// hovering above her shoulder.
    static let libraArmLiftEWBack: CGFloat = 25

    /// How far each arm sits from centre when facing toward or away.
    ///
    /// **Negative is outward**, which is where they actually go — I read "in
    /// toward Libra" as the arms tucking against the body and had the pair
    /// mirrored, so they crossed over each other. They hang wide of her, which
    /// is what holding a balance looks like.
    ///
    /// In profile they are centred on the body instead, since one is simply
    /// behind the other.
    static let libraArmInsetNS: CGFloat = -10

    /// And how far the pans sit from centre, independently of the arm.
    ///
    /// Its own number because the two are not rigidly joined: an arm reaches
    /// out and the pan hangs *plumb* from its end, so the horizontal that suits
    /// the arm is not necessarily the one that suits what dangles off it.
    static let libraScalesInsetX: CGFloat = -6

    /// The gap between an arm's lowest pixel and the top of its pans.
    ///
    /// One per pose, because the pans are aiming at something: Equitable Impact
    /// trenches the two squares *flanking* Libra, and the art was drawn so the
    /// pans sit over the middle of those squares. A single gap can put them on
    /// the right tiles from one angle only — in profile the far pan is a whole
    /// tile further up the screen than the near one, and it has to be, because
    /// the tile it belongs to is.
    static let libraScalesGapNS: CGFloat = 0
    static let libraScalesGapEW: CGFloat = 3
    static let libraScalesGapEWBack: CGFloat = -4

    /// Where an arm's lowest pixel sits inside its own cell, from the top.
    ///
    /// Measured off the sheet rather than assumed. Both arm cells put their
    /// foot at ten, five pixels clear of the cell's bottom edge — which is
    /// exactly where Libra's own foot sits in his, and is what makes "line the
    /// cells up by their bottoms" the right way to attach them.
    ///
    /// It matters for the pans, which hang from that pixel rather than from the
    /// cell: hanging them a whole cell down put them six pixels too low.
    static let libraArmFootInCell: CGFloat = 10

    /// How far the arms rise and fall while Libra is standing still, and how
    /// long a full breath takes.
    ///
    /// Opposed: one arm is at the top of its travel while the other is at the
    /// bottom, which is what a balance does and what makes the pair read as one
    /// object rather than two decorations.
    ///
    /// One pixel either way, for three positions in total. Three *pixels* either
    /// way — which is what this was — is most of the distance between the tiles
    /// the pans are supposed to be pointing at, so the aim came and went as it
    /// breathed.
    static let libraArmSway: CGFloat = 1

    /// How far the pans swing back when Libra is carried sideways, in degrees.
    static let libraSwingAngle: Double = 60

    /// One full swing of the pans, in seconds.
    ///
    /// Deliberately longer than a hop. The swing is not an animation of the
    /// move — it is what the move *left behind*, so it keeps going after the
    /// piece has stopped and settles in its own time.
    static let libraSwingPeriod: TimeInterval = 0.8

    /// How long the swing takes to fall to a third of its size.
    ///
    /// Short enough that the backward lean is comfortably the largest thing that
    /// happens: the first peak lands around a quarter of a period in and the
    /// forward overshoot three quarters later, so the damping between them is
    /// what sets the ratio between the two — and the overshoot is a settle, not
    /// a second swing.
    static let libraSwingDamping: TimeInterval = 0.45

    /// Which sense the pans rock in facing toward or away — the same either
    /// way, so a move north and a move south disturb the balance identically.
    /// Flip the sign to swap which pan leads.
    static let libraRockSense: Double = -1

    /// Which way a north-south swing is drawn: as a turn into the screen, or as
    /// the two pans rocking apart in the plane the viewer can see.
    ///
    /// The keystone is the truthful one and is kept whole behind this — see
    /// `PanSwing`. The rock is the one that reads at sixteen pixels.
    static let libraDepthSwingUsesKeystone = false

    /// How much of the swing's angle the north-south poses spend. See `PanSwing`.
    ///
    /// Under one, because a rotation into the screen has less room than one
    /// across it: past sixty degrees the pan is nearly edge-on and collapses to
    /// a line, where the same angle sideways is still plainly a dish.
    static let libraDepthSwingScale: Double = 0.75

    /// How far the far edge of a pan pinches in at full swing, as a fraction of
    /// its width. See `PanSwing` — the taper is bounded, so this only deepens
    /// the keystone and never grows the sprite.
    ///
    /// Far stronger than life. At sixteen pixels a realistic amount of
    /// foreshortening is a sub-pixel change and reads as nothing.
    static let libraDepthSwingTaper: Double = 0.55

    /// How far the arms rise while she is in the air, and how far below resting
    /// they drop as she lands — the pans meeting the tile is the moment the
    /// ground is charged for.
    static let libraCarryLift: CGFloat = 3
    static let libraLandDip: CGFloat = 3

    /// How much of a hop is spent in the air before the landing dip.
    static let libraLandFraction: Double = 0.8

    /// How big each pan's dust cloud is against an ordinary landing puff.
    ///
    /// Under half, because there are two of them and they fire together: two
    /// full puffs either side of the piece is more dust than a fall raises.
    static let libraPanDustMagnitude: CGFloat = 0.7

    /// The pans' own shadows. See `LibraPieceView.panShadow(side:sway:)`.
    ///
    /// A full tile wide, and deliberately wider than the body's own — a pan is
    /// wider than Libra is, and a big object throwing a small shadow reads as
    /// hovering. It was set narrower on the reasoning that a hanging part is a
    /// detail, which is a rule about importance rather than about size.
    ///
    /// One tile is the cap rather than the true width. The pans overhang a
    /// little further than that, but a shadow that crosses into the next square
    /// is claiming ground the scales are not standing on — and those squares are
    /// exactly the ones the player is reading for what the trenches will hit.
    static let libraPanShadowWidth: CGFloat = 1
    /// The same as any other piece's — a pan is a solid object standing over a
    /// tile and occludes it exactly as much as the piece does. It was darker,
    /// which made the scales read as heavier than the sign carrying them.
    static let libraPanShadowOpacity: Double = 0.45

    /// How far a pan has to rise, in art pixels, for the shadow to reach its
    /// full shrink. The swing and the landing dip both work well inside this.
    static let libraPanShadowRange: CGFloat = 4

    /// How much of the shadow that rise takes away, at most.
    static let libraPanShadowSpread: CGFloat = 0.45

    /// How far a pan's shadow travels with the swing, as a fraction of a tile at
    /// full lean. The pan pivots at the cord, so its foot moves and its shadow
    /// has to move with it or it is paint rather than shadow.
    static let libraPanShadowTravel: Double = 0.3

    /// How far up the screen a pan's shadow sits when its square is a row away,
    /// as a fraction of a tile.
    ///
    /// Under one because the board is foreshortened vertically and not
    /// horizontally: every tile is drawn with a front edge, so the row above is
    /// nearer than a tile is wide. A full tile put the far pan's shadow a row
    /// too high — see `LibraPieceView.panShadow(side:sway:swing:)`.
    static let libraPanShadowFlankRise: CGFloat = 0.7
    static let libraArmSwayPeriod: TimeInterval = 2.4

    /// How fast the pans cycle.
    static let libraScalesRate = SpriteRate.fps7_5

    /// How far the shadow sits below a piece's own centre.
    ///
    /// At `0` it lands dead centre of the tile, where the sprite covers it
    /// completely — which is how it went missing. The piece's opaque pixels end
    /// about two art pixels below the tile's centre, so the shadow has to clear
    /// that to be seen at all.
    /// How far the shadow sits below the piece's own middle, in art pixels.
    ///
    /// Four rather than two: it has been riding two pixels high all along,
    /// which reads as the piece hovering rather than standing.
    static let pieceShadowDrop: CGFloat = 4

    /// How much smaller the piece's shadow gets at the top of a hop, as a
    /// fraction of its resting size.
    ///
    /// The same trick the Pentacle's glow uses: a shadow narrowing as its caster
    /// rises says "height" far more clearly than the rise itself does, because
    /// the shadow stays on the ground where the eye can measure it against
    /// something fixed.
    /// How small a shadow is allowed to get, however high the piece goes.
    /// Not zero — a piece with no shadow at all has left the board rather than
    /// jumped.
    static let pieceShadowFloor: CGFloat = 0.25

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
    ///
    /// Seven copies at 0.88 keep more than half their brightness all the way to
    /// the end of the trail, and additively that is most of the light. Dropping
    /// it puts the weight on the copies nearest the piece, which is where a
    /// streak should be brightest anyway.
    static let gemTrailFalloff: Double = 0.72

    /// Seconds of spring response per step of lag.
    ///
    /// This is the knob that decides whether the gems streak or merely smear:
    /// raise it and the tail stretches further behind the piece.
    static let gemTrailLag: TimeInterval = 0.22

    /// How many times each after-image is drawn on top of itself.
    ///
    /// **One.** It was three, to carry a three-pixel gem across a whole square
    /// after the blur had been cut off square at the piece's frame and lost most
    /// of its reach. With the trail given room to spread, the same three copies
    /// summed additively blew the piece out to white.
    ///
    /// Left as a knob rather than removed: restacking is still the cheapest way
    /// to make a small light carry, if a sign ever needs one that does.
    static let gemTrailBoost = 1

    /// A single hop between tiles.
    static let hopDuration: TimeInterval = 0.12

    /// How long a move asked for mid-turn stays worth answering, in seconds.
    ///
    /// Generous enough to cover the tail of an ordinary turn — which is what the
    /// player is flicking through — and far short of a Zodiaction or a fall. An
    /// input held across one of those is an input about a board that has since
    /// changed, and answering it late is a lurch rather than a favour. See
    /// `GameSession.submit(_:reach:)`.
    static let inputBufferWindow: TimeInterval = 0.6

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
    /// Raised from a fraction to a whole arc: each extra square adds as much
    /// height again as the first one had. A two-square vault reads as a *vault*
    /// rather than as a step that happened to cover more ground, which is the
    /// only thing that distinguishes Scorpio's hole-clearing jump on sight.
    static let hopArcHeightPerExtraTile: CGFloat = 1

    /// How much higher a hop arcs when it ends **on the island**.
    ///
    /// The Nexys stands proud of the board, so a hop onto it is a climb rather
    /// than a step across. At the ordinary arc the piece skims the rock's face
    /// and appears on top of it; the taller arc clears the edge, which is what
    /// makes the landing read as getting *up* there.
    static let hopArcHeightOntoNexys: CGFloat = 1.1

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
    /// How long Gemini takes to come apart, and to come back together.
    /// What driving the shadow into something fatal is worth, as a fraction of
    /// the meter. Catching it outright is worth all of it.
    ///
    /// Catching costs a move spent walking into the thing that is doubling your
    /// wear; driving it somewhere is something you were doing anyway. The gap
    /// between them is the difference between a plan and an opportunity.
    /// How often Shadow Work turns up.
    ///
    /// Legendary, alongside Polaris. It is the one coin in the game that makes
    /// the board actively worse, so it wants to be a *event* rather than a
    /// recurring tax — and the disposal rules only read as clever if you meet
    /// them rarely enough to have to think each time.
    static let shadowWorkWeight = 1

    /// How solid the double looks. Dark enough to be a shadow, present enough to
    /// be a thing you have to deal with.
    static let shadowOpacity: Double = 0.75

    static let shadowDriveOffFraction: Double = 0.5

    static let soulSplitDuration: TimeInterval = 0.55


    /// How long a lost half's soul takes to rise and be absorbed.
    static let soulRiseDuration: TimeInterval = 0.9

    /// What rejoining is worth: the meter, outright.
    ///
    /// Gemini has no other charge rule — see `GeminiMirroredMandate` — so this
    /// is the whole of it. Getting two halves onto one square across two planes
    /// is hard enough to be the sign's entire economy.
    static let soulRejoinCharge = 999

    /// What a lost half is worth to the one that absorbs it, as a fraction of
    /// the meter. Sibling Soul.
    static let siblingSoulFraction: Double = 0.5

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
    /// How much smaller the coin is drawn at the top of its bob.
    ///
    /// Its pool of light already narrows as it rises, but the coin itself held
    /// one size the whole way up — so the two halves of the hover disagreed
    /// about whether anything had moved away. Small: it is a hand's height off
    /// a tile, not a departure.
    static let pentacleRiseScaleSwing: CGFloat = 0.08

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
    /// The one square Polaris may appear on: north, middle.
    static let polarisPoint = GridPoint(gridSize / 2, 0)

    /// And how often it does, once a Pentacle is confirmed there.
    ///
    /// A third. The square alone was supposed to be the gate and is a weak one —
    /// a five-square sparkle set covers it often — so the scarcity that reads as
    /// "one tile in forty-nine" has to actually be asked *of that tile*. See
    /// `GameEngine.drawPickup(at:on:)`.
    static let polarisSpawnChance: Double = 1.0 / 3.0

    static let polarisSpinPeriod: TimeInterval = -6.5

    /// How strongly the coin's highlights bloom. Below 1 the glow is thinner
    /// than the mask it is drawn from.
    static let pentacleGlowIntensity: Double = 0.26

    /// Polaris' own bloom. Separate from the gold coin's: the star is already
    /// the brightest thing on the board before anything is added to it.
    static let polarisGlowIntensity: Double = 0.3

    // ──────────────────────────────────────────────────────────────────────
    // MARK: - The gavel
    //
    // One frame of art, swung from code. See `PentacleView.gavelSwing(at:)`.
    // The fractions below are portions of one loop and should sum to less than
    // 1 — whatever is left over is the ease back to rest.

    static let gavelGlowIntensity: Double = 1.3

    /// The shadow under it, in dark magenta.
    static let gavelShadowOpacity: Double = 0.85
    static let gavelShadowRadius: CGFloat = 3
    static let gavelShadowDrop: CGFloat = 3

    /// How long one whole swing-and-settle takes.
    static let gavelSwingPeriod: TimeInterval = 2.6

    /// Sitting perfectly still, which is most of it. A hammer that swings
    /// without pause is wallpaper; the stillness is what makes the swing an
    /// event.
    static let gavelRestFraction: Double = 0.52

    /// Winding back, coming round, and held at the bottom.
    static let gavelCockFraction: Double = 0.16
    static let gavelStrikeFraction: Double = 0.07
    static let gavelHangFraction: Double = 0.09

    /// How far back it winds, and how far past level it carries.
    static let gavelCockAngle: Double = 34
    static let gavelOvershoot: Double = 16

    /// It shrinks as it draws back and swells as it lands — the oldest trick
    /// there is for making a small drawing hit hard.
    static let gavelCockScale: CGFloat = 0.85
    static let gavelStrikeScale: CGFloat = 1.12

    /// And flattens on the way through. With nothing to strike, the squash is
    /// the only thing that says it struck.
    static let gavelPancake: CGFloat = 1.14

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

    /// How hard the tint sits on the square at its strongest.
    /// How long the whole run of colours takes.
    ///
    /// Matched to the motes, so the flash and the shimmer are one event rather
    /// than two that happen to overlap.
    static var healFlashDuration: TimeInterval { healSparkleDuration }

    static let healFlashStrength: Double = 0.85


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

    /// Charge for one ordinary step on Astra. See `PiscesStarstreamSurfer`.
    ///
    /// The surf used to pay this and steps paid nothing; they have traded
    /// places. Steps are what fill the meter now, and a full meter is what buys
    /// the surf.
    static let starstreamStepCharge = 1

    // ── Pisces' bubbles ───────────────────────────────────────────────────

    /// How deep Pisces' meter runs on Terra. See `PiscesSurgingStream`.
    static let piscesTerraMeterMax = 12

    /// What one bubble is worth.
    ///
    /// Small on purpose. Bubbles are the *whole* of Pisces' charge on Terra, so
    /// they are meant to be gathered rather than found — the sign's problem down
    /// there is a long errand, not a lucky break.
    ///
    /// There is deliberately no snipe bonus here. Reaching any pickup on the
    /// turn it appeared already pays `revealTileCharge`, to every sign, so a
    /// bubble caught that way is worth this plus that and needs no rule of its
    /// own. It had one, and the two stacked.
    static let bubbleCharge = 1

    /// The chance of a bubble appearing alongside the reveal, and how many may.
    ///
    /// Rolled per bubble, so two is the chance twice rather than a separate
    /// case. Scaled by the run's luck, which is how Sagittarius' Fortunate Find
    /// reaches them without naming them.
    /// How long a spilled bubble takes to fly from the piece to its square.
    ///
    /// The whole handful shares one throw — see `GameSession.scatterBubbles`.
    static let bubbleScatterDuration: TimeInterval = 0.55

    /// How long each bubble waits behind the one before it.
    ///
    /// They erupt one after another rather than as a single spray — a handful
    /// leaving on the same frame reads as a pattern being drawn, where a stagger
    /// reads as things being thrown.
    static let bubbleScatterStagger: TimeInterval = 0.07

    /// How high a thrown bubble arcs above the straight line to its square, as a
    /// fraction of the distance it covers. Up and out, then raining down.
    static let bubbleScatterArc: CGFloat = 0.55

    /// How small a bubble starts. Zero, and it grows as it climbs — the volcano
    /// rather than a coin sliding across the floor.
    static let bubbleScatterGrowth: CGFloat = 1.25

    static let bubbleSpawnChance = 0.55
    static let bubbleMaxPerPhase = 2

    /// Charge for stepping into a pool. Paid every time, not once.
    ///
    /// One, and deliberately small. The pool is a place worth walking back to on
    /// a plane that drains a pip for every square you leave — it is break-even
    /// plus nothing, which makes it a foothold rather than an engine.
    static let poolCharge = 1

    /// Charge from one of Gaia Geyser's droplets.
    ///
    /// What one droplet is worth.
    ///
    /// It used to be a whole meter, because a droplet was one of eight in a ring
    /// and taking it dismissed the other seven — a full meter *was* the offer.
    /// The ring is gone; a droplet is now what a geyser throws up, and it is
    /// worth what a geyser is worth.
    static let gaiaDropletCharge = 3

    /// The chance a freshly-made hole on Terra sprouts one. See
    /// `PiscesGaiaGeyser`.
    ///
    /// Read as *water finding a way up through ground that just broke*, which is
    /// also why it only answers to new holes: an old one has already drained.
    static let gaiaGeyserChance = 0.12

    // ── Umbra ─────────────────────────────────────────────────────────────

    /// Scenery is drawn in `smoke`, which is also the dark floor's own colour.
    /// On a dark tile it is swapped one step darker so it still reads. See
    /// `SpriteID.umbraDecor`.
    static let umbraDecorDarkSwap = PaletteSwap(Palette.smoke, Palette.coolBlack)

    /// How likely a tile is to be given a piece of scenery when Umbra is
    /// generated, and how much rarer the turned one is.
    static let umbraDecorChance = 0.18
    static let umbraDecorRareChance = 0.04

    /// How many impassable rocks a generated Umbra carries. Their job is to
    /// give the player something to put between themselves and Nilyth.
    static let umbraRockCount = 2

    // ── The ground seen from Astra ────────────────────────────────────────
    //
    // See `BoardView.groundBelow(plane:metrics:)`.

    /// How much of the sky's height the world below occupies, from the bottom.
    static let groundBelowHeight: CGFloat = 0.25

    /// How far past the bottom of the square the ground below is pushed.
    ///
    /// The keystone pulls its content toward the near edge, so the band ends
    /// slightly short of the bottom and leaves a seam of sky under the world.
    /// A floor has no far side from here — it runs off the bottom of the
    /// screen — so overshooting costs nothing and closes it.
    static let groundBelowOvershoot: CGFloat = 0.04

    /// Where Astra's sky has finished turning from the dark of space into
    /// Terra's daylight, measured down the upper square.
    ///
    /// Just above the top of the faux Terra below, so the light has arrived by
    /// the time the ground does. Derived from `groundBelowHeight` rather than
    /// written twice, so moving the horizon moves the gradient with it.
    static var astraSkyFade: CGFloat { 2.25 }

    /// Where Astra's stars have finished fading out, down the upper square.
    ///
    /// Above the sky's own fade, so the last star is gone before the blue
    /// arrives. Stars in daylight are the tell that a starfield was laid over a
    /// gradient rather than being the far half of one sky.
    static var astraStarFade: CGFloat { astraSkyFade * 0.7 }

    /// How long the turn from space to daylight takes, as a fraction of the
    /// square.
    ///
    /// Fixed, so `astraSkyFade` moves the band rather than stretching it. With
    /// the ramp pinned to the top of the square instead, raising the fade made
    /// the transition longer and softer — which looks like the sky changing
    /// strength rather than the horizon changing height.
    static let astraSkyFadeWidth: CGFloat = 1.5


    /// How far off each edge of the screen it is held, as a fraction of the
    /// square. Run edge to edge it reads as a fitted carpet; inset, as a
    /// landmass with sky either side.
    static let groundBelowInset: CGFloat = 0.08

    /// How much narrower the far edge of a board is than its near one.
    ///
    /// Laying the plane down rather than showing it flat-on. See
    /// `View.foreshortened(_:)`.
    ///
    /// The ceiling on this is legibility rather than taste: far enough and the
    /// top row's squares stop reading as the same size as the bottom's, and a
    /// grid the player cannot count is a grid they cannot plan on.
    /// How high the camera sits above the board, in board-widths.
    ///
    /// The degree of freedom the projection was missing. A pinhole looking at a
    /// plane sees widths as `1/distance` and heights as `cameraHeight/distance`
    /// — so the tilt sets how much the board *narrows* into the distance, and
    /// the camera height *alone* sets how tall the whole thing stands. They are
    /// independent, and the old `projected` fused them: it was algebraically
    /// identical to this with the height pinned at exactly `1 / boardForeshorten`.
    ///
    /// That pin is why the board's squares could not be made squarer without
    /// also changing the tilt, and why correcting the shape needed a stack of
    /// dials pulling against each other. Raising this makes the rows taller and
    /// the squares squarer; lowering it lays the board flatter. It does not
    /// touch the widths, so the perspective stays consistent either way.
    /// Three quarters of a board-width up. Chosen by eye at 1.75, which lays the
    /// plane down convincingly while keeping the squares close to square.
    static let boardCamera: CGFloat = 1.75

    static let boardForeshorten: CGFloat = 0.45

    /// How much the board is enlarged to fill the space foreshortening costs it.
    ///
    /// A keystone pulls the far rows down and in, so the tilt leaves a margin at
    /// the top and at the upper corners. Scaling back up from the near edge
    /// spends that margin rather than leaving it as a gap.
    static let boardForeshortenScale: CGFloat = 1.25

    /// How hard depth bites on Astra — a magnitude on the shrink itself, where
    /// `1` is the true camera. See `PixelArtMetrics.projected(_:)`.
    ///
    /// Astra is allowed the licence because nothing up there has to tile: the
    /// clouds are loose shapes drawn foreshortened already, so how much they
    /// recede is a matter of how deep the sky should feel. Terra stays at `1`,
    /// where a grid disagreeing with its own geometry would open seams.
    static let astraDepthEmphasis: CGFloat = 1.0

    /// Astra's own framing zoom and lift, kept apart from Terra's.
    ///
    /// The plane rides higher and is framed slightly smaller than the ground
    /// below it, which is what puts a piece's feet at the same height on both.
    static let astraForeshortenScale: CGFloat = 1.0
    static let astraForeshortenLift: CGFloat = 0.15 + 0.25 / CGFloat(gridSize)

    /// How much of its square a cloud fills, and how far apart the squares sit.
    ///
    /// **Two spacings, not one.** A cloud is wider than it is tall and the rows
    /// are closer together than the columns, so one number for both had to be
    /// wrong on one axis to be right on the other — which is why the field kept
    /// reading as either too gappy across or too crowded down.
    /// The row the depth emphasis pivots on, as a divisor.
    ///
    /// The middle of the board, so tuning the depth opens outward from a fixed
    /// centre instead of resizing the plane. **Terra does not pivot** — its
    /// squares are placed by `BoardBand`, which measures from the near edge, and
    /// a piece pivoted about the middle would stand 22% too large on ground that
    /// was not.
    static let astraDepthPivot: CGFloat = 1 + boardForeshorten / 2

    /// How much taller a ground marker is drawn on the near rows, on **Astra**.
    ///
    /// A mark on a cloud is not lying on a flat plane — the cloud is a mound, so
    /// the nearer ones present more of their top face to the viewer than the
    /// squash of a flat floor allows for. Terra takes none of this: its ground
    /// really is flat, and the band's squash is already exactly right there.
    ///
    /// Slight on purpose. It is a correction for the shape of the art, not a
    /// second perspective.
    static let astraMarkStretch: CGFloat = 0.15

    static let cloudBaseSize: CGFloat = 0.9
    static let cloudSpacingX: CGFloat = 1.0
    /// Wider apart down the screen than across it, because a cloud is wider
    /// than it is tall — one number could only ever be right on one axis.
    static let cloudSpacingY: CGFloat = 1.25

    /// Where the figure sits on its square, in art pixels.
    static let pieceSeatDrop: CGFloat = 0

    /// How far the tilted board is lifted back up its square, as a fraction of
    /// the board. A keystone pulls its content toward the near edge, so without
    /// this the board sits lower in the sky than the flat one did.
    /// Both boards ride one whole tile higher than the framing alone puts them,
    /// which is what `1 / gridSize` is: the lift is a fraction of the board, and
    /// a board is `gridSize` tiles.
    static let boardForeshortenLift: CGFloat = 0.05 + 0.25 / CGFloat(gridSize)

    /// How far each row of the board overdraws the one behind it.
    ///
    /// How far a tile's art is drawn past its own square, in art pixels.
    ///
    /// The sprites carry a two-pixel border meant to overlap the neighbour, so
    /// squares meet with no seam. Any drawing that sizes a tile to its bare
    /// geometric extent — a row band, for one — comes up exactly this short.
    ///
    /// A *fixed* number of pixels, never a percentage: a multiplier closes the
    /// same seam by stretching the ground, and then the squares are no longer
    /// square. See `BoardBand`.
    /// Not a whole two: the far rows lose their border at 2 and the near rows
    /// open a seam at 3, so the value that satisfies both ends of the board sits
    /// between them. A row is a fraction of a pixel either way once it has been
    /// scaled for depth, and this is where that fraction lands.
    static let tileBorderPixels: CGFloat = 1.5

    /// How much night sits over the far edge of a board, fading to nothing at
    /// the near one. Atmospheric perspective — see `BoardView`.
    static let boardHazeFar: Double = 0.2

    /// How much of a tile the front face of the board actually occupies. Used to
    /// un-bend it across its own height rather than a whole square.
    static let tileFrontEdgeStrip: CGFloat = 0.25

    /// How far an uprighted object is pushed back down, in **art pixels**.
    /// Measured on device: one pixel seats a piece in an ordinary tile.
    static let uprightFeetDrop: CGFloat = 1

    /// And the extra a piece needs while riding the island, on top of that.
    ///
    /// **Added, not subtracted**, which is the opposite of what the geometry
    /// suggests — the island holds the piece higher, so the intuition is to
    /// pull it up. Measured on device: five pixels total seats it in the wreath
    /// against one on the ground.
    static let nexysRideDrop: CGFloat = 4

    /// How much of the island's float a carried piece takes.
    ///
    /// Not one. The island is fully keystoned while the piece is corrected back
    /// upright, so the same offset is scaled differently for each and they
    /// drift apart over the bob. Measured on device by eye at full speed:
    /// either side of this and the lag is visible within a pixel.
    /// How much of the island's float the piece standing on it takes.
    ///
    /// **All of it.** It was 0.78, which is not a thing a passenger can be: a
    /// figure standing on a moving object moves with the object. The fraction
    /// was hiding a placement error underneath it, and now that the piece and
    /// the island are on one camera there is nothing left to hide — anything
    /// other than 1 reads as the piece sliding on the rock.
    static let carryFollow: CGFloat = 1

    /// How far the piece's shadow is lifted back, in art pixels, against the
    /// drop that seats the figure. Measured on device — see `PieceView`.
    static let pieceShadowPerspectiveLift: CGFloat = 2

    /// How far out of focus it is, in art pixels. Heavy on purpose: anything
    /// legible enough to count squares on is something the player will try to
    /// plan with.
    static let groundBelowBlur: CGFloat = 1.2

    /// How much night is laid over it. **Opaque** — the ground is solid, and
    /// fading it let the stars shine through the world.
    static let groundBelowShade: Double = 0.65

    // ── Nilyth's eyes, through the umbra hole ─────────────────────────────
    //
    // See `UmbraEyesView`. All distances are art pixels.

    /// Two eyes, each two pixels on a diagonal, with two pixels of dark between
    /// them — matching the slant and the spacing Aries' statue already wears.
    static let umbraEyeRows = 2
    static let umbraEyeGap = 2

    /// How far the pair drifts from the tile's centre, in either direction.
    /// They move together — it is one creature looking around, not two.
    static let umbraEyeWander = 2

    /// How often the eyes come back, how long they stay, and how much the
    /// interval wanders so it never reads as a metronome.
    static let umbraEyesCycle: TimeInterval = 6.5
    static let umbraEyesCycleJitter: TimeInterval = 2.5
    static let umbraEyesDwell: TimeInterval = 2.8

    /// How long a direction is held before the eyes move again.
    static let umbraEyesLookInterval: TimeInterval = 0.65

    /// One frame of a blink, and how often one happens on a given look.
    static let umbraBlinkFrame: TimeInterval = 0.07
    static let umbraBlinkChance = 0.35

    /// The carried-Polaris badge, as a fraction of a tile, and how far it fades
    /// while the fragment is still cold.
    static let polarisBadgeScale: CGFloat = 0.7
    static let polarisBadgeDormantOpacity: Double = 0.55

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
    /// How translucent the abandoned skin is.
    ///
    /// It is a receipt, and a receipt you cannot read is not one — at a quarter
    /// it was invisible against Terra. Ghostly, not absent.
    static let shedSkinOpacity: Double = 0.62

    /// How far the husk drifts, in art pixels, and how long one breath takes.
    ///
    /// It hangs over the hole rather than lying in it. Scorpio did not leave a
    /// body on the ground; it left the *shape* of itself where it stopped being
    /// there, and a shape that holds perfectly still reads as a sprite somebody
    /// forgot to clear.
    static let shedSkinFloat: CGFloat = 1.5
    static let shedSkinFloatPeriod: TimeInterval = 2.8

    /// How long the strike is on screen, out and back.
    static let stingDuration: TimeInterval = 0.34

    /// How solid the lance is. Low: it is a phantasm, and the board it crosses
    /// has to stay readable underneath it.
    static let stingOpacity: Double = 0.55

    /// How long a coin takes to be reeled in along the tail.
    ///
    /// The gather used to be instantaneous and fired before the lance had
    /// finished extending, so the Pentacle vanished while the tail was still on
    /// its way out — the ability read as "coins near you disappear", which is
    /// not what it does at all.
    static let stingReelDuration: TimeInterval = 0.22

    /// How much of the strike is the lunge, the rest being the withdrawal.
    ///
    /// Shared with the session, which waits out exactly this much before it lets
    /// anything be gathered: the tail has to be *there* before it can take
    /// something.
    static let stingAttack: Double = 0.35

    /// Capricorn's purse, in Pentacles, on each plane.
    ///
    /// Lower on Terra: the earth sign is at home down there, so the price of
    /// being at home is a smaller ceiling. Costing the cap rather than the fill
    /// rate keeps every individual coin worth the same.
    static let capricornPurseAstra = 10
    static let capricornPurseTerra = 8

    /// How full Capricorn's **meter** gets, here.
    ///
    /// Named for the purse because that is what the meter counts and how it is
    /// drawn — but it is a charge cap, not an inventory limit. The purse itself
    /// has no ceiling: quantities stack, so two Tears banked are one slot
    /// reading two, and nothing is ever lost for having plenty.
    ///
    /// Which matters most for Leo. A borrowed Capricorn does not shrink Leo's
    /// ten-pip meter to eight on Terra — the meter belongs to the sign being
    /// played, and only the purse is on loan. Pentacles are not charge, whatever
    /// they share underneath.
    static func purseCapacity(on plane: Plane) -> Int {
        plane == .terra ? capricornPurseTerra : capricornPurseAstra
    }

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
    /// How far a tinted puff is lifted before its colour is multiplied in.
    ///
    /// See `SmokeSpriteView.recoloured` — a multiply cannot brighten, so the
    /// art has to be brought up to meet the tint.
    static let smokeTintLift: Double = 0.3

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

    /// How big the storm's own art is drawn when it plays for the **transform**
    /// rather than for the Zodiaction.
    ///
    /// Smaller, because the two are not the same event. Going from bare statue
    /// to storm is the sign waking up; popping the Zodiaction is the sign
    /// spending everything it has. If both played at the same size the second
    /// would land as a repeat of the first, and the loudest moment in the kit
    /// would be the one the player had already seen.
    static let aquariusTransformScale: CGFloat = 0.6

    /// Committed moves the two Essences run for.
    ///
    /// Three, and the same number for both, because they are one effect with a
    /// sign in front of it — a drain that outlasted its mirror would make the
    /// pair read as two unrelated coins that happen to share a word.
    static let essenceMoves = 3

    /// Seconds the Breeze takes to carry the piece across.
    ///
    /// Longer than a step and shorter than a fall: the distance is the point, so
    /// it has to be watchable, but it is still one move and the turn is waiting
    /// on it.
    static let blownDuration: TimeInterval = 0.42

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

    /// How long one square of each travelling style takes, against a step.
    ///
    /// Declared beside each other so the styles can be compared rather than
    /// discovered one call site at a time. See `MovementStyle.paceMultiplier`.
    static let slideStepPace: Double = 0.45
    static let chargeStepPace: Double = 0.6
    static let leapPace: Double = 2.2

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
    /// How far ahead of the piece its facing arrow sits, in tiles.
    ///
    /// Short of the next square's centre on purpose: it points *at* that square,
    /// and sitting on it would read as something standing there.
    static let facingArrowReach: CGFloat = 0.66

    /// How big it is drawn against a full cell.
    static let facingArrowScale: CGFloat = 0.5

    /// How far off the ground it floats, in art pixels.
    ///
    /// It is a marker rather than a thing lying on the floor, and at ground
    /// level it was being read as debris on the square ahead.
    ///
    /// Twelve, not eight. The lift is applied inside the arrow, so the row's
    /// own scale shrinks it along with everything else — which is right for
    /// something standing on the ground and wrong for the gap that keeps a
    /// marker legible, so it read as sitting lower the further back it went.
    /// Astra stretches the picture further: its rows are spread 1.25 vertically
    /// against 1.0 across, so the ground under the arrow moved down and the
    /// lift did not move with it.
    /// **One** number, for both planes and both axes.
    ///
    /// It was briefly four. They were four because the arrow was being
    /// foreshortened twice — once by its own art and once by the floor's squash
    /// — and each pairing needed a different amount of that undone. With the
    /// double gone the four collapse into one, which is the tell that they were
    /// never four different quantities.
    // MARK: - Aquarius' storm

    /// The funnel, settled. Everything here is a proportion of the square the
    /// storm is drawn in, so the assembly scales as one — see
    /// `aquariusStormScale`.
    static let aquariusStormHeight: CGFloat = 0.15
    static let aquariusStormBlade: CGFloat = 0.8
    static let aquariusStormSpread: Double = 2
    /// How many frames come off the end of a plate's strip, at a full meter and
    /// at an empty one.
    ///
    /// The tail of the strip is where the gust thins out and breaks up, so
    /// keeping more of it is how a storm comes apart. A full meter trims all
    /// five and every plate is a solid sheet; near empty only two come off, the
    /// ragged frames play, and the gaps between blades start showing — which is
    /// the picture of something about to run out of wind rather than a smaller
    /// copy of something that is not.
    static let aquariusStormTaperMost: Int = 5
    static let aquariusStormTaperLeast: Int = 2

    static let aquariusStormTaper: Int = 5

    /// The eye: two plates, the smaller two thirds of the larger, taking half
    /// the stack's sway because the eye sits deeper in the column than the wall
    /// around it.
    static let aquariusEyeScale: CGFloat = 0.75
    static let aquariusEyeTwinScale: CGFloat = 0.66
    static let aquariusEyeTurn: Double = 10
    static let aquariusEyeSway: CGFloat = 0.5
    static let aquariusEyeY: CGFloat = -0.05
    static let aquariusEyeTwinY: CGFloat = -0.15

    /// The figure inside, and where his eyes sit in the picture.
    static let aquariusFigureScale: CGFloat = 1.5
    static let aquariusFigureTurn: Double = 5
    /// Where he hangs in the funnel.
    ///
    /// High in it rather than at its middle: the funnel is widest at the top
    /// and the eye of the storm sits up there, so a figure at the centre is
    /// behind the thickest part of the wall instead of inside the opening.
    static let aquariusFigureY: CGFloat = -150
    static let aquariusEyeGlowY: CGFloat = -55

    /// How hard the eyes burn at the top of their breath, and how long one
    /// breath takes.
    ///
    /// They swing all the way to nothing and back rather than pulsing about a
    /// middle: a light that never fully goes out reads as a lamp, and one that
    /// does reads as something blinking at you.
    static let aquariusEyeGlowPeak: CGFloat = 2.5
    static let aquariusEyeGlowPeriod: TimeInterval = 6.5

    /// How soft the eyes are at a full meter, in points, falling to nothing by
    /// phase one.
    ///
    /// Applied to the **pair**, after they are placed, rather than to either
    /// eye — the two smear into one another at full strength, which is what
    /// makes a storm's eyes read as light in cloud rather than as two shapes
    /// sitting in front of it. Where the blur goes changes the look, so this is
    /// only the amount.
    static let aquariusEyeHaze: CGFloat = 5

    /// The whole assembly against a board square.
    /// One. The storm is allowed to be as big as it is — which is the sign's
    /// whole claim — so long as the square he is standing on stays readable.
    /// That is what the cursor, his shadow and the facing arrow are for, and
    /// they all sit on the ground rather than inside the funnel.
    static let aquariusStormScale: CGFloat = 1.0

    /// How many board squares the tuned assembly is meant to span.
    ///
    /// It is built at the 300-point size it was judged at and scaled once, so
    /// this is the only thing that says how big that is on a board. Scaling it
    /// to one tile made everything correct and minute; the funnel is a few
    /// squares across by design.
    static let aquariusStormTiles: CGFloat = 3

    /// The square the assembly is flattened into, in points.
    ///
    /// Bigger than the 300 the storm's proportions are measured against,
    /// because the figure is 264 tall before his scale and the outer plates
    /// reach most of the way across — flattening into the measuring square cut
    /// both off. The extra is headroom for the group's bounds and costs nothing
    /// but texture.
    static let aquariusStormCanvas: CGFloat = 620

    /// How many frames a phase's cached loop holds, and how long it runs.
    ///
    /// The storm's motions do not share a period — the plates shake on their
    /// own counts, the strip loops on another — so a cached loop is a slice of
    /// something that never exactly repeats. Two seconds is long enough that
    /// the seam is not a beat you can count, and twenty-four frames is the rate
    /// the long strips already play at.
    static let aquariusStormFilmFrames = 24
    static let aquariusStormFilmPeriod: TimeInterval = 2

    /// How much smaller the figure and his eyes are at an **empty** meter.
    ///
    /// The bluff, and it runs the way the storm does rather than against it:
    /// a full storm holds something huge, and what is left when the storm goes
    /// is a little gold pot. The shape inside grows *with* the funnel, which is
    /// what makes the reveal at zero land — the tornado was never hiding
    /// something small, it was hiding something that shrank as it lost its
    /// cover. See the Aquarius rework.
    static let aquariusFigureShrink: CGFloat = 0.5

    /// How far the eyes follow the figure's shrink — see the gallery. `1` rides
    /// his centre, `2` his head.
    static let aquariusEyeFollow: CGFloat = 0.75

    /// How much of his own shrink he sinks by.
    ///
    /// Not all of it. Pinning his feet was the wrong model: he is not standing
    /// in the funnel, he is held up by it — and the funnel's **top edge is at
    /// the same height whatever the phase**, because the plate spacing divides
    /// out of where the topmost one lands. So the eye of the storm does not
    /// come down as the storm weakens, and neither should he. Half, so he
    /// settles a little without following a floor that is not there.
    static let aquariusFigureSink: CGFloat = 0.75

    /// How many plates the funnel has, at an empty meter and at a full one.
    ///
    /// The floor is high on purpose. A storm is a *wall*, and three plates
    /// spread over his height are a few bands with the figure showing between
    /// them — which reads as a costume rather than as something he is inside.
    /// The stack thins toward the reveal by getting smaller, not by getting
    /// gappy.
    static let aquariusStormBandsLeast = 6
    static let aquariusStormBandsMost = 13

    // MARK: - Virgo's gems

    /// How far the outer gems travel, in art pixels.
    ///
    /// The drawn position is the **top** of the path, not its middle: the gems
    /// swing down toward her and come back, rather than bobbing either side of
    /// where they were authored. That is what keeps the resting arrangement —
    /// the one that was checked against the art — as a real position in the
    /// motion instead of an average of two wrong ones.
    static let virgoGemSwingX: CGFloat = 3
    static let virgoGemSwingY: CGFloat = 3

    /// Seconds for one circuit of the oval.
    static let virgoGemPeriod: TimeInterval = 3.4

    /// How far the middle gem rises and falls, and how long it takes.
    ///
    /// Slower than the pair and on its own count, so the three never line up
    /// into a single pulse.
    /// Twice the pair's travel. The middle gem hangs alone with nothing beside
    /// it to read against, so the same distance the outer two share reads as
    /// almost still on it.
    static let virgoGemFloat: CGFloat = 6
    static let virgoGemFloatPeriod: TimeInterval = 2.3

    /// How much bigger a gem is at the bottom of its fall.
    ///
    /// Dropping and growing together is the plainest way to say a thing is
    /// coming *toward* the viewer rather than sliding down a wall — the same
    /// reading the board's rows get for free from the perspective, which a gem
    /// hanging in front of everything cannot use.
    static let virgoGemFloatGrowth: CGFloat = 0.18

    static let facingArrowLift: CGFloat = 4

    /// Added on Astra, where the ground is spread further apart vertically.
    static let facingArrowAstraLift: CGFloat = 2

    /// Pulled back at the **far** row, in art pixels, ramped to nothing at the
    /// near one.
    ///
    /// Negative because the squared correction below slightly overshoots. It is
    /// a depth term rather than a smaller `facingArrowLift` so the near row,
    /// which is already right, is left alone.
    static let facingArrowDepthLift: CGFloat = -6

    /// The row correction goes as the **square** of the row's scale.
    ///
    /// Found by measuring, and it says which quantity actually matters: a row's
    /// scale falls as `1/w`, but the *gap* between rows falls as `1/w²`, and the
    /// arrow's lift has to clear the gap rather than match the scale. Cancelling
    /// with the scale could never hold front-to-back, which is exactly how it
    /// behaved — and is why it wanted a different number on every row.
    static let facingArrowRowPower: CGFloat = 2

    /// Edge length of one cell of the direction guide, in art pixels.
    static let compassPixelSize = 48

    /// How big it is drawn, in board tiles.
    ///
    /// The art is 48px against a 16px tile, so its *native* size is three tiles
    /// — nearly half the width of the board, which is what it came out as. A
    /// compass is a label in the corner, not a feature of the world.
    ///
    /// One and a half tiles is a clean 24px, so the sampling still lands on
    /// whole art pixels at the usual board scales rather than smearing the
    /// letters.
    static let compassSpan: CGFloat = 1.5

    /// How far it is inset from the board's bottom-left corner, in tiles.
    ///
    /// Scaled with the compass rather than left where it was. The inset was set
    /// against a rose three tiles across; halving the rose and keeping the gap
    /// leaves it stranded off the corner it is supposed to sit in — padding
    /// belongs to the thing it surrounds, not to the board.
    static let compassInset: CGFloat = -0.5

    /// How far the compass fades when the piece is standing on its square.
    static let compassFaded: Double = 0.5

    /// How long the Gavel's slab takes to drop the last of the way in, and how
    /// long its squares stay outlined afterwards.
    static let slabDropDuration: TimeInterval = 0.18
    static let slabFlashDuration: TimeInterval = 0.28

    /// How heavy the outline on a freshly placed slab is.
    static let slabOutline: CGFloat = 2

    /// How far it steps between its two positions, in art pixels.
    ///
    /// Three. Eight was the lift's number reused without thinking, and at eight
    /// the arrow travels half a tile — which stops being a marker breathing and
    /// becomes a marker pacing about.
    static let facingArrowNudge: CGFloat = 2

    /// How long each of the two positions is held.
    ///
    /// Slow. It is a pulse on something that sits on screen every turn of the
    /// game, and anything quick enough to notice is something you end up
    /// noticing constantly. Higher value is slower.
    static let facingArrowBeat: TimeInterval = 0.5

    /// How long it takes to swing round to a new facing.
    static let facingArrowTurn: TimeInterval = 0.15

    static let slidePressLinger: TimeInterval = 0.2

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

    /// How far the board is dimmed while it waits on an answer. See
    /// `BoardView.choiceDim`.
    static let choiceDim: Double = 0.34

    /// How many squares a hop must cover to count as a leap worth drawing —
    /// Sagittarius' full bound rather than any long step.
    /// How far a move has to carry to count as a *bound* and throw its strip.
    ///
    /// Two, not three. The archer's leap is two squares and it had no fire on it
    /// at all — the test was written when the only bound in the game was the
    /// three-square shot, and a leap that clears a hole in silence looks like a
    /// step that teleported.
    static let longJumpDistance = 2

    // ──────────────────────────────────────────────────────────────────────
    // MARK: - Big leaps
    //
    // Taurus' Flowering Flop and Pisces' dive. See `HopPose.leap(progress:)`.

    /// How far off the board a deliberate leap carries, in art pixels.
    ///
    /// Far higher than a hop's arc. The point is that the piece leaves — a leap
    /// that clears the same height as a step is a step.
    static let leapHeight: CGFloat = 30

    /// The crouch before it.
    static let leapSquashX: CGFloat = 1.25
    static let leapSquashY: CGFloat = 0.75

    /// How much bigger it gets at the top, which reads as *nearer*.
    static let leapRiseScale: CGFloat = 1.5

    /// And how flat it lands. Twice as wide as it stands.
    static let leapPancakeX: CGFloat = 2.0
    static let leapPancakeY: CGFloat = 0.45

    /// How long the whole thing takes.
    static let leapDuration: TimeInterval = 0.62

    /// How much of a vault is the crouch before it, and how long the climb
    /// off-screen takes.
    static let vaultCrouchFraction: Double = 0.35
    static let vaultLaunchDuration: TimeInterval = 0.3

    /// How long the board shudders under one of Taurus' Astra steps.
    ///
    /// Short — a fraction of the landing shake. Every step does it, and anything
    /// longer would be a board that never stops moving.
    static let taurusStepShake: TimeInterval = 0.12

    /// How hard, against a landing's knock.
    static let taurusStepShakeStrength: CGFloat = 0.3

    // ──────────────────────────────────────────────────────────────────────
    // MARK: - Leo's retinue
    //
    // The phantoms Attracting Aten calls. See `RetinueView`.

    /// How solid a phantom is. Present, but plainly not the piece.
    static let retinueOpacity: Double = 0.65

    /// How solid a follower's own facing arrow is.
    ///
    /// Half. It has to be readable — a borrowed move is aimed by that facing —
    /// without competing with the lion's, which is the one the player is
    /// actually steering.
    static let retinueArrowOpacity: Double = 0.5

    /// How far behind the piece each one trails, in art pixels, and how hard it
    /// glows in its element.
    static let retinueTrail: CGFloat = 5
    static let retinueGlowRadius: CGFloat = 2.5

    /// How much slower a phantom's spring is than the piece's.
    ///
    /// The lag is the whole illusion: nothing computes a follow path, the
    /// phantom is simply told to be where the piece is and takes longer getting
    /// there.
    static let retinueLag: Double = 1.9

    /// How much further behind each phantom is than the one in front.
    /// How long after Leo each phantom takes its own hop.
    ///
    /// One beat per place in the line, so the second follower goes after the
    /// first. Short: long enough to read as separate jumps, brief enough that
    /// the line is not still arriving when you have made your next move.
    /// Long enough to be a separate jump.
    ///
    /// At an eighth of a second the two hops overlapped so heavily that they
    /// read as one animation with a soft edge. The gap wants to be visible: Leo
    /// lands, and *then* the phantom goes.
    static let retinueBeat: TimeInterval = 0.14

    /// The shadow under a phantom, and how far below it sits.
    /// How far a shadowed figure is lifted back up after being multiplied down.
    ///
    /// Shared by Leo's phantoms and Shadow Work's double, because they are the
    /// same treatment and should not drift apart.
    static let shadowRampUp: Double = 0.18

    /// How solid the phantom island under Shadow Work's double looks.
    ///
    /// Faint: it is not ground anybody can use, and a player who tried to stand
    /// on it because it looked real would rightly be annoyed.
    static let shadowNexysOpacity: Double = 0.5

    static let retinueShadowOpacity: Double = 0.35
    static let retinueShadowDrop: CGFloat = 0.08

    /// Its bob over a hole, where there is nothing to stand on.
    static let retinueFloatPeriod: TimeInterval = 1.6
    static let retinueFloatAmount: CGFloat = 3

    /// How much meter comes back when a phantom is lost to a change of plane.
    ///
    /// **Zero**, for now, and deliberately a number rather than nothing: losing
    /// a whole meter to a fall you did not choose is the sort of thing that
    /// reads as unfair on the twentieth run and fine on the first, and the
    /// answer is a playtest rather than an argument. Half a meter is the obvious
    /// alternative if it bites.
    static let retinueRefund = 0

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

    /// How bright a pixel must be before it contributes to a glow, `0`…`1`.
    ///
    /// Low enough that mid-tones tint the bloom, high enough that a sprite's
    /// shadows do not smear a grey halo around it. One number for the whole
    /// game: "which of my colours are the light ones" is not a question each
    /// sprite should answer separately, and that was the old arrangement — it
    /// produced a steady trickle of glows in the wrong hue, and glows that did
    /// not appear at all because the list named a colour the art did not use.
    static let glowLuminanceThreshold: Double = 0.45

    // ── The Fracturing Fissure's screen effect ────────────────────────────

    /// How far the world ripples while Gemini is split, in **art pixels**.
    ///
    /// Small on purpose. The shader rounds to whole pixels, so at this setting
    /// the board sits still most of the time and steps a pixel at the crests —
    /// which is the difference between a world that is unstable and a world that
    /// is underwater. See `fractureWarp`.
    static let fractureWarpAmplitude: Double = 1.6

    /// How long the ripple takes to arrive and to leave, in seconds.
    ///
    /// Long enough to be a transition rather than a toggle: coming apart is the
    /// most dramatic thing this sign does and it should take a beat.
    static let fractureRampDuration: TimeInterval = 0.5

    /// How bright a pixel has to be to feed the split's haze.
    ///
    /// Lower than the house threshold, because this bloom is not picking out
    /// highlights on one sprite — it is lifting a whole board slightly off its
    /// own background, and that wants more of the picture contributing.
    static let fractureBloomThreshold: Double = 0.3

    /// How far the haze spreads, in points, and how strong it is.
    ///
    /// Wide and faint. Every copy of an additive bloom adds to every other one
    /// and to the board behind it, so spread over a whole screen this needs a
    /// fraction of the strength a single piece's glow uses.
    static let fractureBloomRadius: CGFloat = 12
    static let fractureBloomIntensity: Double = 0.3

    /// For strips that have to read as an event rather than as decoration.
    ///
    /// Above the fire default. These are things the player has to *notice* —
    /// where the arrow landed, which square is humming, which line just levelled
    /// — competing against a board that is always moving slightly.
    static let effectGlowStrongIntensity: Double = 1.35

    /// How far an on-the-ground effect rides up so its base sits on the tile
    /// rather than its middle. In art pixels.
    static let effectGroundLift: CGFloat = 8

    static let elementalBurstDuration: TimeInterval = 0.75

    // ──────────────────────────────────────────────────────────────────────
    // MARK: - Screen shake
    //
    // The jolt of a heavy landing.

    /// Seconds the shove for a rejected swipe takes, out and back.
    static let blockedNudgeDuration: TimeInterval = 0.22

    /// How far that shove travels, in points.
    static let blockedNudgeDistance: CGFloat = 6

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
