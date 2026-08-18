//
//  MovementPattern.swift
//  Project Stars
//
//  How a piece is allowed to move, independent of which sign owns it.
//

import Foundation

// MARK: - MoveType

/// How a piece travels between its origin and its destination.
///
/// This decides *which tiles the move wears*, and is therefore one of the
/// sharpest balance levers in the game — a sliding piece leaves a trail of
/// damage behind it, a jumping piece leaves the board between two points
/// untouched.
///
/// ## One list, for every move in the game
///
/// There were two of these: this one for steps and `TeleportStyle` for
/// everything that arrived without walking. Two lists meant two dispatches, and
/// a move could only be described by whichever list its *emitter* happened to
/// use — so the question "how is this piece moving" had two different answers
/// depending on who was asking.
///
/// That is what let a sign's identity leak into its movement. The archer had
/// exactly one way to teleport when the code was written, so his launch was
/// keyed on **being Sagittarius** rather than on taking that kind of move; the
/// day anything else teleported him — Astral Breeze, a corner, an island — he
/// vaulted after an arrow that was not there.
///
/// So: one list, and a piece takes a move of a type. Nothing reads the sign to
/// decide how a move looks, because the type already said.
enum MoveType: String, CaseIterable, Codable {

    /// The piece walks the squares between origin and destination, wearing
    /// **every tile it crosses**, not just the one it stops on. A tile that
    /// breaks underfoot mid-slide drops the piece right there — the rest of the
    /// slide never happens.
    ///
    /// The default. Most signs slide.
    case slide

    /// The piece is **carried** rather than moving under its own power.
    ///
    /// Aquarius in his storm. Visually a slide — it stays on the ground and it
    /// does not arc — and mechanically nothing: the wind is doing the work, so
    /// it neither presses the squares it crosses nor charges the one it leaves.
    ///
    /// Its own case rather than `slide`, for a reason that is not cosmetic. One
    /// square of travel is coerced to `.hop` when a move has no middle, because
    /// most patterns declare `.slide` as a harmless default and a one-square
    /// "slide" would charge its exit tile. Aquarius moves exactly one square, so
    /// that coercion overwrote his style on *every* move and he hopped at every
    /// phase. A style that is deliberately about being carried has to survive
    /// the rule meant for styles that were never deliberate.
    case blown

    /// The piece leaves the ground and lands, wearing **only the destination**.
    /// Whatever it passes over is untouched, including holes.
    ///
    /// The ordinary short arc — one square, or a sign's own two or three.
    case hop

    /// A hop that is *about* leaving the ground: far higher, far slower, and
    /// pancaked on the way down.
    ///
    /// Identical to `hop` in what it touches, and different in everything the
    /// player sees — Taurus' Flowering Flop, Pisces' dive, Sagittarius going
    /// after his own arrow. It is a separate case rather than a flag on `hop`
    /// because the distinction is not "how far": a three-square stride is still
    /// a hop, and a leap that lands where it started is still a leap.
    case superJump

    /// The piece runs, standing on **every square on the way** and charging each
    /// one as it leaves it — one turn however far it goes.
    ///
    /// Between the other two rather than a variant of either. A slide is carried
    /// and touches only its ends; a jump is airborne and touches only where it
    /// lands; a charge is *walked*, so every square is both stood on and left,
    /// and the damage is charged on the way out.
    ///
    /// Aries' Brazen Blaze is the only thing that moves this way today, and it
    /// was built as a pile of hand-written events inside the sign — which is why
    /// nothing else could reuse it, and why its wear, its balk and its effects
    /// each had to be special-cased somewhere else. Naming the *style* puts it
    /// where `travel` can drive it like the other two.
    case charge

    /// The piece is somewhere else, without having been anywhere in between.
    ///
    /// Astral Breeze, Aquarius' corners, Sagittarius recalling his arrow, the
    /// island carrying its passenger. It touches its destination and nothing
    /// else — not even the square it left, since it did not push off from it.
    ///
    /// Named here because half the game already asks the question and each place
    /// answered it its own way: the retinue restarts its queue for one, the
    /// cursor projects differently for another, the wake fires for a third. One
    /// case they can all read is the point.
    case teleport

    /// Straight up through the ceiling, surfacing on the plane above.
    ///
    /// Pisces swimming Upstream — the one piece that climbs under its own power.
    /// A teleport is *out here, in there*; this is a body breaking a surface,
    /// which is a different picture and the reason it is not simply a teleport
    /// that happens to change plane.
    case rise

    var displayName: String {
        switch self {
        case .slide: "Slide"
        case .blown: "Blown"
        case .hop: "Hop"
        case .superJump: "Super jump"
        case .charge: "Charge"
        case .teleport: "Teleport"
        case .rise: "Rise"
        }
    }

