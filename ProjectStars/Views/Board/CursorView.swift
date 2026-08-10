//
//  CursorView.swift
//  Project Stars
//
//  The four-bracket cursor marking where a move would land.
//

import SwiftUI

/// Draws the destination cursor as four independent corner brackets.
///
/// The brackets are cut from a single 16x16 cell into 8x8 quarters so each can be
/// pushed diagonally outward. They flare out briefly and settle back in tight,
/// on a loop — the whole animation is three numbers in `GameRules`
/// (`cursorFlareOutset`, `cursorFlareInset`, `cursorFlarePeriod`) plus
/// `cursorFlareAttack` for how sharp the flare is.
///
/// **Colour is the cursor's meaning**, so it is chosen from the tile beneath
/// rather than from the piece: white for clear ground, yellow and orange for
/// wear, red — with a warning struck through it — for a hole. A move that is not
/// on the board at all shows the white set at low opacity, because the point is
/// that there is nothing there.
struct CursorView: View {

    let status: GameEngine.CursorStatus

    /// Size of a board cell, in points.
    let size: CGFloat

    /// Whole-pixel scale, for converting art-pixel offsets to points.
    let scale: CGFloat

    /// Which brackets to draw.
    ///
    /// The cursor is split across two depths so it can wrap around whatever it
    /// is marking — see `BoardObject.sortLayer`.
    var corners: [CursorCorner] = CursorCorner.allCases

    /// Whether this half carries the hole warning. Only the front half does,
    /// so it is never hidden behind the thing it is warning about.
    var showsWarning: Bool = true

    var body: some View {
        TimelineView(.animation) { timeline in
            let spread = flare(at: timeline.date) * scale

            ZStack {
                ForEach(corners, id: \.self) { corner in
                    bracket(corner, spread: spread)
                }
                if showsWarning { warning }
            }
            .frame(width: size, height: size)
            .opacity(status == .impossible ? GameRules.cursorImpossibleOpacity : 1)
        }
        .allowsHitTesting(false)
    }

    // MARK: - Parts

    private func bracket(_ corner: CursorCorner, spread: CGFloat) -> some View {
        let quarter = size / 2
        let sign = corner.outwardSign

        return PixelSprite(id: .cursorCorner(tint, corner)) {
            placeholderBracket(corner)
        }
        .frame(width: quarter, height: quarter)
        .offset(
            x: CGFloat(sign.x) * (quarter / 2 + spread),
            y: CGFloat(sign.y) * (quarter / 2 + spread)
        )
    }

    /// The exclamation shown only over a hole — the one case where the cursor
    /// has to say more than "here".
    @ViewBuilder
    private var warning: some View {
        if status == .open {
            PixelSprite(id: .cursorWarning) {
                Text("!")
                    .font(.system(size: size * 0.5, weight: .black, design: .rounded))
                    .foregroundStyle(Palette.cursorWarning)
            }
            .frame(width: size, height: size)
        }
    }

    /// Drawn while the sheet is missing: a plain L in the right colour.
    private func placeholderBracket(_ corner: CursorCorner) -> some View {
        let thickness = max(1, size * 0.08)
        let sign = corner.outwardSign
        return ZStack {
            Rectangle().fill(colour)
                .frame(width: size * 0.22, height: thickness)
                .frame(maxWidth: .infinity, alignment: sign.x < 0 ? .leading : .trailing)
            Rectangle().fill(colour)
                .frame(width: thickness, height: size * 0.22)
                .frame(maxHeight: .infinity, alignment: sign.y < 0 ? .top : .bottom)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity,
               alignment: Alignment(
                   horizontal: sign.x < 0 ? .leading : .trailing,
                   vertical: sign.y < 0 ? .top : .bottom
               ))
    }

    // MARK: - Animation

    /// How far the brackets sit from their tight position, in art pixels.
    ///
    /// A quick push outward over `cursorFlareAttack` of the period, then a
    /// longer settle back — so the resting state is tight and the flare reads as
    /// a pulse rather than a wobble.
    private func flare(at date: Date) -> CGFloat {
        let period = GameRules.cursorFlarePeriod
        let phase = date.timeIntervalSinceReferenceDate
            .truncatingRemainder(dividingBy: period) / period

        let attack = max(GameRules.cursorFlareAttack, 0.001)
        let eased: Double = phase < attack
            ? phase / attack
            : max(0, 1 - (phase - attack) / (1 - attack))

        let inset = GameRules.cursorFlareInset
        return inset + (GameRules.cursorFlareOutset - inset) * eased
    }

    // MARK: - Colour

    /// The sheet only carries four bracket colours; `impossible` reuses white
    /// and says its piece with opacity instead.
    private var tint: CursorTint {
        switch status {
        case .clear, .impossible: .white
        case .damaged: .yellow
        case .badlyDamaged: .orange
        case .open: .red
        }
    }

    private var colour: Color {
        switch status {
        case .clear: Palette.cursorClear
        case .damaged: Palette.cursorDamaged
        case .badlyDamaged: Palette.cursorBadlyDamaged
        case .open: Palette.cursorOpen
        case .impossible: Palette.cursorImpossible
        }
    }
}
