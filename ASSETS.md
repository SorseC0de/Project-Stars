# Sprite sheets

Everything the game draws is 16x16 unless noted. Art comes in one of two ways
and the game takes whichever it finds, per sprite — so a **partial import is
fine**. Bring one sheet, or one row, and the rest keeps drawing placeholders
until you get to it.

## 1. Sheets — the recommended route

Three sheets, all 16px cells, laid out left-to-right then top-to-bottom.

| Sheet | Cells | Size @1x |
|---|---|---|
| `sheet_board` | 6 x 2 | 96 x 32 |
| `sheet_pieces` | 12 x 1 | 192 x 16 |
| `sheet_pentacles` | 12 x 2 | 192 x 32 |

Grid guides matching these exactly are in `Sheet Guides/` — draw over them and
delete the guide layer before exporting.

### `sheet_board`

Row 0 is **Astra**, row 1 is **Terra**, same order across both:

| Col | 0 | 1 | 2 | 3 | 4 | 5 |
|---|---|---|---|---|---|---|
| | healthy | cracked | badly cracked | hole | Nexys | chasm |

The Nexys is the floating island; the chasm is the permanent gap it leaves on
whichever plane it is *not* on. Both are structural — they never wear — so they
need one frame each, not four.

### `sheet_pieces`

Row 0, zodiacal order:

`0` aries · `1` taurus · `2` gemini · `3` cancer · `4` leo · `5` virgo · `6` libra · `7` scorpio · `8` sagittarius · `9` capricorn · `10` aquarius · `11` pisces

### `sheet_pentacles`

Row 0 — the coin, then effects:

| Col | 0 | 1 | 2 | 3 | 4–7 |
|---|---|---|---|---|---|
| | Pentacle | Shadow Work coin | Polaris coin | piece drop-shadow | sparkle, 4 frames |

The sparkle's four frames run left to right and loop. Every other coin is a
still.

Row 1 — the face struck into each Pentacle, shown **only** on the
first-encounter splash. The coin on the board never reveals which effect it
holds, so these are never drawn in play:

`0` zCharge · `1` restoreTile · `2` astralBrook · `3` astralBreeze · `4` astralBlaze · `5` astralBlossom · `6` cornerWarp · `7` nexysShift · `8` forcedFate · `9` alignment · `10` polaris · `11` shadowWork

### Plane backdrops

Not on a sheet: they are 7x7 cells (112 x 112) each and would dominate one. Add
them as their own image sets, named `bg_astra` and `bg_terra`.

## 2. Individual image sets — the fallback

Any sprite can instead be an image set named after its `SpriteID.assetName`.
Useful for one-offs and for anything you want to override without touching a
sheet. Full list of names below.

## Adding art to Xcode

1. Drag the PNG into `Assets.xcassets`.
2. Name the image set exactly as above.
3. Put the file in the **1x** slot and leave 2x/3x empty. The game scales pixel
   art itself by whole numbers (`PixelArtMetrics`) with nearest-neighbour
   filtering — a 2x source would be scaled twice and lose its edges.

A sheet exported at 2x in the 2x slot also works: `SpriteSheetLoader` multiplies
every cell by the image's scale, so the layout numbers never change. Do not mix
scales across slots on one sheet.

## Moving things around

The layout above lives in `Art/SpriteAtlas.swift` as plain numbers. If the art
is arranged differently, change the atlas rather than the art — nothing else in
the project knows where a sprite sits.

## Full asset-name list

Used by the individual-image-set route, and as a checklist.

**Board** — `bg_astra`, `tile_astra_healthy`, `tile_astra_cracked`, `tile_astra_badlyCracked`, `tile_astra_hole`, `tile_astra_nexys`, `tile_astra_chasm`, `bg_terra`, `tile_terra_healthy`, `tile_terra_cracked`, `tile_terra_badlyCracked`, `tile_terra_hole`, `tile_terra_nexys`, `tile_terra_chasm`

**Pieces** — `piece_aries`, `piece_taurus`, `piece_gemini`, `piece_cancer`, `piece_leo`, `piece_virgo`, `piece_libra`, `piece_scorpio`, `piece_sagittarius`, `piece_capricorn`, `piece_aquarius`, `piece_pisces`

**Coins** — `pickup_pentacle`, `pickup_pentacle_shadow`, `pickup_pentacle_radiant`

**Pentacle faces** — `pentacle_zCharge`, `pentacle_restoreTile`, `pentacle_astralBrook`, `pentacle_astralBreeze`, `pentacle_astralBlaze`, `pentacle_astralBlossom`, `pentacle_cornerWarp`, `pentacle_nexysShift`, `pentacle_forcedFate`, `pentacle_alignment`, `pentacle_polaris`, `pentacle_shadowWork`

**Effects** — `fx_sparkle`, `fx_shadow`
