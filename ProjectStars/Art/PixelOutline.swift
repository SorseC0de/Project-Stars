//
//  PixelOutline.swift
//  Project Stars
//
//  A hard one-pixel edge around a sprite.
//

import SwiftUI

extension View {

    /// Rings this view's silhouette in `colour`, one **art pixel** thick.
    ///
    /// ## Why eight copies rather than a shader
    ///
    /// Because the offsets are whole art pixels, and that is the entire point. A
    /// sampling shader works in device space, so at any scale that is not a
    /// clean multiple the edge lands between pixels and softens — which is the
    /// one thing this game\'s rendering exists to avoid. Eight shifted copies of
    /// a flattened silhouette land exactly on the grid at every scale, and the
    /// result is as hard-edged as the art it is drawn around.
    ///
    /// Diagonals included, so corners are rung rather than notched. Four copies
    /// leaves a stair-step gap at every 45-degree edge, and pixel art is mostly
    /// 45-degree edges.
    ///
    /// ## What it does not do
    ///
    /// Outline holes. A gap *inside* the silhouette — under an arm, between
    /// Libra\'s scales — is not touched, because a copy shifted outward has
    /// nothing to expose there. This rings the shape, which is what a HUD icon
    /// wants; something that needs its interior edges lit wants a neighbour-
    /// sampling `layerEffect` instead, and a softer edge with it.
    ///
    /// - Parameters:
    ///   - colour: The ring. White by default, which is what reads against both
    ///     planes without belonging to either.
    ///   - scale: Points per art pixel. One art pixel is the only thickness on
    ///     offer, deliberately: two is a border, and a border is a different
    ///     design decision from an outline.
    func pixelOutline(_ colour: Color = Palette.white, scale: CGFloat) -> some View {
        modifier(PixelOutline(colour: colour, scale: scale))
    }
}

private struct PixelOutline: ViewModifier {

    let colour: Color
    let scale: CGFloat

    func body(content: Content) -> some View {
        content.background {
            ZStack {
                ForEach(Array(Self.ring.enumerated()), id: \.offset) { _, step in
                    content
                        .colorEffect(
                            ShaderLibrary.flatSilhouette(.color(colour))
                        )
                        .offset(x: step.0 * scale, y: step.1 * scale)
                }
            }
            // One texture rather than eight composited layers, for the same
            // reason `PaletteGlow` groups its trail.
            .drawingGroup()
            .allowsHitTesting(false)
        }
    }

    /// The eight neighbours of a pixel.
    private static let ring: [(CGFloat, CGFloat)] = [
        (-1, -1), (0, -1), (1, -1),
        (-1, 0), (1, 0),
        (-1, 1), (0, 1), (1, 1),
    ]
}
