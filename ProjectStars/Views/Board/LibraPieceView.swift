//
//  LibraPieceView.swift
//  Project Stars
//
//  The only piece that is assembled rather than drawn.
//

import SwiftUI

/// Libra, plus two arms and two sets of pans.
///
/// ## Why this is not one sprite
///
/// Because the scales are *carried*. They hang off the body at their own
/// heights, they swing while she stands still, and — the part that decides it —
/// they sit at different depths: facing toward or away, the arms pass behind her
/// and the pans hang in front. Drawn into the body sprite, the whole assembly
/// would be locked to one depth and one pose, and none of the movement the sign
/// is built around would be possible.
///
/// ## How the pieces are positioned
///
/// Every offset here is in **art pixels measured from the body's bottom edge**,
/// which works because the art was authored for it: an arm's lowest pixel sits
/// at the same height inside its cell as Libra's does inside his. Line the cells
/// up by their bottoms and the drawings line up too, so each number below is a
/// deliberate departure from that baseline rather than a measurement of the art.
///
/// ## Two drawings, four directions
///
/// North is south seen from behind, so one arm drawing serves both; the left arm
/// is the right one mirrored. In profile the far arm is the near one flipped
/// vertically. Four poses out of two cells, and no cell that can fall out of step
/// with its twin.
struct LibraPieceView: View {

    /// Which way she is facing.
    let facing: SwipeDirection

    /// Size of a board cell, in points.
    let tileSize: CGFloat

    /// Whole-pixel scale, for art-pixel offsets.
    let scale: CGFloat

    @Environment(\.ambientClock) private var ambientClock

    var body: some View {
        TimelineView(.animation) { timeline in
            let now = ambientClock(timeline.date.timeIntervalSinceReferenceDate)
            let sway = CGFloat(sin(now / GameRules.libraArmSwayPeriod * 2 * .pi))
                * GameRules.libraArmSway

            ZStack {
                // Behind the body.
                //
                // Facing toward or away, *both* arms pass behind her and both
                // sets of pans hang in front — she is holding them out. In
                // profile the far side of the assembly goes behind and the near
                // side in front, which is what puts her inside her own scales
                // rather than beside them.
                if isProfile {
                    limb(side: .far, sway: -sway)
                } else {
                    arm(side: .left, sway: -sway)
                    arm(side: .right, sway: sway)
                }

                PixelSprite(id: .piece(.libra)) { Color.clear }
                    .frame(width: tileSize, height: tileSize * 2)

                // In front of the body.
                if isProfile {
                    limb(side: .near, sway: sway)
                } else {
                    pans(side: .left, sway: -sway)
                    pans(side: .right, sway: sway)
                }
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Parts

    /// Which of a pair this is.
    private enum Side { case left, right, near, far }

    /// True while she is seen from the side, where the arms stack in depth
    /// rather than sitting either side of her.
    private var isProfile: Bool {
        facing == .left || facing == .right
            || facing == .upLeft || facing == .upRight
            || facing == .downLeft || facing == .downRight
    }

    /// An arm and its pans together, for the profile poses where the two share
    /// a depth.
    @ViewBuilder
    private func limb(side: Side, sway: CGFloat) -> some View {
        arm(side: side, sway: sway)
        pans(side: side, sway: sway)
    }

    /// One arm.
    private func arm(side: Side, sway: CGFloat) -> some View {
        PixelSprite(id: .libraArm(isProfile ? .eastWest : .northSouth)) { Color.clear }
            .frame(width: tileSize, height: tileSize)
            // Mirrored for the left arm facing toward or away; turned over for
            // the far arm in profile. Both are the same drawing seen from
            // somewhere else.
            .scaleEffect(
                x: side == .left ? -1 : 1,
                y: side == .far ? -1 : 1
            )
            .offset(x: armInset(side), y: armLift(side) + sway * scale)
    }

    /// The pans hanging off it.
    private func pans(side: Side, sway: CGFloat) -> some View {
        PixelSprite(id: .libraScales) { Color.clear }
            .frame(width: tileSize, height: tileSize)
            .scaleEffect(x: side == .left ? -1 : 1, y: 1)
            // Hung from the arm's lowest *pixel*, not from its cell.
            //
            // The pans' own top pixel is the top of their cell, so the drop is
            // however far down the arm's cell its foot sits, plus the gap. A
            // whole cell would be six pixels too far — the arm's foot is not at
            // its cell's edge, it is five pixels clear of it, the same as
            // Libra's own.
            .offset(
                x: armInset(side),
                y: armLift(side) + sway * scale
                    + (GameRules.libraArmFootInCell + GameRules.libraScalesGap) * scale
            )
    }

    // MARK: - Placement

    /// How far above the body's bottom edge an arm's cell sits.
    ///
    /// Negative because up is negative, and measured from the body's own bottom
    /// rather than its centre — the two sprites are different heights, so their
    /// centres mean nothing to each other.
    private func armLift(_ side: Side) -> CGFloat {
        let pixels: CGFloat = isProfile
            ? (side == .far ? GameRules.libraArmLiftEWBack : GameRules.libraArmLiftEW)
            : GameRules.libraArmLiftNS

        // The body is two tiles tall and the arm one, so aligning their bottoms
        // is already half a tile down from centre before anything is lifted.
        return CGFloat(GameRules.tilePixelSize) / 2 * scale - pixels * scale
    }

    /// And how far in from the middle.
    private func armInset(_ side: Side) -> CGFloat {
        guard !isProfile else { return 0 }
        return (side == .left ? 1 : -1) * GameRules.libraArmInsetNS * scale
    }
}
