//
//  ColorFlash.swift
//  Project Stars
//
//  Recolouring anything, without flattening it.
//

import SwiftUI

extension View {

    /// Washes this view in `color` while keeping its own light and shade.
    ///
    /// ## Why `.color` and not a tint
    ///
    /// `.blendMode(.color)` takes hue and saturation from the source and
    /// *luminosity from the backdrop* — so a gold piece flashed red is a red
    /// piece with all of the gold's shading, highlights and dark outline still
    /// where they were. An overlay of flat colour would paint over the sprite
    /// and turn it into a silhouette; `.colorMultiply` would darken rather than
    /// recolour, and cannot make anything brighter than it started.
    ///
    /// ## Why the content is masked with itself
    ///
    /// A blend mode composites against whatever is behind it, and behind a
    /// 16x32 sprite is mostly empty frame. Masking the wash to the view means
    /// only the drawn pixels are recoloured, rather than a rectangle of colour
    /// landing on the board around it.
    ///
    /// - Parameter amount: `0` leaves it alone, `1` is a full recolour.
    func colorFlash(_ color: Color, amount: Double) -> some View {
        overlay {
            color
                .blendMode(.color)
                .mask(self)
                .opacity(min(max(amount, 0), 1))
                .allowsHitTesting(false)
        }
    }
}
