//
//  CloudTileView.swift
//  Project Stars
//
//  Astra's squares: clusters of cloud rather than tiles.
//

import SwiftUI

/// One square of Astra, drawn as a cluster of small astral clouds.
///
/// ## Why wear shrinks rather than cracks
///
/// A cloud cannot crack. Terra's tiles show damage as fractures spreading across
/// a solid face; Astra's show it as there being *less cloud* — the cluster
/// contracts until, at `badlyCracked`, it is about the width of a piece's base.
/// At a glance you can see there is only just enough left to stand on, which is
/// the same information a fracture carries, expressed in the material.
///
/// ## Why it is drawn rather than sprited
///
/// Four sprites per shade per plane could have covered the wear states, but the
/// contraction is continuous and the dispersal is not a state at all — see
/// `CloudPoofView`. Generating the cluster also means every square is a slightly
/// different cloud for free, which a sheet would need one drawing each to match.
struct CloudTileView: View {

    let health: TileHealth
    let shade: Palette.TileShade

    /// Which square this is, so its cluster is its own and stays put.
    let point: GridPoint

    /// Rendered edge length in points.
    let size: CGFloat

    /// True for one beat after this square changes state.
    var isFlashing: Bool = false

    /// True for the cloud a Pentacle is sitting on, which is tinted rather than
    /// only lifted. See `Palette.cloudRaised`.
    var isRaised: Bool = false

    /// Whole-pixel scale, for art-pixel distances.
    private var scale: CGFloat { size / CGFloat(GameRules.tilePixelSize) }

    /// When this cloud last started changing between resting and raised.
    ///
    /// `nil` means it has always been whatever it is — the 48 clouds that are
    /// not under the Pentacle, which must not play a transition on appear.
    @State private var raiseChangedAt: Date?

    /// The wear scale this cluster is easing away from, and when it started.
    ///
    /// A `Canvas` has no view identity for SwiftUI to hang an implicit
    /// animation on, so the shrink is timed by hand — like every other effect
    /// in this game, and unlike the `.animation(value: health)` this replaces.
    @State private var wearFrom: CGFloat = 1
    @State private var wearStartedAt: Date?

