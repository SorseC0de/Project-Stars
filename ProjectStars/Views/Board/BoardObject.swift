//
//  BoardObject.swift
//  Project Stars
//
//  The depth law: anything standing above the floor sorts by the row it is on.
//

import Foundation

/// What kind of thing is standing above the floor.
///
/// Kept separate from *where* it stands, because this is the part that has to be
/// **stable**. It is the `ForEach` identity, and an identity that changed as an
/// object moved would tell SwiftUI the old one had gone and a new one arrived —
/// destroying and rebuilding the view every step, which loses its position
/// animation and fades it in from nothing.
enum BoardObjectKind: String, Hashable, CaseIterable {
    case raisedTile

    /// The cursor's two **upper** brackets, which pass behind whatever shares
    /// their square.
    case cursorBack

    case pentacle
    /// The little arrow on the ground ahead of the piece. Sorted just under it,
    /// so a piece standing at the front of the board still covers its own
    /// marker rather than being overlapped by it.
    case facing

    case piece

    /// One of Leo's phantoms. Slotted, since there can be two.
    case follower

    /// Leo's Aten, riding over the lion's head.
    case sun

    case nexys

    /// The cursor's two **lower** brackets, which pass in front.
    case cursorFront
}

/// Something that stands proud of the board and therefore has to be depth-sorted
/// against everything else that does.
///
/// ## The law
///
/// **Higher cell Y draws in front.** A thing nearer the bottom of the grid is
/// nearer the viewer, whether it is a piece, the island, the cursor, or a tile
/// that has popped up.
///
/// Flat tiles are not objects. They cannot occlude anything, so they stay in
/// their own grid pass drawn in reading order — which already satisfies the law
/// among themselves. Only the *raised* tile leaves that pass and joins this one.
///
/// ## Ties
///
/// Objects sharing a row are ordered by `sortLayer`, and the island wins by
/// default. That is deliberate: the Nexys is a 48x48 sprite overhanging its own
/// square, and on the tiles either side of it that overhang is the *front* of
/// the island — a piece drawn over it would look like it was standing inside the
/// rock.
///
/// The exception is anything standing on the island's own square, which is on
/// top of it rather than beside it and has to draw in front.
struct BoardObject: Identifiable, Equatable {

    let kind: BoardObjectKind

    /// The square this object stands on.
    let point: GridPoint

    /// Which of its kind this is, when a kind can appear more than once.
    ///
    /// The Pentacle and its raised square can — Sagittarius may have two out at
    /// a time — and so can Leo's phantoms. Everything else is always slot zero.
    var slot: Int = 0

    /// True while a slide is running.
    ///
    /// A coin the slide is about to sweep up should pass over the piece's head
    /// rather than behind it. Behind, it reads as having been missed — the piece
    /// visibly goes *through* it — where in front it reads as being scooped out
    /// of the air, which is what `pickupGathered` actually is.
    var sweeping: Bool = false

    /// Stable across movement — see `BoardObjectKind`.
    ///
    /// **The square must not be part of this.** Identity is what tells SwiftUI
    /// that the thing at the new position is the *same* thing that was at the
    /// old one; key it on position and every move destroys one view and creates
    /// another, which it renders as a cross-fade rather than a movement. The
    /// piece visibly faded from square to square.
    ///
    /// The slot disambiguates the kinds that can repeat without costing that,
    /// because it does not change when the object moves.
    struct ID: Hashable {
        let kind: BoardObjectKind
        let slot: Int
    }

    var id: ID { ID(kind: kind, slot: slot) }

    /// Order within a row, lowest drawn first.
    ///
    /// The cursor straddles this list rather than sitting at one point in it:
    /// its upper brackets go near the bottom and its lower brackets at the very
    /// top, so a cursor sharing a square with the coin or the piece appears to
    /// *wrap around* it. That is the whole trick — four brackets at one depth
    /// would look like a sticker either behind or in front of the object,
    /// never like a frame around it.
    var sortLayer: Int {
        switch kind {
        // Always in front within its row, island included.
        case .cursorFront: return 6

        // Over the lion's head and over everything else on the square. It is a
        // light source hanging in the air; nothing on the ground occludes it.
        case .sun: return 8

        // Above the tile face — otherwise the raised tile would hide it — but
        // behind everything standing on that tile.
        //
        // Except on the island, which is a 48x48 sprite tall enough to swallow
        // the brackets whole. While the player is aiming *at* the Nexys that
        // makes the one square they are looking at the one they cannot see, so
        // there it goes in front.
        case .cursorBack: return point == GameRules.nexysPoint ? 5 : 1

        case .raisedTile: return 0
        case .pentacle: return sweeping ? 5 : 2
        case .nexys: return 4

        // On the island's square you are on top of it, not beside it.
        case .piece: return point == GameRules.nexysPoint ? 5 : 3

        // Exactly where a piece would be, because that is what it is standing
        // in for. Sorted by its own square like everything else, so a phantom
        // behind the lion draws behind it and one in front draws in front.
        case .follower: return point == GameRules.nexysPoint ? 5 : 3

        // Over the cursor, within its own row.
        //
        // They can occupy the same ground and mean different things — the cursor
        // is where a move *would* go, the arrow is which way the piece is
        // looking — and of the two the facing is the one that is currently true.
        // A marker for a fact should not be hidden behind a marker for a
        // possibility.
        //
        // Row order still decides everything above that, which is what keeps the
        // arrow behind the piece when it points north. See where the object is
        // built in `BoardView`.
        case .facing: return 7
        }
    }

    /// Back-to-front ordering.
    static func draw(_ objects: [BoardObject]) -> [BoardObject] {
        objects.sorted { ($0.point.y, $0.sortLayer) < ($1.point.y, $1.sortLayer) }
    }
}
