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
                // Underside first, top surface last: the muffin's lit crown has
                // to overlap the shaded body, not the other way round.
                ForEach(CloudCluster.drawOrder, id: \.self) { index in
                    puffView(index, at: now)
                }
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
                    .fill(Palette.ice)
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

        return ZStack {
            Circle().fill(CloudCluster.tone(puff, tones: tones))

            // A smaller, brighter cap on the puffs facing the sky. This is the
            // whole cel-shaded read: two flat tones meeting on a hard edge,
            // rather than a gradient that would turn to mud across 16 pixels.
            if puff.depth < 0.5 {
                Circle()
                    .fill(tones[0])
                    .scaleEffect(GameRules.cloudCapScale)
                    .offset(y: -puff.radius * scale * GameRules.cloudCapRise)
            }
        }
        .frame(width: diameter, height: diameter)
        .offset(x: puff.x * scale, y: puff.y * scale)
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

        /// `0` for the sunlit top surface, `1` for the shaded underside.
        ///
        /// Authored rather than derived from `y`, because the jitter that keeps
        /// squares from looking stamped would otherwise flip a puff's shading
        /// when it nudged across the midline.
        let depth: Double
    }

    /// The base arrangement: a flattish muffin — a broad domed crown carrying
    /// most of the mass, tucking into a narrower base.
    ///
    /// Authored top-first. Clouds seen from slightly above are top-heavy; the
    /// earlier wide-bodied arrangement read as a puddle.
    private static let base: [Puff] = [
        // The crown, left to right.
        Puff(x: -4.7, y: -1.4, radius: 3.3, depth: 0.15),
        Puff(x: -1.7, y: -2.7, radius: 3.9, depth: 0.0),
        Puff(x:  1.8, y: -2.5, radius: 3.8, depth: 0.05),
        Puff(x:  4.8, y: -1.2, radius: 3.1, depth: 0.2),
        // The base, tucked in under it.
        Puff(x: -2.6, y:  1.5, radius: 2.9, depth: 0.7),
        Puff(x:  0.4, y:  1.9, radius: 3.0, depth: 0.75),
        Puff(x:  3.0, y:  1.3, radius: 2.7, depth: 0.7),
        Puff(x:  0.2, y:  3.5, radius: 2.1, depth: 1.0),
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
