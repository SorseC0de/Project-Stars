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
                x: armInset(side) + scalesInset(side),
                y: armLift(side) + sway * scale
                    + (GameRules.libraArmFootInCell + scalesGap(side)) * scale
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

// MARK: - Preview

#if DEBUG
/// A bench for Libra's five parts, with every offset on a slider.
///
/// ## Why it is here and not in `Views/Previews/`
///
/// Because it is not a gallery of finished art — it is the tuning surface for
/// *this file*, and the numbers it moves are the constants declared beside it.
/// Kept next to what it adjusts, it goes stale the moment the assembly changes,
/// which is the point.
///
/// ## Why nothing moves
///
/// The sway and the pans' cycle are both off. Judging a resting position against
/// something that is drifting means waiting for it to come back round, and the
/// resting position is what every one of these numbers actually sets. There is a
/// switch for the sway when it is the sway itself being judged.
private struct LibraBench: View {

    @State private var facing: SwipeDirection = .down
    @State private var liftNS = GameRules.libraArmLiftNS
    @State private var liftEW = GameRules.libraArmLiftEW
    @State private var liftEWBack = GameRules.libraArmLiftEWBack
    @State private var insetNS = GameRules.libraArmInsetNS
    @State private var gapNS = GameRules.libraScalesGapNS
    @State private var gapEW = GameRules.libraScalesGapEW
    @State private var gapEWBack = GameRules.libraScalesGapEWBack
    @State private var scalesX = GameRules.libraScalesInsetX
    @State private var sway = false
    @State private var zoom: CGFloat = 6

    var body: some View {
        // Scrollable, because the stage grows with the zoom and a control you
        // cannot reach is a control you do not have.
        ScrollView {
            content
        }
        .background(Palette.background)
        .preferredColorScheme(.dark)
    }

    private var content: some View {
        VStack(spacing: 18) {
            stage

            // The settled numbers, in the shape they go back into the code as.
            //
            // A screenshot of a figure is a picture of a result nobody can act
            // on; a screenshot with the values under it is the answer written
            // down. This is here so the bench can be *reported* rather than
            // described.
            Text(summary)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Palette.textPrimary)
                .textSelection(.enabled)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Palette.warmBlack)
                .padding(.horizontal)

            VStack(spacing: 10) {
                Picker("Facing", selection: $facing) {
                    Text("N").tag(SwipeDirection.up)
                    Text("S").tag(SwipeDirection.down)
                    Text("E").tag(SwipeDirection.right)
                    Text("W").tag(SwipeDirection.left)
                }
                .pickerStyle(.segmented)

                slider("Arm lift N/S", $liftNS, 0...24)
                slider("Arm lift E/W near", $liftEW, 0...24)
                slider("Arm lift E/W far", $liftEWBack, 0...40)
                slider("Arm inset N/S", $insetNS, -12...12)
                slider("Scales gap N/S", $gapNS, -8...24)
                slider("Scales gap E/W near", $gapEW, -8...24)
                slider("Scales gap E/W far", $gapEWBack, -8...24)
                slider("Scales x", $scalesX, -16...16)
                slider("Zoom", $zoom, 2...12, unit: "x")

                Toggle("Animate", isOn: $sway)
            }
            .padding(.horizontal)
        }
        .padding(.top)
        // Clear of the home indicator, and of the canvas' own bottom edge.
        .padding(.bottom, 48)
        // Written straight back into the constants the game reads, so the board
        // in another preview pane shows the same thing — there is one set of
        // numbers and this is a window onto it, not a copy.
        .onChange(of: liftNS) { _, new in GameRules.libraArmLiftNS = new }
        .onChange(of: liftEW) { _, new in GameRules.libraArmLiftEW = new }
        .onChange(of: liftEWBack) { _, new in GameRules.libraArmLiftEWBack = new }
        .onChange(of: insetNS) { _, new in GameRules.libraArmInsetNS = new }
        .onChange(of: gapNS) { _, new in GameRules.libraScalesGapNS = new }
        .onChange(of: gapEW) { _, new in GameRules.libraScalesGapEW = new }
        .onChange(of: gapEWBack) { _, new in GameRules.libraScalesGapEWBack = new }
        .onChange(of: scalesX) { _, new in GameRules.libraScalesInsetX = new }
    }

    /// Every value, written as the constants they set.
    private var summary: String {
        """
        libraArmLiftNS      = \(Int(liftNS))
        libraArmLiftEW      = \(Int(liftEW))
        libraArmLiftEWBack  = \(Int(liftEWBack))
        libraArmInsetNS     = \(Int(insetNS))
        libraScalesGapNS    = \(Int(gapNS))
        libraScalesGapEW    = \(Int(gapEW))
        libraScalesGapEWBack= \(Int(gapEWBack))
        libraScalesInsetX   = \(Int(scalesX))
        """
    }

    /// The figure, on a tile, at whatever zoom is set.
    private var stage: some View {
        let tile = GameRules.tilePixelSize

        return ZStack {
            // Three squares of board, not one.
            //
            // The parts that hang highest and lowest — the far arm above, the
            // pans below — leave the square she is standing on entirely, and
            // against a single tile there is nothing to say whether that is
            // correct or merely far. Neighbours give the overhang something to
            // be measured in.
            VStack(spacing: 0) {
                ForEach(0..<3, id: \.self) { row in
                    Rectangle()
                        .fill(Palette.tileFace(
                            .healthy,
                            on: .terra,
                            shade: row == 1 ? .light : .dark
                        ))
                        .frame(width: CGFloat(tile), height: CGFloat(tile))
                }
            }
            .offset(y: CGFloat(tile) / 2)

            LibraPieceView(
                facing: facing,
                tileSize: CGFloat(tile),
                scale: 1
            )
            .environment(\.ambientClock, sway ? { $0 } : { _ in 0 })
        }
        .frame(width: CGFloat(tile) * 3, height: CGFloat(tile) * 4)
        .scaleEffect(zoom)
        .frame(
            width: CGFloat(tile) * 3 * zoom,
            height: CGFloat(tile) * 4 * zoom
        )
        // Reserves its own room rather than borrowing the controls'.
        //
        // `scaleEffect` does not change a view's layout size — the figure grows
        // visually and the box it sits in does not, so at any real zoom it drew
        // straight over whatever came next. A `maxHeight` made that worse by
        // letting the box shrink. The frame has to be the *scaled* size, so the
        // stack below it starts where the drawing actually ends.
    }

    private func slider(
        _ name: String,
        _ value: Binding<CGFloat>,
        _ range: ClosedRange<CGFloat>,
        unit: String = "px"
    ) -> some View {
        HStack {
            Text(name)
                .font(.caption)
                .frame(width: 130, alignment: .leading)

            Slider(value: value, in: range, step: 1)

            Text("\(Int(value.wrappedValue))\(unit)")
                .font(.caption.monospacedDigit())
                .frame(width: 40, alignment: .trailing)
        }
        .foregroundStyle(Palette.textPrimary)
    }
}

#Preview("Libra — assembly bench") {
    LibraBench()
}
#endif
