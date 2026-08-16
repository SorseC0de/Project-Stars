//
//  AquariusStormFilm.swift
//  Project Stars
//
//  The storm, rendered once and played back.
//

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

    /// Phases already being drawn, so a second ask does not start again.
    private var underway: Set<Int> = []

    /// The frames for `phase`, or `nil` while they are being drawn.
    ///
    /// Returning `nil` rather than blocking is what keeps the first frame of a
    /// new phase from being a stutter: the caller falls back to drawing the
    /// storm live for the moment it takes, which is the exact thing being
    /// optimised away and so is affordable once.
    func reel(for phase: Int) -> [Image]? { reels[phase] }

    /// Draws `phase` if it has not been drawn yet.
    func prepare(_ phase: Int, side: CGFloat, scale: CGFloat) {
        guard phase > 0, reels[phase] == nil, !underway.contains(phase) else { return }
        underway.insert(phase)

        Task { @MainActor in
            var frames: [Image] = []
            frames.reserveCapacity(GameRules.aquariusStormFilmFrames)

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
                }

                // A frame at a time, so drawing a phase never holds a turn up.
                // Eleven of these at once would be a visible stall; one per
                // pass through the loop is invisible.
                await Task.yield()
            }

            reels[phase] = frames
            underway.remove(phase)
        }
    }
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
