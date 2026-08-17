# Project Stars Cronos

> Cronos — a planned Pentacle that rewinds the run several turns, implemented by snapshotting the engine struct.


Designed 2026-08-14. Not built. A Pentacle called **Cronos** that **rewinds time**
by three to five turns.

## What it undoes

Everything about the run's state: the **piece returns to the square it stood on
X moves ago**, **tile damage is undone**, **ZC is reset**, and so on for anything
held in the engine.

## What it does not undo

The **glow phase reshuffles**. The board that plays out after a rewind is a new
deal, not a repeat — that is what makes the item worth having.

## How to build it

`GameEngine` is a `struct` and everything in it is a value type — boards, piece,
`signState`, the RNG. So a snapshot is `let past = engine`, copy-on-write makes it
nearly free, and a ring buffer of five gets the whole feature. **Do not build an
action log or a replay**; a replay can diverge from the original wherever some
effect turns out to be less pure than it looks, and a snapshot cannot.

Restore **everything except `rng`**. Keeping the generator where it is now is what
reshuffles the glow phase while the board unwinds — one field, and it is the
whole difference between a repeat and a new deal. It also means the feature does
not depend on the run being seeded at all.

Snapshots get Gemini's split, Leo's retinue, a planted arrow, a Bastion and the
meter for free, since all of it lives in `signState`.

## Presentation

Every action **plays back visually in reverse order**, with **a shader over the
screen** during it.

Note that a rewind is the first thing in the game that is not a forward event —
`GameEvent` is a list the session animates in order, and this replaces the whole
engine at once. The session's own presentation state (afterimages, smoke, the
piece's pose) is not in the engine and needs clearing explicitly rather than
unwinding.

## Watch for

The **self-resurrection loop**: if the snapshot predates picking Cronos up, the
coin is back on the board after the rewind. Take it, rewind, take it, forever.
Whichever way it is built, the fact that *this* Cronos is spent has to survive
the rewind.

See [[project-stars-architecture]] and [[project-stars-goal]].
