//
//  GameSession.swift
//  Project Stars
//
//  The bridge between the pure engine and SwiftUI.
//

import Observation
import SwiftUI

/// The observable object the views read from.
///
/// Owns a `GameEngine` and drives it. Its one real job is *replay*: when the
/// player swipes, the engine plans the whole move up front, and this class
/// applies those events one at a time with animation between them. All game
/// rules stay in the engine; everything here is pacing and presentation state.
///
/// - Important: The delays here are the only clocks in the project, and they
///   pace a move that has *already been fully decided*. The game itself is
///   move-based — no rule fires on a timer.
@MainActor
@Observable
final class GameSession {

    // MARK: - Game state

    /// The authoritative state. Views read it; only this class mutates it.
    private(set) var engine: GameEngine

    // MARK: Meter, mirrored
    //
    // The engine is the authority; these are what the panel reads.
    //
    // Views used to reach through `session.engine.zodiactionMeter`, and the
    // button did not always notice a change — a debug fill left it showing the
    // old state until the next move. Mirroring the three facts onto the session
    // and refreshing them wherever the engine is touched removes the question:
    // there is one place charge is published, so there is one place it can be
    // wrong.

    private(set) var zodiactionMeter = 0
    private(set) var zodiactionMeterMax = GameRules.defaultZodiactionMeterMax
    private(set) var isZodiactionReady = false

    /// Republishes anything derived from the engine.
    ///
    /// Called after every applied event. Cheap, and it cannot go stale.
    private func publish() {
        zodiactionMeter = engine.zodiactionMeter
        zodiactionMeterMax = engine.zodiactionMeterMax
        // Held steady while a move plays out.
        //
        // Readiness is a live question — several signs ask where the piece is
        // standing and which way it is facing before answering — so recomputing
        // it on every event of a move made the button strobe between grey and
        // gold as the piece travelled. It is a statement about the *next* turn,
        // and the next turn has not begun until this one stops.
        if phase != .resolvingMove {
            isZodiactionReady = engine.isZodiactionReady
        }
        purse = engine.signState.purse
    }

    /// What Capricorn has banked, oldest first. Empty for every other sign.
    private(set) var purse: [PickupID] = []

    /// A coin on its way from its tile down to the shop strip.
    ///
    /// One at a time: only one Pentacle is ever open at once, so there is never
    /// a second arc to draw.
    private(set) var bankArc: BankArc?

    /// A banked coin in flight. See `BankArcView`.
    struct BankArc: Equatable {
        let id: PickupID
        let from: GridPoint
        let plane: Plane
        let start: Date
    }

    /// What the session is currently doing.
    private(set) var phase: GamePhase = .awaitingInput

    /// Which sign the current run started with. Kept so "play again" can reuse
    /// it, and so pickups that swap the piece can be added later without losing
    /// the original choice.
    private(set) var startingZodiac: Zodiac

    // MARK: - Presentation state
    //
    // Transient flags the views animate on. None of this affects the rules.

    /// Bumped every time the piece completes a hop.
    ///
    /// Drives the squash-and-stretch and the puff of smoke on landing. A counter
    /// rather than a flag because both are keyframed animations that need a
    /// *retrigger*, not a state to observe — two hops in a row have to play
    /// twice, not merge into one.
    private(set) var hopCount: Int = 0

    /// Running total of the piece's fall rotation, in degrees.
    ///
    /// Only ever decreases, so the spin always turns counter-clockwise instead
    /// of unwinding back the way it came at the halfway point.
    private(set) var fallSpin: Double = 0

    /// Multiplier on the next smoke burst. Landing after a fall throws up much
    /// more than an ordinary hop.
    private(set) var smokeMagnitude: CGFloat = 1

    /// When the current screen shake began, or `nil` for none.
    private(set) var shakeStartedAt: Date?

    /// How hard the current shake is, against the usual amplitude.
    private(set) var shakeStrength: CGFloat = 1

    /// The slab's squares while they light up on arrival.
    private(set) var slabLanding: SlabLanding?

    /// One slab settling into the board.
    struct SlabLanding: Equatable {
        let points: Set<GridPoint>
        let plane: Plane
        let start: Date
    }

    /// Set when a slab placement is confirmed, so the `tilesChanged` it causes
    /// can be told apart from every other one.
    private var placedSlab: GavelSlab?

    /// When the piece began falling in onto the lower plane, or `nil` when it is
    /// not arriving. Drives the drop from off-screen and the growing shadow.
    private(set) var fallArrivalStartedAt: Date?

    /// When the island began carrying the piece up out of Terra, or `nil`.
    private(set) var ascentRiseStartedAt: Date?

    /// When the pair began swelling back in on Astra, or `nil`.
    private(set) var ascentGrowStartedAt: Date?

    /// Whiteout at the moment the planes swap, `0`…`1`.
    private(set) var ascentFlash: Double = 0

    /// When the island began leaving a plane on its own, or `nil`.
    private(set) var nexysDepartStartedAt: Date?

    /// When it began swelling back in on the other plane, or `nil`.
    private(set) var nexysArriveStartedAt: Date?

    /// Whether the island's current journey is upward. Decides which way it
    /// drifts as it shrinks away.
    private(set) var nexysTravellingUp = false

    /// How many squares the current hop covers. Scales its arc.
    private(set) var hopDistance: Int = 1

    /// When the current hop began, for evaluating `HopPose`.
    ///
    /// A timestamp rather than an animation, so the pose is a pure function of
    /// elapsed time and can never be left stuck part-way through.
    private(set) var hopStartedAt: Date?

    /// Bumped whenever an illegal swipe is rejected, so the board can nudge.
    private(set) var blockedNudge: Int = 0

    /// The direction of the most recent rejected swipe, for the nudge offset.
    private(set) var blockedDirection: SwipeDirection?

    /// Set while the piece is mid-drop between planes; the piece view shrinks
    /// and fades on this.
    private(set) var isFalling = false

    /// Set while the Nexys island is travelling between planes.
    private(set) var isNexysShifting = false

    /// The pickup most recently collected, shown briefly in the info panel.
    private(set) var lastCollectedPickup: PickupID?

    /// Bumped when a Zodiaction fires, so the UI can flash.
    private(set) var zodiactionFlash: Int = 0

    /// Tiles that changed this move, used to flash them. Cleared as the replay
    /// moves on.
    private(set) var flashingTiles: Set<GridPoint> = []

    /// The Pentacle effect currently being explained, if any.
    ///
    /// While this is non-nil the replay is **suspended mid-move** — see
    /// `introducePentacle(_:)`.
    private(set) var pentacleIntro: PickupID?

    /// The Pentacle just opened, named so the player always knows what they got.
    ///
    /// The first-encounter splash explains an effect once; this is the standing
    /// answer to "what did I just pick up" on every later one. Cleared when the
    /// next move is committed rather than on a timer, so it is still there
    /// whenever the player looks up.
    private(set) var pentacleBanner: PickupID?

    /// The elemental burst currently playing, if any. Presentation only.
    private(set) var elementalBurst: ElementalBurst?

    /// Drawn effect strips currently playing. See `EffectSprite`.
    ///
    /// A list rather than one at a time: Aries' Brazen Blaze burns every tile it
    /// leaves, and a two-square exit lights two of them on the same beat.
    private(set) var effectBursts: [EffectBurst] = []

    /// The square something has just landed on, so the surface can give under
    /// it. See `GameRules.surfaceBounceDepth`.
    private(set) var surfaceBounce: SurfaceBounce?

    /// One landing.
    struct SurfaceBounce: Equatable {
        let point: GridPoint
        let plane: Plane
        let start: Date
    }

