//
//  Fracture.metal
//  Project Stars
//
//  The world seen through a Fracturing Fissure.
//

#include <metal_stdlib>
using namespace metal;

/// Ripples the whole board while Gemini is in two places.
///
/// ## Why the offset is whole art pixels
///
/// Because everything on screen is a sixteen-pixel drawing scaled up by a whole
/// number, and a warp measured in *points* moves things by fractions of an art
/// pixel. The sampler then has to invent what sits between two pixels that were
/// drawn to be adjacent, and every sprite on the board goes soft — which is the
/// one thing this game's rendering is built to never do.
///
/// So the wave is computed in art-pixel space, rounded, and applied in whole
/// pixels. The result steps rather than slides, and it should: an unstable tear
/// in the world has no business looking smooth, and a chunky ripple reads as
/// *glitch* where a silky one reads as *underwater*.
///
/// ## Why two waves per axis
///
/// One sine is a flag in the wind. Two at frequencies that do not divide into
/// each other never repeat within a screen, so the board never shows the viewer
/// a pattern to lock onto — which is most of what makes this read as unstable
/// rather than as decorative.
///
/// The two axes are deliberately unequal: the horizontal wave is roughly twice
/// the vertical one, because a board that shears sideways reads as a reflection
/// coming apart, and one that bobs evenly in both reads as water.
///
/// - Parameters:
///   - time: Seconds, from the ambient clock — so the ripple freezes with
///     everything else when the game stops to ask the player something.
///   - amplitude: How far the world moves at full lean, in **art pixels**.
///     Ramped by the caller, so entering and leaving the split is a fade rather
///     than a switch.
///   - pixel: Points per art pixel, which is what puts the wave in the art's own
///     coordinates instead of the device's.
[[ stitchable ]]
float2 fractureWarp(float2 position, float time, float amplitude, float pixel) {
    if (amplitude < 0.001 || pixel < 0.001) { return position; }

    float2 art = position / pixel;

    float2 wave;
    wave.x = sin(art.y / 6.0 + time * 1.7)
           + sin(art.y / 17.0 - time * 0.9) * 0.6;
    wave.y = sin(art.x / 9.0 - time * 1.3) * 0.5
           + sin(art.x / 23.0 + time * 0.7) * 0.35;

    // Rounded *after* scaling, so a low amplitude spends most of its time at
    // zero and snaps to one pixel at the crests. That is what keeps a subtle
    // setting subtle: the alternative is a wave that is always displacing
    // something, which at this size is a board that never sits still.
    float2 offset = round(wave * amplitude);

    return position + offset * pixel;
}
