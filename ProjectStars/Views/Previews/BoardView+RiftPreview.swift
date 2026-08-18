//
//  BoardView+RiftPreview.swift
//  Project Stars
//
//  Gemini's rift, on the bench — debug builds only.
//

#if DEBUG
import SwiftUI

/// The rift bench: both drawings of the tear, stacked on one square, being
/// looked at.
///
/// Out here rather than in `BoardView` because it is **not part of the board**.
/// It draws for every sign, it answers to nothing that happens in a run, and it
/// exists until one of the two drawings is chosen — at which point the rift
/// becomes a real thing the game does and gets written properly, somewhere
/// else. Keeping it beside the board's own layers is how a bench turns into
/// scenery nobody remembers adding.
///
/// The dials it reads live in `GameRules` under Gemini's rift, and the blend is
/// `RiftPreviewDebug`.
extension BoardView {

    /// Gemini's rift: both drawings stacked on one square, circling.
    ///
    /// Not tied to Gemini and not tied to anything that happens — it is on the
    /// board for every sign, because the question is what the drawing looks like
    /// standing next to a piece and that question has no prerequisites. It comes
    /// out when the rift is a real thing the game does.
    ///
    /// The two plates each travel a small **oval, counter-clockwise**, and the
    /// ovals are placed so both pass through the square's centre — the position
    /// the stack would sit at if nothing were moving. So the pair cross there
    /// rather than orbiting a common middle, which is what makes it read as one
    /// tear working rather than as two sprites doing laps.
    ///
    /// Their opacities breathe half a turn apart, so one is brightest exactly
    /// when the other is faintest and the tear is never entirely gone.
    ///
    /// - TODO: **Try a Z.** The crossed pair reads as a three-dimensional X,
    ///   which is worth keeping either way — but the same parts arranged as a
    ///   zigzag would be the sign's own letter standing in the board, and that
    ///   is a better answer if it works. Needs a third plate, or the inner pair
    ///   laid flat with the outer ones as the bars. Gallery it against this one
    ///   rather than replacing it: both are live candidates.
    @ViewBuilder
    func riftPreview(metrics: PixelArtMetrics) -> some View {
        if RiftPreviewDebug.shared.isShown {
            TimelineView(.animation(paused: session.isPaused)) { timeline in
                let now = session.ambientClock(
                    at: timeline.date.timeIntervalSinceReferenceDate
                )

                // **The two leans trade length, and neither moves.**
                //
                // One arm grows to full height while the other shortens to
                // half, then back — so the X keeps turning itself inside out
                // and the eye reads depth being exchanged rather than two fixed
                // bars. Each plate scales about its own centre and the crossing
                // stays exactly where it was.
                //
                // **Height only.** Trading both axes was a zoom, and a zooming
                // sprite reads as coming toward you; a tear has no business
                // approaching anybody. Holding the width and moving only the
                // length makes it a *stretch*, which is what a rip in something
                // does.
                //
                // Smooth, unlike everything else here: the jitter is the thing
                // that jumps, and a scale that jumped with it would just be
                // more noise at a different size.
                let trade = (1 - cos(now / GameRules.riftTradePeriod * 2 * .pi)) / 2
                let outer = GameRules.riftInnerScale
                    + (1 - GameRules.riftInnerScale) * (1 - trade)
                let inner = GameRules.riftInnerScale
                    + (1 - GameRules.riftInnerScale) * trade

                ZStack {
                    // The pair, leaning one way.
                    riftPlate(.geminiRiftOne, phase: 0, at: now, metrics: metrics, length: outer)
                    riftPlate(.geminiRiftTwo, phase: .pi, at: now, metrics: metrics, length: outer)

                    // And the same pair again at half size, leaning the other —
                    // so the tear crosses itself rather than being one slash.
                    // Salted differently, so the small pair distorts on its own
                    // rolls instead of shadowing the big one.
                    // Turned end over end **before** it leans, so the drawing's
                    // own light and dark edges meet the outer pair's the right
                    // way round. Without it the two crossed with their bright
                    // sides on the same diagonal, which is what made it read as
                    // two sprites rather than as one X with depth in it.
                    riftPlate(
                        .geminiRiftOne, phase: 0, at: now, metrics: metrics,
                        tilt: -GameRules.riftTilt,
                        width: GameRules.riftInnerScale, length: inner,
                        flipped: true, salt: 21
                    )
                    riftPlate(
                        .geminiRiftTwo, phase: .pi, at: now, metrics: metrics,
                        tilt: -GameRules.riftTilt,
                        width: GameRules.riftInnerScale, length: inner,
                        flipped: true, salt: 31
                    )
                }
                // **Stood on the square, not centred over it.**
                //
                // A tear opens *out of the ground*, so its foot belongs on the
                // tile and the rest of it reaches up — where every other effect
                // here is centred on the square it marks. Lifted by half its own
                // drawn height, which is what bottom-anchoring is; stated as the
                // art's height rather than as a number of tiles, so changing the
                // span or the stretch cannot leave it half-buried.
                .offset(y: -riftDrawnHeight(metrics: metrics) / 2 * GameRules.riftLift)
                .modifier(placedOnPlaneModifier(GridPoint(3, 3), metrics: metrics))
            }
        }
    }

