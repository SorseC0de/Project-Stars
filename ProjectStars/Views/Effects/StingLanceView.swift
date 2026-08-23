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
                let step = direction.unitOffset

                // **A chain, not a shaft.**
                //
                // The links are drawn apart from each other and read as one
                // tail anyway — the Chain Chomp trick. Each sits at its own
                // share of the current length, so the whole thing grows out of
                // the piece rather than stretching.
                PaletteGlow(
                    radius: GameRules.stingGlow * (tileSize / CGFloat(GameRules.tilePixelSize)),
                    intensity: GameRules.stingGlowStrength
                ) {
                ZStack {
                    ForEach(0..<linkCount(for: length), id: \.self) { link in
                        let along = CGFloat(link + 1) / CGFloat(linkCount(for: length) + 1)
                        let wander = wiggle(link, at: elapsed)

                        PixelSprite(id: .scorpioTailLink) { Color.clear }
                            .frame(width: tileSize, height: tileSize)
                            .offset(
                                x: CGFloat(step.dx) * length * along + wander.width,
                                y: CGFloat(step.dy) * length * along + wander.height
                            )
                    }

                    PixelSprite(id: .scorpioStinger(direction)) { Color.clear }
                        .frame(width: tileSize, height: tileSize)
                        // East is west mirrored — three drawings, four ways.
                        .scaleEffect(x: direction == .right ? -1 : 1, y: 1)
                        .offset(x: CGFloat(step.dx) * length, y: CGFloat(step.dy) * length)
                }
                .frame(width: span, height: span)
                }
                // Added to the board rather than filtered through it. Soft
                // light was the wrong read entirely: over ground this dark it
                // took the tail down to almost nothing.
                .opacity(GameRules.stingOpacity)
                .blendMode(.plusLighter)
            }
        }
        .allowsHitTesting(false)
    }

    /// How many links fill the current length.
    ///
    /// From the length rather than from `reach`, so the chain gains segments as
    /// it extends instead of squeezing a fixed count into a growing gap.
    private func linkCount(for length: CGFloat) -> Int {
        max(Int((length / (tileSize * GameRules.stingLinkSpacing)).rounded()) - 1, 0)
    }

    /// How far this link has wandered off the line, in points.
    ///
    /// Deterministic in the link and the clock: the tail should look loose and
    /// alive, not different every frame for no reason.
    private func wiggle(_ link: Int, at elapsed: TimeInterval) -> CGSize {
        let amount = GameRules.stingLinkWiggle * (tileSize / CGFloat(GameRules.tilePixelSize))
        let tick = elapsed / GameRules.stingWigglePeriod
        return CGSize(
            width: GameRules.jitter(tick + Double(link), salt: 11) * amount,
            height: GameRules.jitter(tick + Double(link), salt: 23) * amount
        )
    }

    /// How much of the reach is currently drawn, `0`…`1`.
    ///
    /// Out fast and back slower — a strike is the lunge, and the withdrawal is
    /// only tidying up after it.
    private func reachFraction(at elapsed: TimeInterval) -> CGFloat {
        let life = GameRules.stingDuration
        guard elapsed >= 0, elapsed <= life else { return 0 }

        let progress = elapsed / life
        let out = GameRules.stingAttack
        return progress < out
            ? CGFloat(progress / out)
            : CGFloat(1 - (progress - out) / (1 - out))
    }

}
