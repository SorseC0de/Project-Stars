//
//  NexysView.swift
//  Project Stars
//
//  The floating island at the centre of the board.
//

import SwiftUI

/// Draws the Nexys island.
///
/// The sprite is 48x48 — three cells — but only its **middle cell is the tile**.
/// The overhang is rim and greenery spilling past the square it occupies, which
/// is what makes it read as an island rather than a stone slab.
///
/// It rests slightly above where a tile would sit (`GameRules.nexysRaise`) and
/// drifts up and down around that. The drift is supplied by the caller rather
/// than generated here, because the piece standing on the island has to ride the
/// same offset — one clock, two views.
struct NexysView: View {

    /// Size of a single board cell, in points.
    let tileSize: CGFloat

    /// Whole-pixel scale factor, for converting art pixels to points.
    let scale: CGFloat

    /// Current bob offset in points, negative being up. Comes from
    /// `BoardView.nexysOffset(at:)`.
    let bob: CGFloat

    /// True while the piece stands on one of the three squares directly north,
    /// where a fully opaque island would cover it.
    let isFaded: Bool

    var body: some View {
        PixelSprite(id: .nexys) {
            placeholder
        }
        // Three cells wide and tall, centred on its own square.
        .frame(width: tileSize * 3, height: tileSize * 3)
        .offset(y: -GameRules.nexysRaise * scale + bob)
        .opacity(isFaded ? GameRules.nexysFadedOpacity : 1)
        .animation(.easeInOut(duration: 0.2), value: isFaded)
        .allowsHitTesting(false)
    }

    /// Stand-in while the sheet is missing: the old carved-slab drawing, sized
    /// to the middle cell only.
    private var placeholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: tileSize * 0.12)
                .fill(Palette.nexysFace)
                .overlay(
                    RoundedRectangle(cornerRadius: tileSize * 0.12)
                        .strokeBorder(Palette.nexysEdge, lineWidth: max(1, tileSize * 0.06))
                )
                .frame(width: tileSize, height: tileSize)
                .shadow(color: Palette.nexysEdge.opacity(0.7), radius: tileSize * 0.14)
        }
    }
}
