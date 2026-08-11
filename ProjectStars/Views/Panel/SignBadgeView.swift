//
//  SignBadgeView.swift
//  Project Stars
//
//  The sign and its element, in whichever treatment is being tried.
//

import SwiftUI

/// The sign's mark and its element's, drawn from the flat vector icons.
///
/// ## Why three treatments
///
/// The icons are deliberately flat monochrome so the *presentation* is a
/// separate decision from the art. Which one reads best on a phone, against a
/// dark panel, at a glance, is not a thing to be reasoned out — it is a thing to
/// be looked at. All three are here to be switched between; see
/// `GameRules.badgeStyle`.
///
/// The element is never named in words. It is one of four marks a player learns
/// in a minute, and spelling it out costs a line of the panel forever to save a
/// minute once.
struct SignBadgeView: View {

    let zodiac: Zodiac

    /// Height of the sign's mark, in points. The element scales off it.
    var size: CGFloat = GameRules.badgeSize

    var body: some View {
        HStack(spacing: size * 0.34) {
            mark(icon: signIcon, tint: Palette.gold, side: size)
            mark(icon: elementIcon, tint: elementTint, side: size * GameRules.badgeElementScale)
        }
    }

    /// One icon in the treatment being tried.
    @ViewBuilder
    private func mark(icon: Image, tint: Color, side: CGFloat) -> some View {
        let glyph = icon
            .renderable(side: side * GameRules.badgeGlyphInset, tint: tint)

        switch GameRules.badgeStyle {
        case .flat:
            glyph.frame(width: side, height: side)

        case .emblem:
            // Struck into a coin: the same flat planes the buttons use, so the
            // badge belongs to the same object as the rest of the panel.
            ZStack {
                Circle().fill(Palette.gold.celShadow)
                Circle().fill(Palette.gold).padding(side * 0.09)
                glyph
            }
            .frame(width: side, height: side)

        case .constellationPlate:
            // Dealer's choice: a dark plate with the sign lit on it like a
            // window onto the sky, which is what the board above already is.
            ZStack {
                RoundedRectangle(cornerRadius: side * 0.26)
                    .fill(Palette.midnight)
                RoundedRectangle(cornerRadius: side * 0.26)
                    .strokeBorder(Palette.gold, lineWidth: max(1, side * 0.05))
                glyph
            }
            .frame(width: side, height: side)
        }
    }

    private var signIcon: Image { Image("Signs/\(zodiac.rawValue)") }
    private var elementIcon: Image { Image("Elements/\(zodiac.element.rawValue)") }

    private var elementTint: Color {
        ElementFX.ramp(for: zodiac.element).bright
    }
}

// MARK: - Drawing a template icon

private extension Image {
    /// The icon at a size, in a colour.
    ///
    /// `renderingMode(.template)` is what makes the flat vectors take a palette
    /// entry instead of whatever they were exported as — which is the entire
    /// reason they were drawn monochrome.
    func renderable(side: CGFloat, tint: Color) -> some View {
        self
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: side, height: side)
            .foregroundStyle(tint)
    }
}
