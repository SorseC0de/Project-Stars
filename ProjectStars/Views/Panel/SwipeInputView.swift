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

    /// Whether to cut the circle into eight sectors instead of four.
    ///
    /// Only true for a piece that can actually go diagonally. For everyone else
    /// eight sectors would turn a perfectly clear swipe that happened to run at
    /// 40° into a move that does not exist.
    var includingDiagonals: Bool = false

    /// Where the current drag points, or `nil` when there is no drag or it is
    /// still under the preview threshold. Owned by the panel so the on-screen
    /// hint can react while the finger is still down.
    @Binding var liveDirection: SwipeDirection?

    /// Called once, on release, with the resolved direction.
    let onCommit: (SwipeDirection, Int) -> Void

    /// Reports the drag in progress so the cursor can preview it.
    let onPreview: (SwipeDirection?, Int) -> Void

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
            // A single tap and a drag, and nothing else.
            //
            // The Zodiaction used to be a double-tap here, which made the two
            // taps fight: SwiftUI has to wait out the double-tap window before
            // it can deliver a single one, so stepping forward was always late
            // *and* the double-tap was unreliable because a drag could start
            // between the two. Now that the Zodiaction has a button of its own
            // there is nothing to arbitrate, and the step is instant.
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
                    minimumDistance: GameRules.minimumSwipeDistance * 0.5,
                    includingDiagonals: includingDiagonals
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
                      let direction = SwipeDirection.from(
                          translation: value.translation,
                          includingDiagonals: includingDiagonals
                      )
                else { return }
                onCommit(direction, SwipeDirection.reach(for: value.translation))
            }
    }
}
