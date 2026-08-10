# Project Stars

A SwiftUI remake of *Knight Move* (Famicom, 1990), rebuilt for mobile with
twelve zodiac pieces, two stacked planes, and a Pentacle system.

This is the **pre-alpha skeleton**: the full loop plays, but every sprite is a
placeholder shape and every zodiac passive and Z-Action is a stub.

---

## Running it

Open `ProjectStars.xcodeproj` and run. iOS 17+, portrait.

The project uses Xcode's **synchronized folder groups**, so new `.swift` files
and new asset catalogs are picked up automatically — you never have to add a
file to the target by hand.

---

## Architecture

The guiding rule is that the **rules never touch SwiftUI** and **SwiftUI never
decides anything**.

```
Core/      value types: coordinates, tiles, boards, movement, RNG, tunables
Zodiac/    the twelve signs — one file each, under Signs/
Pickups/   sparkle patterns, Pentacle effects, the first-encounter codex
Game/      GameEngine (pure rules) + GameSession (observable, drives animation)
Art/       sprite naming, pixel-perfect metrics, placeholder palette, shaders
Views/     the screens — everything else is grouped beneath them
```

Docs live at the repository root, beside this file: `SIGNS.md` (per-sign
implementation checklist) and `ASSETS.md` (the sprite names to create).

### Inside `Views/`

`Views/` itself holds **only whole screens** — the things something can navigate
to. Everything else is grouped by which part of the screen it belongs to, so the
folder a file is in tells you where on screen it appears.

```
Views/
  RootView.swift            navigation between screens
  PieceSelectionScreen.swift
  GameScreen.swift          the two-square layout

  Board/                    the upper square, and everything drawn on it
    BoardView · TileView · PieceView · CursorView · SparkleView
    PentacleView · MirrorsView · MiniBoardView · TileChoiceOverlay

  Panel/                    the lower square: readouts and input
    ControlPanelView · HUDView · ZodiactionMeterView
    SwipeInputView · TapTargetOverlayView

  Overlays/                 things that cover the screen
    PauseMenuView · GameOverOverlay
    PentacleIntroView · PentacleBannerView · PieceChoiceOverlay

  Effects/                  transient visuals
    ElementalBurstView · SmokeBurstView · WarpBeamView · ScreenShake
    Spectral/               the Zodiaction apparitions

  Previews/                 Xcode canvas tools, not part of the game
    PentacleGallery · SpectralHeadGallery
```

Note `TileChoiceOverlay` is filed under `Board/` rather than `Overlays/` despite
its name: it is laid directly over the grid and shares its metrics, so it belongs
with the board it aligns to.

### Plan / apply

`GameEngine` never mutates itself in response to input. Instead:

1. **`plan(_ direction:)`** simulates the whole move on a private copy and
   returns it as an ordered `[GameEvent]`. *All randomness is resolved here* —
   events carry concrete outcomes, never "roll for it" instructions.
2. **`apply(_ event:)`** performs one event. No decisions, no randomness.

`GameSession` applies a plan's events one at a time with a delay between each,
which is what animates a move. Because the animation and the simulation replay
the *same list*, they cannot drift apart. It also means a run is a pure function
of (seed, inputs) — pass a `seed` to `GameSession(zodiac:seed:)` to reproduce
one exactly.

### Move-based, never time-based

Nothing in the engine changes on a clock. Every state change is the consequence
of a committed move or a fired Z-Action. The `TimeInterval` values in
`GameRules` pace the *replay* of a move that has already been decided in full —
delete them all and the game plays identically, it just looks instant.

### Where to change things

| To change… | Edit |
|---|---|
| Any balance number or timing | `Core/GameRules.swift` |
| A sign's movement, passive, or Z-Action | `Zodiac/Signs/<Name>.swift` |
| Movement patterns and slide/jump | `Core/MovementPattern.swift` |
| Pentacle effects | `Pickups/Effects/` + a case in `PickupID` |
| Sparkle shapes and odds | `Pickups/SparklePattern.swift`, `GameRules` |
| Placeholder colours | `Art/Palette.swift` |
| Asset names | `Art/SpriteID.swift` (see `ASSETS.md`) |

