//
//  JoystickView.swift
//  Project Stars
//
//  Control scheme A: the stick that shows where the drag points.
//

import SwiftUI

/// A golden stick that leans the way the piece is about to go.
///
/// Not an input control — the whole panel is the input surface, and this reports
/// what it is hearing. Which is the honest arrangement for a thumb-sized target:
/// the player drags anywhere comfortable and this says what that meant, rather
/// than asking them to find and hold a small circle.
struct JoystickView: View {

    /// Where the drag points, or the piece's facing when nobody is dragging.
    let direction: SwipeDirection

    /// True while a finger is down, which is when the stick commits to a lean.
    let isDragging: Bool

    var body: some View {
        let side = GameRules.joystickSize
        let step = direction.unitOffset
        let lean = isDragging ? GameRules.joystickLean : GameRules.joystickRest

        ZStack {
            // The well it sits in: a flat dark plane, same treatment as a
            // button's rim.
            Circle()
                .fill(Palette.midnight)
                .frame(width: side, height: side)

            Circle()
                .strokeBorder(Palette.dusk, lineWidth: max(2, side * 0.03))
                .frame(width: side, height: side)

            // The knob, leaning. Its own rim under it, so it reads as standing
            // out of the well rather than painted on.
            ZStack {
                Circle()
                    .fill(Palette.gold.celShadow)
                    .offset(y: GameRules.buttonDepth)
                Circle()
                    .fill(Palette.gold)
                Circle()
                    .fill(Palette.gold.celHighlight)
                    .padding(side * 0.14)
                    .mask(alignment: .top) {
                        Rectangle().frame(maxHeight: side * 0.12)
                    }
            }
            .frame(width: side * 0.52, height: side * 0.52)
            .offset(
                x: CGFloat(step.dx) * side * lean,
                y: CGFloat(step.dy) * side * lean
            )
        }
        .animation(.spring(response: 0.18, dampingFraction: 0.7), value: direction)
        .animation(.easeOut(duration: 0.12), value: isDragging)
    }
}
