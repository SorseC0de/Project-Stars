# Pickups — designed, spec'd, and now built

> Recovered 2026-08-19 from the conversation they were dictated in. They had
> never been written down, which is why `SignState` carries fields for three of
> them (`stellunaRider`, `miasmaMark`, `stardarPending`) while none of the three
> exist as pickups. **The spec belongs here, not in a chat log.**

Icons are already drawn and named in parentheses — the SVG in
`_Graphic Assets/Icons/Pickups`.

## Status

**All five were built 2026-08-19.** The specs below are kept as the statement of
intent — where the code and this document ever disagree, this is the target.

Umbral Essence, Astral Essence, Trivial Tremor and Seismic Shakedown were
already in before that.

### Authored chances as built, and the problem with them

| coin | chance |
|---|---|
| Stardar | 4 |
| Nexyial Bastion | 4 |
| Match-shift Miasma | 4 |
| Stelluna Sprite | 3 |
| Polarity Prongs | 2 (Terra only) |

Adding seventeen points took the authored table to **136**, so every number in
it — old and new — is currently worth about **0.74 of what it says**. The Tear
reads 33 and plays as roughly 24.

Nothing was rebalanced to hide that: the numbers are the designer's and the
dilution is a decision, not a bug to be quietly patched. The DEBUG check that
used to assert now prints a warning once a run naming the total and the scale
factor, because a catalogue that is deliberately growing should not take the
game down for being mid-expansion.

---

## Stardar *(radar)*

**Common–Uncommon cusp.** *(Revised 2026-08-19, down from Uncommon–Rare.)*

> "Trust the glimmer of the stars to guide you to fortune"

Next glow phase, the sparkle that is holding the Pentacle wears `sparkles.png`
on top of it, so the player can see which one to take.

If pre-selecting the winning sparkle would mean rewriting the glow phase, the
sanctioned shortcut is to **force the Pentacle to spawn on the sparkling one**
instead. `SignState.stardarPending` already exists for this.

## Nexyial Bastion *(shield_reflect)*

**Uncommon.**

> "Astral energy emits from the Nexys, protecting a tile from its next damage."
> Nexys elsewhere: "Dregs of Astral Energy emit from where the Nexys once was
> and may someday be again."

A tracking sparkle travels from the centre tile to a random non-hole tile —
including the one you are standing on. That tile gains an aura and **tanks the
next damage it takes, however much it is**. Cycling elemental colours like the
Astral Bolt.

If the Nexys is not on your plane: the alternate summary, the sparkle travels
from the hole *to the player*, and it grants **1 ZC** instead.

- Note: this negates, unlike ground cover, which absorbs one stage and steps
  down. Do not let the two rules borrow from each other.

## Match-shift Miasma *(typhoon)*

**Uncommon.**

> First: "A strange sigil forms below."
> Second: "A strange sigil forms be— woah!"

**First pickup** marks a random tile — the SVG overlaid with a blend mode,
*before* the tile skew — in either sky or orange at random, glowing. The pickup
icon takes that same colour.

**Second pickup** warps you to the marked tile, and its colour is always the
opposite one. Eligible tiles include your current one and **holes** (in case
they are restored later, or to unfortunately kill you); the Nexys tile is
excluded.

**If a marked tile becomes a hole before the second pickup, the mark breaks.**

`SignState.miasmaMark`, `miasmaPlane` and `miasmaIsWarm` are already there.

## Stelluna Sprite *(fairy — re-import, the SVG was edited)*

**Uncommon–Rare cusp.**

> "A peculiar fairy whose sparkling wings make those it visits feel safe and
> protected."

You may stand on the **next hole you would fall into**, once. `sparkles` loops
on that tile until you leave it. `curly_wing.svg` shows in the buff row until it
is consumed.

`BuffsView` — the left-expanding HStack this asked for — already exists.

## Polarity Prongs *(crystals)*

**Rare, Terra only.** Explicitly the last one to build.

> "Shards of Astra rain down in an oddly specific pattern, emitting pulling
> pulses"

Four shards fall, one at each cardinal pole, **cracking those tiles into holes**
and standing up out of them. Each is one of the four elemental colours. The
**active** pole glows and emits pulsing ripples.

For **four turns**, at the end of your turn you are pulled one tile toward the
active pole, then the active pole is re-rolled. So the next pull is visible in
advance and can be planned around. No lockout on the re-roll — the same pole may
come up all four times.

**+1 ZC** with the pull when the active pole matches your element.

After four turns all four shatter; the holes they made remain.

Rectangles are acceptable for a first pass — dim gem colour for the inactive
poles, element colour for the active one. A shader that genuinely ripples the
screen from that spot would be the right finish, tinted with the pole's colour.
