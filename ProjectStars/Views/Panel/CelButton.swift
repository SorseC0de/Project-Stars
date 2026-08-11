//
//  CelButton.swift
//  Project Stars
//
//  The chunky, flat-shaded buttons the panel is built from.
//

import SwiftUI

/// A big, obviously-pressable button drawn the way the game is drawn.
///
/// ## Why no gradients
///
/// The game is a fixed 47-colour palette and pixel art. A gradient is thousands
/// of colours none of which are in it, and it reads as a different piece of
/// software sitting under the board. Depth here comes from *flat planes* at
/// different tones — a lit face, a darker rim, a shadow under it — which is how
/// the pieces themselves are shaded, and it is the whole cel-shaded look.
///
/// ## Why the press moves it
///
/// The lift is real: the face sits `depth` above the rim, and pressing drops it
/// onto it. Nothing fades, nothing dims — the button physically goes down, which
/// on a phone is the clearest possible confirmation that a touch landed.
struct CelButton<Label: View>: View {

    /// The lit face.
    var tint: Color = Palette.gold

    /// How far the face stands above its rim, in points.
    var depth: CGFloat = GameRules.buttonDepth

    /// Greys out and stops responding.
    var isEnabled: Bool = true

    let action: () -> Void
    @ViewBuilder let label: () -> Label

    @State private var isPressed = false

    var body: some View {
        let face = isEnabled ? tint : Palette.gray
        let rim = face.celShadow

        ZStack {
            // The rim, standing proud below the face. Drawn as its own rounded
            // rectangle rather than a border so the button has a genuine side.
            RoundedRectangle(cornerRadius: GameRules.buttonCorner)
                .fill(rim)
                .offset(y: depth)

            RoundedRectangle(cornerRadius: GameRules.buttonCorner)
                .fill(face)
                .overlay {
                    // A single flat highlight across the top, cel-shaded: one
                    // hard-edged lighter plane, not a sheen.
                    RoundedRectangle(cornerRadius: GameRules.buttonCorner)
                        .fill(face.celHighlight)
                        .padding(GameRules.buttonHighlightInset)
                        .mask(alignment: .top) {
                            Rectangle().frame(maxHeight: GameRules.buttonHighlightHeight)
                        }
                }
                .offset(y: isPressed ? depth : 0)

            label()
                .foregroundStyle(isEnabled ? Palette.warmBlack : Palette.darkGray)
                .offset(y: isPressed ? depth : 0)
        }
        .animation(.easeOut(duration: 0.06), value: isPressed)
        .contentShape(Rectangle())
        .onTapGesture { if isEnabled { action() } }
        // A press has to show the instant the finger lands, which a tap gesture
        // alone cannot do — it only reports once the tap completes.
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in if isEnabled { isPressed = true } }
                .onEnded { _ in isPressed = false }
        )
        .disabled(!isEnabled)
    }
}

// MARK: - Cel shading

extension Color {
    /// The darker plane under a lit face.
    ///
    /// Looked up in the palette rather than computed: darkening a colour
    /// arithmetically lands between entries, and the whole point of the fixed
    /// palette is that nothing does.
    var celShadow: Color { PaletteRamp.darker(self) }

    /// The lighter plane across the top of one.
    var celHighlight: Color { PaletteRamp.lighter(self) }
}
