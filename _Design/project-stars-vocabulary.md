# Project Stars Vocabulary

> Project Stars has specific in-game names — Pentacle, Zodiaction, Nexys, Astra/Terra — that differ from generic terms and should be used in player-facing text.


The user has settled names for several systems. Use them in player-facing text
and prefer them in code:

- **Pentacle** — the pickup. Always a gold coin, visually identical whatever
  effect it holds; think loot box. Code still uses `PickupID`/`PickupEffect`
  internally, but the UI says Pentacle.
- **Zodiaction** — a piece's charged, player-fired ability (never "super"). The
  user's own shorthand in their docs is "Z-Action" or "zaction", and they used it
  so often they briefly forgot the full name — so treat "zaction" in their
  messages as meaning Zodiaction, but write the full name in code and UI. Exactly
  one per sign, with per-plane differences.
- **Nexys** — the indestructible floating island at the board centre, on exactly
  one plane at a time, with a permanent chasm at the same square on the other.
- **Astra / Terra** — the upper and lower planes. Astra is meant to be a grid of
  clustered clouds (flat blue is a testing stand-in), and the clustering is
  load-bearing for a mechanic not yet built.

**Why:** these are the user's design vocabulary and appear in their existing
GMS2 documentation; drifting to generic terms ("pickup", "super") makes the code
and the design docs disagree.

**How to apply:** when adding UI copy or new systems, match this vocabulary.
"Pentacle" is singular-per-coin; the *effect* inside has its own name (Mend,
Shift).

Related: [[project-stars]], [[project-stars-architecture]]

## Zodea — the user-facing word for a sign / piece / statue

Chosen 2026-08-16. **Singular and plural are both "Zodea."**

> "Your Zodea glows with a golden aura."
> "The Zodea come from Astra, a magical realm amongst the stars."

Built from **Zo**, Japanese for statue, plus **dea** — which reads as "to be" or
"goddess" in Japanese *and* Latin, and lands near "deity" in English.

**Where it applies:** anything the player reads. Code may keep saying `piece`,
`zodiac` and `sign` — those are the mechanical terms and renaming them would
churn the whole engine for no reader's benefit. The rule is the same one this
project already follows for Pentacle, Z-Action and Nexys: **the design's own
name in the fiction, the plain word in the source.**
