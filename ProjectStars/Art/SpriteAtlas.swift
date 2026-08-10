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
                width: effect.pixelSize,
                height: effect.pixelSize,
                frames: effect.frames,
                frameDuration: effect.rate.frameDuration
            )
        }

        // ── Nexys ────────────────────────────────────────────────────────
        // 48x48. Its middle cell is the tile it stands on; the overhang is the
        // island's rim and the greenery spilling off it.
        map[.nexys] = .cells(column: 10, row: 0, width: 3, height: 3)

        // ── Pieces ───────────────────────────────────────────────────────
        // 16x32 — a piece is twice a tile's height.
        //
        // TODO: Every sign currently points at Pisces. Give each its own column
        // as the art arrives; this is the only line that needs to change.
        let piscesColumn = 6
        for sign in Zodiac.allCases {
            map[.piece(sign)] = .cells(column: piscesColumn, row: 1, height: 2)
        }

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

        // ── Cursor ───────────────────────────────────────────────────────
        // One 16x16 cell per colour, holding all four brackets. Cut into 8x8
        // quarters so each can be pushed outward as the cursor flares.
        let cursorColumn: [CursorTint: Int] = [
            .red: 2, .yellow: 3, .orange: 4, .white: 6,
        ]
        // Column 5 is a green set, held back for a "confirm" state that does not
        // exist yet.
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
        let arrowColumn: [SwipeDirection: Int] = [.left: 3, .down: 4, .up: 5, .right: 6]
        for (direction, column) in arrowColumn {
            map[.directionArrow(direction)] = .cells(column: column, row: 9)
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
