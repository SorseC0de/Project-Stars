//
//  AquariusStormFilm.swift
//  Project Stars
//
//  The storm, rendered once and played back.
//

import SpriteKit
import SwiftUI

/// Frames of the storm, drawn off-screen and kept.
///
/// ## Why this exists
///
/// The assembly is a stack of blurred, blended layers, and every one of them is
/// re-rendered on every frame. Flattening it into a single texture fixed the
/// cost of *compositing* them, but not the cost of drawing them — and a texture
/// is only reused while nothing under it changes, so the moment the piece starts
/// moving it is rebuilt sixty times a second. That is the difference between a
/// storm standing still and a storm crossing the board.
///
/// The way out is the one the rest of the game already uses: it is a sprite
/// strip. The look is settled, so the frames can be drawn once and played like
/// any other effect — at which point Aquarius costs what Aries costs.
///
/// ## What it is not
///
/// It is not eleven strips built at launch. Each phase is rendered the first
/// time it is asked for, because a run only ever passes through the phases it
/// passes through, and rendering the ten a player never sees is a stall for
/// nothing.
@MainActor
@Observable
final class AquariusStormFilm {

    /// One entry per phase asked for so far.
    private var reels: [Int: [Image]] = [:]

    /// The same frames, cut for the scene.
    ///
    /// **Rendered once, used twice.** The board is drawn either as views or as
    /// nodes, and filming the storm twice would be filming it twice — twenty
    /// four `ImageRenderer` passes apiece, for two copies of one picture. So
    /// the reel is drawn once and each renderer takes the form it can use.
    private var cuts: [Int: [SKTexture]] = [:]

    /// The eyes, at a ladder of glow steps, per phase.
    ///
    /// The pair burns up and out over six and a half seconds — the blur
    /// *radius* grows with the glow, not just its brightness, so a single
    /// drawing faded up and down cannot say it. Each step is its own small
    /// render, drawn the first time that phase is asked for, and there are few
    /// enough of them that the whole ladder is cheaper than one frame of the
    /// funnel.
    private var eyes: [Int: [SKTexture]] = [:]

    /// Phases already being drawn, so a second ask does not start again.
    private var underway: Set<Int> = []

    /// The frames for `phase`, or `nil` while they are being drawn.
    ///
    /// Returning `nil` rather than blocking is what keeps the first frame of a
    /// new phase from being a stutter: the caller falls back to drawing the
    /// storm live for the moment it takes, which is the exact thing being
    /// optimised away and so is affordable once.
    func reel(for phase: Int) -> [Image]? { reels[phase] }

    /// The same frames as textures, or `nil` while they are being drawn.
    func cut(for phase: Int) -> [SKTexture]? { cuts[phase] }

    /// The eyes' glow ladder for `phase`, dimmest first.
    func glow(for phase: Int) -> [SKTexture]? { eyes[phase] }

    /// How many steps the ladder has. Twelve over a six-and-a-half second
    /// pulse is a step every quarter second, which is under what the eye
    /// resolves as a change in a soft shape.
    static let glowSteps = 12

    /// Drops reels more than one phase away from `phase`.
    ///
    /// A reel is twenty-four rendered frames, and a run that climbs to ten
    /// leaves ten of them alive at once — all of them mounted, because the
    /// phases are stacked so the visible one can cut rather than dissolve. That
    /// is what turned a storm into a slideshow the further a run got.
    ///
    /// One either side, because those are the two the meter can reach next and
    /// re-filming on arrival is the stutter this whole class exists to avoid.
    /// The current phase is never dropped.
    func forget(farFrom phase: Int) {
        for stage in reels.keys where abs(stage - phase) > 1 {
            reels[stage] = nil
            cuts[stage] = nil
            eyes[stage] = nil
        }
    }