    // MARK: - Body
    //
    // ## Why this is a Canvas and not a ZStack
    //
    // A cluster is 13 puffs, 18 speckles and 8 curls: 39 shapes. Times 49
    // squares that is roughly 1,900 SwiftUI views, every one of them rebuilt
    // every frame because everything here is a function of the clock. Astra
    // could not hold 60fps.
    //
    // None of those views need identity, layout, hit testing or transitions —
    // they are pixels. `Canvas` draws them as primitives with none of that
    // machinery, which is what this is for.

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, canvas in
                draw(&context, in: canvas, at: timeline.date.timeIntervalSinceReferenceDate)
            }
            .frame(width: size, height: size)
        }
        .allowsHitTesting(false)
        // Nothing in here may be animated by anybody else.
        //
        // Every colour and size below is recomputed each frame from the clock
        // above. If an ancestor installs a transaction — the pop's spring does
        // exactly that — SwiftUI starts a *second* interpolation toward each new
        // value on every frame. Springs overshoot, and overshoot on colour
        // channels runs past the ends of the ramp: a magenta cloud turning blue
        // takes a detour through red, because its dominant channel overshoots
        // while the others undershoot.
        .transaction { $0.animation = nil }
        // The raised cloud is a different view from the ordinary one — it is
        // depth-sorted with the pieces rather than laid down with the board — so
        // it arrives already raised and has to start its ramp on appear.
        .onAppear { if isRaised { raiseChangedAt = .now } }
        .onChange(of: isRaised) { raiseChangedAt = .now }
        .onChange(of: health) { old, _ in
            wearFrom = GameRules.cloudScale(old)
            wearStartedAt = .now
        }
    }

    /// Paints this one cluster, via the shared painter.
    private func draw(_ context: inout GraphicsContext, in canvas: CGSize, at now: TimeInterval) {
        let blend = raiseBlend(at: now)

        CloudCluster.paint(
            CloudCluster.Brush(
                centre: CGPoint(x: canvas.width / 2, y: canvas.height / 2),
                point: point,
                wear: wearScale(at: now),
                tones: Palette.cloudTones(shade, raiseBlend: blend),
                // Swapped at the ramp's midpoint rather than crossfaded: two
                // palette entries have no legal colours between them.
                speckleTones: Palette.speckleTones(raised: blend >= 0.5),
                scale: scale,
                size: size,
                isFlashing: isFlashing
            ),
            into: &context,
            at: now
        )
    }

    // MARK: - Clocks

    /// How far along the colour ramp this cloud is, `0` resting to `1` raised.
    private func raiseBlend(at now: TimeInterval) -> Double {
        guard let raiseChangedAt else { return isRaised ? 1 : 0 }

        let elapsed = now - raiseChangedAt.timeIntervalSinceReferenceDate
        let linear = min(max(elapsed / GameRules.cloudRaiseTintDuration, 0), 1)

        // Smoothstep, so the colour eases in and out rather than starting and
        // stopping dead. The lift it rides on is a spring; a linear tint against
        // an eased movement is what makes the two read as separate events.
        let travelled = linear * linear * (3 - 2 * linear)

        return isRaised ? travelled : 1 - travelled
    }

    /// How much of the cluster is left, easing toward its new wear state.
    private func wearScale(at now: TimeInterval) -> CGFloat {
        let target = GameRules.cloudScale(health)
        guard let wearStartedAt else { return target }

        let elapsed = now - wearStartedAt.timeIntervalSinceReferenceDate
        let linear = min(max(elapsed / GameRules.cloudWearDuration, 0), 1)
        let eased = CGFloat(linear * linear * (3 - 2 * linear))

        return wearFrom + (target - wearFrom) * eased
    }

    private func drift(at now: TimeInterval) -> CGSize {
        CloudCluster.drift(at: point, time: now, scale: scale)
    }
}

// MARK: - CloudGlintSpiral

/// An open spiral, wound outward from its centre.
///
/// Archimedean — radius grows in step with angle, so the gap between windings
/// stays even. The alternative, a logarithmic spiral, opens ever faster and at
/// this size would just look like a comma.
///
/// Drawn rather than sprited for the same reason the clouds are: every cloud
/// gets its own, and the tilt and scale are continuous.
struct CloudGlintSpiral: Shape {

    /// Windings, fractional. See `GameRules.cloudGlintTurns`.
    var turns: Double

    /// The curl at unit size, centred on the origin, built once.
    ///
    /// The cloud field draws eight of these per square across forty-eight
    /// squares — 384 curls a frame, each of which was re-running its own sine
    /// and cosine per segment. The shape never changes, only its size, angle and
    /// place, so it is generated once and moved with a transform. This was the
    /// single largest cost in drawing Astra.
    static let unit: Path = CloudGlintSpiral(turns: GameRules.cloudGlintTurns)
        .path(in: CGRect(x: -0.5, y: -0.5, width: 1, height: 1))

    /// Segments per turn. Enough that the curve is smooth at this size without
    /// building a path nobody can see the detail of.
    private let resolution = 24

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let centre = CGPoint(x: rect.midX, y: rect.midY)
        let maxRadius = min(rect.width, rect.height) / 2
        let sweep = turns * 2 * .pi
        let steps = max(Int(Double(resolution) * turns), 2)

        for step in 0...steps {
            let progress = Double(step) / Double(steps)
            let angle = progress * sweep
            let radius = maxRadius * progress

            let point = CGPoint(
                x: centre.x + CGFloat(cos(angle)) * radius,
                y: centre.y + CGFloat(sin(angle)) * radius
            )

            if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }

        return path
    }
}

// MARK: - CloudCluster

/// The shape of a cluster: where its puffs sit and how big they are.
///
/// Shared with `CloudPoofView` so a dispersing cloud scatters the puffs it
/// actually had, rather than a fresh set that happens to look similar.
enum CloudCluster {