    /// Bounces the surface once the hop currently in flight has landed.
    ///
    /// A hop is drawn as an arc over `hopDuration`, and the piece is in the air
    /// for all of it. Bouncing the ground at the moment the move is *planned*
    /// would have the cloud give way before anything touched it.
    /// - Parameter after: An extra wait, for the followers who jump late.
    private func landAfterHop(at point: GridPoint, on plane: Plane, after delay: TimeInterval = 0) {
        Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(
                nanoseconds: UInt64((self.hopDuration + delay) * 1_000_000_000)
            )
            self.bounceSurface(at: point, on: plane)
        }
    }

    /// Presses the surface at `point` down and lets it spring back.
    func bounceSurface(at point: GridPoint, on plane: Plane) {
        // Cloud and the island give; stone does not.
        guard plane == .astra || engine[plane][point].kind == .nexys else { return }

        let bounce = SurfaceBounce(point: point, plane: plane, start: .now)
        surfaceBounce = bounce

        Task { [weak self] in
            try? await Task.sleep(
                nanoseconds: UInt64(GameRules.surfaceBounceDuration * 1_000_000_000)
            )
            guard self?.surfaceBounce == bounce else { return }
            self?.surfaceBounce = nil
        }
    }

    /// The square something has just dropped through or risen out of, so the
    /// clouds around it can be pushed aside. See `CloudSpriteField`.
    private(set) var cloudWake: CloudWake?

    /// One disturbance in the sky.
    struct CloudWake: Equatable {
        let point: GridPoint
        let start: Date
    }

    /// Shoves the sky around `point`.
    private func disturbClouds(at point: GridPoint) {
        let wake = CloudWake(point: point, start: .now)
        cloudWake = wake

        Task { [weak self] in
            try? await Task.sleep(
                nanoseconds: UInt64(GameRules.cloudWakeDuration * 1_000_000_000)
            )
            guard self?.cloudWake == wake else { return }
            self?.cloudWake = nil
        }
    }

    /// Squares the piece is passing over right now, pressed down under it.
    ///
    /// Only a slide fills this. A slide crosses ground without landing on it —
    /// no wear, no dust, no landing checks — which left it looking like the
    /// piece was gliding over a photograph. The tiles giving slightly as it goes
    /// is the cheapest way to say *something is moving across this board*
    /// without claiming any of the consequences a landing would.
    private(set) var pressedTiles: Set<GridPoint> = []

    /// True while a slide is in progress.
    ///
    /// The coin sorts in front of the piece while this holds — a Pentacle the
    /// slide is about to sweep up should pass over the piece's head, not behind
    /// it, or it reads as having been missed.
    private(set) var isSliding = false

    /// When a deliberate leap began, or `nil` when none is playing.
    ///
    /// Taurus' Flowering Flop and Pisces' dive. Distinct from `hopStartedAt`
    /// because it is a different pose entirely — see `HopPose.leap(progress:)`.
    /// The movement currently playing out, if any.
    ///
    /// One clock for every kind, rather than a flag per kind. It began as
    /// `hopStartedAt`, gained `leapStartedAt` beside it when leaps arrived, and
    /// would have gained a third for charges — each of them answering "is *my*
    /// sort of movement happening" when the question anything downstream
    /// actually asks is "what is happening, since when, and which way".
    ///
    /// Anything that wants to move with the piece — Libra's scales, the
    /// retinue's beat, a future sign's cape — reads this rather than being told
    /// about its own special case.
    private(set) var movement: Movement?

    /// One movement, from the moment it starts.
    struct Movement: Equatable {
        let style: MovementStyle
        let direction: SwipeDirection
        let start: Date
        let duration: TimeInterval

        /// How far through it is, `0`…`1`.
        func progress(at now: Date) -> Double {
            guard duration > 0 else { return 1 }
            return min(max(now.timeIntervalSince(start) / duration, 0), 1)
        }
    }

    /// Starts the clock for a movement of `style`.
    func beginMovement(_ style: MovementStyle, direction: SwipeDirection, duration: TimeInterval) {
        movement = Movement(
            style: style,
            direction: direction,
            start: .now,
            duration: duration
        )
    }

    /// And stops it.
    func endMovement() { movement = nil }

    private(set) var leapStartedAt: Date?

    /// True while the piece is climbing away off the top of the board.
    private(set) var isLaunching = false

    /// Throws the piece into the air and waits out the arc.
    func playLeap() async {
        leapStartedAt = .now
        beginMovement(
            .leap,
            direction: engine.piece.facing,
            duration: GameRules.leapDuration
        )
        defer { endMovement() }
        await sleep(GameRules.leapDuration)
        leapStartedAt = nil
    }

    /// True while Aries is mid-charge, so the piece burns for the length of the
    /// run rather than for a fixed number of turns afterwards.
    private(set) var isCharging = false

    /// A coin on its way in to the piece, if one is being reeled.
    private(set) var coinFlight: CoinFlight?

    /// One coin travelling to the piece.
    struct CoinFlight: Equatable {
        let id: PickupID
        let from: GridPoint
        let plane: Plane
        let start: Date
    }

    /// Sagittarius' arrow on its way up, if one has just been fired.
    private(set) var loosedArrow: LoosedArrow?

    /// One shot leaving the bow.
    struct LoosedArrow: Equatable {
        let point: GridPoint
        let plane: Plane
        let start: Date
    }

    /// Scorpio's tail, mid-strike. See `StingLanceView`.
    private(set) var stingStrike: StingStrike?

    /// One lunge of the tail.
    struct StingStrike: Equatable {
        let plane: Plane
        let from: GridPoint
        let direction: SwipeDirection
        let reach: Int
        let start: Date
    }

    /// Tiles currently shimmering from having been repaired. See
    /// `HealSparkleView`.
    private(set) var healSparkles: [HealSparkle] = []

    /// One mended square's shimmer.
    struct HealSparkle: Identifiable, Equatable {
        let id = UUID()
        let point: GridPoint
        let plane: Plane
        let start: Date
    }

    /// When the piece last gained charge, for the colour flash. `nil` when it
    /// is not flashing.
    private(set) var chargeFlashStartedAt: Date?

    /// The square a seafoam scuttle started from, so its first bubble is only played
    /// once however many squares the walk covers. Cleared when the move commits.
    /// The cloud coming down with an arrow inside it, if one is falling.
    private(set) var fallingCloud: FallingCloud?

    /// One cloud on its way down out of Astra.
    struct FallingCloud: Identifiable, Equatable {
        let id = UUID()
        let point: GridPoint
        let plane: Plane
        let start: Date
    }

    /// Squares the piece has recently left, newest first.
    ///
    /// Real positions, not interpolated ones — see `AfterimageView` for why that
    /// is the whole difference between an afterimage and a smear.
    private(set) var afterimages: [Afterimage] = []

    /// True while something big enough to be watched is playing out.
    ///
    /// A multi-tile move is *one* turn, and a long sweep reads as several unless
    /// the board says otherwise — so for as long as one is resolving, the tiles
    /// dim and the ambient motion holds still. What is doing the moving stays
    /// lit: the piece, the coins, and the move's own effects.
    ///
    /// ## Why not simply `phase == .resolvingMove`
    ///
    /// Because an ordinary step is also a resolving move, and it lasts about a
    /// tenth of a second. Dimming for that put a flicker on the screen for every
    /// single turn of the game. The wash is meant to say *stop and watch this*,
    /// and something that happens on every step says nothing at all.
    private(set) var isResolvingAction = false

    /// When the ambient clock was stopped, or `nil` while it is running.
    private var ambientPausedAt: TimeInterval?

    /// How much time the ambient clock has spent stopped, in total.
    private var ambientLost: TimeInterval = 0

    /// The clock the ambient art runs on.
    ///
    /// Ambient art is a pure function of a timestamp, so freezing it means
    /// handing it a clock that has stopped rather than asking it to stop.
    ///
    /// ## Why it is paused rather than pinned
    ///
    /// Pinning it to the instant the freeze began works until it is released,
    /// at which point the art is handed the *wall* clock again and jumps
    /// forward by however long it was held. For an action that is a few frames;
    /// for a first-encounter splash, which waits on the player, it is however
    /// long they spent reading — and every cloud on the board visibly snapped
    /// to a new position the moment the splash went away.
    ///
    /// Subtracting the time spent stopped means the clock resumes exactly where
    /// it left off. Drift against the wall clock is the point, not a defect:
    /// nothing here is synchronised to anything outside the board.
    func ambientClock(at now: TimeInterval) -> TimeInterval {
        (ambientPausedAt ?? now) - ambientLost
    }

    /// Stops the ambient clock, if it is running.
    fileprivate func pauseAmbient(at now: TimeInterval) {
        guard ambientPausedAt == nil else { return }
        ambientPausedAt = now
    }

    /// Starts it again from where it stopped.
    fileprivate func resumeAmbient(at now: TimeInterval) {
        guard let paused = ambientPausedAt else { return }
        ambientLost += now - paused
        ambientPausedAt = nil
    }

    /// One square the piece was on, and when it left.
    struct Afterimage: Identifiable, Equatable {
        let id = UUID()
        let point: GridPoint
        let plane: Plane
        let born: Date
    }

    private var crabWalkOrigin: GridPoint?

    /// The strip owed to the tiles the Pentacle just opened is about to change.
    ///
    /// Set when the coin opens and spent on the `.tilesChanged` that follows it.
    /// A coin knows what it looks like; only its events know what it touched.
    private var pluming: EffectSprite?

    /// The strip a repair is owed, held until one happens. See `PickupShape`.
    private var mending: EffectSprite?

    /// Sparkles flying off a Pentacle that was just opened.
    private(set) var collectBurst: ElementalBurst?

    /// The element an afterimage should wear right now.
    ///
    /// The sign's own, except when something else is doing the moving. An Astral
    /// Brook is water carrying you — that is the whole picture — and a trail of
    /// fire behind a piece being swept along by a river describes the wrong
    /// event entirely.
    var trailElement: ZodiacElement {
        pluming == .waterSplash ? .water : zodiac.element
    }

    /// The dust currently settling, if any.
    private(set) var smoke: SmokePuff?

    /// Cloud squares currently coming apart.
    ///
    /// A list rather than one at a time: an area effect can take out several
    /// squares of Astra at once, and each has to disperse from its own cluster.
    private(set) var cloudPoofs: [CloudPoof] = []

    /// The pillar of light currently standing on the board, if any.
    private(set) var warpBeam: WarpBeam?

    /// The apparition summoned by a Zodiaction, if one is on screen.
    private(set) var constellation: ConstellationSummon?

    /// Whether the pause menu is up. Blocks all input while it is.
    private(set) var isPaused = false

    /// The direction of the drag in progress, or `nil` when none is.
    ///
    /// Feeds the cursor so it previews the move being aimed rather than the one
    /// last made — which matters most for the signs that offer several
    /// distances, where the drag's length is the choice.
    private(set) var previewDirection: SwipeDirection?

    /// How far the drag in progress has run, in distance-steps.
    private(set) var previewReach: Int = 0

    /// Record of which effects have already introduced themselves.
    let codex: PentacleCodex

    /// A Pentacle waiting on the player to answer something.
    ///
    /// While this is non-nil the move is **suspended mid-resolve**, exactly like
    /// a first-encounter strip — but here the answer changes the outcome rather
    /// than just the pacing.
    private(set) var pendingPickupChoice: (source: ChoiceSource, kind: PickupChoice)?

    /// The square being aimed at while a question about a square is open.
    ///
    /// Held here rather than inside the pad because two views need it: the pad
    /// is where it is *chosen*, and the board is where it is *shown*. A cursor
    /// that stayed on the movement projection while the player was picking a
    /// warp destination was pointing at the wrong question entirely.
    private(set) var targetAim: GridPoint?


    // MARK: - Lifecycle

    /// - Parameters:
    ///   - zodiac: The sign to control. Defaults to Aries.
    ///   - seed: Fixed seed for a reproducible run, or `nil` for a random one.
    ///   - codex: Pass a throwaway instance in tests so a run cannot mark the
    ///     real player's Pentacles as already seen. Defaults to the shared one.
    ///
    /// - Note: `codex` defaults to `nil` rather than to `.shared` directly.
    ///   `PentacleCodex.shared` is main-actor isolated, and a default argument
    ///   expression is evaluated in a nonisolated context — which is a warning
    ///   today and an error under the Swift 6 language mode. Resolving it inside
    ///   the (isolated) initialiser body sidesteps that.
    init(
        zodiac: Zodiac = .aries,
        seed: UInt64? = nil,
        codex: PentacleCodex? = nil
    ) {
        self.startingZodiac = zodiac
        self.engine = GameEngine(zodiac: zodiac, seed: seed)
        self.codex = codex ?? .shared
        publish()
    }

    /// Abandons the current run and starts a new one.
    func newGame(zodiac: Zodiac? = nil, seed: UInt64? = nil) {
        replayTask?.cancel()
        replayTask = nil

        let sign = zodiac ?? startingZodiac
        startingZodiac = sign
        engine = GameEngine(zodiac: sign, seed: seed)
        publish()

        phase = .awaitingInput
        isFalling = false
        isNexysShifting = false
        blockedDirection = nil
        balkStartedAt = nil
        balkDirection = nil
        hopCount = 0
        hopStartedAt = nil
        hopDistance = 1
        fallSpin = 0
        smokeMagnitude = 1
        shakeStartedAt = nil
        fallArrivalStartedAt = nil
        ascentRiseStartedAt = nil
        ascentGrowStartedAt = nil
        ascentFlash = 0
        nexysDepartStartedAt = nil
        nexysArriveStartedAt = nil
        lastCollectedPickup = nil
        pentacleBanner = nil
        elementalBurst = nil
        effectBursts = []
        healSparkles = []
        nexysCarryingPiece = false
        coinFlight = nil
        leapStartedAt = nil
        surfaceBounce = nil
        cloudWake = nil
        pressedTiles = []
        isSliding = false
        isCharging = false
        stingStrike = nil
        loosedArrow = nil
        pluming = nil
        crabWalkOrigin = nil
        afterimages = []
        fallingCloud = nil
        chargeFlashStartedAt = nil
        collectBurst = nil
        smoke = nil
        cloudPoofs = []
        warpBeam = nil
        constellation = nil
        isPaused = false
        flashingTiles = []

        // A pending splash belongs to the run that is being thrown away.
        resumeContinuation?.resume()
        resumeContinuation = nil
        pentacleIntro = nil

        // Same for an unanswered Pentacle: resume with anything, the events are
        // discarded along with the run.
        choiceContinuation?.resume(returning: .piece(sign))
        choiceContinuation = nil
        pendingPickupChoice = nil
    }

    // MARK: - Input

    /// Handles a committed swipe.
    ///
    /// Ignored unless the session is idle, so a fast second swipe cannot
    /// interleave with a move that is still animating.
    /// Updates the live preview from a drag in progress.
    func preview(direction: SwipeDirection?, reach: Int) {
        // A drag that has only just started counts too: the splash should be
        // gone by the time the stick has anything to say.
        if direction != nil { dismissIntroIfShowing() }

        previewDirection = direction
        previewReach = reach
    }

    /// - Parameter reach: Which of the distances available that way the drag
    ///   selected. Ignored by patterns offering only one.
    func submit(_ direction: SwipeDirection, reach: Int = 0) {
        // Reaching for the controls is how the splash is put away, and that
        // input is spent doing it.
        if dismissIntroIfShowing() { return }

        // While a question is open, movement steers the answer instead of the
        // piece. Same keys, same stick, same buttons — there is only ever one
        // thing on screen asking to be pointed at.
        if nudgeTarget(direction) { return }

        // `acceptsInput` rather than `phase` alone: it is the one place that
        // knows about pausing, first-encounter splashes and parked Pentacles, and
        // a second guard that only checked `phase` would quietly diverge from it.
        guard acceptsInput else { return }

        // Whatever the last Pentacle was, the player has moved on.
        pentacleBanner = nil

        previewDirection = nil
        previewReach = 0

        let events = engine.plan(direction, reach: reach)
        guard !events.isEmpty else { return }

        // A rejected swipe has nothing to animate — just nudge and stay idle.
        if events.count == 1, case let .moveBlocked(blocked) = events[0] {
            reportBlocked(blocked)
            return
        }

        run(events)
    }

    #if DEBUG
    /// Fills the Zodiaction meter. Debug builds only.
    ///
    /// Testing a Zodiaction otherwise means playing a full charge for every
    /// attempt, which makes tuning its animation impractical.
    func debugFillZodiaction() {
        guard acceptsInput else { return }
        let events = engine.planFillZodiaction()
        guard !events.isEmpty else { return }
        run(events)
    }

