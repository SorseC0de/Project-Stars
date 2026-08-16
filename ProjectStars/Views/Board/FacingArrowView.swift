//
//  FacingArrowView.swift
//  Project Stars
//
//  The little marker showing which way the piece is looking.
//

import SwiftUI

/// A small arrow on the ground just ahead of the piece, pointing its facing.
///
/// ## Why it has to exist
///
/// Facing is load-bearing in a way almost nothing about the art shows. Libra
/// trenches the squares either side of it, Sagittarius strides along it,
/// Capricorn floats on holes only while looking north, the tap control steps
/// that way, and a sidestep is *defined* as moving perpendicular to it. The
/// sprites themselves face front at all times — they are two tiles tall and read
/// as portraits — so without a marker the player is asked to track a hidden
/// variable that half the rules depend on.
///
/// The sprite has been in the atlas since the first build and simply was not
/// being drawn by anything.
///
/// ## It follows the facing, never the aim
///
/// `piece.facing` and nothing else. Hold the stick north while facing west and
/// the cursor goes north while this stays west, until the move is committed —
/// because that is the truth: the facing has not changed yet, and every rule
/// keyed to it is still reading west. An arrow that previewed the aim would be a
/// second cursor, and the one thing it must never do is agree with the cursor
/// about something that has not happened.
///
/// ## Why it is on the ground rather than on the piece
///
/// Because it points at *the square it would move to*. Put it on the figure and
/// it reads as decoration on a character; put it on the ground ahead and it
/// reads as an intention. It sits a little short of the next square's centre so
/// it cannot be mistaken for something standing on that square.
struct FacingArrowView: View {

    let facing: SwipeDirection

    /// Size of a board cell, in points.
    let tileSize: CGFloat

    /// Whole-pixel scale, for art-pixel offsets.
    let scale: CGFloat

    var body: some View {
        TimelineView(.animation) { timeline in
            let out = nudge(at: clock(timeline.date.timeIntervalSinceReferenceDate))

            PixelSprite(id: .directionArrow(facing)) {
                placeholder
            }
            .frame(width: tileSize, height: tileSize)
            .scaleEffect(GameRules.facingArrowScale)
            .offset(
                x: CGFloat(facing.unitOffset.dx)
                    * (tileSize * GameRules.facingArrowReach + out),
                y: CGFloat(facing.unitOffset.dy)
                    * (tileSize * GameRules.facingArrowReach + out)
                    - GameRules.facingArrowLift * scale
            )
            // Follows the turn rather than snapping, so a change of facing is
            // something you see happen — several rules key off it and a silent
            // swap is the sort of thing a player only notices by losing to it.
            .animation(.easeOut(duration: GameRules.facingArrowTurn), value: facing)
        }
        .allowsHitTesting(false)
    }

    /// How far out along its own axis the arrow currently sits.
    ///
    /// ## Two positions, not a wobble
    ///
    /// It snaps between them and holds — this is a two-frame sprite animation
    /// that happens to be written as maths, and easing between the stops would
    /// make it a floating icon rather than a drawn one. Everything else on this
    /// board moves in whole pixels on a held beat and so does this.
    ///
    /// ## Why north is the odd one
    ///
    /// The four arrows were authored so that up already sits at its *far*
    /// position and the other three sit at their near one. Rather than nudge the
    /// art, north swings inward — `[-8, 0]` where the others run `[0, +8]`. The
    /// pair is the same eight pixels along the same axis in every case; only
    /// which end is home differs.
    private func nudge(at now: TimeInterval) -> CGFloat {
        let beat = Int(now / GameRules.facingArrowBeat) % 2 == 0
        let step = GameRules.facingArrowNudge * scale

        if facing == .up {
            return beat ? -step : 0
        }
        return beat ? 0 : step
    }

    /// The ambient clock, so it holds still with everything else while the game
    /// waits on the player.
    var clock: (TimeInterval) -> TimeInterval = { $0 }

    /// Drawn only while the sprite is missing: a plain triangle, rotated.
    private var placeholder: some View {
        Triangle()
            .fill(Palette.white)
            .frame(width: tileSize * 0.3, height: tileSize * 0.22)
            .rotationEffect(.degrees(facing.iconRotation))
    }
}

/// A simple upward triangle, for the placeholder.
private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