    /// One puff's place in the cluster, in art pixels from the square's centre.
    struct Puff {
        let x: CGFloat
        let y: CGFloat
        let radius: CGFloat

        /// `0` for the lit crown, `1` for the shadowed body beneath it.
        ///
        /// Authored rather than derived from position, because the jitter that
        /// keeps squares from looking stamped would otherwise flip a puff's
        /// layer when it nudged across a boundary — and because from directly
        /// above, position tells you nothing about depth anyway.
        let depth: Double
    }

    /// The base arrangement: three stacked layers of puffs filling the square,
    /// darkest and broadest underneath.
    ///
    /// ## Why it is round rather than cloud-shaped
    ///
    /// This is a top-down board. A cloud drawn in profile — flat base, domed
    /// top — is a side-scroller's cloud, and reads as a sticker lying on the
    /// grid. Seen from above there is no up: the mass spreads as far vertically
    /// as it does horizontally, and the cluster nearly fills its cell so that
    /// neighbours crowd each other and the squares read as a continuous deck.
    ///
    /// ## Why the layers do not cover each other
    ///
    /// The broad dark layer is deliberately wider than the light one on top of
    /// it, and the light puffs are spaced to leave gaps. Dark showing between
    /// them is what gives the cluster depth — a solid light cap would be a
    /// circle, not a volume.
    private static let base: [Puff] = [
        // The shadowed body, spread wide so it shows through everywhere above.
        Puff(x:  0.0, y:  0.0, radius: 5.4, depth: 1.0),
        Puff(x: -3.4, y: -3.0, radius: 4.2, depth: 0.95),
        Puff(x:  3.4, y: -3.0, radius: 4.2, depth: 0.95),
        Puff(x: -3.4, y:  3.2, radius: 4.2, depth: 0.95),
        Puff(x:  3.4, y:  3.2, radius: 4.2, depth: 0.95),
        // The mid tone, pushed out to the four compass points.
        Puff(x:  0.0, y: -4.4, radius: 3.6, depth: 0.5),
        Puff(x:  0.0, y:  4.4, radius: 3.4, depth: 0.55),
        Puff(x: -4.6, y:  0.0, radius: 3.6, depth: 0.5),
        Puff(x:  4.6, y:  0.0, radius: 3.6, depth: 0.55),
        // The lit crown, spaced so the body shows between the four of them.
        Puff(x: -2.0, y: -1.8, radius: 3.4, depth: 0.0),
        Puff(x:  2.0, y: -1.6, radius: 3.4, depth: 0.05),
        Puff(x: -1.7, y:  2.0, radius: 3.0, depth: 0.1),
        Puff(x:  1.9, y:  2.1, radius: 2.9, depth: 0.05),
    ]

    /// Painter's order: deepest first, so the crown lands on top.
    static let drawOrder: [Int] = base.indices.sorted { base[$0].depth > base[$1].depth }

    /// The body and mid layers, and the lit crown, split so curls can be drawn
    /// between them and end up half-buried in the cloud.
    static let bodyOrder: [Int] = drawOrder.filter { base[$0].depth >= crownDepth }
    static let crownOrder: [Int] = drawOrder.filter { base[$0].depth < crownDepth }

    /// Where the crown begins.
    private static let crownDepth: Double = 0.3

    /// This square's version of puff `index`, jittered so no two squares carry
    /// an identical cloud.
    static func puff(_ index: Int, at point: GridPoint) -> Puff {
        let template = base[index % base.count]
        let wobble = hash(point, salt: index)

        return Puff(
            x: template.x + (wobble - 0.5) * 1.6,
            y: template.y + (hash(point, salt: index + 31) - 0.5) * 1.2,
            radius: template.radius * (0.85 + wobble * 0.3),
            depth: template.depth
        )
    }

