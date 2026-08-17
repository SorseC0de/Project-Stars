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
/// Which of Gemini's two halves.
///
/// Gold and silver rather than left and right: Soul Split leaves one standing
/// and takes the other anywhere on the board, so which side of the pair it is
/// stops meaning anything the moment they separate. A colour keeps its name
/// wherever it goes.
/// Which of Umbra's two floor tones a tile is.
///
/// The underworld's ground is drawn as a two-tone check rather than as one
/// surface, so the eye has something to measure movement against on a plane that
/// is otherwise flat and dark. Both tones share an edge sprite each.
enum UmbraTone: String, Hashable, CaseIterable, Codable, Sendable {
    case light
    case dark
}

enum GeminiHalf: String, Hashable, CaseIterable, Codable, Sendable {
    case gold
    case silver

    /// The other one. There are only ever two, and they are always both.
    var sibling: GeminiHalf { self == .gold ? .silver : .gold }
}

/// One of Virgo's two floating gems.
///
/// `outer` is a single drawing used twice — once as it is and once mirrored, so
/// the pair sits either side of her. `middle` draws in front of both.
enum VirgoGem: String, Hashable, CaseIterable, Codable, Sendable {
    case outer
    case middle
}

/// Which pair of Libra's arms is being drawn.
///
/// Two drawings rather than four: north is south seen from behind and the
/// left arm is the right one flipped, so the sheet carries one of each axis.
enum LibraArmSet: String, Hashable {
    case northSouth
    case eastWest
}

enum CursorTint: String, CaseIterable, Hashable {
    case white
    case yellow
    case orange
    case red

    /// Drawn only while the player is choosing a square rather than a move.
    /// Its brackets have been on the sheet all along — see `SpriteAtlas`.
    case green
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

    /// The compass in the corner of the board. Four cells, N S E W, lit one at
    /// a time to show which way the piece is looking.
    case directionGuide(SwipeDirection)

    /// One of Libra's arms. The sheet holds the north-facing and east-facing
    /// versions; the other two are those flipped — see `LibraPieceView`.
    case libraArm(LibraArmSet)

    /// The pans hanging off an arm. Three frames, looped — the lit version,
    /// worn only at a full meter.
    case libraScales

    /// The same pans at rest, drawn plain.
    case libraScalesPlain

    /// The fish that rides on Pisces' shoulders, in stone.
    ///
    /// Its own sprite because it does not sit on a cell boundary — the art
    /// crosses one — so it cannot be part of a two-cell bust the way every
    /// other sign's top half is. `piece(.pisces)` is the body alone.
    case piscesFish

    /// The fish, made of astral energy. Full meter only.
    case piscesFishCharged

    /// The archer's arrow, drawn apart from the bust so it can float.
    ///
    /// Its own cell for the same reason Libra's arms are: a part that has to
    /// move independently cannot be baked into the figure, or the figure has to
    /// be redrawn for every position it might be in.
    case sagittariusArrowRest

    /// One of Gemini's two halves. See `GeminiHalf`.
    case geminiHalf(GeminiHalf)

    /// Cancer seen from a given side.
    ///
    /// The only sign drawn from more than one angle, because the claw swings
    /// sideways and stops where you tap, so it is genuinely looked at from all
    /// four. East is west mirrored — three drawings, four facings.
    case cancerFacing(SwipeDirection)

    /// One of Virgo's floating gems. See `VirgoGem`.
    case virgoGem(VirgoGem)

    // MARK: Umbra

    /// The underworld's floor, in one of its two tones.
    case umbraFloor(UmbraTone)

    /// The lip below a floor tile, matched to the tone above it.
    case umbraEdge(UmbraTone)

    /// Scenery scattered at board generation. Two of them, picked between.
    ///
    /// Drawn in `Palette.smoke`, which is also the dark floor — so on a dark
    /// tile it has to be swapped down a step to `coolBlack` or it is invisible.
    /// See `GameRules.umbraDecorDarkSwap`.
    case umbraDecor(Int)

    /// The rarer piece of scenery, drawn once and turned to any angle.
    case umbraDecorRare

    /// The impassable rock. Two cells tall, and the only thing in Umbra that
    /// blocks Nilyth as well as the player.
    case umbraRock

    /// A stand-in hole for Astra, where there are no tiles to make one out of.
    case astraHole

    /// The coin a piece carries over its head.
    case carriedCoin

    /// Libra's gavel, drawn as its own Pentacle.
    case gavel

    /// One of Astra's clouds: a 48x48 puff covering three cells' width.
    ///
    /// Three frames, played ping-pong, in a light and a dark variant so
    /// neighbouring squares alternate the way Terra's chequerboard does.
    case astraCloud(Palette.TileShade)

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

    /// The astral-energy arrow, for a sign's *longer* move that way.
    ///
    /// A second set rather than a tint of the first: the two sit side by side on
    /// the pad and have to be told apart at a glance, which a recolour of the
    /// same silhouette does not manage.
    case specialArrow(SwipeDirection)

    // MARK: Effects

    /// One of the imported 64px effect strips. See `EffectSprite`.
    case effect(EffectSprite)

    // MARK: - Asset names
    //
    // Only used by the individual-image-set fallback; anything the atlas covers
    // never looks at these. Kept so a one-off can still be dropped in by name.

    var assetName: String {
        switch self {
        case let .tileFace(plane, shade, popped):
            "tile_\(plane.rawValue)_\(shade.assetSuffix)\(popped ? "_popped" : "")"
        case .directionGuide:
            "direction_guide"
        case let .libraArm(set):
            "libra_arm_\(set.rawValue)"
        case .libraScales:
            "libra_scales"
        case .sagittariusArrowRest:
            "sagittarius_arrow_rest"
        case .piscesFish:
            "pisces_fish"
        case .piscesFishCharged:
            "pisces_fish_charged"
        case .libraScalesPlain:
            "libra_scales_plain"
        case let .geminiHalf(half):
            "gemini_\(half.rawValue)"
        case let .cancerFacing(facing):
            "cancer_\(facing.rawValue)"
        case let .virgoGem(gem):
            "virgo_gem_\(gem.rawValue)"
        case let .umbraFloor(tone):
            "umbra_floor_\(tone.rawValue)"
        case let .umbraEdge(tone):
            "umbra_edge_\(tone.rawValue)"
        case let .umbraDecor(index):
            "umbra_decor_\(index)"
        case .umbraDecorRare:
            "umbra_decor_rare"
        case .umbraRock:
            "umbra_rock"
        case .astraHole:
            "astra_hole"
        case .carriedCoin:
            "carried_coin"
        case .gavel:
            "Air/libra_gavel"
        case let .astraCloud(shade):
            "cloud_astra_\(shade.assetSuffix)"
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
        case let .specialArrow(direction):
            "arrow_special_\(direction.rawValue)"
        case let .effect(effect):
            effect.assetName
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
        ids += SwipeDirection.allCases.map { SpriteID.specialArrow($0) }
        ids += EffectSprite.allCases.map { SpriteID.effect($0) }
        return ids
    }

    /// Every sprite name the finished game expects.
    static var manifest: [String] {
        allSprites.map(\.assetName)
    }
}
