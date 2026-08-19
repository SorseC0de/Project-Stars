# Sign implementation checklist

Every line of the per-zodiac design, and whether the code does it yet. Keep this
in step with `Zodiac/Signs/` — if a row here says **done**, the behaviour is live
in the build, not merely commented.

Status key: **done** · **partial** · **todo**

---

## ♈ Aries — fire, strong on Terra

| # | Item | Status |
|---|------|--------|
| 1 | Normal movement | done |
| 2 | Passive — +1 charge per consecutive move in the same direction after the first, resets on turn | done |
| 3 | Zodiaction — Blaze Path: 5 moves, damage on exit instead of entry, doubled | done |

## ♉ Taurus — earth, strong on Terra

| # | Item | Status |
|---|------|--------|
| 1 | Normal movement | done |
| 2 | No charge outside Pentacles | done |
| 3 | Passive — Heavy/Hydroponic Hooves: Astra 2 stages per landing, Terra grows cover that takes the first hit | done |
| 4 | Zodiaction — Heavy Flop, Astra: crash to Terra, mend the tile below, fatal if open | done |
| 5 | Zodiaction — Heavy Flop, Terra: fully mend the 3×3 including holes | done |

## ♊ Gemini — air, strong on Astra

| # | Item | Status |
|---|------|--------|
| 1 | Normal movement | done |
| 2 | Passive — Mirrored Healing: Astra repairs echo onto the Terra tile below | done |
| 3 | Passive — Mirrors: four edge-centre portals, Astra only | done |
| 4 | Mirrors drawn as four floating ovals outside the grid | done |
| 5 | Passive — Split Soul: falling from Astra splits the piece, alternating turns | **todo** |
| 6 | Split Soul — rejoining both halves fills the meter | **todo** |
| 7 | Passive — Sibling Soul: a half falling into a Terra hole rises and is absorbed, half meter | **todo** |
| 8 | Zodiaction — mirror the left half of the board onto the right | done |

**Blocker for 5–7:** everything from `Piece` upward assumes one controlled piece.
Needs a piece collection plus an active index, a `.turnPassed` event, and the
board view drawing the inactive half on the other plane.

## ♋ Cancer — water, strong on Astra

| # | Item | Status |
|---|------|--------|
| 1 | Movement — Sidestep: up to 2 tiles to the side of current facing | done |
| 2 | Passive — charge for sidestepping: full 2 on Terra, either distance on Astra | done |
| 3 | Passive — Homebound Surge: +3 charge returning to the Nexys by anything but walking | done |
| 4 | Passive — Heavenly Hoarder: Pentacle adjacent to Nexys, half meter Terra / full Astra | done |
| 5 | Zodiaction | **undesigned** — awaiting a concept |

## ♌ Leo — fire, strong on Terra

| # | Item | Status |
|---|------|--------|
| 1 | Normal movement | done |
| 2 | Passive — Prideful Fall: +3 charge on landing after a fall | done |
| 3 | Zodiaction — Solar Pull: draw the Pentacle 1 tile on Astra, 2 on Terra | **todo** |

**Blocker for 3:** no event moves a revealed Pentacle, and the persistent-sun
reading needs a world object with a lifetime. Shared with Sagittarius' arrow.

## ♍ Virgo — earth, strong on Terra

| # | Item | Status |
|---|------|--------|
| 1 | Normal movement | done |
| 2 | Passive — Controlled Landing: the Pentacle always spawns on the sparkle you land on | done |
| 3 | Passive — Protective Step: badly damaged tile does not break, 3-move cooldown | done |
| 4 | Passive — Soft Landing: falling from Astra fully restores the Terra tile landed on | done |
| 5 | Zodiaction — force a new sparkle phase, re-rolling any active one | done |

## ♎ Libra — air, strong on Astra

| # | Item | Status |
|---|------|--------|
| 1 | Movement — Balanced Impact: damage the two tiles flanking facing, not the landing tile | done |
| 2 | Passive — Perfect Balance: a uniform row/column is fully healed, alternating axes | done |
| 3 | Zodiaction — Terra: cracked → healthy, badly cracked → hole | done |
| 4 | Zodiaction — Astra: cracked ↔ badly cracked, hole ↔ healthy | done |

## ♏ Scorpio — water, strong on Astra

| # | Item | Status |
|---|------|--------|
| 1 | Movement — 1-tile slide or 2-tile jump | done |
| 2 | Passive — Void Culling: charge for jumping holes, escalating on consecutive moves | done |
| 3 | Passive — Deathdream: Astra hole into Terra hole returns you up, mends the hole | done |
| 4 | Passive — Shed: once per run, dying on Terra returns you to the Nexys | done |
| 5 | Shed — ascent locked for the rest of the run afterwards | done |
| 6 | Shed — refreshed only by changing pieces | done |
| 7 | Zodiaction — Tail Strike: 3 tiles on Terra, full row/column on Astra, collects Pentacles hit | **todo** |

**Blocker for 7:** collection is welded to the piece coming to rest on the coin.
Needs a `collect(at:)` that does not assume the piece is standing there — shared
with Shadow Work's collision rule.

