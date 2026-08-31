//
//  TileMaterial.swift
//  Project Stars
//
//  What a tile is made of, answered in one place.
//

import SwiftUI

/// What a tile is made of, and in what order.
///
/// ## Why this exists
///
/// **Terra's wear drawings are overlays, not tiles.** Cracked is sixty-seven
/// pixels of a two hundred and fifty six pixel cell and badly cracked is a
/// hundred and twenty four — speckles on nothing. They are drawn *over* a face
/// and have no face of their own. Only healthy and hole are whole tiles, and
/// hole is one on purpose: it is what a missing tile looks like.
///
/// A renderer that swaps the face for the wear drawing instead of stacking them
/// shows cracks floating over the sky. That has been written wrong more than
/// once, in more than one renderer, which is why the answer lives here and
/// nowhere else: the board is drawn twice — once as SwiftUI views by `TileView`
/// and once into a baked strip by `BoardScene.rowImage` — and two copies of
/// this rule is one copy waiting to drift.
///
/// Anything that draws a tile asks these three questions in this order, and
/// draws whatever it gets back on top of whatever came before it.
enum TileMaterial {

    /// The drawing underneath everything. Always present.
    static func face(
        of tile: Tile, on plane: Plane, shade: Palette.TileShade, popped: Bool
    ) -> SpriteID {
        .tileFace(plane, shade, popped: popped)
    }

    /// The cast a badly cracked tile takes, over its face and under its wear.
    ///
    /// Terra's only — Astra's clouds carry their wear in a palette swap.
    static func tint(of tile: Tile, on plane: Plane) -> (colour: Color, share: Double)? {
        guard plane == .terra, tile.health == .badlyCracked else { return nil }
        return (Palette.khaki, GameRules.badlyCrackedTint)
    }

    /// The wear drawn **over** the face, if the tile has any.
    ///
    /// `nil` for a healthy tile and for a pool, which draws its own water.
    /// A chasm and the Nexys' own square read as holes whatever their health
    /// says, because that is what is under them.
    static func wear(of tile: Tile) -> TileHealth? {
        switch tile.kind {
        case .chasm, .nexys: .hole
        case .normal: tile.health == .healthy ? nil : tile.health
        case .pool: nil
        }
    }
}