    /// Whether the squares between the ends are stood on.
    ///
    /// The question `travel` actually asks, rather than a list of cases at each
    /// site that has to be kept in step with this one.
    var touchesEverySquare: Bool { self == .charge }

    /// Whether this leaves the ground, and so touches nothing it passes over.
    var isAirborne: Bool { self == .hop || self == .superJump || self == .rise }

    /// Whether the squares between the ends were crossed at all.
    ///
    /// False for a warp, which is the distinction the retinue, the wake and the
    /// cursor were each making for themselves.
    /// `.blown` counts: it is on the ground the whole way, which is what makes
    /// it read as being carried rather than as a short hop. What it does *to*
    /// the ground is a separate question, answered by `wear`.
    var travelsTheGround: Bool { self == .slide || self == .charge || self == .blown }

    /// Whether this arrives without having crossed anything at all.
    var isInstant: Bool { self == .teleport }

    /// Whether this can end on a different plane from the one it began on.
    ///
    /// A rise always does; a teleport may. Everything else stays where it is —
    /// falling through a hole is its own event, not a move.
    var mayChangePlane: Bool { self == .teleport || self == .rise }

    // MARK: - What a style already implies
    //
    // The point of naming these five is that saying "slide" should be enough:
    // the engine knows it wears its ends, the panel knows it thumps when it runs
    // out of board, the board knows not to bounce the sprite. Every one of the
    // questions below used to be answered at the site that needed it — which is
    // how a slide ended up wearing every square it crossed in one place and only
    // its ends in another, and why Aries' charge had to hand-write events no
    // other sign could reuse.
    //
    // A new style declares its answers here once and the whole game behaves.

    /// Which squares this charges on the way through.
    var wear: MoveMoment {
        switch self {
        case .slide: .both
        // Nothing. The wind is carrying him, so no square pays — not the one he
        // leaves, not the ones he crosses. Quirky Caper says the same thing in
        // its own terms; this is the movement agreeing with it.
        case .blown: .landing
        case .charge: .everySquare
        case .hop, .superJump: .landing
        case .teleport, .rise: .landing
        }
    }

    /// Whether running out of board is worth a thump.
    ///
    /// A style that travels has somewhere it was trying to get to and was
    /// stopped; one that arrives had no journey to interrupt.
    var balksAtWalls: Bool { travelsTheGround }

    /// Whether the piece leaves the ground, and so takes an arc rather than
    /// being carried along it.
    var arcs: Bool { isAirborne }

    /// Whether the ground gives under the arrival.
    ///
    /// Only something that came *down* lands. A slide is already at ground
    /// level and a warp was never above it.
    var bouncesOnArrival: Bool { isAirborne }

    /// How long one square of it takes, as a share of the base step.
    ///
    /// A leap is slow because it is a decision; a charge is quick because it is
    /// a run. Both were literals at their call sites before.
    var paceMultiplier: Double {
        switch self {
        case .slide, .blown: GameRules.slideStepPace
        case .charge: GameRules.chargeStepPace
        case .hop: 1
        case .superJump, .rise: GameRules.leapPace
        case .teleport: 0
        }
    }
}

/// A point in a move that something can be attached to.
///
/// One vocabulary, used for two questions that were previously asked in
/// different words: **which squares a move damages**, and **where its effect
/// plays**. They are the same question — *when in this move does the thing
/// happen* — and a caller that can say "wear the exit, play the sprite on both
/// ends" without learning two enums is the whole point of `GameEngine.move`.
enum MoveMoment: String, CaseIterable, Codable {

    /// Nowhere. A move that costs the ground nothing, or carries no effect.
    case never

    /// The square pushed off from, charged as the piece leaves it.
    case exit

    /// The square arrived on.
    case landing

    /// Both ends, and nothing in between — see `GameRules.slideWearsEndsOnly`.
    case both

    /// Every square touched, charged on the way out of each. Only something
    /// that is *walked* can use this; a jump is not on the squares it crosses.
    case everySquare

    /// Whether this includes the square being left.
    var includesExit: Bool { self == .exit || self == .both || self == .everySquare }

    /// Whether this includes the square being arrived on.
    var includesLanding: Bool { self == .landing || self == .both || self == .everySquare }
}

// MARK: - MovementPattern

/// The set of moves a piece may make, and the rule for picking one from a swipe.
///
/// A pattern is a list of **options**. Each option says how far it goes, how it
/// covers that ground, and in which directions it is available — either
/// absolutely (Capricorn climbs north and only north) or relative to the piece's
/// current facing (Cancer steps to whichever side it happens to be looking
/// across).
///
/// Several options can apply to one direction. When they do, the player chooses
/// between them **with the length of the swipe**: a short flick takes the
/// nearest, a long drag takes the furthest. That is why options are always
/// sorted by distance — the ordering is the control scheme.
struct MovementPattern: Equatable {

