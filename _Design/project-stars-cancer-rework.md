# Project Stars Cancer Rework

> The Cancer rework — all movement sideways, auto-rotating, a stoppable full-length crab walk. A literal claw machine.


Designed 2026-08-15. **Not built.** Cancer was judged the most boring playstyle
once Aquarius, Gemini and Scorpio are reworked, excluding the Steady signs.

## The diagnosis

Cancer is tagged **Tenacious Mover** — both tags are about *not dying* and
*getting around*, and neither is a verb that changes the board. Every other
non-Steady sign has one: Libra trenches and mends, Leo summons, Capricorn trades,
Sagittarius plants, Pisces floods.

**Bubble Bastion is the only ability in the game whose success condition is
"nothing happens"** — and once placed there is no further input. In a game where
the board decaying is the clock, Cancer's answer to the central pressure was to
briefly opt out of it.

Bastion and the Scuttle are the **most interesting things about Cancer and the
most likely to be kept**. The fix is not to replace them; it is to give the sign
a verb.

## The claw machine

- **All** of Cancer's movement is **sideways**.
- At the end of every move Cancer **auto-rotates clockwise** — otherwise you
  could never get anywhere. Over four turns it sweeps all four directions.
- The crab walk is **slowed down** and converted **back to steps** rather than a
  slide.
- It runs **up to the full length of the board**, and the **player taps to stop**
  it at any point.

You do not choose a direction, you are given one; you choose a *moment*. That is
a different input from anything else in the game, and everyone understands a claw
machine on sight.

## Facing matters

Cancer **auto-grabs items directly in front of it**, not only ones it walks over.

## Bubbles — the prizes

At the start of each **Cancer turn** the player may **fire a bubble** in the
direction Cancer is facing. It travels that way and **traps** what it meets,
suspending a **glow sparkle or a coin** in place for Cancer to come and collect,
like a web. This is what solidifies the claw-machine identity: those are the
prizes.

- Trapped things are **additional**. The game carries on producing glow phases
  and Pentacles normally.
- **A trapped sparkle keeps its identity.** If it never held a Pentacle it
  **disperses into nothing** on collection. You are not banking a prize, you are
  banking a *gamble* — nothing else in the game preserves uncertainty across
  time like this.
- **Collecting a bubble is +1 ZC regardless**, so an empty trap is never
  nothing. It also means "should I fire" is never a real question; all the
  tension sits in *where*, which the auto-rotation already governs.

### The deduction layer this creates

Trap a sparkle, then let the phase resolve. If the Pentacle turns up on one of
the *other* squares from that set, the player now **knows** their trapped one is
empty, and the right play is to stop walking toward it. A trapped bubble is not a
fixed prize, it is a claim whose value changes as the board reveals itself.

### Routing

No auto-stop on a prize — it is not needed, and the geometry works out. Walking
north while facing west, the bubble ends at the left wall while Cancer ends at
the top; but at the top Cancer faces north, so it can walk west, and then east to
come down onto it. The rotation *is* the route.

### The speedforce

While the crab walk runs, **Cancer and its bubbles are the only things in
motion.** Everything else — other pickups, timers, glow phases, anything that
chases — waits until Cancer stops.

Stated as a rule rather than an exception list: **anything Cancer set in motion
moves at Cancer's speed; everything else waits.** That covers the crab, its
bubbles and the tiles breaking under it, and will cover whatever Cancer is given
later without anybody maintaining a list.

Consequence to accept deliberately: a pursuer is not Cancer's, so it freezes too
— the crab can outrun anything for free.

## Drawing a trapped bubble

**Big bubble sprites**, not Pisces' small ones — a bubble has to be visibly
larger than a Pentacle for the prize to read as suspended *inside* it.

- Floats: **oscillates 2–4 px above the tile centre**, house float mechanics,
  with a shadow underneath.
- Programmatically **rotates**, and **scales up and down** by a small margin, to
  give it life.
- **The thing inside does not rotate**, but **does follow the scaling**, so it
  appears to distort the way something seen through a real bubble would.

### Seeing through it

Do **not** simply lower the whole sprite's opacity. Two approaches:

1. Selectively alpha down only the **non-edge colours** of the bubble sprite —
   the inner fill, possibly cyan; *sample the sheet, do not assume*.
2. **Preferred:** a programmatic `Circle()` mask slightly smaller than the
   bubble, centred, using a **radial gradient from black to clear** so only the
   interior loses opacity while the rim stays solid.

The second is better for a reason beyond taste: it is **art-agnostic**. It needs
no knowledge of which palette entries the fill uses, so it keeps working if the
bubble is ever redrawn or recoloured.

One caveat: a smooth radial gradient introduces alpha that is not aligned to the
art's pixel grid, which is the sort of thing this game otherwise avoids. On a
bubble that may be exactly right — they *are* soft — but if it reads wrong,
quantising the gradient to whole art pixels is the fix.

## It is n consecutive automatic turns

Not one long move. The crab walk is **a series of ordinary turns played
automatically** until the player taps to stop.

Everything follows from that, and two objections raised at design time dissolve:

- **Wear is normal.** Each square is its own turn's landing, so a traverse costs
  exactly what walking that far always costs. There is no multiplication to tune.
- **Plan/apply is untouched.** The engine never sees an interrupted move; it sees
  n ordinary moves and then a stop. No preview, no pending choice, no special
  planning path.

It is also **self-costing**: every square is a turn, so a long traverse ticks the
board n times — the glow phase advances, timers run down, and anything else on
the board moves. The player is spending turns and chooses how many. No extra
price needs inventing.

## The Nexys is his prize bin

Added 2026-08-16. Cancer **does not use a Pentacle when he takes it**. What he
collects is sent to the Nexys, and he picks what to use from what is waiting
there.

This is the **Capricorn shape applied to a different resource**: Capricorn turns
Pentacles into currency with a purse and a shop, and Cancer turns them into
inventory with a bin and a choice. Both take the sign's pickups out of "happens
to you" and into "you decide when".

Why it suits the claw specifically: the crab walk is a run of automatic turns
that only stops when you tap, so a Pentacle taken mid-traverse would fire in the
middle of a movement nobody is steering. Banking it removes that entirely — the
traverse collects, and the decisions happen when the claw stops.

It also gives the Nexys a second job for one sign, which pairs with the walk
being sideways-only: the bin is somewhere you have to **go**, and going anywhere
in particular is the hard part of his kit.

## Why the payoff is choice specifically

Stated 2026-08-16. Every other sign has **freedom of movement and no say in what
fires**; Cancer has **the say and pays for it in movement**. Same total,
inverted — which is why banking Pentacles is the right reward for a sideways,
auto-running kit rather than an arbitrary one.

## Idea: top-down while he walks

Wanted 2026-08-16, not built. A **completely top-down Cancer sprite**, with the
board flattening to top-down while the crab walk runs and tilting back when it
stops. The camera change says "you are not steering this" louder than anything
on the piece can.

**Terra is nearly free.** Since the perspective rework everything derives from
`GameRules.boardForeshorten`, and depth `0` *is* a flat board — same code path,
one input at zero. Terra's tiles are drawn face-on with the perspective applied
as a transform, so nothing needs redrawing.

**Astra's art has the perspective baked in** — its clouds are drawn
already-foreshortened, which is why they skip the keystone and take only scale
and placement. So a flat camera needs a second set of drawings for the clouds,
the Nexys, the arrow, the cursor and the Pentacle.

**That is not the blocker.** Top-down sprites are quick to draw, and Cancer
himself needs exactly one — rotated for all four facings. The markers are the
same deal. Do not treat the art as the cost here.

What is actually left is three engineering questions:

- **How a sprite says it has a top-down version.** Best as something the atlas
  resolves — one `SpriteID` picking a different cell under a flat camera — so it
  never becomes an `if flat` scattered through every view.
- **The transition.** Band edges snap to whole points to keep seams closed, so
  tweening the depth makes rows jump a pixel at a time. Cutting rather than
  tweening avoids it, and a hard cut reads better for a mode change anyway.
- **Holding across the run.** The walk is *n* consecutive turns, so the camera
  keys off "the walk is running" rather than off any single move.

See [[project-stars-kit-descriptors]], [[project-stars-architecture]] and
[[board-perspective-solved]].
