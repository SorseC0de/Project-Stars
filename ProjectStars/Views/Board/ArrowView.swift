//
//  ArrowView.swift
//  Project Stars
//
//  The shaft Sagittarius leaves standing in a square.
//

import SwiftUI

/// An Astral Arrow, stuck in the ground and waiting to be recalled.
///
/// ## Why it is drawn rather than sprited
///
/// It is a line of light, and a line of light is cheaper to draw than to store —
/// four palette colours, a shaft, a head and fletching, none of which needs
/// pixel art to read at this size. It also lets the glow pulse continuously
/// without a frame count, which matters for something that may stand in the
/// board for fifty moves.
///
/// ## Why it leans
///
/// Straight up reads as a post. Everything else the game draws in the air —
/// the constellations, Polaris — turns or drifts, and a shaft at a slight angle
/// says *thrown* rather than *installed*.
struct ArrowView: View {

    /// Rendered edge length of one cell, in points.
    let tileSize: CGFloat

    /// Whole-pixel scale, for art-pixel measurements.
    let scale: CGFloat

    var body: some View {
        TimelineView(.animation) { timeline in
            let now = timeline.date.timeIntervalSinceReferenceDate
            let pulse = (sin(now / GameRules.arrowPulsePeriod * 2 * .pi) + 1) / 2

            ZStack {
                shaft
                    .blur(radius: GameRules.arrowGlowRadius * scale)
                    .opacity(0.5 + 0.5 * pulse)
                    .blendMode(.plusLighter)

                shaft
            }
            .rotationEffect(.degrees(GameRules.arrowLean))
            // Its point is in the ground, so it stands *above* the square it
            // marks rather than centred on it.
            .offset(y: -GameRules.arrowRise * scale)
        }
        .allowsHitTesting(false)
    }

    /// Shaft, head and fletching, in the neutral ramp — the arrow belongs to no
    /// element, like everything else Astral.
    private var shaft: some View {
        let ramp = ElementFX.neutral

        return ZStack {
            Capsule()
                .fill(ramp.mid)
                .frame(width: GameRules.arrowThickness * scale,
                       height: GameRules.arrowLength * scale)

            // The head, pointing down into the square.
            Triangle()
                .fill(ramp.bright)
                .frame(width: GameRules.arrowHead * scale,
                       height: GameRules.arrowHead * scale)
                .offset(y: GameRules.arrowLength * scale / 2)

            // Fletching, up at the nock.
            ForEach([-1.0, 1.0], id: \.self) { side in
                Capsule()
                    .fill(ramp.deep)
                    .frame(width: GameRules.arrowThickness * scale,
                           height: GameRules.arrowHead * scale * 1.4)
                    .rotationEffect(.degrees(35 * side))
                    .offset(x: GameRules.arrowThickness * scale * 1.2 * side,
                            y: -GameRules.arrowLength * scale / 2.6)
            }
        }
    }
}

/// A downward-pointing triangle, for the arrowhead.
private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}