    /// Short label shown in the info panel, e.g. "Step" or "Sidestep".
    var name: String

    /// Every move this pattern can make, nearest first.
    var options: [MoveOption]

    init(name: String, options: [MoveOption]) {
        self.name = name
        self.options = options.sorted { $0.distance < $1.distance }
    }

    /// Convenience for the common case: one distance, one style, all directions.
    init(name: String, distance: Int, style: MoveType = .slide) {
        self.init(name: name, options: [MoveOption(.any, distance: distance, style: style)])
    }

    // MARK: - MoveOption

    /// One move a pattern can make.
    struct MoveOption: Equatable {
        /// Which directions this option is available in.
        var applies: Applicability

        /// How many squares it covers.
        var distance: Int

        /// How it covers them. A slide wears everything it crosses; a jump wears
        /// only where it lands.
        var style: MoveType

        /// The phantom this option came from, if it is on loan.
        ///
        /// Leo's retinue lends its movement — see `LeoAttractingAten` — and
        /// taking a borrowed move spends the phantom that lent it. The option
        /// has to remember whose it was, because by the time the move resolves
        /// the only thing left describing it *is* the option.
        var owner: Zodiac?

        /// When true the move runs until the board runs out, and `distance` is
        /// only a sort key.
        ///
        /// A pattern cannot know how far the wall is — it has no board — so the
        /// path for one of these is built by `GameEngine.resolvedMove(for:reach:)`
        /// instead. Pisces' surf is the only user: it is the Astral Brook made
        /// into ordinary movement, and the Brook has always gone to the edge.
        var reachesWall: Bool

        init(
            _ applies: Applicability,
            distance: Int,
            style: MoveType = .slide,
            reachesWall: Bool = false,
            owner: Zodiac? = nil
        ) {
            self.applies = applies
            self.distance = distance
            self.style = style
            self.reachesWall = reachesWall
            self.owner = owner
        }
    }

    /// Where an option is available.
    enum Applicability: Equatable {
        /// All four **cardinal** directions.
        ///
        /// Not all eight. The diagonals were added to `SwipeDirection` for
        /// Virgo, and had `any` widened to include them every sign in the game
        /// would silently have become a queen.
        case any

        /// The four diagonals and nothing else.
        case diagonal

        /// All eight. Virgo's step, and so far only Virgo's.
        case everyWay

        /// One fixed compass direction, regardless of facing.
        case absolute(SwipeDirection)

        /// A direction defined by where the piece is looking.
        case relative(Relative)
    }

    /// A direction expressed against the piece's facing.
    enum Relative: Equatable {
        /// The way the piece is already looking.
        case forward
        /// Directly behind it.
        case backward
        /// Either of the two sides.
        case sideways
    }

    /// A one-line description of what this pattern can do, for the panel and the
    /// selection screen.
    ///
    /// Reads off the options rather than being written by hand, so it cannot go
    /// stale when a pattern is retuned.
    var summary: String {
        let distances = Set(options.map(\.distance)).sorted()
        let reach = distances.map(String.init).joined(separator: "–")
        let styles = Set(options.map(\.style))
        let style = styles.count == 1
            ? (styles.first ?? .slide).displayName
            : "Mixed"
        return "\(name) · \(reach) · \(style)"
    }

    // MARK: - Swipe resolution

    /// The options available for a swipe in `direction`, nearest first.
    ///
    /// - Parameter facing: Where the piece is currently looking, which is what
    ///   `.relative` options are measured against.
    func options(for direction: SwipeDirection, facing: SwipeDirection) -> [MoveOption] {
        options.filter { option in
            switch option.applies {
            case .any:
                return direction.isCardinal
            case .diagonal:
                return !direction.isCardinal
            case .everyWay:
                return true
            case let .absolute(fixed):
                return fixed == direction
            case let .relative(relative):
                switch relative {
                case .forward: return direction == facing
                case .backward: return direction == facing.opposite
                case .sideways: return facing.perpendicular.contains(direction)
                }
            }
        }
    }

    /// The option a swipe of the given reach selects.
    ///
    /// `reach` is how many distance-steps the drag ran past the commit
    /// threshold. It is clamped, so overshooting simply takes the longest move
    /// available rather than failing.
    func option(
        for direction: SwipeDirection,
        facing: SwipeDirection,
        reach: Int
    ) -> MoveOption? {
        let available = options(for: direction, facing: facing)
        guard !available.isEmpty else { return nil }
        return available[min(max(reach, 0), available.count - 1)]
    }

