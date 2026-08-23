//
//  AquariusStormView.swift
//  Project Stars
//
//  The bluff: a tornado with something small inside it.
//

import SwiftUI

/// Aquarius, hidden inside the storm pouring out of its own jar.
///
/// ## What this is
///
/// The sign's meter, drawn on the piece. Aquarius runs backwards — it starts at
/// full ZC and fires at zero — so the storm is **thickest when it cannot act**
/// and gone at the moment it can. The last thing revealed is a little gold pot
/// half the size of an ordinary piece, which is the joke and also the tell: how
/// frightening Aquarius looks runs opposite to how dangerous it is.
///
/// See the Aquarius design note.
///
/// ## Sourced art, made native
///
/// The funnel is expected to be an outside asset rather than a drawn sprite, so
/// it goes through `Image.paletteQuantised(artPixels:scale:)` — nearest-neighbour
/// onto the art's own grid, then every colour snapped to the palette. What comes
/// out is not a photograph made to look like pixel art; it is pixel art in this
/// game's palette at this game's resolution.
///
/// ## What is not drawn here
///
/// The shadow. It belongs to the piece and is the one honest signal while the
/// storm lies — large under the funnel, small under the pot — so it is sized by
/// whoever draws the piece, from the same `stage`.
struct AquariusStormView: View {
    @Environment(\.planeIsAsleep) private var planeIsAsleep



    /// How far through the storm's retreat this is, `0` fully wrapped and `1`
    /// fully revealed.
    ///
    /// A fraction rather than a stage index, so the parts that *can* move
    /// continuously — the fade, the spin, the squash — do, while the sprite
    /// underneath steps between however many frames exist. Fine feedback for
    /// free, without drawing for it.
    let revealed: Double

    /// Size of a board cell, in points.
    let tileSize: CGFloat

    /// Points per art pixel.
    let scale: CGFloat

    /// The funnel frames, thickest first. Whatever exists — three is enough,
    /// five is better, and the last one is never drawn because at full reveal
    /// there is no storm left.
    var funnels: [Image] = []

    /// Seconds, stopped whenever the game is.
    @Environment(\.ambientClock) private var ambientClock

    var body: some View {
        TimelineView(.animation(paused: planeIsAsleep)) { timeline in
            #if DEBUG
            let _ = RenderTally.tick("AquariusStorm")
            #endif
            let now = ambientClock(timeline.date.timeIntervalSinceReferenceDate)
            let hidden = 1 - min(max(revealed, 0), 1)

            ZStack {
                // The pot, always there and mostly not visible.
                PixelSprite(id: .piece(.aquarius)) { Color.clear }
                    .frame(width: tileSize * Style.potSize, height: tileSize * Style.potSize)

                if hidden > 0, let funnel = frame(at: hidden) {
                    funnel
                        .paletteQuantised(
                            artPixels: CGFloat(GameRules.tilePixelSize) * 2,
                            scale: scale
                        )
                        // Turning, and breathing on the other axis as it turns.
                        // A funnel that only spins reads as a wheel; one that
                        // narrows and swells while it spins reads as weather.
                        // Both are the piece's own squash and stretch, which is
                        // why this needs no new machinery.
                        .rotationEffect(.degrees(sin(now / Style.swayPeriod * 2 * .pi) * Style.sway))
                        .scaleEffect(
                            x: 1 + CGFloat(sin(now / Style.breathPeriod * 2 * .pi)) * Style.breath,
                            y: 1 - CGFloat(sin(now / Style.breathPeriod * 2 * .pi)) * Style.breath,
                            anchor: .bottom
                        )
                        // Shrinking toward the pot as it goes, so the storm is
                        // drawn *into* the jar rather than fading off it.
                        .scaleEffect(Style.potSize + (1 - Style.potSize) * CGFloat(hidden),
                                     anchor: .bottom)
                        .opacity(min(hidden * Style.fadeSharpness, 1))

                    // The eyes, in there somewhere, and only while there is
                    // enough storm to hide in.
                    UmbraEyesView(
                        point: GameRules.nexysPoint,
                        tileSize: tileSize,
                        scale: scale,
                        tint: Palette.sky,
                        cycle: Style.eyeCycle,
                        dwell: Style.eyeDwell
                    )
                    .opacity(hidden > Style.eyeThreshold ? 1 : 0)
                }
            }
            .frame(width: tileSize, height: tileSize * 2)
        }
        .allowsHitTesting(false)
    }

    /// Which funnel frame this much storm calls for.
    ///
    /// Biased toward the low end deliberately: a distinct frame is worth most
    /// where the player's decisions are tightest, which is near firing. At full
    /// storm there is nothing to decide, so several turns of identical funnel
    /// costs nothing.
    private func frame(at hidden: Double) -> Image? {
        guard !funnels.isEmpty else { return nil }
        let curved = pow(hidden, Style.frameBias)
        let index = Int(curved * Double(funnels.count))
        return funnels[min(max(index, 0), funnels.count - 1)]
    }

    private enum Style {
        /// Half an ordinary piece. The smallest thing on the board, under the
        /// largest.
        static let potSize: CGFloat = 0.5

        static let sway: Double = 4
        static let swayPeriod: TimeInterval = 1.9
        static let breath: CGFloat = 0.06
        static let breathPeriod: TimeInterval = 1.3

        /// How quickly the storm goes opaque as it thickens. Above one it is
        /// solid for most of its range and only sheer at the very end, which is
        /// where the reveal wants its drama.
        static let fadeSharpness: Double = 2.5

        /// Above one, frames change faster near the reveal than at full storm.
        static let frameBias: Double = 1.6

        /// Enough storm left to hide something in.
        static let eyeThreshold: Double = 0.35

        /// Always watching, unlike Nilyth surfacing now and then.
        static let eyeCycle: TimeInterval = 3.4
        static let eyeDwell: TimeInterval = 2.6
    }
}
