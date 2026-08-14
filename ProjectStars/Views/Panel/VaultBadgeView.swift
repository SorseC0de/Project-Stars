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

        // A `CelButton`, like everything else down here.
        //
        // It was a circle with a soft `shadow` bloom behind it, which is the one
        // language this panel does not speak: the controls are flat two-plane
        // shapes with a hard rim below them and no blur anywhere. A badge that
        // glowed read as belonging to the *board*, which is drawn art — and it
        // sits inches from the Zodiaction button, so the mismatch was on show.
        //
        // It is also a real button, so it should look pressable rather than
        // merely lit.
        CelButton(
            tint: ready ? Palette.red : Palette.stone,
            isEnabled: ready,
            acceptsTouch: session.acceptsInput
        ) {
            Haptics.longer()
            session.vaultForward()
        } label: {
            Image("Signs/VulcanVault")
                .resizable()
                .renderingMode(.template)
                .aspectRatio(contentMode: .fit)
                // The panel's own background colour, so the mark reads as cut
                // *out* of the button rather than printed on it — the same way
                // the bow on the recall button does. White made it a label, and
                // the sign's accent made it a second bright thing competing with
                // the button it sits inside.
                .foregroundStyle(ready ? Palette.panel : Palette.darkGray)
                .padding(Style.padding)
        }
        .frame(width: Style.size, height: Style.size)
        .animation(.easeOut(duration: 0.18), value: ready)
        .accessibilityLabel(Text("Vulcan Vault"))
    }

    private enum Style {
        static let size: CGFloat = 42
        static let padding: CGFloat = 5
        static let edge: CGFloat = 1.5
        static let glow: Double = 0.85
        static let glowRadius: CGFloat = 5
    }
}
