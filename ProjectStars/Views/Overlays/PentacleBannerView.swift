//
//  PentacleBannerView.swift
//  Project Stars
//
//  What you just picked up, every time — not only the first.
//

import SwiftUI

/// Names the Pentacle that was just opened.
///
/// The first-encounter splash (`PentacleIntroView`) teaches an effect once and
/// then never appears again, which left every later pickup silent — the coin is
/// deliberately anonymous *before* it is opened, but after opening the player
/// should always know what they got.
///
/// Unlike the splash this never pauses the game: it is a readout, not an
/// interruption. It stays up until the next move is committed rather than fading
/// on a timer, so it is still there whenever the player looks up.
struct PentacleBannerView: View {

    let id: PickupID

    var body: some View {
        let effect = PickupCatalog.effect(for: id)

        HStack(spacing: 8) {
            Text(effect.glyph.monochromeGlyph)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Palette.background)
                .frame(width: 24, height: 24)
                .background(Circle().fill(tint(for: effect)))

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 5) {
                    Text(effect.displayName.uppercased())
                        .font(.system(size: 11, weight: .heavy, design: .monospaced))
                        .foregroundStyle(Palette.textPrimary)

                    Text(effect.rarity.displayName.uppercased())
                        .font(.system(size: 7, weight: .heavy, design: .monospaced))
                        .foregroundStyle(tint(for: effect))
                }

                Text(effect.summary)
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(Palette.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Palette.panel.opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(tint(for: effect).opacity(0.7), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.5), radius: 6, y: 2)
        .transition(.move(edge: .top).combined(with: .opacity))
        .allowsHitTesting(false)
    }

    /// Rarity reads as colour, so the tier registers before the words do.
    private func tint(for effect: any PickupEffect) -> Color {
        switch effect.rarity {
        case .common: Palette.textSecondary
        case .uncommon: Palette.pickupUncommon
        case .rare: Palette.pickupRare
        case .legendary: Palette.pickupLegendary
        }
    }
}
