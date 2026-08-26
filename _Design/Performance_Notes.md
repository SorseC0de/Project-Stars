# Astra performance — what is known

State: `a745266`. Debug and Release both build.

**Baseline: 60fps resting on Astra.** A 120fps reading was taken once, mid-
revision, and could not be reproduced — treat it as noise, not as a state to
get back to. Terra rests and runs far higher, which is the asymmetry to chase.

## Reproducible facts

Measured by the user, not inferred.

| Case | Result |
|---|---|
| Terra, Aries, full ZC, bloom **on**, running around | **90fps** |
| Astra, Aries, bloom off | low 40s moving |
| Astra, Aries, bloom **and** aura layers off | high 40s / low 50s |
| Astra, Libra, full ZC | **low 20s** — worst in the game |
| Astra, Cancer, moving in the **interior** | 50s |
| Astra, Cancer, running along **any wall** | 40s, occasionally 39 |
| Astra, Pisces, glowing effect every step, **6 ghosts** | 60fps |
| Astra, Virgo, 3 floating pins | 60fps, `ctx` past 2000 |
| Resting, corner, facing **out** | `ctx`/`psv` 720–730 |
| Resting, corner, facing **in** | `ctx`/`psv` 230–240 |

The two strongest signals: **Terra is roughly twice Astra**, and **the outer
ring costs more than the interior**.

## Ruled out, with the evidence

- **Astra's cloud canvases.** Every layer toggled off individually made no
  noticeable difference. (Claude proposed this twice and was wrong twice; the
  second attempt shipped a "smaller" band that measured *larger* than what it
  replaced — 532pt against 526pt.)
- **Passive context / passive list construction.** Cancer runs 1800–1900 `ctx`
  with *higher* fps than Aries at 1300. Virgo runs past 2000 at 60fps.
- **Afterimages.** Pisces holds 60fps with six of them plus an effect every step.
- **The charged bloom.** Aries is in the low 40s with `bloom: OFF`. Turning the
  aura layers off as well buys only a few frames.
- **Memoising `reachableSquares` / `availableDirections`.** Made it worse. See
  below.

## Two mistakes worth not repeating

1. **A cache on an `@Observable` class must be `@ObservationIgnored`.** Writing a
   stored property from inside a getter that views call while rendering tells
   every reader it is out of date — the read invalidates the reader, which
   re-renders and reads again. This halved the frame rate. Fixing the isolation
   did **not** restore the frames, which means the memoisation was not buying
   anything either.
2. **`PassiveContext`'s coin lists must stay eager.** Computing them on demand
   looks cheaper — few questions are about coins — but `Libra.swift:286` and
   `Aquarius.swift:342` read them inside a loop, so it becomes one filter per
   square.

## The methodological trap

**Every counter in this game measures view evaluations, i.e. frequency. None of
them measures cost.** `tick` goes *down* as the frame rate falls, because it is
reporting the display's own rate. Everything confirmed expensive this session —
an offscreen mask rasterisation, Gaussian blur passes, semi-transparent fill —
was invisible to all of them.

Do not infer a culprit from a counter. Either profile, or bisect by removal.

## Tools already built

- **`RenderTallyView`** — right edge. FPS, per-view tick counts, `g.*` gauges for
  every collection, `ctx`/`psv` for passive work, `nx.*` for the island.
- **`LayerBenchControls`** — folding bench, top screen, bottom-right. Astra:
  clouds, stars. Terra: scenery, tile edges. Both: ground, sparkles, fracture.
- **`AuraControls`** — same corner. `bloom` on/off, `ghosts` 0–6, glow radius,
  trail, and the Aquarius-only aura's layers/radius/opacity.

## Never tried

**Instruments' Time Profiler.** Ten seconds of Aries running along an Astra wall
would name the hot frame directly. Every attempt so far has been an inference
from frame-rate deltas, and every one has been wrong.

## Unrelated, still open

- Nexys goes invisible mid-transition between planes. Seven attempts. The offset
  is applied outside the board's placement and the flags read correctly; it is
  visible at both ends of the crossing and nowhere between.
- Terra pop-tiles are skewed and sit slightly low. Explicitly lowest priority.

## The measurement itself is suspect (2026-08-26)

Three findings that change how any of this should be read.

**`fracture` reads 0.** The board is no longer rebuilt at display rate — that fix
landed and worked. It did not move the frame rate, so the cost is elsewhere.

**The frame rate warms up.** On a fresh build: 15–20fps, then 30–40 after a
reset, then 50–60, then **120 resting and 60–90 moving** after a few minutes.
Then it fell back to 60/40–50 with the piece standing still. Nothing in the game
changed across any of that. This is compilation, image decoding and paging
settling — plus host contention, since testing happens in the canvas simulator.

**`FPS` cannot tell idling from struggling.** It is a `TimelineView`, so it
reports the *display's* rate, and iOS lowers that by itself when nothing is
asking to be drawn. Sixty resting may be a display idling with the board
genuinely still. The 60↔120 swing while stationary is consistent with adaptive
refresh, not with anything in the game.