    /// Which tone a puff takes, from its depth.
    ///
    /// Shading by height rather than by index: the cluster has to read as one
    /// lit volume, and alternating tones around the ring made it read as a
    /// handful of separate balls.
    static func tone(_ puff: Puff, tones: [Color]) -> Color {
        let step = Int(puff.depth * Double(tones.count))
        return tones[min(step, tones.count - 1)]
    }

    /// How much bigger or smaller this puff is right now.
    ///
    /// Each puff has its own period *and* its own phase, so the cluster boils
    /// gently instead of inflating and deflating as one lump — which is the
    /// difference between something alive and something being scaled.
    static func pulse(_ index: Int, at point: GridPoint, time: TimeInterval) -> CGFloat {
        let roll = hash(point, salt: index + 101)
        let period = GameRules.cloudPulseFastest
            + (GameRules.cloudPulseSlowest - GameRules.cloudPulseFastest) * roll
        let wave = sin(time / period * 2 * .pi + hash(point, salt: index + 211) * 2 * .pi)

        return 1 + GameRules.cloudPulseSwing * CGFloat(wave) / 2
    }

    /// One fleck of light, and how bright it is right now.
    ///
    /// Scattered through the cluster rather than placed on it: these are what
    /// make the cloudstuff read as astral rather than as weather.
    static func speckle(
        _ index: Int,
        at point: GridPoint,
        time: TimeInterval
    ) -> (x: CGFloat, y: CGFloat, size: CGFloat, opacity: Double) {
        let angle = hash(point, salt: index + 401) * 2 * .pi
        // Square-rooted, like the curls: sampling radius uniformly puts half of
        // them inside the middle quarter of the disc's area.
        let reach = GameRules.cloudSpeckleSpread
            * CGFloat(hash(point, salt: index + 503).squareRoot())
        let roll = hash(point, salt: index + 601)
        let grade = hash(point, salt: index + 709)

        let period = GameRules.cloudPulseFastest
            + (GameRules.cloudPulseSlowest - GameRules.cloudPulseFastest) * roll
        let wave = (sin(time / period * 2 * .pi + roll * 2 * .pi) + 1) / 2

        let span = GameRules.cloudSpeckleMinScale
            + (GameRules.cloudSpeckleMaxScale - GameRules.cloudSpeckleMinScale) * CGFloat(grade)

        return (
            x: CGFloat(cos(angle)) * reach,
            y: CGFloat(sin(angle)) * reach,
            size: GameRules.cloudSpeckleSize * span * (0.75 + 0.5 * CGFloat(wave)),
            opacity: 0.35 + 0.65 * wave
        )
    }

    /// One curl: where it lies, how it leans, and how bright it is now.
    ///
    /// Scattered through the whole cluster. What keeps the lit set from
    /// flattening the shading is that it is drawn *after* the crown while the
    /// buried set is drawn under it — the layering, not where they sit.
    static func glint(
        _ index: Int,
        at point: GridPoint,
        time: TimeInterval
    ) -> (x: CGFloat, y: CGFloat, angle: Double, length: CGFloat, opacity: Double) {
        let across = hash(point, salt: index + 701)
        let up = hash(point, salt: index + 809)
        let tilt = hash(point, salt: index + 907)
        let roll = hash(point, salt: index + 1009)
        let size = hash(point, salt: index + 1103)
        let way = hash(point, salt: index + 1201)

        // Resting tilt, leaning either way.
        let lean = GameRules.cloudGlintMinAngle
            + (GameRules.cloudGlintMaxAngle - GameRules.cloudGlintMinAngle) * tilt
        let rest = roll < 0.5 ? lean : -lean

        // A slow turn on top of it, winding whichever way this curl was dealt.
        let spinPeriod = GameRules.cloudGlintSpinFastest
            + (GameRules.cloudGlintSpinSlowest - GameRules.cloudGlintSpinFastest) * way
        let spin = (way < 0.5 ? -1.0 : 1.0) * time / spinPeriod * 360

        // Breathes on the same clocks the puffs and speckles use.
        let period = GameRules.cloudPulseFastest
            + (GameRules.cloudPulseSlowest - GameRules.cloudPulseFastest) * roll
        let wave = (sin(time / period * 2 * .pi + tilt * 2 * .pi) + 1) / 2

        let span = GameRules.cloudGlintMinScale
            + (GameRules.cloudGlintMaxScale - GameRules.cloudGlintMinScale) * CGFloat(size)

        return (
            x: CGFloat(across - 0.5) * GameRules.cloudGlintSpread,
            y: CGFloat(up - 0.5) * GameRules.cloudGlintSpread,
            angle: rest + spin,
            length: span * (0.9 + 0.2 * CGFloat(wave)),
            opacity: 0.45 + 0.55 * wave
        )
    }

