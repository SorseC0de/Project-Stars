
## The board's layers

Added 2026-08-19, branch `board-layers`, after the fourth time adding something
to the board meant rediscovering the same four rules and getting one wrong.

**`BoardLayer`** names where a thing lives: `ground`, `groundMark`, `object`,
`piece`, `overhead`, `effect`. The layer answers, on its own:

- **shape** — `lies` layers are sheared into the ground's perspective, standing
  ones keep their own shape and are only scaled by depth;
- **order** — `z(row:)` is **row-major**: `row * 10 + layer`. Depth wins, and
  the layer only breaks ties inside one row. That is what makes grass on row 4
  draw in front of a piece on row 3 and behind one on row 4, with no second
  layer to keep in step. Effects sit above the whole scene.

**`onBoard(_:layer:in:)`** is the only placement. It shears or stands, centres
on the square, sets the `zIndex`, and applies any hover or bounce. Everything
else the board knows — the metrics, the plane, the projection, the ground's
give, the ambient clock — is handed down in a `BoardContext` rather than passed
as eleven arguments.

**Behaviour is set, not written.** `HoverStyle` carries the motions that kept
being rewritten — `.island` for the Nexys' heave, `.coin` for a Pentacle's small
orbit, `.star` for Polaris bobbing, turning and breathing. `BounceMoment` says
whether a thing takes the ground's give on entry, exit, or both.

**Adding something to the board is now:** draw it, name its layer, hand it a
square.

```swift
PentacleView(...)
    .onBoard(point, layer: .object, in: context(for: shown, metrics: metrics),
             hover: .coin)
```

`groundMark` and `placedOnPlaneModifier` survive as names for the twenty-odd
existing call sites; they are the same answer underneath. Migrate opportunistically
— do not rewrite the whole board at once.