    /// One of the pair, on its own lap of the oval.
    ///
    /// - Parameter phase: Where this plate starts, in radians. The two are half
    ///   a turn apart, which puts one at each end of the crossing and keeps the
    ///   two breaths out of step.
    /// How tall a rift plate is drawn, in points.
    ///
    /// The catalogue's span, through the stretch `riftPreview` applies. Read
    /// rather than assumed, because the lift is half of it.
    private func riftDrawnHeight(metrics: PixelArtMetrics) -> CGFloat {
        metrics.tileSize * EffectSprite.geminiRiftOne.span * 1.25
    }

    func riftPlate(
        _ art: EffectSprite,
        phase: Double,
        at now: TimeInterval,
        metrics: PixelArtMetrics,
        tilt: Double = GameRules.riftTilt,
        width: CGFloat = 1,
        length: CGFloat = 1,
        flipped: Bool = false,
        salt: Int? = nil
    ) -> some View {
        let salt = salt ?? (art == .geminiRiftOne ? 3 : 11)

        // ── Version 1: two crossing orbits ────────────────────────────
        //
        // Kept, not deleted. It works and it may still be the answer; version
        // two is a different idea rather than a correction of this one.
        //
        // let angle = now / GameRules.riftOrbitPeriod * 2 * .pi + phase
        //
        // // Counter-clockwise on a screen whose y grows downward, and centred
        // // so the square's own middle lies **on** the path rather than inside
        // // it — which is why each term is measured against where the plate
        // // started rather than from the oval's centre.
        // let x = GameRules.riftOrbitWidth * metrics.scale * (cos(angle) - cos(phase))
        // let y = -GameRules.riftOrbitHeight * metrics.scale * (sin(angle) - sin(phase))
        //
        // let shiverX = GameRules.riftJitter * metrics.scale
        //     * GameRules.jitter(now, salt: salt)
        // let shiverY = GameRules.riftJitter * metrics.scale
        //     * GameRules.jitter(now, salt: salt + 1)
        //
        // // All the way down to nearly nothing and back, half a turn apart, so
        // // one is brightest exactly when the other is faintest.
        // let breath = (1 - cos(now / GameRules.riftPulsePeriod * 2 * .pi + phase)) / 2
        // let alpha = GameRules.riftFaintest + (1 - GameRules.riftFaintest) * breath

        // ── Version 2: per-frame distortion ───────────────────────────
        //
        // No path and no curve: a new offset and a new opacity **held for one
        // frame and then replaced**, which is what makes it read as a picture
        // failing rather than as a sprite being animated. Nothing here is
        // interpolated — the value is a function of which frame it is, so it
        // jumps.
        //
        // Stepped at the strip's own rate rather than the display's. A value
        // redrawn sixty times a second is noise, and noise averages out to a
        // blur; changing when the drawing changes ties the distortion to the
        // art's own beat, which is the thing it is supposed to be interfering
        // with. `riftJumpRate` is the dial if that beat wants to be faster.
        let step = (now * GameRules.riftJumpRate).rounded(.down)
        let x = GameRules.riftJumpReach * metrics.scale
            * GameRules.jitter(step, salt: salt)
        let y = GameRules.riftJumpReach * metrics.scale
            * GameRules.jitter(step, salt: salt + 1)

        // Anywhere in its range, every frame, and the two plates roll
        // separately — so the pair flickers rather than pulsing together.
        let roll = (GameRules.jitter(step, salt: salt + 2) + 1) / 2
        let alpha = GameRules.riftFaintest + (1 - GameRules.riftFaintest) * roll

        return EffectSpriteView(
            effect: art,
            tileSize: metrics.tileSize,
            start: .distantPast,
            loops: true,
            clock: session.ambientClock(at:),
            blend: RiftPreviewDebug.shared.blend
        )
        .scaleEffect(x: 0.375 * width, y: 1.25 * length)
        .rotationEffect(.degrees(flipped ? 180 : 0))
        .rotationEffect(.degrees(tilt))
        .opacity(alpha)
        .offset(x: x, y: y)
        // Nothing about this may be smoothed by whatever is animating
        // elsewhere on the board. An eased jitter is a wobble.
        .transaction { $0.animation = nil }
    }

    // MARK: - Board layers

}
#endif
