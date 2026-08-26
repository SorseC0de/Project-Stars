# The top screen as a scene

`LayerBench.scene` — **SCENE (spritekit)** in the layer bench — swaps the entire
SwiftUI board for `BoardScene`. Not layered under it: swapped for it. Layering
was the mistake in the first attempt, and it measured two renderers drawing one
board.

## Why

The SwiftUI board describes itself from scratch whenever the session publishes —
twenty-four times a second while a move resolves — and SwiftUI then diffs and
lays out the result. That cost does not scale with what is on the board, which
is why removing the ground, the panel, the clouds, the trail and the glow each
bought a few frames and none of them fixed it.

`BoardScene.update(_:)` runs on SpriteKit's own loop, reads the session outside
any view body — so nothing is observed and nothing is invalidated — and writes a
handful of positions. Whatever else changed that frame, that is what it costs.

## What is in it

| | |
|---|---|
| sky | one gradient texture, the height of the column, made once |
| ground | one node per square, both planes, rebuilt only when the board itself changes |
| drift | an `SKAction` per cloud, interpolated by the render thread |
| piece | one node; its texture is rebuilt only when the facing changes |
| cursor | brackets baked to a texture; only colour and place change |
| island | two nodes, the piece standing between them |
| coins | diffed against what is on the board, not rebuilt |
| camera | an `SKCameraNode` following `cameraRow` |

## What is not, yet

The facing arrow, effects and their sprites, the cloud wake and dip, tile wear
animation, afterimages, the charged glow, Gemini's halves, Libra's parts,
Aquarius' storm, the dim wash, the fracture. Every one of them is more nodes and
more `update`. None changes the shape of the answer.

Fidelity is approximate where it exists: the cursor has no flare or warning
pulse, the clouds have no wake, the piece has no bob or squash.

## The result

Measured: SwiftUI 28/35 late at 35fps; the scene **3–10 late out of 58–60 at
60fps**, while drawing more. The port is worth finishing.

Two things it also taught, both worth keeping:

- **SpriteKit does not complain about an absurd texture.** It crashes later, on
  the render thread, when Metal validates the descriptor. The sky was baked at
  its real size — 1179 by 10611 pixels — and took the app down. Bake small,
  size the *node*.
- **A scene built inside `body` is a new scene every time the body runs**, which
  is exactly what the port exists to avoid. Hold it in `@State`.

## How to read the comparison

On Astra, moving, read `late` with the toggle on and off.

The fairest existing number to compare against is **SwiftUI with `ground` off**,
which was 20/45 — because that board was down to about ten objects while the
scene draws the full ground, the island and the coins. If the scene wins while
drawing *more*, that is conclusive.

- **`late` collapses** → the diagnosis holds and the port is worth finishing.
- **`late` is unchanged** → a retained scene costs the same as a rebuilt tree,
  the rendering model is not the problem, and the answer is somewhere nobody has
  looked. That would be worth knowing before another week goes into it.

## If it wins, the order to finish it in

1. The facing arrow and the piece's bob and squash — small, and they make the
   scene playable rather than demonstrable.
2. Effects. They are already sprite strips; `SKAction.animate(with:)` plays them.
3. The wake and the dip — per-node actions fired on the event, not per frame.
4. The charged glow, as an additive sprite or an `SKEffectNode`.
5. The signs with assembled pieces: Gemini, Libra, Aquarius, Pisces.
6. Delete the SwiftUI board and its layer bench.

The panel, the overlays, the mode card and the death screen all stay SwiftUI.
None of them is in the per-frame path.

## Deferred: the perspective's true scale

The front and back row scales were asked for as 1.25x and 0.75x, and by eye they
are wrong in both directions — 1.25 too large in front, 0.75 too small behind.
The right numbers are derivable from the perspective the board actually uses
rather than guessed, and the eye's estimate is around 1.15 / 0.85.

**Not while the port is mid-flight.** It is a global change to every position and
size on both boards, and making it now would mean never knowing which of the two
things moved something. Once the scene matches the SwiftUI board, this is the
first thing to do after.
