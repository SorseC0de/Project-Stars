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

    /// What the piece is doing, if anything. See `GameSession.Movement`.
    var movement: GameSession.Movement?

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
            // The idle breath, and whatever the current move is doing on top of
            // it. A move overrides the breath rather than adding to it: the two
            // are the same pixels, and a balance that is being carried somewhere
            // is not idling.
            let idle = CGFloat(sin(now / GameRules.libraArmSwayPeriod * 2 * .pi))
                * GameRules.libraArmSway
            let travel = carriage(at: timeline.date)

            // The two terms are not the same kind of motion, and folding them
            // into one number is what made the landing dip invisible.
            //
            // The **breath** is a seesaw: one pan rises as the other falls, so
            // it is handed out with opposite signs. The **carry** is the whole
            // balance being lifted and set down, so both sides get it
            // identically. Sharing one value meant a landing pushed one pan a
            // pixel down and the other a pixel up — a scissor, not a bounce, and
            // at a pixel apiece it read as nothing happening at all.
            let carry = travel.lift ?? 0

            // A move overrides the breath rather than adding to it: the two are
            // the same pixels, and a balance being carried somewhere is not
            // idling.
            let breath = travel.lift == nil ? idle : 0

            ZStack {
                // On the ground, under everything.
                if isProfile {
                    panShadow(side: .far, sway: carry - breath, swing: travel.swing)
                    panShadow(side: .near, sway: carry + breath, swing: travel.swing)
                } else {
                    panShadow(side: .left, sway: carry - breath, swing: travel.swing)
                    panShadow(side: .right, sway: carry + breath, swing: travel.swing)
                }

                // Behind the body.
                //
                // Facing toward or away, *both* arms pass behind her and both
                // sets of pans hang in front — she is holding them out. In
                // profile the far side of the assembly goes behind and the near
                // side in front, which is what puts her inside her own scales
                // rather than beside them.
                if isProfile {
                    limb(side: .far, sway: carry - breath, swing: travel.swing)
                } else {
                    arm(side: .left, sway: carry - breath)
                    arm(side: .right, sway: carry + breath)
                }

                // The pose lands here and nowhere else.
                //
                // `PieceView` skips its usual whole-figure squash for Libra —
                // see `PieceView.posesItself` — because only the body pushes off
                // the ground. The arms and pans hang from it: they ride its
                // *lift*, which the piece still applies to the whole assembly,
                // and decline its squash, which is a thing a body does and a
                // dish on a string does not.
                shaded(
                    PixelSprite(id: .piece(.libra)) { Color.clear }
                        .frame(width: tileSize, height: tileSize * 2),
                    cells: 2
                )
                .scaleEffect(x: pose.scaleX, y: pose.scaleY, anchor: .bottom)

                // In front of the body.
                if isProfile {
                    limb(side: .near, sway: carry + breath, swing: travel.swing)
                } else {
                    // Both on the same beat, leaning apart.
                    //
                    // Staggering them in time was tried and is the more truthful
                    // pair of pendulums; the flare is the one that reads as a
                    // *balance* — two dishes thrown outward by the same shove,
                    // which is the shape the sign is named for.
                    pans(side: .left, sway: carry - breath, swing: travel.swing)
                    pans(side: .right, sway: carry + breath, swing: travel.swing)
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
    private func limb(side: Side, sway: CGFloat, swing: Double) -> some View {
        if side == .far {
            pans(side: side, sway: sway, swing: swing)
            arm(side: side, sway: sway)
        } else {
            arm(side: side, sway: sway)
            pans(side: side, sway: sway, swing: swing)
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
            .offset(x: armInset(side), y: armLift(side) + sway * scale)
    }

    /// The shadow a pan drops on the square below it.
    ///
    /// Its own, rather than being covered by the body's: the pans hang out over
    /// the squares either side of her — the squares they are about to trench —
    /// and a shadow is what says a thing is above the ground rather than painted
    /// on it. Sized inversely to height, which is the whole reason it is worth
    /// drawing: as a pan rises the shadow shrinks away from it, and as it comes
    /// down to meet the tile the shadow swells back to meet it.
    private func panShadow(side: Side, sway: CGFloat, swing: Double) -> some View {
        // How far off its resting height this pan is, in art pixels. Up is
        // negative, so a raised pan gives a positive lift.
        let lift = -sway

        let shrink = 1 - min(max(lift / GameRules.libraPanShadowRange, -1), 1)
            * GameRules.libraPanShadowSpread

        // Where the swing has actually carried the pan, on the ground.
        //
        // A shadow that stays put under a pan that has swung out is a shadow
        // painted on the tile. The pan pivots at the cord, so its foot travels
        // by the sine of the angle across the length it hangs — sideways in
        // profile, and toward or away from the viewer facing north-south, which
        // on a board seen from above is the same as up and down the screen.
        let hand: Double = side == .left ? -1 : 1
        let radians = isProfile
            ? swing * .pi / 180
            : swing * GameRules.libraDepthSwingScale * hand * .pi / 180
        let reach = sin(radians) * Double(tileSize) * GameRules.libraPanShadowTravel

        // A rocking pan travels across the ground; a pan turning into the screen
        // travels up and down it. Which one this is decides which axis the
        // shadow moves along.
        let rocks = isProfile || !GameRules.libraDepthSwingUsesKeystone
        let depth = rocks ? 0 : CGFloat(reach)

        return PieceShadowView(
            tileSize: tileSize,
            widthFraction: GameRules.libraPanShadowWidth,
            opacity: GameRules.libraPanShadowOpacity * Double(shrink)
        )
            .scaleEffect(shrink)
            // On the square the pan is actually over.
            //
            // A pan hangs above one of the two squares flanking Libra's facing —
            // the ones its trench lands on — so its shadow belongs on that
            // square, a whole tile out. It was placed with the *sprite's* own
            // offsets instead, which are how far the drawing sits from the body
            // and are zero in profile by design: seen from the side the two arms
            // stack in depth rather than spreading sideways. That put both
            // shadows underneath her.
            //
            // Which axis the tile lies along is simply which way she is facing.
            // In profile the flanks are north and south of her, so the far pan's
            // shadow goes up the screen and the near one's down; facing toward
            // or away they are east and west, and it goes sideways.
            .offset(
                x: (isProfile ? 0 : flank(side) * tileSize) + (rocks ? CGFloat(reach) : 0),
                // Short of a whole tile going up the screen, and a whole one
                // going across.
                //
                // The two axes are not the same distance. A board drawn with a
                // front edge on every tile is foreshortened vertically — the row
                // above is nearer than a tile's width — so a shadow pushed a
                // full `tileSize` up lands on the row *beyond* the one the pan
                // is over. Sideways there is no foreshortening and a tile is a
                // tile. See `GameRules.libraPanShadowFlankRise`.
                y: (isProfile ? flank(side) * tileSize * GameRules.libraPanShadowFlankRise : 0)
                    + CGFloat(GameRules.tilePixelSize) / 2 * scale
                    // Down onto the tile, the same way the body's shadow sits
                    // below the body — see `PieceView`.
                    + GameRules.pieceShadowDrop * scale
                    + depth
            )
    }

    /// Which side of Libra this pan's square is on: `-1` back or left, `+1`
    /// front or right. The axis is decided by the pose; this is only the sign.
    private func flank(_ side: Side) -> CGFloat {
        side == .left || side == .far ? -1 : 1
    }

    /// The pans hanging off it.
    private func pans(side: Side, sway: CGFloat, swing: Double = 0) -> some View {
        // Pinned to one frame unless charged.
        //
        // Recolouring the strands to a single purple was not enough: the frames
        // move the cords as well as tint them, so it still shimmered. Uncharged
        // is one still drawing.
        shaded(
            // Two drawings, not one drawing recoloured.
            //
            // The plain pans used to be the lit ones with every strand
            // palette-swapped to a single purple and the animation pinned to
            // frame zero — a shader and a frame lock to arrive at something that
            // is now just drawn. It also means the two can differ in more than
            // colour without any of this changing.
            PixelSprite(id: isCharged ? .libraScales : .libraScalesPlain) { Color.clear }
                .frame(width: tileSize, height: tileSize),
            cells: 1
        )
            .scaleEffect(x: side == .left ? -1 : 1, y: 1)
            // Swung from the very top of the pan, where the cord meets the arm.
            // A dish on a string pivots from where it hangs, not from its middle.
            //
            // ## Two axes, one pendulum
            //
            // In profile the swing is across the screen and an ordinary rotation
            // draws it. Facing toward or away it is *into* the screen, which a
            // flat rotation cannot show at all — which is why the north-south
            // poses had a swing running the whole time that was completely
            // invisible.
            //
            // So the same angle is spent on a rotation about the horizontal
            // axis instead, with perspective. That gives the three things a pan
            // swinging toward you actually does, from one number: it grows as it
            // comes forward and shrinks going back, it foreshortens vertically
            // at the extremes, and its far edge pinches narrower than its near
            // one. The scale-and-pinch trick, taken from the transform that
            // produces it rather than approximated with two of its symptoms.
            .modifier(PanSwing(
                degrees: swing,
                intoTheScreen: !isProfile,
                size: tileSize,
                hand: side == .left ? -1 : 1
            ))
            // Hung from the arm's lowest *pixel*, not from its cell.
            //
            // The pans' own top pixel is the top of their cell, so the drop is
            // however far down the arm's cell its foot sits, plus the gap. A
            // whole cell would be six pixels too far — the arm's foot is not at
            // its cell's edge, it is five pixels clear of it, the same as
            // Libra's own.
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

    // MARK: - Being carried

    /// What the current movement is doing to the scales.
    ///
    /// ## Two answers, because the two axes are different problems
    ///
    /// Moving **across** the screen, the pans trail: they swing back toward
    /// where Libra came from, overshoot the other way as she stops, and settle.
    /// That is what a hanging weight does when the thing holding it changes
    /// speed, and it is only visible from the side.
    ///
    /// Moving **toward or away**, the pans trail into the screen instead. It is
    /// the same pendulum on the same clock — only the transform that draws it
    /// changes, from a rotation across to one about the horizontal axis. See
    /// `PanSwing`. On top of that the arms lift, level with each other, and drop
    /// *below* their resting height as she lands: the pans meet the tile, which
    /// is the moment the ground is being charged for.
    ///
    /// Returns `nil` for `lift` when nothing is moving, so the idle breath keeps
    /// the pixels rather than being added to a zero.
    private func carriage(at date: Date) -> (swing: Double, lift: CGFloat?) {
        // Any movement that goes anywhere, not only the airborne ones.
        //
        // Gating this on `arcs` meant a slide carried the scales perfectly
        // still — which is backwards: a pan trails because the thing holding it
        // is changing speed, and being dragged along the ground changes speed
        // exactly as much as hopping does. Only a warp is exempt, having made no
        // journey to swing through.
        guard let movement, !movement.style.isInstant else { return (0, nil) }

        // ## A pendulum, on its own clock
        //
        // It ran on `movement.progress`, so the entire swing was born and buried
        // inside the hop — a fifth of a second, out and back, which is a
        // windscreen wiper rather than a hanging weight. A cape on somebody who
        // runs and stops keeps moving *after* they stop, and that trailing
        // settle is the whole read. So this has its own period and its own
        // damping, and outlives the movement that started it.
        //
        // ## Why exponential damping
        //
        // A decay still most of the way up at the second lobe made the forward
        // overshoot nearly the size of the backward lean — and the forward one
        // lands last, so it is the one that reads as *the* swing. Halving every
        // `libraSwingDamping` seconds makes the first, backward lean plainly the
        // largest thing that happens.
        let elapsed = date.timeIntervalSince(movement.start)
        let decay = exp(-elapsed / GameRules.libraSwingDamping)
        let step = movement.direction.unitOffset

        // Trailing means leaning *away* from the direction of travel: run east
        // and the pans hang west. Read off the step's own offset rather than by
        // naming `.right`, which answered the same as `.left` for every diagonal
        // — and which axis is asked is simply which one the viewer can see.
        //
        // Positive degrees is a clockwise turn, and the pans hang *below* the
        // anchor they rotate about, so a clockwise turn carries them east and
        // travelling east wants exactly that.
        //
        // ## Why north and south rock the same way
        //
        // Because the north-south motion is not a trail — the pans rock apart in
        // the viewer's plane, which is a stand-in for a swing that actually goes
        // into the screen. A stand-in has no direction to be faithful to, and
        // taking the sign from `dy` made the two directions mirror each other
        // for no reason the player can see: one of them read as scales rocking
        // and the other as scales snapping shut. So both take north's sense, and
        // `dy` decides only *whether* there is a swing at all.
        let along = isProfile
            ? Double(step.dx)
            : (step.dy == 0 ? 0 : GameRules.libraRockSense)

        let swing: Double = {
            guard decay > 0.02, along != 0 else { return 0 }
            let phase = elapsed / GameRules.libraSwingPeriod * 2 * .pi
            return sin(phase) * decay * GameRules.libraSwingAngle * along
        }()

        // The lift is the north-south answer only: seen from the side, a rise
        // and a dip are hidden behind the body that is doing them.
        guard !isProfile else { return (swing, nil) }

        let progress = movement.progress(at: date)
        guard progress < 1 else { return (swing, nil) }

        // Up while airborne, and a beat below resting as she arrives.
        let lift = progress < GameRules.libraLandFraction
            ? -GameRules.libraCarryLift
            : GameRules.libraLandDip
        return (swing, lift)
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

/// One pan's swing, drawn on whichever axis the viewer can see.
///
/// ## Why not two modifiers
///
/// Because it is one motion. A pan on a cord swings in the plane it was pushed
/// in; whether that plane happens to lie across the screen or into it is a fact
/// about where the camera is, not about the pan. Splitting it in two invites the
/// two halves to be tuned apart, which is how the north-south poses ended up
/// with no swing at all while the profile ones had one.
///
/// ## The north-south illusion
///
/// A swing into the screen cannot be drawn flat, so it is drawn as a keystone:
/// the edge nearer the viewer keeps its width, the far edge pinches in, and the
/// whole pan foreshortens vertically by the cosine of the angle. Three cues, and
/// between them they read as a dish turning to face you.
///
/// ## Why this is not `rotation3DEffect`
///
/// It was, and a perspective divide is the wrong tool at this size. The divide
/// is not symmetric — the same angle toward the viewer magnifies far more than
/// it shrinks going away — so facing south the pans ballooned while facing north
/// they barely moved. Turning the perspective up for a deeper pinch made the
/// near end explode, because a strong `m34` at sixteen pixels puts the bottom
/// edge close to the eye point, and cancelling that with a uniform scale only
/// traded it for a stretch: the magnification varies down the sprite and a
/// single multiplier does not.
///
/// Built as a projective transform instead, the taper and the size are separate
/// numbers. The widest the pan is ever drawn is its resting width, in either
/// direction — so the two ends of the swing match, and `libraDepthSwingTaper`
/// deepens the pinch without inflating anything.
private struct PanSwing: ViewModifier {

    let degrees: Double

    /// True when the swing is toward and away from the viewer rather than across
    /// the screen — which is to say, when Libra is facing toward or away.
    let intoTheScreen: Bool

    /// The pan's own size, which the keystone is measured against.
    let size: CGFloat

    /// Which way this pan rocks when the swing is drawn as a rock rather than as
    /// a turn — `-1` for the left pan, `+1` for the right.
    var hand: Double = 1

    func body(content: Content) -> some View {
        if intoTheScreen, GameRules.libraDepthSwingUsesKeystone {
            content.projectionEffect(keystone)
        } else if intoTheScreen {
            // ## The rock
            //
            // The alternative to drawing a swing that goes into the screen is
            // not drawing it: the two pans lean *apart* instead, each rocking on
            // its own cord in the plane the viewer can actually see.
            //
            // It is not what a real balance carried toward you would do, and it
            // is legible, which the honest version is not — a dish turning
            // edge-on at sixteen pixels is a few pixels of taper on a shape too
            // small to read it. Opposite signs are what keep it from looking
            // like the whole assembly is tilting: a pair leaning away from each
            // other is scales rocking, where a pair leaning the same way is a
            // piece falling over.
            content.rotationEffect(
                .degrees(degrees * GameRules.libraDepthSwingScale * hand),
                anchor: .top
            )
        } else {
            content.rotationEffect(.degrees(degrees), anchor: .top)
        }
    }

    /// The transform, in the pan's own coordinates.
    ///
    /// Everything happens about the top edge, where the cord is: a pan turning
    /// on its string does not move the point it hangs from.
    private var keystone: ProjectionTransform {
        let radians = degrees * GameRules.libraDepthSwingScale * .pi / 180
        let toward = sin(radians)

        // How much narrower the far edge is than the near one, at this angle.
        let pinch = GameRules.libraDepthSwingTaper * toward

        // Divides everything by `1 + q·y`, which narrows the sprite steadily
        // from the cord downward — or upward, when the swing is going away.
        let q = -pinch / size

        // The bottom edge would come out `1 / (1 - pinch)` wide swinging toward
        // the viewer, which is the ballooning. Scaled back so the widest edge is
        // never wider than the pan at rest, whichever way it is swinging.
        let level = min(1, 1 - pinch)

        var core = ProjectionTransform()
        core.m11 = level
        core.m22 = level * cos(radians)   // foreshortened, never taller than rest
        core.m23 = q
        core.m33 = 1

        let toAnchor = ProjectionTransform(CGAffineTransform(translationX: -size / 2, y: 0))
        let back = ProjectionTransform(CGAffineTransform(translationX: size / 2, y: 0))
        return toAnchor.concatenating(core).concatenating(back)
    }
}
