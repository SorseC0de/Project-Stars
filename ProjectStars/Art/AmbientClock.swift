//
//  AmbientClock.swift
//  Project Stars
//
//  The one clock every ambient animation runs on.
//

import SwiftUI

/// The clock ambient art reads, as an environment value.
///
/// ## Why this is not a parameter
///
/// It was, and that was the mistake. Freezing the board meant handing a stopped
/// clock to each view that needed one, which worked exactly as far as somebody
/// remembered to pass it — so the coin kept spinning while its float held still,
/// the sun burned on over a frozen board, and every sprite added later started
/// out unfrozen by default. A rule enforced by remembering is not a rule.
///
/// An environment value inverts that. It is injected once at `GameScreen` and
/// every descendant reads it whether it knows about pausing or not, which
/// includes `PixelSprite` — and since practically everything drawn on this board
/// is a `PixelSprite`, the frame cycling of the entire game stops in one place.
///
/// ## What it does
///
/// Returns the ambient time for a given wall time. While the board is running it
/// is the identity; while it is paused it returns the instant of the pause, and
/// afterwards it subtracts the time spent stopped so nothing jumps. See
/// `GameSession.ambientClock(at:)`.
///
/// ## What should *not* use it
///
/// Anything the player is currently operating — the cursor, the control panel —
/// and anything that is an impact rather than ambience, since an impact is set
/// off by the very action the clock is stopped for. See `CloudMotion`.
private struct AmbientClockKey: EnvironmentKey {
    static let defaultValue: (TimeInterval) -> TimeInterval = { $0 }
}

extension EnvironmentValues {
    var ambientClock: (TimeInterval) -> TimeInterval {
        get { self[AmbientClockKey.self] }
        set { self[AmbientClockKey.self] = newValue }
    }
}
