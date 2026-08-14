//
//  PaletteFX.metal
//  Project Stars
//
//  Recolouring and glow, done per palette entry rather than per sprite.
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>

using namespace metal;

/// How close two colours must be to count as the same palette entry.
///
/// The art is indexed, so a match should be exact — but the colour makes a trip
/// through `Color` → `UIColor` → floats on the way in, and sRGB conversion can
/// shift a channel by a fraction of a step. Loose enough to survive that, far
/// tighter than the gap between any two entries in a 47-colour palette.
constant float kPaletteEpsilon = 0.02;

/// Undoes premultiplication so a colour can be compared against a palette entry.
///
/// SwiftUI hands `colorEffect` premultiplied colours. Comparing those directly
/// would only match at full opacity — every antialiased or faded pixel would
/// silently miss.
static float3 straightColor(half4 color) {
    return float3(color.rgb) / max(float(color.a), 0.0001);
}

/// Replaces specific palette entries with others.
///
/// `pairs` is flat: from-r, from-g, from-b, to-r, to-g, to-b, repeating. Anything
/// not listed passes through untouched, so a partial mapping recolours part of a
/// sprite and leaves the rest alone.
///
/// This is how the Shadow Pentacle exists at all — it is the gold coin with five
/// entries swapped, not a second sheet to keep in step with the first.
[[ stitchable ]]
half4 paletteSwap(
    float2 position,
    half4 color,
    device const float *pairs,
    int count
) {
    if (color.a < 0.004h) { return color; }

    float3 rgb = straightColor(color);

    for (int i = 0; i + 5 < count; i += 6) {
        float3 from = float3(pairs[i], pairs[i + 1], pairs[i + 2]);
        if (distance(rgb, from) < kPaletteEpsilon) {
            float3 to = float3(pairs[i + 3], pairs[i + 4], pairs[i + 5]);
            return half4(half3(to * float(color.a)), color.a);
        }
    }
    return color;
}

/// Keeps only the listed palette entries, discarding everything else.
///
/// `keys` is flat: r, g, b, repeating.
///
/// On its own this is not a glow — it is the *mask* a glow is built from. Blur
/// the result and composite it additively over the original and only those
/// entries light up, which is what "isolated add blending" means: the highlights
/// bloom, the body of the sprite does not.
[[ stitchable ]]
half4 paletteGlowMask(
    float2 position,
    half4 color,
    device const float *keys,
    int count
) {
    if (color.a < 0.004h) { return half4(0.0h); }

    float3 rgb = straightColor(color);

    for (int i = 0; i + 2 < count; i += 3) {
        float3 key = float3(keys[i], keys[i + 1], keys[i + 2]);
        if (distance(rgb, key) < kPaletteEpsilon) { return color; }
    }
    return half4(0.0h);
}

/// Keeps only the pixels bright enough to be a light source, in their own
/// colours.
///
/// ## Why this replaced the colour-list mask
///
/// `paletteGlowMask` above takes a list of palette entries and keeps exactly
/// those. It is precise and it was the wrong tool: every glowing thing in the
/// game had to be handed a list of the colours *it happened to be drawn in*, so
/// a list that was slightly wrong produced a glow of the wrong hue, and a list
/// naming a colour the art did not contain produced no glow at all. Both
/// happened repeatedly, and neither is visible in the code — you have to run it
/// and look.
///
/// Brightness needs no list. A sprite's own bright pixels are what would emit
/// light if the thing were real, and they are already the right colour, so the
/// glow of anything is simply *itself, thresholded*. Gold coins bloom gold and
/// blue clouds bloom blue without anybody choosing.
///
/// Perceptual luminance rather than a flat average: at equal numbers a green
/// reads far brighter than a blue, and a mask that disagrees with the eye about
/// what is bright is a mask that has to be argued with per sprite — which is the
/// problem being removed.
[[ stitchable ]]
half4 luminanceGlowMask(float2 position, half4 color, float threshold) {
    if (color.a < 0.004h) { return half4(0.0h); }

    float3 rgb = straightColor(color);
    float luma = dot(rgb, float3(0.2126, 0.7152, 0.0722));

    if (luma < threshold) { return half4(0.0h); }

    // Weighted by how far past the threshold it is, so the brightest pixels
    // carry the glow and the merely light ones only tint it. A hard cut makes
    // every lit pixel equal and the bloom comes out as a flat silhouette.
    float weight = (luma - threshold) / max(1.0 - threshold, 0.001);
    return half4(color.rgb * half(weight), color.a * half(weight));
}

/// Sprinkles moss over a sprite, on whole art pixels, deterministically.
///
/// `args` is self-describing so one array carries two lists: the first float is
/// how many moss colours follow, then that many r,g,b triples, then the r,g,b of
/// every colour that must be left alone.
///
/// ## Why this is generated rather than drawn
///
/// The stone variant of a piece is its gold sheet recoloured, and three of those
/// recoloured entries also carry scattered moss. A palette swap cannot express
/// that: the mossy pixels are the *same source colour* as their neighbours, so
/// no colour-matching rule can tell six pixels from the fifty beside them. What
/// distinguishes them is where they sit — low, and toward the edges, where damp
/// collects.
///
/// So the moss is placed rather than matched. The hash is seeded per piece and
/// keyed on the art pixel, which makes it stable frame to frame — moss that
/// crawled would be worse than no moss — and different for every sign without
/// anyone drawing it.
[[ stitchable ]]
half4 paletteMoss(
    float2 position,
    half4 color,
    float2 viewSize,
    float2 artSize,
    float seed,
    float coverage,
    device const float *args,
    int count
) {
    if (color.a < 0.004h || count < 1) { return color; }

    float3 rgb = straightColor(color);

    // Reserved entries are never overgrown. The gem is the piece's eye, and moss
    // creeping over it would put out the one pixel that has to stay readable.
    int mossCount = int(args[0]);
    int keepStart = 1 + mossCount * 3;
    for (int i = keepStart; i + 2 < count; i += 3) {
        float3 keep = float3(args[i], args[i + 1], args[i + 2]);
        if (distance(rgb, keep) < kPaletteEpsilon) { return color; }
    }
    if (mossCount < 1) { return color; }

    // Quantise to the art grid, so moss lands on whole pixels rather than being
    // smeared across the magnified edges of one.
    float2 cell = floor(position / (viewSize / artSize));

    // Two independent hashes: one decides whether this pixel is overgrown, the
    // other which green it takes.
    float roll = fract(sin(dot(cell, float2(12.9898, 78.233)) + seed) * 43758.5453);
    float pick = fract(sin(dot(cell, float2(39.3468, 11.135)) + seed * 1.7) * 24634.6345);

    // Damp collects low and at the edges. `bias` runs 0 at the top middle to 1
    // at the bottom corners, so the same coverage reads as overgrowth creeping
    // up rather than as noise sprayed evenly over the sprite.
    float down = cell.y / max(artSize.y - 1.0, 1.0);
    float out = abs(cell.x / max(artSize.x - 1.0, 1.0) - 0.5) * 2.0;
    float bias = clamp(down * 0.75 + out * 0.45, 0.0, 1.0);

    if (roll > coverage * bias) { return color; }

    int index = clamp(int(pick * float(mossCount)), 0, mossCount - 1);
    float3 moss = float3(args[1 + index * 3], args[2 + index * 3], args[3 + index * 3]);
    return half4(half3(moss * float(color.a)), color.a);
}