    /// Draws `phase` if it has not been drawn yet.
    func prepare(_ phase: Int, side: CGFloat, scale: CGFloat) {
        guard phase > 0, reels[phase] == nil, !underway.contains(phase) else { return }
        underway.insert(phase)

        Task { @MainActor in
            var frames: [Image] = []
            var cut: [SKTexture] = []
            frames.reserveCapacity(GameRules.aquariusStormFilmFrames)
            cut.reserveCapacity(GameRules.aquariusStormFilmFrames)

            for step in 0..<GameRules.aquariusStormFilmFrames {
                let moment = GameRules.aquariusStormFilmPeriod
                    * Double(step) / Double(GameRules.aquariusStormFilmFrames)

                let renderer = ImageRenderer(
                    content: AquariusStormStill(phase: phase, at: moment, side: side)
                )
                // Rendered at the screen's own scale, so a strip drawn for a
                // board does not come back soft on it.
                renderer.scale = scale
                renderer.isOpaque = false

                if let image = renderer.uiImage {
                    frames.append(Image(uiImage: image))
                    let texture = SKTexture(image: image)
                    // Not nearest: this is a *rendered* frame of blurred,
                    // blended plates rather than a drawing, so there are no art
                    // pixels in it to preserve and snapping to them would only
                    // stipple the soft edges the whole assembly is made of.
                    cut.append(texture)
                }

                // A frame at a time, so drawing a phase never holds a turn up.
                // Eleven of these at once would be a visible stall; one per
                // pass through the loop is invisible.
                await Task.yield()
            }

            reels[phase] = frames
            cuts[phase] = cut
            eyes[phase] = Self.glowLadder(phase: phase, scale: scale)
            underway.remove(phase)
        }
    }

    /// The eye pair drawn at each step of its burn, for one phase.
    ///
    /// The size and the haze are the phase's and do not move; only the glow
    /// does. Built at the canvas's own proportions — `FloatingAquarius` sizes
    /// them against three hundred like everything else inside the assembly —
    /// so the scene can scale the whole ladder by the same number it scales
    /// the funnel by.
    private static func glowLadder(phase: Int, scale: CGFloat) -> [SKTexture] {
        let strength = Double(min(max(phase, 0), 10)) / 10
        let shrink = GameRules.aquariusFigureShrink
            + (1 - GameRules.aquariusFigureShrink) * CGFloat(strength)
        let haze = GameRules.aquariusEyeHaze
            * CGFloat(max(strength * 10 - 1, 0) / 9)

        // Room for the bloom at its widest, which reaches well past the shapes
        // themselves — cut to the pair's own size, the halo is clipped square.
        let box = CGSize(width: 240, height: 240)

        return (0..<glowSteps).compactMap { step in
            let burn = GameRules.aquariusEyeGlowPeak
                * CGFloat(step) / CGFloat(glowSteps - 1)

            let renderer = ImageRenderer(
                content: StormEyes(
                    width: 40 * shrink,
                    spacing: 46 * shrink,
                    glow: burn,
                    haze: haze
                )
                    .frame(width: box.width, height: box.height)
            )
            renderer.scale = scale
            renderer.isOpaque = false

            return renderer.uiImage.map { SKTexture(image: $0) }
        }
    }

    /// The box the ladder is drawn in, in canvas points. See `glowLadder`.
    static let glowBox: CGFloat = 240
}

/// The **funnel** at one fixed moment, with nothing running.
///
/// The figure is deliberately not in here. Caching the whole assembly flattened
/// the two things it is made of into one, and they want opposite treatment:
///
/// - The storm is thirteen blurred, blended plates shaking on periods of about
///   a second. It is nearly all of the cost and none of it is worth watching
///   closely, so a two-second loop is indistinguishable from the real thing.
/// - The figure is one sprite and four small shapes, turning over five seconds,
///   rising over four and breathing over another, with eyes that swell to white
///   over six and a half. It is almost free to draw and the slowest thing on
///   screen — so a two-second loop is exactly where it falls apart.
///
/// So the funnel is filmed and the figure is live. That is the whole trick, and
/// it costs a fraction of what the storm did while keeping the parts a player
/// actually looks at.
struct AquariusStormStill: View {

    let phase: Int
    let at: TimeInterval
    let side: CGFloat

    var body: some View {
        AquariusStorm(phase: phase, frozenAt: at, side: 300, scale: 4)
            .frame(width: side, height: side)
    }
}
