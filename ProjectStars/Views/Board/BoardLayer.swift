//
//  BoardLayer.swift
//  Project Stars
//
//  Where a thing lives on the board, and what that implies.
//

import SwiftUI

/// Which layer of the board something belongs to.
///
/// ## Why this exists
///
/// Everything on this board stands on a square, and until this existed every
/// new thing re-answered the same four questions for itself: is it sheared into
/// the ground or standing up out of it, where in the tile does it sit, what
/// draws in front of it, and does it bob. Each answer was written at the site
/// that needed it, so each was a fresh chance to get one wrong — and they were
/// wrong often. Grass spilled off the front of the board because it was placed
/// twice. A sigil drew over the player because nothing ordered it by row. An
/// aura filled the whole board because a `Rectangle` was never told its size.
///
/// **Naming a layer answers all four at once.** Adding something to the board is
/// now: draw it, say which layer it is on, and hand it a square.
///
///     PentacleView(...)
///         .onBoard(point, layer: .object, metrics: metrics, plane: shown)
///
/// ## Order
///
/// **Row first, layer second.** A piece of grass on row 4 must draw in front of
/// a player on row 3 and behind a player on row 4, which no fixed stack of
/// layers can express — the board is a painter's-algorithm scene, and the row
/// is the depth. Only the ground (which is drawn as bands, back to front, and
/// can never be in front of anything) and effects (which are events and always
/// want to be seen) sit outside that.
enum BoardLayer: Int, CaseIterable, Comparable {

    /// The tiles themselves, and their bands.
    case ground

    /// Lying **on** the ground and sheared with it: sigils, auras, cracks,
    /// scorch marks, the cursor.
    case groundMark

    /// Standing on a square: coins, the island, arrows, grass, statues.
    case object

    /// The piece and anything that moves with it.
    case piece

    /// Standing on a square but always drawn over the piece on that square —
    /// grass in front of the feet, a canopy, a held item.
    case overhead

    /// Bursts, flourishes and sparkles. Above everything, because an effect is
    /// an event and being obscured by scenery is the one thing it must not be.
    case effect

    static func < (lhs: BoardLayer, rhs: BoardLayer) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Whether this is sheared into the ground's perspective.
    ///
    /// A mark lies flat and takes the row's lean; anything standing keeps its
    /// own shape and is only *scaled* by depth. This is the difference between
    /// grass growing out of a tile and grass painted onto it.
    var lies: Bool { self == .ground || self == .groundMark }

    /// Whether the row decides what draws in front of what.
    var sortsByRow: Bool { self != .effect }

    /// Whether `BoardObject.draw` already orders this layer.
    ///
    /// **The board has one depth sorter and it predates all of this.** Objects
    /// and pieces are drawn from a list sorted by row, and that list states the
    /// row on each of them itself — `BoardObject.z`, the same scale this uses.
    ///
    /// A second `zIndex` set from down here would land on a descendant of the
    /// stack doing the ordering, where it orders that view against its own
    /// children and does nothing about the row. Anything the sorter owns takes
    /// its place from the sorter; marks and effects, drawn outside that list,
    /// take it from here.
    var isSortedByObjectList: Bool { self == .object || self == .piece }

    /// Where this sits in the stack, for a thing on `row`.
    ///
    /// Row-major, so depth wins; the layer only breaks ties inside one row.
    /// Effects are lifted clear of the whole scene.
    func z(row: Int) -> Double {
        sortsByRow
            ? Double(row) * 10 + Double(rawValue)
            : 10_000 + Double(row)
    }
}

// MARK: - Hovering

/// How a thing floats above its square.
///
/// Set once and forgotten: the modifier drives it off the ambient clock, so it
/// stops with everything else when the board is waiting. Each case is a *shape
/// of motion* rather than a number, because the same three or four motions keep
/// being rewritten — the island's heave, a coin's little orbit, the star's
/// spinning bob.
enum HoverStyle {

    /// Planted. The default.
    case none

    /// The Nexys: a slow, heavy rise and fall.
    case island

    /// A Pentacle: a small circle, so it reads as suspended rather than as
    /// bouncing. Shared by Virgo's clips and Pisces' full-meter mark.
    case coin

    /// Polaris: bobs, turns and breathes at once.
    case star

