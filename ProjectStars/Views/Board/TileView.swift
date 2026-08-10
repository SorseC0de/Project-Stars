//
//  TileView.swift
//  Project Stars
//
//  One square of the board: its face, and the wear drawn over it.
//

import SwiftUI

/// Draws a tile's top face with its damage overlay.
///
/// Wear is an **overlay**, not a different tile: the face stays the same and the
/// cracks are laid on top. That is why a damaged tile still reads as belonging
/// to its plane and its checkerboard shade.
///
/// The edge underneath is *not* drawn here — `BoardView` lays a whole grid of
/// edges down in a first pass so that lifting a face reveals the one beneath it.
/// See `BoardView.edgeLayer`.
struct TileView: View {

    let tile: Tile
    let plane: Plane
    let shade: Palette.TileShade

    /// Rendered edge length in points.
    let size: CGFloat

    /// True for the tile a Pentacle is sitting on, which draws the bordered
    /// variant. The lift itself is applied by `BoardView`.
    var isPopped: Bool = false

    /// True for one beat after this tile changes state, so it can flash.
    var isFlashing: Bool = false

    var body: some View {
        ZStack {
            face
            damage
        }
        .frame(width: size, height: size)
        .overlay {
            // A bright rim rather than a fill, so the tile's state stays legible
            // while it animates.
            Rectangle()
                .strokeBorder(Palette.textPrimary, lineWidth: size * 0.06)
                .opacity(isFlashing ? 0.9 : 0)
        }
    }

    // MARK: - Layers

    private var face: some View {
        PixelSprite(id: .tileFace(plane, shade, popped: isPopped)) {
            Rectangle().fill(Palette.tileFace(tile.health, on: plane, shade: shade))
        }
        .frame(width: size, height: size)
    }

    /// Cracks, or the black of a hole. Healthy tiles have no overlay at all.
    @ViewBuilder
    private var damage: some View {
        if let health = overlayHealth {
            PixelSprite(id: .tileDamage(plane, health)) {
                // Fallback while the sheet is missing: darken by severity.
                Rectangle().fill(.black.opacity(health.isHole ? 0.92 : 0.25))
            }
            .frame(width: size, height: size)
        }
    }

    /// Which wear overlay this tile needs, if any.
    ///
    /// **Both** structural squares show the hole overlay, and permanently. The
    /// chasm is a hole outright; the Nexys square is the hole the island floats
    /// *above* — the island is a separate 48x48 sprite drawn over the top, and
    /// the gap has to stay visible around and beneath its rim or it reads as a
    /// slab sitting flat on the floor.
    private var overlayHealth: TileHealth? {
        switch tile.kind {
        case .chasm, .nexys: .hole
        case .normal: tile.health == .healthy ? nil : tile.health
        }
    }
}

// MARK: - TileEdgeView

/// The side of a tile, seen only when the face above it lifts.
///
/// The sprite is a full cell with pixels only in its **top 4 rows**, so it is
/// drawn pushed down by the remaining 12 — that puts the visible sliver at the
/// bottom of the square, exactly where a lifted face uncovers it.
struct TileEdgeView: View {

    let plane: Plane
    let shade: Palette.TileShade
    let size: CGFloat

    var body: some View {
        PixelSprite(id: .tileEdge(plane, shade)) {
            // Nothing sensible to stand in with: without the sprite there is no
            // edge, and a lifted tile simply shows the backdrop.
            Color.clear
        }
        .frame(width: size, height: size)
    }
}