/// Fills the meter *and* pops it, in one keypress. Debug builds only.
    ///
    /// Popping normally means holding the input surface, which is the right
    /// gesture in play and a poor one for testing — every tweak to a Zodiaction's
    /// animation costs a charge and a hold.
    func debugPopZodiaction() {
        guard acceptsInput else { return }
        if engine.zodiactionMeter < engine.zodiactionMeterMax {
            for event in engine.planFillZodiaction() { engine.apply(event) }
        }
        fireZodiaction()
    }

    /// Becomes another sign where it stands, keeping the board as it is.
    ///
    /// Goes through the same `pieceChanged` event a Pentacle uses, so everything
    /// that follows from a swap — memory cleared, rifts left standing, the meter
    /// clamped to a new cap — happens exactly as it would in play.
    func debugSwapSign(to sign: Zodiac) {
        guard sign != engine.piece.zodiac else { return }
        engine.apply(.pieceChanged(to: sign))
        publish()
    }

    /// Cycles the control scheme. Debug builds only.
    ///
    /// Stands in for the selection screen, so both schemes can be felt on a
    /// device before either is committed to.
    func debugCycleControls() {
        let all = GameRules.ControlScheme.allCases
        let next = (all.firstIndex(of: GameRules.controlScheme) ?? 0) + 1
        GameRules.controlScheme = all[next % all.count]
        publish()
    }

    /// Stages the Astral Bolt as the next Pentacle. Debug builds only.
    ///
    /// Only the *next* one, and it does not disturb the coin already on the
    /// board — take that one, and the set that replaces it is the Bolt.
    func debugStageLightning() {
        engine.debugNextPickup = .astralBolt
    }

    /// Sends the Nexys to the other plane. Debug builds only.
    ///
    /// Goes through `GameEngine.planNexysShift()` rather than firing the event
    /// directly, so it behaves exactly like the Pentacle that does this —
    /// including dropping the piece when the island was the only thing holding
    /// it up, and rolling a fresh sparkle phase if that changes plane.
    func debugShiftNexys() {
        guard acceptsInput else { return }
        let events = engine.planNexysShift()
        guard !events.isEmpty else { return }
        run(events)
    }
    #endif

    /// Whether this change is a whole row or column being restored.
    ///
    /// Axial Adjudication mends complete lines and nothing else does, so the
    /// shape of the change is enough to recognise it — no marker on the event,
    /// and no way for the two to fall out of step later.
    private func isLevelledLine(_ changes: [GridPoint: TileHealth], on plane: Plane) -> Bool {
        let points = Set(changes.keys)
        guard points.count >= 2 else { return false }

        let size = engine[plane].size

        // A line is levelled when every ordinary square of some row or column is
        // in the set. Structural squares are skipped, exactly as the passive
        // skips them.
        return (0..<size).contains { index in
            let row = (0..<size).map { GridPoint($0, index) }
            let column = (0..<size).map { GridPoint(index, $0) }

            return [row, column].contains { line in
                let ground = line.filter { engine[plane][$0].kind == .normal }
                return !ground.isEmpty && ground.allSatisfy(points.contains)
            }
        }
    }

    /// The mirrored double, if one is on the board.
    var shadow: GameEngine.Shadow? { engine.shadow }

    /// The half of Gemini waiting its turn, if there is one.
    var otherHalf: Piece? { engine.otherHalf }

    /// True when Gemini is in two places.
    var isSplit: Bool { engine.isSplit }

    /// True when Libra's power is in play, as the piece or as a phantom.
    var hasLibra: Bool {
        zodiac == .libra || engine.signState.retinue.contains(.libra)
    }

    /// The phantoms currently following, oldest first.
    var retinue: [Zodiac] { engine.signState.retinue }

    /// Fires a phantom's Zodiaction. See `GameEngine.planRetinueZodiaction`.
    /// Whether a follower's button should read as pressable.
    func canFireRetinue(_ follower: Zodiac) -> Bool {
        engine.canFireRetinueZodiaction(follower)
    }

    func fireRetinueZodiaction(_ follower: Zodiac) {
        if dismissIntroIfShowing() { return }
        guard acceptsInput else { return }

        let events = engine.planRetinueZodiaction(follower)
        guard !events.isEmpty else { return }
        Haptics.zodiaction()
        run(events)
    }

    /// Whether the vault badge is shown at all, and whether it is lit.
    ///
    /// Shown for anyone who has the vault — which after Leo's rework can mean a
    /// phantom archer, so it asks the whole company rather than the piece.
    var showsVault: Bool {
        engine.activePassives.contains { $0 is SagittariusVulcanVault }
    }

    var canVault: Bool {
        acceptsInput && engine.longestReach(for: engine.piece.facing) > 0
    }

    /// Takes the full-length vault, the way the piece is already looking.
    func vaultForward() {
        if dismissIntroIfShowing() { return }
        guard canVault else { return }

        Haptics.longer()
        submit(engine.piece.facing, reach: engine.longestReach(for: engine.piece.facing))
    }

    /// Presses the elevator. See `GameEngine.planNexysCall`.
    func callNexys() {
        if dismissIntroIfShowing() { return }
        guard acceptsInput, engine.canCallNexys else { return }

        let events = engine.planNexysCall()
        guard !events.isEmpty else { return }
        Haptics.zodiaction()
        run(events)
    }

    /// Whether the lift is showing at all, and whether it will answer.
    var showsNexysCall: Bool {
        engine.activePassives.ridesNexysDown(context: engine.passiveSnapshot)
    }

    var canCallNexys: Bool { engine.canCallNexys }

    /// Which way the lift would go if it were pressed.
    var nexysCallDestination: Plane {
        engine.nexysPlane != engine.piece.plane
            ? engine.piece.plane
            : engine.piece.plane.opposite
    }

    /// One square the way the piece is already looking.
    ///
    /// The tap control. Reach zero, so a sign with a choice of distances takes
    /// its shortest — a tap carries no magnitude, and guessing that the player
    /// meant the long one is exactly the mistake the drag exists to avoid.
    func stepForward() {
        if dismissIntroIfShowing() { return }
        guard acceptsInput else { return }
        submit(engine.piece.facing, reach: 0)
    }

    /// Pops the current sign's Zodiaction, if it is charged.
    ///
    /// A Zodiaction is its own action rather than part of a move, so it has its
    /// own entry point — but it is planned and replayed exactly like a move, and
    /// it is refused while a move is still resolving.
    func fireZodiaction() {
        guard acceptsInput, engine.isZodiactionReady else { return }

        let events = engine.planZodiaction()
        guard !events.isEmpty else { return }

        zodiactionFlash += 1
        run(events)
    }

    // MARK: - Replay

    private var replayTask: Task<Void, Never>?

    /// Starts replaying a planned event list.
    private func run(_ events: [GameEvent]) {
        phase = .resolvingMove
        replayTask = Task { [weak self] in
            await self?.replay(events)
        }
    }

    /// Whether this plan is an *action* — something the player should be given a
    /// moment to watch — rather than an ordinary turn.
    ///
    /// A single hop from one square to the next is not. Anything that sweeps
    /// across the board, changes plane, fires a super, or rewrites ground is.
    /// Deliberately a question about what the events *are* rather than how long
    /// they take: a slow step is still a step.
    private static func isWorthWatching(_ events: [GameEvent]) -> Bool {
        var steps = 0

        for event in events {
            switch event {
            case .zodiactionFired, .pieceSlid, .pieceFell, .pieceTeleported,
                 .nexysMoved, .planeRestored, .tilesChanged, .pickupCollected,
                 .arrowPlanted, .stingStruck, .poolFormed, .pickupBanked:
                return true

            case .pieceStepped:
                // One hop is a step; several in a row are a charge.
                steps += 1
                if steps > 1 { return true }

            default:
                continue
            }
        }
        return false
    }

    /// Applies a plan to the engine one event at a time, animating each and
    /// waiting out its display duration before the next.
    private func replay(_ events: [GameEvent]) async {
        defer { publish() }

        // Judged from the plan rather than from the phase: an action is a thing
        // that travels or transforms, not merely a turn that is in progress.
        isResolvingAction = Self.isWorthWatching(events)
        defer { isResolvingAction = false }

        // The ambient art holds its pose for the same span, and only that span.
        if isResolvingAction {
            pauseAmbient(at: Date.now.timeIntervalSinceReferenceDate)
        }
        defer { resumeAmbient(at: Date.now.timeIntervalSinceReferenceDate) }
        // Anything lit for the duration of an action goes out with it, however
        // the action ended.
        defer { isCharging = false }
        defer { isSliding = false }

        // Per-move presentation bookkeeping, cleared before anything is drawn.
        crabWalkOrigin = nil
        pluming = nil
        mending = nil

        for event in events {
            guard !Task.isCancelled else { return }
            await present(event)
        }

        guard !Task.isCancelled else { return }

        flashingTiles = []
        phase = engine.isGameOver ? .gameOver : .awaitingInput
    }

    /// Animates a single event, mutates the engine, and holds for its beat.
    private func present(_ event: GameEvent) async {
        // Every event ends with the panel told what the engine now says.
        defer { publish() }

        // Checked here rather than in the handful of branches that heal, so the
        // rule really is *any* mend from *any* source — including one added
        // later by somebody who never reads this line.
        noteHeals(in: event)

        #if DEBUG
        logWear(event)
        #endif

        switch event {

        case let .moveBlocked(direction):
            reportBlocked(direction)

        case .pieceFell:
            await animateFall(event)

        case let .nexysMoved(destination, carrying) where hasLibra:
            // The island answering the call, in Libra's own diamonds.
            //
            // Thrown over the square it is *leaving* when nobody is aboard —
            // that is where the player is looking, waiting for it — and over the
            // arrival when it is carrying somebody, because then the player is
            // going with it.
            playEffect(
                .libraZodiaction,
                at: GameRules.nexysPoint,
                on: carrying ? destination : destination.opposite
            )
            await animateNexysTravel(event, goingUp: destination == .astra)

        case let .nexysMoved(destination, carryingPiece)
            where destination == .astra && carryingPiece:
            // Riding the island home is the one plane change the player earns,
            // so it gets its own sequence rather than the generic fade.
            await animateAscent(event)

        case let .nexysMoved(destination, _):
            await animateNexysTravel(event, goingUp: destination == .astra)

        case .planeRestored:
            // Nothing to flash tile-by-tile: the player is mid-fall and looking
            // at the other plane. Applied as one animated change.
            withAnimation(.easeOut(duration: GameRules.planeRestoreDuration)) {
                engine.apply(event)
            }
            await sleep(GameRules.planeRestoreDuration)

        case let .tilesChanged(plane, changes) where placedSlab != nil:
            // The Gavel's slab arriving.
            //
            // A preview that simply becomes ground on the next frame throws away
            // the one moment the ability is *about* — so it falls the last of
            // the way in and the squares it took light up, which is the same
            // white outline Libra's own moves use.
            slabLanding = SlabLanding(points: Set(changes.keys), plane: plane, start: .now)
            placedSlab = nil

            withAnimation(.easeIn(duration: GameRules.slabDropDuration)) {
                engine.apply(event)
            }
            await sleep(GameRules.slabDropDuration)

            disperseClouds(in: changes, on: plane)
            await sleep(GameRules.slabFlashDuration)
            slabLanding = nil

        case let .tilesChanged(plane, changes):
            // Libra's scales, made visible on the ground they levelled.
            //
            // Only for lines the *scales* levelled. Keyed on "Libra is here and
            // something healed" it fired for Astral Blossom too, which is not
            // her power and does not look like it — the diamonds are a signature
            // and a signature on somebody else's work is just noise.
            if hasLibra, isLevelledLine(changes, on: plane) {
                for (point, health) in changes
                where health == .healthy && engine[plane][point].health != .healthy {
                    playEffect(.libraZodiaction, at: point, on: plane)
                }
            }
            disperseClouds(in: changes, on: plane)
            flashingTiles.formUnion(changes.keys)
            withAnimation(.easeOut(duration: GameRules.areaEffectDuration)) {
                engine.apply(event)
            }
            await sleep(event.displayDuration)
            flashingTiles.subtract(changes.keys)

        case let .tilesWornOnExit(plane, changes, cause):
            showWear(cause, changes: changes, on: plane)
            disperseClouds(in: changes, on: plane)
            flashingTiles.formUnion(changes.keys)
            withAnimation(.easeOut(duration: GameRules.tileDamageDuration)) {
                engine.apply(event)
            }
            await sleep(event.displayDuration)
            flashingTiles.subtract(changes.keys)

        case let .tilesWorn(plane, changes, cause):
            showWear(cause, changes: changes, on: plane)
            disperseClouds(in: changes, on: plane)
            flashingTiles.formUnion(changes.keys)
            withAnimation(.easeOut(duration: GameRules.tileDamageDuration)) {
                engine.apply(event)
            }
            await sleep(event.displayDuration)
            flashingTiles.subtract(changes.keys)

        case let .shadowSpawned(point, plane, _):
            playEffect(.astralBloom, at: point, on: plane)
            withAnimation(.spring(response: 0.34, dampingFraction: 0.7)) {
                engine.apply(event)
            }
            await sleep(event.displayDuration)

        case .shadowStepped:
            withAnimation(.spring(response: hopDuration * 1.4, dampingFraction: 0.75)) {
                engine.apply(event)
            }
            await sleep(event.displayDuration)

        case let .shadowDestroyed(point, plane, caught):
            // Caught is worth the whole meter and should sound like it.
            shake(for: caught ? GameRules.arrowLandShake : GameRules.taurusStepShake)
            playEffect(caught ? .explosion : .astralBloom, at: point, on: plane)
            kickUpDust(at: point, on: plane, magnitude: 1)
            engine.apply(event)
            await sleep(event.displayDuration)

        case .pieceSplit:
            // Coming apart. The rifts flare, because tearing in half is the
            // same power that tears doorways.
            playEffect(.libraZodiaction, at: engine.piece.point, on: engine.piece.plane)
            withAnimation(.spring(response: 0.34, dampingFraction: 0.7)) {
                engine.apply(event)
            }
            await sleep(event.displayDuration)

        case .piecesRejoined:
            shake(for: GameRules.arrowLandShake)
            playEffect(.libraZodiaction, at: engine.piece.point, on: engine.piece.plane)
            withAnimation(.spring(response: 0.34, dampingFraction: 0.7)) {
                engine.apply(event)
            }
            await sleep(event.displayDuration)

        case let .halfLost(point, plane):
            // The soul rises from where it went through, and the survivor takes
            // it in. Drawn on the square that was lost rather than the one that
            // gains, because the loss is what happened.
            playEffect(.astralBloom, at: point, on: plane)
            engine.apply(event)
            await sleep(event.displayDuration)

        case let .tileDamaged(plane, point, _):
            // A trailing effect marks each square as the water reaches it.
            if let plume = pluming { playEffect(plume, at: point, on: plane) }
            flashingTiles.insert(point)
            withAnimation(.easeOut(duration: event.displayDuration)) {
                engine.apply(event)
            }
            await sleep(event.displayDuration)
            flashingTiles.remove(point)

        case let .tileHealed(plane, point, _):
            // Whatever the coin owed this repair, paid where the repair is.
            if let drawn = mending {
                playEffect(drawn, at: point, on: plane)
                mending = nil
            }
            flashingTiles.insert(point)
            withAnimation(.easeOut(duration: event.displayDuration)) {
                engine.apply(event)
            }
            await sleep(event.displayDuration)
            flashingTiles.remove(point)

        case let .choiceRequested(source, kind):
            engine.apply(event)
            // Suspend until the player answers, then play out whatever the
            // answer produced — including the sparkle phase that could not be
            // rolled without it.
            let answer = await askForChoice(source: source, kind: kind)
            for follow in engine.planChoice(answer) {
                guard !Task.isCancelled else { return }
                await present(follow)
            }

        case let .pickupDestroyed(_, plane, point):
            // Sparks, but no banner and no dust: nothing landed here, and
            // nothing was gained. The coin simply went down with the tile.
            collectBurst = ElementalBurst(element: .air, center: point, plane: plane, start: .now)
            clearCollectBurstLater()

            withAnimation(.easeOut(duration: event.displayDuration)) {
                engine.apply(event)
            }
            await sleep(event.displayDuration)

        case let .signStateChanged(state)
            where state.shedSkin != nil && engine.signState.shedSkin == nil:
            // Scorpio has just died and not died. The husk appears on the square
            // and the game stops for a moment before the island takes the piece
            // — without the beat this read as the fall being cancelled rather
            // than as something surviving it.
            withAnimation(.easeOut(duration: 0.2)) {
                engine.apply(event)
            }
            await sleep(GameRules.shedPauseDuration)

        case let .stingStruck(plane, from, along):
            stingStrike = StingStrike(
                plane: plane,
                from: from,
                direction: engine.piece.facing,
                reach: along.count,
                start: .now
            )
            engine.apply(event)

            // Only the lunge is waited out here. Whatever the tail caught is the
            // next event, so pausing for the full strike would take the coin
            // *after* the tail had already come back — and pausing for none of
            // it took the coin before the tail had left. The rest of the strike
            // plays underneath the reel.
            await sleep(event.displayDuration * GameRules.stingAttack)

        case let .pickupGathered(id, plane, point):
            // Reeled in rather than vanishing. Everything that sweeps a coin up
            // does it this way — the sting, a slide crossing one, Leo's pull —
            // so the coin is always seen *going somewhere* rather than simply
            // ceasing to be on the board.
            coinFlight = CoinFlight(id: id, from: point, plane: plane, start: .now)
            engine.apply(event)
            await sleep(GameRules.stingReelDuration)
            coinFlight = nil
            stingStrike = nil

        case let .pickupBanked(id, plane, point):
            // The coin does not go off, it goes *away*. The arc is the whole
            // animation, and the only thing telling the player where it went.
            pentacleBanner = id
            bankArc = BankArc(id: id, from: point, plane: plane, start: .now)
            engine.apply(event)
            await sleep(event.displayDuration)
            bankArc = nil

        case let .pickupSpent(id):
            // Bought back out. The banner names it for the same reason opening
            // one does: this is the moment the player finds out what it does.
            pentacleBanner = id
            engine.apply(event)

        case let .pickupCollected(id, plane, point):
            lastCollectedPickup = id
            pentacleBanner = id

            // Landing on a raised tile is a heavier arrival than an ordinary
            // hop: the tile slams flat, dust kicks up, and the coin bursts.
            kickUpDust(
                at: point, on: plane,
                magnitude: GameRules.smokeCollectMagnitude,
                // This *is* the pop-down: the coin's tile slamming back flat.
                fromRaisedTile: true
            )
            collectBurst = ElementalBurst(element: .air, center: point, plane: plane, start: .now)

            clearCollectBurstLater()

            // Elemental Pentacles throw their burst as they open. Only the four
            // Astral Essences declare an element; everything else is silent.
            if let element = PickupCatalog.effect(for: id).element {
                playBurst(element, at: point, on: plane)
            }
            // The coin's own strip, laid out by what the coin *does* rather
            // than by what its events happened to change — see
            // `EffectSprite.shape(for:)`.
            if let drawn = EffectSprite.pickup(for: id) {
                switch EffectSprite.shape(for: id) {
                case .here:
                    playEffect(drawn, at: point, on: plane)

                case .ring:
                    for square in point.neighbourhood(includingSelf: true)
                    where engine[plane].contains(square) {
                        playEffect(drawn, at: square, on: plane)
                    }

                case .mending:
                    // Held until something is actually healed. The Tear's coin
                    // is opened where the piece is standing and its repair
                    // happens somewhere else entirely, so playing it at the
                    // collection point drew water over the wrong square.
                    mending = drawn

                case .trailing:
                    // Held, and spent square by square as the slide reaches
                    // them. Cleared when the move ends, in case it never does.
                    pluming = drawn
                }
            }

            // The Bolt is the exception: it changes no ground, it strikes *you*.
            // One of four drawings, so the rarest thing in the game is not the
            // same picture every time somebody finally finds it.
            if id == .astralBolt {
                playEffect(
                    EffectSprite.strike(at: engine.moveCount),
                    at: point,
                    on: plane
                )
            }
            withAnimation(.spring(response: 0.28, dampingFraction: 0.6)) {
                engine.apply(event)
            }
            await sleep(event.displayDuration)

            // The coin is open. If this is the first time the player has ever
            // seen this effect, stop the game and explain it before any of its
            // consequences play out.
            if codex.needsIntroduction(id) {
                await introducePentacle(id)
            }

        case let .pieceSlid(from, to, plane):
            leaveAfterimage(at: from, on: plane)
            isSliding = true
            beginMovement(
                .slide,
                direction: stepDirection(from: from, to: to),
                duration: event.displayDuration
            )
            pressedTiles.insert(to)

            // Water on every square the surf crosses. A slide is the one move
            // long enough to leave a wake, and for the fish it *is* the wake.
            if let trail = EffectSprite.slideTrail(for: zodiac, on: plane) {
                playEffect(trail, at: to, on: plane)
            }

            // The crab's scuttle bubbles up on every square it crosses.
            //
            // It lives here rather than with the hops because the scuttle *is* a
            // slide — and when the crab walk became one, this was left behind in
            // the branch for stepping and stopped firing altogether. A sideways
            // move is one where the piece travels perpendicular to the way it is
            // looking, which only happens when the facing was kept.
            if let drawn = EffectSprite.sidestep(for: zodiac),
               engine.piece.facing.perpendicular.contains(stepDirection(from: from, to: to)) {
                if crabWalkOrigin == nil {
                    crabWalkOrigin = from
                    playEffect(drawn, at: from, on: plane)
                }
                playEffect(drawn, at: to, on: plane, delay: GameRules.crabWalkStagger)
            }
            // No hop pose, no dust, no beat to speak of. The animation runs
            // *longer* than the beat it waits — see `GameRules.slideOverlap` —
            // so each square is still moving when the next starts and the whole
            // sweep is one continuous slide rather than a row of short ones.
            //
            // Smooth rather than linear: the sweep is one movement now, and one
            // movement should ease out of its start and into its end. The
            // overlap is what keeps the squares from showing as separate steps
            // in between.
            withAnimation(.smooth(duration: event.displayDuration * GameRules.slideOverlap)) {
                engine.apply(event)
            }
            await sleep(event.displayDuration)
            // Released a beat behind the piece, so the press trails it rather
            // than snapping back the instant it leaves.
            releasePressLater(to)

        case let .pieceStepped(from, to, plane):
            leaveAfterimage(at: from, on: plane)
            hopDistance = max(from.manhattanDistance(to: to), 1)
            hopCount += 1
            hopStartedAt = .now
            beginMovement(
                .hop,
                direction: stepDirection(from: from, to: to),
                duration: hopDuration
            )

            // The ground gives when the piece reaches it, not when it sets off —
            // so the dip is scheduled for the end of the hop rather than fired
            // here. `hopDuration` is the arc; the impact is what follows it.
            // Only a style that came down lands. `bouncesOnArrival` rather
            // than "is this a step", so a leap gets the dip and a slide does not
            // without either having to be named here.
            if movement?.style.bouncesOnArrival ?? true {
                landAfterHop(at: to, on: plane)
            }

            // And every phantom lands too, a beat later each.
            //
            // They are bodies with weight — that is the whole reason they wear
            // the ground — so the cloud has to give under them as it does under
            // the lion. Scheduled off the same hop, offset by each one's beat,
            // so the dips arrive in the order the jumps do.
            for (step, _) in engine.signState.retinue.enumerated() {
                landAfterHop(
                    at: engine.retinueSquare(step: step),
                    on: plane,
                    after: GameRules.retinueBeat * Double(step + 1)
                )
            }

            // The crab's scuttle bubbles up on every square it crosses.
            //
            // Fired per step rather than planned up front: a sidestep is a
            // *slide*, so the engine emits one `.pieceStepped` per square and
            // there is no single event carrying the whole two-square walk. That
            // is also why the previous `hopDistance >= 2` test never fired —
            // every step of a slide covers exactly one square.
            //
            // A seafoam scuttle is recognised by the piece moving perpendicular to the
            // way it is looking, which only happens when the facing was kept —
            // i.e. exactly on the sidestep, and never on an ordinary step, which
            // turns the piece to face its direction.
            if let drawn = EffectSprite.sidestep(for: zodiac),
               engine.piece.facing.perpendicular.contains(stepDirection(from: from, to: to)) {
                if crabWalkOrigin == nil {
                    crabWalkOrigin = from
                    playEffect(drawn, at: from, on: plane)
                }
                playEffect(drawn, at: to, on: plane, delay: GameRules.crabWalkStagger)
            }

            // Their full three-tile bound, thrown from the square pushed off.
            // Not any long move: a two-square sidestep is not the leap this
            // draws.
            if hopDistance >= GameRules.longJumpDistance,
               let drawn = EffectSprite.longJump(for: zodiac) {
                playEffect(drawn, at: from, on: plane)
            }
            withAnimation(.spring(response: hopDuration * 1.6, dampingFraction: 0.72)) {
                engine.apply(event)
            }
            await sleep(hopDuration)

            // Dust on the *landing*, not the launch. Firing it with the step
            // put the puff at the destination before the piece got there.
            kickUpDust(at: to, on: plane, magnitude: 1)

        case let .gameOver(reason) where reason == .fellThroughTerra:
            // The same spin-and-shrink as any other hole. There is simply
            // nothing below this one.
            await animateDescent(duration: GameRules.fallDuration / 2)
            engine.apply(event)
            await sleep(event.displayDuration)

        case let .zodiactionMeterChanged(to):
            // Gaining charge flashes the piece its element's colour, and a sign
            // with a drawn strip for it throws that too.
            if to > engine.zodiactionMeter {
                flashCharge()
                if let drawn = EffectSprite.chargeGain(for: zodiac) {
                    playEffect(drawn, at: engine.piece.point, on: engine.piece.plane)
                }
            }
            withAnimation(.easeInOut(duration: max(event.displayDuration, 0.01))) {
                engine.apply(event)
            }
            await sleep(event.displayDuration)

        case let .zodiactionFired(zodiac, plane)
            where (zodiac == .pisces && plane == .astra) || zodiac == .taurus:
            // A deliberate leap: Pisces' dive and Taurus' flop. Whatever
            // follows — a fall, a mend — is the next event, so the arc is played
            // out here in full and the consequence takes over from the top of
            // it. See `HopPose.leap(progress:)`.
            summonConstellation(zodiac, on: plane)
            for layer in EffectSprite.zodiaction(for: zodiac) {
                playEffect(layer, at: engine.piece.point, on: plane)
            }
            engine.apply(event)
            await playLeap()

        case let .zodiactionFired(zodiac, plane):
            // The ram burns for the length of its run — the embers on the piece
            // itself. The fire it *leaves* is drawn from the damage's cause, so
            // a borrowed charge burns exactly as the real one does.
            if zodiac == .aries { isCharging = true }
            summonConstellation(zodiac, on: plane)
            // Signs whose Zodiaction has been drawn play it; the rest keep the
            // spectral head and their programmatic burst alone.
            // Some Zodiactions travel and mark the ground as they go, exactly
            // as the coin they are borrowed from does.
            pluming = EffectSprite.zodiactionTrail(for: zodiac, on: plane)

            for layer in EffectSprite.zodiaction(for: zodiac) {
                playEffect(layer, at: engine.piece.point, on: plane)
            }
            // Leo's sun is drawn from engine state by `SunView`, summon flare
            // included — one appearance rather than a burst followed by a sun.
            withAnimation(.easeOut(duration: event.displayDuration)) {
                engine.apply(event)
            }
            await sleep(event.displayDuration)

        case let .pickupMoved(_, plane, _, to):
            // Dragged, so it travels rather than blinking across.
            withAnimation(.spring(response: event.displayDuration * 1.4, dampingFraction: 0.8)) {
                engine.apply(event)
            }
            await sleep(event.displayDuration)
            // It lands like anything else does.
            kickUpDust(at: to, on: plane, magnitude: 1)

        case let .tileStamped(plane, point):
            // Smoke, and nothing else. An empty raised tile has nothing to give.
            kickUpDust(at: point, on: plane, magnitude: 1, fromRaisedTile: true)
            withAnimation(.spring(response: GameRules.tilePopFallResponse, dampingFraction: 0.8)) {
                engine.apply(event)
            }
            await sleep(event.displayDuration)

        case let .arrowPlanted(plane, point):
            // Up first, out of the square the archer is standing on.
            warpBeam = WarpBeam(
                point: engine.piece.point,
                plane: engine.piece.plane,
                isDeparture: true,
                start: .now
            )

            // The shot itself, leaving the bow.
            //
            // The arrow was only ever drawn coming *down*, so the ability began
            // with a beam and a wait — the one frame that says an arrow was
            // fired was missing entirely. It rises out of the piece's head and
            // off the top of the board, and the descent picks it up from there.
            loosedArrow = LoosedArrow(
                point: engine.piece.point,
                plane: engine.piece.plane,
                start: .now
            )
            await sleep(GameRules.arrowRiseDuration)
            loosedArrow = nil

            // Then down. Fired from Terra it brings a cloud with it, wrapped
            // around the shaft — Astra is whole again by the time anyone looks
            // up, so the cloud is only ever a thing that is seen.
            if plane == .terra {
                fallingCloud = FallingCloud(point: point, plane: plane, start: .now)
            }
            await sleep(event.displayDuration)
            warpBeam = nil

            // It lands, the cloud comes apart over the square, and the arrow is
            // in the ground.
            if plane == .terra {
                fallingCloud = nil

                // Where it went in. The strike is the loudest single frame the
                // archer has, and it belongs on the square rather than on the
                // shaft — the arrow is what is left over, the hit is the event.
                playEffect(.sagittariusArrowHit, at: point, on: plane)

                // And the board feels it. Something came out of the sky and
                // buried itself in the floor; a strike that big without a knock
                // reads as a decal being placed rather than an arrival.
                shake(for: GameRules.arrowLandShake)

                // The cloud comes apart in Astra's own violets, wherever it has
                // landed. It is cloudstuff that fell out of the sky; the ground
                // it happens to have hit has nothing to do with what it is made
                // of.
                if SmokeSpriteView.hasArt(on: .astra) {
                    smoke = SmokePuff(
                        point: point,
                        plane: plane,
                        magnitude: GameRules.cloudPoofMagnitude,
                        start: .now,
                        cloudstuff: true
                    )
                }

                let poof = CloudPoof(point: point, start: .now)
                cloudPoofs.append(poof)
                Task { [weak self] in
                    try? await Task.sleep(
                        nanoseconds: UInt64(GameRules.cloudPoofDuration * 1_000_000_000)
                    )
                    self?.cloudPoofs.removeAll { $0.id == poof.id }
                }
            }
            withAnimation(.easeOut(duration: GameRules.tilePopResponse)) {
                engine.apply(event)
            }

        // Not gated on the arrow still being there.
        //
        // The recall *consumes* it, and the `signStateChanged` that clears it is
        // applied before this event — so by the time the teleport is presented
        // the arrow is already gone and the guard never passed. The archer has
        // exactly one way to teleport, so the sign is the whole condition.
        case let .pieceTeleported(from, _, fromPlane, _) where zodiac == .sagittarius:
            // The archer does not warp to the arrow, he *jumps* to it.
            //
            // A beam is the right picture for Astral Breeze, where the board
            // moves you. This is the same body that vaults three squares under
            // its own power, going after its own shot — so it crouches flat,
            // launches off the top of the screen in its own fire, and comes down
            // hard where the arrow is standing.
            await launchToArrow(event, from: from, plane: fromPlane)

        case let .pieceTeleported(from, _, fromPlane, toPlane):
            await animateWarp(event, from: from, fromPlane: fromPlane, toPlane: toPlane)

        default:
            withAnimation(.easeInOut(duration: max(event.displayDuration, 0.01))) {
                engine.apply(event)
            }
            await sleep(event.displayDuration)
        }
    }

    /// Sagittarius launching after his own arrow.
    ///
    /// Crouch, fire, up and off the screen; then the board changes underneath
    /// and he lands on the arrow's square hard enough to be felt. The pose is
    /// `HopPose.leap` run past its own end — the piece keeps rising rather than
    /// coming down, because the descent happens somewhere else.
    private func launchToArrow(_ event: GameEvent, from: GridPoint, plane: Plane) async {
        // The crouch, and the fire it pushes off with.
        leapStartedAt = .now
        playEffect(.sagittariusJump, at: from, on: plane)
        Haptics.longer()
        await sleep(GameRules.leapDuration * GameRules.vaultCrouchFraction)

        // Away. `isLaunching` lifts the piece clear of the board on its own
        // curve, since the leap pose alone only clears a tile or so.
        isLaunching = true
        await sleep(GameRules.vaultLaunchDuration)

        engine.apply(event)
        isLaunching = false
        leapStartedAt = nil

        // Arrival: the fire again, on the square he has landed on, and a knock.
        playEffect(.sagittariusJump, at: engine.piece.point, on: engine.piece.plane)
        playEffect(.sagittariusArrowHit, at: engine.piece.point, on: engine.piece.plane)
        kickUpDust(at: engine.piece.point, on: engine.piece.plane, magnitude: 1.4)
        shake(for: GameRules.arrowLandShake)
        bounceSurface(at: engine.piece.point, on: engine.piece.plane)
        await sleep(GameRules.fallArrivalDuration)
    }

    /// The piece disappearing down a hole: spin, shrink, fade.
    ///
    /// Split out because going down a hole is a property of **the hole**, not of
    /// what happens next. Dropping to Terra and dropping out of the world
    /// entirely look identical while you are falling; they differ only in what
    /// is waiting underneath.
    private func animateDescent(duration: TimeInterval) async {
        withAnimation(.easeIn(duration: duration)) {
            isFalling = true
            fallSpin += GameRules.fallSpinDegrees / 2
        }
        await sleep(duration)
    }

    /// The drop between planes, in three beats.
    ///
    /// 1. **Departure.** The piece spins counter-clockwise, shrinks and fades as
    ///    it goes through the hole.
    /// 2. **Arrival.** The board below is applied, then the piece falls in from
    ///    above the screen while a shadow on the destination tile swells to meet
    ///    it — the shadow is what tells the player where it is coming down before
    ///    the piece is anywhere near.
    /// 3. **Impact.** A heavy dust cloud and a short shake.
    ///
    /// The spin is accumulated in halves rather than set to a target angle, so
    /// it keeps turning the same way across the plane swap instead of unwinding.
    ///
    /// - TODO: **Replace the plane change with a proper transition.** Not the
    ///   piece's animation — this one is fine — but the swap itself, which is
    ///   currently a cut hidden behind a flash.
    ///
    ///   The effect wanted: take the game screen as it stands and scroll it
    ///   upward, fast, looping — so the world reads as rushing past on the way
    ///   down — with high-glow vertical capsules in white, ice blue, light
    ///   yellow and light pink flying up through it on their own loop. Inverted
    ///   for an ascent: everything travels down instead.
    ///
    ///   This is the GameMaker surface trick, and it has an equivalent here.
    ///   `ImageRenderer` will hand back a snapshot of a view hierarchy, which is
    ///   the surface; scrolling it is then two copies offset by the loop height
    ///   with the phase driven off a timestamp, exactly like every other effect
    ///   in this file. The capsules want a `Canvas` over the top — they are
    ///   dozens of soft additive shapes, which is what `CloudSpriteField` and
    ///   `HealSparkleView` already use one for.
    ///
    ///   One snapshot, taken *before* the boards swap — afterwards the view is
    ///   already showing the destination. Once, not per frame: `ImageRenderer`
    ///   is main-actor and not free, and re-taking it would be paying for
    ///   detail nobody can see.
    ///
    ///   Which is the point, and the thing not to lose. It moves fast enough
    ///   that the colours blur together, and **that blur is the effect** — the
    ///   scroll is not there to be read, it is there to smear. Anything done in
    ///   the name of making it legible, slowing it down or sharpening it, works
    ///   directly against it.
    private func animateFall(_ event: GameEvent) async {
        let departure = GameRules.fallDuration / 2

        // A sign that means to be down there does not tumble on the way. The
        // shrink stays — that is distance — and only the spin goes, since the
        // spin is the part that says the piece has lost control of what is
        // happening to it.
        let controlled: Bool = {
            guard case let .pieceFell(_, to, _) = event else { return false }
            return engine.piece.zodiac.passives.fallIsControlled(
                to: to, context: engine.passiveSnapshot
            )
        }()
        let tumble = controlled ? 0 : GameRules.fallSpinDegrees / 2

        // Going down through the sky pushes it aside. Only leaving Astra: a fall
        // out of Terra is a fall out of the world and there is no cloud there to
        // move.
        if case let .pieceFell(from, _, at) = event, from == .astra {
            disturbClouds(at: at)
        }

        // Spin and shrink together, and *animated* — incrementing the angle
        // outside `withAnimation` snapped the sprite round instead of turning it.
        withAnimation(.easeIn(duration: departure)) {
            isFalling = true
            fallSpin += tumble
        }
        await sleep(departure)

        guard !Task.isCancelled else {
            isFalling = false
            return
        }
        engine.apply(event)

        // Arrival. The piece is whole again the instant it re-enters — it is
        // falling in, not fading in — so the flag is cleared without animation.
        isFalling = false
        fallArrivalStartedAt = .now
        withAnimation(.linear(duration: GameRules.fallArrivalDuration)) {
            fallSpin += tumble
        }
        await sleep(GameRules.fallArrivalDuration)

        guard !Task.isCancelled else {
            fallArrivalStartedAt = nil
            return
        }
        fallArrivalStartedAt = nil
        bounceSurface(at: engine.piece.point, on: engine.piece.plane)

        // Impact. The lion does not raise dust — it lands, and the ground
        // knows about it. Its own strip stands in for the puff entirely rather
        // than playing over it.
        if let drawn = EffectSprite.landing(for: zodiac) {
            playEffect(drawn, at: engine.piece.point, on: engine.piece.plane)
        } else {
            kickUpDust(
                at: engine.piece.point,
                on: engine.piece.plane,
                magnitude: GameRules.smokeFallMagnitude
            )
        }
        hopStartedAt = nil          // no squash: this is a landing, not a hop
        shakeStartedAt = .now

        Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(GameRules.shakeDuration * 1_000_000_000))
            self?.shakeStartedAt = nil
        }
    }

    /// A warp: out through a pillar of light at one end, in through another.
    ///
    /// The piece does not travel between the two squares — it is *gone* from the
    /// first and *arrives* at the second. Sliding it across, which is what the
    /// default animation did, said the opposite: that it walked there very fast.
    ///
    /// Both ends get a beam. Playing one only at the destination would read as
    /// something happening on arrival rather than as a journey.
    private func animateWarp(
        _ event: GameEvent,
        from origin: GridPoint,
        fromPlane: Plane,
        toPlane: Plane
    ) async {
        // Out. The piece shrinks into the beam.
        warpBeam = WarpBeam(point: origin, plane: fromPlane, isDeparture: true, start: .now)
        withAnimation(.easeIn(duration: GameRules.warpBeamDuration * 0.7)) {
            isFalling = true
        }
        await sleep(GameRules.warpBeamDuration)

        guard !Task.isCancelled else {
            warpBeam = nil
            isFalling = false
            return
        }

        engine.apply(event)

        // In. A second beam where it lands, and the piece swells back out of it.
        warpBeam = WarpBeam(
            point: engine.piece.point,
            plane: toPlane,
            isDeparture: false,
            start: .now
        )
        withAnimation(.easeOut(duration: GameRules.warpBeamDuration * 0.7)) {
            isFalling = false
        }
        await sleep(GameRules.warpBeamDuration)

        warpBeam = nil
    }

    /// Riding the Nexys back up to Astra.
    ///
    /// Three beats, mirroring the fall but earned rather than suffered:
    ///
    /// 1. **Rise.** Island and piece climb together off the top of the screen,
    ///    accelerating, while the board whites out.
    /// 2. **Swap.** Astra is applied behind the flash.
    /// 3. **Settle.** The pair swell back from nothing at the centre of the
    ///    tile, overshooting a touch so they drop into place.
    ///
    /// Input is already locked for the duration — the whole replay runs in
    /// `resolvingMove`, and `acceptsInput` is false throughout.
    private func animateAscent(_ event: GameEvent) async {
        // The island is a great deal bigger than a piece, and it goes through
        // the same hole.
        disturbClouds(at: GameRules.nexysPoint)

        ascentRiseStartedAt = .now
        withAnimation(.easeIn(duration: GameRules.ascentRiseDuration)) {
            ascentFlash = GameRules.ascentFlashOpacity
        }
        await sleep(GameRules.ascentRiseDuration)

        guard !Task.isCancelled else {
            ascentRiseStartedAt = nil
            ascentFlash = 0
            return
        }

        engine.apply(event)
        ascentRiseStartedAt = nil

        ascentGrowStartedAt = .now
        withAnimation(.easeOut(duration: GameRules.ascentGrowDuration)) {
            ascentFlash = 0
        }
        await sleep(GameRules.ascentGrowDuration)

        ascentGrowStartedAt = nil
    }

    /// The island travelling between planes **without** a passenger.
    ///
    /// Its own sequence rather than the ascent's, because it means something
    /// different: an ascent is the player being carried home, this is the island
    /// leaving — or arriving — under someone else's instruction. So it shrinks
    /// away and drifts the way it is headed, then swells back in on the far side,
    /// and the board never whites out because the player has not gone anywhere.
    /// True while the island is travelling with the piece on it.
    ///
    /// The piece borrows the island's pose for the whole journey rather than
    /// having one of its own — see `BoardView.ascentPose(at:metrics:)`. Riding
    /// is the one case where the two must agree exactly, and two timelines that
    /// have to agree exactly should be one timeline.
    private(set) var nexysCarryingPiece = false

    private func animateNexysTravel(_ event: GameEvent, goingUp: Bool) async {
        // The island is a great deal bigger than a piece, and it goes through
        // the same hole.
        disturbClouds(at: GameRules.nexysPoint)

        nexysTravellingUp = goingUp
        if case let .nexysMoved(_, carrying) = event { nexysCarryingPiece = carrying }
        defer { nexysCarryingPiece = false }

        nexysDepartStartedAt = .now
        // Climbing away takes as long as carrying the player would; shrinking
        // out on Astra is quicker, because there is less to watch.
        await sleep(goingUp ? GameRules.ascentRiseDuration : GameRules.nexysTravelDepartDuration)

        guard !Task.isCancelled else {
            nexysDepartStartedAt = nil
            return
        }

        engine.apply(event)
        nexysDepartStartedAt = nil

        nexysArriveStartedAt = .now
        await sleep(goingUp ? GameRules.ascentGrowDuration : GameRules.fallArrivalDuration)
        nexysArriveStartedAt = nil
    }

    /// A two-part "leaves one plane, arrives on the other" animation, kept for
    /// any transition that still wants a plain crossfade.
    private func animateTransit(
        _ event: GameEvent,
        flag: ReferenceWritableKeyPath<GameSession, Bool>,
        duration: TimeInterval
    ) async {
        let half = duration / 2

        withAnimation(.easeIn(duration: half)) { self[keyPath: flag] = true }
        await sleep(half)

        guard !Task.isCancelled else {
            self[keyPath: flag] = false
            return
        }
        engine.apply(event)

        withAnimation(.easeOut(duration: half)) { self[keyPath: flag] = false }
        await sleep(half)
    }

    // MARK: - Pentacle introductions

    /// Continuation held while a first-encounter splash is on screen.
    private var resumeContinuation: CheckedContinuation<Void, Never>?

    /// Shows the splash for `id` and does not return until it is dismissed.
    ///
    /// Suspending here is what makes the splash genuinely game-pausing: the
    /// remaining events of the move — the effect's own consequences, the new
    /// sparkle phase — are still queued behind this call.
    private func introducePentacle(_ id: PickupID) async {
        pentacleIntro = id
        await withCheckedContinuation { continuation in
            resumeContinuation = continuation
        }
    }

    /// Dismisses the splash and lets the paused move finish.
    /// Dismisses the splash if one is up, and reports whether it was.
    ///
    /// Every control funnels through here first: reaching for the stick, the
    /// pad or the keyboard is how the splash is put away, so the move that
    /// dismissed it is deliberately **not** also played. Otherwise the first
    /// input after a Pentacle would be spent before it could be read, which is
    /// the opposite of what a splash is for.
    @discardableResult
    func dismissIntroIfShowing() -> Bool {
        guard pentacleIntro != nil else { return false }
        dismissPentacleIntro()
        return true
    }

    func dismissPentacleIntro() {
        guard let id = pentacleIntro else { return }
        codex.markSeen(id)
        pentacleIntro = nil
        resumeContinuation?.resume()
        resumeContinuation = nil
    }

    // MARK: - Pentacle choices

    /// Continuation held while a Pentacle waits on the player.
    private var choiceContinuation: CheckedContinuation<PickupChoiceResult, Never>?

    /// Puts the question up and does not return until it is answered.
    private func askForChoice(
        source: ChoiceSource,
        kind: PickupChoice
    ) async -> PickupChoiceResult {
        // The cursor does not jump home when it is asked a question.
        //
        // It was already pointing somewhere — at whatever the piece was aimed
        // at — and that is very often the square the player wants. Starting at
        // the piece's own cell throws away a decision they had already half
        // made, and on a seven-wide board that is up to six taps to undo.
        targetAim = engine.cursor(direction: nil, reach: 0).point

        // The board holds its pose while it waits. A question can be open for as
        // long as the player likes, and ambient motion carrying on underneath a
        // frozen game is the clearest possible signal that nothing is waiting on
        // anything — which is the opposite of true.
        pauseAmbient(at: Date.now.timeIntervalSinceReferenceDate)
        pendingPickupChoice = (source, kind)
        return await withCheckedContinuation { continuation in
            choiceContinuation = continuation
        }
    }

    /// Answers the outstanding Pentacle question and lets the move finish.
    func resolvePickupChoice(_ result: PickupChoiceResult) {
        guard pendingPickupChoice != nil else { return }
        pendingPickupChoice = nil
        targetAim = nil
        resumeAmbient(at: Date.now.timeIntervalSinceReferenceDate)
        choiceContinuation?.resume(returning: result)
        choiceContinuation = nil
    }

    /// Records a rejected swipe so the board can nudge in that direction.
    private func reportBlocked(_ direction: SwipeDirection) {
        blockedDirection = direction
        blockedNudge += 1

        // The piece tries anyway. A board that shakes while the piece stands
        // perfectly still reads as the *game* refusing; a piece that hops and
        // gets nowhere reads as the piece refusing, which is what actually
        // happened.
        balkStartedAt = .now
        balkDirection = direction
    }

    /// When the piece last tried a move it could not make, and which way.
    private(set) var balkStartedAt: Date?
    private(set) var balkDirection: SwipeDirection?

    private func sleep(_ seconds: TimeInterval) async {
        guard seconds > 0 else { return }
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
}

