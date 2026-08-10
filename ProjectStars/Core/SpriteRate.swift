//
//  SpriteRate.swift
//  Project Stars
//
//  The frame rates pixel-art animation actually gets authored at.
//

import Foundation

/// How fast an animated sprite plays.
///
/// A closed set rather than a free number, because these are the rates that
/// divide the 60fps clock exactly — anything else lands between ticks and the
/// animation judders, holding one frame a beat longer than its neighbour.
///
/// | Rate | Holds | Suits |
/// |---|---|---|
/// | `fps20` | 3 | short, sharp bursts — sparks, impacts |
/// | `fps15` | 4 | quick effects that still need to read |
/// | `fps12` | 5 | the house default; most things |
/// | `fps10` | 6 | slow, weighty, or long loops |
///
/// The raw value *is* the hold: how many of the game's frames each drawn frame
/// stays on screen. That is the unit these are authored in — "five ticks", not
/// "0.0833 seconds" — and keeping it as the source of truth is what stops a
/// hand-timed animation drifting out of step with the sheet it was drawn
/// against.
enum SpriteRate: Int, CaseIterable {
    case fps20 = 3
    case fps15 = 4
    case fps12 = 5
    case fps10 = 6

    /// Game frames each art frame is held for.
    var hold: Int { rawValue }

    /// Seconds each art frame is on screen.
    var frameDuration: TimeInterval {
        TimeInterval(hold) / TimeInterval(GameRules.spriteFramesPerSecond)
    }

    /// Frames per second, for reading back.
    var framesPerSecond: Int {
        GameRules.spriteFramesPerSecond / hold
    }

    /// How long a sheet of `count` frames takes to play through once.
    func duration(frames count: Int) -> TimeInterval {
        frameDuration * TimeInterval(count)
    }
}
