//
//  SpriteAtlas.swift
//  Project Stars
//
//  Where each sprite sits on the master sheet. The one file to edit if art moves.
//

import Foundation

// MARK: - SpriteSlice

/// A rectangle of a sprite sheet, in pixels.
///
/// Most sprites land on the 16px cell grid and are easiest to declare with
/// ``cells(_:column:row:width:height:)``. A few — the cursor's 8x8 brackets —
/// sit inside a cell, so the underlying representation is plain pixels.
struct SpriteSlice: Equatable {

    /// Image set name of the sheet this lives on.
    let sheet: String

    /// Pixel origin and size within the sheet, at 1x.
    let x: Int
    let y: Int
    let width: Int
    let height: Int

    /// Animation frames, laid out left-to-right starting at `x`.
    /// `1` is a still image.
    let frames: Int

    /// How many frames sit on one row before the strip wraps.
    ///
    /// Everything imported so far is a single row, and that is still the
    /// default. Wrapping exists because `actool` does not cope with a very wide
    /// image: Gemini's rift is sixty 256px frames, and at 15360x256 the asset
    /// compiler ground for over twenty minutes without finishing. The same
    /// frames as an 8x8 grid are 2048 square and compile instantly.
    ///
    /// Reflowed by blitting whole frames, so the art is untouched — this is a
    /// packing question, not an art one.
    let columns: Int

    /// Seconds per frame. Ignored when `frames == 1`.
    ///
    /// Set this from a `SpriteRate` rather than as a literal — see that type for
    /// why the hold, not the duration, is the number worth naming.
    let frameDuration: TimeInterval

    init(
        sheet: String,
        x: Int, y: Int,
        width: Int, height: Int,
        frames: Int = 1,
        columns: Int? = nil,
        frameDuration: TimeInterval = GameRules.defaultSpriteRate.frameDuration
    ) {
        self.sheet = sheet
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.frames = max(frames, 1)
        self.columns = max(columns ?? max(frames, 1), 1)
        self.frameDuration = frameDuration
    }

    /// A slice declared on the 16px cell grid.
    ///
    /// - Parameters:
    ///   - width: Span in cells. The Nexys is 3, a piece is 1.
    ///   - height: Span in cells. A piece is 2 (16x32), the Nexys 3.
    static func cells(
        sheet: String = SpriteAtlas.masterSheet,
        column: Int,
        row: Int,
        width: Int = 1,
        height: Int = 1,
        frames: Int = 1,
        frameDuration: TimeInterval = GameRules.defaultSpriteRate.frameDuration
    ) -> SpriteSlice {
        let cell = GameRules.tilePixelSize
        return SpriteSlice(
            sheet: sheet,
            x: column * cell, y: row * cell,
            width: width * cell, height: height * cell,
            frames: frames, frameDuration: frameDuration
        )
    }

    /// The pixel rect of one frame.
    func pixelRect(frame: Int) -> (x: Int, y: Int, width: Int, height: Int) {
        let index = frame % frames
        return (
            x + (index % columns) * width,
            y + (index / columns) * height,
            width,
            height
        )
    }
}

// MARK: - SpriteAtlas

/// The map from every `SpriteID` to its place on the sheet.
///
/// ## How art gets in
///
/// Two routes, taken per sprite, first hit wins:
///
/// 1. **The master sheet**, sliced here. Nearly everything.
/// 2. **An individual image set** named `SpriteID.assetName`, for one-offs and
///    for anything not yet on the sheet.
///
/// Anything with neither keeps drawing its placeholder, so a partial import is
/// never a broken build.
///
/// ## Deliberately absent
///
/// - **Sparkles** are still drawn programmatically. They are wanted for the
///   tutorial splash graphics, where they have to be generated rather than
///   photographed.
/// - **Shadows** are a programmatic ellipse in `Palette.shadow` — see
///   `PieceShadowView`. Cheap to swap for a sprite if it ever looks pasted-on.
/// - **Plane backdrops** are 112x112 and would swamp the sheet; they resolve as
///   `bg_astra` / `bg_terra` image sets if they ever exist.
enum SpriteAtlas {

