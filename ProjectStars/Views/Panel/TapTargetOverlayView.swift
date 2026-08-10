//
//  TapTargetOverlayView.swift
//  Project Stars
//
//  Control scheme 2: tap a destination on a ghost grid. NOT YET IMPLEMENTED.
//

import SwiftUI

/// The second control scheme: a transparent 7x7 grid mirrored into the lower
/// square, where tapping a legal destination moves the piece there.
///
/// - TODO: Not implemented. The pieces needed are already in place:
///   - `GameEngine.legalDestinations` gives the tappable squares.
///   - `PixelArtMetrics.gridPoint(at:)` converts a tap location to a `GridPoint`.
///   - `GameSession.submit(_:)` takes a `SwipeDirection`; adding a
///     `submit(destination:)` that resolves a point back to its offset is the
///     only engine-side work left.
///
///   Design notes carried over from the brief: the overlay is a *transparent*
///   grid aligned to the board above it, so the tap zone for a square is in the
///   same relative position in the lower half as the square itself is in the
///   upper half.
struct TapTargetOverlayView: View {

    let session: GameSession

    /// The side length available, in points. Matches the board's own metrics so
    /// the two grids line up.
    let availableSide: CGFloat

    /// Master switch. Stays false until the scheme is built.
    var isEnabled: Bool = false

    var body: some View {
        if isEnabled {
            let metrics = PixelArtMetrics(availableSide: availableSide)
            ZStack {
                ForEach(GridPoint.allPoints(), id: \.self) { point in
                    Rectangle()
                        .strokeBorder(Palette.outline.opacity(0.5), lineWidth: 1)
                        .frame(width: metrics.tileSize, height: metrics.tileSize)
                        .position(metrics.center(of: point))
                }
            }
            .frame(width: metrics.boardSize, height: metrics.boardSize)
        }
    }
}
