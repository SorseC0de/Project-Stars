//
//  NexysCallView.swift
//  Project Stars
//
//  Libra's elevator panel.
//

import SwiftUI

/// A pair of call buttons for the Nexys, in the manner of a lift.
///
/// ## Why a button at all
///
/// Judicator Elevator began as a thing that happened *to* Libra: stand on the
/// island and it takes you. That is not an elevator, it is a trapdoor — she
/// could not choose when to travel, could not call the island to her, and if it
/// was on the other plane she had no way down at all short of falling. Worse,
/// getting anywhere useful meant stepping off and back on, and every one of
/// those steps costs a tile.
///
/// A button is the whole ability made explicit. It is also, in fairness, what
/// the sign has been called since the start.
///
/// ## Why two lamps and not a toggle
///
/// Because the island being *here* is not the same as being *aboard*. The button
/// answers in two cases — it is elsewhere and can be called, or you are standing
/// on it and can ride — and does nothing in the third, when it is sitting on
/// your plane and you are not on it. A toggle in that state is an invitation to
/// flap the island back and forth forever, which is neither a decision nor
/// something anyone wants to watch.
///
/// So the lamp that is lit tells you which of the two you are about to get.
///
/// ## Why it lives here
///
/// Everything the player touches is in the lower square — see `GameScreen`. The
/// island is at the top of the board and this is emphatically not a reason to
/// reach up and tap it.
struct NexysCallView: View {

    let session: GameSession

    var body: some View {
        let enabled = session.canCallNexys
        let going = session.nexysCallDestination

        // Up above down, because that is what up and down mean. Side by side
        // they are two buttons; stacked they are a lift.
        //
        // Wide enough to be a panel rather than two loose discs: it sits beside
        // the Zodiaction button, which is the biggest thing on the screen, and a
        // control that small next to a control that large reads as an
        // afterthought.
        VStack(spacing: Style.gap) {
            lamp(.astra, isLit: enabled && going == .astra)
            lamp(.terra, isLit: enabled && going == .terra)
        }
        .padding(.horizontal, Style.inset)
        .padding(.vertical, Style.padding)
        .background {
            RoundedRectangle(cornerRadius: Style.corner)
                .fill(Palette.midnight)
                .overlay {
                    RoundedRectangle(cornerRadius: Style.corner)
                        .strokeBorder(Palette.nexysFace, lineWidth: Style.edge)
                }
        }
        .contentShape(RoundedRectangle(cornerRadius: Style.corner))
        .onTapGesture { session.callNexys() }
        .accessibilityLabel(Text("Call the Nexys"))
    }

    /// One lamp: an arrow in a disc, lit when that is where the island is going.
    ///
    /// Both are always drawn. A panel that hid the unavailable direction would
    /// change shape as the island moved, and a control that moves is a control
    /// you have to look at before pressing.
    private func lamp(_ plane: Plane, isLit: Bool) -> some View {
        ZStack {
            Circle()
                .fill(isLit ? Palette.planeTint(plane) : Palette.coolBlack)

            Circle()
                .strokeBorder(
                    isLit ? Palette.nexysFace : Palette.outline,
                    lineWidth: Style.lampEdge
                )

            Image(systemName: plane == .astra ? "chevron.up" : "chevron.down")
                .font(.system(size: Style.glyphSize, weight: .black))
                .foregroundStyle(isLit ? Palette.textPrimary : Palette.darkGray)
        }
        .frame(width: Style.lampSize, height: Style.lampSize)
        // Lit means *this is what the button does now*, so it breathes — the
        // same signal the Zodiaction button uses when it is ready.
        .shadow(
            color: isLit ? Palette.nexysFace.opacity(Style.glow) : .clear,
            radius: Style.glowRadius
        )
        .animation(.easeOut(duration: 0.2), value: isLit)
    }

    private enum Style {
        static let lampSize: CGFloat = 30
        static let lampEdge: CGFloat = 1.5
        static let glyphSize: CGFloat = 14
        static let gap: CGFloat = 6

        static let inset: CGFloat = 8
        static let padding: CGFloat = 6
        static let corner: CGFloat = 10
        static let edge: CGFloat = 1.5

        static let glow: Double = 0.9
        static let glowRadius: CGFloat = 6
    }
}
