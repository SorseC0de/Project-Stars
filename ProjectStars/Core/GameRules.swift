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
    // MARK: - Board
    //
    // The shape of the world. These change what the game *is*, not how it
    // feels.

    /// Edge length of each plane, in tiles.
    static let gridSize = 7

    /// Native pixel size of one tile's art. Drives integer sprite scaling.
    static let tilePixelSize = 16

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
    static let astraRestoresOnDescent = true

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
    // MARK: - Rules — Pentacle effects
    //
    // What individual Pentacles are worth. The effects themselves are in
    // Pickups/Effects/.

    /// Charge granted by the Z-Charge Pentacle.
    static let zChargePentacleAmount = 3

    /// Charge granted by Restore Tile when there is nothing left to repair.
    static let restoreTileBonusCharge = 1

    /// Charge Astral Blaze pays per tile it wears.
    static let astralBlazeChargePerDamage = 1

    /// Charge Astral Blaze pays per tile it breaks outright. Worth more than
    /// mere damage, so the effect scales with how ruined the board already is.
    static let astralBlazeChargePerBreak = 2

    // ──────────────────────────────────────────────────────────────────────
    // MARK: - Rules — scoring

    /// Points awarded per successful move.
    static let scorePerMove = 1

    /// Points awarded per pickup collected.
    static let scorePerPickup = 10

    // ──────────────────────────────────────────────────────────────────────
    // MARK: - Input
    //
    // How a drag becomes a move.

    /// Minimum drag length, in points, before a swipe counts as a move.
    static let minimumSwipeDistance: CGFloat = 24

    /// Extra drag length, in points, that selects each successive distance for
    /// signs whose movement offers more than one.
    ///
    /// Deliberately generous: mistaking a two-square vault for a one-square step
    /// is a much worse error than having to drag a little further.
    static let swipeReachStep: CGFloat = 46

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

    /// Seconds a cluster takes to disperse when its square becomes a hole.
    static let cloudPoofDuration: TimeInterval = 0.5

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
    static let sparkleNudge = CGSize(width: 2, height: 0)

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
    // MARK: - Spectral heads
    //
    // The apparition a Zodiaction summons.

    /// A Zodiaction firing.
    static let zodiactionDuration: TimeInterval = 0.35

    /// Seconds an apparition is on screen when a Zodiaction fires.
    static let spectralHeadDuration: TimeInterval = 1.15

    /// Size of the head, in cells.
    static let spectralHeadScale: CGFloat = 1.15

    /// How far above the piece it hangs, in cells, before it starts rising.
    ///
    /// Clear of the piece rather than over it: the piece is a two-cell sprite,
    /// so anything under about two cells of lift lands on its head.
    static let spectralHeadRise: CGFloat = 2.3

    /// Radians per second it turns.
    static let spectralHeadSpin: Float = 1.6

    /// Tilt, so it is seen slightly from below — looming rather than level.
    static let spectralHeadPitch: Float = -0.22

    /// Peak opacity. It is a ghost, not a model.
    static let spectralHeadOpacity: Double = 0.72

    // ──────────────────────────────────────────────────────────────────────
    // MARK: - Elemental bursts
    //
    // The Metal-shaded flourish an Astral Essence plays.

    /// How long an elemental burst plays for. Purely cosmetic; the rule it
    /// illustrates has already resolved.
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