    /// Where this square's cloud has wandered to, in points.
    ///
    /// A slow wander, out of phase per square, deliberately under an art pixel:
    /// a cloud that visibly moved would fight the grid the player is counting
    /// squares on.
    ///
    /// Public and static because the piece standing on a cloud has to sway with
    /// it. Two copies of this would drift apart the first time either was
    /// retuned, and a piece sliding off its own footing is worse than no sway at
    /// all.
    static func drift(at point: GridPoint, time: TimeInterval, scale: CGFloat) -> CGSize {
        let clock = time / GameRules.cloudDriftPeriod * 2 * .pi
        let offset = phase(at: point)
        let amount = GameRules.cloudDriftAmount * scale

        return CGSize(
            width: CGFloat(sin(clock + offset)) * amount,
            height: CGFloat(cos(clock * 0.8 + offset)) * amount * 0.6
        )
    }

    /// This square's drift offset, so neighbouring clouds do not breathe in
    /// unison.
    static func phase(at point: GridPoint) -> Double {
        hash(point, salt: 7) * 2 * .pi
    }

    /// Deterministic `0`…`1` from a square and a salt.
    ///
    /// Stable across frames and across launches: a cluster that reshuffled would
    /// read as static rather than as cloud.
    ///
    /// ## Why the avalanche step matters
    ///
    /// The obvious version — `(x * A) ^ (y * B) ^ (salt * C)` — is not good
    /// enough here, and fails in a way that is visible on screen. A curl takes
    /// its `x` from one salt and its `y` from another, and those two salts
    /// always differ by the same amount. XOR barely propagates that difference
    /// into the low bits, so the two draws come back nearly equal and every curl
    /// lands near the line `y = x`: a cluster of spirals strung along a 45°
    /// diagonal.
    ///
    /// This is the murmur3 finalizer, which is built to make one bit of input
    /// change about half the output bits. Neighbouring salts decorrelate, and
    /// the scatter is actually a scatter.
    static func hash(_ point: GridPoint, salt: Int) -> Double {
        let seed = point.x &* 73_856_093 &+ point.y &* 19_349_663 &+ salt &* 83_492_791

        var z = UInt64(bitPattern: Int64(seed))
        z = (z ^ (z >> 33)) &* 0xFF51_AFD7_ED55_8CCD
        z = (z ^ (z >> 33)) &* 0xC4CE_B9FE_1A85_EC53
        z ^= z >> 33

        return Double(z % 10_000) / 10_000
    }
}

// MARK: - Painting

extension CloudCluster {

    /// Everything one cluster needs to be drawn.
    ///
    /// A struct rather than nine arguments because both callers — a single tile
    /// and the whole field — assemble the same set, and the field assembles 49
    /// of them a frame.
    struct Brush {
        /// Where the square's centre is, in the context's coordinates.
        var centre: CGPoint

        /// Which square, so the cluster is its own.
        var point: GridPoint

        /// How much of the cluster is left, `0`…`1`.
        var wear: CGFloat

        /// Body tones, crown first.
        var tones: [Color]

        /// The flecks' two colours.
        var speckleTones: [Color]

        /// Points per art pixel.
        var scale: CGFloat

        /// Rendered edge length of one square, in points.
        var size: CGFloat

        var isFlashing: Bool
    }

