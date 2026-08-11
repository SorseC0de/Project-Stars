//
//  DirectionPadView.swift
//  Project Stars
//
//  Control scheme B: move by pressing.
//

import SwiftUI

/// A keyboard cross of direction buttons, with a sign's special moves beside
/// them.
///
/// ## Why a keyboard cross rather than a diamond
///
/// Up on its own row, then left/down/right together. It is the shape every
/// keyboard already uses, it is what a thumb expects, and it costs one row less
/// than a diamond — which on a phone is the difference between buttons being big
/// enough and not.
///
/// ## Why the special moves are separate buttons
///
/// A sign with a two-square sidestep or a northward vault cannot express that
/// with a tap: the direction is the same, only the distance differs. Scheme A
/// gets it from how far the drag went. Here it needs its own button, so the
/// longer move appears as a smaller arrow beside the direction it extends —
/// present only when that sign can actually make it.
struct DirectionPadView: View {

    let session: GameSession

    var body: some View {
        VStack(spacing: GameRules.directionButtonSize * 0.14) {
            row([.up])
            row([.left, .down, .right])
        }
    }

    private func row(_ directions: [SwipeDirection]) -> some View {
        HStack(spacing: GameRules.directionButtonSize * 0.14) {
            ForEach(directions) { direction in
                HStack(spacing: 4) {
                    button(direction)
                    special(direction)
                }
            }
        }
    }

    /// The ordinary one-square move.
    private func button(_ direction: SwipeDirection) -> some View {
        CelButton(isEnabled: session.acceptsInput) {
            session.submit(direction, reach: 0)
        } label: {
            arrow(direction, tint: Palette.warmBlack)
                .frame(
                    width: GameRules.directionButtonSize * 0.46,
                    height: GameRules.directionButtonSize * 0.46
                )
        }
        .frame(width: GameRules.directionButtonSize, height: GameRules.directionButtonSize)
    }

    /// The sign's longer move that way, when it has one.
    @ViewBuilder
    private func special(_ direction: SwipeDirection) -> some View {
        if let reach = session.specialReach(for: direction) {
            let side = GameRules.directionButtonSize * GameRules.specialArrowScale

            CelButton(tint: Palette.lightBlue, isEnabled: session.acceptsInput) {
                session.submit(direction, reach: reach)
            } label: {
                arrow(direction, tint: Palette.midnight)
                    .frame(width: side * 0.5, height: side * 0.5)
            }
            .frame(width: side, height: side)
        }
    }

    /// The drawn arrow, turned to point the right way.
    ///
    /// One sprite rotated rather than four, which is also how the sheet is laid
    /// out — the cursor's brackets do the same thing.
    private func arrow(_ direction: SwipeDirection, tint: Color) -> some View {
        PixelSprite(id: .directionArrow(direction)) {
            Image(systemName: "arrowtriangle.up.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(tint)
                .rotationEffect(.degrees(direction.iconRotation))
        }
    }
}

// MARK: - Which way an arrow points

extension SwipeDirection {
    /// Degrees to turn an up-pointing arrow by.
    var iconRotation: Double {
        switch self {
        case .up: 0
        case .right: 90
        case .down: 180
        case .left: 270
        }
    }
}
