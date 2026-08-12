//
//  MovementPattern.swift
//  Project Stars
//
//  How a piece is allowed to move, independent of which sign owns it.
//

import Foundation

// MARK: - MovementStyle

/// How a piece travels between its origin and its destination.
///
/// This decides *which tiles the move wears*, and is therefore one of the
/// sharpest balance levers in the game — a sliding piece leaves a trail of
/// damage behind it, a jumping piece leaves the board between two points
/// untouched.
enum MovementStyle: String, CaseIterable, Codable {

    /// The piece walks the squares between origin and destination, wearing
    /// **every tile it crosses**, not just the one it stops on. A tile that
    /// breaks underfoot mid-slide drops the piece right there — the rest of the
    /// slide never happens.
    ///
    /// The default. Most signs slide.
    case slide

    /// The piece leaves the ground and lands, wearing **only the destination**.
    /// Whatever it passes over is untouched, including holes.
    case jump

    var displayName: String {
        switch self {
        case .slide: "Slide"
        case .jump: "Jump"
        }
    }
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
    init(name: String, distance: Int, style: MovementStyle = .slide) {
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
        var style: MovementStyle

        init(_ applies: Applicability, distance: Int, style: MovementStyle = .slide) {
            self.applies = applies
            self.distance = distance
            self.style = style
        }
    }

    /// Where an option is available.
    enum Applicability: Equatable {
        /// All four directions.
        case any

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
    static let cardinalLeap = MovementPattern(name: "Leap", distance: 2, style: .jump)

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
            MoveOption(.any, distance: 2, style: .jump),
        ]
    )

    /// **Sagittarius — Archer.** Ordinary in every direction except forward,
    /// where it can leap two squares or loose itself three.
    ///
    /// Both forward options are jumps. The two-square stride used to be a slide,
    /// which meant the archer's own direction was the one it could not safely
    /// travel far in — it wore two tiles to go two squares. Leaping it costs the
    /// ground nothing, and the price is paid instead by
    /// `SagittariusVariableVoyager`, which will not let it be taken twice
    /// running.
    static let archer = MovementPattern(
        name: "Archer",
        options: [
            MoveOption(.any, distance: 1, style: .slide),
            MoveOption(.relative(.forward), distance: 2, style: .jump),
            MoveOption(.relative(.forward), distance: 3, style: .jump),
        ]
    )

    /// **Capricorn — Capable Climber.** Ordinary everywhere, but northward it
    /// may vault two squares instead. The cooldown is enforced by the passive,
    /// not by the pattern.
    static let mountainClimber = MovementPattern(
        name: "Climber",
        options: [
            MoveOption(.any, distance: 1, style: .slide),
            MoveOption(.absolute(.up), distance: 2, style: .jump),
        ]
    )
}
