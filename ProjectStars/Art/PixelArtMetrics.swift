//
//  PixelArtMetrics.swift
//  Project Stars
//
//  Keeping 16x16 tiles on whole-pixel boundaries.
//

import CoreGraphics
import Foundation

/// Layout maths for a pixel-art board.
///
/// Pixel art only looks right at integer scale. Rather than stretching the grid
/// to fill whatever space is available, the board is sized to the largest whole
/// multiple of its native pixel size that fits, and the leftover becomes an even
/// margin. That guarantees every source pixel maps to the same number of screen
/// points, with no shimmering half-pixel seams between tiles.
struct PixelArtMetrics: Equatable {

    /// Tiles per side.
    let gridSize: Int

    /// Native pixel size of one tile — 16 for this project.
    let tilePixelSize: Int

    /// Whole-number scale factor applied to the native art.
    let scale: CGFloat

    /// Rendered size of one tile, in points.
    var tileSize: CGFloat { CGFloat(tilePixelSize) * scale }

    /// Rendered size of the whole board, in points.
    var boardSize: CGFloat { tileSize * CGFloat(gridSize) }

    /// Native size of the whole board, in source pixels.
    var boardPixelSize: Int { tilePixelSize * gridSize }

    /// Fits a board into `availableSide` points.
    ///
    /// - Parameter allowFractionalScale: When the available space is smaller
    ///   than one full board at 1x — a very small screen, or an Xcode preview —
    ///   integer scaling would overflow the frame. In that case the scale falls
    ///   back to fractional so the board still fits.
    init(
        availableSide: CGFloat,
        gridSize: Int = GameRules.gridSize,
        tilePixelSize: Int = GameRules.tilePixelSize,
        allowFractionalScale: Bool = true
    ) {
        self.gridSize = gridSize
        self.tilePixelSize = tilePixelSize

        let nativeSide = CGFloat(gridSize * tilePixelSize)
        let rawScale = availableSide / nativeSide

        if rawScale >= 1 {
            self.scale = rawScale.rounded(.down)
        } else if allowFractionalScale {
            self.scale = max(rawScale, 0.01)
        } else {
            self.scale = 1
        }
    }

    /// The top-left corner of a tile, relative to the board's own origin.
    func origin(of point: GridPoint) -> CGPoint {
        CGPoint(x: CGFloat(point.x) * tileSize, y: CGFloat(point.y) * tileSize)
    }

    /// The centre of a tile, relative to the board's own origin. This is what
    /// sprite views position themselves on.
    func center(of point: GridPoint) -> CGPoint {
        CGPoint(
            x: (CGFloat(point.x) + 0.5) * tileSize,
            y: (CGFloat(point.y) + 0.5) * tileSize
        )
    }

    /// The tile under a point in board-local coordinates, or `nil` if outside.
    ///
    /// Needed by the tap-to-move control scheme.
    func gridPoint(at location: CGPoint) -> GridPoint? {
        guard tileSize > 0 else { return nil }
        let point = GridPoint(
            Int((location.x / tileSize).rounded(.down)),
            Int((location.y / tileSize).rounded(.down))
        )
        return point.isInBounds(size: gridSize) ? point : nil
    }
}
