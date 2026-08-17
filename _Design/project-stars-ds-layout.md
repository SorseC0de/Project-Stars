# Project Stars Ds Layout

> Think of Project Stars as a Nintendo DS game — the top screen is display only, every control lives in the bottom half.


Project Stars is laid out as a **Nintendo DS game**: two stacked squares, the
board on top and the controls beneath. The upper square is a **display**. It is
never interactable.

Every control lives in the bottom half — the joystick, the direction pad, the
tap-a-square grid, the Zodiaction button, and any question the game asks (which
square to warp to, where to drop Libra's slab). Anything that would otherwise
want a tap on the board goes to the panel instead.

**Why:** It is the shape of the game, and it is also the ergonomics — the top of
a phone is the hardest place to reach and the place your own hand covers while
reaching. A board that sometimes takes taps also makes the player wonder, every
turn, whether this is one of those times.

**How to apply:** Do not add tap targets, gestures or dismiss-on-tap to anything
in the upper square, and remove them where they exist. A splash or banner is
dismissed by *reaching for the controls* — a swipe, an arrow key, a direction
button — not by tapping it away. See also [[project-stars-architecture]].
