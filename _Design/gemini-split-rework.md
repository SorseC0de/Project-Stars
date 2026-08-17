# Gemini Split Rework

> The agreed redesign of Gemini's Soul Split — Fracture Point, mirrored movement, confined halves, contrasting gold/silver wear — to be implemented.


Designed 2026-08-14, to be built — **after** the Aquarius rework, which is the
cheaper build and was queued ahead of this on 2026-08-15. See
[[project-stars-aquarius-rework]]. Replaces the shipped Soul Split, which works
exactly as written but plays badly: control alternates between the halves every
turn and the forced switching is the problem, not any defect in it.

The passive is named **Fracturing Fissure**.

## The shape

**Splitting** happens at the **Fracture Point** — a thin vertical distortion,
pixel art, unstable-looking (Janemba's ultimate; Breath of the Wild's shattering
weapons) hanging over the centre square, `GameRules.nexysPoint` = (3,3) on a 7×7
board. You **enter** it rather than standing on it: on the island's plane that is
stepping onto the Nexys, and on the other plane the centre square is a hole and
the rift catches you instead of dropping you through. Same square, same input,
both planes — and Gemini's ability never switches off because Libra moved the
island.

**While split, movement is mirrored** across the vertical centre line. One input
moves both halves: east-west is mirrored, north-south is parallel. This is what
keeps turns equal to moves — no toggle, no switching action, no non-move turn.

**The halves are confined.** Gold holds columns 0–2, silver 4–6; the centre
column is barred with a visible barrier and a balk. That gives 3 | 1 | 3, a
proper 3×7 board each, and it guarantees the halves can never overlap.

**Pinning is the skill.** An illegal move for one half moves only the other —
the standard Zelda/Pokémon mirrored-puzzle technique, and already Shadow Work's
intended play. The barrier matters because it makes pinning *always available*
instead of depending on where the board happens to be broken.

**Rejoining** is a button that snaps both halves back to the Nexys from
anywhere — its own panel control, as Libra's lift is. It counts as a turn,
cleanly, because the piece genuinely moves.

It lands the piece **on** the Fracture Point, and that is deliberately not a
shortcut back into a split: the rift is *entered*, not stood on, so parking on
it does nothing. Splitting again means stepping off and stepping back in — two
turns and two tiles, paid at the centre of the board where ground is dearest.
Do not "fix" this into a stand-on trigger.

## Separated across planes

If the halves are **not on the same plane**, Gemini **loses essentially its whole
kit and plays as a vanilla Steady piece** until they are reunited.

This is what makes the sign's tenacity honest rather than generous. A lost half
does not end the run — effectively four lives — but surviving costs the entire
kit rather than nothing, and being separated becomes a state the player is
actively trying to escape. Without it, drifting apart has no downside at all.

### Seeing both boards at once

While separated you hold **two vanilla pieces** and **toggle between the boards
manually**, the way Libra's lift is a button rather than something that happens
to you.

Both planes are drawn **overlaid**, unique to Gemini: the inactive one is
**transparent but still visible**, offset vertically by about **a tile and a
half**. The half is deliberate — a whole number of tiles would interleave the two
grids into one plausible-looking board, where an offset that never aligns reads
as two stacked surfaces.

**Why it matters beyond convenience:** Gemini's Astra passive **copies heals
down** to Terra. Under forced alternation you healed a board you could not see,
so the player had to memorise the Terra layout or simply accept that *something*
got mended. Seeing both turns that passive from flavour into something you aim.

Pairs with **warping the screen** while separated.

**What already exists for it:** `BoardView.layers(board:plane:metrics:)` is the
whole board stack as one function taking the plane as a parameter, so drawing
both is calling it twice with an offset and an opacity. `FractureField` already
wraps that stack and is driven by a single flag, so the warp is a condition
change rather than new rendering.

### Getting the kit back

Reuniting across planes the honest way is **deliberately hard**. The alternative
is to **kill the Astra half on purpose**, sacrificing a life to restore the
mirrors and the rejoining — so the surviving half continues on Terra, having
given up the high ground for its kit.

Two things this does:

- **Four lives become a currency rather than a cushion.** You spend one to buy
  your kit back, which is a decision, where a buffer is just insurance.
- **The kit simplifies exactly when the player is under pressure**, and the way
  out is a single clear act. Gemini has a difficulty valve built into it: an
  overwhelmed player ends up in the simple mode, with one deliberate choice to
  climb back into the complex one. Worth preserving — it is unusual for a
  complexity-heavy sign to teach itself like that.

## Costs and rewards

| | whole | split |
|---|---|---|
| wear per step | 1 tile | 2 tiles, one per half |
| centre column | reachable, so its coins are | barred |
| Zodiaction charge | gains normally | **no gain at all** |
| abilities | none | gold and silver each have one |

No charge while split is what stops split being a farming stance: it is a tool
entered to solve a board, and you rejoin to start earning again. (An earlier
proposal to make split the *charging* state was rejected for creating exactly
the pressure to stay split.)

## The twins

Only the **east-west** rifts exist. Entering one swaps which side each half is
on, which is how the player chooses which twin's ability operates where.

Contrasting wear, so the two are read as opposites:

- **Gold** damages on **entry** — its destruction lands ahead of it.
- **Silver** damages on **exit** — its destruction is left behind it.

Which means gold can carve forward but cannot end a turn on fragile ground, and
silver can stand anywhere but ruins its own retreat.

## Still open

- What a fall does while split — both halves drop, or the fallen one is lost.
- Whether coins can be gathered by both halves or only one.

**How to apply:** The existing implementation is not scaffolding for this. The
seam is `turnPassed` and `otherHalf` in `GameEngine`; `Piece.twin`, the random
faller and silver's clockwise tumble all survive unchanged. See
[[project-stars-architecture]] and [[project-stars-goal]] — wear is a cost and
never a reward, which is the entire reason two bodies self-limit.
