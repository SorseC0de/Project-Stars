//
//  CloudTileView.swift
//  Project Stars
//
//  Astra's squares: clusters of cloud rather than tiles.
//

import SwiftUI

/// One square of Astra, drawn as a tight cluster of small clouds.
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
            let drift = drift(at: timeline.date)

            ZStack {
                ForEach(0..<GameRules.cloudPuffCount, id: \.self) { index in
                    let puff = CloudCluster.puff(index, at: point)

                    Circle()
                        .fill(tones[index % tones.count])
                        .frame(width: puff.radius * 2 * scale, height: puff.radius * 2 * scale)
                        .offset(x: puff.x * scale, y: puff.y * scale)
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
                    .fill(Palette.white)
                    .frame(width: size * 0.5, height: size * 0.5)
                    .blendMode(.plusLighter)
                    .opacity(0.5)
            }
        }
        .allowsHitTesting(false)
    }

    private var tones: [Color] { Palette.cloudTones(shade) }

    /// A slow wander, out of phase per square.
    ///
    /// Deliberately under an art pixel: a cloud that visibly moved would fight
    /// the grid the player is counting squares on.
    private func drift(at date: Date) -> CGSize {
        let phase = date.timeIntervalSinceReferenceDate / GameRules.cloudDriftPeriod * 2 * .pi
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
    }

    /// The base arrangement: a wide low body with two bumps riding on top.
    ///
    /// Ordered so alternating indices alternate shades — neighbouring puffs take
    /// different tones, which is what produces the cel-shaded read rather than
    /// one flat blob.
    private static let base: [Puff] = [
        Puff(x: 0.0, y: 1.0, radius: 4.6),
        Puff(x: -4.2, y: 1.8, radius: 3.2),
        Puff(x: 4.2, y: 1.8, radius: 3.2),
        Puff(x: -2.0, y: -2.2, radius: 3.0),
        Puff(x: 2.4, y: -1.8, radius: 3.2),
        Puff(x: -1.4, y: 3.2, radius: 2.8),
        Puff(x: 2.0, y: 3.2, radius: 2.6),
    ]

    /// This square's version of puff `index`, jittered so no two squares carry
    /// an identical cloud.
    static func puff(_ index: Int, at point: GridPoint) -> Puff {
        let template = base[index % base.count]
        let wobble = hash(point, salt: index)

        return Puff(
            x: template.x + (wobble - 0.5) * 1.6,
            y: template.y + (hash(point, salt: index + 31) - 0.5) * 1.2,
            radius: template.radius * (0.85 + wobble * 0.3)
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
