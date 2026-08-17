//
//  TileHealth.swift
//  Project Stars
//
//  The four-step wear cycle every tile goes through.
//

import Foundation

/// How worn a tile is.
///
/// Landing on a tile normally advances it one step along
/// `healthy -> cracked -> badlyCracked -> hole`. A hole is terminal: it can only
/// be undone by a healing effect.
enum TileHealth: Int, CaseIterable, Codable, Comparable {
    case healthy = 0
    case cracked = 1
    case badlyCracked = 2
    case hole = 3

    static func < (lhs: TileHealth, rhs: TileHealth) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var displayName: String {
        switch self {
        case .healthy: "Healthy"
        case .cracked: "Cracked"
        case .badlyCracked: "Badly Cracked"
        case .hole: "Hole"
        }
    }

    /// True when a piece landing here falls through instead of standing on it.
    var isHole: Bool { self == .hole }

    /// The next state after taking one point of wear. A hole stays a hole.
    var damaged: TileHealth {
        TileHealth(rawValue: min(rawValue + 1, TileHealth.hole.rawValue)) ?? .hole
    }

    /// Where this ends up after `amount` points of wear.
    ///
    /// **Damage is dealt all at once and then resolved**, never one event per
    /// point. Anything standing between the source and the tile — a shield that
    /// absorbs the next hit, a passive that softens one — needs a single hit
    /// with a size, not a stream of ones it can only ever interrupt partway
    /// through. A Bastion that ate the first third of a Shakedown and let the
    /// rest land is not what nullifying a hit means.
    ///
    /// Negative repairs, so one function covers both directions and a caller
    /// that computes a signed amount does not have to branch.
    func worn(by amount: Int) -> TileHealth {
        var health = self
        if amount >= 0 {
            for _ in 0..<amount where health != .hole { health = health.damaged }
        } else {
            for _ in 0..<(-amount) where health != .healthy { health = health.healed }
        }
        return health
    }

    /// The previous state after one point of repair. Healthy stays healthy.
    var healed: TileHealth {
        TileHealth(rawValue: max(rawValue - 1, TileHealth.healthy.rawValue)) ?? .healthy
    }
}
