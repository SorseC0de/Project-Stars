//
//  ShopBarView.swift
//  Project Stars
//
//  Capricorn's purse, laid out along the bottom of the board.
//

import SwiftUI

/// The strip Capricorn spends a banked Pentacle from.
///
/// ## Why a strip and not a page
///
/// Every other question the game asks — pick a square, pick a sign — is asked
/// *about* the board, so the board stays visible and the question sits on top of
/// it. Cosmic Cash-in is the same kind of question: what is worth buying depends
/// entirely on how the ground looks right now, and a shop that covered the board
/// would be asking the player to decide with their eyes shut.
///
/// So it is a hotbar. It lands in the letterbox below the grid, where the
/// Pentacle banner already appears, and it is the width of the board and no
/// taller than it has to be.
///
/// ## Why the coins are flat
///
/// The board is pixel art; the controls are not, and never have been. Down here
/// a Pentacle is a cartoon disc with its glyph on it — legible at thumb size,
/// instantly countable, and not competing with the sprite work above it. The
/// gold coin proper is a thing you find on the board, not a thing you shop from.
struct ShopBarView: View {

    /// Everything banked, oldest first.
    let purse: [PickupID]

    /// The sign's accent, for the strip's own edge.
    let accent: Color

    /// True while the shop is open and a coin can actually be bought.
    ///
    /// The belt is on screen at all times so the player can see what they are
    /// carrying; it only becomes a *control* when the Zodiaction has been
    /// popped and paid for.
    var isLive: Bool = true

    let onBuy: (PickupID) -> Void

    /// What is being pressed, so the coin can dip under the finger.
    @State private var pressed: PickupID?

    var body: some View {
        VStack(spacing: Style.captionGap) {
            Text(isLive ? "COSMIC CASH-IN" : "PURSE")
                .font(.system(size: Style.captionSize, weight: .heavy, design: .rounded))
                .tracking(Style.captionTracking)
                .foregroundStyle(Palette.pentacle)

            // Quantity is part of the purse: two Tears banked are two Tears to
            // spend, so they are two slots, not one slot with a badge. A hotbar
            // counts by taking up room.
            HStack(spacing: Style.slotGap) {
                ForEach(Array(purse.enumerated()), id: \.offset) { index, id in
                    slot(id: id, index: index)
                }
            }
        }
        .padding(.horizontal, Style.barInset)
        .padding(.vertical, Style.barPadding)
        .background {
            RoundedRectangle(cornerRadius: Style.barCorner)
                .fill(Palette.warmBlack.opacity(Style.barOpacity))
                .overlay {
                    RoundedRectangle(cornerRadius: Style.barCorner)
                        .strokeBorder(accent.opacity(Style.barEdgeOpacity),
                                      lineWidth: Style.barEdge)
                }
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    /// One coin in the bar.
    private func slot(id: PickupID, index: Int) -> some View {
        let effect = PickupCatalog.effect(for: id)
        let isDown = pressed == id

        return ZStack {
            // Rim first, face over it and lifted — the same flat two-plane
            // shading the buttons use, so the strip belongs to the controls
            // rather than to the board.
            Circle()
                .fill(Palette.pentacleEdge)
                .offset(y: Style.coinDepth)

            Circle()
                .fill(Palette.pentacle)
                .overlay {
                    Circle()
                        .fill(Palette.pentacle.celHighlight)
                        .padding(Style.coinHighlightInset)
                        .mask(alignment: .top) {
                            Rectangle().frame(maxHeight: Style.coinHighlightHeight)
                        }
                }
                .offset(y: isDown ? Style.coinDepth : 0)

            Text(effect.glyph)
                .font(.system(size: Style.glyphSize))
                .offset(y: isDown ? Style.coinDepth : 0)
        }
        .frame(width: Style.coinSize, height: Style.coinSize + Style.coinDepth)
        .animation(.easeOut(duration: 0.08), value: isDown)
        .opacity(isLive ? 1 : Style.restingOpacity)
        .contentShape(Circle())
        .onTapGesture { if isLive { onBuy(id) } }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in pressed = id }
                .onEnded { _ in pressed = nil }
        )
        .accessibilityLabel(Text(effect.displayName))
    }

    // MARK: - Style

    private enum Style {
        static let captionSize: CGFloat = 10
        static let captionTracking: CGFloat = 3
        static let captionGap: CGFloat = 5

        static let coinSize: CGFloat = 34
        static let coinDepth: CGFloat = 3
        static let coinHighlightInset: CGFloat = 3
        static let coinHighlightHeight: CGFloat = 9
        static let glyphSize: CGFloat = 17
        static let slotGap: CGFloat = 6

        static let barInset: CGFloat = 12
        static let barPadding: CGFloat = 8
        static let barCorner: CGFloat = 12
        static let barEdge: CGFloat = 2
        static let barOpacity: Double = 0.82
        static let barEdgeOpacity: Double = 0.6

        /// How the belt sits when it is only being read, not spent.
        static let restingOpacity: Double = 0.72
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Palette.background
        ShopBarView(
            purse: [.restoreTile, .restoreTile, .astralBlaze, .polaris],
            accent: Zodiac.capricorn.definition.accentColor,
            onBuy: { _ in }
        )
    }
    .ignoresSafeArea()
}
