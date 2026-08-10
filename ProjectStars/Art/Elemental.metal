//
//  Elemental.metal
//  Project Stars
//
//  One shader, four elements. Placeholder VFX until the real sprites arrive.
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>

using namespace metal;

// MARK: - Helpers

/// Cheap deterministic hash. No texture lookups, no noise table — this runs over
/// a board-sized rectangle for a fraction of a second and does not need to be
/// good, only stable.
static float hash21(float2 p) {
    p = fract(p * float2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

/// Value noise built from the hash above, smoothed across the cell.
static float valueNoise(float2 p) {
    float2 cell = floor(p);
    float2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);

    float a = hash21(cell);
    float b = hash21(cell + float2(1.0, 0.0));
    float c = hash21(cell + float2(0.0, 1.0));
    float d = hash21(cell + float2(1.0, 1.0));

    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

/// A soft expanding ring: brightest exactly on the wavefront, dark either side.
static float wavefront(float distance, float front, float thickness) {
    return smoothstep(thickness, 0.0, abs(distance - front));
}

/// Fades a burst in fast and out slowly, so it reads as an impact rather than a
/// pulse. `t` runs 0 → 1 over the effect's lifetime.
static float envelope(float t) {
    return smoothstep(0.0, 0.12, t) * (1.0 - smoothstep(0.35, 1.0, t));
}

// MARK: - Elemental burst

/// A single burst, tinted and shaped by `element`.
///
/// Deliberately one entry point rather than four: every element wants the same
/// expanding-wavefront skeleton, and keeping them together makes them read as one
/// family. Swap the branch bodies freely — nothing outside this file depends on
/// how any of them look.
///
/// - Parameters:
///   - position: Pixel position, in the effect rect's own space.
///   - color: The source colour. Ignored; the burst is drawn from scratch.
///   - center: Where the burst originates, same space as `position`.
///   - radius: How far it reaches, in points.
///   - t: Progress, 0 → 1.
///   - element: 0 fire, 1 water, 2 air, 3 earth. Matches
///     `ZodiacElement.shaderIndex`.
[[ stitchable ]]
half4 elementalBurst(
    float2 position,
    half4 color,
    float2 center,
    float radius,
    float t,
    float element
) {
    float2 delta = position - center;
    float distance = length(delta) / max(radius, 1.0);

    // Past the reach of the burst there is nothing to draw.
    if (distance > 1.2) {
        return half4(0.0h);
    }

    float angle = atan2(delta.y, delta.x);
    float front = t * 1.05;
    float fade = envelope(t);

    float3 tint = float3(1.0);
    float intensity = 0.0;

    int kind = int(element + 0.5);

    if (kind == 0) {
        // Fire — a ragged front that licks upward and flickers as it goes.
        float lick = valueNoise(float2(angle * 3.0, t * 6.0 - distance * 5.0));
        float upward = 0.5 - 0.5 * normalize(delta + float2(0.0, 0.001)).y;
        float edge = wavefront(distance, front * (0.85 + 0.25 * lick), 0.30);

        intensity = edge * (0.55 + 0.75 * lick) * (0.6 + 0.8 * upward);
        // Hot core through to a cooler rim.
        tint = mix(float3(1.0, 0.28, 0.08), float3(1.0, 0.86, 0.35), saturate(1.0 - distance * 1.3));

    } else if (kind == 1) {
        // Water — concentric ripples chasing the leading edge outward.
        float ripples = 0.0;
        for (int i = 0; i < 3; ++i) {
            float offset = float(i) * 0.16;
            ripples += wavefront(distance, front - offset, 0.10);
        }
        intensity = ripples * 0.7;
        tint = mix(float3(0.25, 0.75, 1.0), float3(0.65, 0.98, 0.95), saturate(distance));

    } else if (kind == 2) {
        // Air — thin streaks spiralling out, thinning as they widen.
        float swirl = angle * 2.5 + distance * 7.0 - t * 9.0;
        float streaks = pow(saturate(sin(swirl) * 0.5 + 0.5), 6.0);
        float edge = wavefront(distance, front, 0.42);

        intensity = streaks * edge * 1.1;
        tint = float3(0.85, 0.95, 1.0);

    } else {
        // Earth — a blooming flower: lobed petals opening from the centre.
        float petals = pow(saturate(cos(angle * 6.0) * 0.5 + 0.5), 2.0);
        float bloom = smoothstep(front, front - 0.55, distance);
        float rim = wavefront(distance, front * 0.9, 0.20);

        intensity = bloom * (0.35 + 0.65 * petals) + rim * 0.5;
        tint = mix(float3(0.45, 0.85, 0.35), float3(0.90, 0.75, 0.35), saturate(distance * 1.2));
    }

    float alpha = saturate(intensity * fade);

    // Premultiplied, which is what SwiftUI expects back from a colour effect.
    return half4(half3(tint * alpha), half(alpha));
}
