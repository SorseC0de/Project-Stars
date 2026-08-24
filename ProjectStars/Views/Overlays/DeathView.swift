//
//  DeathView.swift
//  Project Stars
//
//  What is under Terra.
//

import SwiftUI

/// The row below Terra: where a piece that falls out of the world ends up.
///
/// ## Why it is a row and not a screen
///
/// It used to be a full-screen overlay that faded in over a greyed-out board,
/// with its own copy of the piece spinning on it and its own dark behind that.
/// Every part of that was a picture *of* falling drawn after the fact.
///
/// This is the place itself. It sits directly under Terra in the world column,
/// which puts it directly behind the control panel, and it is drawn there for
/// the whole run whether or not anybody has died. Nothing fades in, nothing is
/// revealed: the piece falls one row, and the lid over that row stops being
/// opaque. The piece you watch spinning down here is the piece — not a second
/// one posed to look like it.
///
/// See `World.underground` for where it sits and `GameSession.panelVeil` for
/// the lid.
struct DeathView: View {

    let session: GameSession

    var body: some View {
        // No fill of its own. The column's sky is already dark this far down —
        // that is what the gradient's lower half is *for* — and a second black
        // rectangle over it would be a second opinion about how deep this is.
        // **Alive exactly while the lid is off.**
        //
        // Not "while the run is over": the panel comes back once the piece is
        // down, carrying the way out, and it is opaque and exactly one square
        // and sitting exactly over this row. Keyed on the run's state, forty
        // eight additively-blended capsules would go on being drawn at display
        // rate into a canvas nothing can see — on the one screen where a player
        // might sit for a minute deciding what to do.
        FallStreaks(isLive: session.panelVeil > 0)
    }
}

/// What the underground is made of.
enum DeathStyle {

    static let title = "GAME OVER"

    /// How long one turn of the endless spin takes, once the piece is down here.
    ///
    /// The fall's own rate, carried on. The piece does not change what it is
    /// doing when it reaches the bottom — it just never lands — so a player
    /// watching cannot see the moment one became the other.
    static var spinPeriod: TimeInterval {
        let turns = abs(GameRules.fallSpinDegrees) / 360
        return (GameRules.fallDuration + GameRules.fallArrivalDuration) / turns
    }

    /// Which way it turns. Sign carries the fall's own direction.
    static var spinDirection: Double { GameRules.fallSpinDegrees < 0 ? -1 : 1 }
}
