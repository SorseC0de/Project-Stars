//
//  Plane.swift
//  Project Stars
//
//  The two stacked playfields.
//

import Foundation

/// The two boards the game is played on.
///
/// `astra` sits conceptually *above* `terra`. Every round starts on Astra;
/// dropping through a hole moves the piece down to the matching square on
/// Terra. There is no way back up by falling — Terra is the last floor.
enum Plane: String, CaseIterable, Codable, Identifiable {
    case astra
    case terra

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .astra: "Astra"
        case .terra: "Terra"
        }
    }

    /// The plane a piece arrives on after falling through a hole here,
    /// or `nil` when there is nothing below (falling here ends the run).
    var planeBelow: Plane? {
        switch self {
        case .astra: .terra
        case .terra: nil
        }
    }

    /// The other plane. Unlike `planeBelow` this is always defined — used by
    /// anything that moves *between* planes rather than *down*, such as the
    /// Nexys island.
    var opposite: Plane {
        switch self {
        case .astra: .terra
        case .terra: .astra
        }
    }
}
