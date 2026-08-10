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

    /// Sparkles flying off a Pentacle that was just opened.
    private(set) var collectBurst: ElementalBurst?

    /// The dust currently settling, if any.
    private(set) var smoke: SmokePuff?

    /// The pillar of light currently standing on the board, if any.
    private(set) var warpBeam: WarpBeam?

    /// The apparition summoned by a Zodiaction, if one is on screen.
    private(set) var spectralHead: SpectralSummon?

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
    private(set) var pendingPickupChoice: (id: PickupID, kind: PickupChoice)?

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
    }

    /// Abandons the current run and starts a new one.
    func newGame(zodiac: Zodiac? = nil, seed: UInt64? = nil) {
        replayTask?.cancel()
        replayTask = nil

        let sign = zodiac ?? startingZodiac
        startingZodiac = sign
        engine = GameEngine(zodiac: sign, seed: seed)

        phase = .awaitingInput
        isFalling = false
        isNexysShifting = false
        blockedDirection = nil
        hopCount = 0
        hopStartedAt = nil
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
        collectBurst = nil
        smoke = nil
        warpBeam = nil
        spectralHead = nil
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
        previewDirection = direction
        previewReach = reach
    }

    /// - Parameter reach: Which of the distances available that way the drag
    ///   selected. Ignored by patterns offering only one.
    func submit(_ direction: SwipeDirection, reach: Int = 0) {
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

    /// Applies a plan to the engine one event at a time, animating each and
    /// waiting out its display duration before the next.
    private func replay(_ events: [GameEvent]) async {
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
        switch event {

        case let .moveBlocked(direction):
            reportBlocked(direction)

        case .pieceFell:
            await animateFall(event)

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

        case let .tilesWorn(_, changes), let .tilesWornOnExit(_, changes):
            flashingTiles.formUnion(changes.keys)
            withAnimation(.easeOut(duration: GameRules.tileDamageDuration)) {
                engine.apply(event)
            }
            await sleep(event.displayDuration)
            flashingTiles.subtract(changes.keys)

        case let .tilesChanged(_, changes):
            flashingTiles.formUnion(changes.keys)
            withAnimation(.easeOut(duration: event.displayDuration * 0.6)) {
                engine.apply(event)
            }
            await sleep(event.displayDuration)
            flashingTiles.subtract(changes.keys)

        case .tileDamaged(_, let point, _), .tileHealed(_, let point, _):
            flashingTiles.insert(point)
            withAnimation(.easeOut(duration: event.displayDuration)) {
                engine.apply(event)
            }
            await sleep(event.displayDuration)
            flashingTiles.remove(point)

        case let .choiceRequested(id, kind):
            engine.apply(event)
            // Suspend until the player answers, then play out whatever the
            // answer produced — including the sparkle phase that could not be
            // rolled without it.
            let answer = await askForChoice(id: id, kind: kind)
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

        case let .pickupCollected(id, plane, point):
            lastCollectedPickup = id
            pentacleBanner = id

            // Landing on a raised tile is a heavier arrival than an ordinary
            // hop: the tile slams flat, dust kicks up, and the coin bursts.
            kickUpDust(at: point, on: plane, magnitude: GameRules.smokeCollectMagnitude)
            collectBurst = ElementalBurst(element: .air, center: point, plane: plane, start: .now)

            clearCollectBurstLater()

            // Elemental Pentacles throw their burst as they open. Only the four
            // Astral Essences declare an element; everything else is silent.
            if let element = PickupCatalog.effect(for: id).element {
                playBurst(element, at: point, on: plane)
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

        case let .pieceStepped(_, to, plane):
            hopCount += 1
            hopStartedAt = .now
            withAnimation(.spring(response: GameRules.hopDuration * 1.6, dampingFraction: 0.72)) {
                engine.apply(event)
            }
            await sleep(event.displayDuration)

            // Dust on the *landing*, not the launch. Firing it with the step
            // put the puff at the destination before the piece got there.
            kickUpDust(at: to, on: plane, magnitude: 1)

        case let .gameOver(reason) where reason == .fellThroughTerra:
            // The same spin-and-shrink as any other hole. There is simply
            // nothing below this one.
            await animateDescent(duration: GameRules.fallDuration / 2)
            engine.apply(event)
            await sleep(event.displayDuration)

        case let .zodiactionFired(zodiac, plane):
            summonSpectralHead(zodiac, on: plane)
            withAnimation(.easeOut(duration: event.displayDuration)) {
                engine.apply(event)
            }
            await sleep(event.displayDuration)

        case let .pieceTeleported(from, _, fromPlane, toPlane):
            await animateWarp(event, from: from, fromPlane: fromPlane, toPlane: toPlane)

        default:
            withAnimation(.easeInOut(duration: max(event.displayDuration, 0.01))) {
                engine.apply(event)
            }
            await sleep(event.displayDuration)
        }
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
    private func animateFall(_ event: GameEvent) async {
        let departure = GameRules.fallDuration / 2

        // Spin and shrink together, and *animated* — incrementing the angle
        // outside `withAnimation` snapped the sprite round instead of turning it.
        withAnimation(.easeIn(duration: departure)) {
            isFalling = true
            fallSpin += GameRules.fallSpinDegrees / 2
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
            fallSpin += GameRules.fallSpinDegrees / 2
        }
        await sleep(GameRules.fallArrivalDuration)

        guard !Task.isCancelled else {
            fallArrivalStartedAt = nil
            return
        }
        fallArrivalStartedAt = nil

        // Impact.
        kickUpDust(
            at: engine.piece.point,
            on: engine.piece.plane,
            magnitude: GameRules.smokeFallMagnitude
        )
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
    private func animateNexysTravel(_ event: GameEvent, goingUp: Bool) async {
        nexysTravellingUp = goingUp
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
    private func askForChoice(id: PickupID, kind: PickupChoice) async -> PickupChoiceResult {
        pendingPickupChoice = (id, kind)
        return await withCheckedContinuation { continuation in
            choiceContinuation = continuation
        }
    }

    /// Answers the outstanding Pentacle question and lets the move finish.
    func resolvePickupChoice(_ result: PickupChoiceResult) {
        guard pendingPickupChoice != nil else { return }
        pendingPickupChoice = nil
        choiceContinuation?.resume(returning: result)
        choiceContinuation = nil
    }

    /// Records a rejected swipe so the board can nudge in that direction.
    private func reportBlocked(_ direction: SwipeDirection) {
        blockedDirection = direction
        blockedNudge += 1
    }

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
    func kickUpDust(at point: GridPoint, on plane: Plane, magnitude: CGFloat) {
        let puff = SmokePuff(point: point, plane: plane, magnitude: magnitude, start: .now)
        smoke = puff

        Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(GameRules.smokeDuration * 1_000_000_000))
            guard let self, self.smoke?.id == puff.id else { return }
            self.smoke = nil
        }
    }
}

// MARK: - Spectral heads

/// An apparition hanging over the piece.
struct SpectralSummon: Identifiable, Equatable {
    let id = UUID()
    let zodiac: Zodiac
    let plane: Plane
    let start: Date
}

extension GameSession {

    /// Raises the sign's apparition and clears it once it has faded.
    func summonSpectralHead(_ zodiac: Zodiac, on plane: Plane) {
        let summon = SpectralSummon(zodiac: zodiac, plane: plane, start: .now)
        spectralHead = summon

        Task { [weak self] in
            try? await Task.sleep(
                nanoseconds: UInt64(GameRules.spectralHeadDuration * 1_000_000_000)
            )
            guard let self, self.spectralHead?.id == summon.id else { return }
            self.spectralHead = nil
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

extension GameSession {

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

    /// The revealed pickup, if it is on the visible plane.
    var visiblePickup: RevealedPickup? {
        guard let pickup = engine.revealedPickup, pickup.plane == visiblePlane else { return nil }
        return pickup
    }

    /// True while the player may act.
    ///
    /// A first-encounter strip and an unanswered Pentacle both block input as
    /// hard as a resolving move does — the game is turn-based, and a turn that
    /// has not finished resolving accepts nothing.
    var acceptsInput: Bool {
        phase == .awaitingInput && pentacleIntro == nil && pendingPickupChoice == nil && !isPaused
    }

    /// True while the player is being asked to pick a square on the board.
    var isChoosingTile: Bool { pendingPickupChoice?.kind == .tile }

    /// True while the player is being asked to pick a sign.
    var isChoosingPiece: Bool { pendingPickupChoice?.kind == .piece }

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
