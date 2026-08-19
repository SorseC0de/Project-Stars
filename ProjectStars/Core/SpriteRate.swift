//
//  SpriteRate.swift
//  Project Stars
//
//  The frame rates pixel-art animation gets authored at.
//

import Foundation

/// How fast an animated sprite plays, in frames per second.
///
/// A struct of named presets rather than an enum, so fractional rates work and
/// so a one-off rate can be written inline without amending this file.
///
/// Frame timing comes from elapsed time rather than from counting display
/// ticks, which is what makes any rate expressible.
///
/// | Rate | Ticks per frame at 60Hz | Suits |
/// |---|---|---|
/// | `fps30` | 2 | fluid motion, closer to animation than sprite work |
/// | `fps24` | 2.5 | brisk effects; exact on a 120Hz display |
/// | `fps20` | 3 | short sharp bursts — sparks, impacts |
/// | `fps15` | 4 | quick effects that still need to read |
/// | `fps12` | 5 | the house default |
/// | `fps10` | 6 | weighty, or long loops |
/// | `fps7_5` | 8 | slower still — an eighth of the clock, and exact |
struct SpriteRate: Equatable, Hashable {

    let framesPerSecond: Double

    init(_ framesPerSecond: Double) {
        self.framesPerSecond = max(framesPerSecond, 0.01)
    }

    // MARK: Presets

    static let fps7_5 = SpriteRate(7.5)
    static let fps10 = SpriteRate(10)
    static let fps12 = SpriteRate(12)
    static let fps15 = SpriteRate(15)
    static let fps20 = SpriteRate(20)
    static let fps24 = SpriteRate(24)
    static let fps30 = SpriteRate(30)
    static let fps45 = SpriteRate(45)

    /// For the very long strips. Forty frames at 24fps is nearly two seconds;
    /// the same strip at 60 lands in two thirds of one, which is the difference
    /// between decorating a move and outlasting it.
    static let fps60 = SpriteRate(60)

    /// The presets, slowest first. For debug readouts and pickers.
    static let allCases: [SpriteRate] = [
        .fps7_5, .fps10, .fps12, .fps15, .fps20, .fps24, .fps30, .fps45, .fps60,
    ]

    // MARK: Timing

    /// Seconds each art frame is on screen.
    var frameDuration: TimeInterval { 1 / framesPerSecond }

    /// How long a sheet of `count` frames takes to play through once.
    func duration(frames count: Int) -> TimeInterval {
        frameDuration * TimeInterval(count)
    }

    /// Display ticks each art frame occupies, at the game's clock.
    var ticksPerFrame: Double {
        Double(GameRules.spriteFramesPerSecond) / framesPerSecond
    }

    /// Whether every frame gets the same number of display ticks.
    ///
    /// True for anything that divides the clock — including `fps7_5`, which is
    /// exactly an eighth of it. Only useful as a debug readout; an uneven rate
    /// is a legitimate choice, not a mistake.
    var dividesDisplayClock: Bool {
        let ticks = ticksPerFrame
        return abs(ticks - ticks.rounded()) < 0.0001
    }
}