---

## Current rules

**Choosing a sign.** Runs start from `PieceSelectionScreen`. The sign is fixed
for the run's duration — the only planned mid-run changes are two rare Pentacles
that do not exist yet. The `#if DEBUG` picker in the control panel deliberately
breaks that rule for testing.

**Board.** 7×7, 16×16 px tiles, two planes — **Astra** above, **Terra** below.

**The Nexys.** The centre square is a floating island. It is indestructible,
never sparkles, and exists on **exactly one plane at a time**; the centre of the
other plane is a permanent chasm. Runs start standing on it.

Its behaviour is deliberately asymmetric:

- **Coming to rest on it in Terra rides it up to Astra**, carrying you. This is
  the ascent mechanic, and it pairs with Astra restoring on descent: the Astra
  you rise to is the one your own descent repaired. Reaching the island across a
  decaying Terra is the reward.
- **Landing on it in Astra does nothing.** It is simply safe ground.
- The `Nexys Shift` Pentacle closes the distance either way round: if the island
  is on the other plane it comes to yours, and if it is already on yours you warp
  onto it. Stranded on Terra, that is two Pentacles to get home — one to call the
  island down, one to step onto it and ride back up.

Ascent is checked **at rest**, not on entry, so a slide that merely crosses the
island keeps going rather than ascending mid-move.

**Wear.** Landing wears a tile one step: healthy → cracked → badly cracked →
hole. A tile that reaches `hole` **gives way immediately** — you never stand on
a hole you just made. Falling through Astra drops you to the same square on
Terra; falling through Terra ends the run.

**Astra restores itself on descent.** The moment the player leaves Astra for
Terra, every ordinary tile on Astra returns to healthy — holes included. This is
what makes long runs possible: descending is not purely a loss, because a player
who can find a way back up arrives on fresh ground. `astraRestoresOnDescent` in
`GameRules`. The Nexys and its chasm are structural and unaffected.

**Slides and jumps.** A **slide** walks every square between origin and
destination and wears each one; if a tile breaks underfoot halfway along, the
piece drops there and the rest of the slide never happens. A **jump** wears only
the destination and ignores everything it passes over. Most signs slide.

**Facing and the cursor.** The piece turns to face the direction of every
committed move, and that facing is real state — several signs' passives are
deterministic on it. A **destination cursor** is permanently projected along that
facing: four L-shaped corner brackets with an empty middle, colour-coded by what
is there.

| Colour | Meaning |
|---|---|
| White | Healthy ground, or the Nexys |
| Yellow | Cracked |
| Orange | Badly cracked |
| Red, with a yellow `!` | A hole or chasm — moving here drops you |
| Faint grey | Off the board; the move cannot be made |

The cursor is deliberately allowed to hang **outside** the grid, which is how an
impossible move reads. `BoardView` is unclipped for exactly that reason.

**Board shading.** There are **no grid lines**. Squares alternate between two
tones by the parity of `x + y`, and that alternation is the only thing dividing
one square from the next. Derived arithmetically from the tile palette, so
changing the palette carries the alternation with it — if the board ever reads as
too busy or too mushy, `Palette.TileShade.darkening` is the single knob.

**Pentacles.** The pickup cycle has exactly two phases and no timers:

- *Sparkle phase* — up to five tiles shimmer in a `+`, `×`, or (rarely)
  scattered arrangement. No Pentacle is visible. A shape overlapping a hole or
  the Nexys simply loses that member, so a broken `+` tells you where the board
  is damaged — and can be engineered.
- *Pentacle phase* — the instant a move is committed the sparkles vanish and a
  gold coin appears on one of the tiles they occupied, before the piece lands.
  Every Pentacle looks identical; you only learn what is inside by opening it.

A run **begins in the sparkle phase** — no coin is on the board until the first
move is committed. Collecting one immediately starts a new sparkle phase, so one
is always available; changing plane relocates the cycle for the same reason.