// MARK: - Pause

extension GameSession {

    /// Opens or closes the pause menu.
    ///
    /// Pausing does not touch the engine — the game is turn-based and has
    /// nothing running to suspend. It only withdraws input, which is enough,
    /// and is why a move already in flight finishes rather than freezing
    /// half-resolved.
    func togglePause() {
        isPaused.toggle()
    }

    func resume() {
        isPaused = false
    }

    /// Abandons the current run and starts another with the same sign.
    func restart() {
        isPaused = false
        newGame()
    }
}

// MARK: - Dust

/// One puff of dust settling on the board.
struct SmokePuff: Identifiable, Equatable {
    let id = UUID()
    let point: GridPoint
    let plane: Plane
    let magnitude: CGFloat
    let start: Date

    /// True when this is a lifted square settling rather than a footfall — see
    /// `GameSession.kickUpDust(at:on:magnitude:fromRaisedTile:)`.
    var fromRaisedTile = false

    /// Overrides the plane's own smoke colour.
    var tint: Color?

    /// True when this puff is made of cloud regardless of where it landed —
    /// Sagittarius' shot brings one down onto Terra.
    var cloudstuff = false
}

extension GameSession {

    /// Clears the sparkle burst once it has played out.
    func clearCollectBurstLater() {
        let burstID = collectBurst?.id
        Task { [weak self] in
            try? await Task.sleep(
                nanoseconds: UInt64(GameRules.collectBurstDuration * 1_000_000_000)
            )
            guard let self, self.collectBurst?.id == burstID else { return }
            self.collectBurst = nil
        }
    }

