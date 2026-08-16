//
//  PickupIconView.swift
//  Project Stars
//
//  A Pentacle's face, drawn or written.
//

import SwiftUI

/// The icon for a pickup, falling back to its glyph.
///
/// One view rather than the same `if let icon` at every site. The catalogue is
/// illustrated a few at a time, so *some art and some glyphs* is the normal
/// state for as long as it takes — and a rule written once holds across all of
/// it, where a rule written six times drifts on the second one somebody edits.
///
/// The art is a template, so it takes the colour it is given. A glyph is not:
/// an emoji carries its own, and tinting it produces a coloured block. That is
/// the one place the two disagree, and it is handled here so nothing else has
/// to know which of the two it is looking at.
struct PickupIconView: View {

    let effect: any PickupEffect

    /// Point size of the icon's box.
    var size: CGFloat = 22

    /// What a drawn icon is tinted. Ignored by a glyph.
    var tint: Color = Palette.white

    /// A disc behind it, so an icon reads against whatever it is over.
    ///
    /// The panel and the shop both put these on backgrounds the icon was not
    /// drawn against — a thin white line over pale stone is not an icon, it is
    /// a scratch. Off for anywhere that provides its own ground.
    var background: Color? = Palette.midnight

    var body: some View {
        ZStack {
            if let background {
                Circle()
                    .fill(background)
                    .frame(width: size * 1.5, height: size * 1.5)
            }

            if let name = effect.icon, UIImage(named: name) != nil {
                Image(name)
                    .renderable(size: size)
                    .foregroundStyle(tint)
            } else {
                // The stand-in. Sized a little smaller because an emoji fills
                // its box where a drawn icon is padded inside one.
                Text(effect.glyph)
                    .font(.system(size: size * 0.82))
            }
        }
        .frame(width: size * 1.5, height: size * 1.5)
    }
}

private extension Image {
    /// Scaled to fit, as a template.
    func renderable(size: CGFloat) -> some View {
        self
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
    }
}
