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

    /// What the bloom is recoloured to, or `nil` to keep the art's own light.
    ///
    /// Applied to the halo only — the sprite underneath is untouched. Multiply
    /// rather than replace, so a white highlight comes out as the tint exactly
    /// while anything already coloured is deepened rather than flattened: the
    /// glow stays a property of what is glowing.
    var tint: Color?

    /// How the tint is laid onto the halo.
    ///
    /// A choice rather than a fixed multiply, because the two useful answers
    /// look nothing alike: `sourceAtop` recolours the light and keeps its shape,
    /// while `multiply` deepens what is already there and leaves white as the
    /// tint exactly. Which one is wanted depends on whether the glow is meant to
    /// read as *the thing shining* or as *something shining through it*.
    var tintBlend: BlendMode = .sourceAtop

    @ViewBuilder var content: () -> Content

    /// How far past the content the bloom must be able to reach.
    ///
    /// **The whole of the clipping bug.** A blur spreads well beyond the thing
    /// it blurs, and every rasteriser in the chain — `drawingGroup`, a mask, a
    /// `colorEffect` — draws into the view's *layout bounds* and discards
    /// everything outside them. On a sixteen-point sprite the glow was sliced
    /// off square at the sprite's edge: Libra's scales lost theirs the moment
    /// they swung past their own box, and anything orbiting went dark on the
    /// way out.
    ///
    /// The blurred copy is given this much room before it is rasterised and has
    /// it taken back afterwards, so the bloom overflows the way light does and
    /// the layout never knows. Three times the widest spread, which is where a
    /// Gaussian has nothing left to give.
    private var reach: CGFloat {
        radius * (1 + CGFloat(max(trail, 0)) * 0.9) * 3
    }

    var body: some View {
        content()
            .overlay {
                ZStack {
                    ForEach(Array(0...max(trail, 0)), id: \.self) { step in
                        let spread = radius * (1 + CGFloat(step) * 0.9)
                        let fade = intensity / Double(step + 1)

                        mask
                            .blur(radius: spread)
                            .opacity(fade)
                    }
                }
                .padding(reach)
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
                .drawingGroup()
                // And the room handed back, so the glow costs the layout
                // nothing while the bloom overflows the content's box the way
                // light actually does.
                .padding(-reach)
                // Recoloured after flattening, so the tint lands on the halo as
                // one shape rather than on each copy in the stack — eight
                // overlapping layers tinted individually go uneven wherever they
                // cross.
                // The colour, cut to the halo's shape — **only when one was
                // asked for**.
                //
                // Both the overlay and the group below it are skipped
                // otherwise. An untinted bloom is what every sign but Aquarius
                // wears, and wrapping it in a compositing group changed how the
                // halo met the board for all of them — which is what turned
                // Pisces' orbiting fish into a column of light.
                .overlay {
                    if let tint {
                        tint.mask {
                            ZStack {
                                ForEach(Array(0...max(trail, 0)), id: \.self) { step in
                                    mask
                                        .blur(radius: radius * (1 + CGFloat(step) * 0.9))
                                        .opacity(intensity / Double(step + 1))
                                }
                            }
                            .padding(reach)
                        }
                        .padding(-reach)
                    }
                }
                .compositingGroup(tint != nil)
                // How the finished bloom meets the board.
                //
                // A bloom is light, so adding it is the honest default and what
                // every other glow here uses. Naming a tint is asking a
                // different question — how should this light *interact* with
                // what is behind it — answered here, where the halo actually
                // touches the board.
                .blendMode(tint == nil ? .plusLighter : tintBlend)
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

private extension View {
    /// Groups only when asked.
    ///
    /// `compositingGroup()` is not free of consequence: it flattens what is
    /// under it into one layer before anything else applies, which changes how
    /// blurs and blends behave around it. Applying it unconditionally to make
    /// one tinted glow work altered every untinted one in the game.
    @ViewBuilder
    func compositingGroup(_ when: Bool) -> some View {
        if when { compositingGroup() } else { self }
    }
}

// MARK: - Animatable palette swaps

/// A list of numbers SwiftUI can interpolate.
///
/// Needed because a palette swap is a *set of colours*, and SwiftUI will only
/// tween something that is `VectorArithmetic`. Without this a swap can only
/// switch — which is why the turn counter's charge originally drove its colours
/// off a `TimelineView` and blended them by hand. That worked and was a
/// band-aid: it put colour interpolation inside one view instead of inside the
/// thing that does colour.
struct AnimatableVector: VectorArithmetic {

    var values: [Double]

    static var zero: AnimatableVector { AnimatableVector(values: []) }

    static func + (lhs: AnimatableVector, rhs: AnimatableVector) -> AnimatableVector {
        paired(lhs, rhs, +)
    }

    static func - (lhs: AnimatableVector, rhs: AnimatableVector) -> AnimatableVector {
        paired(lhs, rhs, -)
    }

    /// Element-wise, over the longer of the two — a swap set that grows or
    /// shrinks mid-animation still interpolates rather than snapping.
    private static func paired(
        _ lhs: AnimatableVector,
        _ rhs: AnimatableVector,
        _ combine: (Double, Double) -> Double
    ) -> AnimatableVector {
        let count = max(lhs.values.count, rhs.values.count)
        return AnimatableVector(values: (0..<count).map { index in
            combine(
                index < lhs.values.count ? lhs.values[index] : 0,
                index < rhs.values.count ? rhs.values[index] : 0
            )
        })
    }

    mutating func scale(by rhs: Double) {
        values = values.map { $0 * rhs }
    }

    var magnitudeSquared: Double {
        values.reduce(0) { $0 + $1 * $1 }
    }
}

/// A palette swap whose colours can be animated between.
///
/// The shader already takes its colours as a flat array of floats; this makes
/// that array the modifier's `animatableData`, so `withAnimation` interpolates
/// every channel of every swap for free. Any view can now change palette
/// *gradually* — the counter's charge, a sign heating up, a tile cooling.
struct AnimatablePaletteSwap: ViewModifier, Animatable {

    var animatableData: AnimatableVector

    init(_ swaps: [PaletteSwap]) {
        animatableData = AnimatableVector(
            values: swaps.flatMap { swap in
                (swap.from.shaderComponents + swap.to.shaderComponents).map(Double.init)
            }
        )
    }

    func body(content: Content) -> some View {
        content.colorEffect(
            ShaderLibrary.paletteSwap(
                .floatArray(animatableData.values.map(Float.init))
            )
        )
    }
}

extension View {
    /// Swaps palette entries, interpolating when the set changes inside a
    /// `withAnimation`.
    func animatedPaletteSwap(_ swaps: [PaletteSwap]) -> some View {
        modifier(AnimatablePaletteSwap(swaps))
    }
}