    /// The sheet nearly everything comes from.
    static let masterSheet = "Master Spritesheet"

    /// The Pentacle's own sheet.
    ///
    /// Standalone rather than on the master sheet because the coin's sparkles
    /// spill a full cell in every direction — it needs 48x48 per frame, and
    /// eight frames of that would dominate any sheet it shared.
    static let pentacleSheet = "Pentacle"

    /// Astra's clouds: 144x96, three 48x48 frames across and two rows — the
    /// light variant above the dark.
    static let cloudSheet = "Astra_Cloud"

    /// The landing puffs, one sheet per plane. Five 32x32 frames in a row each.
    static func smokeSheet(for plane: Plane) -> String {
        switch plane {
        case .astra: "Astra_Smoke"
        case .terra: "Terra_Smoke"
        }
    }

    // MARK: - Layout
    //
    // Coordinates are cells on a 16px grid, (column, row) from the top-left.
    // These are the numbers to change if the sheet is rearranged — nothing else
    // in the project knows where a sprite lives.

    /// How far everything that is **not** a sign sits from the left edge.
    ///
    /// Six cells were added to the left of the sheet to fit the twelve statues
    /// in zodiac order, so every other sprite moved right by that much. Adding
    /// it here rather than to each number means the next time the block grows
    /// it is one edit again.
    /// How far the sheet's contents have moved since the coordinates below were
    /// written, in cells.
    ///
    /// Two numbers, not one. Columns were added to the **left** of the sheet, so
    /// everything that is not a sign moved right — but the next edit may just as
    /// easily be a row added above, and a single `sheetShiftX` cannot express
    /// that. Worse, columns are named in one place and rows are literals
    /// scattered through the map, so a vertical move would have to be found by
    /// hand thirty-one times and would fail silently wherever it was missed.
    ///
    /// Keeping both means the next resize is two numbers rather than an audit.
    ///
    /// - Note: Signs are exempt. They start at column zero and the insert went
    ///   in beside them, so their own coordinates never moved.
    private static let sheetShiftX = 6
    /// **Zero, and rows are absolute again.**
    ///
    /// Four rows went in above everything on 2026-08-20 to make room for the
    /// signs facing all four ways. Carrying that as a shift would have meant
    /// half the file speaking the old sheet's numbering and half the new one —
    /// every row written from here on is read straight off the sheet, so the
    /// move is baked into the numbers instead and this is back to a clean base
    /// for the next one.
    ///
    /// It also has to stay off anything that is not the master sheet: it was
    /// being added to the Pentacle sheet, which is one row tall, and sent the
    /// coin clean off it — the drawn fallback appearing was the only sign.
    private static let sheetShiftY = 0

    /// Column of each tile face variant, before `sheetShiftX`.
    private enum TileColumn {
        static let light = 3 + SpriteAtlas.sheetShiftX
        static let dark = 4 + SpriteAtlas.sheetShiftX
        static let lightPopped = 5 + SpriteAtlas.sheetShiftX
        static let darkPopped = 6 + SpriteAtlas.sheetShiftX
        /// Edge strips sit under the *popped* columns, not the plain ones.
        static let lightEdge = 5 + SpriteAtlas.sheetShiftX
        static let darkEdge = 6 + SpriteAtlas.sheetShiftX
        static let cracked = 7 + SpriteAtlas.sheetShiftX
        static let badlyCracked = 8 + SpriteAtlas.sheetShiftX
        static let hole = 9 + SpriteAtlas.sheetShiftX
    }

    /// The two rows the turn counter was drawn into, in raw sheet cells.
    private enum TurnRow {
        /// The hand-drawn turn-over: nine frames of a numeral rolling.
        static let roll = 13
        static let digits = 14
        static let furniture = 15
    }

    /// Where the ground cover sits, in raw sheet cells.
    private enum GrassRow {
        static let light = 10
        static let dark = 11
        /// The first drawn grass, kept: it is a finished tile with its own dirt
        /// in it, and worth having beside the generated one.
        static let drawn = 3

