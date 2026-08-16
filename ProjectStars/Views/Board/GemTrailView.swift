//
//  GemTrailView.swift
//  Project Stars
//
//  The streak a charged piece's gems leave behind it.
//

import SwiftUI

/// One lagging after-image of a charged piece's lit gems.
///
/// ## Why this is not `PaletteGlow`'s trail
///
/// `PaletteGlow(trail:)` stacks progressively wider blurs *at the same place*.
/// That is bloom depth — it makes a light look hot — but a light that never
/// moves off its own centre cannot streak. A motion trail needs the glow to be
/// somewhere the piece **was**.
///
/// ## How the lag is produced
///
/// Not by recording positions. Each copy is placed at the piece's *current*
/// square and given its own, slower spring: `.animation(_:value:)` overrides the
/// transaction the replay is running under, so copy `step` chases the piece
/// instead of arriving with it. Stack a few and the gems draw lines of light
/// across the board.
///
/// Falling out of step is the entire point, so nothing here needs cleaning up —
/// when the piece stops, every copy settles onto it and the trail closes.
struct GemTrailView: View {

    let zodiac: Zodiac

    /// Size of a board cell, in points.
    let tileSize: CGFloat

    /// Whole-pixel scale, for art-pixel offsets.
    let scale: CGFloat

    /// How far back in the trail this copy is. `0` rides closest to the piece.
    let step: Int

    var body: some View {
        let gem = GemTones.forElement(zodiac.element)

        ZStack {
            ForEach(0..<GameRules.gemTrailBoost, id: \.self) { _ in
                PixelSprite(id: .piece(zodiac)) { Color.clear }
                    .frame(width: tileSize, height: tileSize * 2)
            // Light the gem first, then keep only that entry: the trail is the
            // gems alone, never a ghost of the whole figure.
                    .paletteSwap([PaletteSwap(gem.dim, gem.lit)])
                    .colorEffect(
                        ShaderLibrary.paletteGlowMask(
                            .floatArray(gem.lit.shaderComponents)
                        )
                    )
                    .blur(
                        radius: GameRules.gemTrailRadius * scale
                            * (1 + CGFloat(step) * 0.45)
                    )
            }
        }
        // Room for the blur before it is flattened.
        //
        // Every copy in the stack is framed at exactly the piece's box, and
        // `drawingGroup` rasterises into the layout bounds — so the blur was cut
        // off square at that box and the streak came out as a hard-edged
        // rectangle the size of the sprite's frame, standing behind a charged
        // piece. The padding is the widest blur this copy will draw.
        .padding(GameRules.gemTrailRadius * scale * (1 + CGFloat(step) * 0.45) * 3)
        // One offscreen pass for the whole stack, for the same reason
        // `PaletteGlow` needs it: this is the sprite re-shaded and re-blurred
        // once per copy, and a charged piece draws several of these at once.
        .drawingGroup()
        .opacity(pow(GameRules.gemTrailFalloff, Double(step + 1)))
        // Matches `PieceView`'s figure box exactly, so the streak comes off
        // the gems and not off some point near them.
        .offset(y: -tileSize / 2 - GameRules.pieceLift * scale)
        // Additive: two on-palette colours summed are brighter than either
        // and still on-palette, which is how light reads without a
        // fifty-eighth entry.
        .blendMode(.plusLighter)
        .allowsHitTesting(false)
    }
}
