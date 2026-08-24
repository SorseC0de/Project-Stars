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

    /// One row of Terra's ground, band and all.
    ///
    /// **The floor is in the list.** It was drawn in a pass of its own, ahead of
    /// everything standing on it, which meant every object was above every row
    /// of ground however far apart the two stood — so anything hanging past the
    /// bottom of its own square landed on the row in front instead of behind
    /// it. A board drawn row by row has each row's ground covering the overhang
    /// of the row behind, and that only works if the ground is sorted with the
    /// rest of the row.
    ///
    /// A whole row rather than a square, because the band is a whole row: it is
    /// laid edge to edge and scaled as one piece so no seam can open between
    /// neighbours. See `BoardView.bandRow(_:board:plane:metrics:)`.
    case tileRow

    case raisedTile

    /// The cursor's two **upper** brackets, which pass behind whatever shares
    /// their square.
    case cursorBack

    case pentacle

    /// One of the Polarity Prongs' shards.
    case prong

    /// A Match-shift Miasma sigil, lying on the square it marks.
    ///
    /// In the list rather than inside the tile: a mark drawn inside an upright
    /// tile view is an upright mark, and on Astra nothing shears it afterwards.
    /// Here it takes the ground's own shape on either plane.
    case sigil

    /// Libra's near pan, drawn on the row ahead of her.
    ///
    /// In profile it hangs out over the square in front, and a board that draws
    /// row by row buries anything hanging into the next row under that row's
    /// tile. So the pan is emitted where it visually belongs — see
    /// `LibraPieceView.Part`.
    case libraPan

    /// One square of the glow phase, shimmering.
    ///
    /// In the list so it sorts by its own row: drawn outside it, a sparkle on a
    /// far square hung over the grass growing on a near one.
    case sparkle

    /// Scorpio's Zodiaction tail.
    ///
    /// An object rather than an overlay: it is swung across the board and has
    /// to lean and shrink with the row it is swung from, and sort against
    /// whatever it reaches over.
    case sting

    /// Every grassed square in one row, drawn together.
    ///
    /// The row rather than the square, because a canvas per square was the
    /// board's largest cost and the row is what the sorter works in anyway —
    /// see `GrassRow`.
    case grassRow

    /// A patch of grass standing on a square.
    ///
    /// An object rather than a layer of its own, because that is what it is:
    /// something standing on a tile that has to sort against the piece, the
    /// coins and the island by row like anything else. Drawn outside this list
    /// it could only ever be entirely in front of them or entirely behind.
    case grass

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

    /// The pillar under the foreshortened island's near corner.
    case nexysPillar

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

        // Under everything standing in its row, and — because the row is what
        // sorts first — over everything standing in the row behind.
        case .tileRow: return -1

        // On the ground, over the square it marks and under anything standing
        // on it.
        case .sigil: return 0

        case .raisedTile: return 0

        // Behind whatever is standing on the same square — you stand *in* the
        // grass — and in front of the tile it grows out of.
        case .grass, .grassRow: return 1

        // Standing in its square like a piece does — it is a thing planted on
        // the board, and being drawn outside the list is what let it cover the
        // row in front of it.
        //
        // Below the piece rather than level with it: a shard carries a blend
        // mode and a glow, both of which make it a layer of its own, and a
        // layer of its own wins every tie. Sharing the piece's number meant
        // that tie happened on every row they shared.
        // **Over the ground it has reached into, not under it.**
        //
        // The row was right — `y + 1` is the row nearer the camera — but at the
        // grass's own number it tied with the grass on that square and lost the
        // tie, which put a pan she is holding out in front of her behind a
        // tuft. It hangs in the air over that square, so it sorts above what is
        // lying on it.
        case .libraPan: return 3

        // Above the grass it shines through and below anything standing in it.
        case .sparkle: return 2

        case .prong: return 2

        // Over the piece on its own square: it comes off his back, and a tail
        // behind the figure it belongs to reads as somebody else's.
        // Below the piece, so a tail thrown north passes behind the figure it
        // comes off rather than across it.
        case .sting: return 2

        case .pentacle: return sweeping ? 5 : 2
        case .nexys: return 4

        // **In front of whoever is standing on the island.**
        //
        // Above the piece's 5, which is the whole reason this is a separate
        // object from the island it belongs to: the island is behind the piece
        // and this near corner of it is in front.
        //
        // It ties with `cursorFront`, which also asks for 6 and *can* be on
        // this square — the cursor is built at whatever point is being aimed
        // at, with no exception for the Nexys. Left tied rather than resolved
        // by inventing a number: the two only meet while the player is aiming
        // at the island, `sorted(by:)` is deterministic for a given board even
        // though it is not stable, and the honest fix if it reads wrong is a
        // Nexys case on `cursorFront` — which would then need weighing against
        // `facing`, that sits deliberately above the cursor already.
        case .nexysPillar: return 6

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

    /// Where this sits in the stack.
    ///
    /// **The row is the answer, and it is meant to be the whole answer.** The
    /// board draws back to front by row, each row in front of the one behind
    /// it, so anything new is placed by saying which row it is on and nothing
    /// else. `sortLayer` only breaks ties inside a single row, which is why it
    /// stays smaller than ten.
    ///
    /// The same scale as `BoardLayer.z(row:)`, deliberately: marks and effects
    /// are drawn outside this list and have to stack against the things in it.
    var z: Double { Double(point.y) * 10 + Double(sortLayer) }

    /// Back-to-front ordering.
    static func draw(_ objects: [BoardObject]) -> [BoardObject] {
        objects.sorted { ($0.point.y, $0.sortLayer) < ($1.point.y, $1.sortLayer) }
    }
}
