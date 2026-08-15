//
//  FractureFX.swift
//  Project Stars
//
//  Swift side of the Fracturing Fissure's screen effect.
//

import SwiftUI

/// The board as it looks while Gemini is torn in two.
///
/// A slow whole-pixel ripple over everything, and a wide, dim bloom on top of
/// it — the world seen through a tear that has not closed.
///
/// ## Why it wraps rather than modifies
///
/// The bloom needs the content twice: once as itself and once thresholded down
/// to only its bright pixels. A `ViewModifier` receives its content once, which
/// is the same reason `PaletteGlow` is a wrapper — and this reuses that rather
/// than growing a second bloom with its own opinions about brightness.
///
/// ## Why the bloom is applied first
///
/// Warping the finished composite is one distortion pass over one layer. Warping
/// first and blooming after would run the ripple over the content *and* over the
/// glow mask, for a difference nobody can see: at an amplitude of one or two art
/// pixels, a bloom of a rippled board and a rippled bloom of a board are the
/// same picture.
struct FractureField<Content: View>: View {

    /// Whether the world is currently torn.
    ///
    /// The fade in and out is this view's own business rather than the caller's:
    /// it is a property of the effect, not of the game state, and asking the
    /// session to carry a ramped number would put a rendering detail into the
    /// model. At rest the shader returns early and the bloom is transparent, so
    /// an unsplit board pays for nothing but the wrapper.
    var isActive: Bool

    /// Points per art pixel — `PixelArtMetrics.scale`.
    let scale: CGFloat

    @ViewBuilder var content: () -> Content

    /// Seconds, stopped whenever the game is. Ambient motion carrying on under a
    /// frozen game says nothing is waiting on anything — see `AmbientClock`.
    @Environment(\.ambientClock) private var ambientClock

    /// When the tear last opened or closed, for the ramp.
    @State private var changedAt = Date.distantPast

    var body: some View {
        TimelineView(.animation) { timeline in
            // Wrapped before it is narrowed to `Float`.
            //
            // Seconds since 2001 is about 8×10⁸, and `Float` carries seven
            // significant digits — so the value handed to the shader only
            // changed in steps of about a minute, and the wave was frozen. A
            // still warp of a pixel or two reads as nothing happening at all,
            // which is why this looked like it was never working.
            //
            // An hour is long enough that the seam never shows and short enough
            // that `Float` keeps sub-millisecond resolution.
            let now = ambientClock(timeline.date.timeIntervalSinceReferenceDate)
                .truncatingRemainder(dividingBy: 3600)
            let lean = lean(at: timeline.date)

            if lean <= 0 {
                // Nothing on, nothing paid. Whole and unrippled, the board is
                // drawn exactly as it was before any of this existed — no
                // rasterisation, no bloom, no shader.
                content()
            } else {
                bloomed(lean)
                    // Padded out and pulled back in, around the rasterisation.
                    //
                    // `drawingGroup` flattens to the view's *layout* bounds, and
                    // the board deliberately overhangs its own: the cursor can
                    // sit past the edge when a move would leave the grid, and
                    // the Nexys overhangs its square. Rasterised tight, both get
                    // guillotined. The padding gives the texture room for them
                    // and the negative padding afterwards puts the layout back
                    // where it was, so nothing below this moves.
                    .padding(overhang)
                    // Flattened before the warp, and this is the part that
                    // decides whether any of this is visible at all.
                    //
                    // A distortion shader remaps one rendered layer. The board
                    // is not one layer — it is a stack of `TimelineView`s,
                    // additive blends and existing drawing groups — and asked to
                    // warp that, SwiftUI quietly warps nothing. Collapsing it
                    // first gives the shader the single texture it needs, and is
                    // cheaper besides: one pass over the board instead of one
                    // per layer that would have taken it.
                    .drawingGroup()
                    .distortionEffect(
                        ShaderLibrary.fractureWarp(
                            .float(Float(now)),
                            .float(Float(GameRules.fractureWarpAmplitude * lean)),
                            .float(Float(scale))
                        ),
                        // How far the shader may reach outside the layer.
                        // Understate it and the ripple is clipped flat at the
                        // board's edges, which is where it is most visible.
                        maxSampleOffset: CGSize(width: reach, height: reach)
                    )
                    .padding(-overhang)
            }
        }
        .onChange(of: isActive) { changedAt = .now }
    }

    /// How far the board is allowed to draw outside itself, in points.
    private var overhang: CGFloat {
        CGFloat(GameRules.tilePixelSize) * scale
    }

    /// How far through the fade this is, `0`…`1`.
    ///
    /// Eased rather than linear, so the tear arrives with a shove and settles,
    /// instead of sliding open at a constant rate like a door.
    private func lean(at date: Date) -> Double {
        let elapsed = date.timeIntervalSince(changedAt) / GameRules.fractureRampDuration
        let progress = min(max(elapsed, 0), 1)
        let eased = progress * progress * (3 - 2 * progress)
        return isActive ? eased : 1 - eased
    }

    /// The content, already glowing.
    ///
    /// Deliberately dim and wide. A bloom that reads well on one lit sprite is
    /// far too hot spread over a whole board: every copy adds to every other and
    /// to the board behind it, so a screen-wide haze wants a fraction of the
    /// strength a piece's own glow uses — see the note on translating Canvas
    /// glows into views.
    private func bloomed(_ lean: Double) -> some View {
        PaletteGlow(
            threshold: GameRules.fractureBloomThreshold,
            radius: GameRules.fractureBloomRadius,
            intensity: GameRules.fractureBloomIntensity * lean
        ) {
            content()
        }
    }

    /// The furthest the warp can throw a pixel, in points.
    ///
    /// The wave's two layers sum to 1.6 at their crest, and the shader rounds
    /// afterwards, so a whole art pixel of slack covers the rounding.
    private var reach: CGFloat {
        (GameRules.fractureWarpAmplitude * 1.6 + 1) * scale
    }
}
