//
//  BubbleThrow.swift
//  Project Stars
//
//  A bubble leaving the fish.
//

import SwiftUI

/// Puts a pickup where its throw has got to, or leaves it alone.
///
/// ## Why a modifier and not a position
///
/// Because the coin is already positioned on its square, and everything else
/// about it — the lift over a raised tile, the cloud's drift — is expressed as
/// offsets from there. Replacing the position throws all of that away for the
/// half-second the bubble is in the air and puts it back afterwards, which
/// shows as a jump on landing. Offsetting *from* the square keeps one source of
/// truth for where the thing lives and treats the flight as what it is: a
/// temporary displacement from home.
struct BubbleThrow: ViewModifier {

    /// Where the bubble is and how big, or `nil` when it is not being thrown.
    /// Positions are absolute board points; the square's own centre is
    /// subtracted here.
    let flight: (position: CGPoint, scale: CGFloat)?

    /// The square it is going to, in board points.
    var home: CGPoint = .zero

    func body(content: Content) -> some View {
        if let flight {
            content
                .scaleEffect(flight.scale)
                .offset(
                    x: flight.position.x - home.x,
                    y: flight.position.y - home.y
                )
        } else {
            content
        }
    }
}
