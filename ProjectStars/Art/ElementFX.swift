//
//  ElementFX.swift
//  Project Stars
//
//  The colour each element's energy is made of.
//

import SwiftUI

/// The three-colour ramp every energy effect for an element draws from.
///
/// One place, so a fire effect written next year matches the fire effect written
/// today without either knowing about the other. Shaders read the same ramp —
/// `ElementalBurstView` passes these straight to Metal rather than the shader
/// hardcoding its own — so a change here moves everything at once.
///
/// All nine colours are palette entries. Energy is the one place it would be
/// tempting to reach outside the palette for a brighter highlight; additive
/// blending is the answer to that instead. Two palette colours added together
/// are brighter than either, and still on-palette.
struct ElementFX {

    /// Deepest tone. The body of the effect.
    let deep: Color

    /// Mid tone. Where most of the mass sits.
    let mid: Color

    /// Brightest tone. Edges, sparks, the leading front.
    let bright: Color

    static func ramp(for element: ZodiacElement) -> ElementFX {
        switch element {
        case .water:
            // Blues, from deep water up to sea spray.
            ElementFX(deep: Palette.blue, mid: Palette.lightBlue, bright: Palette.cyan)

        case .air:
            // Teals through lime into yellow-green — wind as something seen in
            // the leaves it disturbs rather than in itself.
            ElementFX(deep: Palette.teal, mid: Palette.lime, bright: Palette.yellowGreen)

        case .earth:
            // Green, kept clear of the darkest end: earth energy is growth, and
            // `forest` reads as shadow rather than as life.
            ElementFX(deep: Palette.darkGreen, mid: Palette.green, bright: Palette.grass)

        case .fire:
            // Reds up through the heat into the flame's edge.
            ElementFX(deep: Palette.darkRed, mid: Palette.red, bright: Palette.orange)
        }
    }

    /// The ramp used by effects that belong to no element — teleports, the
    /// Pentacle's own sparks.
    ///
    /// White through to the palest blue: light, not an element.
    static let neutral = ElementFX(
        deep: Palette.lightGray,
        mid: Palette.white,
        bright: Palette.ice
    )

    /// The three tones in order, for effects that want to pick per particle.
    var tones: [Color] { [deep, mid, bright] }
}
