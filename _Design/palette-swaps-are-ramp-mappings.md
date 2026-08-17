# Palette Swaps Are Ramp Mappings

> A palette swap maps one ramp onto another — order and anchoring matter more than which colours are picked.


In Project Stars, a `PaletteSwap` set is a **mapping between ramps**, not a
choice of nice colours. Three rules, all learned the hard way:

1. **Order the target like the source**, lightest to darkest. A target ramp
   sorted differently turns a rounded shape inside out — darker tones land as
   highlights and lighter ones as shadows.
2. **Ask which ramp you are actually swapping.** Sprite sheets with light/dark
   variants are *different ramps*, not one drawing at two brightnesses — the
   same palette entry can be the shadow on one row and the highlight on the
   other, so a single table is wrong somewhere by construction.
3. **A degraded thing must stay recognisably the same thing.** Hold one tone —
   usually the shadow — and move only the outline and highlight. Replacing all
   three makes a new object rather than a damaged one.

**Why:** These are failures no amount of re-picking colours fixes, because the
error is in the mapping rather than in the hues. Astra's damaged clouds went
through orange, grey and red before the actual bug turned out to be one table
serving two ramps plus every tone being replaced at once.

**How to apply:** Sample the real art before writing a swap — perimeter pixels
give the outline, pixel counts give body vs shadow. Never infer a ramp from
colour names. See `GameRules.cloudWearSwaps` and the note on
`SmokeSpriteView.cloudSwaps`. Related: [[project-stars-architecture]],
[[canvas-to-view-glow-translation]].
