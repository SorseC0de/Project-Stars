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
/// has to still be there five turns later.
///
/// ## The three phases
///
/// A strip drawn as a single burst has a beginning, a body and an end, and a
/// thing with a lifetime needs those separated:
///
/// 1. **Kindling** — frames up to `sunLoopStart`, played once as it arrives.
/// 2. **Burning** — `sunLoopStart..<sunLoopEnd` on repeat, for however many
///    moves it lasts. Looping the *middle* is what lets one strip cover a
///    duration nobody knew when the art was drawn.
/// 3. **Going out** — the rest of the frames, played once when the engine says
///    it is on its last move.
///
/// The summon flare is stacked over all of it and plays once at the start. It is
/// drawn here rather than fired as a separate burst so the two are the same
/// object: one appearance, not a flash followed by a sun.
struct SunView: View {

    let sun: SignState.Sun

    /// Size of a board cell, in points.
    let tileSize: CGFloat

    /// When this sun appeared.
    @State private var lit = Date()

    /// When it started going out. `nil` while it is still burning.
    @State private var guttering: Date?

    var body: some View {
        TimelineView(.animation) { timeline in
            let now = timeline.date

            ZStack {
                ForEach(EffectSprite.leoSun, id: \.self) { layer in
                    PixelSprite(id: .effect(layer), frame: frame(of: layer, at: now)) {
                        EmptyView()
                    }
                    .frame(width: side(layer), height: side(layer))
                }

                summon(at: now)
            }
        }
        .allowsHitTesting(false)
        .onChange(of: sun.movesRemaining) { _, remaining in
            // One move left is the last one it will be seen on, so the tail has
            // to start now rather than when the state disappears.
            if remaining <= 1, guttering == nil { guttering = .now }
        }
    }

    /// The flare of it being called, over the top and played once.
    @ViewBuilder
    private func summon(at now: Date) -> some View {
        let flare = EffectSprite.leoZodiactionSummon
        let step = Int(now.timeIntervalSince(lit) / flare.rate.frameDuration)

        if step < flare.frames {
            PixelSprite(id: .effect(flare), frame: step) { EmptyView() }
                .frame(width: side(flare), height: side(flare))
        }
    }

    /// Which frame of a sun layer is showing.
    private func frame(of layer: EffectSprite, at now: Date) -> Int {
        let loopStart = min(GameRules.sunLoopStart, layer.frames - 1)
        let loopEnd = min(GameRules.sunLoopEnd, layer.frames)

        // Going out: play whatever is left, and hold on the final frame rather
        // than snapping back — the state vanishes a beat later either way.
        if let guttering {
            let step = Int(now.timeIntervalSince(guttering) / layer.rate.frameDuration)
            return min(loopEnd + step, layer.frames - 1)
        }

        let step = Int(now.timeIntervalSince(lit) / layer.rate.frameDuration)
        if step < loopStart { return step }

        let body = max(loopEnd - loopStart, 1)
        return loopStart + (step - loopStart) % body
    }

    private func side(_ layer: EffectSprite) -> CGFloat {
        tileSize * layer.span
    }
}
