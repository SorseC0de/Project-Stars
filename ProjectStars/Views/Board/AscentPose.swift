//
//  AscentPose.swift
//  Project Stars
//
//  How the island and its passenger look mid-ascension.
//

import CoreGraphics
import Foundation

/// The lift and scale applied to both the Nexys and the piece riding it while
/// the island climbs from Terra back to Astra.
///
/// One value covering both, because the whole point of the ascent is that they
/// move as a single object — the island is carrying the piece, and any drift
/// between the two would break that.
///
/// Like `HopPose`, evaluated from elapsed time rather than driven by an
/// animation, so it cannot be left stuck part-way.
struct AscentPose: Equatable {

    /// Vertical offset in points. Negative is up.
    var lift: CGFloat

    /// Scale factor. Zero at the instant of arrival, growing to full.
    var scale: CGFloat

    static let rest = AscentPose(lift: 0, scale: 1)

    /// Climbing out of Terra: rises off the top of the screen at full size.
    ///
    /// Eased so it accelerates away rather than leaving at a constant crawl.
    static func rising(progress: Double, boardSize: CGFloat) -> AscentPose {
        let eased = CGFloat(progress * progress)
        return AscentPose(
            lift: -eased * boardSize * GameRules.ascentRiseHeight,
            scale: 1
        )
    }

    /// Dropping in from above the screen onto the plane below.
    ///
    /// The mirror of `rising`, and used for the same reason: an island arriving
    /// on Terra has come *down from Astra*, so it enters through the top of the
    /// screen. Growing it out of the tile would say it materialised there.
    static func fallingIn(progress: Double, boardSize: CGFloat) -> AscentPose {
        let p = min(max(progress, 0), 1)
        // Accelerates in, matching how the piece falls.
        let remaining = 1 - CGFloat(p * p)
        return AscentPose(
            lift: -remaining * boardSize * GameRules.ascentRiseHeight,
            scale: 1
        )
    }

    /// Rising into place from below the screen onto the plane above.
    ///
    /// The mirror of `fallingIn`, and the arrival that replaced `growing` for
    /// anything with a passenger. A thing that swelled out of the tile said it
    /// had materialised there; this says it came up through the hole, which is
    /// what actually happened — the same hole it went down through, seen from
    /// the other side.
    ///
    /// Decelerates rather than accelerating, because it is climbing against the
    /// fall's gravity rather than with it.
    static func risingIn(progress: Double, boardSize: CGFloat) -> AscentPose {
        let p = min(max(progress, 0), 1)
        // Eases *out*: fast off the mark, slowing into place.
        let remaining = CGFloat((1 - p) * (1 - p))
        return AscentPose(
            lift: remaining * boardSize * GameRules.ascentRiseHeight,
            scale: 1
        )
    }

    /// Leaving a plane under its own power: shrinks toward the tile centre
    /// while drifting the way it is headed.
    ///
    /// Used when the island travels *without* a passenger — the Pentacle sends
    /// it away rather than riding it — so it reads as the island departing
    /// rather than as the world moving.
    static func departing(progress: Double, boardSize: CGFloat, goingUp: Bool) -> AscentPose {
        let p = min(max(progress, 0), 1)
        // No vertical drift. The island is drawn in front of the tiles, so
        // sliding it downward reads as it moving *across* the board rather than
        // away from it — shrinking in place is what says "leaving".
        _ = goingUp
        _ = boardSize
        return AscentPose(lift: 0, scale: 1 - CGFloat(p))
    }

    /// Arriving on Astra: swells from nothing at the centre of the tile.
    ///
    /// Overshoots very slightly before settling, which reads as the island
    /// dropping into place rather than inflating.
    static func growing(progress: Double) -> AscentPose {
        let p = CGFloat(min(max(progress, 0), 1))
        let overshoot = 1 + 0.12 * sin(.pi * Double(p))
        return AscentPose(lift: 0, scale: p * CGFloat(overshoot))
    }
}