The **first time ever** a given effect is opened, the game pauses mid-move and
explains it (`PentacleCodex`). The explanation is a **strip across the screen,
not a takeover** — the board stays visible and dimmed behind it, because the
player is still reading the position it is about to change. "Reset all prompts"
wipes that record.

**Z-Actions.** Each sign has **exactly one**, and it behaves differently per
plane. The meter is **10 discrete pips**, drawn as ticks rather than a bar so the
player can count how many moves are left. Popping empties it to zero; short of
that a full meter is held for as long as the player likes. Pop it with a **long
press or double-tap anywhere in the input zone**.

There is **no universal charge rule**. `ZAction.meterGain(from:context:)` has no
default implementation on purpose — every sign must write its own, so none can
silently inherit someone else's. All twelve currently return
`GameRules.placeholderZMeterGainPerMove` (1 per move) as an interim stand-in, and
each will be replaced independently.

**Passives.** Each sign carries **two or three**, held in
`ZodiacDefinition.passives`. They combine so that adding one can only ever be
additive or protective: movement folds in order, bonus moves sum, wear is
unanimous (one light-footed passive spares the tile), fall prevention is any-of.
Write each as a single self-contained rule.

**Turn discipline.** Once a move is committed, **nothing** is accepted until it
finishes resolving — not another swipe, not a Z-Action. Each move is a turn.

**Scoring.** 1 per move, 10 per Pentacle.

---

## What's stubbed

- **All twelve passives and Z-Actions.** Each sign file holds two stub passives
  (`<Name>PassiveA` / `PassiveB`, with a third allowed) and one stub Z-Action.
  All hooks are handed `context.plane`, `context.facing`, and
  `context.isEmpowered` — fire and earth are strong on Terra, air and water on
  Astra.
- **All twelve movement styles.** Every sign uses `.cardinalStep` (one
  orthogonal square, sliding). Other patterns are staged in `MovementPattern`.
- **Pentacle effects.** Eleven work. The two legendaries do not: `Polaris` has
  no designed effect yet (its spawn rule — pinned to the north-middle tile — *is*
  implemented), and `ShadowWork` needs a persistent second entity the engine has
  no concept of. Both are at `weight: 0` so they cannot spawn, with the full spec
  recorded in their files.
- **Tap-to-move.** `Views/Panel/TapTargetOverlayView.swift` documents what's left; the
  engine side (`legalDestinations`, `PixelArtMetrics.gridPoint(at:)`) is done.
- **Bonus / forced movement.** `ZodiacPassive.bonusMoves` exists but nothing
  consumes it yet — see the TODO in `GameEngine.plan(_:)`.
- **Settings and encyclopedia.** `PentacleCodex.resetAll()` is the whole of the
  "reset prompts" feature; there is no screen for it yet, and no encyclopedia.
- **The two sign-changing Pentacles.** Not implemented; selection is the only
  way to change sign.
- **Art.** See `ASSETS.md`.
- **Audio, haptics, persistence beyond the codex, menus.** Not started.

A `#if DEBUG` sign picker sits at the bottom of the control panel so you can
drop any of the twelve onto the board. Delete that section once a real
piece-selection flow exists.

---

## Known issue

**On-screen controls do not work inside the lower square.** The panel's
`DragGesture` wins gesture arbitration against any tappable control placed in
it, and the tap never arrives. This was verified against `Button`, a bare
`TapGesture`, `simultaneousGesture`, `highPriorityGesture`, and with the drag
surface moved out of the control's ancestry into a sibling layer — the only
arrangement that ever fired was one with no `DragGesture` in the panel at all.
Two gestures attached to the *same* view compose fine, which is why the Z-Action
trigger lives on the input surface rather than on a button.

The `#if DEBUG` sign picker is unaffected because its `ScrollView` claims the
touch first. If a real on-screen control is ever needed down there, it will have
to live outside the swipe zone or inside a scroll container.
