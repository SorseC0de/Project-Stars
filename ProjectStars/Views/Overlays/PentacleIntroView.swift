//
//  PentacleIntroView.swift
//  Project Stars
//
//  The strip shown the first time a given Pentacle effect is opened.
//

import SwiftUI

/// Explains a Pentacle effect the player has never opened before.
///
/// Shown **once ever** per effect, and it stops the game while it is up: the
/// move that opened the coin is paused mid-replay and only resumes when the
/// player dismisses this.
///
/// Deliberately a **strip across the screen, not a takeover**. The board stays
/// visible and merely dimmed behind it, because the explanation is about a
/// position the player is still looking at — where the coin was, what the move
/// did, what the effect is about to change. Covering the board would throw that
/// away.
///
/// - TODO: The strip is the natural home for a wide PNG banner once art exists.
///   Its frame is already full-width and fixed-height for exactly that; drop a
///   `PixelSprite(id: .pentacleFace(id))` in behind the text.
struct PentacleIntroView: View {

    /// What the run looks like, for summaries that vary — see
    /// `PickupEffect.summary(in:)`.
    let context: PickupSummaryContext


    let id: PickupID
    let accent: Color
    let onDismiss: () -> Void

    @State private var hasAppeared = false

    var body: some View {
        let effect = PickupCatalog.effect(for: id)

        ZStack {
            // Dim, not opaque: the board reads through it.
            Palette.background.opacity(0.55)
                .ignoresSafeArea()

            strip(effect: effect)
        }
        // The whole area is tappable so the player never hunts for a control —
        // which also keeps this off the swipe zone's gesture problem.
        // No tap to dismiss.
        //
        // The upper square is a **display**, not a control surface — see the
        // note on `GameScreen`. This splash is dismissed by reaching for the
        // controls: a swipe, an arrow key, a direction button. Reading it and
        // then playing on are the same gesture, which is one fewer than tapping
        // it away first.
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                hasAppeared = true
            }
        }
        .transition(.opacity)
    }

    /// The band itself: full width, centred vertically over the split between
    /// the board and the panel.
    private func strip(effect: any PickupEffect) -> some View {
        HStack(spacing: 14) {
            // The coin, open — here and only here does an effect show its own
            // glyph rather than the anonymous gold face.
            ZStack {
                Circle()
                    .fill(Palette.pentacle)
                    .shadow(color: Palette.pentacle.opacity(0.8), radius: 10)
                    .frame(width: 52, height: 52)

                PickupIconView(
                    effect: effect,
                    size: 26,
                    tint: Palette.background,
                    background: nil
                )
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 3) {
                Text("NEW PENTACLE")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(Palette.textSecondary)

                Text(effect.displayName.uppercased())
                    .font(.system(size: 18, weight: .heavy, design: .monospaced))
                    .tracking(1)
                    .foregroundStyle(Palette.pentacle)

                Text(effect.summary(in: context))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Tap to continue · shown once")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(Palette.textSecondary)
                    .padding(.top, 1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(
            Palette.panel
                .overlay(
                    // Gold rules top and bottom, so it reads as a banner laid
                    // over the game rather than a dialog floating above it.
                    VStack {
                        Rectangle().fill(Palette.pentacle).frame(height: 2)
                        Spacer()
                        Rectangle().fill(Palette.pentacle).frame(height: 2)
                    }
                )
        )
        .shadow(color: .black.opacity(0.6), radius: 12)
        .scaleEffect(y: hasAppeared ? 1 : 0.2, anchor: .center)
        .opacity(hasAppeared ? 1 : 0)
    }
}