    /// Where this is, relative to its resting place, at `time`.
    ///
    /// - Parameter salt: Keeps two things on the same square from moving in
    ///   lockstep.
    func offset(at time: TimeInterval, salt: Int) -> CGSize {
        let drift = Double(salt) * 0.37

        switch self {
        case .none:
            return .zero

        case .island:
            let phase = (time / GameRules.nexysFloatPeriod + drift) * 2 * .pi
            return CGSize(width: 0, height: sin(phase) * GameRules.nexysFloatAmplitude)

        case .coin:
            let phase = (time / GameRules.pentacleOrbitPeriod + drift) * 2 * .pi
            return CGSize(
                width: cos(phase) * GameRules.pentacleOrbitRadius,
                height: sin(phase) * GameRules.pentacleOrbitRadius
            )

        case .star:
            // **A circle, not a bob.** Polaris and the charged fish both travel
            // rather than pump — a purely vertical rise reads as bouncing, and
            // the thing they have in common is that they are *loose*, orbiting
            // whatever they came from.
            // Anticlockwise: the fish leads with its head, and clockwise had it
            // swimming backwards round its own orbit.
            let phase = (time / GameRules.polarisBobPeriod + drift) * 2 * .pi
            return CGSize(
                width: -cos(phase) * GameRules.polarisBobRadius,
                height: sin(phase) * GameRules.polarisBobRise
            )
        }
    }

    /// How far round this has turned at `time`, in degrees.
    func spin(at time: TimeInterval) -> Double {
        switch self {
        case .star: time / GameRules.polarisSpinPeriod * 360
        default: 0
        }
    }

    /// How much bigger or smaller than itself this is at `time`.
    func breath(at time: TimeInterval) -> CGFloat {
        switch self {
        case .star:
            let phase = time / GameRules.polarisBreathPeriod * 2 * .pi
            return 1 + CGFloat(sin(phase)) * GameRules.polarisBreathSwell
        default:
            return 1
        }
    }
}

// MARK: - Bouncing

/// When a thing takes the board's give.
///
/// The ground dips under something arriving and springs as it leaves. Anything
/// can ask for either — a piece, a coin dropped onto a square, a statue being
/// placed — rather than each writing its own dip.
struct BounceMoment: OptionSet {
    let rawValue: Int

    static let entry = BounceMoment(rawValue: 1 << 0)
    static let exit = BounceMoment(rawValue: 1 << 1)

    static let none: BounceMoment = []
    static let both: BounceMoment = [.entry, .exit]
}

// MARK: - The board's own environment

/// What the board tells everything drawn on it, so a placement does not need
/// eleven arguments.
struct BoardContext {
    var metrics: PixelArtMetrics
    var plane: Plane

    /// The per-plane projection — see `BoardView.planeFraming`.
    var framing: (emphasis: CGFloat, zoom: CGFloat, lift: CGFloat, pivot: CGFloat, spacing: CGSize)

    /// How far the ground under a square is currently pushed down, in points.
    var bounce: (GridPoint) -> CGFloat = { _ in 0 }

    /// The ambient clock, so hovering stops when the board does.
    var clock: (TimeInterval) -> TimeInterval = { $0 }
}

private struct BoardContextKey: EnvironmentKey {
    static let defaultValue: BoardContext? = nil
}

extension EnvironmentValues {
    var boardContext: BoardContext? {
        get { self[BoardContextKey.self] }
        set { self[BoardContextKey.self] = newValue }
    }
}

// MARK: - Putting something on the board

/// The one placement. Everything drawn on a square goes through here.
///
/// It answers, in order:
///
/// 1. **Shape** — sheared into the ground for a `lies` layer, upright for
///    anything standing. `isStanding` overrides, for the odd mark that has to
///    stand or object that has to lie.
/// 2. **Place** — centred on its square, using the projection for the plane it
///    is on. Terra's squares are bands and Astra's are clusters; the caller
///    never has to know which.
/// 3. **Order** — `zIndex` from the row, so what is nearer the camera draws in
///    front. See `BoardLayer.z(row:)`.
/// 4. **Motion** — the hover it asked for and the ground's give under it.
///
/// Anything that needs none of the last two simply does not pass them.
struct OnBoard: ViewModifier {

    let point: GridPoint
    let layer: BoardLayer
    let context: BoardContext

    /// Overrides the layer's own answer about shearing.
    var isStanding: Bool?

    var hover: HoverStyle = .none
    var bounces: BounceMoment = .none

