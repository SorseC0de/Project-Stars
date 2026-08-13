//
//  FlyingArrowView.swift
//  Project Stars
//
//  The arrow while it is still in the air.
//

import SwiftUI

/// Sagittarius' arrow, mid-flight.
///
/// ## Why it is a separate view from the planted one
///
/// They are the same sprite and nothing else about them matches. In flight the
/// arrow is whole, vertical, and moving; planted it is masked at the ground
/// line, leaning, and perfectly still with a warp square humming under it. One
/// view with a `isFlying` flag would be two drawings sharing a body out of
/// tidiness rather than because they have anything in common.
///
/// ## Ninety degrees, both ways
///
/// The shot goes straight up out of the board and comes straight back down onto
/// it. That is the shape of something fired into the sky — the arc a thrown
/// object makes would put the arrow somewhere other than where it was aimed, and
/// the whole point of this Zodiaction is that it comes down exactly where it was
/// sent. It only leans once it is in the ground, where the lean says *arrived*
/// rather than describing a flight path.
struct FlyingArrowView: View {

    /// Rendered edge length of one cell, in points.
    let tileSize: CGFloat

    var body: some View {
        PixelSprite(id: .effect(.sagittariusArrow)) { EmptyView() }
            .frame(width: tileSize * 2, height: tileSize * 2)
            .allowsHitTesting(false)
    }
}
