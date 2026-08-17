# Project Stars Pisces Rework

> The agreed Pisces rework — bubbles replace ZC drain on Terra, movement is restricted instead, and falling scatters your meter.


Designed and **built** 2026-08-14. Supersedes an earlier rework that was built
the same day (+1 ZC per Astra step, surf gated on a full meter) — see "State of
the code" below.

## Which passive owns what

The new behaviour **replaces** the old, it does not sit beside it.

- **Gaia Geyser** — the spill, and nothing else. Its droplet ring on arrival is
  gone.
- **Arid Aquanaut** — the movement lock and the bubble spawn. Its Z-Charge /
  Astral Tear weight swap and the larger Terra grant are gone.
- **Starstream Surfer** — the full-meter gate on multi-tile movement, and +1 ZC
  per Astra step. The Terra pip-per-move drain is gone.

## Arid Aquanaut, on Terra

- **No ZC drain at all.** The pip-per-move toll is gone.
- Instead it **disables all multi-tile movement** for Pisces on Terra — Astral
  Brook and the rest. One tile per move, on activation.
- It enables **bubbles** to spawn from the **glow phase**. Terra only — Pisces
  does **not** spawn bubbles on Astra.
- **Z-Charge stays out of the item pool**, and on Terra Pisces **cannot gain ZC
  from anything except bubbles and the Pentacle-guess mechanic**.

The **+1 ZC per step is Astra-only** and survives this rework — on Astra the fish
pulls charge out of the air, and below it has only water.

## TODO: bubbles were never meant to be Pisces'

**Pisces was never intended to have bubbles of any kind** — the sign is
droplets, puddles and geysers. Bubbles were used because bubble **assets already
existed**, and it was rolled with for now. **Eventually all of it will be
converted.**

Cancer, meanwhile, wants *more* use of bubbles — see
[[project-stars-cancer-rework]] — so the two may simply trade.

## Bubbles

A spawn category of their own, **no longer tied to Pentacles**. A Pentacle and a
bubble can appear in the same reveal phase, on different tiles.

- Worth **1 ZC**, or **3** if sniped via the Pentacle-guess mechanic (+2).
- Drop rate is affected by **Sagittarius' luck passive**.
- A single glow phase can produce **two bubbles and two Pentacles** — which
  matters for Leo.
- Bubbles **do not** follow the "taking one pops the rest" rule that Pentacles do.

## Falling from Astra to Terra

Any fall **outside of Zodiaction use** turns your ZC into bubbles that **scatter
like Sonic rings** — flying off to random tiles across the map.

- The **fire evaporation rule** applies to them.
- A bubble is **destroyed** if its destination tile is a hole.

## The slide — settled and built

**Not plane-dependent — state-dependent.** *Gold* means **a full meter**, which
is what makes every sign gold. So:

> **Multi-tile movement requires a full meter, on both planes.**

Arid Aquanaut's "one tile per move" on Terra is simply what not-being-gold looks
like down there. Going gold is what lifts it. The plane never enters the test —
Terra's dryness shows up as how hard it is to *get* gold, not as a second rule
about where you may surf.

This part **is built**: `PiscesStarstreamSurfer.adjustedMovement` now filters the
wall-reaching option whenever the meter is short of its cap, on either board.

## State of the code

Already built and **kept**: `starstreamStepCharge` (1 ZC per ordinary Astra
step, Astra-only), the surf paying nothing itself, the full-meter gate on
multi-tile movement across both planes, and `PassiveContext.zodiactionMeterMax`
which that gate reads.

All of it is now built:

- `PickupClass.scatter` — a third class beside pentacle and boon. Several on the
  board at once, and taking one leaves the rest.
- `PickupID.bubble` / `BubbleEffect` — weight 0, never rolled into the hunt.
- `PickupContext.takenOnRevealTile`, mirrored from a new
  `GameEngine.pickupRevealedThisMove`, is how the snipe bonus is known.
- `ZodiacPassive.bubbleChance(context:)` — Arid Aquanaut answers on Terra; the
  engine rolls per bubble in `revealBubbles`, scaled by the run's `luck`, which
  is how Sagittarius reaches them.
- `ZodiacPassive.spillsMeterOnDescent(context:)` — answered by **Gaia Geyser** — and
  `GameEngine.scatterMeterAsBubbles(landingOn:)` — one bubble per pip, placed on
  random free squares of the plane below; a pip whose square is a hole is lost.
- `GameEngine.popBubbles` hangs off `burnOffPools`, so anything that would have
  damaged the square bursts the bubble on it. No droplet is left behind.
- Arid Aquanaut: Z-Charge weight is **0** on Terra (the Tear absorbs it) and
  `chargeFromPickup` is gone; the pip-per-move drain is deleted from
  `PiscesStarstreamSurfer.meterBonus`.

Also live: a `[zc]` DEBUG log in `GameSession.logMeter` printing every meter
change, added to diagnose whether Terra grants were landing. Delete it once this
lands.

See [[project-stars-goal]] and [[project-stars-architecture]].
