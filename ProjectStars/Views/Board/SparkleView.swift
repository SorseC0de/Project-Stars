//
//  SparkleView.swift
//  Project Stars
//
//  The shimmer marking a tile the pickup might appear on.
//

import SwiftUI

/// A pulsing marker drawn on each of the five candidate pickup tiles.
///
/// Deliberately **drawn rather than imported**, and deliberately not in
/// `SpriteAtlas`. The tutorial splash graphics generate boards from scratch, and
/// a sparkle that is code can be composed into those at any size; a sparkle that
/// is a sheet cell cannot.
struct SparkleView: View {

    /// Rendered edge length in points — one tile.
    let size: CGFloat

    /// Which plane it is shimmering on, which decides its colour.
    var plane: Plane = .terra

    /// Staggers the pulse so the five sparkles do not blink in unison.
    /// Which sparkle in the set this is.
    ///
    /// Drives both its rate and its phase. Staggering phase alone was not
    /// enough — five sparkles sharing a period read as one blinking object no
    /// matter how they are offset, because the eye locks onto the shared rhythm.
    var index: Int = 0

    /// Overrides the plane's colour.
    ///
    /// Virgo's ring is drawn pink so it cannot be mistaken for the ordinary
    /// hunt: the two look the same, sit on the same board and are opened the
    /// same way, but only one of them may be standing over a hole.
    var tint: Color?

    var body: some View {
        ZStack {
            tileGlow
            placeholder
        }
        .frame(width: size, height: size)
        // Evaluated from the clock rather than driven by a repeating animation,
        // so each sparkle can run at its own rate without needing its own
        // animation state.
        .modifier(SparklePulse(index: index))
        .allowsHitTesting(false)
    }

    /// Light thrown onto the square underneath, so the tile is marked and not
    /// just overlaid.
    ///
    /// Counter-offset by `sparkleNudge`: the sparkle itself sits a couple of
    /// pixels east to clear the art beneath it, but a glow *on* the square
    /// belongs centred on the square.
    private var tileGlow: some View {
        Circle()
            .fill(tint ?? Palette.sparkleGlow(on: plane))
            .frame(
                width: size * GameRules.sparkleTileGlowSize,
                height: size * GameRules.sparkleTileGlowSize
            )
            .blur(radius: size * GameRules.sparkleTileGlowBlur)
            .opacity(GameRules.sparkleTileGlowOpacity * bloom)
            .blendMode(.plusLighter)
            .offset(
                x: -GameRules.sparkleNudge.width,
                y: -GameRules.sparkleNudge.height
            )
    }

    // TODO: Once the real sparkle art lands it will likely be a multi-frame
    // animation. Add a `SpriteAnimation` view that cycles `fx_sparkle_0…n` and
    // swap it in here — nothing outside this file needs to change.

    // MARK: - Placeholder art

    /// How much bloom this plane can take before the glyph is lost in it.
    private var bloom: Double {
        plane == .terra ? GameRules.sparkleGlowTerraDamping : 1
    }

    private var placeholder: some View {
        let glow = tint ?? Palette.sparkleGlow(on: plane)
        let side = size * 0.45

        return ZStack {
            // The colour lives out here, where the light is thin enough to keep
            // it. Stacked additively it still brightens toward the middle, which
            // is what puts the white core underneath.
            ZStack {
                ForEach(0..<GameRules.sparkleGlowLayers, id: \.self) { step in
                    SparkleGlyph()
                        .fill(glow)
                        .frame(width: side, height: side)
                        .blur(
                            radius: size * GameRules.sparkleGlowRadius
                                * (1 + CGFloat(step) * 0.9)
                        )
                        .opacity(GameRules.sparkleGlowIntensity * bloom / Double(step + 1))
                }
            }
            .blendMode(.plusLighter)

            SparkleGlyph()
                .fill(Palette.sparkleCore)
                .frame(width: side * GameRules.sparkleCoreScale, height: side * GameRules.sparkleCoreScale)
        }
    }
}

// MARK: - FourPointStar

/// A classic pixel-art twinkle: four points with concave sides.
///
/// Shared with `CollectBurstView` — the same mark, whether it is sitting on a
/// candidate tile or flying off an opened coin.
struct SparkleGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        let centerX = rect.midX
        let centerY = rect.midY
        let halfWidth = rect.width / 2
        let halfHeight = rect.height / 2
        let waist = min(halfWidth, halfHeight) * 0.28

        var path = Path()
        path.move(to: CGPoint(x: centerX, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: centerY),
            control: CGPoint(x: centerX + waist, y: centerY - waist)
        )
        path.addQuadCurve(
            to: CGPoint(x: centerX, y: rect.maxY),
            control: CGPoint(x: centerX + waist, y: centerY + waist)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: centerY),
            control: CGPoint(x: centerX - waist, y: centerY + waist)
        )
        path.addQuadCurve(
            to: CGPoint(x: centerX, y: rect.minY),
            control: CGPoint(x: centerX - waist, y: centerY - waist)
        )
        path.closeSubpath()
        return path
    }
}

// MARK: - Preview

#Preview("Sparkle") {
    SparkleView(size: 64)
        .padding(40)
        .background(Palette.background)
}


// MARK: - SparklePulse

/// Breathes a sparkle in and out on a rate of its own.
private struct SparklePulse: ViewModifier {

    let index: Int

    func body(content: Content) -> some View {
        TimelineView(.animation) { timeline in
            let pulse = pulse(at: timeline.date)
            content
                .scaleEffect(0.72 + 0.28 * pulse)
                .opacity((0.55 + 0.45 * pulse) * GameRules.sparkleOpacity)
        }
    }

    /// `0`…`1`, on this sparkle's own period and offset.
    private func pulse(at date: Date) -> CGFloat {
        // A cheap hash of the index, so neighbouring sparkles do not land on
        // neighbouring rates.
        let spread = Double((index &* 2654435761 &+ 12345) % 1000) / 1000
        let period = GameRules.sparklePulseFastest
            + (GameRules.sparklePulseSlowest - GameRules.sparklePulseFastest) * spread
        let offset = spread * 2 * .pi

        let turns = date.timeIntervalSinceReferenceDate / period * 2 * .pi + offset
        return CGFloat(sin(turns) + 1) / 2
    }
}
