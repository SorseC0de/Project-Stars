//
//  DeathView.swift
//  Project Stars
//
//  Where a run ends: the piece still falling, and the card that says so.
//

import SwiftUI

/// The screen a run ends on.
///
/// ## What it is
///
/// Not a dialog over the board. When the piece goes through Terra it does not
/// stop — it keeps falling, and this is what is down there: a long dark drop
/// with the walls streaking past. The board is gone because the piece has left
/// it, which is a truer picture of losing than the board greyed out behind a
/// box.
///
/// ## Why there are no buttons on it
///
/// There used to be, and they had to fight the panel's swipe surface for the
/// gesture — the comment they carried explaining that fight is the tell. Every
/// touch in this game belongs to the bottom screen; the top screen is a window.
/// So the way out of a lost run lives on the panel's own death face, and this
/// view is only the view.
struct DeathView: View {

    let session: GameSession

    /// How far round the piece has turned since the fall began. Drives itself,
    /// so nothing has to wake this view to keep it going.
    @State private var spin: Double = 0

    /// How far in the dark has come, `0`…`1`.
    ///
    /// Faded by an explicit `withAnimation` on this one property rather than a
    /// transition or an `.animation(_:value:)` over the view: either of those
    /// governs everything underneath, and everything underneath is a spin and a
    /// card that are already timing themselves.
    @State private var arrived: Double = 0

    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            let metrics = PixelArtMetrics(availableSide: side * DeathStyle.pieceShare)

            ZStack {
                Palette.coolBlack

                // The same streaks the passive prompts fly in on, turned from a
                // decoration into a place: there, they say a thing came from
                // somewhere fast; here, they say *you* are moving, and the walls
                // are what you are passing.
                SideStreaks()

                PieceView(
                    zodiac: session.zodiac,
                    tileSize: metrics.tileSize,
                    scale: metrics.scale,
                    // Falling, so gold — the material of a piece that belongs to
                    // no plane. See `PieceView.forcesGold`. It never lands, so it
                    // never takes another.
                    forcesGold: true,
                    showsShadow: false
                )
                .rotationEffect(.degrees(spin))
                .position(
                    x: geometry.size.width / 2,
                    y: geometry.size.height * DeathStyle.pieceHeight
                )

                // The same card the run opened on, saying the opposite thing.
                // It arrives and never leaves: `isLeaving` stays low, so the
                // bars settle into their Z and hold there for as long as the
                // player is looking at this.
                GameModeSplashView(
                    title: DeathStyle.title,
                    subtitle: session.engine.gameOverReason?.displayText ?? "",
                    ink: Palette.red,
                    isLeaving: false,
                    onLanded: {},
                    onFinished: {}
                )
            }
        }
        .ignoresSafeArea()
        // **Nothing here takes a touch.**
        //
        // This covers the panel as well as the board, and the way out of a lost
        // run is now a button on that panel. A view with no controls on it that
        // sits over the only controls there are is a view that has to say so.
        .allowsHitTesting(false)
        .opacity(arrived)
        .onAppear {
            // The piece is still falling out of the bottom of the board as this
            // starts, which is the point: the board does not cut away, it goes
            // dark around a fall already in progress.
            withAnimation(.easeIn(duration: DeathStyle.dawn)) { arrived = 1 }

            withAnimation(
                .linear(duration: DeathStyle.spinPeriod)
                    .repeatForever(autoreverses: false)
            ) {
                spin = DeathStyle.spinDirection * 360
            }
        }
    }
}

/// The death screen's dimensions.
enum DeathStyle {

    static let title = "GAME OVER"

    /// How long the dark takes to close over the board. Half the fall it is
    /// arriving during, so it is fully up by the time the piece would have
    /// cleared the screen.
    static var dawn: TimeInterval { GameRules.fallDuration / 2 }

    /// How much of the screen's short side the piece is drawn at, as a whole
    /// board's worth of tiles. Below one it is smaller than it was on the
    /// board — far away, which is where a thing you are falling away from is.
    static let pieceShare: CGFloat = 0.55

    /// Where the piece sits down the screen. Above the card, so the two do not
    /// share a line and the eye reads the figure before the words.
    static let pieceHeight: CGFloat = 0.28

    /// Which way it turns, and how long one turn takes.
    ///
    /// Both taken from the fall itself rather than picked: the piece does not
    /// change what it is doing when the run ends, it just never lands. Sign
    /// carries the fall's direction; the period is the fall's own rate, so a
    /// player watching cannot see the moment one became the other.
    static var spinDirection: Double { GameRules.fallSpinDegrees < 0 ? -1 : 1 }

    static var spinPeriod: TimeInterval {
        let turns = abs(GameRules.fallSpinDegrees) / 360
        return (GameRules.fallDuration + GameRules.fallArrivalDuration) / turns
    }
}
