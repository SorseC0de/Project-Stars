//
//  SignState.swift
//  Project Stars
//
//  The scratchpad a sign's abilities remember things in.
//

import Foundation

/// Everything a sign needs to remember between moves.
///
/// Passives were originally pure decisions over the current board, which was
/// fine while none of them had memory. Most of the real designs do: Aries counts
/// a direction streak, Virgo runs a cooldown, Capricorn and Aquarius each get
/// one use per plane visit, Scorpio's Samsaric Shed fires once per run, Taurus needs two
/// footfalls to crack a Terra tile. All of that lives here.
///
/// ## Rules of the road
///
/// - **It changes only through `GameEvent.signStateChanged`.** Never assign to
///   the engine's copy directly. Anything a planner mutates outside an event
///   lives on a throwaway simulation copy and silently never reaches the real
///   engine — a mistake this project has already shipped twice.
/// - **The event carries the whole value, not a delta.** Coarse on purpose:
///   replacement cannot drift, and the meaning of a replay never depends on how
///   many times it was applied.
/// - **Keys are declared by the sign that owns them**, as constants in that
///   sign's own file. Nothing here knows what `"protectiveStep"` means.
///
/// ## Lifetimes
///
/// Three scopes, cleared at three different moments — see `clearedForPlaneChange`
/// and `clearedForPieceChange`:
///
/// | Scope        | Survives a plane change | Survives a piece change |
/// |--------------|-------------------------|-------------------------|
/// | `counters`   | yes                     | no                      |
/// | `cooldowns`  | yes                     | no                      |
/// | `buffs`      | yes                     | no                      |
/// | `planeFlags` | **no**                  | no                      |
/// | `runFlags`   | yes                     | **yes**¹                |
///
/// ¹ Scorpio's Samsaric Shed is explicitly refreshed by changing pieces, so `runFlags` is
/// the one scope a piece change *does* wipe. See `clearedForPieceChange`.
struct SignState: Equatable {

    // MARK: Direction streak

    /// The direction of the last committed move, or `nil` before the first.
    var streakDirection: SwipeDirection?

    /// How many moves in a row have gone `streakDirection`, counting the first.
    ///
    /// So a value of `1` is "no streak yet" and `3` is "two consecutive repeats".
    /// Aries pays out on everything above `1`.
    var streakLength: Int = 0

    /// Consecutive moves that have cleared at least one hole.
    ///
    /// Tracked by the engine rather than by a passive because `meterBonus` is a
    /// read-only hook — it can price a streak but cannot count one. Scorpio's
    /// Void Culling escalates off this.
    var holeJumpStreak: Int = 0

    /// `moveCount` at the moment the piece arrived on the plane it is on.
    ///
    /// Lets an ability refuse to fire on the same turn as the arrival that
    /// enabled it — Pisces cannot Upstream straight back out of a fall.
    var planeArrivalMove: Int = 0

    // MARK: Timers

    /// Moves remaining before a keyed ability is usable again.
    ///
    /// Ticks down by one per committed move; an entry at zero is removed. Absent
    /// key means ready.
    var cooldowns: [String: Int] = [:]

    /// Moves remaining on a keyed temporary effect, e.g. Aries' Brazen Blaze.
    ///
    /// Ticks down the same way. Absent key means inactive.
    var buffs: [String: Int] = [:]

    // MARK: Flags

    /// Keyed one-shots that reset every time the piece arrives on a plane.
    ///
    /// For "once per plane visit" abilities. Note this resets on *arrival*, so
    /// bouncing Astra → Terra → Astra genuinely refreshes it — which is the
    /// intent, since getting back up is itself the achievement.
    var planeFlags: Set<String> = []

    /// Keyed one-shots that last the whole run.
    var runFlags: Set<String> = []

    // MARK: Tile memory

    /// Tiles that have taken a partial footfall but not yet a full stage of
    /// wear.
    ///
    /// Taurus' Hasty Hooves needs two steps on Terra to advance one stage; this
    /// is where the first of the two is remembered. Keyed by plane so the two
    /// boards cannot bleed into each other.
    var partialWear: [Plane: Set<GridPoint>] = [:]

    /// Free-form per-sign counters for anything the named fields do not cover.
    var counters: [String: Int] = [:]

    // MARK: Sanctuary

    /// Leo's sun, if one is burning.
    ///
    /// Named like `sanctuary` and for the same reason: it is a *place* with a
    /// lifetime, which `buffs` cannot express.
    var sun: Sun?

    /// A small sun hanging over one square.
    struct Sun: Equatable {
        /// The square it burns over. It does not move once placed.
        var point: GridPoint
        var plane: Plane

        /// Committed moves left before it goes out.
        var movesRemaining: Int
    }

    /// The protected patch of board a Zodiaction has thrown up, if any.
    ///
    /// A named field rather than a `buffs` entry because a buff is only a
    /// number of moves — this also has to remember *where* and *on which
    /// plane*, and the engine has to be able to ask about it on every single
    /// tile change. Same reasoning as `partialWear`.
    var sanctuary: Sanctuary?

