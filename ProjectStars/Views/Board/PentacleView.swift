//
//  PentacleView.swift
//  Project Stars
//
//  The gold coin a pickup appears as on the board.
//

import SwiftUI

/// A **Pentacle**: the gold coin that every pickup appears as.
///
/// Identical for every common, uncommon and rare effect. The coin is a loot box:
/// the player learns what is inside by opening it, never by looking at it, which
/// is what makes committing to a move to reach one a real decision. The two
/// legendaries break that on purpose and carry their own `PentacleAppearance`.
///
/// ## Why it is three tiles wide
///
/// The coin itself is one cell, but its sparkle spills a full cell in every
/// direction, so the art is 48x48 with the coin in the middle. Drawing it at one
/// tile would crop the sparkle off; drawing it at three and centring on the tile
/// puts the coin exactly where it belongs and lets the sparkle overhang.
///
/// Contrast `PentacleIntroView`, which *does* show the effect's own glyph,
/// because by then the coin is open.
struct PentacleView: View {

    /// How this coin looks.
    var appearance: PentacleAppearance = .standard

    /// Size of a board cell, in points. The view draws itself larger than this.
    let size: CGFloat

    /// Whole-pixel scale, for art-pixel offsets.
    var scale: CGFloat = 1

    var body: some View {
        TimelineView(.animation) { timeline in
            // One phase drives everything, so the coin, its orbit and its pool
            // of light can never drift out of step with each other.
            let phase = timeline.date.timeIntervalSinceReferenceDate
            let rise = riseFraction(at: phase)
            let orbit = orbitOffset(at: phase)

            ZStack {
                // The shadow stays put on the tile while the coin drifts above
                // it — that separation is what sells the hover.
                // Not a shadow so much as a pool of light: the coin glows, so
                // what lands on the tile beneath it is additive white rather
                // than an occluding dark ellipse.
                PieceShadowView(
                    tileSize: size,
                    widthFraction: 0.34,
                    opacity: GameRules.pentacleShadowOpacity,
                    color: Palette.white,
                    blendMode: .plusLighter
                )
                // Shrinks as the coin rises and swells as it dips — a pool of
                // light narrows the further its source gets from the ground, and
                // that change in size reads as height far more strongly than the
                // coin's own drift does.
                .scaleEffect(1 - GameRules.pentacleShadowScaleSwing * rise)
                .offset(
                    x: orbit.width,
                    y: orbit.height + GameRules.pentacleShadowDrop * scale
                )

                PixelSprite(id: .pentacle(appearance)) {
                    placeholder
                }
                .frame(
                    width: size * GameRules.pentacleCellSpan,
                    height: size * GameRules.pentacleCellSpan
                )
                // Floats clear of its own glow, then drifts — the gap between
                // coin and pool is what sells the hover.
                .offset(
                    x: orbit.width,
                    y: float(at: timeline.date) - GameRules.pentacleLift * scale
                )
            }
        }
        .transition(.scale(scale: 0.2).combined(with: .opacity))
        .allowsHitTesting(false)
    }

    /// Where the coin is in its bob, `0` at the bottom and `1` at the top.
    ///
    /// The shadow reads this rather than the raw offset so its response stays
    /// correct if the float is ever re-shaped.
    private func riseFraction(at phase: TimeInterval) -> CGFloat {
        let turns = phase / GameRules.pentacleFloatPeriod
        return CGFloat(sin(turns * 2 * .pi) + 1) / 2
    }

    /// The coin's position around its orbit of the tile centre.
    ///
    /// Flattened vertically: a circle drawn in perspective on the ground is an
    /// ellipse, and a coin circling level would otherwise look like it was
    /// bobbing twice.
    private func orbitOffset(at phase: TimeInterval) -> CGSize {
        let turns = phase / GameRules.pentacleOrbitPeriod * 2 * .pi
        let radius = GameRules.pentacleOrbitRadius * scale
        return CGSize(
            width: CGFloat(cos(turns)) * radius,
            height: CGFloat(sin(turns)) * radius * 0.4
        )
    }

    private func float(at date: Date) -> CGFloat {
        let phase = date.timeIntervalSinceReferenceDate / GameRules.pentacleFloatPeriod
        return CGFloat(sin(phase * 2 * .pi)) * GameRules.pentacleFloatAmplitude * scale
    }

    // MARK: - Placeholder art

    /// Drawn only while the sprite is missing. Sized to the middle cell, since
    /// the placeholder has no sparkle to spill.
    private var placeholder: some View {
        ZStack {
            Circle().fill(faceColor)
            Circle().strokeBorder(edgeColor, lineWidth: max(1, size * 0.06))
            Image(systemName: "star.fill")
                .font(.system(size: size * 0.4))
                .foregroundStyle(edgeColor)
        }
        .frame(width: size, height: size)
    }

    private var faceColor: Color {
        switch appearance {
        case .standard: Palette.pentacle
        case .shadow: Palette.pentacleShadow
        case .radiant: Palette.pentacleRadiant
        }
    }

    private var edgeColor: Color {
        switch appearance {
        case .standard: Palette.pentacleEdge
        case .shadow: Palette.pentacleShadowEdge
        case .radiant: Palette.lightBlue
        }
    }
}
