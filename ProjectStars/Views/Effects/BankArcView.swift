//
//  BankArcView.swift
//  Project Stars
//
//  The money going into the purse.
//

import SwiftUI

/// Motes of earth-light arcing from an opened Pentacle down into the purse.
///
/// ## What it is for
///
/// A banked coin does nothing. No burst, no repair, no charge — the tile it was
/// on looks exactly as it did a moment ago, which without this reads as a
/// Pentacle that failed to go off. The arc is the answer: the coin did something,
/// and this is where it went.
///
/// ## How it moves
///
/// A quadratic bow between the tile and the strip, one control point lifted
/// perpendicular to the line by `GameRules.bankArcHeight`. Each mote is given the
/// same curve and a different head start, so they string out along it rather
/// than travelling as a clump — a line of light between two places says
/// *transfer* in a way a single travelling dot does not.
///
/// Pure function of elapsed time from `start`, like every other effect here, so
/// it cannot be stranded mid-flight.
struct BankArcView: View {

    /// Where the coin was, in board-local points.
    let from: CGPoint

    /// Where the purse is, in the same space.
    let to: CGPoint

    /// When the transfer began.
    let start: Date

    /// Size of a board cell, for scaling the motes.
    let tileSize: CGFloat

    var body: some View {
        TimelineView(.animation) { timeline in
            let elapsed = timeline.date.timeIntervalSince(start)
            let life = GameRules.pickupBankDuration

            Canvas { context, _ in
                for index in 0..<GameRules.bankSparkCount {
                    // Spread the departures across the first half of the flight,
                    // so the last mote leaves as the first arrives and the line
                    // is briefly whole.
                    let lead = Double(index) / Double(GameRules.bankSparkCount) * 0.5
                    let progress = (elapsed / life - lead) / (1 - lead)
                    guard progress > 0, progress < 1 else { continue }

                    let point = position(at: progress)
                    // Fades out at the end rather than winking off, and swells
                    // slightly at the middle of the arc where it is "highest".
                    let fade = 1 - progress * progress
                    let swell = 1 + sin(progress * .pi) * 0.5
                    let radius = tileSize * GameRules.bankSparkSize * swell

                    let box = CGRect(
                        x: point.x - radius, y: point.y - radius,
                        width: radius * 2, height: radius * 2
                    )
                    context.opacity = fade
                    context.fill(Path(ellipseIn: box), with: .color(Palette.green))
                }
            }
            // Additive, so the motes read as light crossing the board rather
            // than as green paint over it.
            .blendMode(.plusLighter)
            .opacity(elapsed >= 0 && elapsed <= life ? 1 : 0)
        }
        .allowsHitTesting(false)
    }

    /// A point along the bow, `0` at the coin and `1` at the purse.
    private func position(at t: Double) -> CGPoint {
        let mid = CGPoint(x: (from.x + to.x) / 2, y: (from.y + to.y) / 2)
        let run = CGSize(width: to.x - from.x, height: to.y - from.y)
        let distance = sqrt(run.width * run.width + run.height * run.height)

        // Perpendicular to the line, so the bow leans the same way whichever
        // corner of the board the coin was in.
        let lift = distance * GameRules.bankArcHeight
        let normal = distance > 0
            ? CGSize(width: -run.height / distance, height: run.width / distance)
            : .zero
        let control = CGPoint(
            x: mid.x + normal.width * lift,
            y: mid.y + normal.height * lift
        )

        let u = 1 - t
        return CGPoint(
            x: u * u * from.x + 2 * u * t * control.x + t * t * to.x,
            y: u * u * from.y + 2 * u * t * control.y + t * t * to.y
        )
    }
}
