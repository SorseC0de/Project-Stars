//
//  PieceShadowView.swift
//  Project Stars
//
//  The soft ellipse under a piece or a coin.
//

import SwiftUI

/// A flattened ellipse standing in for a drop shadow.
///
/// Drawn rather than imported. It is a single flat colour at low opacity, which
/// is cheap to keep consistent across every plane and wear state — and trivial
/// to replace with a sprite if it ever reads as too soft against the pixel art,
/// since nothing but this file knows how it is made.
struct PieceShadowView: View {

    /// Size of a board cell, in points.
    let tileSize: CGFloat

    /// Fraction of a cell the shadow spans.
    var widthFraction: CGFloat = 0.62

    /// How flat it is, as a fraction of its own width.
    var flatness: CGFloat = 0.34

    var opacity: Double = 0.45

    /// What the shadow is made of.
    ///
    /// Defaults to `Palette.shadow`, which is how a solid object occludes the
    /// ground. A *glowing* object does the opposite — it spills light onto the
    /// tile — so the Pentacle passes white and an additive blend instead.
    var color: Color = Palette.shadow

    var blendMode: BlendMode = .normal

    var body: some View {
        Ellipse()
            .fill(color)
            .opacity(opacity)
            .blendMode(blendMode)
            .frame(
                width: tileSize * widthFraction,
                height: tileSize * widthFraction * flatness
            )
            .allowsHitTesting(false)
    }
}