    /// Throws up dust at a square, and clears it once it has settled.
    ///
    /// Carries its own timestamp rather than riding the hop's: dust is kicked up
    /// by landings that are not hops at all — a fall, or taking a coin — and
    /// borrowing the hop's clock meant those bursts started already expired.
    #if DEBUG
    /// Prints every tile-damage event, with what it was and what it became.
    ///
    /// ## Delete me
    ///
    /// Here to answer one report: a fall to Terra taking the landing square down
    /// two stages instead of one. The engine only ever proposes a single stage
    /// per landing and Aries no longer has a passive that doubles anything, so
    /// if two stages are really landing they are arriving as two separate
    /// events — and this says which two, in order, with the plane and square.
    ///
    /// Remove once the cause is known.
    private func logWear(_ event: GameEvent) {
        func report(_ label: String, _ plane: Plane, _ changes: [GridPoint: TileHealth]) {
            for (point, after) in changes {
                let before = engine[plane][point].health
                print("[wear] \(label) \(plane) \(point) \(before) -> \(after)")
            }
        }

        switch event {
        case let .tilesWorn(plane, changes, cause): report("worn \(cause)", plane, changes)
        case let .tilesWornOnExit(plane, changes, cause):
            report("exit \(cause)", plane, changes)
        case let .tileDamaged(plane, point, to): report("damaged", plane, [point: to])
        case let .tilesChanged(plane, changes): report("changed", plane, changes)
        case let .pieceFell(from, to, at): print("[wear] fell \(from)->\(to) at \(at)")
        default: break
        }
    }
    #endif

