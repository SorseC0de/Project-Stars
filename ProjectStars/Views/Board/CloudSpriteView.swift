//
//  CloudSpriteView.swift
//  Project Stars
//
//  One cloud, as a view rather than as a canvas stamp.
//

import SwiftUI

/// A single Astra cloud, drawn as a view so it can be recoloured.
///
/// ## Why this exists alongside the field
///
/// `CloudSpriteField` stamps every square into one `Canvas`, which is what makes
/// Astra affordable — but a `Canvas` cannot run the palette shader, and a
/// `GraphicsContext` filter cannot express "these four colours become those four
/// colours". Exactly one square ever needs that: the one a Pentacle is sitting
/// on. One extra view for one square is nothing, and it buys the recolour.
///
/// It shares the field's motion — the same frame, drift and stretch, off the
/// same clock — so the lifted cloud belongs to the sky it came out of rather
/// than looking like a different object placed on top of it.
struct CloudSpriteView: View {

    let point: GridPoint
    let health: TileHealth
    let metrics: PixelArtMetrics

    /// The ambient clock, which stops and resumes rather than jumping. See
    /// `GameSession.ambientClock(at:)`.
    var clock: (TimeInterval) -> TimeInterval = { $0 }

    /// A disturbance in the sky, if one is playing.
    var wake: CloudMotion.Wake?

    /// A landing pressing this square down, if one is playing.
    var bounce: CloudMotion.Bounce?

    /// A mend running the cloud through the palette, if one is playing.
    var healFlash: (ramp: [Color], strength: Double)?

    /// Recolouring applied to the sprite, if any.
    var swaps: [PaletteSwap] = []

    /// Whether this cloud carries the lifted square's bloom.
    var glows: Bool = false

    var body: some View {
        TimelineView(.animation) { timeline in
            let now = clock(timeline.date.timeIntervalSinceReferenceDate)
            let wall = timeline.date.timeIntervalSinceReferenceDate
            let motion = CloudMotion(
                point: point, health: health, metrics: metrics,
                now: now, impulseNow: wall, wake: wake, bounce: bounce
            )

            let art = flashed(recoloured(
                PixelSprite(id: .astraCloud(.at(point)), frame: motion.frame) { EmptyView() }
                .paletteSwap(GameRules.cloudWearSwaps(health))
                    .frame(width: motion.size.width, height: motion.size.height)
                    .scaleEffect(x: motion.isFlipped ? -1 : 1, y: 1)
            ))

            art
                .background { if glows { bloom(art, at: now) } }
                // Wear is suspended for the length of a mend. The drain says
                // "this square is failing" and the flash says "this square was
                // just saved" — showing both at once is the board contradicting
                // itself, and the flash is the newer news.
                .saturation(healFlash == nil ? motion.saturation : 1)
                .colorMultiply(Color(white: healFlash == nil ? motion.luminance : 1))
                .offset(x: motion.offset.width, y: motion.offset.height)
        }
        .allowsHitTesting(false)
    }

    /// The light a lifted cloud throws, under the cloud itself.
    ///
    /// Copies of the same art, each blurred wider than the last and summed.
    /// Additive blending saturates towards white rather than clipping, so
    /// stacking a soft glow is how it gets *bright* instead of merely opaque —
    /// the same way `PaletteGlow` lights the coins.
    ///
    /// It is the recoloured art that blooms, not the original, so the blue cloud
    /// glows blue.
    private func bloom(_ art: some View, at now: TimeInterval) -> some View {
        // Each pass is its own dim additive draw, which is exactly what this was
        // in the `Canvas` it came from: three `drawLayer` calls, each at the
        // breath's opacity, each summed onto the board.
        //
        // Both of the obvious translations are wrong and were tried. Blending
        // the *stack* additively at full opacity per copy lights each pass with
        // the ones under it before it ever reaches the board. Flattening it
        // first with `compositingGroup` fixes that and replaces it with a single
        // near-opaque blob added in one go — brighter still, and flat with it.
        // Dimming each copy and letting them sum is the only arrangement that
        // gives back the numbers that were tuned.
        ZStack {
            ForEach(0..<GameRules.cloudSpriteGlowPasses, id: \.self) { pass in
                art
                    .blur(
                        radius: GameRules.cloudSpriteGlowRadius
                            * metrics.scale
                            * (1 + CGFloat(pass) * 0.8)
                    )
                    .opacity(breath(at: now))
                    .blendMode(.plusLighter)
            }
        }
        .allowsHitTesting(false)
    }

    /// How hard the bloom is breathing.
    private func breath(at now: TimeInterval) -> Double {
        let phase = now / GameRules.cloudSpriteGlowPeriod * 2 * .pi
        let swell = (sin(phase) + 1) / 2
        return GameRules.cloudSpriteGlowMin
            + (GameRules.cloudSpriteGlowMax - GameRules.cloudSpriteGlowMin) * swell
    }

