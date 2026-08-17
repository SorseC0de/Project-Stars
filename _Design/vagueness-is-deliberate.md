# Vagueness Is Deliberate

> User-facing text is intentionally under-explained — discovery is the design, not a gap to fix.


Stated 2026-08-16. **Some pickup summaries and effect descriptions are vague on
purpose. Do not clarify them.**

## The intent

Part of the game's pitch is that older games did not hand you everything at the
front door: working out what something does, and trading that knowledge with
other players, *was* the fun. The goal is an arcade **pick-up-and-play** feel —
no long tutorial, no painfully revealing instructions, no loot boxes, no daily
hearts.

## How to apply

- A summary that does not fully explain its effect is **finished**, not a TODO.
- Do not "improve" text by making it explicit. `PickupEffect.summary(in:)`
  exists so a line can be *correct for the run* — Polaris being cold on Terra,
  Umbral Essence feeding Scorpio — not so every line can spell out its rules.
- The distinction that matters: **a line may not be wrong, but it may be
  incomplete.** Saying a coin does X when it does Y for this sign is a bug.
  Saying "Nothing to worry about" and letting the player find out is the design.
- Trivial Tremor and Seismic Shakedown are the model — "Nothing to worry about"
  and "Worrying warranted" tell you the *relative* size and nothing else.

See [[project-stars-goal]] and [[dont-volunteer-balance-opinions]] — both are
the same instinct: the user has decided, and the job is to build it rather than
to soften it.
