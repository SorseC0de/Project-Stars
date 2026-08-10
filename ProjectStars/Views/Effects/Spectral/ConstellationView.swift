//
//  ConstellationView.swift
//  Project Stars
//
//  Drawing a sign in the air, one star at a time.
//

import SwiftUI

/// A sign's constellation, drawing itself above the piece.
///
/// ## How it plays
///
/// Three overlapping stages, all pure functions of elapsed time:
///
/// 1. **Tracing.** Stars light in the order the lines join them, and each line
///    grows from the star it starts at to the star it ends at. The figure writes
///    itself rather than appearing — which is the difference between a summoned
///    thing and a stamp.
/// 2. **Holding.** It turns, complete, with the stars twinkling.
/// 3. **Fading.** The whole thing goes out together.
///
/// ## Why a Canvas
///
/// Twelve figures of eight-odd stars and as many lines, additive, on palette
/// colours, over a moving board. A `Canvas` draws them as primitives with no
/// view identity to diff — the same reasoning the clouds use, and the same
/// reasoning the meshes this replaced used.
struct ConstellationView: View {

    let zodiac: Zodiac

    /// Size of a board cell, in points.
    let tileSize: CGFloat

    /// When the summon began.
    let start: Date

    var body: some View {
        TimelineView(.animation) { timeline in
            let elapsed = timeline.date.timeIntervalSince(start)
            let life = min(max(elapsed / GameRules.constellationDuration, 0), 1)

            Canvas { context, size in
                draw(&context, in: size, elapsed: elapsed, life: life)
            }
            .frame(
                width: tileSize * GameRules.constellationSpan,
                height: tileSize * GameRules.constellationSpan
            )
            .opacity(fade(at: life))
            .blendMode(.plusLighter)
        }
        .allowsHitTesting(false)
    }

    // MARK: - Drawing

    private func draw(
        _ context: inout GraphicsContext,
        in canvas: CGSize,
        elapsed: TimeInterval,
        life: Double
    ) {
        let figure = Constellation.figure(for: zodiac)
        guard !figure.stars.isEmpty else { return }

        // Turns throughout, so the depth reads from parallax rather than from
        // anything having to be shaded.
        let yaw = Float(elapsed) * GameRules.constellationSpin
        let placed = figure.projected(
            yaw: yaw,
            pitch: GameRules.constellationPitch,
            scale: tileSize * GameRules.constellationScale
        )

        let middle = CGPoint(x: canvas.width / 2, y: canvas.height / 2)
        let ramp = ElementFX.ramp(for: zodiac.element)
        let traced = trace(elapsed: elapsed, lines: figure.lines.count)

        // Lines first, so a star always sits on top of the threads reaching it.
        for (index, line) in figure.lines.enumerated() {
            let reach = min(max(traced - Double(index), 0), 1)
            guard reach > 0 else { continue }

            let from = placed[line.0], to = placed[line.1]
            let head = CGPoint(
                x: from.point.x + (to.point.x - from.point.x) * reach,
                y: from.point.y + (to.point.y - from.point.y) * reach
            )

            var path = Path()
            path.move(to: CGPoint(x: middle.x + from.point.x, y: middle.y + from.point.y))
            path.addLine(to: CGPoint(x: middle.x + head.x, y: middle.y + head.y))

            context.stroke(
                path,
                with: .color(ramp.mid.opacity(GameRules.constellationLineOpacity)),
                style: StrokeStyle(
                    lineWidth: GameRules.constellationLineWidth * scale,
                    lineCap: .round
                )
            )
        }

        for (index, star) in placed.enumerated() {
            // A star lights when the first line that touches it reaches it, and
            // the first star lights immediately so there is something to draw
            // from.
            guard let at = lights(star: index, lines: figure.lines) else { continue }
            let born = traced - Double(at)
            guard born > 0 else { continue }

            // Pops slightly oversized, then settles.
            let pop = born < 1 ? 1 + (1 - born) * GameRules.constellationPop : 1
            let twinkle = 0.75 + 0.25 * sin(elapsed * 3.1 + Double(index) * 1.7)

            let radius = GameRules.constellationStarSize
                * scale * CGFloat(star.magnitude) * star.scale * CGFloat(pop)

            let centre = CGPoint(x: middle.x + star.point.x, y: middle.y + star.point.y)

            // A soft body under a hard core: the same white-hot-centre rule the
            // glow-phase sparkles follow, for the same reason.
            context.fill(
                Path(ellipseIn: CGRect(
                    x: centre.x - radius * 2.2, y: centre.y - radius * 2.2,
                    width: radius * 4.4, height: radius * 4.4
                )),
                with: .color(ramp.bright.opacity(GameRules.constellationHaloOpacity * twinkle))
            )
            context.fill(
                Path(ellipseIn: CGRect(
                    x: centre.x - radius, y: centre.y - radius,
                    width: radius * 2, height: radius * 2
                )),
                with: .color(Palette.white.opacity(twinkle))
            )
        }
    }

    // MARK: - Timing

    private var scale: CGFloat { tileSize / CGFloat(GameRules.tilePixelSize) }

    /// How many lines have been drawn, fractionally.
    private func trace(elapsed: TimeInterval, lines: Int) -> Double {
        max(elapsed, 0) / GameRules.constellationTracePerLine
    }

    /// The line index at which a star first lights.
    ///
    /// The star a line starts from lights with that line; the star it ends at
    /// lights when the line arrives. A star nothing touches never lights, which
    /// is a data error rather than something to paper over.
    private func lights(star: Int, lines: [(Int, Int)]) -> Int? {
        for (index, line) in lines.enumerated() {
            if line.0 == star { return index }
            if line.1 == star { return index + 1 }
        }
        return nil
    }

    /// Full brightness while it holds, then out.
    private func fade(at life: Double) -> Double {
        let start = GameRules.constellationFadeStart
        guard life > start else { return 1 }
        return max(1 - (life - start) / (1 - start), 0)
    }
}
