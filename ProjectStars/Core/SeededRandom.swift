//
//  SeededRandom.swift
//  Project Stars
//
//  Deterministic randomness so runs can be replayed and tested.
//

import Foundation

/// A small, fast, seedable PRNG (SplitMix64).
///
/// The engine owns one of these instead of reaching for `Int.random(in:)`, which
/// buys three things: identical runs from identical seeds, reproducible bug
/// reports, and the option of a daily-challenge mode later.
struct SeededRandom: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed
    }

    /// Seeds from the clock — the normal case for a fresh run.
    init() {
        self.init(seed: UInt64(Date().timeIntervalSince1970 * 1000))
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

// MARK: - Collection helpers

extension Array {
    /// A random element using the engine's generator. Returns `nil` when empty.
    func randomElement(using generator: inout SeededRandom) -> Element? {
        guard !isEmpty else { return nil }
        let index = Int(generator.next() % UInt64(count))
        return self[index]
    }

    /// A shuffled copy using the engine's generator.
    func shuffled(using generator: inout SeededRandom) -> [Element] {
        var copy = self
        guard copy.count > 1 else { return copy }
        for i in stride(from: copy.count - 1, to: 0, by: -1) {
            let j = Int(generator.next() % UInt64(i + 1))
            copy.swapAt(i, j)
        }
        return copy
    }
}

// MARK: - Weighted choice

extension SeededRandom {
    /// Picks one element from `choices` in proportion to its weight.
    ///
    /// Entries with a weight of zero or less are skipped. Returns `nil` when no
    /// entry has a positive weight.
    mutating func pick<T>(weighted choices: [(value: T, weight: Int)]) -> T? {
        let usable = choices.filter { $0.weight > 0 }
        let total = usable.reduce(0) { $0 + $1.weight }
        guard total > 0 else { return nil }

        var roll = Int(next() % UInt64(total))
        for choice in usable {
            roll -= choice.weight
            if roll < 0 { return choice.value }
        }
        return usable.last?.value
    }
}
