//
//  SunView.swift
//  Project Stars
//
//  Leo's sun, for as long as it burns.
//

import SwiftUI

/// The sun Leo's Solar Pull hangs over a square.
///
/// ## Why this is not an `EffectSpriteView`
///
/// Those play once and stop, which is right for an event. A sun is not an
/// event — it is a thing on the board with a lifetime measured in moves, and it
/// has to still be there five turns later. So it loops, keyed on nothing but the
/// clock, and disappears when the engine says the sun is out.
///
/// ## Why two strips
///
/// The art was authored as two layers meant to be composited. Stacked they read
/// as a body of fire; either one alone is a flat disc.
struct SunView: View {

    let sun: SignState.Sun

    /// Size of a board cell, in points.
    let tileSize: CGFloat

    var body: some View {
        TimelineView(.animation) { timeline in
            let now = timeline.date.timeIntervalSinceReferenceDate

            ZStack {
                ForEach(EffectSprite.leoSun, id: \.self) { layer in
                    let frame = Int(now / layer.rate.frameDuration) % layer.frames

                    PixelSprite(id: .effect(layer), frame: frame) { EmptyView() }
                        .frame(width: side(layer), height: side(layer))
                }
            }
            // Fades as it goes out, so the last move under it is visibly the
            // last one — the same warning the Bastion gives by pulsing faster.
            .opacity(sun.movesRemaining <= 1 ? GameRules.sunGuttering : 1)
        }
        .allowsHitTesting(false)
    }

    private func side(_ layer: EffectSprite) -> CGFloat {
        tileSize * layer.span
    }
}
