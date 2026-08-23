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

    /// The element a Polarity Prong standing at this pole is made of.
    ///
    /// North is air and south is earth — the sky above, the ground below — and
    /// the two water-and-fire sides fall out of that. Stated once here so the
    /// shard, its glow and the charge it pays all agree.
    var pullElement: ZodiacElement {
        switch self {
        case .up: .air
        case .down: .earth
        case .left: .water
        case .right: .fire
        default: .air
        }
    }

    /// The four in between.
    static let diagonals: [SwipeDirection] = [.upLeft, .upRight, .downLeft, .downRight]

    /// True for the four the whole game is built around.
    var isCardinal: Bool { Self.cardinals.contains(self) }

    /// The board offset a single step in this direction corresponds to.
    /// Which way the piece ends up looking after moving `self` while facing
    /// `current`.
    ///
    /// **Four drawings, eight directions.** A diagonal keeps the facing you
    /// already had when it is one of the two ways that diagonal goes — walk
    /// south-west facing south and you are still facing south. When it is not,
    /// the facing you had points backwards along one axis, so the answer is the
    /// diagonal's other half: facing west and moving north-east leaves you
    /// facing north, not east.
    ///
    /// A cardinal is simply itself. This is how a game with four-way art has
    /// always handled eight-way movement, and it is a fact about facing rather
    /// than about drawing, which is why it lives here and not in `PieceView`.
    func facing(from current: SwipeDirection) -> SwipeDirection {
        guard let halves else { return self }
        if current == halves.vertical || current == halves.horizontal { return current }
        // Turning away from one axis leaves the other one to face along.
        return current == halves.vertical.opposite ? halves.horizontal : halves.vertical
    }

    /// A diagonal's two cardinal halves, or `nil` when this is already one.
    private var halves: (vertical: SwipeDirection, horizontal: SwipeDirection)? {
        switch self {
        case .upLeft: (.up, .left)
        case .upRight: (.up, .right)
        case .downLeft: (.down, .left)
        case .downRight: (.down, .right)
        default: nil
        }
    }

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
