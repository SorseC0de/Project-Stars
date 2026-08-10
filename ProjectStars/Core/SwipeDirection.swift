//
//  SwipeDirection.swift
//  Project Stars
//
//  Turning a raw drag gesture into a movement intent.
//

import CoreGraphics
import Foundation
import SwiftUI

/// The four input directions the game accepts.
///
/// Movement is cardinal-only, so a drag is resolved by whichever axis it
/// travelled furthest along. If diagonal-moving signs are added later, extend
/// this enum and `MovementPattern.offsets(for:)` — nothing else needs to know.
enum SwipeDirection: String, CaseIterable, Identifiable {
    case up
    case down
    case left
    case right

    var id: String { rawValue }

    /// The board offset a single step in this direction corresponds to.
    var unitOffset: GridOffset {
        switch self {
        case .up: .up
        case .down: .down
        case .left: .left
        case .right: .right
        }
    }

    /// The keys that mean this direction: an arrow and its WASD twin.
    ///
    /// Both, rather than a preference between them — a keyboard player reaches
    /// for whichever their hands are already near, and there is nothing else
    /// bound that either could collide with.
    var keyEquivalents: [KeyEquivalent] {
        switch self {
        case .up: [.upArrow, "w"]
        case .down: [.downArrow, "s"]
        case .left: [.leftArrow, "a"]
        case .right: [.rightArrow, "d"]
        }
    }

    /// Arrow glyph, used by the placeholder UI and the debug overlay.
    var arrow: String {
        switch self {
        case .up: "↑"
        case .down: "↓"
        case .left: "←"
        case .right: "→"
        }
    }

    /// Directly behind.
    var opposite: SwipeDirection {
        switch self {
        case .up: .down
        case .down: .up
        case .left: .right
        case .right: .left
        }
    }

    /// The two directions at right angles to this one.
    ///
    /// Libra's Balanced Impact throws its force into these rather than into the
    /// square it lands on.
    var perpendicular: [SwipeDirection] {
        switch self {
        case .up, .down: [.left, .right]
        case .left, .right: [.up, .down]
        }
    }

    /// How many distance-steps past the commit threshold a drag ran.
    ///
    /// This is the whole variable-distance control scheme: a short flick is
    /// reach `0` and takes the nearest option, each further
    /// `GameRules.swipeReachStep` points adds one. Patterns with a single option
    /// per direction ignore it entirely, so it costs nothing for the signs that
    /// do not use it.
    static func reach(for translation: CGSize) -> Int {
        // Measured along the dominant axis, not the diagonal: a drag that wanders
        // sideways should not quietly buy a longer move than the player aimed
        // for.
        let along = max(abs(translation.width), abs(translation.height))
        let past = along - GameRules.minimumSwipeDistance
        guard past > 0 else { return 0 }
        return Int(past / GameRules.swipeReachStep)
    }

    /// Resolves a drag translation into a direction.
    ///
    /// Returns `nil` when the drag is shorter than `minimumDistance`, so a tap
    /// or a twitch never commits a move by accident.
    static func from(
        translation: CGSize,
        minimumDistance: CGFloat = GameRules.minimumSwipeDistance
    ) -> SwipeDirection? {
        let dx = translation.width
        let dy = translation.height
        guard hypot(dx, dy) >= minimumDistance else { return nil }

        // Dominant axis wins; ties (a perfect 45°) resolve to horizontal.
        if abs(dx) >= abs(dy) {
            return dx < 0 ? .left : .right
        } else {
            return dy < 0 ? .up : .down
        }
    }
}
