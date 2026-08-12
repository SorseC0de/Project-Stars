//
//  TileChoiceOverlay.swift
//  Project Stars
//
//  Asks the player to pick a square. Lives with the board it is laid over.
//

import SwiftUI

/// Asks the player to pick a square on the board.
///
/// Laid directly over the grid, matching its metrics exactly, so the player taps
/// the square they can see rather than a proxy for it.
///
/// ## Two shapes of question
///
/// `PickupChoice.tile` allows **every** square — holes, the chasm and the Nexys
/// included — because the effect that asks (Astral Breeze) deliberately has no
/// restrictions, and picking a hole on purpose is a real play.
///
/// `PickupChoice.among` names a handful instead, and may be **declined**. That
/// is what an always-on ability offering something on arrival looks like:
/// Aquarius' Corner Current is not a prize to be collected, it is a door left
/// open, and a door you cannot walk past is a corridor.
///
/// Taps work here where they fail in the lower panel: the board carries no
/// `DragGesture`, so nothing competes with them.
struct TileChoiceOverlay: View {

    let session: GameSession
    let metrics: PixelArtMetrics
    let accent: Color

    @State private var pulse = false

    var body: some View {
        let allowed = session.choosableTiles

        ZStack {
            // Highlights are display only. They must not carry the gesture:
            // `.position` fills the available space, so a hit shape applied
            // after it covers the whole board rather than one square, and 49
            // board-sized targets stack into "every tap hits the last one".
            ZStack {
                ForEach(highlighted(allowed), id: \.self) { point in
                    Rectangle()
                        .fill(accent.opacity(pulse ? 0.22 : 0.10))
                        .overlay(
                            Rectangle().strokeBorder(accent.opacity(0.8), lineWidth: 1)
                        )
                        .frame(width: metrics.tileSize, height: metrics.tileSize)
                        .position(metrics.center(of: point))
                }
            }
            .allowsHitTesting(false)

            // One tap surface for the whole grid, resolved back to a square
            // through the same metrics that laid the board out — so the square
            // the player taps is by construction the square they see.
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture(coordinateSpace: .local) { location in
                    guard let point = metrics.gridPoint(at: location) else { return }
                    // A tap outside the offered set is not an answer. Ignored
                    // rather than treated as a decline: a mis-tap should cost
                    // nothing, and the way to say no is to say no.
                    if let allowed, !allowed.contains(point) { return }
                    session.resolvePickupChoice(.tile(point))
                }

            if session.choiceIsDeclinable {
                declineButton
            }
        }
        .frame(width: metrics.boardSize, height: metrics.boardSize)
        .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: pulse)
        .onAppear { pulse = true }
        .transition(.opacity)
    }

    /// The way to walk past an offer.
    ///
    /// Sits over the middle of the board, which is the one place no offer's
    /// candidates have ever been — Corner Current's are the four corners, and
    /// anything else declinable will be similarly peripheral by nature, since
    /// an offer worth refusing is an offer to *go somewhere*.
    private var declineButton: some View {
        Text("STAY")
            .font(.system(size: 12, weight: .heavy, design: .monospaced))
            .tracking(3)
            .foregroundStyle(Palette.textPrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(Capsule().fill(Palette.warmBlack.opacity(0.85)))
            .overlay(Capsule().strokeBorder(accent.opacity(0.8), lineWidth: 1.5))
            .contentShape(Capsule())
            .onTapGesture { session.resolvePickupChoice(.declined) }
    }

    /// Which squares to light up.
    private func highlighted(_ allowed: [GridPoint]?) -> [GridPoint] {
        allowed ?? GridPoint.allPoints(size: metrics.gridSize)
    }
}