        /// **The blank.** What used to be the second drawn grass — sampling the
        /// sheet, it is two colours and no detail, where its neighbour has six.
        /// This is the tile the generator works on: dirt specked onto it and
        /// blades standing above it.
        static let blank = 4

        static let flowers = 5
    }

    /// Row of the drawn tile block. The face is on `row`, its edge on `row + 1`.
    ///
    /// Only Terra has one. Astra's squares are clusters of cloud drawn by
    /// `CloudTileView`, so there is nothing here to point at — which is also why
    /// the warmer orange set further down the sheet is currently unused.
    private static let terraTileRow = 8

    /// Every sprite that comes from the sheet.
    static let slices: [SpriteID: SpriteSlice] = {
        var map: [SpriteID: SpriteSlice] = [:]

        // ── Tiles ────────────────────────────────────────────────────────
        // Terra only — see `terraTileRow`.
        for plane in [Plane.terra] {
            let row = terraTileRow

            map[.tileFace(plane, .light, popped: false)] = .cells(column: TileColumn.light, row: row)
            map[.tileFace(plane, .dark, popped: false)] = .cells(column: TileColumn.dark, row: row)
            map[.tileFace(plane, .light, popped: true)] = .cells(column: TileColumn.lightPopped, row: row)
            map[.tileFace(plane, .dark, popped: true)] = .cells(column: TileColumn.darkPopped, row: row)

            // Edge strips live on the row below, under columns 5 and 6 — the
            // side of a tile does not change with the checkerboard shade, so the
            // two are near enough identical; both are mapped so a future
            // difference needs no code change.
            map[.tileEdge(plane, .light)] = .cells(column: TileColumn.lightEdge, row: row + 1)
            map[.tileEdge(plane, .dark)] = .cells(column: TileColumn.darkEdge, row: row + 1)

            map[.tileDamage(plane, .cracked)] = .cells(column: TileColumn.cracked, row: row)
            map[.tileDamage(plane, .badlyCracked)] = .cells(column: TileColumn.badlyCracked, row: row)
            map[.tileDamage(plane, .hole)] = .cells(column: TileColumn.hole, row: row)
        }

        // ── The turn counter ─────────────────────────────────────────────
        //
        // Two rows at the very bottom, in raw sheet cells: the numerals across
        // row 10, and the counter's furniture on row 11 — the label over two
        // cells, the cap, then the plate over three.
        //
        // Each numeral is drawn against the **bottom right** of its cell, so a
        // digit can be laid down on a plain 16-point square and land where it
        // should without the layout knowing anything about the glyph inside it.
        for value in 0...9 {
            map[.digit(value)] = .cells(column: value, row: TurnRow.digits)
        }
        for frame in 0...8 {
            map[.turnRoll(frame)] = .cells(column: frame, row: TurnRow.roll)
        }
        // The four crystals, on their own sheet: 48 by 96 each, in the order
        // they were drawn — fire, air, earth, water.
        for (index, element) in [
            ZodiacElement.fire, .air, .earth, .water,
        ].enumerated() {
            map[.polarityProng(element)] = SpriteSlice(
                sheet: "crystal_poles",
                x: index * 48, y: 0,
                width: 48, height: 96
            )
        }

        // Terra's scenery, on its own sheet: seven cells across, the ridge on
        // the top three rows and the rock on the bottom two.
        map[.terraScenery(.backdrop)] = .cells(
            sheet: "Terra_Scenery", column: 0, row: 0, width: 7, height: 3
        )
        map[.terraScenery(.midground)] = .cells(
            sheet: "Terra_Scenery", column: 0, row: 0, width: 7, height: 3
        )
        map[.terraScenery(.midLeft)] = .cells(
            sheet: "Terra_Scenery", column: 0, row: 3, width: 2, height: 2
        )
        map[.terraScenery(.midRight)] = .cells(
            sheet: "Terra_Scenery", column: 5, row: 3, width: 2, height: 2
        )
        map[.terraScenery(.foreground)] = .cells(
            sheet: "Terra_Scenery", column: 0, row: 5, width: 7, height: 2
        )

        // **Seven cells across and two down.** They are centred inside that
        // pair of rows, which is why reading them as one row tall clipped the
        // plaque itself rather than anything drawn in it.
        map[.planeBadge(.astra)] = .cells(
            column: 10, row: TurnRow.digits, width: 7, height: 2
        )
        map[.planeBadge(.terra)] = .cells(
            column: 18, row: TurnRow.digits, width: 7, height: 2
        )
        map[.turnLabel] = .cells(column: 0, row: TurnRow.furniture, width: 2)
        map[.turnCap] = .cells(column: 2, row: TurnRow.furniture)
        map[.turnPlateLeft] = .cells(column: 3, row: TurnRow.furniture)
        map[.turnPlateMiddle] = .cells(column: 4, row: TurnRow.furniture)
        map[.turnPlateRight] = .cells(column: 5, row: TurnRow.furniture)

        // ── Ground cover ─────────────────────────────────────────────────
        //
        // Two rows of three: the light shade above the dark, and within each
        // row the two grass drawings followed by the flowered one. Declared in
        // **raw sheet cells** rather than against `sheetShiftX`, because these
        // were drawn into the sheet as it stands today — the shift describes
        // where the older art moved to, and nothing that arrives now needs it.
        for (shade, coverRow) in [
            (Palette.TileShade.light, GrassRow.light),
            (Palette.TileShade.dark, GrassRow.dark),
        ] {
            // Both levels of ordinary cover are generated now — the variety
            // that grass and tuft used to carry between them comes from the
            // straw each square draws. See `DirtPatterns`.
            map[.tileCover(shade, .grass)] = .cells(column: GrassRow.blank, row: coverRow)
            map[.tileCover(shade, .tuft)] = .cells(column: GrassRow.blank, row: coverRow)
            map[.tileCover(shade, .flowers)] = .cells(column: GrassRow.flowers, row: coverRow)
        }

        // ── Effects ──────────────────────────────────────────────────────
        // Each is its own strip rather than a region of the master sheet: they
        // are 64px, they are long, and they arrive one file at a time. The whole
        // slice is derived from the sprite, so importing another one is a case
        // in `EffectSprite` and nothing here.
        for effect in EffectSprite.allCases {
            map[.effect(effect)] = SpriteSlice(
                sheet: effect.assetName,
                x: 0, y: 0,
                width: Int(effect.frameSize.width),
                height: Int(effect.frameSize.height),
                frames: effect.frames,
                columns: effect.stripColumns,
                frameDuration: effect.rate.frameDuration
            )
        }

        // ── Nexys ────────────────────────────────────────────────────────
        // 48x48. Its middle cell is the tile it stands on; the overhang is the
        // island's rim and the greenery spilling off it.
        map[.nexys] = .cells(column: 12 + sheetShiftX, row: 6, width: 3, height: 3)

        // ── Pieces ───────────────────────────────────────────────────────
        // 16x32 — a piece is twice a tile's height.
        //
        // **One column per sign, in astrological order from the left edge**,
        // and three facings stacked down it: left on rows 1-2, up on 3-4, down
        // on 5-6. East is west mirrored, so four directions cost three
        // drawings. This replaced a block that was contiguous by nothing —
        // Gemini took three columns, Cancer took three for the only facings
        // that existed, and a drawing guide sat in the middle of it.
        let column: [Zodiac: Int] = [
            .aries: 0, .taurus: 1, .gemini: 2, .cancer: 3,
            .leo: 4, .virgo: 5, .libra: 6, .scorpio: 7,
            .sagittarius: 8, .capricorn: 9, .aquarius: 10, .pisces: 11,
        ]

        /// Which row a facing's drawing starts on.
        func facingRow(_ facing: SwipeDirection) -> Int {
            switch facing {
            case .left, .right: 1
            case .up: 3
            // Diagonals never reach here: a diagonal move resolves to one of
            // the cardinals before the piece's facing is set. See
            // `SwipeDirection.facing(from:)`. Front view if one ever does.
            default: 5
            }
        }

        for sign in Zodiac.allCases {
            let col = column[sign] ?? 0

            // **Pisces is one cell**, on the *bottom* cell of his block so his
            // feet line up with everyone else's. His body was redrawn short and
            // his top half became a separate sprite.
            let short = sign == .pisces

            for facing in SwipeDirection.cardinals {
                map[.pieceFacing(sign, facing)] = .cells(
                    column: col,
                    row: facingRow(facing) + (short ? 1 : 0),
                    height: short ? 1 : 2
                )
            }

            // The plain `.piece` is the south-facing drawing — it is what the
            // sign picker, the storm and every other still of a Zodea use.
            map[.piece(sign)] = .cells(
                column: col,
                row: facingRow(.down) + (short ? 1 : 0),
                height: short ? 1 : 2
            )
        }

        // ── Gemini keeps one face ────────────────────────────────────────
        //
        // **Deliberately no facings.** Two figures that each turn to face four
        // ways is two sets of drawings to keep straight while the player is
        // already keeping two twins straight — the halves read more clearly
        // when they always look the same way. So Gemini's column spends its
        // three slots on the halves instead: silver where left would be, gold
        // where up would be, and the whole pair facing south.
        map[.geminiHalf(.silver)] = .cells(column: 2, row: 1, height: 2)
        map[.geminiHalf(.gold)] = .cells(column: 2, row: 3, height: 2)
        for facing in SwipeDirection.cardinals {
            map[.pieceFacing(.gemini, facing)] = .cells(column: 2, row: 5, height: 2)
        }

        // ── Pisces, in two halves ────────────────────────────────────────
        //
        // The composite above is what is drawn nearly always. These two are for
        // the one case where the halves come apart — with the accessories now,
        // since that is what they are.
        map[.piscesFish] = .cells(column: 13, row: 4)
        map[.piscesFishCharged] = .cells(column: 14, row: 4)

        // ── Virgo's floating gems ────────────────────────────────────────
        //
        // Five drawings for three facings. South and north each use a middle
        // gem and one side gem mirrored into a pair; the side-on view needs
        // three distinct gems because there is no symmetry left to exploit —
        // one behind her, one out in front, and the middle further out than
        // either. Which drawing goes where is `PieceView.gemCast`.
        map[.virgoGem(.south)] = .cells(column: 13, row: 0)
        map[.virgoGem(.southWest)] = .cells(column: 14, row: 0)
        map[.virgoGem(.west)] = .cells(column: 15, row: 0)
        map[.virgoGem(.north)] = .cells(column: 16, row: 0)
        map[.virgoGem(.northWest)] = .cells(column: 17, row: 0)

        // The archer's nocked arrow, one drawing per axis — the same two-way
        // split Libra's arms take, and for the same reason: north is south seen
        // from behind, and east is west mirrored.
        // ── Scorpio's tail ───────────────────────────────────────────────
        //
        // A stinger per way of pointing and one link repeated behind it. East
        // is west mirrored, the same three-for-four the pieces take.
        map[.scorpioStinger(.left)] = .cells(column: 13, row: 5)
        map[.scorpioStinger(.right)] = .cells(column: 13, row: 5)
        map[.scorpioStinger(.down)] = .cells(column: 14, row: 5)
        map[.scorpioStinger(.up)] = .cells(column: 15, row: 5)
        map[.scorpioTailLink] = .cells(column: 16, row: 5)

        map[.sagittariusArrowRest(.northSouth)] = .cells(column: 13, row: 3)
        map[.sagittariusArrowRest(.eastWest)] = .cells(column: 14, row: 3)

        map[.libraArm(.northSouth)] = .cells(column: 13, row: 2)
        map[.libraArm(.eastWest)] = .cells(column: 14, row: 2)
        // Gemini's halves, either side of the whole.
        //
        // Their own drawings rather than a recolour: Soul Split leaves one
        // behind and takes the other, and two figures that are the same sprite
        // in two tints are one figure the player has to keep track of twice.


        // The plain scales, drawn once rather than computed.
        //
        // The uncharged pans used to be the coloured ones with every strand
        // palette-swapped to a single purple and the animation pinned to one
        // frame — a shader and a frame lock to arrive at a drawing that now
        // simply exists.
        // Straight above Libra: the dull pan, then the three lit frames.
        map[.libraScalesPlain] = .cells(column: 13, row: 1)

        map[.libraScales] = SpriteSlice(
            sheet: masterSheet,
            x: 14 * GameRules.tilePixelSize,
            y: 1 * GameRules.tilePixelSize,
            width: GameRules.tilePixelSize,
            height: GameRules.tilePixelSize,
            frames: 3,
            frameDuration: GameRules.libraScalesRate.frameDuration
        )

        // The hole a Gavel slab carries onto Astra.
        //
        // Astra has no tiles, so a slab of holes placed there drew nothing at
        // all — the shape was invisible until it landed. This is a cloud-side
        // stand-in for one.
        // ── Umbra ─────────────────────────────────────────────────────────
        //
        // Wired ahead of the plane itself: the art exists, and an atlas entry
        // costs nothing until something asks for it. See the Umbra design note.
        map[.umbraFloor(.light)] = .cells(column: 0 + sheetShiftX, row: 9)
        map[.umbraFloor(.dark)] = .cells(column: 1 + sheetShiftX, row: 9)
        map[.umbraEdge(.light)] = .cells(column: 0 + sheetShiftX, row: 10)
        map[.umbraEdge(.dark)] = .cells(column: 1 + sheetShiftX, row: 10)

        map[.umbraDecor(0)] = .cells(column: 1 + sheetShiftX, row: 7)
        map[.umbraDecor(1)] = .cells(column: 1 + sheetShiftX, row: 8)
        map[.umbraDecorRare] = .cells(column: 2 + sheetShiftX, row: 7)

        // Two cells tall, like a piece — it stands on the board rather than
        // lying in it.
        map[.umbraRock] = .cells(column: 0 + sheetShiftX, row: 7, height: 2)

        map[.astraHole] = .cells(column: 0 + sheetShiftX, row: 12)

        // The coin a piece carries over its head.
        map[.carriedCoin] = .cells(column: TileColumn.hole + 2, row: terraTileRow)

        // ── Pentacle ─────────────────────────────────────────────────────
        // Eight 48x48 frames laid out left to right. The coin itself is the
        // middle cell; the surrounding ring is the sparkle, which is why this is
        // drawn three tiles wide rather than one.
        // Shadow Work's coin is the *same sheet*, recoloured at draw time by a
        // palette swap — see `PentacleView`. Keeping it as one sheet means the
        // two can never fall out of step when the coin is redrawn.
        map[.pentacle(.shadow)] = .cells(
            sheet: pentacleSheet,
            column: 0, row: 0,
            width: 3, height: 3,
            frames: 8,
            frameDuration: GameRules.pentacleRate.frameDuration
        )

        // Polaris: a single 16x16 star on the master sheet. No frames of its
        // own — all of its motion is applied by the view.
        map[.pentacle(.radiant)] = .cells(column: 12 + sheetShiftX, row: 9)

        // The cell to its left: the same fragment, cold.
        map[.pentacle(.dormant)] = .cells(column: 11 + sheetShiftX, row: 9)

        // An ordinary coin, not spinning — (17, 6) on the sheet, a row below
        // the two Polaris cells rather than beside them.
        map[.pentacle(.still)] = .cells(column: 11 + sheetShiftX, row: 10)

        map[.pentacle(.standard)] = .cells(
            sheet: pentacleSheet,
            column: 0, row: 0,
            width: 3, height: 3,
            frames: 8,
            frameDuration: GameRules.pentacleRate.frameDuration
        )

        // TODO: Polaris is a 16x16 cell among the gold stars around columns
        // 11–14, rows 5–7 — exact cell not yet confirmed, so it stays unmapped
        // and falls back to its placeholder. It never spawns anyway (weight 0).
        // It should float like the coin and sparkle programmatically.

        // ── Smoke ────────────────────────────────────────────────────────
        // Five 32x32 frames — two cells square — played once per landing rather
        // than looped. See `SmokeBurstView`.
        for plane in Plane.allCases {
            map[.smoke(plane)] = .cells(
                sheet: smokeSheet(for: plane),
                column: 0, row: 0,
                width: 2, height: 2,
                frames: GameRules.smokeFrameCount,
                frameDuration: GameRules.smokeRate.frameDuration
            )
        }

        // ── Astra's clouds ───────────────────────────────────────────────
        // One strip per shade, three frames each, played ping-pong. The cell is
        // 48px — three board squares wide — so neighbouring clouds overlap
        // heavily. That is the intent: the drift and the stretch break up the
        // grid, and the row-by-row depth sort keeps the overlap readable.
        for (row, shade) in [Palette.TileShade.light, .dark].enumerated() {
            map[.astraCloud(shade)] = SpriteSlice(
                sheet: cloudSheet,
                x: 0, y: row * GameRules.cloudSpritePixelSize,
                width: GameRules.cloudSpritePixelSize,
                height: GameRules.cloudSpritePixelSize,
                frames: GameRules.cloudSpriteFrames,
                frameDuration: GameRules.cloudSpriteRate.frameDuration
            )
        }

        // ── Direction guide ──────────────────────────────────────────────
        // One 48x48 cell per cardinal, in the order they were drawn: N S E W.
        // Its own sheet rather than the master, because it is HUD rather than
        // board art and is authored at the board's tile size.
        let guideOrder: [SwipeDirection] = [.up, .down, .right, .left]
        for (column, direction) in guideOrder.enumerated() {
            map[.directionGuide(direction)] = SpriteSlice(
                sheet: "direction_guide",
                x: column * GameRules.compassPixelSize, y: 0,
                width: GameRules.compassPixelSize,
                height: GameRules.compassPixelSize
            )
        }

        // ── Cursor ───────────────────────────────────────────────────────
        // One 16x16 cell per colour, holding all four brackets. Cut into 8x8
        // quarters so each can be pushed outward as the cursor flares.
        // Column 5's green set is the "you may choose this" bracket, used while
        // a Pentacle or an ability is asking which square.
        let cursorColumn: [CursorTint: Int] = [
            .red: 2 + sheetShiftX, .yellow: 3 + sheetShiftX, .orange: 4 + sheetShiftX,
            .green: 5 + sheetShiftX, .white: 6 + sheetShiftX,
        ]
        for (tint, column) in cursorColumn {
            for corner in CursorCorner.allCases {
                let origin = corner.originInCell
                map[.cursorCorner(tint, corner)] = SpriteSlice(
                    sheet: masterSheet,
                    x: column * GameRules.tilePixelSize + origin.x,
                    y: 12 * GameRules.tilePixelSize + origin.y,
                    width: 8, height: 8
                )
            }
        }
        map[.cursorWarning] = .cells(column: 1 + sheetShiftX, row: 12)

        // ── Direction arrows ─────────────────────────────────────────────
        // Row 9, in the order they sit on the sheet.
        // Two sets on the same row: the plain white arrows, and the
        // astral-energy ones four cells along for a sign's longer move.
        let arrowColumn: [SwipeDirection: Int] = [
            .left: 3 + sheetShiftX, .down: 4 + sheetShiftX,
            .up: 5 + sheetShiftX, .right: 6 + sheetShiftX
        ]
        let specialOffset = 4

        for (direction, column) in arrowColumn {
            map[.directionArrow(direction)] = .cells(column: column, row: 13)
            map[.specialArrow(direction)] = .cells(column: column + specialOffset, row: 13)
        }

        return map
    }()

    /// Where a sprite lives, or `nil` if it does not come from a sheet.
    static func slice(for id: SpriteID) -> SpriteSlice? {
        slices[id]
    }

    /// Every sheet the atlas references.
    static var sheetNames: [String] {
        Array(Set(slices.values.map(\.sheet))).sorted()
    }
}
