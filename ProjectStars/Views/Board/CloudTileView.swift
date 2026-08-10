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

    var body: some View {
        TimelineView(.animation) { timeline in
            let now = timeline.date.timeIntervalSinceReferenceDate
            let drift = drift(at: now)
            let blend = raiseBlend(at: now)
            let tones = Palette.cloudTones(shade, raiseBlend: blend)

            ZStack {
                // Deepest first: the lit crown has to land on top of the
                // shaded body, not the other way round.
                ForEach(CloudCluster.bodyOrder, id: \.self) { index in
                    puffView(index, at: now, tones: tones)
                }

                // Between the layers, so the crown half-covers them.
                glints(
                    at: now,
                    count: GameRules.cloudGlintBuriedCount,
                    salt: 0,
                    tones: [tones[0], tones[1]],
                    additive: false
                )

                ForEach(CloudCluster.crownOrder, id: \.self) { index in
                    puffView(index, at: now, tones: tones)
                }

                // Cloud-coloured, over the crown: these cut across the buried
                // curls and mix the two sets together.
                glints(
                    at: now,
                    count: GameRules.cloudGlintMaskCount,
                    salt: 2_048,
                    tones: [tones[0]],
                    additive: false
                )

                speckles(at: now, blend: blend)
            }
            // The whole cluster shrinks toward its own centre as it wears.
            .scaleEffect(GameRules.cloudScale(health))
            .offset(x: drift.width, y: drift.height)
            .animation(.spring(response: 0.34, dampingFraction: 0.75), value: health)
        }
        .frame(width: size, height: size)
        .overlay {
            if isFlashing {
                Circle()
                    .fill(Palette.pink)
                    .frame(width: size * 0.5, height: size * 0.5)
                    .blendMode(.plusLighter)
                    .opacity(0.5)
            }
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
        //
        // The wear shrink below sets its own animation explicitly, which
        // survives this.
        .transaction { $0.animation = nil }
        // The raised cloud is a different view from the ordinary one — it is
        // depth-sorted with the pieces rather than laid down with the board — so
        // it arrives already raised and has to start its ramp on appear.
        .onAppear { if isRaised { raiseChangedAt = .now } }
        .onChange(of: isRaised) { raiseChangedAt = .now }
    }

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

    /// One puff, breathing on its own clock.
    private func puffView(_ index: Int, at now: TimeInterval, tones: [Color]) -> some View {
        let puff = CloudCluster.puff(index, at: point)
        let diameter = puff.radius * 2 * scale * CloudCluster.pulse(index, at: point, time: now)

        return Circle()
            .fill(CloudCluster.tone(puff, tones: tones))
            .frame(width: diameter, height: diameter)
            .offset(x: puff.x * scale, y: puff.y * scale)
    }

    /// Flecks of blue and gold caught in the cloudstuff.
    private func speckles(at now: TimeInterval, blend: Double) -> some View {
        ZStack {
            ForEach(0..<GameRules.cloudSpeckleCount, id: \.self) { index in
                let fleck = CloudCluster.speckle(index, at: point, time: now)
                // Swapped at the ramp's midpoint rather than crossfaded: two
                // palette entries have no legal colours between them.
                let tones = Palette.speckleTones(raised: blend >= 0.5)

                Circle()
                    .fill(tones[index % tones.count])
                    .frame(width: fleck.size * scale, height: fleck.size * scale)
                    .offset(x: fleck.x * scale, y: fleck.y * scale)
                    .opacity(fleck.opacity)
            }
        }
        .blendMode(.plusLighter)
    }

    /// One set of curls.
    ///
    /// - Parameters:
    ///   - salt: Offsets the hashes, so the buried set and the lit set are not
    ///     the same curls drawn twice in different colours.
    ///   - additive: Light adds; cloudstuff does not.
    private func glints(
        at now: TimeInterval,
        count: Int,
        salt: Int,
        tones: [Color],
        additive: Bool
    ) -> some View {
        ZStack {
            ForEach(0..<count, id: \.self) { index in
                let glint = CloudCluster.glint(index + salt, at: point, time: now)
                let span = GameRules.cloudGlintLength * scale * glint.length

                CloudGlintSpiral(turns: GameRules.cloudGlintTurns)
                    .stroke(
                        tones[index % tones.count],
                        style: StrokeStyle(
                            lineWidth: GameRules.cloudGlintThickness * scale,
                            lineCap: .round
                        )
                    )
                    .frame(width: span, height: span)
                    .rotationEffect(.degrees(glint.angle))
                    .offset(x: glint.x * scale, y: glint.y * scale)
                    .opacity(glint.opacity)
            }
        }
        .blendMode(additive ? .plusLighter : .normal)
    }



    /// A slow wander, out of phase per square.
    ///
    /// Deliberately under an art pixel: a cloud that visibly moved would fight
    /// the grid the player is counting squares on.
    private func drift(at now: TimeInterval) -> CGSize {
        let phase = now / GameRules.cloudDriftPeriod * 2 * .pi
        let offset = CloudCluster.phase(at: point)
        let amount = GameRules.cloudDriftAmount * scale

        return CGSize(
            width: CGFloat(sin(phase + offset)) * amount,
            height: CGFloat(cos(phase * 0.8 + offset)) * amount * 0.6
        )
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
    private static func hash(_ point: GridPoint, salt: Int) -> Double {
        let seed = point.x &* 73_856_093 &+ point.y &* 19_349_663 &+ salt &* 83_492_791

        var z = UInt64(bitPattern: Int64(seed))
        z = (z ^ (z >> 33)) &* 0xFF51_AFD7_ED55_8CCD
        z = (z ^ (z >> 33)) &* 0xC4CE_B9FE_1A85_EC53
        z ^= z >> 33

        return Double(z % 10_000) / 10_000
    }
}