    /// Ground that refuses to get any worse.
    struct Sanctuary: Equatable {

        /// The middle of the patch. It does not follow the piece: the ground was
        /// consecrated where it was standing, and walking away does not take it
        /// along.
        var centre: GridPoint

        /// Which board it was raised on. A sanctuary on Astra means nothing to
        /// the Terra square with the same coordinates.
        var plane: Plane

        /// Committed moves left before it lifts.
        var movesRemaining: Int

        /// How far it reaches from the centre, in squares. `1` is the 3x3.
        var radius: Int

        /// Whether this square is inside the patch.
        ///
        /// Chebyshev distance, not Manhattan: the region is a square, so the
        /// corners are in.
        func covers(_ point: GridPoint, on plane: Plane) -> Bool {
            guard plane == self.plane else { return false }
            return abs(point.x - centre.x) <= radius
                && abs(point.y - centre.y) <= radius
        }
    }

    /// True when this square is currently under a sanctuary.
    func isSheltered(_ point: GridPoint, on plane: Plane) -> Bool {
        sanctuary?.covers(point, on: plane) ?? false
    }

    // MARK: - Queries

    /// True when a keyed ability is off cooldown.
    func isReady(_ key: String) -> Bool {
        (cooldowns[key] ?? 0) <= 0
    }

    /// Moves left on a keyed buff. Zero when inactive.
    func remaining(_ key: String) -> Int {
        max(buffs[key] ?? 0, 0)
    }

    /// True when a keyed buff is currently running.
    func isActive(_ key: String) -> Bool {
        remaining(key) > 0
    }

    /// True when a tile already carries a partial footfall.
    func hasPartialWear(at point: GridPoint, on plane: Plane) -> Bool {
        partialWear[plane]?.contains(point) ?? false
    }

    // MARK: - Mutation
    //
    // These edit a *copy* that is on its way into a `signStateChanged` event.
    // They are never called on the engine's live value.

    /// Puts a keyed ability on cooldown for `moves` committed moves.
    mutating func startCooldown(_ key: String, moves: Int) {
        cooldowns[key] = max(moves, 0)
    }

    /// Starts (or refreshes) a keyed buff for `moves` committed moves.
    mutating func startBuff(_ key: String, moves: Int) {
        buffs[key] = max(moves, 0)
    }

    /// Records a partial footfall on a tile.
    mutating func addPartialWear(at point: GridPoint, on plane: Plane) {
        partialWear[plane, default: []].insert(point)
    }

    /// Clears a tile's partial footfall, e.g. because it has now taken a full
    /// stage, or because the tile was repaired out from under the memory.
    mutating func clearPartialWear(at point: GridPoint, on plane: Plane) {
        partialWear[plane]?.remove(point)
    }

    /// Folds a committed move into the streak counter.
    mutating func recordMove(direction: SwipeDirection) {
        if direction == streakDirection {
            streakLength += 1
        } else {
            streakDirection = direction
            streakLength = 1
        }
    }

    /// Folds a move's hole-clearing into the escalating streak. A move that
    /// clears nothing breaks it.
    mutating func recordHoleJumps(_ count: Int) {
        holeJumpStreak = count > 0 ? holeJumpStreak + 1 : 0
    }

    /// Advances every timer by one committed move, dropping the expired ones.
    ///
    /// Called once per move, after the move has resolved — so a buff granted
    /// with `moves: 5` covers the five moves *after* the one that granted it.
    mutating func tickTimers() {
        cooldowns = cooldowns.compactMapValues { $0 > 1 ? $0 - 1 : nil }
        buffs = buffs.compactMapValues { $0 > 1 ? $0 - 1 : nil }

        // Granted with 3, it shelters the three moves after the one that raised
        // it and lifts as the fourth begins.
        if var standing = sanctuary {
            standing.movesRemaining -= 1
            sanctuary = standing.movesRemaining > 0 ? standing : nil
        }

        if var burning = sun {
            burning.movesRemaining -= 1
            sun = burning.movesRemaining > 0 ? burning : nil
        }
    }

    // MARK: - Lifetime boundaries

    /// This state as it should look on arriving at a new plane.
    ///
    /// Only `planeFlags` resets. Cooldowns and buffs deliberately survive: a
    /// three-move cooldown means three moves, not "three moves unless you fell".
    func clearedForPlaneChange(atMove moveCount: Int) -> SignState {
        var copy = self
        copy.planeFlags = []
        copy.planeArrivalMove = moveCount
        return copy
    }

    /// This state as it should look after the piece becomes a different sign.
    ///
    /// Everything goes, `runFlags` included — the new sign has no business
    /// inheriting the old one's memory, and Scorpio's Samsaric Shed is specified to be
    /// refreshed by exactly this.
    var clearedForPieceChange: SignState {
        var copy = SignState()
        // The streak is a property of how the *player* has been moving, not of
        // the sign, so it is the one thing that carries across.
        copy.streakDirection = streakDirection
        copy.streakLength = streakLength
        return copy
    }
}
