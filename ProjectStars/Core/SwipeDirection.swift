//
//  SwipeDirection.swift
//  Project Stars
//
//  Turning a raw drag gesture into a movement intent.
//

import CoreGraphics
import Foundation
import SwiftUI

/// The eight input directions the game accepts.
///
/// ## Why four of them are second-class
///
/// Almost everything moves on the cardinals. Virgo does not — she steps like a
/// queen, one square in any of the eight — and rather than give her a parallel
/// vocabulary, the diagonals were added here alongside the rest.
///
/// The cost of that is that `allCases` is now eight long, and most of the places
/// that iterate directions mean *the four buttons on the pad*. Those use
/// `cardinals`. Anything that means "every way a piece could conceivably go" —
/// the legal-destination map, the joystick — uses `allCases`.
///
/// A pattern that has not opted in is unaffected: `Applicability.any` means the
/// four cardinals, exactly as it always did, and a swipe resolved to a diagonal
/// simply finds no option there.
enum SwipeDirection: String, CaseIterable, Identifiable {
    case up
    case down
    case left
    case right

    case upLeft
    case upRight
    case downLeft
    case downRight

    var id: String { rawValue }

    /// The four directions everything can move in, and the four the pad has
    /// buttons for.
    static let cardinals: [SwipeDirection] = [.up, .down, .left, .right]

    /// The four in between.
    static let diagonals: [SwipeDirection] = [.upLeft, .upRight, .downLeft, .downRight]

    /// True for the four the whole game is built around.
    var isCardinal: Bool { Self.cardinals.contains(self) }

    /// The board offset a single step in this direction corresponds to.
    var unitOffset: GridOffset {
        switch self {
        case .up: .up
        case .down: .down
        case .left: .left
        case .right: .right
        case .upLeft: GridOffset(-1, -1)
        case .upRight: GridOffset(1, -1)
        case .downLeft: GridOffset(-1, 1)
        case .downRight: GridOffset(1, 1)
        }
    }

    /// The keys that mean this direction: an arrow and its WASD twin.
    ///
    /// Both, rather than a preference between them — a keyboard player reaches
    /// for whichever their hands are already near, and there is nothing else
    /// bound that either could collide with.
    /// The diagonals take the four keys around WASD, roguelike fashion.
    ///
    /// Not two keys held at once. SwiftUI's `keyboardShortcut` reports a chord,
    /// not a set of keys currently down, so "W and A together" is not something
    /// this can hear — and the near-misses it *would* hear are two separate
    /// cardinal moves, which on this board is a wasted tile and sometimes a
    /// death. A key each is unambiguous.
    var keyEquivalents: [KeyEquivalent] {
        switch self {
        case .up: [.upArrow, "w"]
        case .down: [.downArrow, "s"]
        case .left: [.leftArrow, "a"]
        case .right: [.rightArrow, "d"]
        case .upLeft: ["q"]
        case .upRight: ["e"]
        case .downLeft: ["z"]
        case .downRight: ["c"]
        }
    }

    /// Arrow glyph, used by the placeholder UI and the debug overlay.
    var arrow: String {
        switch self {
        case .up: "↑"
        case .down: "↓"
        case .left: "←"
        case .right: "→"
        case .upLeft: "↖"
        case .upRight: "↗"
        case .downLeft: "↙"
        case .downRight: "↘"
        }
    }

    /// Directly behind.
    var opposite: SwipeDirection {
        switch self {
        case .up: .down
        case .down: .up
        case .left: .right
        case .right: .left
        case .upLeft: .downRight
        case .downRight: .upLeft
        case .upRight: .downLeft
        case .downLeft: .upRight
        }
    }

    /// The two directions at right angles to this one.
    ///
    /// Libra's Equitable Impact throws its force into these rather than into the
    /// square it lands on.
    var perpendicular: [SwipeDirection] {
        switch self {
        case .up, .down: [.left, .right]
        case .left, .right: [.up, .down]
        // A diagonal's right angles are the other two diagonals, which keeps
        // "sideways" meaning the same thing however the piece is standing.
        case .upLeft, .downRight: [.upRight, .downLeft]
        case .upRight, .downLeft: [.upLeft, .downRight]
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
    /// - Parameter includingDiagonals: When true the circle is cut into eight
    ///   rather than four, so a drag at 45° means the corner instead of being
    ///   rounded to an axis. Passed by the panel, which asks the piece whether it
    ///   has anywhere diagonal to go — a sign that cannot move that way should
    ///   not have its sloppy swipes rejected for aiming between two buttons.
    static func from(
        translation: CGSize,
        minimumDistance: CGFloat = GameRules.minimumSwipeDistance,
        includingDiagonals: Bool = false
    ) -> SwipeDirection? {
        let dx = translation.width
        let dy = translation.height
        guard hypot(dx, dy) >= minimumDistance else { return nil }

        if includingDiagonals {
            // Eight equal sectors, each 45° wide, measured from due right.
            // Screen y grows downward, so the angle is negated to make the
            // sectors read anticlockwise from east in ordinary compass terms.
            let sector = Int((atan2(-dy, dx) / .pi * 4).rounded()) &+ 8
            return switch sector % 8 {
            case 0: .right
            case 1: .upRight
            case 2: .up
            case 3: .upLeft
            case 4: .left
            case 5: .downLeft
            case 6: .down
            default: .downRight
            }
        }

        // Dominant axis wins; ties (a perfect 45°) resolve to horizontal.
        if abs(dx) >= abs(dy) {
            return dx < 0 ? .left : .right
        } else {
            return dy < 0 ? .up : .down
        }
    }
}