    /// Throws teal motes off every square this event is about to *improve*.
    ///
    /// Compares the event's stated outcome against the board as it stands right
    /// now, before the event is applied — so a "heal" that changed nothing, or
    /// one that only halted further wear, correctly sparkles nothing.
    ///
    /// Deliberately driven by the health *change* rather than by which events
    /// are nominally healing ones. Repair arrives under half a dozen different
    /// names in this game — `tileHealed`, `tilesChanged`, `planeRestored`, and
    /// whatever a sign invents next — and a list of them would be out of date
    /// the first time one was added.
    private func noteHeals(in event: GameEvent) {
        var mended: [(GridPoint, Plane)] = []

        func check(_ point: GridPoint, _ plane: Plane, _ after: TileHealth) {
            guard engine[plane].contains(point) else { return }
            let tile = engine[plane][point]
            // The Nexys and its chasm are not ground and cannot be mended.
            guard tile.kind == .normal, after < tile.health else { return }
            mended.append((point, plane))
        }

        switch event {
        case let .tileHealed(plane, point, health):
            check(point, plane, health)

        case let .tilesChanged(plane, changes):
            for (point, health) in changes { check(point, plane, health) }

        case let .tilesWorn(plane, changes, _), let .tilesWornOnExit(plane, changes, _):
            // Wear events can carry a repair: Virgo's compensation mends one
            // square in the same breath as damaging another.
            for (point, health) in changes { check(point, plane, health) }

        case let .tileDamaged(plane, point, health):
            check(point, plane, health)

        case .planeRestored:
            // Deliberately silent. Astra re-forming is a whole-plane event with
            // its own presentation, and marking it here would put a shimmer
            // canvas on every one of forty-nine squares at the same instant —
            // for a repair the player is not even looking at, since they are
            // mid-fall onto the other plane.
            return

        default:
            return
        }

        guard !mended.isEmpty else { return }
        for (point, plane) in mended.prefix(GameRules.healSparkleMaxTiles) {
            spawnHealSparkle(at: point, on: plane)
        }
    }

