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

    /// When the current drag began, or `nil` when nothing is held.
    @State private var heldSince: Date?

    /// Ticks while a drag is held, so the reach can grow without the finger
    /// having to move.
    private let pulse = Timer.publish(
        every: 1 / 30, on: .main, in: .common
    ).autoconnect()

    var body: some View {
        Color.clear
            // Makes the whole area draggable despite being fully transparent.
            .contentShape(Rectangle())
            .gesture(dragGesture)
            .onReceive(pulse) { _ in
                // Held still, the reach still climbs. Without this the preview
                // only updated when the finger moved, so a player holding
                // perfectly still — which is what you do while waiting for a
                // longer move — saw nothing happen.
                guard let held = heldSince, let direction = liveDirection else { return }
                onPreview(direction, Self.reach(heldFor: Date().timeIntervalSince(held)))
            }
    }

    /// One gesture decides everything.
    ///
    /// ## Direction from the drag, distance from the *hold*
    ///
    /// Reach used to come from how far you dragged, which is the wrong axis on a
    /// surface this short. Sagittarius' three-square Vault wanted a hundred and
    /// eighty points of travel — further than the panel is tall — so the
    /// archer's longest move was not merely hard to ask for, it could not be
    /// asked for at all. Every sign with a choice of distance had the same
    /// problem in milder form: aiming and reaching fought over the same finger.
    ///
    /// Holding separates them. The drag says *where*, the hold says *how far*,
    /// and neither interferes with the other — which is also how the arrow
    /// buttons already work, so the panel now has one idiom instead of two.
    ///
    /// ## Why the tap survives
    ///
    /// A drag that never showed a direction is a tap: step forward. That is
    /// unchanged, and it is why there is one gesture here rather than two with
    /// thresholds that have to be kept in agreement.
    private var dragGesture: some Gesture {
        // Zero, because this gesture is the tap as well. The surface sits
        // *behind* the panel's content as a sibling, so it only ever sees
        // touches that missed a control.
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if heldSince == nil { heldSince = Date() }

                let direction = SwipeDirection.from(
                    translation: value.translation,
                    minimumDistance: GameRules.minimumSwipeDistance * 0.5,
                    includingDiagonals: includingDiagonals
                )
                liveDirection = direction

                let held = heldSince.map { Date().timeIntervalSince($0) } ?? 0
                onPreview(direction, Self.reach(heldFor: held))
            }
            .onEnded { value in
                // Read before they are cleared: this is the arrow the player was
                // looking at, and the reach they had waited for.
                let aimed = liveDirection
                let held = heldSince.map { Date().timeIntervalSince($0) } ?? 0

                liveDirection = nil
                heldSince = nil
                onPreview(nil, 0)
                guard isEnabled else { return }

                if let aimed {
                    onCommit(aimed, Self.reach(heldFor: held))
                } else {
                    // Never showed a direction, so it was a tap: step the way
                    // the piece is already looking.
                    onStepForward()
                }
            }
    }

    /// How many options past the shortest a hold of this length is asking for.
    ///
    /// The first stretch is dead on purpose — an ordinary step is a quick flick,
    /// and every one of those would otherwise pick up a longer move on the way
    /// past.
    static func reach(heldFor seconds: TimeInterval) -> Int {
        let past = seconds - GameRules.swipeReachDelay
        guard past > 0 else { return 0 }
        return Int(past / GameRules.swipeReachHold) + 1
    }
}
