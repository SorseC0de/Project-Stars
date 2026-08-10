//
//  HopPose.swift
//  Project Stars
//
//  The squash, stretch and arc of a piece mid-hop.
//

import CoreGraphics
import Foundation

/// How a piece is deformed and lifted at one instant of a hop.
///
/// Evaluated from elapsed time rather than driven by `keyframeAnimator`. The
/// keyframe animator was the obvious tool and the wrong one: it holds its last
/// value when the trigger stops changing, so a hop that was interrupted — or
/// simply finished while the view was rebuilt for another reason — left the
/// piece stretched and offset with nothing to put it back.
///
/// A pure function of elapsed time cannot get stuck. Past the end of the hop it
/// returns ``rest`` unconditionally, so the worst a glitch can do is skip the
/// animation rather than break the piece.
struct HopPose: Equatable {

    var scaleX: CGFloat
    var scaleY: CGFloat

    /// Height above the ground, in art pixels.
    var lift: CGFloat

    static let rest = HopPose(scaleX: 1, scaleY: 1, lift: 0)

    // MARK: - Curve

    /// One stop on the hop's timeline.
    private struct Stop {
        let t: Double
        let scaleX: CGFloat
        let scaleY: CGFloat
        let lift: CGFloat
    }

    /// The shape of a hop, as stops in normalised time.
    ///
    /// Wind up wide and flat, launch tall and thin, hang, land wide again,
    /// settle. The stretch peaks at 0.42 while the arc peaks at 0.42 too but
    /// falls away more slowly — the piece is still thin as it starts to descend,
    /// which is what makes the landing feel like it arrives rather than floats.
    private static var stops: [Stop] {
        [
            Stop(t: 0.00, scaleX: 1, scaleY: 1, lift: 0),
            Stop(t: 0.16, scaleX: GameRules.hopSquashX, scaleY: GameRules.hopSquashY, lift: 0),
            Stop(t: 0.42, scaleX: GameRules.hopStretchX, scaleY: GameRules.hopStretchY,
                 lift: GameRules.hopArcHeight),
            Stop(t: 0.68, scaleX: GameRules.hopStretchX, scaleY: GameRules.hopStretchY,
                 lift: GameRules.hopArcHeight * 0.5),
            Stop(t: 0.86, scaleX: GameRules.hopSquashX, scaleY: GameRules.hopSquashY, lift: 0),
            Stop(t: 1.00, scaleX: 1, scaleY: 1, lift: 0),
        ]
    }

    /// The pose at `progress` through a hop, where 1 is the end.
    ///
    /// Anything outside `0..<1` is ``rest`` — including a negative, so a hop
    /// scheduled slightly in the future does not deform the piece early.
    static func at(progress: Double) -> HopPose {
        guard progress > 0, progress < 1 else { return .rest }

        let table = stops
        guard let next = table.firstIndex(where: { $0.t >= progress }), next > 0 else {
            return .rest
        }

        let a = table[next - 1]
        let b = table[next]
        let span = b.t - a.t
        let raw = span > 0 ? (progress - a.t) / span : 1

        // Smoothstep between stops so the joins do not read as corners.
        let k = CGFloat(raw * raw * (3 - 2 * raw))

        return HopPose(
            scaleX: a.scaleX + (b.scaleX - a.scaleX) * k,
            scaleY: a.scaleY + (b.scaleY - a.scaleY) * k,
            lift: a.lift + (b.lift - a.lift) * k
        )
    }
}
