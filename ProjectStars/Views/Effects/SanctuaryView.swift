//
//  SanctuaryView.swift
//  Project Stars
//
//  The ground Cancer's Astral Bastion is holding.
//

import SwiftUI

/// Marks the squares a sanctuary is protecting, and how long it has left.
///
/// ## Why it reads as a floor and not as a wall
///
/// The Bastion protects *ground*. Drawn as a dome or a bubble it would suggest
/// the piece inside is safe, which is not what it does — a piece can still fall
/// through a hole that was already there, and can still walk out of it. A lit
/// floor with a hard edge says exactly what is true: these squares, not this
/// space.
///
/// ## Why the last move looks different
///
/// A three-move buff that vanishes without warning is a buff the player cannot
/// plan around, and planning around it is the entire ability. On its final move
/// the pulse roughly doubles in rate — read at a glance, without a number to
/// parse.
struct SanctuaryView: View {

    let sanctuary: SignState.Sanctuary
    let metrics: PixelArtMetrics

    var body: some View {
        TimelineView(.animation) { timeline in
            let beat = pulse(at: timeline.date.timeIntervalSinceReferenceDate)

            ZStack {
                ForEach(points, id: \.self) { point in
                    Rectangle()
                        .fill(water.deep)
                        .frame(width: metrics.tileSize, height: metrics.tileSize)
                        .position(metrics.center(of: point))
                }
                .opacity(GameRules.sanctuaryFieldOpacity * (0.75 + 0.25 * beat))

                border(beat: beat)

                bubbles(at: timeline.date.timeIntervalSinceReferenceDate)
            }
            .blendMode(.plusLighter)
        }
        .frame(width: metrics.boardSize, height: metrics.boardSize)
        .allowsHitTesting(false)
    }

    /// The drawn water, one bubble per sheltered square, looping for as long as
    /// the Bastion stands.
    ///
    /// The lit floor says *which squares*; this says *what is happening to
    /// them*. Neither alone is enough — a floor tint is easy to miss under the
    /// board's own colour, and bubbles without an edge do not tell you where the
    /// protection stops.
    private func bubbles(at now: TimeInterval) -> some View {
        ZStack {
            ForEach(points, id: \.self) { point in
                ForEach(Array(EffectSprite.cancerBastion.enumerated()), id: \.offset) { layer, effect in
                    // The lower bubble runs slower *and* starts later. Rate
                    // alone still lets them meet at the top of every cycle.
                    // Two lags at once: the lower bubble trails the upper one,
                    // and every square trails every other. Nine bubbles in
                    // lockstep read as one animation stamped nine times.
                    let lag = Double(EffectSprite.cancerBastion.count - 1 - layer)
                        * GameRules.sanctuaryLayerStagger
                        + Self.offset(of: point) * effect.duration
                    let frame = Int(max(now - lag, 0) / effect.rate.frameDuration) % effect.frames
                    let side = metrics.tileSize * GameRules.sanctuaryTileSpan

                    PixelSprite(id: .effect(effect), frame: frame) { EmptyView() }
                        .frame(width: side, height: side)
                        .offset(y: -effect.groundLift * metrics.scale)
                        .position(metrics.center(of: point))
                }
            }
        }
    }

    /// How far into its own cycle a square's bubble sits, `0`…`1`.
    ///
    /// Hashed from the square so it is stable: a bubble that reshuffled its
    /// phase between frames would flicker rather than loop.
    private static func offset(of point: GridPoint) -> Double {
        var z = UInt64(bitPattern: Int64(point.x &* 73_856_093 &+ point.y &* 19_349_663))
        z = (z ^ (z >> 33)) &* 0xFF51_AFD7_ED55_8CCD
        z = (z ^ (z >> 33)) &* 0xC4CE_B9FE_1A85_EC53
        z ^= z >> 33
        return Double(z % 1_000) / 1_000
    }

    /// The edge, drawn around the whole patch rather than around each square —
    /// it is one place, not nine.
    private func border(beat: Double) -> some View {
        let bounds = self.bounds
        let width = CGFloat(bounds.maxX - bounds.minX + 1) * metrics.tileSize
        let height = CGFloat(bounds.maxY - bounds.minY + 1) * metrics.tileSize

        let middle = CGPoint(
            x: (CGFloat(bounds.minX + bounds.maxX) / 2 + 0.5) * metrics.tileSize,
            y: (CGFloat(bounds.minY + bounds.maxY) / 2 + 0.5) * metrics.tileSize
        )

        return Rectangle()
            .strokeBorder(
                water.bright,
                lineWidth: GameRules.sanctuaryBorderWidth * metrics.scale
            )
            .frame(width: width, height: height)
            .position(middle)
            .opacity(0.45 + 0.55 * beat)
    }

    // MARK: - Shape of the patch

    /// Every square inside it, clipped to the board.
    ///
    /// Clipped rather than clamped: raising the Bastion in a corner protects the
    /// four squares that exist there, it does not slide the patch inward to keep
    /// all nine.
    private var points: [GridPoint] {
        let bounds = self.bounds
        return (bounds.minY...bounds.maxY).flatMap { y in
            (bounds.minX...bounds.maxX).map { GridPoint($0, y) }
        }
    }

    private var bounds: (minX: Int, maxX: Int, minY: Int, maxY: Int) {
        let last = GameRules.gridSize - 1
        return (
            minX: max(sanctuary.centre.x - sanctuary.radius, 0),
            maxX: min(sanctuary.centre.x + sanctuary.radius, last),
            minY: max(sanctuary.centre.y - sanctuary.radius, 0),
            maxY: min(sanctuary.centre.y + sanctuary.radius, last)
        )
    }

    // MARK: - Clocks

    /// Cancer is water, so the Bastion is drawn from water's own ramp — the same
    /// one its bursts use.
    private var water: ElementFX { .ramp(for: .water) }

    /// `0`…`1`, quickening on the final move.
    private func pulse(at now: TimeInterval) -> Double {
        let period = sanctuary.movesRemaining <= 1
            ? GameRules.sanctuaryFinalPulsePeriod
            : GameRules.sanctuaryPulsePeriod

        return (sin(now / period * 2 * .pi) + 1) / 2
    }
}
