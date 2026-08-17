# Project Stars Umbra

> Umbra — a planned third plane beneath Terra, the underworld, with a shadow chaser, soul Pentacles and a Scorpio re-kit.


Designed 2026-08-14. Not built. A **third plane below Terra**, the underworld.

## Getting there and back

- At the start of every run, **one random Terra tile is secretly marked** as the
  umbra hole. Falling through *that* one drops you into Umbra instead of ending
  the run; every other hole kills you as normal.
  - Supersedes an earlier version where every death rolled a very low chance.
    A mark placed at the start makes Umbra a property of the run rather than a
    lottery at the moment of death.
- The umbra hole should be **visible once it opens** rather than secret — it
  swallows light instead of casting a pool, or its pool is the wrong colour.
  The model is Animal Crossing's buried money: the glow tells you *where to
  look*, not what is there, so you are not digging up the whole village. This
  turns falling in from an accident into a decision, and gives "break tiles
  looking for it" a real cost in ground.

- Returning to Terra is **possible but difficult**. Making it back **fully
  restores Terra**, as the reward for surviving.

## Arrival

**Arriving in Umbra always strips all ZC.** No sign keeps a meter through the
fall.

## The soul, and the body

**Supersedes the pillar-and-keys version below.** No barrier, no Nexys, and the
centre tile is irrelevant or closed.

Falling to Umbra **shatters your statue**. The broken piece stays on the entry
tile as decoration — which is also the tile lit from above by the Terra hole you
came through, so it doubles as the landmark for where you came in.

You then control a **soul version of your piece**, and what you gather is **gold
statue fragments**: a new body. Umbral Essences spawn like any other Pentacle,
after their own glow phase, and are **not guaranteed to contain a fragment** — so
how long a run down there takes is genuinely variable.

**The chaser now has a motive.** He cannot siphon your astral energy while it is
protected by the gold body, so he waits in Umbra for prey that arrives without
one. This is also what the death easter egg has always been: the shadow
respawning on Astra wearing your statue's body is him getting exactly what he
came for.

Drawing it: the spirit form **z-stacked with the ordinary gold form under a
mask**, with programmatic **clusters of pixels reversing the mask** so the body
accrues as gold armour shards. The progress bar is the piece itself — nothing to
put on the HUD. `paletteMoss` already places deterministic hash-keyed pixel
clusters on art-pixel coordinates and is the pattern to build this from.

### The way out

Two versions; the user **prefers the second**:

1. Astral powers restored, you simply **ascend** — teleport back to Astra.
2. The **luster of the completed gold body destroys the shadow**, leaving behind
   what was inside it all along: a **wormhole**, and you **pick which plane to
   warp to**. In this version **Terra does not reset** — the choice is the reward
   instead of the repair.

### The shortcut drop

A **rare Umbral Essence** that fully restores your **entry body** (stone
appearance) in one go, rather than a fragment at a time. You still have to
*reach* the tile it lands on before you are eaten, and reaching it is what
re-golds the body — which triggers the shadow's destruction and everything that
follows from it.

### Making the shadow threatening

Either **two moves per turn**, or **full eight-directional movement** like
Virgo's. Not decided.

Note the structural difference: two moves on four directions is a *speed* threat
that still has to path around corners, so geometry beats it. Eight directions is
a *positioning* threat — it closes on the diagonal and never wastes a step, so a
piece that cannot move diagonally can never gain ground on it in open board.
That would make surviving Umbra depend on which sign you are holding in a way
the two-move version does not. Long ground-travelling moves (a slide, Aries'
charge) buy distance against either.

## Superseded: the pillar and the keys

Kept because signs still carry hooks written for it — **Aries' charge was written
to shatter the barrier** — and because the barrier itself may return elsewhere.

