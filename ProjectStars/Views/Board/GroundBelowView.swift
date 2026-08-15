//
//  GroundBelowView.swift
//  Project Stars
//
//  The world underneath, seen from the sky.
//

import SwiftUI

/// A suggestion of Terra along the bottom of Astra.
///
/// ## Why it exists
///
/// Astra otherwise floats in nothing, and a plane with nothing under it is a
/// plane you cannot fall *from*. The drop is most of what makes the sky tense,
/// and the sky was not showing it.
///
/// ## Why it lives above the board rather than inside it
///
/// Two reasons, and both were found the hard way by putting it inside.
///
/// It has to span the **whole upper square**, not the board. The board is
/// 112 art pixels across and the screen is wider, so a board-width horizon stops
/// short of both edges and reads as a rug rather than as a world.
///
/// And it has to sit **behind everything**, including the cloud field. Drawn
/// inside `BoardView` it was covered by the very tiles it is supposed to be
/// underneath — which also means that from here it shows through Astra's
/// **holes**, which is exactly right: a hole in the sky should have the ground
/// visible at the bottom of it.
///
/// ## What it is
///
/// A stand-in, borrowing Terra's own tile art. It will be replaced by a
/// dedicated drawing — curved, with trees and mountains — and nothing here cares
/// which it is.
struct GroundBelowView: View {

    /// The side of the upper square, in points.
    let side: CGFloat

    /// Board metrics, for the tile size the horizon is drawn at.
    let metrics: PixelArtMetrics

    var body: some View {
        // Held off both edges. Run to the screen's sides it read as a floor
        // somebody had laid wall to wall; inset, it reads as a landmass with sky
        // either side of it, which is what it is.
        let bandWidth = side * (1 - GameRules.groundBelowInset * 2)

        // Enough columns to cross the band however wide it is, rather than the
        // board's seven.
        let columns = Int((bandWidth / metrics.tileSize).rounded(.up)) + 1

        VStack(spacing: 0) {
            ForEach(0..<GameRules.gridSize, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<columns, id: \.self) { column in
                        // Checkered like the real thing, so the horizon reads as
                        // ground rather than as a flat band.
                        PixelSprite(
                            id: .tileFace(
                                .terra,
                                Palette.TileShade.at(GridPoint(column, row)),
                                popped: false
                            )
                        ) { Color.clear }
                            .frame(width: metrics.tileSize, height: metrics.tileSize)
                    }
                }
            }
        }
        // Cut to the bottom band, keeping the *top* of what is drawn — the far
        // edge of a floor seen from above, not a strip of one.
        .frame(
            width: bandWidth,
            height: side * GameRules.groundBelowHeight,
            alignment: .top
        )
        .clipped()
        // Night laid over it, not transparency.
        //
        // It was faded instead, which let the stars shine straight through the
        // ground — nonsense for a solid world below you. Midnight over the top
        // darkens it to the same distance while leaving it opaque.
        .overlay(Palette.midnight.opacity(GameRules.groundBelowShade))
        // The same tilt as the board. It is the same kind of surface seen from
        // the same eye — left flat while the board lay down, it read as a wall
        // behind the world rather than a floor beneath it.
        .foreshortened(
            size: CGSize(width: bandWidth, height: side * GameRules.groundBelowHeight)
        )
        .blur(radius: GameRules.groundBelowBlur * metrics.scale)
        .frame(width: side, height: side, alignment: .bottom)
        .allowsHitTesting(false)
    }
}