    /// The mend, drawn as a second swap on top of whatever the cloud already
    /// wears.
    ///
    /// A ramp for a ramp: the four body tones go to three shades of the flash
    /// colour, darkest doubled up. Every fold in the cloud survives and only the
    /// hue moves — which a flat tint cannot do, and which is the whole reason
    /// this is a swap rather than an overlay.
    @ViewBuilder
    private func flashed(_ art: some View) -> some View {
        if let flash = healFlash, flash.ramp.count >= 3 {
            art
                .paletteSwap([
                    PaletteSwap(Palette.pink, flash.ramp[0]),
                    PaletteSwap(Palette.magenta, flash.ramp[1]),
                    PaletteSwap(Palette.darkMagenta, flash.ramp[2]),
                    PaletteSwap(Palette.purple, flash.ramp[2]),
                ])
                .opacity(flash.strength)
                .background { art.opacity(1 - flash.strength) }
        } else {
            art
        }
    }

    @ViewBuilder
    private func recoloured(_ art: some View) -> some View {
        if swaps.isEmpty {
            art
        } else {
            art.paletteSwap(swaps)
        }
    }
}

// MARK: - Recolourings

extension CloudSpriteView {

    /// The lifted cloud: cloudstuff turned to blue, and its stars to magenta.
    ///
    /// ## Why swap rather than draw a second sheet
    ///
    /// Because the palette is fixed and the shader is already here. A blue
    /// variant of the cloud is the same drawing in different entries — asking
    /// for it in art would be paying twice for something the ramp already
    /// describes, and it would drift the moment either version was retouched.
    ///
    /// ## Why the stars go white
    ///
    /// The stars are the one part of the cloud that is *not* cloudstuff, and
    /// they read as light rather than as material. Sent to blue with everything
    /// else they vanish into it. White keeps them reading as light on any body
    /// colour at all — which is what they are — and leaves the blue to say
    /// *which square*, with nothing competing for the same job.
    ///
    /// Lightest to lightest and darkest to darkest throughout: a ramp swapped
    /// out of order turns a rounded shape inside out.
    static let raisedSwaps: [PaletteSwap] = [
        // Stars: light blue becomes white.
        PaletteSwap(Palette.lightBlue, Palette.white),

        // Body: the four violets become four blues, in order — and a tint
        // lighter than the obvious mapping. The violets sit near the dark end of
        // their own ramp; landing them on the matching end of the blues gave a
        // cloud you had to look for. A rung up puts the lifted square where it
        // belongs, which is brighter than the sky around it.
        //
        // The highlight stops at `cyan` rather than carrying on to `ice`. `ice`
        // is a near-white — it is the top of the *cools*, not a blue — and a
        // cloud whose lightest tone is white does not read as a blue cloud, it
        // reads as a lit one. That, and not the bloom, is what kept looking like
        // glare however far the bloom came down: the three darker rungs are
        // still a step up, so the shape is as bright as it was asked to be
        // without any part of it turning to light.
        PaletteSwap(Palette.pink, Palette.cyan),
        PaletteSwap(Palette.magenta, Palette.cyan),
        PaletteSwap(Palette.darkMagenta, Palette.lightBlue),
        PaletteSwap(Palette.purple, Palette.blue),
    ]
}

// MARK: - CloudMotion

/// Where a cloud is, how big, which frame, and which way round.
///
/// Pulled out of `CloudSpriteField` so the field and the single-cloud view
/// cannot drift apart: the lifted square has to breathe on exactly the same
/// clock as its neighbours or it reads as a separate object sitting on the
/// board. One description, two renderers.
struct CloudMotion {

    let frame: Int
    let size: CGSize
    let offset: CGSize
    /// How much colour is left in it and how lit it is. See
    /// `GameRules.cloudWear`.
    let saturation: Double
    let luminance: Double

    let isFlipped: Bool

    /// - Parameter now: The **ambient** clock, which stops while an action
    ///   plays out. Drives the idle drift and stretch.
    /// - Parameter impulseNow: The **wall** clock. Drives the wake and the
    ///   landing dip, which are impacts rather than ambience: they are set off
    ///   *by* the action the ambient clock is stopped for, so timing them
    ///   against a stopped clock means they never play at all.
    init(
        point: GridPoint,
        health: TileHealth,
        metrics: PixelArtMetrics,
        now: TimeInterval,
        impulseNow: TimeInterval,
        wake: Wake? = nil,
        bounce: Bounce? = nil
    ) {
        let stages = health.rawValue
        let side = metrics.tileSize * CGFloat(GameRules.cloudSpritePixelSize)
            / CGFloat(GameRules.tilePixelSize)
            * GameRules.cloudSpriteScale
        let wear = GameRules.cloudScale(health)

        frame = Self.pingPong(at: now)
        isFlipped = !stages.isMultiple(of: 2)
        let worn = GameRules.cloudWear(health)
        saturation = worn.saturation
        luminance = worn.luminance

        size = CGSize(
            width: side * wear * Self.stretch(
                point, now: now, salt: 0, period: GameRules.cloudSpriteStretchPeriodH
            ),
            height: side * wear * Self.stretch(
                point, now: now, salt: 97, period: GameRules.cloudSpriteStretchPeriodV
            )
        )

        let wander = Self.shift(point, now: now, scale: metrics.scale)
        let shove = Self.shove(point, wake: wake, now: impulseNow, scale: metrics.scale)
        let give = Self.dip(point, bounce: bounce, now: impulseNow, scale: metrics.scale)

        offset = CGSize(
            width: wander.width + shove.width,
            height: wander.height + shove.height + give
                + GameRules.cloudSpriteDrop * metrics.scale
        )
    }