The Nexys sat at the centre tile inside a **pillar of light** that acted as a
barrier; escape was always from the centre, and dropping the barrier took **10
"key" items**. Originally a Terra mechanic with two items, one raising and one
lowering it, deprecated when the Nexys travelling between planes replaced it with
something more cohesive.

Gemini's **Fracturing Fissure does not exist in Umbra**, and the chaser always
pursues **the main player**.

## What Umbra is

Two versions were sketched. The user **prefers the second**:

1. Tiles crack as elsewhere, with **lava showing through** the cracks.
2. **Umbra cannot be cracked at all.** Instead: two randomly placed **static rock
   tiles**, and **Nilyth**, a shadow copy of your piece with yellow glowing eyes, that
   chases you one square for every step you take. **Touching you ends the run.**
   A **pulsing shader around the rim of the screen** holds the tension the whole
   time you are down there.

Easter egg on death by the chaser: a short visual of the shadow piece
**respawning on Astra wearing your statue's body**.

## Light

Visual only, possibly. Terra's **holes let light through**: pools of light fall
on the cells beneath them and the rest of Umbra is very dark.

Optional deeper version, undecided: tie **map luminance to the number of holes in
Terra**, and let luminance drive the **drop rate of negative items** — more light
getting in means a weaker underworld.

## The art, and where it lives

Wired into `SpriteID` / `SpriteAtlas` on 2026-08-14, ahead of the plane itself.
All coordinates are cells on the master sheet.

| what | cell | note |
|---|---|---|
| floor, light | (0,5) | `#50576B`, `Palette.darkGray` |
| floor, dark | (1,5) | `#2E3740`, `Palette.smoke` |
| edge, light | (0,6) | |
| edge, dark | (1,6) | |
| decoration | (1,3), (1,4) | scattered at board generation, *maybe* per tile |
| decoration, rare | (2,3) | rarer, and **turned to a random angle** |
| impassable rock | (0,3)–(0,4) | two cells tall; **two per generated Umbra** |

The decorations are drawn in `smoke`, which is also the dark floor's own colour,
so on a dark tile they must be swapped one step down to `coolBlack` (palette
index 6) or they vanish — `GameRules.umbraDecorDarkSwap`.

The rocks exist to **block Nilyth**: something the player can put between
themselves and the chaser.

## Nilyth

The shadow creature is named **Nilyth** — *nil*, as in null, plus *Lilith*, the
astrological point outside the twelve signs. A thing that is nothing, and that
belongs to no sign.

Working name was **Ziliyth**; the chibi eyes drawn under that name are the ones
Aquarius' revealed pot uses — see [[project-stars-aquarius-rework]]. Nilyth's own
eyes are the angry Aries-slanted pair, which is a different set.

## Pentacles

Umbra's coins are little **soul-looking things** (sprite already drawn), working
name **Umbral Essence** (not settled). They behave like ordinary Pentacles except
**negative items are weighted much higher**, and there are **Umbra-only items** in
the pool.

## Umbral Essence items

- **Stellar Shackle** — in Umbra it **binds the shadow for a turn**. On Terra or
  Astra, where Scorpio can reach it, it instead **binds one glow sparkle to
  persist at that location through the next glow phase**.

## Scorpio

Re-kitted around Umbra. Umbra being reached mainly through Scorpio is
**intended, not a problem**: the game already has sign-exclusive content, and not
everyone will want underworld gameplay — the people who do will be Scorpio
players, the same way Libra and Aries each suit a different taste.

- **Samsaric Shed** reworked: sends you to Umbra **100% of the time**, replacing
  the Astra revival.
- A **new passive**: a small chance to spawn Umbral Essence coins on Astra and
  Terra.

**How to apply:** Umbra is a third `Plane`, which nothing in the codebase
currently assumes — `Plane` is treated as a pair throughout (`opposite`, the
Nexys' two planes, Gemini's split across two). Expect that to be the real cost
rather than the art. See [[project-stars-architecture]] and
[[project-stars-cronos]].
