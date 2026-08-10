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

    /// Whole-pixel scale, for art-pixel distances.
    private var scale: CGFloat { size / CGFloat(GameRules.tilePixelSize) }

    var body: some View {
        TimelineView(.animation) { timeline in
            let now = timeline.date.timeIntervalSinceReferenceDate
            let drift = drift(at: now)

            ZStack {
                // Deepest first: the lit crown has to land on top of the
                // shaded body, not the other way round.
                ForEach(CloudCluster.drawOrder, id: \.self) { index in
                    puffView(index, at: now)
                }

                speckles(at: now)
                glints(at: now)
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
    }

    /// One puff, breathing on its own clock.
    private func puffView(_ index: Int, at now: TimeInterval) -> some View {
        let puff = CloudCluster.puff(index, at: point)
        let diameter = puff.radius * 2 * scale * CloudCluster.pulse(index, at: point, time: now)

        return Circle()
            .fill(CloudCluster.tone(puff, tones: tones))
            .frame(width: diameter, height: diameter)
            .offset(x: puff.x * scale, y: puff.y * scale)
    }

    /// Flecks of blue and gold caught in the cloudstuff.
    private func speckles(at now: TimeInterval) -> some View {
        ZStack {
            ForEach(0..<GameRules.cloudSpeckleCount, id: \.self) { index in
                let fleck = CloudCluster.speckle(index, at: point, time: now)
                let tones = Palette.cloudSpeckleTones

                Circle()
                    .fill(tones[index % tones.count])
                    .frame(width: fleck.size * scale, height: fleck.size * scale)
                    .offset(x: fleck.x * scale, y: fleck.y * scale)
                    .opacity(fleck.opacity)
            }
        }
        .blendMode(.plusLighter)
    }

    /// Slivers of light lying across the top of the cluster.
    private func glints(at now: TimeInterval) -> some View {
        ZStack {
            ForEach(0..<GameRules.cloudGlintCount, id: \.self) { index in
                let glint = CloudCluster.glint(index, at: point, time: now)
                let tones = Palette.cloudSpeckleTones

                Ellipse()
                    .fill(tones[index % tones.count])
                    .frame(
                        width: GameRules.cloudGlintLength * scale * glint.length,
                        height: GameRules.cloudGlintThickness * scale
                    )
                    .rotationEffect(.degrees(glint.angle))
                    .offset(x: glint.x * scale, y: glint.y * scale)
                    .opacity(glint.opacity)
            }
        }
        .blendMode(.plusLighter)
    }

    private var tones: [Color] { Palette.cloudTones(shade) }

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
        let reach = GameRules.cloudSpeckleSpread * CGFloat(hash(point, salt: index + 503))
        let roll = hash(point, salt: index + 601)

        let period = GameRules.cloudPulseFastest
            + (GameRules.cloudPulseSlowest - GameRules.cloudPulseFastest) * roll
        let wave = (sin(time / period * 2 * .pi + roll * 2 * .pi) + 1) / 2

        return (
            x: CGFloat(cos(angle)) * reach,
            y: CGFloat(sin(angle)) * reach,
            size: GameRules.cloudSpeckleSize * (0.6 + 0.8 * CGFloat(wave)),
            opacity: 0.35 + 0.65 * wave
        )
    }

    /// One glint: where it lies, how it leans, and how bright it is now.
    ///
    /// Confined to the upper half of the cluster. Light striking a volume from
    /// one side catches the same side of every puff; scattering these evenly
    /// would undo the layering the shading just established.
    static func glint(
        _ index: Int,
        at point: GridPoint,
        time: TimeInterval
    ) -> (x: CGFloat, y: CGFloat, angle: Double, length: CGFloat, opacity: Double) {
        let across = hash(point, salt: index + 701)
        let up = hash(point, salt: index + 809)
        let tilt = hash(point, salt: index + 907)
        let roll = hash(point, salt: index + 1009)

        let magnitude = GameRules.cloudGlintMinAngle
            + (GameRules.cloudGlintMaxAngle - GameRules.cloudGlintMinAngle) * tilt

        let period = GameRules.cloudPulseFastest
            + (GameRules.cloudPulseSlowest - GameRules.cloudPulseFastest) * roll
        let wave = (sin(time / period * 2 * .pi + tilt * 2 * .pi) + 1) / 2

        return (
            x: CGFloat(across - 0.5) * 9,
            // Upper half only, and never right at the crown's edge.
            y: -1 - CGFloat(up) * 4.5,
            angle: roll < 0.5 ? magnitude : -magnitude,
            length: 0.85 + 0.3 * CGFloat(wave),
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
    private static func hash(_ point: GridPoint, salt: Int) -> Double {
        let mixed = (point.x &* 73_856_093) ^ (point.y &* 19_349_663) ^ (salt &* 83_492_791)
        return Double(abs(mixed) % 10_000) / 10_000
    }
}
