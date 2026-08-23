//
//  SleepingPlane.swift
//  Project Stars
//
//  Whether the plane a view belongs to is the one being looked at.
//

import SwiftUI

/// True while this view's plane is off screen.
///
/// ## Why this exists
///
/// Both planes are mounted at once and stacked, with the one being stood on
/// scrolled into frame and the other clipped away — see `GameScreen.planeSquare`.
/// That is what lets a fall travel between them instead of hiding a swap behind
/// a curtain, and it is worth keeping.
///
/// But **clipping hides pixels; it does not stop views running.** Astra's clouds
/// carried on asking for sixty frames a second the whole time the player was
/// standing on Terra — ten sprites, six hundred wake-ups a second, for a picture
/// nobody could see. It was comfortably the largest single cost on the board and
/// it was entirely invisible, because nothing about it *drew* anything: a view
/// that is never rebuilt still wakes the main thread every frame if it asked to.
///
/// So the plane that is not being looked at goes to sleep. It stays mounted,
/// keeps its state, and comes back the instant it is needed — it simply stops
/// asking for frames while there is nothing to see.
///
/// ## Why it is not just `plane != visiblePlane`
///
/// During a fall **both** planes are on screen, scrolling past each other, and
/// the one being left has to still be alive on the way out. `isFalling` is what
/// separates "off screen" from "on its way off".
private struct SleepingPlaneKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var planeIsAsleep: Bool {
        get { self[SleepingPlaneKey.self] }
        set { self[SleepingPlaneKey.self] = newValue }
    }
}
