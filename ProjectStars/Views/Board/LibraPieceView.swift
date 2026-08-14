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

    /// True while the meter is full, which is the only time the strings are lit.
    var isCharged = false

    /// The body's hop, so the hanging parts can decline it.
    var pose: HopPose = .rest

    /// Stone and moss, applied to one part at a time.
    ///
    /// Handed in rather than applied over the finished assembly, because the
    /// moss shader maps screen position onto art pixels — over a stack of
    /// offset parts it shades each as though it sat at the origin, so the
    /// overgrowth ignored every offset that puts an arm where it belongs.
    /// Flattening the stack first would fix the coordinates and clip the arms
    /// off, since they are drawn outside the body's frame on purpose.
    ///
    /// Each part shaded in its own space is both correct and what the shader was
    /// designed for: it is a per-sprite effect, and these are five sprites.
    var stone: ((AnyView, CGFloat) -> AnyView)?

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

                shaded(
                    PixelSprite(id: .piece(.libra)) { Color.clear }
                        .frame(width: tileSize, height: tileSize * 2),
                    cells: 2
                )

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
    ///
    /// The far pan is the backmost thing Libra has — behind its own arm, not
    /// just behind her. It hangs over the tile *beyond* her, so anything nearer
    /// the viewer should cover it, and that includes the arm holding it.
    @ViewBuilder
    private func limb(side: Side, sway: CGFloat) -> some View {
        if side == .far {
            pans(side: side, sway: sway)
            arm(side: side, sway: sway)
        } else {
            arm(side: side, sway: sway)
            pans(side: side, sway: sway)
        }
    }

    /// One arm.
    private func arm(side: Side, sway: CGFloat) -> some View {
        shaded(
            PixelSprite(id: .libraArm(isProfile ? .eastWest : .northSouth)) { Color.clear }
                .frame(width: tileSize, height: tileSize),
            cells: 1
        )
            // Mirrored for the left arm facing toward or away; turned over for
            // the far arm in profile. Both are the same drawing seen from
            // somewhere else.
            .scaleEffect(
                x: side == .left ? -1 : 1,
                y: side == .far ? -1 : 1
            )
            .modifier(Unsquashed(pose: pose))
            .offset(x: armInset(side), y: armLift(side) + sway * scale)
    }

    /// The pans hanging off it.
    private func pans(side: Side, sway: CGFloat) -> some View {
        // Pinned to one frame unless charged.
        //
        // Recolouring the strands to a single purple was not enough: the frames
        // move the cords as well as tint them, so it still shimmered. Uncharged
        // is one still drawing.
        shaded(
            strung(PixelSprite(id: .libraScales, frame: isCharged ? nil : 0) { Color.clear })
                .frame(width: tileSize, height: tileSize),
            cells: 1
        )
            .scaleEffect(x: side == .left ? -1 : 1, y: 1)
            // Hung from the arm's lowest *pixel*, not from its cell.
            //
            // The pans' own top pixel is the top of their cell, so the drop is
            // however far down the arm's cell its foot sits, plus the gap. A
            // whole cell would be six pixels too far — the arm's foot is not at
            // its cell's edge, it is five pixels clear of it, the same as
            // Libra's own.
            .modifier(Unsquashed(pose: pose))
            .offset(
                x: armInset(side) + scalesInset(side),
                y: armLift(side) + sway * scale
                    + (GameRules.libraArmFootInCell + scalesGap(side)) * scale
            )
    }

    /// One part, put through whatever treatment the piece is wearing.
    @ViewBuilder
    private func shaded(_ art: some View, cells: CGFloat) -> some View {
        if let stone {
            stone(AnyView(art), cells)
        } else {
            art
        }
    }

    /// The strings, dimmed unless the meter is full.
    ///
    /// They are drawn as three bright cords and cycle colour across the three
    /// frames, which is a lot of light for something that is on screen every
    /// turn — next to a piece whose own gem is a single dim pixel until it is
    /// charged, the scales looked lit the whole time.
    ///
    /// So they take the gem's own unlit purple by default and are left alone
    /// when the meter is full. The animation is still running underneath; with
    /// every strand mapped to one colour there is simply nothing to see, which
    /// makes the charged version read as the strings *coming on* rather than as
    /// a different drawing.
    @ViewBuilder
    private func strung(_ art: some View) -> some View {
        if isCharged {
            art
        } else {
            art.paletteSwap(
                Self.stringTones.map { PaletteSwap($0, GemTones.forElement(.air).dim) }
            )
        }
    }

    /// The colours the cords are drawn in, across the three frames.
    private static let stringTones: [Color] = [
        Palette.cyan, Palette.lightBlue, Palette.pink,
        Palette.sakura, Palette.yellow, Palette.yellowGreen,
    ]

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

    /// And how far from the middle.
    private func armInset(_ side: Side) -> CGFloat {
        guard !isProfile else { return 0 }
        return (side == .left ? 1 : -1) * GameRules.libraArmInsetNS * scale
    }

    /// How far this pan hangs below its arm.
    ///
    /// Per pose, since the pans are aiming at the squares the scales damage and
    /// those are in different places from each angle — see
    /// `GameRules.libraScalesGapNS`.
    private func scalesGap(_ side: Side) -> CGFloat {
        guard isProfile else { return GameRules.libraScalesGapNS }
        return side == .far ? GameRules.libraScalesGapEWBack : GameRules.libraScalesGapEW
    }

    /// The pans' own horizontal, on top of the arm's.
    ///
    /// Separate because a pan hangs plumb from the end of an arm rather than
    /// being welded to its middle — see `GameRules.libraScalesInsetX`.
    private func scalesInset(_ side: Side) -> CGFloat {
        guard !isProfile else { return 0 }
        return (side == .left ? 1 : -1) * GameRules.libraScalesInsetX * scale
    }
}

/// Cancels the body's squash and stretch for the parts that hang off it.
///
/// ## Why the scales do not pancake
///
/// A hop flattens and stretches the *piece*, which is right for a body pushing
/// off the ground and wrong for something dangling from it: a pan is a rigid
/// dish on a string, and squashing it with the shoulders it hangs from reads as
/// the whole figure being made of rubber.
///
/// The arms and pans are drawn inside the piece, so they inherit that transform
/// whether they want it or not. Inverting it here is cheaper and more honest
/// than lifting them out of the piece, which would cost them everything else the
/// piece carries — its position, its shadow, its charge glow.
private struct Unsquashed: ViewModifier {

    let pose: HopPose

    func body(content: Content) -> some View {
        content.scaleEffect(
            x: pose.scaleX == 0 ? 1 : 1 / pose.scaleX,
            y: pose.scaleY == 0 ? 1 : 1 / pose.scaleY,
            anchor: .top
        )
    }
}
