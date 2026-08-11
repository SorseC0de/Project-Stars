//
//  PieceIconView.swift
//  Project Stars
//
//  A sign drawn as a square badge, for menus and readouts.
//

import SwiftUI

/// Shows a sign as an icon in a square box.
///
/// ## Why the mark and not the piece
///
/// Every sign points at the same piece sprite until twelve are drawn, so a list
/// of them was twelve identical fish. The sign's own mark is the thing that
/// actually differs, it is already flat and monochrome, and it scales to any
/// size — which a 16x32 pixel sprite does not.
///
/// It also matches the panel: the same mark identifies the sign there, so the
/// icon a player picks from is the icon they then play under.
struct PieceIconView: View {

    let zodiac: Zodiac

    /// Edge length of the box, in points.
    let size: CGFloat

    /// What colour the mark takes. Defaults to the sign's accent, which is what
    /// a list of twelve wants — each one distinct at a glance.
    var tint: Color?

    var body: some View {
        Image("Signs/\(zodiac.rawValue)")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: size * 0.78, height: size * 0.78)
            .foregroundStyle(tint ?? zodiac.definition.accentColor)
            .frame(width: size, height: size)
    }
}
