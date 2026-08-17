# Project Stars Aquarius Rework

> The Aquarius rework — floats over holes, holes become currents, and everything about the sign runs backwards.


Designed 2026-08-15. **Not built**, and **queued ahead of the Gemini rework** —
it is the cheaper build of the two. Aquarius was judged the most boring sign on
the roster; this is the fix.

## The one idea

**Aquarius is reversed, in every dimension.** Controls, wear timing, charge. One
sentence teaches the sign, and every instinct built on the other eleven points
the wrong way.

## The names

- **Wacky Whirlwind** — the passive that grants the reversed everything *and*
  the tornado body.
- **Crazy Current** — the passive that floats them over holes and turns holes
  into chutes.
- **Waterbearer Wipeout** — the Zodiaction.

The Pentacle formerly called **Corner Current** is renamed **Corner-Cut** to
clear the collision, and its summary now says *gust* rather than *current*.
Renamed in code 2026-08-15.

## Crazy Current — the passive

- **Aquarius cannot fall into holes at all.** They float.
- Instead, **a hole is a chute**: stepping onto one carries you on **in the
  direction you were already moving**, square after square, for as long as the
  next square is also a hole. Chutes and Ladders.
- **A chain that ends at the board edge is death** — you die by going *off the
  sides*, which is the only way Aquarius dies.
- The piece **spins and bobs** while being carried, which says *you are not
  driving any more* in a way a fast slide would not.

### Straight only — never bending

The current continues in a straight line and stops at the first square that is
not a hole. **Do not make it follow the chain around corners.**

The reason is not simplicity, it is that straight-line is a **total** rule: it
has a defined answer for every board state, including a 2×3 blob or a branch,
because "keep going while the next square is a hole" never has to choose. A
bending current is partial — the moment two holes are both adjacent it needs a
tiebreaker, and any tiebreaker is a rule the player must learn that is not
visible on the board. Straight-line can be traced by eye from where you stand,
which is what makes stepping in a *commitment* rather than a gamble.

### Why the current is the real cost

Not the reversed controls. **Turn-based takes the teeth out of control
inversion** — in an action game inversion costs *reaction*, but here the player
can stare at the board as long as they like, so it only ever costs *recall*, and
recall is a one-time purchase. An hour in it is free.

Losing control of where you end up is positional, and no amount of familiarity
gives it back. The current is also what restores the sign's **clock**: without
hole-death, a careful Aquarius would have no fail state at all and the run would
have no natural end. The more the board breaks, the more of it is uncontrollable
transport, and the edge comes to *you*.

The Nexys chasm is a permanent hole at the centre of every board, so Aquarius
always has one live current from turn one, on the square everything else is
arranged around.

## Reversed charge

Aquarius **starts at full ZC and must reach 0 to fire**, and firing returns them
to full. Every ZC gain elsewhere is a ZC *loss* here, so the reveal-tile pip,
element affinity and Z-Charge all move Aquarius toward firing exactly as they
move everyone else — the hunt is structurally identical, just displayed
backwards. The planned anti-ZC item becomes the sign's best find.

### How to build it: a display inversion and nothing else

Store the meter as **readiness**, not as ZC. Then:

| | every sign | Aquarius |
|---|---|---|
| starts at | readiness 0 | readiness 0, *shown as* full ZC |
| a reveal pip | +1 readiness | +1 readiness, *shown as* −1 ZC |
| can fire at | max readiness | max readiness, *shown as* 0 ZC |
| firing resets to | readiness 0 | readiness 0, *shown as* full ZC |

Displayed ZC is `max - readiness` for this one sign. **No charge source, passive,
gate or `isZodiactionReady` needs to know Aquarius exists**, and the "gold means a
full meter" rule that Pisces' surf is gated on keeps working untouched. The
entire "starts full and drains away" fiction is presentational.

## The look

The piece is **wrapped in cloud, mist or storm pouring from the jar** (the jar is
the statue). The storm **thins as ZC falls**, revealing the piece fully at 0 —
which is the moment they can fire.

The meter is drawn on the piece rather than in the HUD, like Umbra's gold body.
Better than a bar here, because *less on the piece meaning closer to ready*
teaches the inversion with no explanation at all.

### The bluff

At **full ZC** the storm is a **big ominous tornado, throwing a large shadow,
with glowing eyes inside it**.

At **0 ZC** the statue is revealed: **a little gold pot with the chibi eyes
previously drawn for Nilyth**, and **Aquarius is half the size of an average
piece** — secretly the smallest piece in the game.

Firing restores the projection: pop the Zodiaction and the tornado rushes back
in over the pot.

This is the sign's inversion applied to its own presence: **how frightening it
looks runs opposite to how dangerous it is.** Scariest at full ZC, which is
exactly when it cannot fire; harmless at zero, which is when it is about to.

### How many sprites

Three would do — **scary tornado, teen tornado, revealed pot** — stepped at
10-6 / 5-1 / 0. Four or five would be better, and the reason is *where* the
stages go rather than how many there are: a distinct stage is worth most where
the player's decisions are tightest, which is near firing. At the top of the
meter there is nothing to decide, so five turns of identical tornado costs
nothing; at the bottom, one turn of difference is the whole question. Bias the
thresholds low — more art near 0, less near full.

There is also a free source of fine-grained feedback: the **shadow can shrink
continuously with readiness** even while the sprite steps in three. That reads
as a smooth transformation without drawing a frame for it.

The **shadow does the honest reporting** while the storm lies — a large shadow
under the tornado, a small one under the pot. Mechanically the size changes
nothing about grid rules; `PieceShadowView` already takes a `widthFraction`, so
the smaller footprint costs nothing to express.

## Waterbearer Wipeout — the Zodiaction

Named **Waterbearer Wipeout**. (The passive naming shortlist was *Unburdened
Updraft* / *Unburdened Undine* / *Unburdening Undulation* — Updraft was
preferred, since Undine is a **water** elemental that fights both the air sign
and the floating, and *Undulation* names the motion but not the release.)

**Open:** what it actually does. The current teleport is a leftover, not a
statement. The shape the design points at is that everything shed over the run
comes back at once — a big storm splurting out of the jar across the board.

## Visual references

- **Cloudians**, from Yu-Gi-Oh — the archetype the storm-with-something-small-
  inside look is aiming at.
- A similar archetype from **Hex: Shards of Fate**, the old online TCG.

## What is already built for it

Scaffolding only — the sign itself is not built.

- `Image.paletteQuantised(artPixels:scale:)` and the `paletteQuantise` shader:
  drops any sourced art onto the art's pixel grid and snaps every colour to
  `Palette.indexed`. This is what lets a **free tornado asset** be used without
  reading as borrowed, and it is reusable for anything else brought in.
- `AquariusStormView`: the pot under the funnel, a `revealed` fraction driving a
  continuous fade, spin and breath while the funnel *sprite* steps between
  however many frames exist. Frame selection is biased low, so distinct frames
  cluster near the reveal where decisions are tightest.
- `UmbraEyesView` now takes tint, spacing, wander and timing, so the same
  deterministic blink-and-drift serves the eyes in the funnel as well as
  Nilyth's.

A drawn animation of the funnel being sucked into the pot can serve both
directions by being **reversed** for the other.

See [[project-stars-goal]], [[project-stars-architecture]] and
[[gemini-split-rework]], which this now precedes.