    /// Nudge in art pixels, for art that is not centred in its own cell.
    var nudge: CGSize = .zero

    /// Keeps two things on one square from hovering in lockstep.
    var salt: Int = 0

    private var stands: Bool { isStanding ?? !layer.lies }

    func body(content: Content) -> some View {
        let metrics = context.metrics

        // **Terra's marks place themselves.**
        //
        // `asBoardSquare` shears a mark into its row *and puts it on its
        // square* — it is absolute. Everything else here is relative and needs
        // `PlacedOnPlane` afterwards. Running both on Terra positioned the mark
        // twice and threw it off the board entirely, which is why the miasma
        // sigil vanished there while working on Astra.
        let placesItself = !stands && context.plane == .terra

        Group {
            if stands {
                content
            } else if context.plane == .terra {
                content.asBoardSquare(point, metrics: metrics)
            } else {
                content.shapedAsGround(
                    row: point.y,
                    metrics: metrics,
                    stretch: GameRules.astraMarkStretch
                )
            }
        }
        .offset(
            x: nudge.width * metrics.scale,
            y: nudge.height * metrics.scale + (bounces.isEmpty ? 0 : context.bounce(point))
        )
        .modifier(Hovering(style: hover, salt: salt, clock: context.clock))
        .modifier(
            PlacedOnPlane(
                point: point,
                metrics: metrics,
                framing: context.framing,
                isDisabled: placesItself
            )
        )
        // **Ordering is left to the object list where the object list owns
        // it**, and applied there, to the siblings themselves.
        //
        // A `zIndex` set down here would land on a descendant of the stack that
        // does the ordering, and it would be the only one of those siblings
        // carrying one — a sibling with a `zIndex` outranks every sibling
        // without one, so the shards rose above the whole board.
        .modifier(BoardStacking(z: layer.isSortedByObjectList ? nil : layer.z(row: point.y)))
    }
}

/// The float itself, on the ambient clock so it stops when the board does.
///
/// Its own modifier rather than part of `OnBoard` so a thing that is already
/// placed — a piece mid-hop, say — can still be handed a hover without being
/// re-placed.
struct Hovering: ViewModifier {
    @Environment(\.planeIsAsleep) private var planeIsAsleep



    let style: HoverStyle
    var salt: Int = 0
    var clock: (TimeInterval) -> TimeInterval = { $0 }

    func body(content: Content) -> some View {
        if case .none = style {
            content
        } else {
            TimelineView(.animation(paused: planeIsAsleep)) { timeline in
                #if DEBUG
                let _ = RenderTally.tick("BdLayer")
                #endif
                let now = clock(timeline.date.timeIntervalSinceReferenceDate)
                content
                    .scaleEffect(style.breath(at: now))
                    .rotationEffect(.degrees(style.spin(at: now)))
                    .offset(style.offset(at: now, salt: salt))
            }
        }
    }
}

extension View {

    /// Puts this on a square. See `OnBoard`.
    ///
    /// The board hands down everything else through `BoardContext`, so a caller
    /// states only what is true about *this thing*: where it is, what layer it
    /// belongs to, and how it moves.
    @ViewBuilder
    func onBoard(
        _ point: GridPoint,
        layer: BoardLayer,
        in context: BoardContext?,
        isStanding: Bool? = nil,
        hover: HoverStyle = .none,
        bounces: BounceMoment = .none,
        nudge: CGSize = .zero,
        salt: Int = 0
    ) -> some View {
        if let context {
            modifier(
                OnBoard(
                    point: point,
                    layer: layer,
                    context: context,
                    isStanding: isStanding,
                    hover: hover,
                    bounces: bounces,
                    nudge: nudge,
                    salt: salt
                )
            )
        } else {
            // No board around it — a gallery, a preview. Draw it plainly rather
            // than not at all.
            self
        }
    }
}


/// A `zIndex`, or deliberately none at all.
///
/// "None" is not the same as zero: within a stack, a sibling that carries a
/// `zIndex` sorts above every sibling that carries none, whatever order they
/// were emitted in. A layer whose ordering belongs to the object list has to
/// stay out of that contest entirely.
private struct BoardStacking: ViewModifier {
    let z: Double?

    func body(content: Content) -> some View {
        if let z {
            content.zIndex(z)
        } else {
            content
        }
    }
}