    /// Something dropping through the sky, and when it started.
    struct Wake: Equatable {
        let point: GridPoint
        let start: TimeInterval
    }

    /// Something landing on a square, and when it did.
    struct Bounce: Equatable {
        let point: GridPoint
        let start: TimeInterval
    }

    /// How far the surface at `point` has given under a landing, in points.
    ///
    /// Down and back over the bounce's life, on one half-cycle of a sine — a
    /// press and a release, with no overshoot. Cloud is soft and the island
    /// hangs on nothing; neither should twang.
    ///
    /// Only the square landed on. Its neighbours are a separate idea — see
    /// `shove`, which is what a fall *through* the plane does.
    static func dip(_ point: GridPoint, bounce: Bounce?, now: TimeInterval, scale: CGFloat) -> CGFloat {
        guard let bounce, bounce.point == point else { return 0 }

        let progress = (now - bounce.start) / GameRules.surfaceBounceDuration
        guard progress > 0, progress < 1 else { return 0 }

        return GameRules.surfaceBounceDepth * scale * CGFloat(sin(progress * .pi))
    }

    /// How far this cloud is pushed aside by a wake, if it is near one.
    ///
    /// Only the eight squares touching the hole move, and each moves directly
    /// away from it — so the ring opens outward rather than sliding as a block.
    /// Diagonals are normalised, or the corners would be flung half again as far
    /// as the edges and the ring would come apart into a square.
    ///
    /// Out fast and back slowly — see `GameRules.cloudWakeAttack`. Both halves
    /// are eased so the turn at full extension is a curve rather than a corner.
    static func shove(
        _ point: GridPoint,
        wake: Wake?,
        now: TimeInterval,
        scale: CGFloat
    ) -> CGSize {
        guard let wake else { return .zero }

        let dx = point.x - wake.point.x
        let dy = point.y - wake.point.y
        guard dx != 0 || dy != 0, abs(dx) <= 1, abs(dy) <= 1 else { return .zero }

        let progress = (now - wake.start) / GameRules.cloudWakeDuration
        guard progress > 0, progress < 1 else { return .zero }

        let attack = max(GameRules.cloudWakeAttack, 0.001)
        let swell = progress < attack
            ? sin(progress / attack * .pi / 2)
            : cos((progress - attack) / (1 - attack) * .pi / 2)

        let length = (CGFloat(dx) * CGFloat(dx) + CGFloat(dy) * CGFloat(dy)).squareRoot()
        let push = GameRules.cloudWakePush * scale * CGFloat(swell) / length

        return CGSize(width: CGFloat(dx) * push, height: CGFloat(dy) * push)
    }

    /// Which frame of the strip is showing.
    ///
    /// Ping-pong rather than a loop: three frames cycling forwards jump from the
    /// last back to the first, which on a shape this soft reads as a stutter.
    /// Out and back has no seam — `0, 1, 2, 1` and round again.
    static func pingPong(at now: TimeInterval) -> Int {
        let frames = GameRules.cloudSpriteFrames
        guard frames > 1 else { return 0 }

        let span = frames * 2 - 2
        let tick = Int(now / GameRules.cloudSpriteRate.frameDuration) % span
        return tick < frames ? tick : span - tick
    }

    /// This cloud's wander from its square, in points.
    static func shift(_ point: GridPoint, now: TimeInterval, scale: CGFloat) -> CGSize {
        let amount = GameRules.cloudSpriteShift * scale
        let clock = now / GameRules.cloudSpriteShiftPeriod * 2 * .pi
        let phase = CloudCluster.phase(at: point)

        return CGSize(
            width: CGFloat(sin(clock + phase)) * amount,
            height: CGFloat(cos(clock * 0.8 + phase)) * amount * 0.6
        )
    }

    /// This cloud's stretch on one axis, as a multiplier around `1`.
    static func stretch(
        _ point: GridPoint,
        now: TimeInterval,
        salt: Int,
        period: TimeInterval
    ) -> CGFloat {
        let phase = CloudCluster.hash(point, salt: salt) * 2 * .pi
        let wave = sin(now / period * 2 * .pi + phase)
        return 1 + CGFloat(wave) * GameRules.cloudSpriteStretch
    }
}
