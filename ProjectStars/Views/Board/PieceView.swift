//
//  PieceView.swift
//  Project Stars
//
//  The player's zodiac piece.
//

import SwiftUI

/// Draws the controlled piece.
///
/// A piece sprite is **16x32 — twice a tile's height**. Its box rests with the
/// bottom edge on the bottom of the tile, so the figure rises out of its square
/// rather than sitting inside it, and the art can overlap whatever is behind.
/// `GameRules.pieceLift` nudges that resting point without touching this file.
///
/// - Note: Every sign currently points at the same sprite. That is one line in
///   `SpriteAtlas`, not a limitation here.
struct PieceView: View {

    let zodiac: Zodiac

    /// Size of a board cell, in points.
    let tileSize: CGFloat

    /// Whole-pixel scale, for art-pixel offsets.
    let scale: CGFloat

    /// Which way the piece is looking.
    var facing: SwipeDirection = .up

    /// True while the piece is dropping between planes.
    var isFalling: Bool = false

    /// Extra vertical offset in points — how the piece rides the Nexys' drift
    /// while standing on it.
    var carryOffset: CGFloat = 0

    /// How the piece is deformed and lifted right now. `.rest` when still.
    var pose: HopPose = .rest

    /// Running total of fall rotation, in degrees. Only ever decreases, so the
    /// spin reads as one continuous counter-clockwise turn.
    var spin: Double = 0

    /// Vertical offset applied to the **sprite only**, for falling in from
    /// off-screen. The shadow deliberately does not move with it.
    var dropOffset: CGFloat = 0

    /// Size of the shadow relative to its resting size. Swells from small to
    /// full as a falling piece nears the ground.
    var shadowScale: CGFloat = 1

    var body: some View {
        ZStack {
            // The shadow stays on the tile while the figure rises off it, which
            // is what anchors a two-cell-tall sprite to a one-cell square — and
            // during an arrival it is the *only* thing on the destination
            // square, growing to announce where the piece is about to land.
            PieceShadowView(tileSize: tileSize)
                // Two effects multiply: the arrival's swell, and the hop's own
                // narrowing as the piece leaves the ground.
                .scaleEffect(shadowScale * hopShadowScale)
                .offset(y: GameRules.pieceShadowDrop * scale)
                .opacity(isFalling ? 0 : 1)

            PixelSprite(id: .piece(zodiac)) {
                placeholder
            }
            .frame(width: tileSize, height: tileSize * 2)
            // Box bottom on the tile bottom: shift up by half a box height minus
            // half a tile.
            .offset(y: -tileSize / 2 - GameRules.pieceLift * scale)
            // Anchored at the feet, so squashing spreads the piece outward
            // along the ground instead of sinking it through the tile.
            .scaleEffect(x: pose.scaleX, y: pose.scaleY, anchor: .bottom)
            .offset(y: -pose.lift * scale)
            // Spin and drop apply to the sprite alone, so the shadow stays put
            // on the square being fallen onto.
            .rotationEffect(.degrees(spin))
            .offset(y: dropOffset)
        }
        .offset(y: carryOffset)
        // The drop: shrink and fade leaving one plane, reverse arriving at the
        // other.
        .scaleEffect(isFalling ? 0.25 : 1)
        .opacity(isFalling ? 0 : 1)
        .allowsHitTesting(false)
    }

    /// How much the shadow shrinks at this point in the hop.
    ///
    /// Read from the pose's own lift rather than from the clock, so it stays in
    /// step with the piece even if the hop curve is reshaped.
    private var hopShadowScale: CGFloat {
        guard GameRules.hopArcHeight > 0 else { return 1 }
        let height = min(pose.lift / GameRules.hopArcHeight, 1)
        return 1 - GameRules.pieceShadowLiftSwing * height
    }

    // MARK: - Placeholder

    private var placeholder: some View {
        let definition = zodiac.definition
        return ZStack {
            RoundedRectangle(cornerRadius: tileSize * 0.22)
                .fill(definition.accentColor)
            RoundedRectangle(cornerRadius: tileSize * 0.22)
                .strokeBorder(.white.opacity(0.65), lineWidth: max(1, tileSize * 0.05))
            Text(definition.glyph.monochromeGlyph)
                .font(.system(size: tileSize * 0.60, weight: .bold))
                .foregroundStyle(.white)
        }
        .padding(tileSize * 0.10)
        .frame(width: tileSize, height: tileSize)
        .frame(maxHeight: .infinity, alignment: .bottom)
    }
}
