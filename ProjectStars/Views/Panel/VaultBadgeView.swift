//
//  VaultBadgeView.swift
//  Project Stars
//
//  Sagittarius' vault: whether it is ready, and a button to take it.
//

import SwiftUI

/// The archer's vault, as a lamp you can press.
///
/// ## Why the restriction needs a light
///
/// Vulcan Vault cannot be taken twice in a row, and until now the only way to
/// discover that was to aim a long leap and watch nothing happen. A cooldown the
/// player cannot see is not a cost, it is a trap — they read it as the input
/// being dropped, which is worse than the rule itself.
///
/// ## Why it is also a button
///
/// The same reasoning as the Zodiaction's recall arrow: something already on
/// screen to report a state may as well be the control for it. Pressing takes
/// the full-length vault in whatever direction the piece is currently facing,
/// which is the move this badge is about — so the light and the action are the
/// same object, and there is nothing to learn beyond "it is lit, I can jump".
///
/// Grey when it is not available, and unpressable. Not hidden: a control that
/// vanishes takes its own explanation with it, and the point is to say *why*
/// the leap is refused.
struct VaultBadgeView: View {

    let session: GameSession

    var body: some View {
        let ready = session.canVault

        Image("VulcanVault")
            .resizable()
            .renderingMode(.template)
            .aspectRatio(contentMode: .fit)
            .frame(width: Style.size, height: Style.size)
            .foregroundStyle(ready ? Palette.red : Palette.gray)
            .padding(Style.padding)
            .background {
                Circle()
                    .fill(Palette.warmBlack)
                    .overlay {
                        Circle().strokeBorder(
                            ready ? Palette.red : Palette.darkGray,
                            lineWidth: Style.edge
                        )
                    }
            }
            // Lit means ready, and the bloom is static rather than pulsing — the
            // archer's other button already breathes, and two things breathing
            // at different rates in the same corner is noise.
            .shadow(
                color: ready ? Palette.red.opacity(Style.glow) : .clear,
                radius: Style.glowRadius
            )
            .saturation(ready ? 1 : 0)
            .contentShape(Circle())
            .onTapGesture { session.vaultForward() }
            .animation(.easeOut(duration: 0.18), value: ready)
            .accessibilityLabel(Text("Vulcan Vault"))
    }

    private enum Style {
        static let size: CGFloat = 26
        static let padding: CGFloat = 5
        static let edge: CGFloat = 1.5
        static let glow: Double = 0.85
        static let glowRadius: CGFloat = 5
    }
}
