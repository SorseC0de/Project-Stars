//
//  SwipeInputView.swift
//  Project Stars
//
//  Control scheme 1: swipe anywhere in the lower square to move.
//

import SwiftUI

/// A transparent surface that turns drags into movement intents.
///
/// This is designed to sit **behind** the panel's content as a sibling, not to
/// wrap it, and that is deliberate. A `DragGesture` attached to an *ancestor* of
/// a `Button` competes with the button's own press gesture and swallows its
/// taps — `simultaneousGesture` does not help — which silently broke the
/// super's fire button. Layering the surface behind the content instead means
/// the gesture is never an ancestor of a control, so controls behave normally
/// and the surface collects everything else.
///
/// The trade-off: content drawn on top must opt *out* of hit testing wherever
/// it is purely decorative, or it absorbs drags that should reach this surface.
/// `ControlPanelView` does that with `.allowsHitTesting(false)`.
struct SwipeInputSurface: View {

    /// When false the gesture still tracks — so the direction hint stays
    /// responsive — but never commits a move.
    let isEnabled: Bool

    /// Where the current drag points, or `nil` when there is no drag or it is
    /// still under the preview threshold. Owned by the panel so the on-screen
    /// hint can react while the finger is still down.
    @Binding var liveDirection: SwipeDirection?

    /// Called once, on release, with the resolved direction.
    let onCommit: (SwipeDirection, Int) -> Void

    /// Reports the drag in progress so the cursor can preview it.
    let onPreview: (SwipeDirection?, Int) -> Void

    /// Called on a double-tap anywhere in the zone. Fires the Zodiaction.
    ///
    /// - Note: There *was* a long-press trigger here too, while the real input
    ///   was undesigned. It had to go: holding still part-way through a drag let
    ///   the long press succeed, which cancelled the drag — and a cancelled drag
    ///   still delivers `onEnded`, so the move committed under the player's
    ///   finger before they released. A double-tap cannot be mistaken for a
    ///   drag, so it is safe to keep.
    let onZodiaction: () -> Void

    /// Called on a single tap. Steps forward, the shortest move available.
    ///
    /// The common case by a distance: most turns are one square the way you are
    /// already looking, and making the player drag for every one of them is a
    /// lot of thumb for no decision. Aiming still needs the drag.
    let onStepForward: () -> Void

    var body: some View {
        Color.clear
            // Makes the whole area draggable despite being fully transparent.
            .contentShape(Rectangle())
            .gesture(dragGesture)
            // Both gestures live on the *same* view, which is the only
            // arrangement SwiftUI arbitrates cleanly here: a drag needs
            // `minimumDistance` of travel and a double-tap needs two taps, so
            // neither can be mistaken for the other. Putting the Zodiaction on a
            // separate tappable control instead does not work — see the note in
            // `ZodiactionMeterView`.
            .simultaneousGesture(
                TapGesture(count: 2).onEnded { onZodiaction() }
            )
            // After the double-tap, so a second tap is never eaten by this one.
            // SwiftUI waits out the double-tap window before delivering it.
            .simultaneousGesture(
                TapGesture(count: 1).onEnded { if isEnabled { onStepForward() } }
            )
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                // Preview uses a smaller threshold than the commit so the hint
                // appears early in the gesture.
                let direction = SwipeDirection.from(
                    translation: value.translation,
                    minimumDistance: GameRules.minimumSwipeDistance * 0.5
                )
                liveDirection = direction
                // Distance is part of the aim for signs that offer several, so
                // it has to be previewed, not just committed.
                onPreview(direction, SwipeDirection.reach(for: value.translation))
            }
            .onEnded { value in
                liveDirection = nil
                onPreview(nil, 0)
                guard isEnabled,
                      let direction = SwipeDirection.from(translation: value.translation)
                else { return }
                onCommit(direction, SwipeDirection.reach(for: value.translation))
            }
    }
}
