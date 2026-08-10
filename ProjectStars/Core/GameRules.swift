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

    // MARK: - Board

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

    // MARK: - Landing

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

    // MARK: - Sparkles & pickups
    //
    // The cycle has exactly two states and no timers:
    //
    //   sparkle phase — five tiles shimmer, no pickup is visible
    //        ↓ the player commits a move
    //   pickup phase  — the sparkles vanish and the pickup appears on one of
    //                   the tiles they occupied, before the piece lands
    //        ↓ the player collects it
    //   sparkle phase — a new set rolls immediately

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

    /// Scale the smoke sprite is drawn at, relative to its natural two cells.
    static let smokeSpriteScale: CGFloat = 0.75

    /// Above this magnitude the drawn scatter is used instead of the sprite.
    ///
    /// The sprite is one fixed puff — right for a footfall, too small and too
    /// tidy for a body hitting the ground after falling a whole plane. Heavy
    /// landings keep the procedural scatter, which can be thrown as wide as it
    /// needs to be.
    static let smokeSpriteMaxMagnitude: CGFloat = 1.2

    /// Size multiplier for the puff thrown up by taking a Pentacle.
    static let smokeCollectMagnitude: CGFloat = 1.5

    /// Seconds a pillar of light lasts at each end of a warp.
    static let warpBeamDuration: TimeInterval = 0.30

    /// How far past the tile the pillar reaches, as a multiple of a cell.
    static let warpBeamHeight: CGFloat = 3.2

    // MARK: Spectral heads

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

    /// Motes riding each pillar of light.
    static let warpSparkCount = 9

    /// Seconds the burst of sparkles from an opened Pentacle lasts.
    static let collectBurstDuration: TimeInterval = 0.55

    /// How many sparkles fly out of an opened Pentacle.
    static let collectBurstCount = 10

    /// How far they travel, in art pixels.
    static let collectBurstSpread: CGFloat = 16

    /// When `true`, changing plane discards a pickup stranded on the plane the
    /// piece just left and starts a fresh sparkle phase on the new one.
    ///
    /// Without this a fall would leave the pickup somewhere the piece may not
    /// be able to return to, breaking the guarantee that one is always
    /// available.
    static let relocatePickupOnPlaneChange = true

    // MARK: - Zodiactions

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

    // MARK: - Pentacle effects
    //
    // - TODO: All untuned placeholders pending balancing.

    /// Charge granted by the Z-Charge Pentacle.
    static let zChargePentacleAmount = 3

    /// Charge granted by Restore Tile when there is nothing left to repair.
    static let restoreTileBonusCharge = 1

    /// Charge Astral Blaze pays per tile it wears.
    static let astralBlazeChargePerDamage = 1

    /// Charge Astral Blaze pays per tile it breaks outright. Worth more than
    /// mere damage, so the effect scales with how ruined the board already is.
    static let astralBlazeChargePerBreak = 2

    // MARK: - Scoring

    /// Points awarded per successful move.
    static let scorePerMove = 1

    /// Points awarded per pickup collected.
    static let scorePerPickup = 10

    // MARK: - Input

    /// Extra drag length, in points, that selects each successive distance for
    /// signs whose movement offers more than one.
    ///
    /// Deliberately generous: mistaking a two-square vault for a one-square step
    /// is a much worse error than having to drag a little further.
    static let swipeReachStep: CGFloat = 46

    /// Minimum drag length, in points, before a swipe counts as a move.
    static let minimumSwipeDistance: CGFloat = 24

    // MARK: - Pixel-art layout
    //
    // All distances are in **art pixels**, not points — views multiply by
    // `PixelArtMetrics.scale`. Every number here is a knob; none of them is a
    // rule.

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

    /// Spring response for a tile popping up and dropping back. Lower is
    /// snappier — a tile is stone, it should not wallow.
    static let tilePopResponse: Double = 0.14

    /// A Pentacle is drawn 48x48 — coin in the middle cell, sparkle ring
    /// spilling a full cell in every direction — then halved.
    ///
    /// Three cells at half scale is 1.5, so the coin itself lands at half a tile.
    /// Halving happens by shrinking the frame, not by resampling: `PixelSprite`
    /// draws with nearest-neighbour and no antialiasing, so the art stays hard-
    /// edged rather than turning to mush.
    static let pentacleCellSpan: CGFloat = 1.5

    /// How far the coin's shadow sits below the tile centre, in art pixels.
    /// Negative is up.
    static let pentacleShadowDrop: CGFloat = 0

    /// How far the coin itself floats above its shadow, in art pixels.
    static let pentacleLift: CGFloat = 8

    /// Opacity of the pool of light under the coin, at its brightest.
    static let pentacleShadowOpacity: Double = 0.3

    /// How far the coin's glow orbits the tile centre, in art pixels.
    ///
    /// The coin circles as it hovers; its light circles with it. Zero pins the
    /// pool to the centre.
    static let pentacleOrbitRadius: CGFloat = 2.5

    /// Seconds for one full orbit.
    static let pentacleOrbitPeriod: TimeInterval = 3.1

    /// How much smaller the pool gets at the top of the coin's float, as a
    /// fraction of its resting size. Shrinking as the coin rises is what sells
    /// the height rather than a flat drift.
    static let pentacleShadowScaleSwing: CGFloat = 0.3

    /// How far a Pentacle drifts either side of its resting height.
    static let pentacleFloatAmplitude: CGFloat = 1.5

    /// Seconds for one full up-and-down of a Pentacle.
    static let pentacleFloatPeriod: TimeInterval = 1.6

    // MARK: Hop

    /// Peak height of a hop's arc, above the straight line between squares.
    static let hopArcHeight: CGFloat = 6

    /// Widest and flattest the piece gets, winding up and on impact.
    static let hopSquashX: CGFloat = 1.28
    static let hopSquashY: CGFloat = 0.76

    /// Tallest and thinnest the piece gets, at the top of the arc.
    static let hopStretchX: CGFloat = 0.80
    static let hopStretchY: CGFloat = 1.24

    // MARK: Smoke

    /// Puffs kicked up by a landing.
    static let smokePuffCount = 7

    // MARK: - Sprite frame rates
    //
    // One rate per animation, chosen from `SpriteRate`. That type lists what
    // each rate suits and flags the two that do not divide the display clock
    // evenly.

    /// The clock every rate is measured against.
    static let spriteFramesPerSecond = 60

    /// What an animation runs at when it has not asked for a rate.
    static let defaultSpriteRate = SpriteRate.fps12

    /// Landing dust. Matches the GameMaker build.
    static let smokeRate = SpriteRate.fps12

    /// The Pentacle coin's glint.
    static let pentacleRate = SpriteRate.fps12

    /// Frames in a landing puff's sheet.
    static let smokeFrameCount = 5

    /// Seconds a puff takes to play through.
    ///
    /// Derived from the rate rather than set independently, so the sprite and
    /// the scatter that stands in for it always last exactly as long.
    static var smokeDuration: TimeInterval {
        smokeRate.duration(frames: smokeFrameCount)
    }

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

    /// Size multiplier for the cloud thrown up by landing after a fall, as
    /// against an ordinary hop.
    static let smokeFallMagnitude: CGFloat = 2.1

    /// How far a puff drifts from the landing point, in art pixels.
    static let smokeSpread: CGFloat = 9

    /// Diameter of a puff at its largest, in art pixels.
    static let smokePuffSize: CGFloat = 4

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

    /// Extra lift applied to a piece on top of resting its 16x32 box on the
    /// tile. Positive is up.
    static let pieceLift: CGFloat = 1

    /// Nudge applied to sparkles so they sit dead centre in their square.
    ///
    /// **In points, not art pixels** — the sparkle is drawn rather than
    /// sprited, so it has no pixel grid to align to.
    static let sparkleNudge = CGSize(width: 2, height: 0)

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

    /// How far the cursor sits above the centre of the square it marks.
    static let cursorLift: CGFloat = 2

    // MARK: - Backdrops

    /// Stars twinkling behind Astra.
    static let astraStarCount = 60

    /// Clouds drifting behind Terra.
    static let terraCloudCount = 7

    // MARK: - Animation timing (seconds)
    //
    // Presentation only. See the note at the top of this file: none of these
    // gate a rule.

    /// The pickup appearing and the sparkles vanishing.
    ///
    /// Zero because both happen *as the piece starts moving* — they are one
    /// beat with the hop, not a step before it.
    static let pickupRevealDuration: TimeInterval = 0

    /// A single hop between tiles.
    static let hopDuration: TimeInterval = 0.20

    /// A drop from Astra down to Terra.
    static let fallDuration: TimeInterval = 0.72

    /// How long an elemental burst plays for. Purely cosmetic; the rule it
    /// illustrates has already resolved.
    static let elementalBurstDuration: TimeInterval = 0.75

    /// A whole area changing state at once. Longer than a single tile, because
    /// there is more to read.
    static let areaEffectDuration: TimeInterval = 0.42

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

    /// Beat held after collecting a pickup, before new sparkles appear.
    static let pickupCollectDuration: TimeInterval = 0.20

    /// A teleport: the piece vanishing and reappearing elsewhere.
    static let teleportDuration: TimeInterval = 0.28

    /// The piece transforming into another sign.
    static let pieceChangeDuration: TimeInterval = 0.40

    /// A whole plane repairing itself behind a descending player.
    static let planeRestoreDuration: TimeInterval = 0.30

    /// Seconds the piece takes to fall in from off-screen onto the lower plane.
    static let fallArrivalDuration: TimeInterval = 0.42

    /// How far above the board the piece starts its arrival, as a multiple of
    /// the board's own height. Above 1 it begins genuinely off-screen.
    static let fallArrivalHeight: CGFloat = 1.15

    /// How small the destination tile's shadow starts, before the piece nears
    /// it. Growing this shadow is what telegraphs the incoming landing.
    static let fallArrivalShadowMin: CGFloat = 0.15

    /// How far the piece spins as it drops between planes.
    ///
    /// Negative is counter-clockwise. Applied as a running total rather than a
    /// target angle, so the spin always turns the same way instead of unwinding
    /// on the way back.
    static let fallSpinDegrees: Double = -1080

    // MARK: Ascent

    /// Seconds the island takes to carry the piece up out of Terra.
    static let ascentRiseDuration: TimeInterval = 0.55

    /// Seconds the island and piece take to swell back in on Astra.
    static let ascentGrowDuration: TimeInterval = 0.40

    /// How far above the board the pair travel before the plane swaps, as a
    /// multiple of the board's height. Above 1 they leave the screen entirely.
    static let ascentRiseHeight: CGFloat = 1.2

    /// Peak whiteout at the moment the planes swap. Zero disables the flash.
    static let ascentFlashOpacity: Double = 0.55

    // MARK: Nexys travel
    //
    // The island moving *without* a passenger — the Nexys Shift Pentacle, and
    // the debug key. Distinct from an ascent, which the player rides.

    /// Seconds the island takes to leave a plane.
    static let nexysTravelDepartDuration: TimeInterval = 0.34

    /// Seconds it takes to swell back in on the other plane.
    static let nexysTravelArriveDuration: TimeInterval = 0.34

    /// How far the island drifts as it leaves, as a fraction of the board's
    /// height. Small — it shrinks away rather than flying off.
    static let nexysTravelDrift: CGFloat = 0.18

    // MARK: Screen shake

    /// Seconds a shake takes to die away.
    static let shakeDuration: TimeInterval = 0.38

    /// Peak displacement of a shake, in art pixels.
    static let shakeAmplitude: CGFloat = 3

    /// Oscillations per second.
    static let shakeFrequency: Double = 17

    /// The Nexys island travelling between planes.
    static let nexysShiftDuration: TimeInterval = 0.40

    /// A Zodiaction firing.
    static let zodiactionDuration: TimeInterval = 0.35

    /// Pause before the game-over overlay appears.
    static let gameOverDelay: TimeInterval = 0.35
}
