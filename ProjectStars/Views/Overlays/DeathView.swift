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
        ZStack {
            // **Its own ground, over the column's sky.**
            //
            // The sky is one field the height of the world and it has one job:
            // saying how far you are from the light. Down here you are past the
            // point where that is the question — this is not more sky, it is
            // what is under the world, and it gets a colour of its own. Warm
            // rather than cold, and darkening downward, so falling into it reads
            // as going further in rather than further away.
            LinearGradient(
                stops: [
                    .init(color: Palette.coffee, location: 0),
                    .init(color: Palette.coolBlack, location: DeathStyle.floor),
                    .init(color: Palette.coolBlack, location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // **Alive exactly while this row is on screen**, and asleep
            // otherwise — the same question every other row of the column
            // answers. It was briefly keyed on the control panel's opacity
            // instead, and keyed the wrong way round, so forty eight additively
            // blended capsules drew at display rate for the whole of every run
            // on a row nobody had looked at yet.
            FallStreaks(
                isLive: World.isVisible(
                    row: World.underground,
                    sweeping: session.cameraFrom ?? session.cameraRow,
                    to: session.cameraRow
                )
            )

            // **The card is part of this place, and under the piece.**
            //
            // It used to be an overlay on the upper screen square, which put it
            // over whatever the camera happened to be looking at and over the
            // piece with it — so the one thing the screen is about was behind
            // the words describing it. Mounted here it belongs to the
            // underground, it scrolls in with it, and the piece is drawn on
            // Terra's row, which sits above this one.
            //
            // Which is why there is no mask cutting a hole in the card. A hole
            // is what you reach for when the thing you want to see is behind
            // something and cannot be moved; this one could be moved.
            if session.phase == .gameOver || session.deathCardIsLeaving {
                GameModeSplashView(
                    title: DeathStyle.title,
                    subtitle: session.engine.gameOverReason?.displayText ?? "",
                    // The name is the announcement and takes the announcement's
                    // colour. The reason under it is the explanation, and an
                    // explanation in alarm red is a second alarm.
                    ink: Palette.red,
                    titleDrop: DeathStyle.titleDrop,
                    blurbDrop: DeathStyle.blurbDrop,
                    // It leaves the way it arrived, on the press that ends the
                    // screen — see `GameSession.deathCardIsLeaving`.
                    isLeaving: session.deathCardIsLeaving,
                    onLanded: {},
                    onFinished: {}
                )
            }
        }
    }
}

/// What the underground is made of.
enum DeathStyle {

    static let title = "GAME OVER"

    /// Centred in the upper bar rather than sitting low in it, and the line
    /// under it pushed down into the lower one — so the middle of the card,
    /// where the piece is turning, is left clear.
    /// How far down the row the warm crust gives way to the dark under it.
    ///
    /// High: the brown is the underside of the world you have just come through,
    /// and you are past it almost immediately. Most of this place is the dark.
    static let floor: CGFloat = 0.28

    static let titleDrop: CGFloat = 0

    /// Far enough down the lower bar to clear the piece, and not so far it sits
    /// on the bar's own bottom edge.
    static let blurbDrop: CGFloat = 0.28

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
