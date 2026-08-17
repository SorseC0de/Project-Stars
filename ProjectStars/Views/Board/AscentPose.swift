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
        // **Nothing.** The whole world slides on a plane change now, and the
        // piece and the island are standing on it — so a lift of their own moves
        // them a second time, out of the row they belong to and in front of a
        // board that should be covering them.
        //
        // Kept as a named pose rather than deleted because the sequence still
        // asks for it, and because a rise that means "ride the board" is worth
        // saying out loud where the next person looks for it.
        _ = progress
        _ = boardSize
        return .rest
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
        // **Down, not smaller.** The board is drawn in depth-sorted rows now,
        // so a thing leaving by shrinking is being sent away by a trick the
        // board no longer needs — and one that fights it, since the rows are
        // already saying how far away everything is. It slides out of its row
        // instead and the row in front covers it, which is the same exit the
        // fiction describes.
        _ = goingUp
        return AscentPose(lift: p * boardSize * GameRules.ascentRiseHeight, scale: 1)
    }

    /// Arriving on Astra: swells from nothing at the centre of the tile.
    ///
    /// Overshoots very slightly before settling, which reads as the island
    /// dropping into place rather than inflating.
    static func growing(progress: Double, boardSize: CGFloat) -> AscentPose {
        let p = CGFloat(min(max(progress, 0), 1))
        // Up from below, because you arrive on Astra by climbing through its
        // floor rather than falling out of its sky.
        //
        // This is the **island's own** arrival, not a passenger's — the piece
        // riding it is carried by the world slide instead, and asking for both
        // is what put it in front of the board. See `BoardView.ascentPose`.
        let overshoot = 0.12 * sin(.pi * Double(p))
        return AscentPose(
            lift: (1 - p + CGFloat(overshoot)) * boardSize * GameRules.ascentRiseHeight,
            scale: 1
        )
    }
}
