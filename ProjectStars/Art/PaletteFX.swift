//
//  PaletteFX.swift
//  Project Stars
//
//  Swift side of the palette shaders: recolouring, and isolated glow.
//

import SwiftUI

// MARK: - Colour components

extension Color {
    /// This colour's red, green and blue as shader floats.
    ///
    /// The shaders match on colour rather than on an index, because SwiftUI has
    /// no notion of an indexed image — the sprite arrives as pixels. Matching on
    /// value gets the same result as long as the palette has no duplicates,
    /// which it does not.
    var shaderComponents: [Float] {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        return [Float(r), Float(g), Float(b)]
    }
}

// MARK: - Palette swap

/// One entry replaced by another.
struct PaletteSwap: Hashable {
    let from: Color
    let to: Color

    init(_ from: Color, _ to: Color) {
        self.from = from
        self.to = to
    }
}

extension View {
    /// Replaces palette entries in this view's pixels.
    ///
    /// Entries not listed pass through, so a partial mapping recolours part of a
    /// sprite and leaves the rest.
    func paletteSwap(_ swaps: [PaletteSwap]) -> some View {
        let flat = swaps.flatMap { $0.from.shaderComponents + $0.to.shaderComponents }
        return colorEffect(ShaderLibrary.paletteSwap(.floatArray(flat)))
    }
}

// MARK: - Isolated glow

/// Draws its content, then blooms only the listed palette entries over the top.
///
/// The content is rendered twice: once normally, and once through a shader that
/// keeps *only* the glowing entries. The second copy is blurred and composited
/// additively, so those entries throw light onto whatever is behind them while
/// the rest of the sprite stays exactly as drawn.
///
/// Additive blending is what makes this safe under a fixed palette: two palette
/// colours summed are brighter than either and still on-palette, so a highlight
/// never needs a colour the art could not contain.
///
/// - Note: A wrapper view rather than a modifier because it genuinely needs its
///   content twice, and a `ViewModifier` only receives it once.
struct PaletteGlow<Content: View>: View {

    /// How bright a pixel has to be before it glows, `0`…`1`.
    ///
    /// Defaulted, and almost never worth setting — see `luminanceGlowMask` for
    /// why there is no longer a list of colours here.
    var threshold: Double = GameRules.glowLuminanceThreshold

    /// How far the light spreads, in points.
    var radius: CGFloat = 4

    /// How strong the bloom is. Above 1 the glow is drawn more than once.
    var intensity: Double = 1

    /// How many copies of the trail to draw behind a moving highlight.
    ///
    /// Zero is a still glow. Each step is drawn progressively larger and fainter,
    /// which reads as a smear when the view is moving and as a soft halo when it
    /// is not — so it costs nothing to leave on for something that sometimes
    /// moves and sometimes does not.
    var trail: Int = 0

    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .overlay {
                ZStack {
                    ForEach(0...max(trail, 0), id: \.self) { step in
                        let spread = radius * (1 + CGFloat(step) * 0.9)
                        let fade = intensity / Double(step + 1)

                        mask
                            .blur(radius: spread)
                            .opacity(fade)
                    }
                }
                // Rendered once, offscreen, as a single texture.
                //
                // This is what was halving the frame rate wherever a glow was on
                // screen — a full meter, the Bolt's rainbow — and it is worth
                // being precise about why, because it looked like the glow was
                // simply expensive.
                //
                // Every step of the trail rebuilds `content()` and runs the
                // palette shader over it *again*, then blurs the result, and
                // SwiftUI composites each of those as its own layer. A trail of
                // three is four shader passes, four blurs and five composites,
                // sixty times a second, for one piece. Grouping collapses the
                // whole bloom into one offscreen pass whose result is drawn once
                // — and blurs are far cheaper inside a single render than as
                // separate composited layers.
                //
                // The blend has to stay outside the group so the finished bloom
                // still adds to the board behind it.
                //
                // Padded first, because `drawingGroup` rasterises into a buffer
                // the size of the view's **bounds** and a blur spreads past
                // them. Unpadded, the bloom fills the sprite's box and is cut
                // off square at its edges — which does not read as a glow that
                // is slightly clipped, it reads as a glowing rectangle standing
                // behind the piece. Room for the widest step of the trail is
                // enough for every step inside it.
                .padding(radius * (1 + CGFloat(max(trail, 0)) * 0.9) * 2)
                .drawingGroup()
                .blendMode(.plusLighter)
                .allowsHitTesting(false)
            }
    }

    /// The content with everything but the glowing entries removed.
    ///
    /// Rasterised before it is used, so the shader runs once for the whole trail
    /// rather than once per step.
    private var mask: some View {
        content()
            .colorEffect(ShaderLibrary.luminanceGlowMask(.float(Float(threshold))))
            .drawingGroup()
    }
}

// MARK: - Moss

extension View {
    /// Scatters moss over this view's pixels.
    ///
    /// - Parameters:
    ///   - colors: The greens to draw from.
    ///   - keeping: Entries never overgrown — the gem, above all.
    ///   - viewSize: Rendered size, in points.
    ///   - artSize: The sprite's size in art pixels, so moss lands on whole ones.
    ///   - seed: Per-piece, so every sign is overgrown differently.
    ///   - coverage: Roughly how much of the lower half is taken.
    func paletteMoss(
        colors: [Color],
        keeping reserved: [Color],
        viewSize: CGSize,
        artSize: CGSize,
        seed: Float,
        coverage: Float
    ) -> some View {
        var args: [Float] = [Float(colors.count)]
        args += colors.flatMap(\.shaderComponents)
        args += reserved.flatMap(\.shaderComponents)

        return colorEffect(
            ShaderLibrary.paletteMoss(
                .float2(viewSize.width, viewSize.height),
                .float2(artSize.width, artSize.height),
                .float(seed),
                .float(coverage),
                .floatArray(args)
            )
        )
    }
}
