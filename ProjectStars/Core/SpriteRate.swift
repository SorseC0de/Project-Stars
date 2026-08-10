//
//  SpriteRate.swift
//  Project Stars
//
//  The frame rates pixel-art animation actually gets authored at.
//

import Foundation

/// How fast an animated sprite plays.
///
/// The raw value is the rate in frames per second, so these read as what they
/// are. Frame timing is computed from elapsed time rather than by counting game
/// frames, which is what lets any rate work rather than only the ones that
/// divide the display clock.
///
/// | Rate | Ticks per frame at 60Hz | Suits |
/// |---|---|---|
/// | `fps30` | 2 | fast, fluid motion — closer to animation than to sprite work |
/// | `fps25` | 2.4 ⚠︎ | brisk effects |
/// | `fps20` | 3 | short, sharp bursts — sparks, impacts |
/// | `fps15` | 4 | quick effects that still need to read |
/// | `fps12` | 5 | the house default; most things |
/// | `fps10` | 6 | slow, weighty, or long loops |
/// | `fps7` | ~8.6 ⚠︎ | deliberately stilted — drifting, brooding, ominous |
///
/// ## The two marked ⚠︎
///
/// `fps25` and `fps7` do not divide 60 evenly, so on a 60Hz display their frames
/// cannot all be held for the same number of ticks: 25 alternates 2-2-3, and 7
/// alternates 8-9. That unevenness is real and it is visible on a slow, high
/// contrast animation — which is exactly where `fps7` gets used.
///
/// They are here because the choice is yours to make, not because the maths is
/// clean. If one of them looks like it stutters rather than plays slowly, the
/// nearest even rates are `fps20`/`fps30` for 25, and `fps10` for 7.
///
/// - Note: On a 120Hz display 30, 20, 15, 12 and 10 are all exact; 25 and 7 are
///   still not.
enum SpriteRate: Int, CaseIterable {
    case fps7 = 7
    case fps10 = 10
    case fps12 = 12
    case fps15 = 15
    case fps20 = 20
    case fps25 = 25
    case fps30 = 30

    /// Frames per second.
    var framesPerSecond: Int { rawValue }

    /// Seconds each art frame is on screen.
    var frameDuration: TimeInterval { 1 / TimeInterval(rawValue) }

    /// How long a sheet of `count` frames takes to play through once.
    func duration(frames count: Int) -> TimeInterval {
        frameDuration * TimeInterval(count)
    }

    /// Display ticks each art frame occupies, at the game's clock.
    ///
    /// Fractional for the rates that do not divide it — see the type's notes.
    var ticksPerFrame: Double {
        Double(GameRules.spriteFramesPerSecond) / Double(rawValue)
    }

    /// Whether every frame gets the same number of display ticks.
    ///
    /// Useful for a debug readout, and for deciding whether a stutter is the
    /// animation or the rate.
    var dividesDisplayClock: Bool {
        GameRules.spriteFramesPerSecond % rawValue == 0
    }
}
