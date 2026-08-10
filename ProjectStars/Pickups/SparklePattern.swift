//
//  SparklePattern.swift
//  Project Stars
//
//  The shapes a sparkle set can take on the board.
//

import Foundation

/// The arrangement of the five sparkling tiles that telegraph a pickup.
///
/// Exactly one pickup hides somewhere in the set, so the shape is the player's
/// only information about where it might be — a tight `plus` narrows the search
/// to one neighbourhood, while `scattered` (the rare one) could be anywhere.
enum SparklePattern: String, CaseIterable, Codable, Identifiable {
    /// Centre tile plus its four orthogonal neighbours.
    case plus

    /// Centre tile plus its four diagonal neighbours.
    case cross

    /// Five unrelated tiles anywhere on the board. Rarest.
    case scattered

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .plus: "Plus"
        case .cross: "Cross"
        case .scattered: "Scattered"
        }
    }

    /// Compact symbol for the info panel.
    var symbol: String {
        switch self {
        case .plus: "+"
        case .cross: "×"
        case .scattered: "∴"
        }
    }

    /// Offsets from the centre tile, for the two shaped patterns.
    /// `scattered` has no fixed geometry and returns `nil`.
    var offsetsFromCentre: [GridOffset]? {
        switch self {
        case .plus: [GridOffset(0, 0)] + GridOffset.cardinals
        case .cross: [GridOffset(0, 0)] + GridOffset.diagonals
        case .scattered: nil
        }
    }

    /// Weight table used when rolling for the next pattern.
    static var weightedChoices: [(value: SparklePattern, weight: Int)] {
        SparklePattern.allCases.map { ($0, GameRules.sparklePatternWeights[$0] ?? 0) }
    }
}