    /// How many distinct distances are on offer in a direction. `1` means the
    /// swipe's length does not matter.
    func reachCount(for direction: SwipeDirection, facing: SwipeDirection) -> Int {
        options(for: direction, facing: facing).count
    }

    // MARK: - Path

    /// The squares an option actually puts the piece on, in order, **excluding**
    /// the square it started from.
    ///
    /// - A `slide` returns every square along the way, so the engine can wear
    ///   each one and stop early if one gives out.
    /// - A `jump` returns only the destination.
    func path(
        from origin: GridPoint,
        direction: SwipeDirection,
        option: MoveOption
    ) -> [GridPoint] {
        let step = direction.unitOffset
        let destination = GridPoint(
            origin.x + step.dx * option.distance,
            origin.y + step.dy * option.distance
        )

        guard option.style == .slide, option.distance > 1 else { return [destination] }

        return (1...option.distance).map { i in
            GridPoint(origin.x + step.dx * i, origin.y + step.dy * i)
        }
    }

    // MARK: - Pattern library

    /// One square orthogonally. The default, and what most signs use.
    static let cardinalStep = MovementPattern(name: "Step", distance: 1)

    /// Two squares orthogonally, wearing the tile crossed on the way.
    static let cardinalGlide = MovementPattern(name: "Glide", distance: 2, style: .slide)

    /// Two squares orthogonally, leaving the square in between untouched.
    static let cardinalLeap = MovementPattern(name: "Leap", distance: 2, style: .hop)

    // MARK: Per-sign patterns

    /// **Cancer — Sidestep.** An ordinary step in any direction, but up to two
    /// squares to either side of where it is looking.
    static let sidestep = MovementPattern(
        name: "Sidestep",
        options: [
            MoveOption(.any, distance: 1),
            // A slide, and only ever the full two: one square sideways is just
            // a step, and offering it as a separate option asked the player to
            // choose between two things that do the same thing.
            MoveOption(.relative(.sideways), distance: 2, style: .slide),
        ]
    )

    /// **Scorpio.** One square walked, or two vaulted — the vault clears
    /// whatever is between, which is what Void Culling pays out on.
    static let slideOrVault = MovementPattern(
        name: "Vault",
        options: [
            MoveOption(.any, distance: 1, style: .slide),
            MoveOption(.any, distance: 2, style: .hop),
        ]
    )

    /// **Pisces — Starstream Surfer.** An ordinary step, or a surf to the wall.
    ///
    /// The long option is Downstream — what used to be half of Pisces'
    /// Zodiaction — made available on any turn. The sort key is the board's
    /// width so it always comes second in the reach selector; the actual
    /// distance is however far the water goes.
    static let starstream = MovementPattern(
        name: "Starstream",
        options: [
            MoveOption(.any, distance: 1),
            MoveOption(.any, distance: GameRules.gridSize, style: .slide, reachesWall: true),
        ]
    )

    /// **Virgo — Scrupulous Step.** One square in any of the eight directions.
    ///
    /// The only pattern in the game that uses `everyWay`. Virgo covers ground
    /// nobody else can reach in a turn — a diagonal step is two cardinal steps'
    /// worth of progress for one tile of wear — which is the whole of the buff.
    static let scrupulousStep = MovementPattern(
        name: "Scruple",
        options: [MoveOption(.everyWay, distance: 1)]
    )

    /// **Sagittarius — Archer.** Ordinary in every direction except forward,
    /// where it can leap two squares or loose itself three.
    ///
    /// Both forward options are jumps. The two-square stride used to be a slide,
    /// which meant the archer's own direction was the one it could not safely
    /// travel far in — it wore two tiles to go two squares. Leaping it costs the
    /// ground nothing, and the price is paid instead by
    /// `SagittariusVulcanVault`, which will not let it be taken twice
    /// running.
    static let archer = MovementPattern(
        name: "Archer",
        options: [
            MoveOption(.any, distance: 1, style: .slide),
            // The leap goes anywhere. Forward-only was the archer's whole
            // problem: the one direction it could cover ground in was the one
            // direction it was already looking, so it never had a reason to turn
            // — and the every-other-turn cooldown had already paid for the reach
            // twice over.
            MoveOption(.any, distance: 2, style: .hop),
            MoveOption(.relative(.forward), distance: 3, style: .hop),
        ]
    )

    /// **Capricorn — Capable Climber.** Ordinary everywhere, but northward it
    /// may vault two squares instead. The cooldown is enforced by the passive,
    /// not by the pattern.
    static let mountainClimber = MovementPattern(
        name: "Climber",
        options: [
            MoveOption(.any, distance: 1, style: .slide),
            MoveOption(.absolute(.up), distance: 2, style: .hop),
        ]
    )
}
