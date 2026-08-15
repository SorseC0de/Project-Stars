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
        frameDuration: TimeInterval = GameRules.defaultSpriteRate.frameDuration
    ) {
        self.sheet = sheet
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.frames = max(frames, 1)
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
        (x + (frame % frames) * width, y, width, height)
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

    /// Column of each tile face variant.
    private enum TileColumn {
        static let light = 3
        static let dark = 4
        static let lightPopped = 5
        static let darkPopped = 6
        /// Edge strips sit under the *popped* columns, not the plain ones.
        static let lightEdge = 5
        static let darkEdge = 6
        static let cracked = 7
        static let badlyCracked = 8
        static let hole = 9
    }

    /// Row of the drawn tile block. The face is on `row`, its edge on `row + 1`.
    ///
    /// Only Terra has one. Astra's squares are clusters of cloud drawn by
    /// `CloudTileView`, so there is nothing here to point at — which is also why
    /// the warmer orange set further down the sheet is currently unused.
    private static let terraTileRow = 4

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
                frameDuration: effect.rate.frameDuration
            )
        }

        // ── Nexys ────────────────────────────────────────────────────────
        // 48x48. Its middle cell is the tile it stands on; the overhang is the
        // island's rim and the greenery spilling off it.
        map[.nexys] = .cells(column: 12, row: 2, width: 3, height: 3)

        // ── Pieces ───────────────────────────────────────────────────────
        // 16x32 — a piece is twice a tile's height.
        //
        // TODO: Every sign currently points at Pisces. Give each its own column
        // as the art arrives; this is the only line that needs to change.
        // Every sign still falls back to Pisces; the ones that are drawn say so
        // here. This is the only line each needs when its art arrives.
        let piscesColumn = 6
        let drawn: [Zodiac: Int] = [
            .aries: 0,
            .leo: 2,
            .pisces: piscesColumn,
            .libra: 8,
            .gemini: 4,
        ]
        for sign in Zodiac.allCases {
            map[.piece(sign)] = .cells(
                column: drawn[sign] ?? piscesColumn,
                row: 1,
                height: 2
            )
        }

        // ── Libra's loose parts ──────────────────────────────────────────
        // The scales are carried, not worn: two arms and two pans that sit at
        // their own depths around the body. See `LibraPieceView`.
        map[.libraArm(.northSouth)] = .cells(column: 10, row: 1)
        map[.libraArm(.eastWest)] = .cells(column: 10, row: 2)
        // Gemini's halves, either side of the whole.
        //
        // Their own drawings rather than a recolour: Soul Split leaves one
        // behind and takes the other, and two figures that are the same sprite
        // in two tints are one figure the player has to keep track of twice.
        map[.geminiHalf(.gold)] = .cells(column: 3, row: 1, height: 2)
        map[.geminiHalf(.silver)] = .cells(column: 5, row: 1, height: 2)

        // The plain scales, drawn once rather than computed.
        //
        // The uncharged pans used to be the coloured ones with every strand
        // palette-swapped to a single purple and the animation pinned to one
        // frame — a shader and a frame lock to arrive at a drawing that now
        // simply exists.
        map[.libraScalesPlain] = .cells(column: 11, row: 1)

        map[.libraScales] = SpriteSlice(
            sheet: masterSheet,
            x: 12 * GameRules.tilePixelSize,
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
        map[.umbraFloor(.light)] = .cells(column: 0, row: 5)
        map[.umbraFloor(.dark)] = .cells(column: 1, row: 5)
        map[.umbraEdge(.light)] = .cells(column: 0, row: 6)
        map[.umbraEdge(.dark)] = .cells(column: 1, row: 6)

        map[.umbraDecor(0)] = .cells(column: 1, row: 3)
        map[.umbraDecor(1)] = .cells(column: 1, row: 4)
        map[.umbraDecorRare] = .cells(column: 2, row: 3)

        // Two cells tall, like a piece — it stands on the board rather than
        // lying in it.
        map[.umbraRock] = .cells(column: 0, row: 3, height: 2)

        map[.astraHole] = .cells(column: 0, row: 8)

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
        map[.pentacle(.radiant)] = .cells(column: 12, row: 5)

        // The cell to its left: the same fragment, cold.
        map[.pentacle(.dormant)] = .cells(column: 11, row: 5)

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
            .red: 2, .yellow: 3, .orange: 4, .green: 5, .white: 6,
        ]
        for (tint, column) in cursorColumn {
            for corner in CursorCorner.allCases {
                let origin = corner.originInCell
                map[.cursorCorner(tint, corner)] = SpriteSlice(
                    sheet: masterSheet,
                    x: column * GameRules.tilePixelSize + origin.x,
                    y: 8 * GameRules.tilePixelSize + origin.y,
                    width: 8, height: 8
                )
            }
        }
        map[.cursorWarning] = .cells(column: 1, row: 8)

        // ── Direction arrows ─────────────────────────────────────────────
        // Row 9, in the order they sit on the sheet.
        // Two sets on the same row: the plain white arrows, and the
        // astral-energy ones four cells along for a sign's longer move.
        let arrowColumn: [SwipeDirection: Int] = [.left: 3, .down: 4, .up: 5, .right: 6]
        let specialOffset = 4

        for (direction, column) in arrowColumn {
            map[.directionArrow(direction)] = .cells(column: column, row: 9)
            map[.specialArrow(direction)] = .cells(column: column + specialOffset, row: 9)
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
