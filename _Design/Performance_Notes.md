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