So the readout now leads with **`worst NNms`** — the longest gap between two
frames in the last second. That is headroom, and it is unambiguous:

- 120Hz gives a frame 8.3ms; 60Hz gives 16.7ms.
- `worst 4ms` at 60fps = idling with room to spare.
- `worst 30ms` at 60fps = missing frames.

**Read `worst`, not `FPS`.** And take absolute numbers from a device, not the
canvas — an earlier session already found the canvas lagging where the device
did not.

## Ruled out: the cloud surfaces (2026-08-26)

`ONE canvas` — Astra's seven cloud canvases merged into one — measured **25/35
late against 22/35**. No change. The surface count was never the cost, and both
attempts to attack it were wrong.

What it does not rule out is the *redraw*. A `Canvas` is immediate mode: the
picture is discarded and remade every tick, one surface or seven. Merging them
changed how many surfaces were remade, not that they were.

Both planes drop frames while moving — Terra 20/45, Astra 25/35 — so this is not
an Astra problem with a local fix. It is the cost of rendering a game as a view
tree that is re-derived and diffed on every publish, ~24 times a second.

## The SpriteKit proof

`LayerBench.spritekit` swaps Astra's clouds for `CloudScene`, an `SKScene` hosted
in a `SpriteView`. Forty-nine nodes built once, drifted by an `SKAction` the
render thread interpolates, textures from the existing atlas with nearest
filtering, `zPosition` carrying the board's own row order.

Deliberately incomplete: no wake, no dip, no wear, no raised-square promotion. It
exists to answer one question — does a retained scene cost meaningfully less than
a redrawn one — and none of the missing parts change that answer.

Read `late` with it on and off, on Astra, while moving.

**First reading was invalid.** SpriteKit measured 25/30 against one-canvas'
20/40 — worse — because the scene was constructed inside `body`. That makes a
*new* scene on every body evaluation, and the board's body runs on every publish
of a move: forty-nine nodes rebuilt and forty-nine textures re-uploaded, roughly
twenty-four times a second. It measured the cost of building a scene, not of
having one. The scene is held in `@State` now.

**The lesson generalises.** Anything constructed in a SwiftUI `body` is
constructed every time that body runs, and in this codebase that is far more
often than it looks. It is the same fault as the caches that invalidated their
own readers, and the same fault as the timers rebuilt per row.

## The panel test was invalid, and so was the trail reading (2026-08-26)

`.opacity(0)` hides a view; it does not stop it existing. The panel kept
building its body and observing the session throughout, so blanking it measured
nothing. It unmounts now — input survives, because the keyboard shortcuts live
on `GameScreen` rather than on the panel. The instruments moved above it for the
same reason: they hung off the panel's own overlay.

`trail` cannot affect anything while `bloom` is off — `AuraStyle.glowTrail` is
only read inside the `PaletteGlow` branch, which is not taken. A reading that
moved when it was changed, and did not move back, was drift.

## What is actually established

**Idle is solved.** 0/61 late. Not one frame missed.

**Moving misses roughly half its frames, and nothing removed changes it.**
Ground off, clouds merged, clouds in SpriteKit, ghosts at zero, bloom off — each
of them worth a few frames at most, none of them the cause. With the ground off
the board is about ten objects and it is still 20/45.

Ten views cannot be a view-count problem. The cost does not scale with what is
drawn.

## The unexamined structure

`GameSession.engine` is a **struct** held as a property of an `@Observable`
class, and views read `session.engine.…` in seventy places across eight files.
With `@Observable` there is no granularity below the property: every
`engine.apply(event)` is a write to `engine`, and every write invalidates every
view that reads any part of it.

`apply` runs 36 times a second while moving. That is 36 whole-tree
invalidations a second, independent of what is on the board — which fits every
measurement here, including why removing views never helps.

The `publish()` pattern that would fix this already exists and was never
finished: `zodiactionMeter`, `purse` and a few others are republished as narrow
properties, while everything else reads the engine directly.

## Answered (2026-08-26)

| board | late | fps |
|---|---|---|
| SwiftUI | 28/35 | 35 |
| SwiftUI, ground off (≈10 objects) | 20/45 | 45 |
| **SpriteKit scene** | **3–10/58–60** | **60** |

The scene draws *more* than the ground-off board — full ground on both planes,
the island, the coins — and misses a twentieth of the frames instead of four
fifths.

**The cost was never what is drawn.** It was the view tree: described from
scratch on every publish, then diffed and laid out. That is why removing the
ground, the panel, the clouds, the trail, the glow and seven cloud canvases each
bought a few frames and none of them fixed it, and why no counter ever saw it —
every counter here measures view evaluations, and the cost is what SwiftUI does
*with* them.

The remaining three to ten late frames are almost certainly the panel and the
overlays, which are still SwiftUI and still rebuild on every publish. Much
smaller, and addressable separately from the port.
