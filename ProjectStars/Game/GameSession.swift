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

    /// Whether the meter is full, regardless of whether this square will take
    /// the Zodiaction. What the piece *looks* like — see
    /// `GameEngine.isZodiactionCharged`.
    private(set) var isZodiactionCharged = false

    #if DEBUG
    /// A Pentacle chosen in the spawner, waiting for a square.
    ///
    /// Not in `#if DEBUG` on its own would be tidier, but `@Observable` does not
    /// generate accessors for stored properties inside a conditional block — so
    /// a flag declared that way changes without the view ever hearing about it.
    /// This one is outside for that reason; the *uses* are gated instead.
    /// - TODO: **Debug only.** Never ships.
    #endif
    var debugSpawning: PickupID?

    /// When the storm last went from nothing to something, or `nil`.
    ///
    /// Watched rather than told: the phase is derived from the meter, and the
    /// meter changes from a dozen places. A flag every one of them had to
    /// remember to set is a flag that will be missed.
    private(set) var stormWokeAt: Date?

    /// The last phase seen, so the crossing can be spotted.
    private var lastStormPhase = 0

    /// Notices the storm waking. Called wherever the meter settles.
    func noteStormPhase(_ phase: Int) {
        defer { lastStormPhase = phase }

        // **Either crossing.** Waking and going out are the same event seen
        // from opposite sides — the storm arriving around the pot, or leaving
        // it — and the art reads correctly both ways. Only firing on the way up
        // meant the moment he is emptied, which is the moment that matters most
        // for this sign, happened in silence.
        let crossed = (lastStormPhase == 0) != (phase == 0)
        guard zodiac == .aquarius, crossed else { return }
        stormWokeAt = .now

        Task { [weak self] in
            try? await Task.sleep(
                nanoseconds: UInt64(EffectSprite.aquariusZodiaction.duration * 1_000_000_000)
            )
            self?.stormWokeAt = nil
        }
    }

    /// Aquarius' storm, drawn once per phase and played back. See
    /// `AquariusStormFilm`.
    let stormFilm = AquariusStormFilm()

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
        // Not held back with it. Being charged does not depend on where the
        // piece is standing, so there is nothing to strobe — and a meter that
        // fills mid-move should light the statue the moment it does.
        isZodiactionCharged = engine.isZodiactionCharged
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
    /// Only ever moves one way for any given faller, so the spin keeps turning
    /// instead of unwinding back the way it came at the halfway point.
    private(set) var fallSpin: Double = 0

    /// Which way the piece currently tumbles, as a multiplier on the fall spin.
    ///
    /// Everything in the game falls counter-clockwise except Gemini's silver
    /// twin, which turns the other way — the two halves are a mirrored pair, and
    /// a mirror reverses the direction of a turn. It is also the fastest way to
    /// tell at a glance which of them you are holding.
    /// How far a fall turns the piece, and which way.
    ///
    /// **Zero while the storm is up.** Spinning is what a solid thing does when
    /// the ground goes: it has a top and a bottom and loses track of which is
    /// which. A funnel has neither — it is already turning about its own axis —
    /// so end-over-end reads as the sprite being thrown rather than as the sign
    /// falling.
    ///
    /// At an empty meter it tumbles like anything else, which is the point of
    /// draining the meter before a death: what falls is the little pot.
    private var tumble: Double {
        guard !engine.floatsOverHoles else { return 0 }
        return GameRules.fallSpinDegrees / 2 * tumbleDirection
    }

    private var tumbleDirection: Double {
        engine.piece.twin == .silver ? -1 : 1
    }

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

    /// The preview riding down into the board, or `nil`.
    ///
    /// The phantom belongs to the *choice* while a choice is being made, and the
    /// choice ends the instant the player commits — so without this the preview
    /// blinked out of existence and the squares appeared underneath it. It is
    /// handed over here at the same position it was already floating at, and
    /// closes the gap it was hovering over while it fades.
    private(set) var slabDrop: SlabDrop?

    /// One preview falling the last tile into place.
    struct SlabDrop: Equatable {
        let slab: GavelSlab
        let anchor: GridPoint
        let plane: Plane
        let start: Date
    }


    /// When the island began carrying the piece up out of Terra, or `nil`.
    private(set) var ascentRiseStartedAt: Date?


    // MARK: - Where the camera is

    /// Which row of the world the camera is looking at, from the top.
    ///
    /// Fractional while anything is travelling. The camera keeps the row being
    /// stood on in the upper square, so standing still this is simply
    /// `World.row(of:)` for the current plane — and a plane change is this
    /// number going up rather than a board being swapped underneath a curtain.
    ///
    /// The piece is drawn against it too, at the same value in the same
    /// transaction, so the two cannot drift: while it moves, the piece is
    /// visually still and the world goes past it, which is what falling looks
    /// like from inside.
    private(set) var cameraRow: Double = Double(World.row(of: .astra))

    /// Whether the piece is falling back into the world on a seamless restart.
    ///
    /// A run that has begun, on a board that is ready, with a piece that is not
    /// on it yet. Nothing else in the game is in that state — every other way in
    /// waits behind a card — so it needs saying rather than deriving.
    private(set) var isDropping = false

    /// Where a piece that has fallen out of the world is settling to.
    ///
    /// The middle of the board — which is the Nexys' own square, and therefore
    /// exactly where a restart puts it back. It slides there on the way down
    /// rather than landing wherever it happened to fall through, so the run
    /// ends and begins in the same place and the card has something centred to
    /// be built around.
    private(set) var deathSeat: GridPoint?

    /// Raised when the player asks to leave the death screen.
    ///
    /// The card arrives by sliding its two bars across the screen and it should
    /// go the same way, for the same reason the mode card does: the bars never
    /// reverse, they arrive and they leave. Without this the run restarted out
    /// from under a card that was still sitting there.
    private(set) var deathCardIsLeaving = false

    /// How far through a crossing the camera is, `0`…`1`.
    ///
    /// Measured off the camera rather than a clock, so anything reading it
    /// cannot disagree with what is on screen about where the piece has got to.
    var fallProgress: Double {
        guard isChangingPlane, let from = cameraFrom else { return 1 }
        let span = Double(World.row(of: engine.piece.plane.opposite)) - from
        guard abs(span) > 0.001 else { return 1 }
        return min(max((cameraRow - from) / span, 0), 1)
    }

    /// Whether the piece is on its way from one plane to another.
    ///
    /// True for every kind of crossing — a fall through a hole, a climb, a ride
    /// on the island — and false for falling out of the world, which arrives
    /// nowhere and so has no new material to take.
    ///
    /// It is what decides when the piece is gold. Gold is the material of a
    /// thing that belongs to neither plane, so it has to last exactly as long as
    /// that is true: from the moment the crossing starts to the moment it lands.
    /// Read off `piece.plane` instead, the swap happened wherever the board
    /// happened to be exchanged — which for a ride is half way through.
    private(set) var isChangingPlane = false

    /// Whether the island is travelling *with* the camera rather than standing
    /// still while the camera moves past it.
    private(set) var nexysRidesCamera = false

    /// Where the camera set off from, while it is travelling. `nil` at rest.
    ///
    /// Only ever read to decide what may sleep — see
    /// `World.isVisible(row:sweeping:to:)` for why an animated number cannot be
    /// asked that question directly.
    private(set) var cameraFrom: Double?



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
    /// When the last rejected swipe was, or `nil` for none.
    ///
    /// A timestamp rather than a counter. The shove used to be drawn while the
    /// counter was **odd**, which made it a toggle rather than a pulse: the
    /// first rejected swipe pushed the board six points and left it there until
    /// the next one pushed it back. The board genuinely rested in two different
    /// places on alternating nudges.
    private(set) var blockedAt: Date?

    private(set) var blockedNudge: Int = 0

    /// The direction of the most recent rejected swipe, for the nudge offset.
    private(set) var blockedDirection: SwipeDirection?

    /// Set while the piece is mid-drop between planes; the piece view shrinks
    /// and fades on this.
    private(set) var isFalling = false

    /// What game this run is. See `GameMode`.
    var mode: GameMode = .survival

    /// The passive announcements on screen, oldest first. Never more than two.
    ///
    /// See `announce(passive:)` for the rules that keep it to two.
    private(set) var passivePrompts: [PassivePrompt] = []

    /// True once the card's bars have finished arriving.
    ///
    /// The panel waits for it before anything on it starts moving. Two things
    /// animating at once on two screens is two things asking to be looked at,
    /// and the card is the one with something to say.
    var modeCardHasLanded = false

    /// True once Start has been pressed and the card is on its way out.
    ///
    /// Separate from clearing `modeCard`, because the bars have to be told to
    /// leave and then given the time to do it — cleared outright they would
    /// vanish rather than slide off.
    private(set) var modeCardIsLeaving = false

    /// Whether the run is still waiting behind the card.
    var isAwaitingStart: Bool { modeCard != nil && !modeCardIsLeaving }

    /// Whether a run is live: begun, and not yet lost.
    ///
    /// The two ways a run stops being live — waiting on the start button, and
    /// ending — are asked about separately everywhere else, because they mean
    /// different things. This is for the one question that does not care which:
    /// the panel shows its controls exactly when there is something to control.
    var isRunning: Bool { !isAwaitingStart && phase != .gameOver }

    /// The mode being announced right now, or `nil` between runs.
    ///
    /// Holds the mode rather than a flag so the card can outlive a change of
    /// mode mid-dismissal — it announces the run it opened, not whatever is
    /// selected by the time it finishes leaving.
    var modeCard: GameMode?

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
        // Nothing to press when there is no square. A landing outside the board
        // is the run ending, and the rim has no surface to give.
        guard let tile = engine[plane].tile(at: point) else { return }

        // Cloud and the island give; stone does not.
        guard plane == .astra || tile.kind == .nexys else { return }

        let bounce = SurfaceBounce(point: point, plane: plane, start: .now)
        surfaceBounce = bounce

        Task { [weak self] in
            // Outlives the give rather than matching it — see
            // `GameRules.surfaceBounceHold`. Everything that reads this ends on
            // its own clock, and clearing it at the give's own length put a
            // ceiling on all of them.
            try? await Task.sleep(
                nanoseconds: UInt64(GameRules.surfaceBounceHold * 1_000_000_000)
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

    /// The square a spill of bubbles flew out of, and when.
    ///
    /// Bubbles land on their squares the instant they are revealed, which reads
    /// as *having always been there* — the exact complaint rings would draw if
    /// they appeared in a ring instead of flying into one. This is what lets the
    /// board draw the first moment of their lives somewhere else.
    private(set) var bubbleScatter: BubbleScatter?

    /// One eruption of bubbles: where from, when, and in what order they left.
    struct BubbleScatter: Equatable {
        let origin: GridPoint
        let start: Date

        /// The squares being thrown at, in the order they were thrown. Position
        /// in this list is the stagger — they leave one after another rather
        /// than as a single spray.
        var points: [GridPoint] = []
    }

    /// Adds a bubble to the throw, starting one if none is running.
    ///
    /// Cleared once the last of them has landed, so the timer is extended by
    /// each new bubble rather than being restarted.
    func throwBubble(to point: GridPoint, from origin: GridPoint) {
        if bubbleScatter?.origin != origin { bubbleScatter = BubbleScatter(origin: origin, start: .now) }
        bubbleScatter?.points.append(point)

        let count = bubbleScatter?.points.count ?? 1
        let plane = engine.piece.plane

        // Its own arrival, a beat behind the bubble before it. The splash is
        // what makes the landing an event rather than the animation running out
        // — the same strip that goes off at the fish's feet on the way out, so
        // the two ends of the throw match.
        let arrival = GameRules.bubbleScatterDuration
            + GameRules.bubbleScatterStagger * Double(count - 1)

        Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(arrival * 1_000_000_000))
            // Water, then the burst, then the splash on top.
            //
            // Later bursts draw in front, so the order here is the order the
            // eye reads: the droplet arrives, the water it is made of gives up
            // its shape, and the ground answers last. Splashing first put the
            // tile's reaction underneath the thing that caused it.
            // Swapped onto the cold ramp. Sampled from `droplet.png` rather
            // than guessed: it is drawn in yellowGreen, ice, neonGreen and
            // cyan, which is a green-blue ramp, and the two lightest both land
            // on ice so the three-tone result keeps its shading.
            self?.playEffect(
                .droplet,
                at: point,
                on: plane,
                swaps: [
                    PaletteSwap(Palette.yellowGreen, Palette.ice),
                    PaletteSwap(Palette.ice, Palette.ice),
                    PaletteSwap(Palette.neonGreen, Palette.cyan),
                    PaletteSwap(Palette.cyan, Palette.sky)
                ]
            )
            self?.playEffect(.waterSplash, at: point, on: plane)
        }

        let lifetime = GameRules.bubbleScatterDuration
            + GameRules.bubbleScatterStagger * Double(count)

        Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(lifetime * 1_000_000_000))
            guard let self, self.bubbleScatter?.points.count == count else { return }
            self.bubbleScatter = nil
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
        let style: MoveType
        let direction: SwipeDirection
        let start: Date
        let duration: TimeInterval

        /// How far through it is, `0`…`1`.
        func progress(at now: Date) -> Double {
            guard duration > 0 else { return 1 }
            return min(max(now.timeIntervalSince(start) / duration, 0), 1)
        }
    }

    /// Which way the piece is looking, as drawn.
    ///
    /// **A move turns the figure as it leaves, not as it lands.** The engine
    /// only records the new facing once the move resolves, so reading that
    /// straight had the piece travel the whole way still facing where it came
    /// from and snap round on arrival — the turn arriving last is what made it
    /// look like an afterthought.
    var visibleFacing: SwipeDirection {
        // **Nothing in the air is walking anywhere.**
        //
        // The engine turns the piece south the moment a fall or a ride is
        // decided, and that turn was then thrown away here: a movement is still
        // running when the square gives way, and a movement outranked the
        // facing. So the piece fell in whatever direction it had been going and
        // snapped south on landing, which is the one moment it should not have
        // been turning.
        if isChangingPlane || isFalling { return engine.piece.facing }
        guard let movement else { return engine.piece.facing }
        return movement.direction.facing(from: engine.piece.facing)
    }

    /// Starts the clock for a movement of `style`.
    func beginMovement(_ style: MoveType, direction: SwipeDirection, duration: TimeInterval) {
        movement = Movement(
            style: style,
            direction: direction,
            start: .now,
            duration: duration
        )
    }

    /// And stops it.
    func endMovement() { movement = nil }

    /// When the run began, for the arrival wash. `nil` once it has faded.
    private(set) var spawnedAt: Date?

    /// How white the piece still is, `1`…`0`, as it resolves out of the spawn.
    var spawnWash: Double {
        guard let spawnedAt else { return 0 }
        let elapsed = Date().timeIntervalSince(spawnedAt)
        guard elapsed < GameRules.spawnWashDuration else { return 0 }
        return 1 - elapsed / GameRules.spawnWashDuration
    }

    private(set) var leapStartedAt: Date?

    /// The shape of the leap currently in the air. See `HopPose.Weight`.
    private(set) var leapWeight: HopPose.Weight = .dive

    /// True while the piece is climbing away off the top of the board.
    private(set) var isLaunching = false

    /// Throws the piece into the air and waits out the arc.
    /// A deliberate leap, played out in full.
    ///
    /// The bull's is its own shape and its own length — see `HopPose.Weight` —
    /// and it hits the ground hard enough to be felt. The shake is scheduled
    /// for the moment of the pancake rather than the end of the arc, because
    /// the impact is what shakes the board and the flattening *is* the impact.
    func playLeap(weight: HopPose.Weight = .dive) async {
        let duration = weight == .flop ? GameRules.flopDuration : GameRules.leapDuration
        leapWeight = weight
        leapStartedAt = .now
        beginMovement(
            .superJump,
            direction: engine.piece.facing,
            duration: duration
        )
        defer { endMovement() }

        // The pancake begins at 0.8 of the arc — `HopPose.leapStops`.
        if weight == .flop {
            await sleep(duration * 0.8)
            shake(for: GameRules.arrowLandShake, strength: GameRules.flopShake)
            Haptics.longer()
            // The **fall's** cloud, not a footfall's — the same one a piece
            // dropping out of Astra throws, because that is the weight the
            // landing is claiming to have.
            kickUpDust(
                at: engine.piece.point,
                on: engine.piece.plane,
                magnitude: GameRules.smokeFallMagnitude
            )
            await sleep(duration * 0.2)
        } else {
            await sleep(duration)
        }

        leapStartedAt = nil
        leapWeight = .dive
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

    /// While the lion's mane is lit, or `nil`.
    ///
    /// The mane is gemstone now, so it lights through the same swap the gem
    /// does — which means "blazing" is just `isCharged` being true for a moment
    /// that has nothing to do with the meter. Nothing new has to be drawn.
    private(set) var maneBlazeUntil: Date?

    /// True while it is lit.
    var isManeBlazing: Bool {
        guard let until = maneBlazeUntil else { return false }
        return until > .now
    }

    /// Lights it, briefly.
    private func blazeMane() {
        maneBlazeUntil = .now.addingTimeInterval(GameRules.maneBlazeDuration)
        Task { [weak self] in
            try? await Task.sleep(
                nanoseconds: UInt64(GameRules.maneBlazeDuration * 1_000_000_000)
            )
            guard let self, !self.isManeBlazing else { return }
            self.maneBlazeUntil = nil
        }
    }

    /// True once the mane's ring has been thrown this move.
    ///
    /// Two coins pulled on one turn is one pull, and two rings on the same
    /// square at the same instant is a brighter ring rather than a second
    /// event.
    private var manePulledThisMove = false

    /// Sparkles coming apart as the phase ends, one per square that was lit.
    ///
    /// A list because they all go together — the existing `collectBurst` is a
    /// single value, which is right for a coin being taken and wrong for five
    /// squares giving up at once.
    private(set) var sparkleDispersals: [ElementalBurst] = []

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

    /// Something is holding the board: watch, do not play.
    ///
    /// **Raised by whatever needs it**, and named for what it does rather than
    /// for who asked. A ground wave sets it today; the next thing that wants
    /// the player to sit still sets the same flag instead of inventing a second
    /// one, which is what stops the dim from becoming a list of features that
    /// the view has to keep in step.
    ///
    /// Cleared at the end of the plan that raised it — see `replay`.
    private(set) var isHoldingBoard = false

    /// When the Polarity Prongs began falling, or `nil` when none are.
    ///
    /// Drives the descent in `BoardView.prong`: the shards start high and
    /// arrive over `GameRules.prongFallDuration`, with the board held still
    /// underneath them.
    private(set) var prongsFalling: Date?

    /// Whether the board is dimmed, for any reason at all.
    ///
    /// The single question the view asks. It used to ask two — "is a tile being
    /// chosen, or is a sweep running" — which meant every new reason to dim was
    /// an edit in `BoardView` as well as here, and the two drifting apart was a
    /// matter of time.
    var isDimmed: Bool { isChoosingTile || isHoldingBoard }

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

    /// How hard the next tile-damage should shake the screen, if a tremor is
    /// what caused it.
    ///
    /// Set when the coin opens and spent by the damage it deals, for the same
    /// reason `mending` is: the event that lands says *what* changed, and only
    /// the coin knows *why* — and a shake on every crack in the game would make
    /// the board feel like it was falling apart on an ordinary step.
    private var pendingTremor: CGFloat?

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

    /// The dust currently settling.
    ///
    /// A list rather than one puff, because a landing is not always one impact:
    /// Libra comes down on two pans and cracks the squares either side of her,
    /// which is two clouds in two places at once. Each puff clears itself when
    /// its own run is up.
    private(set) var smoke: [SmokePuff] = []

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

        // The first run of the app opens the same way every later one does.
        // `newGame` announces the mode, and the very first board never goes
        // through it — it is built here — so the card would have been the one
        // thing a player saw on every run except their first.
        modeCard = mode
        modeCardIsLeaving = false
        modeCardHasLanded = false
        passivePrompts = []
    }

    /// Abandons the current run and starts a new one.
    /// - Parameter announced: Whether the mode card goes up and the run waits on
    ///   the start button. False for a seamless restart, which is already in
    ///   motion and has nothing to announce — see `restartRunSeamlessly`.
    func newGame(zodiac: Zodiac? = nil, seed: UInt64? = nil, announced: Bool = true) {
        replayTask?.cancel()
        replayTask = nil

        // Every run opens by saying what it is. Set before the board is built
        // rather than after, so the card is already up while the first frame of
        // a fresh board is being put together.
        modeCard = announced ? mode : nil
        modeCardIsLeaving = false
        modeCardHasLanded = false

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
        ascentRiseStartedAt = nil
        cameraRow = Double(World.row(of: engine.piece.plane))
        cameraFrom = nil
        nexysRidesCamera = false
        isChangingPlane = false
        isDropping = false
        deathSeat = nil
        deathCardIsLeaving = false
        isLaunching = false
        nexysDepartStartedAt = nil
        nexysArriveStartedAt = nil
        lastCollectedPickup = nil
        pentacleBanner = nil
        elementalBurst = nil
        sparkleDispersals = []
        effectBursts = []

        // **After the reset, not before it.** This used to be queued up with
        // the rest of the state and then cleared two lines later by the very
        // wipe that empties the board of last run's effects — so the entrance
        // was played and thrown away every time.
        // Only for a run that is *appearing*. A seamless restart's piece has been
        // on screen and turning for the last ten seconds, and a
        // resolve-into-being flash on it would be the game admitting it swapped
        // the piece out.
        if announced {
            spawnedAt = .now
            playEffect(.spawn, at: engine.piece.point, on: engine.piece.plane, glows: true)
        }
        healSparkles = []
        nexysCarryingPiece = false
        coinFlight = nil
        leapStartedAt = nil
        surfaceBounce = nil
        cloudWake = nil
        pressedTiles = []
        bubbleScatter = nil
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
        smoke = []
        bufferedMove = nil
        slabDrop = nil
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
    /// Where the piece is being aimed, for the cursor.
    ///
    /// **Reversed too.** This is the half of the control scheme the player
    /// actually reads: the cursor is where they are told the move lands, so a
    /// cursor showing the asked-for direction while the piece goes the other way
    /// is not a reversed control, it is a lying one — and at phase zero, where
    /// the move is a single hop, it reads as the piece jumping the wrong way and
    /// touching two squares.
    func preview(direction: SwipeDirection?, reach: Int) {
        // A drag that has only just started counts too: the splash should be
        // gone by the time the stick has anything to say.
        if direction != nil { dismissIntroIfShowing() }

        previewDirection = direction
        previewReach = reach
    }

    /// - Parameter reach: Which of the distances available that way the drag
    ///   selected. Ignored by patterns offering only one.
    func submit(_ rawDirection: SwipeDirection, reach: Int = 0) {
        // **Turned around at the door.**
        //
        // One place, and the outermost one: everything past here — the cursor,
        // the reach selector, the projection, the engine — deals in where the
        // piece is actually going, so nothing downstream has to know the sign
        // is reversed. Flipping it any deeper would mean every one of those
        // asking the same question and one of them eventually forgetting.
        //
        // The board is not reversed, only the *instruction*. Aiming at a square
        // still means that square; asking to go north is what means south.
        // **Turned around here and nowhere else.**
        //
        // This is the outermost point a player's instruction reaches, and past
        // it everything — the cursor, the reach selector, the engine — is
        // already dealing in where the piece is going rather than what was
        // asked for.
        //
        // Moving it deeper was an attempt to catch the paths that skip
        // `submit`, and it cost more than it fixed: the engine reverses on
        // behalf of callers that had already reversed, and the cursor ends up
        // dragged along behind the piece instead of sitting on its target.
        let direction = engine.controlsAreReversed ? rawDirection.opposite : rawDirection

        // Reaching for the controls is how the splash is put away, and that
        // input is spent doing it.
        if dismissIntroIfShowing() { return }

        // While a question is open, movement steers the answer instead of the
        // piece. Same keys, same stick, same buttons — there is only ever one
        // thing on screen asking to be pointed at.
        if nudgeTarget(direction) { return }

        // A move asked for while the last one is still playing is *remembered*,
        // not thrown away.
        //
        // ## Why this exists
        //
        // A turn is longer than the hop inside it — the piece lands, then the
        // ground flashes, then the next sparkles arrive — and input is shut for
        // all of it. A player flicking at a comfortable pace gets a second flick
        // in before that tail is over, and the game answered by doing nothing at
        // all. Nothing on screen explains that, so it reads as the input having
        // been missed, which is the worst thing a turn-based game can look like.
        //
        // Only the *last* request is kept, so a flurry does not queue up five
        // moves and then play them at the player. And only briefly: an input
        // held over a long animation — a Zodiaction, a fall between planes — is
        // an input about a board that no longer exists, and playing it when the
        // dust settles would be a lurch nobody asked for.
        if phase == .resolvingMove, pentacleIntro == nil, pendingPickupChoice == nil, !isPaused {
            // **The direction as asked, not as turned around.**
            //
            // This goes back through `submit`, which reverses — so storing the
            // reversed one had it flipped twice and the piece stepped back the
            // way it came. Only reachable by inputting faster than a turn
            // plays, which is why it looked like a phase-zero bug: above zero
            // she slides, and a slide is long enough that the second input
            // lands after the first has finished rather than during it.
            bufferedMove = (rawDirection, reach, Date.now)
            return
        }

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

    // MARK: - Shipping state that lives near the debug block
    //
    // These are **not** debug-only. They were inside `#if DEBUG` by
    // position rather than by intent — the block above grew downward past
    // them — so a Release build had no `isFractured`, no `controlScheme`
    // and no way to steer. Debug compiled, which is why it went unnoticed.
    /// True while the world should look torn — see `FractureField`.
    var isFractured: Bool { isSplit || debugFissure }


    /// Forces the Fracturing Fissure's screen effect on, for looking at it.
    ///
    /// Separate from `isSplit` rather than faking one: a split is a rule and
    /// this is a picture, and a debug key that put the engine into a real split
    /// would be testing the wrong thing.
    ///
    /// ## Why this is not inside `#if DEBUG`
    ///
    /// Because `@Observable` does not reach into conditional-compilation blocks:
    /// a stored property declared inside one gets no observation accessors, so
    /// writing to it changes the value and tells nobody. The toggle flipped and
    /// the screen never redrew. Every other debug member here is a *function*,
    /// which is why nothing had hit this before.
    ///
    /// A single always-false `Bool` in release is cheaper than the hour this
    /// cost. The key that sets it is still debug-only.
    var debugFissure = false

    /// How the player is steering, right now.
    ///
    /// ## Why this is not read straight off `GameRules`
    ///
    /// Because a `static var` is invisible to observation. The panel read the
    /// global directly, so flipping it changed nothing on screen until some
    /// *other* observable write happened to redraw the panel — and the nearest
    /// one is `publish()`, which is turn-shaped. That made a preference appear
    /// to apply on your next move, as though how you steer were a rule of the
    /// game rather than a setting.
    ///
    /// The global stays as the seed and is kept in step, so anything reading it
    /// outside a view still sees the truth.
    var controlScheme: GameRules.ControlScheme = GameRules.controlScheme

    /// Cycles the control scheme.
    ///
    /// Not a debug affordance any more: how you steer is a preference, and one
    /// the player has to be able to change from inside a run — the schemes feel
    /// different enough that nobody can pick between them from a menu they have
    /// not played behind. It stands in for a settings screen until there is one.
    /// What pressing the control button would switch to.
    ///
    /// Exposed rather than worked out again in the view, because the button
    /// *shows* its destination — so the order is now drawn on screen as well as
    /// acted on, and two copies of it would be two chances to disagree.
    var nextControlScheme: GameRules.ControlScheme {
        let all = GameRules.ControlScheme.allCases
        let next = (all.firstIndex(of: controlScheme) ?? 0) + 1
        return all[next % all.count]
    }

    func cycleControls() {
        controlScheme = nextControlScheme
        GameRules.controlScheme = controlScheme
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
        // Charged to ready rather than to full — see `planFillZodiaction`.
        if !engine.meterIsAtFiring {
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





















    var debugArrowYTerraNS: Double = 1
    var debugArrowYAstraNS: Double = 1


    #if DEBUG
    func debugToggleFissure() { debugToggleFissureImpl() }
    private func debugToggleFissureImpl() { debugFissure.toggle() }
    #endif


    /// Moves the meter one pip, in raw terms. Debug builds only.
    ///
    /// **Raw, not "toward firing".** Everything else in the engine asks the
    /// second question, and rightly — but for testing, "put the number up" and
    /// "put the number down" are what is wanted, so a backwards sign can be
    /// walked through both halves of its meter without having to think about
    /// which way its hunt runs.
    func debugNudgeMeter(by amount: Int) {
        let target = min(max(engine.zodiactionMeter + amount, 0), engine.zodiactionMeterMax)
        guard target != engine.zodiactionMeter else { return }
        run([.zodiactionMeterChanged(to: target)])
    }

    /// Stages the Astral Bolt as the next Pentacle. Debug builds only.
    ///
    /// Only the *next* one, and it does not disturb the coin already on the
    /// board — take that one, and the set that replaces it is the Bolt.
    #if DEBUG
    #endif

    func debugStageLightning() {
        engine.debugNextPickup = .astralBolt
    }

    /// Stages Polaris as the next Pentacle. Debug builds only.
    ///
    /// Staged rather than placed, like the Bolt, so it arrives through the
    /// ordinary reveal and is the ordinary thing — a coin that is put on the
    /// board by hand skips the spawn rules, and the spawn rules are half of what
    /// makes this one Polaris. It still lands where the sparkles say, and it
    /// still arrives cold on Terra.
    /// Arms the next reveal to land where the next move lands. Debug only.
    func debugArmSnipe() {
        engine.debugSnipesNext = true
    }

    /// Prints what ten thousand coins actually come up as, on this plane.
    func debugRollDistribution() {
        let rolls = 10_000
        let sample = engine.debugPickupSample(rolls)
        print("── \(rolls) draws as \(engine.piece.zodiac) on \(engine.piece.plane.rawValue) ──")
        for (id, count) in sample {
            let observed = Double(count) / Double(rolls) * 100
            let authored = PickupCatalog.effect(for: id).chance
            // A coin authored at zero that still turns up is drawn some other
            // way — the Bolt out of the elementals. Saying "authored 0" beside
            // an observed one percent reads as a bug rather than as a design.
            let source = authored > 0 ? "authored \(authored)%" : "derived"
            print(String(
                format: "  %-22@ %5.2f%%   %@",
                id.rawValue as NSString, observed, source as NSString
            ))
        }
    }

    /// Throws one puff on the far row and one on the near row, together.
    ///
    /// A measuring stick rather than a fix: the two are the same event at the
    /// two extremes of depth, so whatever the board is doing to scale — or not
    /// doing — is visible in one glance instead of being argued about.
    func debugCompareDepth() {
        let plane = engine.piece.plane
        let last = engine.currentBoard.size - 1
        kickUpDust(at: GridPoint(3, 0), on: plane, magnitude: 1)
        kickUpDust(at: GridPoint(3, last), on: plane, magnitude: 1)
    }

    func debugStagePolaris() {
        engine.debugNextPickup = .polaris
    }

    /// Puts the chosen Pentacle on `point`, now. Debug builds only.
    ///
    /// Unlike `debugStagePolaris`, this places rather than stages — which is the
    /// point of a spawner: to get a coin onto a named square without waiting for
    /// the hunt to offer one. It goes through the reveal event so the view
    /// animates it in like any other, and it lands on the plane you are looking
    /// at.
    func debugSpawn(_ id: PickupID, at point: GridPoint) {
        debugSpawning = nil
        run(engine.debugPlacePickup(id, at: point))
    }

    /// Turns the coin already on the board into `id`. Debug builds only.
    ///
    /// One tap instead of two — see `GameEngine.debugReplacePickup`.
    func debugBecome(_ id: PickupID) {
        run(engine.debugReplacePickup(id))
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


    var canVault: Bool {
        acceptsInput && engine.longestReach(for: engine.piece.facing) > 0
    }


    /// Presses the elevator. See `GameEngine.planNexysCall`.
    /// The fragment being carried, if one is. See `SignState.Polaris`.
    var polaris: SignState.Polaris? { engine.signState.polaris }

    /// True while it is lit and may be spent.
    var canFirePolaris: Bool { engine.canFirePolaris }

    /// Spends it. See `GameEngine.planPolaris()`.
    func firePolaris() {
        if dismissIntroIfShowing() { return }
        guard acceptsInput, engine.canFirePolaris else { return }

        let events = engine.planPolaris()
        guard !events.isEmpty else { return }
        Haptics.zodiaction()
        run(events)
    }

    /// True while an arrow is waiting in the ground, for anybody.
    var canRecallArrow: Bool { engine.canRecallArrow }

    /// Answers it. See `GameEngine.planArrowRecall()`.
    func recallArrow() {
        if dismissIntroIfShowing() { return }
        guard acceptsInput, engine.canRecallArrow else { return }

        let events = engine.planArrowRecall()
        guard !events.isEmpty else { return }
        Haptics.zodiaction()
        run(events)
    }

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

        // **Not `acceptsInput`, which threw the tap away.**
        //
        // A turn is longer than the hop inside it, and `submit` exists to
        // *remember* an input that lands during that tail rather than lose it.
        // Guarding here on `acceptsInput` — false for the whole tail — meant the
        // tap never reached the part that remembers it, so a player tapping at a
        // comfortable pace had every second tap silently dropped while the very
        // same input arriving as a swipe or a key was kept and replayed.
        //
        // That read as the stick being laggy, and it was not: it was the tap
        // being the one input in the game without a memory. `submit` still holds
        // every real gate — pause, splash, parked Pentacle — so letting the
        // resolving tail through only reaches the buffer.
        guard acceptsInput || phase == .resolvingMove else { return }

        // **Already in the piece's own terms, so it must not be turned around.**
        //
        // `submit` reverses what the player *asks for*, which is right for a
        // direction pressed on the pad and wrong for this one: "forward" is
        // read off the piece's facing, and the facing is already where it is
        // really pointing. Reversed, the tap sent Aquarius the opposite way,
        // his facing followed the move, and the next tap sent him back — a
        // stick tap shuffled him between two squares for ever.
        //
        // Handed the raw direction that will survive the flip, so one owner
        // still does the reversing.
        let forward = engine.controlsAreReversed
            ? engine.piece.facing.opposite
            : engine.piece.facing
        submit(forward, reach: 0)
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
    /// The move the player asked for while this one was still playing, if any.
    /// See `submit(_:reach:)`.
    private var bufferedMove: (direction: SwipeDirection, reach: Int, at: Date)?

    private func run(_ events: [GameEvent]) {
        // A fresh move of its own accord clears whatever was waiting: the buffer
        // is a *pending* input, and once one has been answered the next belongs
        // to the turn after this one.
        bufferedMove = nil
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
            case .zodiactionFired, .pieceSlid, .pieceFell,
                 .nexysMoved, .planeRestored, .tilesChanged, .pickupCollected,
                 .arrowPlanted, .stingStruck, .poolFormed, .pickupBanked,
                 // The board is being rewritten from one square outward and the
                 // player is meant to watch it happen — that is the whole
                 // reason the wave is rings rather than one event.
                 .groundWaveBegan:
                return true

            // A move that did not walk there is always worth watching; the
            // ordinary steps are counted below.
            case let .pieceMoved(_, _, _, _, type, _, _) where !type.travelsTheGround
                && type != .hop:
                return true

            case .pieceMoved:
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
        defer { isHoldingBoard = false }

        // The ambient art holds its pose for the same span, and only that span.
        if isResolvingAction {
            pauseAmbient(at: Date.now.timeIntervalSinceReferenceDate)
        }
        defer { resumeAmbient(at: Date.now.timeIntervalSinceReferenceDate) }
        // Anything lit for the duration of an action goes out with it, however
        // the action ended.
        defer { isCharging = false }
        defer { isSliding = false }

        // **And the movement, which is a clock.**
        //
        // `beginMovement` was called by `animateStep` and by the slide, and
        // ended by nobody — so `movement` outlived its own animation and went on
        // reporting the direction of the last successful move for ever after.
        //
        // Invisible almost always, because `engine.apply` turns the piece to the
        // same direction the stale movement claims. It surfaces the one time the
        // facing changes *without* a move: Rebounding Ram, which turns the piece
        // round off a wall it could not walk through. The cursor reads the
        // model and flipped; the sprite and the arrow read `visibleFacing` and
        // did not, so the ram faced one way and walked the other.
        defer { endMovement() }

        // Per-move presentation bookkeeping, cleared before anything is drawn.
        crabWalkOrigin = nil
        pluming = nil
        mending = nil
        manePulledThisMove = false

        for event in events {
            guard !Task.isCancelled else { return }
            await present(event)
        }

        guard !Task.isCancelled else { return }

        flashingTiles = []
        // **The camera cannot be left looking where the piece is not.**
        //
        // A net, not a rule — every transition walks the camera itself, and this
        // catches the ones that do not. There are more ways to change plane than
        // there are transitions that animate it: a teleport between Miasma
        // sigils, a Nexys ride reached through Libra's own dispatch. Any of them
        // used to leave the camera three rows from the piece with no way back,
        // which is a dead run rather than a glitch.
        //
        // Skipped while anything is in flight, so it can never fight an
        // animation that is part way through doing this properly.
        if cameraFrom == nil, !isFalling {
            let home = Double(World.row(of: engine.piece.plane))
            if cameraRow != home { cameraRow = home }
        }

        phase = engine.isGameOver ? .gameOver : .awaitingInput

        playBufferedMove()
    }

    /// Answers the input that arrived mid-turn, if it is still worth answering.
    /// - Note: `waiting.direction` is what the player asked for, untouched, so
    ///   handing it back to `submit` turns it around exactly once. See where it
    ///   is stored.
    private func playBufferedMove() {
        guard let waiting = bufferedMove else { return }
        bufferedMove = nil

        guard acceptsInput,
              Date.now.timeIntervalSince(waiting.at) <= GameRules.inputBufferWindow
        else { return }

        submit(waiting.direction, reach: waiting.reach)
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
        logMeter(event)
        #endif

        switch event {

        case let .passiveFired(name, refused):
            // No sleep and no animation: the card runs on its own clock, and a
            // beat here would stop the move in order to say what the move did.
            if refused {
                refuse(passive: name)
            } else {
                announce(passive: name)
            }

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

            // The preview has arrived where the ground now is, so it stops being
            // a preview.
            slabDrop = nil
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
            // Held for a beat, not for the whole flash.
            //
            // The crack animates on its own once the engine has applied it, so
            // waiting out the full flash before the next event bought nothing
            // and put a sixth of a second on the end of every move that damaged
            // anything — which is every move. The flash clears itself, the way
            // the dust and the tile press already do.
            await sleep(event.displayDuration)
            clearFlashLater(changes.keys)

        case let .tilesWorn(plane, changes, cause):
            showWear(cause, changes: changes, on: plane)
            disperseClouds(in: changes, on: plane)
            flashingTiles.formUnion(changes.keys)
            withAnimation(.easeOut(duration: GameRules.tileDamageDuration)) {
                engine.apply(event)
            }
            // Held for a beat, not for the whole flash.
            //
            // The crack animates on its own once the engine has applied it, so
            // waiting out the full flash before the next event bought nothing
            // and put a sixth of a second on the end of every move that damaged
            // anything — which is every move. The flash clears itself, the way
            // the dust and the tile press already do.
            await sleep(event.displayDuration)
            clearFlashLater(changes.keys)

        case let .groundWaveBegan(plane, origin):
            // **The wave dims the board on its own authority.**
            //
            // `isWorthWatching` reads the plan up front, and a wave raised by a
            // passive can arrive inside a sequence that was judged ordinary
            // before it existed. Rather than teach that judgement about every
            // way an ability can appear late, the one event that *knows* a
            // sweep is starting says so. `replay` still clears it at the end.
            // The same dim a tile choice uses, because it is the same
            // statement: the board is busy and your input is not wanted yet.
            // `actionDim` at a tenth is a mood; this is a modal.
            isHoldingBoard = true
            pauseAmbient(at: Date.now.timeIntervalSinceReferenceDate)

            // **One splash, on the square it starts from.**
            //
            // Not one per tile: forty-nine splashes is a screen of water, and
            // the thing being said is "this came from her", which only the
            // origin can say. The rings that follow are silent and carry the
            // spread on their own.
            playEffect(.waterSplash, at: origin, on: plane)
            Haptics.longer()
            engine.apply(event)

        case let .groundSwept(plane, _, cover):
            // **A few blooms, not one per square.**
            //
            // Hydroponic Hooves greens the whole board, and every square that
            // grew was playing its own strip — forty-nine `EffectSpriteView`s,
            // each a `TimelineView(.animation)`, all asking for a frame sixty
            // times a second. That is enough to saturate the main thread, and a
            // saturated main thread is where it gets nasty: the tasks that
            // remove finished bursts are queued on that same thread, so they do
            // not get to run, so the timelines are never taken down, so the
            // thread stays saturated. The board never comes back.
            //
            // The same cap the mending shimmer already takes, for the same
            // reason — see `GameRules.healSparkleMaxTiles`. A sweep reads as a
            // sweep from a handful of blooms; what it cannot survive is one per
            // tile.
            for (point, grown) in cover.prefix(GameRules.growthBloomMaxTiles) {
                growthPlayed(at: point, on: plane, becoming: grown)
            }
            withAnimation(.easeOut(duration: GameRules.groundWaveRingBeat * 1.6)) {
                engine.apply(event)
            }
            // **As long as the ring takes to arrive, not as long as it takes to
            // start.** The sleep was the beat while the animation ran nearly
            // twice that, so control came back with the last rings still
            // growing in behind her.
            await sleep(event.displayDuration * 1.6)

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

        case let .tileCoverChanged(plane, point, cover, _) where cover != nil:
            // **Only when the square got better.**
            //
            // Flowers stepping down to grass is also a cover change with
            // something left growing, and it was playing the whole planting
            // fanfare — so walking on a meadow looked like sowing one. Asked as
            // a level rather than as a list of cases: see `GroundCover.level`.
            growthPlayed(at: point, on: plane, becoming: cover)
            withAnimation(.easeOut(duration: GameRules.tileHealDuration)) {
                engine.apply(event)
            }

        case let .tileCoverChanged(plane, point, cover, burnt) where cover == nil:
            // **Something hit this square; the grass took it.**
            //
            // Absorbing is not the same as nothing happening, and it read as
            // nothing happening: the fire, the shake and the puff all hung off
            // `tileDamaged`, so a blow the cover ate arrived in silence with a
            // sprite quietly vanishing. The feedback belongs to the *hit*, not
            // to whether the ground underneath was marked.
            // **Only fire smokes.** Grass worn away underfoot is part of the
            // step and already has the step's puff; adding ash to it drew two
            // clouds for one footfall.
            if burnt { singe(at: point, on: plane) }
            if let strength = pendingTremor {
                shake(for: GameRules.arrowLandShake, strength: strength)
                pendingTremor = nil
            }
            if let plume = pluming { playEffect(plume, at: point, on: plane) }
            engine.apply(event)

        case let .tileDamaged(plane, point, _):
            // A trailing effect marks each square as the water reaches it.
            if let plume = pluming { playEffect(plume, at: point, on: plane) }

            // And the ground moving, when a tremor is what moved it.
            if let strength = pendingTremor {
                shake(for: GameRules.arrowLandShake, strength: strength)
                pendingTremor = nil
            }
            flashingTiles.insert(point)
            withAnimation(.easeOut(duration: event.displayDuration)) {
                engine.apply(event)
            }
            await sleep(event.displayDuration)
            flashingTiles.remove(point)

        case let .tileHealed(plane, point, _):
            // Whatever the coin owed this repair, paid at **every** repair it
            // makes. It used to be spent on the first, which was fine while no
            // coin mended twice — Astral Tears does, and the tile you are
            // standing on got nothing. The token is already cleared once per
            // move, so consuming it here only ever meant "one tile per coin".
            if let drawn = mending {
                playEffect(drawn, at: point, on: plane)
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
            collectBurst = ElementalBurst(kind: .element(.air), center: point, plane: plane, start: .now)

            // The flourish every coin gets, whatever it turns out to be — one
            // of two takes, chosen on a coin flip. See `EffectSprite.sparkleBurst`.
            playEffect(.sparkleBurst, at: point, on: plane, glows: true)
            clearCollectBurstLater()

            withAnimation(.easeOut(duration: event.displayDuration)) {
                engine.apply(event)
            }
            await sleep(event.displayDuration)

        // The shards arriving: hold the board still until they land.
        //
        // Four squares are about to become holes, and that should be something
        // the player watches happen rather than finds afterwards.
        case let .signStateChanged(state)
            where state.prongs != nil && engine.signState.prongs == nil:
            engine.apply(event)
            isHoldingBoard = true
            prongsFalling = .now
            pauseAmbient(at: Date.now.timeIntervalSinceReferenceDate)
            Haptics.longer()

            await sleep(GameRules.prongFallDuration)

            prongsFalling = nil
            isHoldingBoard = false
            resumeAmbient(at: Date.now.timeIntervalSinceReferenceDate)
            shake(for: GameRules.arrowLandShake)

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
            collectBurst = ElementalBurst(kind: .element(.air), center: point, plane: plane, start: .now)

            clearCollectBurstLater()

            // Elemental Pentacles throw their burst as they open. Only the four
            // Astral Essences declare an element; everything else is silent.
            //
            // The Breeze is out: it has drawn wind now, played when the gust
            // actually picks the piece up. The generated burst on top of it was
            // two winds for one event, and the generated one arrived first — so
            // the coin announced itself with the placeholder and then did the
            // real thing a beat later.
            if let element = PickupCatalog.effect(for: id).element, id != .astralBreeze {
                playBurst(.element(element), at: point, on: plane)
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
            // The ground moving, felt rather than only seen. Sized to the coin:
            // a Trivial Tremor is a bump and a Shakedown opens a hole, and a
            // shake that could not tell them apart would leave the summaries as
            // the only difference between them.
            switch id {
            case .trivialTremor:
                pendingTremor = GameRules.tremorShake
                // The same plate shattering, sized to the coin that broke it.
                playEffect(
                    .plateBurst, at: point, on: plane,
                    scale: GameRules.tremorBurstScale
                )
            case .seismicShakedown:
                pendingTremor = GameRules.shakedownShake
                playEffect(
                    .plateBurst, at: point, on: plane,
                    scale: GameRules.shakedownBurstScale
                )
            default: break
            }

            if id == .astralBolt {
                playEffect(
                    EffectSprite.strike(at: engine.moveCount),
                    at: point,
                    on: plane
                )
                // And the impact, in front of the piece rather than on the
                // ground: the Bolt is the one Essence that does nothing to the
                // board, so an effect that stays underfoot says the opposite of
                // what happened.
                playEffect(.lightningMisc, at: point, on: plane)
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

        // **One case for every move in the game.**
        //
        // What plays is decided by the move's own type and by the effect its
        // caller attached — never by which sign is standing there. The four
        // clauses this replaced each matched a teleport and then asked a
        // different question about who was moving, which is why an archer blown
        // by a gust launched himself after an arrow that was not there.
        case let .pieceMoved(from, to, fromPlane, toPlane, type, effect, effectPlaysOn):
            if let effect, effectPlaysOn.includesExit {
                playEffect(effect, at: from, on: fromPlane)
            }

            switch type {
            case .teleport:
                await animateWarp(event, from: from, fromPlane: fromPlane, toPlane: toPlane)
                await playArrivalEffect(effect, on: effectPlaysOn)
                return

            case .rise:
                // The fish breaks the surface, the sky is shoved aside where it
                // comes through, and it comes down a square along.
                await animateRise(event, to: toPlane)
                await playArrivalEffect(effect, on: effectPlaysOn)
                return

            // **A carry across the board, not a carry of one square.**
            //
            // `animateBlown` is a flurry of gusts — Astral Breeze's whole
            // picture. Sending every `.blown` move through it meant Aquarius
            // threw the Essence's weather on every single step, because being
            // carried one square by her own storm is the same *type* of move
            // and nothing else about it is the same event. She is flashy enough
            // standing still; what she needs on a step is the afterimages she
            // already has.
            //
            // Distance rather than sign, like the long jump: a wind that moves
            // you across the board is a thing happening to you, and a wind you
            // live inside is not.
            case .blown where from.manhattanDistance(to: to) > 1:
                await animateBlown(event, from: from, to: to, on: fromPlane)
                await playArrivalEffect(effect, on: effectPlaysOn)
                return

            case .superJump where from != to && fromPlane == toPlane
                && to.manhattanDistance(to: from) > 2:
                // Far enough that the arc leaves the board: crouch, launch off
                // the top of the screen, and come down hard where it lands.
                // Distance rather than sign — the archer's jump after his arrow
                // is the long one, and anything else that travels that far
                // under its own power deserves the same picture.
                await launchAcross(event, from: from, plane: fromPlane, effect: effect)
                await playArrivalEffect(effect, on: effectPlaysOn)
                return

            default:
                break
            }

            await animateStep(event, from: from, to: to, plane: fromPlane, type: type)
            await playArrivalEffect(effect, on: effectPlaysOn)
            return

        case let .gameOver(reason)
            where reason == .fellThroughTerra || reason == .blownOffTheBoard:
            // **The same fall as any other hole, and it does not stop.**
            //
            // It used to be half a fall — the piece got a token drop and the
            // old dialog took over. But the drop between planes is now a slide
            // straight down the row, and a death is that slide with no floor
            // under it: the piece leaves the bottom of the board still turning,
            // and the death screen comes up around it while it is on its way.
            // Half a fall would have it stop in mid-air first.
            await animateDescent(duration: GameRules.fallDuration)

            // The only travel path that used to apply its event without asking
            // whether it was still wanted — and the one where it matters most.
            // A restart taken while the piece was still falling applied the old
            // run's game over to the *new* engine, so the fresh run ended on the
            // player's first move carrying the previous run's death text.
            guard !Task.isCancelled else { return }
            engine.apply(event)
            spinForever()
            await sleep(event.displayDuration)

        case let .zodiactionMeterChanged(to):
            // Whether this is the change that arms the sign. Asked before and
            // after, so the *crossing* fires rather than the state — otherwise
            // it would throw again on every pip while the meter sat full.
            let wasCharged = engine.isZodiactionCharged

            // Gaining charge flashes the piece its element's colour, and a sign
            // with a drawn strip for it throws that too.
            // Toward firing, not upward.
            //
            // Aquarius earns charge by *losing* it, so testing for a rising
            // number gave him a silent hunt — no flash, no absorb, nothing to
            // say a Pentacle had paid out. `firesAtEmpty` is what the rest of
            // the engine asks; this asks the same thing.
            // **Any movement at all.**
            //
            // This asked which way the meter was going and showed nothing when
            // it went the other way, which left Aquarius silent for half of what
            // happens to him: he earns by spending, so a coin that *raises* his
            // number is still a coin that paid out. The size of the change is
            // the whole question — the direction is the sign's business, not the
            // effect's.
            let paidOut = abs(to - engine.zodiactionMeter) > 0

            if paidOut {
                flashCharge()
                if let drawn = EffectSprite.chargeGain(for: zodiac) {
                    playEffect(drawn, at: engine.piece.point, on: engine.piece.plane)
                }

                // The absorb, on every gain whatever caused it. Tinted by the
                // element that earned it — the strip is greys so the tint is
                // the only thing saying which.
                playEffect(
                    .absorb,
                    at: engine.piece.point,
                    on: engine.piece.plane,
                    tint: ElementFX.ramp(for: zodiac.element).bright
                )
            }
            withAnimation(.easeInOut(duration: max(event.displayDuration, 0.01))) {
                engine.apply(event)
            }

            // Becoming charged changes what the piece *is* rather than what it
            // holds — Pisces' fish comes loose, the archer's shot is nocked —
            // and a sprite that quietly swaps says less than that deserves.
            if !wasCharged,
               engine.isZodiactionCharged,
               let flourish = EffectSprite.chargedFlourish(for: zodiac) {
                playEffect(flourish, at: engine.piece.point, on: engine.piece.plane)
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
            await playLeap(weight: zodiac == .taurus ? .flop : .dive)

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

        case let .pickupMoved(_, plane, from, to):
            // **Whose pull is this?**
            //
            // The gold pulse and the lion's coat catching are Leo's signature
            // and read as *magnetism*. Aquarius drags a coin with weather, so
            // hers is the wind — and it plays along the coin's own path rather
            // than at the piece, because the gust is the thing that moved it.
            if engine.piece.zodiac.passives.drawsPickupsIn(context: engine.passiveSnapshot) {
                playEffect(.windMisc, at: from, on: plane)
                playEffect(.windMisc, at: to, on: plane)
            }
            // Leo's, on the piece rather than on the coin.
            //
            // The ring is the same one a bubble throws when it pops, and it
            // belongs at the *source*: what the player needs to understand is
            // that the lion is doing this, not that the coin decided to move.
            // Fired once per move however many coins answer it — see
            // `manePulledThisMove`.
            else if !manePulledThisMove {
                manePulledThisMove = true

                // Said once per move, alongside the ring and for the same
                // reason: the lion did this, and a prompt is the part of that
                // sentence a picture cannot carry.
                announce(passive: "Magnetic Mane")
                // Its own picture: water's ripples drawn red. Borrowing an
                // element would have meant a burning ring or a wet lion, and
                // both say something the pull does not.
                playBurst(.magneticPulse, at: engine.piece.point, on: plane)
                blazeMane()
            }

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
                    smoke.append(SmokePuff(
                        point: point,
                        plane: plane,
                        magnitude: GameRules.cloudPoofMagnitude,
                        start: .now,
                        cloudstuff: true
                    ))
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

        case let .pickupRevealed(_, plane, point, thrownFrom, _) where thrownFrom == nil:
            // The phase coming apart.
            //
            // Every lit square bursts, including the one the coin appears on:
            // the sparkles were candidates and all of them stop being
            // candidates at the same instant. Cutting straight from five marks
            // to one coin read as the board being edited rather than as
            // something resolving.
            disperseSparkles(on: plane)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                engine.apply(event)
            }
            await sleep(event.displayDuration)
            _ = point

        case let .pickupRevealed(_, _, point, thrownFrom, _) where thrownFrom != nil:
            // Only a bubble that was *thrown* flies. One surfacing out of the
            // glow phase has nowhere to have come from, and treating those as
            // spills is what made the board re-throw itself on every step.
            throwBubble(to: point, from: thrownFrom!)
            playEffect(.waterSplash, at: thrownFrom!, on: engine.piece.plane)
            engine.apply(event)
            await sleep(event.displayDuration)

        case let .caughtOnReveal(plane, point):
            // The snipe: a coin taken on the move it appeared. Overhead rather
            // than on the square, because the square already has the coin's own
            // collection burst on it and two flourishes in one place read as one
            // messy flourish.
            playEffect(.bonus, at: point, on: plane)
            // And a firework over the head that earned it — thrown on the
            // piece rather than on the square, for the same reason the banner
            // above is: the square already has the coin's own burst.
            playEffect(
                .fireworkFast,
                at: engine.piece.point,
                on: plane,
                glows: true
            )
            engine.apply(event)
            await sleep(event.displayDuration)

        default:
            withAnimation(.easeInOut(duration: max(event.displayDuration, 0.01))) {
                engine.apply(event)
            }
            await sleep(event.displayDuration)
        }
    }

    /// A piece climbing to the plane above under its own power.
    ///
    /// The reverse of a fall, and built from the same one part: the camera walks
    /// up the column to the row above, and the piece is drawn against the same
    /// number, so it holds still while the world comes down past it. The cloud
    /// is pushed aside where it surfaces, which is the tell that something came
    /// *through* rather than appearing.
    private func animateRise(_ event: GameEvent, to plane: Plane) async {
        await climb(event, to: plane, arrivalDuration: GameRules.fallArrivalDuration) { [weak self] in
            guard let self else { return }
            // The sky comes apart where the fish broke through, at the square it
            // is arriving on rather than the one it left — that hole is below it
            // now.
            self.disturbClouds(at: self.engine.piece.point)
        }

        bounceSurface(at: engine.piece.point, on: engine.piece.plane)
        kickUpLandingDust(at: engine.piece.point, on: engine.piece.plane)
    }

    /// Going **up** a plane, however it was earned.
    ///
    /// One sequence rather than two near-identical ones. The rise and the ascent
    /// were separate copies of the same steps, and the only real difference
    /// between them was how long the far side takes and what gets shoved aside
    /// on arrival. Copies of a sequence drift the moment
    /// either is retuned, and this is the sequence most likely to be retuned:
    /// it is the one the player sees on every trip between planes.
    ///
    /// - Parameter arrivalDuration: The tail of the trip, summed into the camera's
    ///   travel. Kept as a parameter because the two callers genuinely differ on
    ///   it, even though nothing settles separately any more.
    /// - Parameter onArrival: What to disturb once the new plane is on screen.
    ///   Called *after* the board has swapped, because the thing being shoved
    ///   aside is only visible then.
    /// - Parameter aboard: Whether the island is carrying the piece up, as
    ///   against the piece climbing under its own power. Only the first has the
    ///   island travelling, and only the first should have it moving with the
    ///   camera — Pisces and Aquarius rise on their own, and an island that
    ///   compensated for the camera on their behalf would hold its screen
    ///   position while the board it stands on scrolled away underneath it.
    private func climb(
        _ event: GameEvent,
        to destination: Plane,
        arrivalDuration: TimeInterval,
        aboard: Bool = false,
        onArrival: @escaping () -> Void
    ) async {
        // The fall run backwards, and the same one number doing it. See
        // `animateFall` — going up is the camera walking to a lower row index
        // instead of a higher one, and nothing else about it differs.
        let travel = GameRules.ascentRiseDuration + arrivalDuration

        ascentRiseStartedAt = .now
        isChangingPlane = true
        nexysRidesCamera = aboard
        cameraFrom = cameraRow
        withAnimation(.linear(duration: travel)) {
            cameraRow = Double(World.row(of: destination))
        }
        await sleep(travel)
        cameraFrom = nil

        guard !Task.isCancelled else {
            ascentRiseStartedAt = nil
            nexysRidesCamera = false
            cameraRow = Double(World.row(of: engine.piece.plane))
            return
        }

        engine.apply(event)
        // Cleared *after* the apply. The island's offset is measured against the
        // square it is drawn in, and until the apply that is still the square it
        // left — dropping the offset first snaps it home for a frame.
        nexysRidesCamera = false
        isChangingPlane = false
        ascentRiseStartedAt = nil
        onArrival()
    }

    /// A move that is walked, hopped or run: the ordinary case.
    ///
    /// Everything here reads `type` and nothing reads the sign. Pulled out of
    /// the event switch so the four ways of arriving without walking can be
    /// answered beside it rather than in four separate `case` clauses that each
    /// re-derived what kind of move this was.
    private func animateStep(
        _ event: GameEvent,
        from: GridPoint,
        to: GridPoint,
        plane: Plane,
        type: MoveType
    ) async {
        let style = type
            leaveAfterimage(at: from, on: plane)
            hopDistance = max(from.manhattanDistance(to: to), 1)
            hopCount += 1
            hopStartedAt = .now

            // The style comes with the step — see `GameEvent.pieceStepped`. It
            // decides the pace, whether the sprite arcs, whether the ground
            // gives on arrival, and whether the squares crossed press down under
            // the piece. Every one of those was previously answered as though a
            // step were always a hop.
            beginMovement(
                style,
                direction: stepDirection(from: from, to: to),
                duration: style.paceMultiplier * hopDuration
            )

            if style.travelsTheGround {
                pressedTiles.insert(to)
                releasePressLater(to)
            }

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
            // Paced by the style, like everything else about the step. A charge
            // is quick because it is a run; watching one crossed at hop speed a
            // square at a time is watching the same hop five times.
            let pace = style.paceMultiplier * hopDuration
            withAnimation(.spring(response: pace * 1.6, dampingFraction: 0.72)) {
                engine.apply(event)
            }
            await sleep(pace)

            // Dust on the arrival, not the launch, and only for a style that
            // arrives. A charge is still running — it throws up its fire as it
            // goes and puffs when it finally stops, which is the settle at the
            // end rather than every square on the way.
            //
            // Where it lands is the sign's business — see `landingDust`. Libra
            // breaks the ground either side of her rather than under her, and
            // the dust follows the damage.
            if style.bouncesOnArrival {
                kickUpLandingDust(at: to, on: plane)
            }
    }

    /// The effect a move carries, played where it lands.
    ///
    /// Split from the exit half so both ends read the same and neither has to
    /// know what kind of move it was attached to.
    private func playArrivalEffect(_ effect: EffectSprite?, on moment: MoveMoment) async {
        guard let effect, moment.includesLanding else { return }
        playEffect(effect, at: engine.piece.point, on: engine.piece.plane)
    }

    /// A jump long enough that the arc leaves the board.
    ///
    /// Crouch, launch, up and off the screen; then the board changes underneath
    /// and the piece lands hard enough to be felt. The pose is `HopPose.leap`
    /// run past its own end — the piece keeps rising rather than coming down,
    /// because the descent happens somewhere else.
    ///
    /// Written for Sagittarius going after his own arrow and keyed on **being
    /// Sagittarius**, which meant every other way of moving him — a gust, a
    /// corner, the island — played it too. It is keyed on the move now, so
    /// anything that takes a long `superJump` gets it and nothing else does.
    private func launchAcross(
        _ event: GameEvent,
        from: GridPoint,
        plane: Plane,
        effect: EffectSprite?
    ) async {
        // The crouch, and whatever the caller sends it off with.
        leapStartedAt = .now
        if let effect { playEffect(effect, at: from, on: plane) }
        Haptics.longer()
        await sleep(GameRules.leapDuration * GameRules.vaultCrouchFraction)

        // Away. `isLaunching` lifts the piece clear of the board on its own
        // curve, since the leap pose alone only clears a tile or so.
        isLaunching = true
        await sleep(GameRules.vaultLaunchDuration)

        engine.apply(event)
        isLaunching = false
        leapStartedAt = nil

        // Arrival: a knock, and the impact where it comes down.
        playEffect(.sagittariusArrowHit, at: engine.piece.point, on: engine.piece.plane)
        kickUpDust(at: engine.piece.point, on: engine.piece.plane, magnitude: 1.4)
        shake(for: GameRules.arrowLandShake)
        bounceSurface(at: engine.piece.point, on: engine.piece.plane)
        await sleep(GameRules.fallArrivalDuration)
    }

    /// The turning that never stops, once the piece is at the bottom.
    ///
    /// A repeating animation rather than a clock this view has to be woken by:
    /// the underground has nothing else moving in it, and the piece kept
    /// spinning is the one thing saying the fall never ended.
    private func spinForever() {
        // The way *this* piece was already turning. `fallSpinDegrees` carries the
        // house direction, `tumbleDirection` carries Gemini's silver twin turning
        // against it — take one without the other and the twin reverses at the
        // bottom of its own fall. And a sign that floats over holes was never
        // tumbling, so it does not start now.
        guard tumble != 0 else { return }
        withAnimation(
            .linear(duration: DeathStyle.spinPeriod).repeatForever(autoreverses: false)
        ) {
            fallSpin += DeathStyle.spinDirection * tumbleDirection * 360
        }
    }

    /// Falling out of the world: through Terra, into what is under it.
    ///
    /// The same walk as any other fall, one row further on. It used to be the
    /// odd one out — the camera held still and the piece dropped into the row
    /// behind the control panel, which then faded so you could see it. Two
    /// mechanisms for one thing, and the second existed only because the first
    /// was not trusted to reach.
    ///
    /// It reaches. The underground is a row like any other, so the camera goes
    /// there, and what you are looking at when the run ends is the place the
    /// piece ended up in — not a gap behind a lid.
    private func animateDescent(duration: TimeInterval) async {
        cameraFrom = cameraRow
        withAnimation(.linear(duration: duration)) {
            isFalling = true
            cameraRow = Double(World.underground)
            deathSeat = GameRules.nexysPoint
            fallSpin += tumble
        }
        await sleep(duration)
        cameraFrom = nil
    }

    private func animateFall(_ event: GameEvent) async {
        guard case let .pieceFell(from, to, at) = event else { return }

        // **The whole fall, as one number going up.**
        //
        // It used to be two beats with the plane swap hidden between them: the
        // piece span and shrank out of the hole, the boards were exchanged, and
        // a second piece dropped in from above the frame. Everything difficult
        // about it came from those being two separate journeys that had to be
        // made to look like one — a spin split across the seam that changed rate
        // half way, an arrival that started above the top of its own square and
        // so was clipped out of existence for the first third of it.
        //
        // There is one journey now. Astra and Terra are rows of one column three
        // apart, and this walks the camera from one to the other. The piece is
        // drawn against the same number in the same transaction, so it holds
        // still on screen while the world goes up past it — which is what
        // falling actually looks like — and at the end it is already standing
        // exactly where the destination board expects it, because three rows
        // down from its tile on Astra *is* its tile on Terra.
        let travel = GameRules.fallDuration + GameRules.fallArrivalDuration

        // A sign that means to be down there does not tumble on the way. Only
        // the spin goes: the spin is the part that says the piece has lost
        // control of what is happening to it.
        let controlled = engine.piece.zodiac.passives.fallIsControlled(
            to: to, context: engine.passiveSnapshot
        )
        // One turn at one speed, ending upright. `fallSpinDegrees` is three whole
        // turns, so the piece is the right way up at the instant it lands — and
        // now it is a single `withAnimation` rather than two, so there is no seam
        // in the middle for the rate to change at.
        let whole = controlled ? 0 : GameRules.fallSpinDegrees * tumbleDirection

        // Going down through the sky pushes it aside. Only leaving Astra: a fall
        // out of Terra is a fall out of the world and there is no cloud there to
        // move.
        if from == .astra { disturbClouds(at: at) }

        cameraFrom = cameraRow
        isChangingPlane = true
        withAnimation(.linear(duration: travel)) {
            isFalling = true
            cameraRow = Double(World.row(of: to))
            fallSpin += whole
        }
        await sleep(travel)
        cameraFrom = nil

        guard !Task.isCancelled else {
            isFalling = false
            cameraRow = Double(World.row(of: engine.piece.plane))
            return
        }

        // **Applied at the end, not the middle.** The camera is already looking
        // at the destination row and the piece is already drawn in it; this only
        // changes which board is underneath, and the piece's offset falls to
        // zero in the same instant because its plane is now the one the camera
        // is on.
        engine.apply(event)
        isFalling = false
        land()
    }

    /// Hitting the ground at the end of a fall, however the fall began.
    ///
    /// One copy, because there is now more than one way to arrive: a fall
    /// through a hole, and a restart that drops the player back into the world
    /// from the seam. Two copies of a landing drift apart the first time either
    /// is retuned, and a landing is mostly feel.
    private func land() {
        // **The crossing is over here and nowhere else.**
        //
        // It used to be cleared beside each `engine.apply`, and the fall's copy
        // was simply missing — so a piece that fell to Terra stayed gold for the
        // rest of the run, never took the plane's material, and dragged every
        // other thing keyed on being mid-crossing along with it. One owner: the
        // crossing ends when the piece is on the ground.
        isChangingPlane = false
        deathSeat = nil

        bounceSurface(at: engine.piece.point, on: engine.piece.plane)

        // **The energy arriving, in the sign's own colour.**
        //
        // The piece has been gold the whole way down — belonging to neither
        // plane — and this is the moment it takes the new one's material. The
        // flash is what marks the handover: `absorb` played backwards is energy
        // going *in* rather than out, which is exactly what a landing is. Which
        // strip it uses is a drawing decision and lives on the bench.
        let flash = FallStyle.arrival
        playEffect(
            flash.effect,
            at: engine.piece.point,
            on: engine.piece.plane,
            tint: ElementFX.ramp(for: zodiac.element).bright,
            reversed: flash.runsBackwards
        )

        // And the sign's own landing strip over the top of it, where one exists.
        // The lion does not raise dust — it lands, and the ground knows about it.
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
    /// Carried across the board by the wind.
    ///
    /// Not a warp and not a slide. A slide is square-by-square along a line and
    /// wears every tile it crosses; this passes *over* the board and touches
    /// nothing until it lands — so it borrows the slide's travel and none of its
    /// consequences.
    ///
    /// The afterimages are wind-coloured whatever sign is being carried. They
    /// are the Breeze's trail rather than the piece's: what is doing the moving
    /// is the air, and a Leo blown across the board leaving a fire trail would
    /// credit the wrong thing.
    private func animateBlown(
        _ event: GameEvent,
        from origin: GridPoint,
        to destination: GridPoint,
        on plane: Plane
    ) async {
        // A gust is several gusts.
        //
        // One swoosh read as a placeholder next to the other Essences, which
        // each throw a whole shader's worth of weather. The strip is the same
        // one every time, so what makes it look like wind rather than like a
        // sprite playing is the *variation*: each copy starts a beat later, at
        // its own size and its own slight angle.
        //
        // Seeded off the move rather than random, so the same move looks the
        // same twice and nothing reshuffles under a redraw.
        for gust in 0..<GameRules.breezeGusts {
            let seed = Double((engine.moveCount &* 7 &+ gust &* 13) % 17) / 17
            playEffect(
                .windMisc,
                at: origin,
                on: plane,
                delay: Double(gust) * GameRules.breezeGustStagger,
                scale: 0.7 + CGFloat(seed) * 0.6,
                angle: (seed - 0.5) * 2 * GameRules.breezeGustAngle,
                // Half of them mirrored. One drawing repeated four times reads
                // as four of the same thing however it is scaled and turned;
                // flipping some of them is what stops the eye finding the
                // repeat.
                mirrored: gust % 2 == 1
            )
        }

        leaveAfterimage(at: origin, on: plane)

        // The direction is only for the pose — the piece leans the way it is
        // being carried. Where it *lands* comes from the event, so the nearest
        // of the eight is close enough and a destination that is dead-on none of
        // them keeps the facing it had.
        beginMovement(
            .slide,
            direction: Self.heading(from: origin, to: destination)
                ?? engine.piece.facing,
            duration: GameRules.blownDuration
        )

        withAnimation(.easeInOut(duration: GameRules.blownDuration)) {
            engine.apply(event)
        }
        await sleep(GameRules.blownDuration)

        guard !Task.isCancelled else { return }

        endMovement()
    }

    /// The direction of travel, to the nearest of the eight.
    ///
    /// For a **pose**, not for a move: the Breeze goes anywhere, including
    /// squares no direction points at, so this only has to be close enough for
    /// the piece to lean the right way.
    private static func heading(from origin: GridPoint, to destination: GridPoint) -> SwipeDirection? {
        let dx = destination.x - origin.x
        let dy = destination.y - origin.y
        guard dx != 0 || dy != 0 else { return nil }

        let step = GridOffset(dx == 0 ? 0 : (dx > 0 ? 1 : -1), dy == 0 ? 0 : (dy > 0 ? 1 : -1))
        return SwipeDirection.allCases.first { $0.unitOffset == step }
    }

    /// - Note: A warp may cross planes — the Miasma sigil pair does. The camera
    ///   is moved with it rather than walked, because a teleport *is* a cut: the
    ///   piece is gone from one place and present at another, and dragging the
    ///   view between them would be claiming a journey that did not happen.
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
    /// The fall run backwards, earned rather than suffered. The camera walks up
    /// the column and the island and its passenger are both drawn against it, so
    /// the two arrive together for the only reason two things ever reliably do:
    /// they are reading the same number.
    ///
    /// Input is already locked for the duration — the whole replay runs in
    /// `resolvingMove`, and `acceptsInput` is false throughout.
    private func animateAscent(_ event: GameEvent) async {
        await climb(event, to: .astra, arrivalDuration: GameRules.ascentGrowDuration, aboard: true) { [weak self] in
            // Astra is on screen now, which is the only moment the sky being
            // shoved aside can actually be seen — see `animateNexysTravel`.
            self?.disturbClouds(at: GameRules.nexysPoint)
        }
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
        // the same hole — on the way up as well as the way down.
        //
        // Fired on the beat when Astra is the plane being *looked at*, which is
        // the departure going down and the arrival coming up. Doing it at the
        // start either way meant a rise shoved the sky aside while the player
        // was still looking at Terra, and by the time Astra came into view the
        // wake had already run out. The clouds part when the island comes
        // through them, whichever direction it is travelling.
        if !goingUp { disturbClouds(at: GameRules.nexysPoint) }

        nexysTravellingUp = goingUp
        if case let .nexysMoved(_, carrying) = event { nexysCarryingPiece = carrying }
        defer { nexysCarryingPiece = false }

        // **A ride with a passenger is a plane change, and moves the camera.**
        //
        // Libra's own dispatch reaches this function for rides that would
        // otherwise go to `animateAscent`, and a carry *downward* has no other
        // path at all — so a ride taken either of those ways flipped the piece's
        // plane while the camera stayed on the row it left. The piece then drew
        // three rows outside the window, and the run could not be recovered
        // without dying.
        let carriesCamera = nexysCarryingPiece
        if carriesCamera, case let .nexysMoved(destination, _) = event {
            let travel = (goingUp
                ? GameRules.ascentRiseDuration
                : GameRules.nexysTravelDepartDuration)
                + (goingUp ? GameRules.ascentGrowDuration : GameRules.fallArrivalDuration)
            nexysRidesCamera = true
            isChangingPlane = true
            cameraFrom = cameraRow
            withAnimation(.linear(duration: travel)) {
                cameraRow = Double(World.row(of: destination))
            }
        }
        defer {
            if carriesCamera {
                cameraFrom = nil
                nexysRidesCamera = false
                isChangingPlane = false
            }
        }

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

        if goingUp { disturbClouds(at: GameRules.nexysPoint) }

        nexysArriveStartedAt = .now
        await sleep(goingUp ? GameRules.ascentGrowDuration : GameRules.fallArrivalDuration)
        nexysArriveStartedAt = nil
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
        // **The mode card is not dismissed this way.**
        //
        // It was, back when it timed its own exit and reaching for the controls
        // only hurried it along. It waits for Start now, and Start is a button
        // on the panel — a card that also went away on any stray input would
        // make that button optional, and a run would begin by accident.
        guard pentacleIntro != nil else { return false }
        dismissPentacleIntro()
        return true
    }

    // MARK: - Passive announcements

    /// Says that a passive just did something.
    ///
    /// ## Why two, and why nothing is cut short
    ///
    /// One would mean a second trigger either replaced the first mid-sentence
    /// or was dropped, and both of those lose something the player was told.
    /// More than two would be a log down the side of the board rather than a
    /// prompt.
    ///
    /// Every card plays its whole exit, whenever the next one arrives. An exit
    /// that gets interrupted reads as a mistake; one that is allowed to finish
    /// while the next slides in over it reads as two things having happened,
    /// which is what did. A third arriving takes the oldest outright — by then
    /// it has been on screen longest and has least left to say.
    func announce(
        passive name: String,
        tone: PassivePrompt.Tone = .announcement
    ) {
        if passivePrompts.count >= 2 { passivePrompts.removeFirst() }
        passivePrompts.append(PassivePrompt(name: name, tone: tone))
    }

    /// Says that a passive is the reason something did **not** happen.
    ///
    /// Its own door rather than a parameter at every call site, because the two
    /// read differently at a glance and the difference matters — see
    /// `PassivePrompt.Tone`.
    func refuse(passive name: String) {
        announce(passive: name, tone: .refusal)
    }

    /// This one has begun sliding out.
    func passivePromptIsLeaving(_ id: PassivePrompt.ID) {
        guard let index = passivePrompts.firstIndex(where: { $0.id == id }) else { return }
        passivePrompts[index].isLeaving = true
    }

    /// This one has finished, whichever way it went.
    func passivePromptFinished(_ id: PassivePrompt.ID) {
        passivePrompts.removeAll { $0.id == id }
    }

    /// Sends the card away and lets the run begin. The Start button's door.
    func startRun() {
        guard modeCard != nil else { return }
        modeCardIsLeaving = true
    }

    /// The bars have finished sliding off.
    func modeCardFinished() {
        modeCard = nil
        modeCardIsLeaving = false
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
        guard let pending = pendingPickupChoice else { return }

        // The goat's shop closing on a purchase: the coin goes off where he is
        // standing. Only the shop — a tile choice is a destination, not a bang.
        if pending.kind == .shop {
            playEffect(
                .coinExplosion,
                at: engine.piece.point,
                on: engine.piece.plane,
                glows: true
            )
        }

        pendingPickupChoice = nil
        targetAim = nil
        resumeAmbient(at: Date.now.timeIntervalSinceReferenceDate)
        choiceContinuation?.resume(returning: result)
        choiceContinuation = nil
    }

    /// Records a rejected swipe so the board can nudge in that direction.
    private func reportBlocked(_ direction: SwipeDirection) {
        blockedDirection = direction
        blockedAt = Date()
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

    /// Beginning again **without leaving the fall.**
    ///
    /// The ordinary way in is the mode card: the run announces itself and the
    /// player presses start. That is right for a run you have chosen to begin
    /// and wrong for one you are already inside. You died falling; you have been
    /// watching yourself fall ever since; so this does not stop the fall — it
    /// gives it somewhere to land.
    ///
    /// ## How it gets away with it
    ///
    /// Entirely through the shape of the world. `newGame` puts a fresh piece on
    /// Astra and points the camera at it; this immediately points the camera
    /// back at the row the old piece fell to, which draws the new piece exactly
    /// where the old one was — four rows under Astra, in the dark, mid-turn. The
    /// player cannot tell the two apart because there is nothing to tell apart:
    /// same sign, same pose, same place, same instant.
    ///
    /// Then it keeps falling. Down to the seam at the bottom of the column, over
    /// the join — where both sides show the same two rows of empty sky, so there
    /// is nothing to fade and nothing to hide — and down into Astra, landing
    /// with the same bounce any other arrival gets.
    ///
    /// Every leg is timed at the rate of the fall the game already has, so they
    /// read as one drop rather than several moves.
    func restartRunSeamlessly() {
        isPaused = false

        // Seconds per row, taken from the trip the player already knows: Astra
        // to Terra, which is three rows.
        let pace = (GameRules.fallDuration + GameRules.fallArrivalDuration)
            / Double(World.row(of: .terra) - World.row(of: .astra))

        // Not the replay task. `newGame` cancels that one, and this sequence
        // calls `newGame` half way through — it would be cancelling itself.
        Task { @MainActor [weak self] in
            guard let self else { return }

            // **1. A fresh world, built behind a piece that never stopped.**
            let landed = self.cameraRow
            let fellFrom = self.engine.piece.point
            self.newGame(announced: false)
            self.cameraRow = landed

            // Still falling, in every sense the rest of the game asks about.
            // `newGame` clears this, which would have the piece stop being gold
            // and grow a ground shadow — and then carry that shadow down five
            // rows of empty sky.
            self.isFalling = true
            self.isChangingPlane = true

            // And still not taking input. `newGame` sets the phase to awaiting
            // input, which for the two seconds of this drop would let a swipe
            // play a real move on the Astra board while the piece is in mid-air.
            self.isDropping = true

            // Seated where the old piece was, not where a new run starts. The
            // vertical arithmetic already cancels; this is the other axis, and
            // without it the piece jumps across the board to the Nexys' tile
            // half way down its own fall.
            self.engine.seatPiece(at: fellFrom)

            // The endless turn ends here: it said the fall had no bottom, and
            // this one has. Cleared without animation first, because a
            // `repeatForever` is not replaced by another animation — it is
            // replaced by an assignment that carries none.
            var settle = Transaction()
            settle.disablesAnimations = true
            withTransaction(settle) { self.fallSpin = 0 }

            let seam = Double(World.rows - 1)
            let home = Double(World.row(of: .astra))
            let remaining = (seam - landed) + (home - World.wrapped(seam))

            // A whole number of turns over the whole trip, so it arrives
            // upright — the same contract `animateFall` keeps.
            withAnimation(.linear(duration: remaining * pace)) {
                self.fallSpin += GameRules.fallSpinDegrees * self.tumbleDirection
            }

            // **2. Down to the seam.**
            self.cameraFrom = self.cameraRow
            withAnimation(.linear(duration: (seam - landed) * pace)) {
                self.cameraRow = seam
            }
            await self.sleep((seam - landed) * pace)

            // **3. Over the join.** One assignment, and nothing sees it.
            self.cameraRow = World.wrapped(self.cameraRow)

            // **4. And down into Astra.**
            let toHome = home - self.cameraRow
            self.cameraFrom = self.cameraRow
            withAnimation(.linear(duration: toHome * pace)) { self.cameraRow = home }
            await self.sleep(toHome * pace)

            self.cameraFrom = nil
            self.cameraRow = home
            self.isFalling = false
            self.isChangingPlane = false
            self.isDropping = false
            self.land()
        }
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
    /// Prints every change to the meter, with what the meter was before it.
    ///
    /// ## Delete me
    ///
    /// Here to settle one question: whether a Pentacle's charge is actually
    /// landing. `zodiactionMeterChanged` is a *whole-value* event, so a grant
    /// and a drain arriving in the same turn are indistinguishable from the
    /// outside — the meter simply ends up somewhere. This makes the sequence
    /// visible: three coins on Terra should read as three jumps with the walk
    /// draining between them, and anything else is the bug.
    private func logMeter(_ event: GameEvent) {
        guard case let .zodiactionMeterChanged(to) = event else { return }
        print("[zc] \(engine.zodiactionMeter) -> \(to) / \(engine.zodiactionMeterMax)")
    }

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

    /// Lets a damaged square stop flashing, once its animation has run.
    ///
    /// Scheduled rather than awaited so the turn can carry on — see the wear
    /// cases in `present(_:)`.
    private func clearFlashLater(_ points: some Collection<GridPoint>) {
        let keys = Set(points)
        Task { [weak self] in
            try? await Task.sleep(
                nanoseconds: UInt64(GameRules.tileDamageDuration * 1_000_000_000)
            )
            self?.flashingTiles.subtract(keys)
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
    /// The dust an arrival raises, wherever the sign actually puts its weight.
    ///
    /// Something took root here.
    ///
    /// The bloom for every square, because growth is the same event wherever it
    /// happens — and water on top of it when it comes up **under the piece**,
    /// which for the sign whose hooves are hydroponic is the moment worth
    /// hearing. The board answers the growing; the splash answers *her*.
    func growthPlayed(at point: GridPoint, on plane: Plane, becoming cover: GroundCover?) {
        // Terra only. Nothing grows on cloud, and the bloom was going off up
        // there for changes that could not have planted anything.
        guard plane == .terra, engine[plane].contains(point) else { return }

        let before = GroundCover.level(of: engine[plane][point].cover)
        guard GroundCover.level(of: cover) > before else { return }

        playEffect(.astralBloom, at: point, on: plane)

        if point == engine.piece.point, plane == engine.piece.plane {
            playEffect(.waterSplash, at: point, on: plane)
        }
    }

    /// Grey smoke off a square whose cover was just spent.
    ///
    /// Programmatic rather than a strip: it is the same puff the board already
    /// throws for a landing, tinted to ash and thrown a little weaker, so grass
    /// coming off reads as *scorched* rather than as an effect of its own. The
    /// tint is what separates it from dust — see `SmokeSpriteView.tint`.
    func singe(at point: GridPoint, on plane: Plane) {
        kickUpDust(
            at: point,
            on: plane,
            magnitude: GameRules.singeSmokeMagnitude,
            tint: Palette.smoke
        )
    }

    /// One puff under the piece for eleven signs; for Libra, one on each square
    /// her pans trench and none beneath her.
    func kickUpLandingDust(at point: GridPoint, on plane: Plane) {
        let placed = engine.piece.zodiac.passives.landingDust(
            at: point, context: engine.passiveSnapshot
        )

        guard let placed else {
            kickUpDust(at: point, on: plane, magnitude: 1)
            return
        }

        for puff in placed {
            guard engine[plane].contains(puff.point) else { continue }
            kickUpDust(at: puff.point, on: plane, magnitude: puff.magnitude)
        }
    }

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
        smoke.append(puff)

        Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(GameRules.smokeDuration * 1_000_000_000))
            self?.smoke.removeAll { $0.id == puff.id }
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
    let kind: BurstKind
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

    /// How big this copy is drawn, against the strip's own size.
    var scale: CGFloat = 1

    /// And how far it is turned, in degrees.
    var angle: Double = 0

    /// True to draw this copy mirrored.
    var mirrored = false

    /// True to bloom this copy, for the flourishes that are made of light.
    var glows = false

    /// True to play the strip back to front — see `EffectSpriteView.reversed`.
    var reversed = false

    /// Entries to exchange, for a strip drawn in colours other than the ones
    /// wanted.
    ///
    /// A **swap**, not a tint: `tint` multiplies, so it can only ever darken —
    /// teal art times cyan is still teal. Naming the entries is the only way to
    /// move a strip onto a different part of the ramp.
    var swaps: [PaletteSwap] = []

    /// What to recolour the strip to, or `nil` to leave the art alone.
    ///
    /// For strips drawn deliberately colourless — the absorb is greys precisely
    /// so that whatever tints it is the thing saying which element earned the
    /// charge.
    var tint: Color?
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
        delay: TimeInterval = 0,
        tint: Color? = nil,
        swaps: [PaletteSwap] = [],
        scale: CGFloat = 1,
        angle: Double = 0,
        mirrored: Bool = false,
        glows: Bool = false,
        reversed: Bool = false
    ) {
        let burst = EffectBurst(
            effect: effect,
            center: point,
            plane: plane,
            start: .now.addingTimeInterval(delay),
            scale: scale,
            angle: angle,
            mirrored: mirrored,
            glows: glows,
            reversed: reversed,
            swaps: swaps,
            tint: tint
        )
        effectBursts.append(burst)

        // **A ceiling, so no single event can bury the frame.**
        //
        // Each burst is a timeline of its own, and they are taken down by tasks
        // that need the main thread — which is exactly what is missing once
        // enough of them are running. The oldest go first: a burst that has
        // been on screen longest is the one nearest finishing anyway.
        if effectBursts.count > GameRules.effectBurstCeiling {
            effectBursts.removeFirst(effectBursts.count - GameRules.effectBurstCeiling)
        }

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

    /// Bursts every square the ending phase had lit.
    ///
    /// The same burst a destroyed Pentacle throws, for the same reason: what
    /// was there is not there any more, and it did not go anywhere.
    private func disperseSparkles(on plane: Plane) {
        guard let set = engine.sparkles, set.plane == plane else { return }

        let bursts = set.points.map {
            ElementalBurst(kind: .element(.air), center: $0, plane: plane, start: .now)
        }
        sparkleDispersals = bursts

        Task { [weak self] in
            try? await Task.sleep(
                nanoseconds: UInt64(GameRules.elementalBurstDuration * 1_000_000_000)
            )
            guard let self else { return }
            self.sparkleDispersals.removeAll { burst in bursts.contains { $0.id == burst.id } }
        }
    }

    /// Starts a burst and clears it once it has played out.
    ///
    /// The clean-up delay is cosmetic bookkeeping, not a game rule — the effect
    /// it illustrates resolved the instant its events were applied.
    func playBurst(_ kind: BurstKind, at point: GridPoint, on plane: Plane) {
        let burst = ElementalBurst(kind: kind, center: point, plane: plane, start: .now)
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


    /// Whether `plane` is off screen and can stop asking for frames.
    ///
    /// See `EnvironmentValues.planeIsAsleep` for what this is for. Both planes
    /// are mounted at once, so the one not being looked at is a full board's
    /// worth of animation running behind a clip.
    func planeIsAsleep(_ plane: Plane) -> Bool {
        // **Asked of the camera, not of the piece.**
        //
        // It used to be "any plane the piece is not standing on, unless it is
        // falling" — which was two separate guesses at the one thing that
        // actually matters, and both were wrong during any other kind of
        // travel: an island crossing between planes on its own ran on a paused
        // timeline and snapped instead of moving. The window onto the world is
        // a fact, so ask it.
        //
        // **But whatever is being carried keeps its own plane awake.**
        //
        // The piece and the island are drawn in the square they belong to even
        // when the camera has taken them somewhere else — that is the whole of
        // what `fallOffset` does — and that offset is read *inside* the square's
        // own timeline. Pause the timeline and the offset freezes at whatever it
        // last was: the thing stops following the camera and scrolls away with a
        // square that is no longer on screen.
        //
        // It is why the island vanished part-way across, and why the piece
        // sometimes stopped turning on the death screen, where its plane is a
        // whole row behind the camera. Neither costs anything the rest of the
        // time — there is one piece, and it is on the plane you are looking at.
        if plane == engine.piece.plane { return false }
        if plane == engine.nexysPlane, isChangingPlane || nexysRidesCamera {
            return false
        }

        return !World.isVisible(
            row: World.row(of: plane),
            sweeping: cameraFrom ?? cameraRow,
            to: cameraRow
        )
    }

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

    /// What a summary is allowed to know. See `PickupSummaryContext`.
    var summaryContext: PickupSummaryContext {
        PickupSummaryContext(
            zodiac: zodiac,
            plane: visiblePlane,
            nexysPlane: engine.nexysPlane,
            signState: engine.signState
        )
    }

    /// The revealed pickups on the visible plane. Usually one, occasionally two.
    var visiblePickups: [RevealedPickup] {
        pickups(on: visiblePlane)
    }

    /// The coins standing on a named plane.
    ///
    /// Asked by plane rather than by where the piece is, because both planes are
    /// drawn now — a coin suppressed on the plane you are falling towards is a
    /// coin that pops into being the instant you land on it.
    func pickups(on plane: Plane) -> [RevealedPickup] {
        engine.revealedPickups.filter { $0.plane == plane }
    }

    /// The popped-up squares, which are not always under a coin — see
    /// `GameEngine.raisedTiles`.
    var visibleRaisedTiles: [RevealedPickup] {
        raisedTiles(on: visiblePlane)
    }

    /// The popped-up squares on a named plane. See `pickups(on:)`.
    func raisedTiles(on plane: Plane) -> [RevealedPickup] {
        engine.raisedTiles.filter { $0.plane == plane }
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
        phase == .awaitingInput && pentacleIntro == nil && pendingPickupChoice == nil
            && !isPaused && modeCard == nil && !isDropping
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
        acceptsInput || pentacleIntro != nil || isChoosingTile || modeCard != nil
    }

    /// True while the player is being asked to pick a square on the board.
    var isChoosingTile: Bool {
        switch pendingPickupChoice?.kind {
        case .tile, .among, .place: true
        default: false
        }
    }

    /// Records that a slab is on its way in, so its arrival can be drawn.
    func notePlacedSlab(_ slab: GavelSlab, at anchor: GridPoint) {
        placedSlab = slab
        slabDrop = SlabDrop(slab: slab, anchor: anchor, plane: visiblePlane, start: .now)
    }

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