    /// Paints one cluster.
    ///
    /// Order is the whole design: shaded body, curls half-buried in it, lit
    /// crown over those, cloud-toned curls stitching the two together, then the
    /// flecks of light on top.
    ///
    /// Takes the context by value and restores nothing — callers that draw more
    /// than one cluster hand it a fresh copy each time, which is cheaper than
    /// unwinding transforms and cannot leak state between squares.
    /// Which half of a cluster to lay down.
    ///
    /// Split so something can be drawn *inside* the cloud: the body goes down,
    /// then whatever is being carried, then the crown over the top of it. That
    /// is the whole trick behind an arrow arriving wrapped in cloud.
    enum Layer {
        case body
        case crown
        case whole
    }

    static func paint(
        _ brush: Brush,
        into context: inout GraphicsContext,
        at now: TimeInterval,
        layer: Layer = .whole
    ) {
        guard brush.wear > 0 else { return }

        let scale = brush.scale
        let point = brush.point
        let drift = drift(at: point, time: now, scale: scale)

        // Everything below is authored in art pixels from the square's centre,
        // so the centre becomes the origin and the wear shrink becomes a scale
        // about it.
        context.translateBy(
            x: brush.centre.x + drift.width,
            y: brush.centre.y + drift.height
        )
        context.scaleBy(x: brush.wear, y: brush.wear)

        func fill(puff index: Int) {
            let puff = puff(index, at: point)
            let radius = puff.radius * scale * pulse(index, at: point, time: now)
            let box = CGRect(
                x: puff.x * scale - radius,
                y: puff.y * scale - radius,
                width: radius * 2,
                height: radius * 2
            )
            context.fill(Path(ellipseIn: box), with: .color(tone(puff, tones: brush.tones)))
        }

        /// - Parameter salt: Offsets the hashes, so the buried curls and the
        ///   ones stitched over the crown are not the same curls drawn twice.
        func stroke(curls count: Int, salt: Int, tones: [Color]) {
            let style = StrokeStyle(
                lineWidth: GameRules.cloudGlintThickness * scale,
                lineCap: .round
            )

            for index in 0..<count {
                let glint = glint(index + salt, at: point, time: now)
                let span = GameRules.cloudGlintLength * scale * glint.length

                // The prebuilt unit curl, scaled, turned about its own middle,
                // then carried out to where it sits.
                let path = CloudGlintSpiral.unit.applying(
                    CGAffineTransform(translationX: glint.x * scale, y: glint.y * scale)
                        .rotated(by: glint.angle * .pi / 180)
                        .scaledBy(x: span, y: span)
                )

                context.stroke(
                    path,
                    with: .color(tones[index % tones.count].opacity(glint.opacity)),
                    style: style
                )
            }
        }

        if layer != .crown {
            for index in bodyOrder { fill(puff: index) }
            stroke(curls: GameRules.cloudGlintBuriedCount, salt: 0,
                   tones: [brush.tones[0], brush.tones[1]])
        }

        guard layer != .body else { return }

        for index in crownOrder { fill(puff: index) }
        stroke(curls: GameRules.cloudGlintMaskCount, salt: 2_048, tones: [brush.tones[0]])

        // Light adds; cloudstuff does not.
        context.blendMode = .plusLighter

        for index in 0..<GameRules.cloudSpeckleCount {
            let fleck = speckle(index, at: point, time: now)
            let radius = fleck.size * scale / 2
            let box = CGRect(
                x: fleck.x * scale - radius,
                y: fleck.y * scale - radius,
                width: radius * 2,
                height: radius * 2
            )
            context.fill(
                Path(ellipseIn: box),
                with: .color(
                    brush.speckleTones[index % brush.speckleTones.count]
                        .opacity(fleck.opacity * GameRules.cloudSpeckleOpacity)
                )
            )
        }

        if brush.isFlashing {
            let radius = brush.size * 0.25
            context.fill(
                Path(ellipseIn: CGRect(x: -radius, y: -radius,
                                       width: radius * 2, height: radius * 2)),
                with: .color(Palette.pink.opacity(0.5))
            )
        }
    }
}
