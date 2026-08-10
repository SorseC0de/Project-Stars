//
//  SpriteID.swift
//  Project Stars
//
//  The single naming authority for every piece of art in the game.
//

import Foundation

// MARK: - Supporting kinds

/// Which of the four corner brackets of the destination cursor.
///
/// The cursor is one 16x16 cell holding all four; they are cut into 8x8 quarters
/// so each can be pushed outward independently, which is the whole animation.
enum CursorCorner: String, CaseIterable, Hashable {
    case topLeft, topRight, bottomLeft, bottomRight

    /// Pixel origin of this corner inside the cursor's own cell.
    var originInCell: (x: Int, y: Int) {
        switch self {
        case .topLeft: (0, 0)
        case .topRight: (8, 0)
        case .bottomLeft: (0, 8)
        case .bottomRight: (8, 8)
        }
    }

    /// Which way this corner travels when the cursor flares open.
    var outwardSign: (x: Int, y: Int) {
        switch self {
        case .topLeft: (-1, -1)
        case .topRight: (1, -1)
        case .bottomLeft: (-1, 1)
        case .bottomRight: (1, 1)
        }
    }
}

/// The colours the cursor is drawn in.
///
/// The sheet carries one bracket set per colour. The game's palette is fixed by
/// design, so these are the only tints that exist — a status without its own
/// colour reuses `white` at reduced opacity rather than inventing one.
enum CursorTint: String, CaseIterable, Hashable {
    case white
    case yellow
    case orange
    case red
}

// MARK: - SpriteID

/// Every sprite the game can draw, and the asset-catalog name it maps to.
///
/// Views never hard-code an image name — they ask for a `SpriteID`. Where that
/// pixel data comes from is `SpriteAtlas`'s business: today almost everything is
/// a slice of one master sheet.
///
/// See `ASSETS.md` for the sheet layout.
enum SpriteID: Hashable {

    // MARK: Board

    /// The top face of an ordinary tile.
    ///
    /// - Parameters:
    ///   - shade: Which half of the board's checkerboard alternation this is.
    ///   - popped: The raised variant, drawn with a border that sells the lift.
    ///     Used for the tile a Pentacle is sitting on.
    case tileFace(Plane, Palette.TileShade, popped: Bool)

    /// The side of a tile, revealed underneath it when it pops up.
    ///
    /// Only the top 4px of the cell is drawn; the rest is transparent.
    case tileEdge(Plane, Palette.TileShade)

    /// Wear, drawn *over* a tile face rather than replacing it.
    /// Healthy has no overlay and is not a valid argument.
    case tileDamage(Plane, TileHealth)

    /// The Nexys island. A single 48x48 sprite, the same on both planes, whose
    /// middle cell is the tile it occupies.
    case nexys

    /// The plane's background layer. → `bg_astra`, `bg_terra`
    case planeBackground(Plane)

    // MARK: Pieces

    /// A zodiac piece. 16 wide, 32 tall — it stands taller than its tile.
    case piece(Zodiac)

    // MARK: Pentacles

    /// The Pentacle coin on the board. **One sprite per appearance, not per
    /// effect** — an ordinary coin never reveals what is inside it.
    case pentacle(PentacleAppearance)

    /// Per-effect art, shown only on the first-encounter splash once the coin
    /// is open.
    case pentacleFace(PickupID)

    // MARK: Cursor & HUD

    /// One bracket of the destination cursor.
    case cursorCorner(CursorTint, CursorCorner)

    /// The exclamation struck through a cursor sitting over a hole.
    case cursorWarning

    /// The puff kicked up by a landing. Five frames, played once.
    ///
    /// Per plane: Astra's dust is cloudstuff and Terra's is earth, and the two
    /// read completely differently against their own boards.
    case smoke(Plane)

    /// The direction indicator in the input panel.
    case directionArrow(SwipeDirection)

    // MARK: - Asset names
    //
    // Only used by the individual-image-set fallback; anything the atlas covers
    // never looks at these. Kept so a one-off can still be dropped in by name.

    var assetName: String {
        switch self {
        case let .tileFace(plane, shade, popped):
            "tile_\(plane.rawValue)_\(shade.assetSuffix)\(popped ? "_popped" : "")"
        case let .tileEdge(plane, shade):
            "tile_\(plane.rawValue)_\(shade.assetSuffix)_edge"
        case let .tileDamage(plane, health):
            "tile_\(plane.rawValue)_damage_\(health.assetSuffix)"
        case .nexys:
            "tile_nexys"
        case let .planeBackground(plane):
            "bg_\(plane.rawValue)"
        case let .piece(zodiac):
            "piece_\(zodiac.rawValue)"
        case let .pentacle(appearance):
            appearance == .standard
                ? "pickup_pentacle"
                : "pickup_pentacle_\(appearance.rawValue)"
        case let .pentacleFace(id):
            "pentacle_\(id.rawValue)"
        case let .cursorCorner(tint, corner):
            "cursor_\(tint.rawValue)_\(corner.rawValue)"
        case let .smoke(plane):
            "fx_smoke_\(plane.rawValue)"
        case .cursorWarning:
            "cursor_warning"
        case let .directionArrow(direction):
            "arrow_\(direction.rawValue)"
        }
    }
}

// MARK: - Asset naming helpers

extension TileHealth {
    /// The token used in tile asset names.
    var assetSuffix: String {
        switch self {
        case .healthy: "healthy"
        case .cracked: "cracked"
        case .badlyCracked: "badlyCracked"
        case .hole: "hole"
        }
    }
}

extension Palette.TileShade {
    var assetSuffix: String {
        switch self {
        case .light: "light"
        case .dark: "dark"
        }
    }
}

// MARK: - Manifest

extension SpriteID {
    /// Every sprite the finished game expects.
    ///
    /// The single source of truth for "what art does this game need" — the
    /// coverage report and `SpriteLoader.missingSprites` both derive from it.
    static var allSprites: [SpriteID] {
        var ids: [SpriteID] = [.nexys, .cursorWarning]

        for plane in Plane.allCases {
            ids.append(.planeBackground(plane))
            ids.append(.smoke(plane))
            for shade in [Palette.TileShade.light, .dark] {
                ids.append(.tileFace(plane, shade, popped: false))
                ids.append(.tileFace(plane, shade, popped: true))
                ids.append(.tileEdge(plane, shade))
            }
            // Healthy has no overlay — an undamaged tile is just its face.
            for health in [TileHealth.cracked, .badlyCracked, .hole] {
                ids.append(.tileDamage(plane, health))
            }
        }

        ids += Zodiac.allCases.map { SpriteID.piece($0) }
        ids += [PentacleAppearance.standard, .shadow, .radiant].map { SpriteID.pentacle($0) }
        ids += PickupID.allCases.map { SpriteID.pentacleFace($0) }
        ids += CursorTint.allCases.flatMap { tint in
            CursorCorner.allCases.map { SpriteID.cursorCorner(tint, $0) }
        }
        ids += SwipeDirection.allCases.map { SpriteID.directionArrow($0) }
        return ids
    }

    /// Every sprite name the finished game expects.
    static var manifest: [String] {
        allSprites.map(\.assetName)
    }
}
