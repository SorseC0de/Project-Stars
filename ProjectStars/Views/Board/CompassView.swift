//
//  CompassView.swift
//  Project Stars
//
//  The direction guide in the corner of the board.
//

import SwiftUI

/// A compass rose showing which way the piece is looking.
///
/// ## Why the board needs one at all
///
/// Facing decides a great deal in this game — Sagittarius' Vault, Libra's
/// flanks, Scorpio's sting, Capricorn's hooves, which square a phantom stands on
/// — and until now the only thing saying which way you were pointed was a small
/// arrow beside the piece, on a board where a dozen other things are also
/// moving. The arrow says it locally; this says it absolutely.
///
/// ## Why it is one sprite per direction rather than a rotating one
///
/// The art is four drawings, and each has its own lit letter. Rotating a single
/// rose would turn the letters with it, which is the one thing a compass must
/// never do.
struct CompassView: View {

    let facing: SwipeDirection

    /// Size of a board cell, in points.
    let tileSize: CGFloat

    var body: some View {
        PixelSprite(id: .directionGuide(cardinal)) { EmptyView() }
            .frame(
                width: tileSize * GameRules.compassSpan,
                height: tileSize * GameRules.compassSpan
            )
            .allowsHitTesting(false)
    }

    /// The nearest cardinal, since the art has four cells and Virgo has eight
    /// directions.
    ///
    /// A diagonal resolves to its vertical component — north-east reads as
    /// north — because up and down are what the two planes are about, and a
    /// compass that flickered between two roses on every diagonal step would be
    /// worse than one that rounds.
    private var cardinal: SwipeDirection {
        switch facing {
        case .up, .upLeft, .upRight: .up
        case .down, .downLeft, .downRight: .down
        case .left: .left
        case .right: .right
        }
    }
}
