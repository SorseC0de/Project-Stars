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