    /// One tile's worth of mending shimmer.
    private func spawnHealSparkle(at point: GridPoint, on plane: Plane) {
        let sparkle = HealSparkle(point: point, plane: plane, start: .now)
        healSparkles.append(sparkle)

        Task { [weak self] in
            try? await Task.sleep(
                nanoseconds: UInt64(GameRules.healSparkleDuration * 1_000_000_000)
            )
            self?.healSparkles.removeAll { $0.id == sparkle.id }
        }
    }

    /// Knocks the board for `duration`.
    ///
    /// The heavy-landing shake already existed but was only ever fired by the
    /// engine's own events; this is the same thing on request, for a sign whose
    /// *ordinary steps* are supposed to land like that.
    /// - Parameter strength: A multiplier on the usual amplitude, for knocks
    ///   that happen often enough that a full one would never let the board
    ///   settle.
    func shake(for duration: TimeInterval, strength: CGFloat = 1) {
        shakeStartedAt = .now
        shakeStrength = strength

        Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            self?.shakeStartedAt = nil
        }
    }

    /// Draws whatever the cause of some damage looks like.
    ///
    /// One place, asking the *cause* rather than the sign. It used to ask "is
    /// this Aries?" and "is this Taurus?", which was already wrong the day Leo
    /// could borrow either of them and would have been wrong again the first
    /// time two things burned. What a hoof looks like belongs to the hoof.
    private func showWear(
        _ cause: WearCause,
        changes: [GridPoint: TileHealth],
        on plane: Plane
    ) {
        if let strip = cause.effect {
            for point in changes.keys { playEffect(strip, at: point, on: plane) }
        }

        if cause.shakes(on: plane) { shake(for: GameRules.taurusStepShake) }

        // Read against the board as it still stands: this runs before the event
        // is applied, so a square listed at the health it already has is a
        // square nothing happened to.
        let changed = changes.contains { engine[plane][$0.key].health != $0.value }

        if let tint = cause.smokeTint(changedAnything: changed),
           let point = changes.keys.first {
            kickUpDust(at: point, on: plane, magnitude: 1, tint: tint)
        }
    }

    /// Lets a pressed square come back up, shortly.
    private func releasePressLater(_ point: GridPoint) {
        Task { [weak self] in
            try? await Task.sleep(
                nanoseconds: UInt64(GameRules.slidePressLinger * 1_000_000_000)
            )
            self?.pressedTiles.remove(point)
        }
    }

    /// - Parameter fromRaisedTile: True when it is a lifted square settling
    ///   back down rather than a footfall. That square is recoloured while it is
    ///   up, so its smoke has to be recoloured with it.
    /// - Parameter tint: Recolours the puff wholesale. Used where the smoke is
    ///   saying something the plane's own dust does not — Taurus' free step is
    ///   earth-green wherever it happens.
    func kickUpDust(
        at point: GridPoint,
        on plane: Plane,
        magnitude: CGFloat,
        fromRaisedTile: Bool = false,
        tint: Color? = nil
    ) {
        let puff = SmokePuff(
            point: point, plane: plane, magnitude: magnitude,
            start: .now, fromRaisedTile: fromRaisedTile, tint: tint
        )
        smoke = puff

        Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(GameRules.smokeDuration * 1_000_000_000))
            guard let self, self.smoke?.id == puff.id else { return }
            self.smoke = nil
        }
    }
}

// MARK: - Constellations

/// A sign written in the air over the piece.
struct ConstellationSummon: Identifiable, Equatable {
    let id = UUID()
    let zodiac: Zodiac
    let plane: Plane
    let start: Date
}

extension GameSession {

    /// Writes the sign in the air and clears it once it has faded.
    func summonConstellation(_ zodiac: Zodiac, on plane: Plane) {
        let summon = ConstellationSummon(zodiac: zodiac, plane: plane, start: .now)
        constellation = summon

        Task { [weak self] in
            try? await Task.sleep(
                nanoseconds: UInt64(GameRules.constellationDuration * 1_000_000_000)
            )
            guard let self, self.constellation?.id == summon.id else { return }
            self.constellation = nil
        }
    }
}

// MARK: - Cloud dispersal

/// One Astra square coming apart.
struct CloudPoof: Identifiable, Equatable {
    let id = UUID()
    let point: GridPoint
    let start: Date
}

extension GameSession {

    /// Sets off a dispersal for every Astra square this change turns into a
    /// hole.
    ///
    /// Reads the change rather than the board, so it fires on the transition and
    /// not on every batch that happens to include an already-open square —
    /// otherwise a second area effect would re-poof squares that dispersed
    /// several moves ago.
    func disperseClouds(in changes: [GridPoint: TileHealth], on plane: Plane) {
        guard plane == .astra else { return }

        let opened = changes.filter { point, health in
            health.isHole && engine[plane][point].health != .hole
        }
        guard !opened.isEmpty else { return }

        let poofs = opened.keys.map { CloudPoof(point: $0, start: .now) }
        cloudPoofs += poofs

        let ids = Set(poofs.map(\.id))
        Task { [weak self] in
            try? await Task.sleep(
                nanoseconds: UInt64(GameRules.cloudPoofDuration * 1_000_000_000)
            )
            self?.cloudPoofs.removeAll { ids.contains($0.id) }
        }
    }
}

// MARK: - Warps

/// A pillar of light standing on one square.
struct WarpBeam: Identifiable, Equatable {
    let id = UUID()
    let point: GridPoint
    let plane: Plane

    /// True at the end the piece leaves from, false where it arrives.
    let isDeparture: Bool

    let start: Date
}

// MARK: - Elemental bursts

/// One elemental burst in flight.
struct ElementalBurst: Identifiable, Equatable {
    let id = UUID()
    let element: ZodiacElement
    let center: GridPoint
    let plane: Plane
    let start: Date
}

/// One drawn effect strip, playing.
struct EffectBurst: Identifiable, Equatable {
    let id = UUID()
    let effect: EffectSprite
    let center: GridPoint
    let plane: Plane
    let start: Date
}

extension GameSession {

    /// Plays a drawn effect strip through once and clears it.
    ///
    /// The clean-up delay is cosmetic bookkeeping, not a game rule — whatever
    /// the effect illustrates resolved the instant its events were applied.
    /// - Parameter delay: Seconds to wait before it starts. `EffectSpriteView`
    ///   draws nothing before its start date, so a delayed burst simply sits
    ///   there — no scheduling, and it still clears itself on time.
    func playEffect(
        _ effect: EffectSprite,
        at point: GridPoint,
        on plane: Plane,
        delay: TimeInterval = 0
    ) {
        let burst = EffectBurst(
            effect: effect,
            center: point,
            plane: plane,
            start: .now.addingTimeInterval(delay)
        )
        effectBursts.append(burst)

        Task { [weak self] in
            try? await Task.sleep(
                nanoseconds: UInt64((delay + effect.duration) * 1_000_000_000)
            )
            self?.effectBursts.removeAll { $0.id == burst.id }
        }
    }

    /// Remembers a square the piece has just left.
    ///
    /// Kept short: an afterimage is the last half second, and the oldest one
    /// falls off the end rather than fading forever.
    private func leaveAfterimage(at point: GridPoint, on plane: Plane) {
        afterimages.insert(Afterimage(point: point, plane: plane, born: .now), at: 0)
        if afterimages.count > GameRules.afterimageCount {
            afterimages.removeLast(afterimages.count - GameRules.afterimageCount)
        }
    }

