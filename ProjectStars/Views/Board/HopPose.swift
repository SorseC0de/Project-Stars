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

    // MARK: - Big leaps

    /// The pose of a piece that has thrown itself into the air on purpose.
    ///
    /// Used by moves that are *about* the leap rather than moves that happen to
    /// cover ground: Taurus' Flowering Flop and Pisces' dive. Both go far higher
    /// than a hop, swell on the way up, and come down flattened — a hop is a
    /// step with an arc on it, and these are a decision to leave the board.
    ///
    /// - Parameter progress: `0` at the crouch, `1` back at rest.
    /// How a leap is shaped. See `HopPose.Weight.flop`.
    struct Weight: Equatable {
        var height: CGFloat
        var rise: CGFloat
        var pancakeX: CGFloat
        var pancakeY: CGFloat

        /// Pisces' dive, and the default for anything that leaves the ground
        /// deliberately.
        static let dive = Weight(
            height: GameRules.leapHeight,
            rise: GameRules.leapRiseScale,
            pancakeX: GameRules.leapPancakeX,
            pancakeY: GameRules.leapPancakeY
        )

        /// Taurus. Higher, bigger in the air, and flattened on arrival.
        static let flop = Weight(
            height: GameRules.flopHeight,
            rise: GameRules.flopRiseScale,
            pancakeX: GameRules.flopPancakeX,
            pancakeY: GameRules.flopPancakeY
        )
    }

    static func leap(progress: Double, weight: Weight = .dive) -> HopPose {
        guard progress > 0, progress < 1 else { return .rest }

        return interpolate(leapStops(weight), at: progress)
    }

    /// Up big, down flat.
    ///
    /// The landing stop is the point of the whole thing — twice as wide as it is
    /// anything else — so it holds a beat before settling rather than passing
    /// through on the way to rest.
    private static func leapStops(_ weight: Weight) -> [Stop] {
        [
            Stop(t: 0.00, scaleX: 1, scaleY: 1, lift: 0),
            Stop(t: 0.10, scaleX: GameRules.leapSquashX, scaleY: GameRules.leapSquashY, lift: 0),
            Stop(t: 0.45, scaleX: weight.rise, scaleY: weight.rise, lift: weight.height),
            Stop(t: 0.62, scaleX: weight.rise, scaleY: weight.rise, lift: weight.height * 0.92),
            Stop(t: 0.80, scaleX: weight.pancakeX, scaleY: weight.pancakeY, lift: 0),
            Stop(t: 0.92, scaleX: weight.pancakeX, scaleY: weight.pancakeY, lift: 0),
            Stop(t: 1.00, scaleX: 1, scaleY: 1, lift: 0),
        ]
    }

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
    /// - Parameter distance: Squares this hop covers. A longer jump arcs
    ///   higher — see `GameRules.hopArcHeightPerExtraTile`.
    static func at(progress: Double, distance: Int = 1) -> HopPose {
        var pose = at(progress: progress)
        guard distance > 1 else { return pose }

        let extra = CGFloat(distance - 1) * GameRules.hopArcHeightPerExtraTile
        pose.lift *= (1 + extra)
        return pose
    }

    private static func at(progress: Double) -> HopPose {
        interpolate(stops, at: progress)
    }

    /// Walks a table of stops and smoothsteps between the two either side.
    private static func interpolate(_ table: [Stop], at progress: Double) -> HopPose {
        guard progress > 0, progress < 1 else { return .rest }

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
