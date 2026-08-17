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

    /// The colour a just-mended square is currently flashing, and how hard.
    ///
    /// Runs through every light entry in the palette — see
    /// `GameRules.healFlashTone(elapsed:)`. Repair is the only good news the
    /// board ever gives and it wanted an event to match.
    var healFlash: (ramp: [Color], strength: Double)?

    /// True while a sliding piece is passing over this square.
    ///
    /// The tile gives a pixel or so and comes back. A slide crosses ground
    /// without landing on it and so has no dust, no wear and no impact to draw —
    /// this is the whole of what says something went past.
    var isPressed: Bool = false

    /// Which square this is. Astra's clusters are generated from it, so each
    /// one keeps its own cloud.
    var point: GridPoint = GridPoint(0, 0)

    /// True when `CloudFieldView` has already painted this square.
    ///
    /// The board sets this for Astra's ordinary squares, which are drawn in one
    /// canvas for the whole plane rather than one view each. Everything else —
    /// the raised square, the gallery, Terra — leaves it false and draws here.
    var drawnByField: Bool = false

    var body: some View {
        pressed {
            content
        }
    }

    /// The give, applied over whatever this square happens to be made of.
    @ViewBuilder
    private func pressed(@ViewBuilder _ content: () -> some View) -> some View {
        content()
            .offset(y: isPressed ? GameRules.slidePressDepth : 0)
            .animation(.easeOut(duration: 0.09), value: isPressed)
    }

    private var content: some View {
        ZStack {
            if plane == .astra, tile.kind != .normal {
                // Nothing at all.
                //
                // Terra's structural squares are holes *in* something and need
                // drawing: the chasm is a gap in the ground, and the square
                // under the island is the shaft it floats above. Astra has no
                // ground for either to be a hole in — it is open sky — so both
                // rendered as a black square, one in the middle of the clouds
                // and one directly beneath the island.
                Color.clear
            } else
            if drawnByField, plane == .astra, tile.kind == .normal, !hasDrawnCloud {
                // Already painted with the rest of the field.
                Color.clear
            } else if plane == .astra, tile.kind == .normal, !hasDrawnCloud {
                // Astra has no tiles — see `CloudTileView`. Structural squares
                // (the island and its chasm) still draw normally: those are not
                // made of cloud.
                //
                // The generated cluster steps aside the moment drawn cloud
                // exists on the sheet, the same way every placeholder in this
                // game does. A sprite is also far cheaper than 39 shapes a
                // frame — see the note on `CloudTileView.body`.
                CloudTileView(
                    health: tile.health,
                    shade: shade,
                    point: point,
                    size: size,
                    isFlashing: isFlashing,
                    isRaised: isPopped
                )
            } else {
                face
                damage
            }
        }
        .frame(width: size, height: size)
        .overlay {
            // A bright rim rather than a fill, so the tile's state stays legible
            // while it animates. Clouds do their own flash — a rectangle around
            // one would draw a square that is not there.
            if plane != .astra || tile.kind != .normal {
                Rectangle()
                    .strokeBorder(Palette.textPrimary, lineWidth: size * 0.06)
                    .opacity(isFlashing ? 0.9 : 0)
            }
        }
        .overlay {
            // The heal flash fills rather than rims. A mend changes what the
            // square *is*, so the whole face carries it — and additive, so it
            // brightens the tile instead of painting over it.
            // Cloud squares are not drawn here at all — `CloudSpriteField` has
            // them — so a rectangle over one paints a square that is not there.
            // Astra's flash is a palette swap on the cloud itself; see
            // `CloudSpriteView.flashed`.
            if let flash = healFlash, plane != .astra || tile.kind != .normal {
                Rectangle()
                    .fill(flash.ramp.first ?? Palette.white)
                    .opacity(flash.strength)
                    .blendMode(.plusLighter)
                    .allowsHitTesting(false)
            }
        }
    }

    /// Whether Astra's tiles have been drawn, in which case they win.
    private var hasDrawnCloud: Bool {
        SpriteLoader.hasAsset(for: .tileFace(.astra, shade, popped: isPopped))
    }

    // MARK: - Layers

    private var face: some View {
        PixelSprite(id: .tileFace(plane, shade, popped: isPopped)) {
            Rectangle().fill(Palette.tileFace(tile.health, on: plane, shade: shade))
        }
        // A wash of red on stone that is one landing from going.
        //
        // Applied **here**, on the 16x16 face, before the tile is framed or
        // put on a band — so it is a rectangle over a sprite and nothing else.
        // Anything added later in the chain would be scaled, sheared and
        // squashed with the row, which is how a flat overlay turns into a
        // pillar or a smear.
        //
        // Terra only: cloud already says it another way, and the red is the
        // colour of ground about to fail.
        .overlay {
            if plane == .terra, tile.health == .badlyCracked {
                Rectangle()
                    .fill(Palette.khaki)
                    .opacity(GameRules.badlyCrackedTint)
                    .blendMode(.plusDarker)
            }
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
        // A pool has no wear to overlay. `PoolView` draws the water itself.
        case .pool: nil
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