## ♐ Sagittarius — fire, strong on Terra

| # | Item | Status |
|---|------|--------|
| 1 | Movement — forward 1–2 slide or 3 jump, ordinary elsewhere | done |
| 2 | Passive — Lucky Reveal: +3 charge when the sparkle you land on held the Pentacle | done |
| 3 | Passive — Safe Landing: small chance a badly cracked tile holds; mends on Terra | done |
| 4 | Passive — Lucky Landing: small chance a fall fully restores the Terra tile | done |
| 5 | Zodiaction — Golden Arrow: fire to a random tile, pop again to warp | **todo** |
| 6 | Golden Arrow — from Terra, also drags the Astra tile down, restoring Terra | **todo** |

**Blocker for 5–6:** persistent world object with a two-stage activation. Same
requirement as Leo's sun.

## ♑ Capricorn — earth, strong on Terra

| # | Item | Status |
|---|------|--------|
| 1 | Movement — Mountain Climber: north may vault 2, 1-turn cooldown | done |
| 2 | Passive — Springboard, Terra: trade a Pentacle beside the centre for a launch to the Nexys | **todo** |
| 3 | Passive — Springboard, Astra: same from any Pentacle south of the centre row, once per visit | **todo** |
| 4 | Zodiaction — Astra: hop the next hole you would fall into | done |
| 5 | Zodiaction — Terra: keep hopping until solid ground or the board edge | **todo** |

**Blocker for 2–3:** "you can opt to" is a player prompt. The suspend-and-ask
machinery exists for Pentacles (`PickupChoice`); it needs a second trigger so a
passive can raise one.

**Blocker for 5:** `preventsFall` answers "do you fall here" and cannot propel
the piece onward. Needs a hook returning a follow-up path.

## ♒ Aquarius — air, strong on Astra

| # | Item | Status |
|---|------|--------|
| 1 | Movement — Airborne: always damage on exit | done |
| 2 | Passive — Weightless: multi-tile moves count as jumps | done |
| 3 | Passive — Corner Flight, Terra: once per visit, corner → diagonal corner | **todo** |
| 4 | Passive — Corner Flight, Astra: once per visit, corner → any other corner | **todo** |
| 5 | Zodiaction — Gone With the Wind: teleport to a random non-hole tile, Nexys included | done |

**Blocker for 3–4:** same player prompt as Capricorn's Springboard. The
once-per-visit limit itself is already covered by `SignState.planeFlags`.

## ♓ Pisces — water, strong on Astra

| # | Item | Status |
|---|------|--------|
| 1 | Normal movement | done |
| 2 | Passive — Astral Flow: +1 charge per move on Astra, −1 on Terra | done |
| 3 | Passive — Earthly Drift: each Terra arrival fully restores charge | done |
| 4 | Zodiaction — Upstream (Terra): swim back to Astra | done |
| 5 | Upstream — cannot be used on the turn you fell | done |
| 6 | Zodiaction — Downstream (Astra): ride your tile 3 squares forward, carrying its state | **todo** |

**Blocker for 6:** the board itself changing shape. Needs a
`.tilesShifted(from:to:plane:)` event and a decision on what is left behind — a
hole, or a swap with the destination.

---

## Landing order

Everything a landing does, in the order it does it. The ordering is a rule in its
own right, not an implementation detail — see `GameEngine.settle`.

1. **Wear** the tile arrived on.
2. **Open any Pentacle** on that square, and resolve its effect in full.
3. **Check the ground.** Only now does a hole drop the piece.
4. **Fall**, or come to rest (and ascend, if resting on the Nexys in Terra).

Step 2 sitting before step 3 is deliberate and load-bearing: a coin on a tile the
landing just broke is a rescue, and can only rescue if it resolves first. Astral
Brook sweeping you off a square that has this instant become a hole is the case
it exists for.

**The damage still lands.** Step 1 already happened and is not undone — the tile
is a hole either way, and stays one. What the Pentacle prevents is only step 3
applying *to you*, because by the time the ground is asked, forced movement has
carried you somewhere else. (Brook rides over holes regardless, so it is the
clearest example, but the same is true of any effect that moves the piece.)

If an effect moves the piece, the loop starts again at step 1 for wherever it
ended up — a new square is a new arrival and owes its own wear and its own checks.

---

## Remaining engine work, by how many items it unblocks

1. **Player prompts raised by passives** — 4 items (Capricorn ×2, Aquarius ×2).
   Reuse `PickupChoice`'s suspend-and-ask with a second trigger.
2. **Persistent world objects** — 3 items (Leo, Sagittarius ×2). One `markers`
   collection with events, shared by the sun, the arrow, and Shadow Work.
3. **Split Soul** — 3 items (Gemini). The largest single change.
4. **Ranged Pentacle collection** — 1 item (Scorpio), also unblocks Shadow Work.
5. **Follow-up movement from a hook** — 1 item (Capricorn's Terra hop chain),
   shares a shape with Astral Brook's slide.
6. **Board-shape mutation** — 1 item (Pisces' Downstream).
