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

    /// What the run looks like, for summaries that vary — see
    /// `PickupEffect.summary(in:)`.
    let context: PickupSummaryContext


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

    /// What the player has asked about but not yet bought.
    ///
    /// ## Why buying is two taps
    ///
    /// Because a coin is a glyph on a disc, and a glyph is a reminder of an
    /// effect rather than a description of one. A tester could not tell what
    /// they were purchasing until after they had purchased it, which for a
    /// resource this sign spends its whole run accumulating is the worst
    /// possible moment to find out.
    ///
    /// The first tap asks, the second buys. It costs one tap in the only place
    /// in the game where the player is spending something irreversible, and it
    /// puts the coin's own words on screen before the decision instead of after
    /// it.
    @State private var asked: PickupID?

    var body: some View {
        VStack(spacing: Style.captionGap) {
            if let asked, isLive {
                description(of: asked)
            } else {
                Text(isLive ? "COSMIC CASH-IN" : "PENTACLES")
                    .font(.system(size: Style.captionSize, weight: .heavy, design: .rounded))
                    .tracking(Style.captionTracking)
                    .foregroundStyle(Palette.pentacle)
            }

            // Stacked, the way a hotbar is.
            //
            // Two Tears are one slot reading two, not two slots. The purse has
            // no ceiling — see `GameEngine.resolvePickupCollection` — so a run
            // of the same coin would otherwise march the belt off both edges of
            // the screen, and counting six identical discs is slower than
            // reading the number six.
            HStack(spacing: Style.slotGap) {
                ForEach(stacks, id: \.id) { stack in
                    slot(id: stack.id, count: stack.count)
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
        .animation(.easeOut(duration: 0.14), value: asked)
        // A shop that closes forgets what was being considered, so re-opening it
        // does not start on last time's question.
        .onChange(of: isLive) { if !isLive { asked = nil } }
    }

    /// What the coin under consideration actually does, and what it is called.
    ///
    /// Its own words, taken from the effect, so a retuned Pentacle cannot end up
    /// described here by a string somebody forgot to change.
    private func description(of id: PickupID) -> some View {
        let effect = PickupCatalog.effect(for: id)

        return VStack(spacing: 1) {
            // A name is a name: it shrinks rather than wrapping. A second line
            // pushes the summary under it out of a strip measured for one.
            Text(effect.displayName.uppercased())
                .font(.system(size: Style.captionSize, weight: .heavy, design: .rounded))
                .tracking(Style.captionTracking)
                .foregroundStyle(Palette.pentacle)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text(effect.summary(in: context))
                .font(.system(size: Style.summarySize, weight: .semibold, design: .rounded))
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(Style.summaryLines)
                .minimumScaleFactor(0.8)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// The purse grouped by kind, in the order each kind was first banked.
    ///
    /// First-banked rather than sorted, so the belt does not reshuffle itself
    /// under the player's thumb every time a coin arrives.
    private var stacks: [(id: PickupID, count: Int)] {
        var order: [PickupID] = []
        var counts: [PickupID: Int] = [:]

        for id in purse {
            if counts[id] == nil { order.append(id) }
            counts[id, default: 0] += 1
        }
        return order.map { ($0, counts[$0] ?? 0) }
    }

    /// One kind of coin in the bar, with how many are held.
    private func slot(id: PickupID, count: Int) -> some View {
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

            // Drawn icon where there is one, glyph where there is not — see
            // `PickupIconView`. No disc behind it: the coin it sits on is the
            // ground already.
            PickupIconView(
                effect: effect,
                size: Style.glyphSize,
                tint: Palette.warmBlack,
                background: nil
            )
            .offset(y: isDown ? Style.coinDepth : 0)
        }
        .overlay(alignment: .bottomTrailing) {
            // Only when there is more than one. A "1" on every slot is noise on
            // the commonest case.
            if count > 1 {
                Text("\(count)")
                    .font(.system(size: Style.countSize, weight: .heavy, design: .rounded))
                    .foregroundStyle(Palette.textPrimary)
                    .padding(.horizontal, 3)
                    .background(Capsule().fill(Palette.warmBlack))
                    .offset(x: 2, y: 2)
            }
        }
        .frame(width: Style.coinSize, height: Style.coinSize + Style.coinDepth)
        .animation(.easeOut(duration: 0.08), value: isDown)
        .opacity(isLive ? 1 : Style.restingOpacity)
        .overlay {
            // A ring on the one being asked about, so the second tap has an
            // obvious target and the description has an obvious owner.
            if asked == id, isLive {
                Circle()
                    .strokeBorder(Palette.textPrimary, lineWidth: Style.askedRing)
                    .padding(-Style.askedRingInset)
                    .offset(y: isDown ? Style.coinDepth : 0)
            }
        }
        .contentShape(Circle())
        // Ask, then buy. See `asked`.
        .onTapGesture {
            guard isLive else { return }
            if asked == id {
                onBuy(id)
                asked = nil
            } else {
                asked = id
            }
        }
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

        /// The coin's own words, under its name. Two lines is every summary in
        /// the game at this width; a third would push the strip over the board.
        static let summarySize: CGFloat = 9
        static let summaryLines = 2

        /// The ring on the coin being asked about.
        static let askedRing: CGFloat = 2
        static let askedRingInset: CGFloat = 3
        static let captionTracking: CGFloat = 3
        static let captionGap: CGFloat = 5

        static let coinSize: CGFloat = 34
        static let coinDepth: CGFloat = 3
        static let coinHighlightInset: CGFloat = 3
        static let coinHighlightHeight: CGFloat = 9
        static let glyphSize: CGFloat = 17
        static let countSize: CGFloat = 10
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
            context: PickupSummaryContext(
                zodiac: .capricorn,
                plane: .terra,
                nexysPlane: .astra,
                signState: SignState()
            ),
            purse: [.restoreTile, .restoreTile, .restoreTile, .astralBlaze, .polaris],
            accent: Zodiac.capricorn.definition.accentColor,
            onBuy: { _ in }
        )
    }
    .ignoresSafeArea()
}