    /// Which way a single step went.
    ///
    /// A step is always one square along one axis, so this cannot be ambiguous.
    /// Defaults to the piece's own facing for a step that went nowhere.
    private func stepDirection(from: GridPoint, to: GridPoint) -> SwipeDirection {
        if to.x > from.x { return .right }
        if to.x < from.x { return .left }
        if to.y > from.y { return .down }
        if to.y < from.y { return .up }
        return engine.piece.facing
    }

    /// Recolours the piece for a moment. Fired whenever the meter gains.
    func flashCharge() {
        chargeFlashStartedAt = .now

        Task { [weak self] in
            try? await Task.sleep(
                nanoseconds: UInt64(GameRules.chargeFlashDuration * 1_000_000_000)
            )
            guard let self else { return }
            let elapsed = Date.now.timeIntervalSince(self.chargeFlashStartedAt ?? .now)
            // Only clear it if nothing has re-flashed in the meantime.
            if elapsed >= GameRules.chargeFlashDuration { self.chargeFlashStartedAt = nil }
        }
    }

    /// Starts a burst and clears it once it has played out.
    ///
    /// The clean-up delay is cosmetic bookkeeping, not a game rule — the effect
    /// it illustrates resolved the instant its events were applied.
    func playBurst(_ element: ZodiacElement, at point: GridPoint, on plane: Plane) {
        let burst = ElementalBurst(element: element, center: point, plane: plane, start: .now)
        elementalBurst = burst

        Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(GameRules.elementalBurstDuration * 1_000_000_000))
            guard let self, self.elementalBurst?.id == burst.id else { return }
            self.elementalBurst = nil
        }
    }
}

// MARK: - Derived view state

extension GameSession {

    /// The sign currently being controlled.
    var zodiac: Zodiac { engine.piece.zodiac }

    /// The plane the camera is showing — always the one the piece is on.
    var visiblePlane: Plane { engine.piece.plane }

    /// The board being rendered in the top half of the screen.
    var visibleBoard: Board { engine[visiblePlane] }

    /// Every square the piece could move to this turn, and the swipe that gets
    /// it there.
    ///
    /// The tap-a-square control scheme is the whole reason this exists: it needs
    /// the inverse of the usual question. Everything else in the game asks
    /// "where does this direction lead"; the pad asks "which direction leads
    /// here", and gets the reach along with it so a sign with several distances
    /// in one direction still resolves to the right one.
    ///
    /// Nearest first, so a square reachable two ways is credited to the shorter
    /// move — which is the one that wears less ground.
    var reachableSquares: [GridPoint: (direction: SwipeDirection, reach: Int)] {
        var found: [GridPoint: (direction: SwipeDirection, reach: Int)] = [:]

        for direction in SwipeDirection.allCases {
            let options = engine.moveOptions(for: direction)
            for (reach, _) in options.enumerated() {
                guard let move = engine.resolvedMove(for: direction, reach: reach),
                      let destination = move.path.last
                else { continue }
                if found[destination] == nil {
                    found[destination] = (direction, reach)
                }
            }
        }
        return found
    }

    /// The plane the piece would fall to, or `nil` on Terra.
    var planeBelow: Plane? { visiblePlane.planeBelow }

    /// The board under the current one, for the small preview in the info
    /// panel. `nil` on Terra, where there is nothing below.
    var boardBelow: Board? { planeBelow.map { engine[$0] } }

    /// Sparkles to draw, but only if they belong to the visible plane.
    var visibleSparkles: SparkleSet? {
        guard let sparkles = engine.sparkles, sparkles.plane == visiblePlane else { return nil }
        return sparkles
    }

    /// The revealed pickups on the visible plane. Usually one, occasionally two.
    var visiblePickups: [RevealedPickup] {
        engine.revealedPickups.filter { $0.plane == visiblePlane }
    }

    /// The popped-up squares, which are not always under a coin — see
    /// `GameEngine.raisedTiles`.
    var visibleRaisedTiles: [RevealedPickup] {
        engine.raisedTiles.filter { $0.plane == visiblePlane }
    }

    /// Sagittarius' arrow, if it is standing on the plane being looked at.
    var visibleArrow: SignState.Arrow? {
        guard let arrow = engine.signState.arrow, arrow.plane == visiblePlane else { return nil }
        return arrow
    }

    /// Leo's sun, if it is burning on the plane being looked at.
    var visibleSun: SignState.Sun? {
        guard let sun = engine.signState.sun, sun.plane == visiblePlane else { return nil }
        return sun
    }

    /// How long the current hop takes.
    ///
    /// Scales with distance only if `hopDurationPerExtraTile` is non-zero; at
    /// its default of zero every hop takes the same time however far it goes.
    /// Read by both the animation and the beat the replay waits, so the two can
    /// never disagree about how long a hop is.
    var hopDuration: TimeInterval {
        GameRules.hopDuration
            * (1 + Double(hopDistance - 1) * GameRules.hopDurationPerExtraTile)
    }

    /// True while the player may act.
    ///
    /// A first-encounter strip and an unanswered Pentacle both block input as
    /// hard as a resolving move does — the game is turn-based, and a turn that
    /// has not finished resolving accepts nothing.
    /// The reach that selects this sign's *longer* move in a direction, or
    /// `nil` when it has none that way.
    ///
    /// Scheme A gets distance from how far the drag ran; scheme B has no drag,
    /// so the longer move needs its own button and this is what decides whether
    /// to offer one. Asked of the pattern rather than hardcoded per sign, so a
    /// retuned movement changes the buttons with it.
    func specialReach(for direction: SwipeDirection) -> Int? {
        // Asked of the engine rather than of the pattern, so an option a passive
        // refuses *here* — Scorpio's vault with no hole under it, Sagittarius'
        // stride on cooldown — is not drawn as a chevron the player cannot
        // reach.
        let options = engine.moveOptions(for: direction)

        guard let longest = options.map(\.distance).max(), longest > 1 else { return nil }

        // Reach counts steps past the first, so the longest option is one less
        // than its distance.
        return longest - 1
    }

    var acceptsInput: Bool {
        phase == .awaitingInput && pentacleIntro == nil && pendingPickupChoice == nil && !isPaused
    }

    /// Whether a control should still *report* what the player did, even though
    /// the move itself will not be played.
    ///
    /// The splash is dismissed by reaching for the controls — so the controls
    /// have to be live enough to notice. Gating them on `acceptsInput`, which is
    /// false precisely *because* the splash is up, left it on screen with no way
    /// to put it away.
    var acceptsGesture: Bool {
        // A question counts too: the stick and the pad steer the *aim* while one
        // is open, so they have to be live enough to report a direction even
        // though no move will be played.
        acceptsInput || pentacleIntro != nil || isChoosingTile
    }

    /// True while the player is being asked to pick a square on the board.
    var isChoosingTile: Bool {
        switch pendingPickupChoice?.kind {
        case .tile, .among, .place: true
        default: false
        }
    }

    /// Records that a slab is on its way in, so its arrival can be drawn.
    func notePlacedSlab(_ slab: GavelSlab) { placedSlab = slab }

    /// Whether this square is an answer the outstanding question would accept.
    ///
    /// One definition, asked by both the pad that collects the answer and the
    /// cursor that reports it. Two would drift, and the drift would show as a
    /// green bracket over a square the pad then refused.
    func isLegalTarget(_ point: GridPoint) -> Bool {
        if let slab = placingSlab {
            return slab.canBePlaced(anchoredAt: point, on: engine.currentBoard)
        }
        if let allowed = choosableTiles {
            return allowed.contains(point)
        }
        // A free tile question takes anything, holes included — that is the
        // whole of Astral Breeze.
        return isChoosingTile
    }

    /// Steps the aim one square, and reports whether it took the input.
    ///
    /// Clamped rather than wrapped, and it consumes the press either way: a
    /// cursor that fell off the east edge and reappeared in the west would be
    /// unreadable, and one that let the keystroke through to the piece would
    /// move the piece while the player thought they were aiming.
    @discardableResult
    func nudgeTarget(_ direction: SwipeDirection) -> Bool {
        guard isChoosingTile else { return false }

        let from = targetAim ?? engine.piece.point
        let next = from.offset(by: direction.unitOffset)
        if engine.currentBoard.contains(next) { targetAim = next }
        return true
    }

    /// Moves the aim. Ignored when nothing is being asked.
    func aimTarget(_ point: GridPoint?) {
        guard pendingPickupChoice != nil else { return }
        targetAim = point
    }

    /// The slab Libra is being asked to place, if that is the outstanding
    /// question. See `GaleforceGavelEffect`.
    var placingSlab: GavelSlab? {
        if case let .place(slab) = pendingPickupChoice?.kind { return slab }
        return nil
    }

    /// The squares that would be a legal answer, or `nil` when every square is.
    ///
    /// `PickupChoice.tile` deliberately allows anything, holes included — see
    /// `TileChoiceOverlay`. `PickupChoice.among` names its handful.
    var choosableTiles: [GridPoint]? {
        if case let .among(points) = pendingPickupChoice?.kind { return points }
        return nil
    }

    /// True when the outstanding question is an offer the player may walk away
    /// from rather than one they must answer.
    var choiceIsDeclinable: Bool {
        if case .among = pendingPickupChoice?.kind { return true }
        return false
    }

    /// True while the player is being asked to pick a sign.
    var isChoosingPiece: Bool { pendingPickupChoice?.kind == .piece }

    /// Every direction the piece has at least one legal move in.
    ///
    /// Drives the joystick's guides and, more importantly, whether a drag is
    /// resolved into eight sectors or four. A sign that cannot step diagonally
    /// must not have its sloppy 40° swipes rejected for aiming between two
    /// buttons — so the diagonals only exist as inputs for a piece that can use
    /// them.
    var availableDirections: Set<SwipeDirection> {
        // The whole company, so a phantom's diagonal shows up on the stick —
        // see `GameEngine.activeMovement`.
        let movement = engine.activePassives.adjustedMovement(
            base: engine.activeMovement,
            context: engine.passiveSnapshot
        )
        return Set(SwipeDirection.allCases.filter { direction in
            !movement.options(for: direction, facing: engine.piece.facing).isEmpty
        })
    }

    /// True when this piece can aim between the cardinals.
    var movesDiagonally: Bool {
        availableDirections.contains { !$0.isCardinal }
    }

    /// True while Sagittarius has an arrow in the ground waiting to be recalled.
    ///
    /// The Zodiaction button reads this: with an arrow out the button is no
    /// longer charging anything, it is a recall, and it says so.
    var arrowIsPlanted: Bool { engine.signState.arrow != nil }

    /// True while Capricorn's shop strip is open.
    var isChoosingShop: Bool { pendingPickupChoice?.kind == .shop }

    /// The distances available along the drag in progress, nearest first.
    ///
    /// Empty when there is no drag, and of length one for the signs whose
    /// movement has nothing to choose between — the selector hides itself in
    /// both cases rather than showing a control with a single setting.
    var previewOptions: [MovementPattern.MoveOption] {
        guard let direction = previewDirection else { return [] }
        return engine.moveOptions(for: direction)
    }

    /// Which of `previewOptions` the current drag has selected.
    var previewOptionIndex: Int {
        guard !previewOptions.isEmpty else { return 0 }
        return min(max(previewReach, 0), previewOptions.count - 1)
    }

    /// Super meter as a 0…1 fraction, for the meter bar.
    var zProgress: Double {
        guard engine.zodiactionMeterMax > 0 else { return 0 }
        return min(Double(engine.zodiactionMeter) / Double(engine.zodiactionMeterMax), 1)
    }
}

// MARK: - GamePhase

/// What the session is doing right now.
///
/// Input is only accepted in `awaitingInput`, which is what keeps a burst of
/// swipes from queueing up behind a move that is still playing out.
enum GamePhase: Equatable {
    /// Idle, ready for a swipe or a super.
    case awaitingInput

    /// Replaying a planned move or super.
    case resolvingMove

    /// The run is over; only "play again" is available.
    case gameOver
}
