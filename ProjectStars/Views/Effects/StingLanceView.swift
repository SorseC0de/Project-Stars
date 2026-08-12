//
//  StingLanceView.swift
//  Project Stars
//
//  Scorpio's tail, reaching.
//

import SwiftUI

/// The lance Scorpio's Snatching Sting throws down its facing.
///
/// A translucent water-blue shaft with a triangular head, extending from the
/// piece to the far end of the strike and drawing back in. Deliberately a
/// **placeholder**: it is a shape, not a sprite, and the real tail will replace
/// it. It exists because a super that reached across the board and showed
/// nothing was indistinguishable from a super that had not fired.
///
/// ## Why it extends rather than appears
///
/// The whole point of this ability is *reach*, and reach is a thing that
/// happens over distance. A shape that simply switched on down the whole line
/// would say "this row is affected"; one that shoots out and snaps back says
/// "something went and got that", which is the rule.
struct StingLanceView: View {

    /// Which way the tail is pointing.
    let direction: SwipeDirection

    /// How far it reaches, in squares.
    let reach: Int

    /// Size of a board cell, in points.
    let tileSize: CGFloat

    /// When the strike began.
    let start: Date

    var body: some View {
        TimelineView(.animation) { timeline in
            let elapsed = timeline.date.timeIntervalSince(start)
            let extended = reachFraction(at: elapsed)

            if extended > 0 {
                let length = tileSize * CGFloat(reach) * extended
                let span = tileSize * CGFloat(reach) * 2

                // Drawn inside a square box centred on the piece, so the
                // rotation turns the lance *about its base* rather than about
                // the middle of its own shaft. Offsetting first and rotating
                // afterwards swings the whole thing around the board instead.
                ZStack {
                    Lance(headLength: tileSize * 0.7)
                        .fill(Palette.lightBlue)
                        .frame(width: tileSize * 0.52, height: length)
                        // Grows out of the piece's end, so the shaft reads as
                        // being pushed rather than as stretching.
                        .offset(y: -length / 2)
                }
                .frame(width: span, height: span)
                .rotationEffect(.degrees(turn))
                .opacity(GameRules.stingOpacity)
                .blendMode(.plusLighter)
            }
        }
        .allowsHitTesting(false)
    }

    /// How much of the reach is currently drawn, `0`…`1`.
    ///
    /// Out fast and back slower — a strike is the lunge, and the withdrawal is
    /// only tidying up after it.
    private func reachFraction(at elapsed: TimeInterval) -> CGFloat {
        let life = GameRules.stingDuration
        guard elapsed >= 0, elapsed <= life else { return 0 }

        let progress = elapsed / life
        let out = 0.35
        return progress < out
            ? CGFloat(progress / out)
            : CGFloat(1 - (progress - out) / (1 - out))
    }

    /// Rotation from the drawn orientation, which points north.
    private var turn: Double {
        switch direction {
        case .up: 0
        case .right: 90
        case .down: 180
        case .left: 270
        }
    }

    /// A shaft with a triangular head, drawn pointing up.
    private struct Lance: Shape {

        /// How much of the total length the head takes.
        let headLength: CGFloat

        func path(in rect: CGRect) -> Path {
            var path = Path()
            let head = min(headLength, rect.height)
            let shaftTop = rect.minY + head
            let inset = rect.width * 0.22

            // Shaft.
            path.addRect(CGRect(
                x: rect.minX + inset, y: shaftTop,
                width: rect.width - inset * 2, height: rect.height - head
            ))

            // Head, spanning the full width so it reads as a point rather than
            // as a slightly wider end to the shaft.
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: shaftTop))
            path.addLine(to: CGPoint(x: rect.minX, y: shaftTop))
            path.closeSubpath()

            return path
        }
    }
}
