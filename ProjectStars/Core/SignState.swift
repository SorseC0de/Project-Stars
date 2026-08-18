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
/// | `purse`      | yes                     | no                      |
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

    // MARK: Shed skin

    /// The husk Scorpio left behind, if it has shed. See `ScorpioSamsaricShed`.
    var shedSkin: ShedSkin?

    /// Where a shed skin is lying.
    struct ShedSkin: Equatable {
        var point: GridPoint
        var plane: Plane
    }

    // MARK: Retinue

    /// The signs following Leo, oldest first.
    ///
    /// Leo's Attracting Aten summons a phantom of another sign, which trails the
    /// piece and lends its movement, its Zodiaction and its passives. See
    /// `LeoAttractingAten`.
    ///
    /// An array rather than one slot because Terra allows two — and the order is
    /// load-bearing: a re-roll drops the **oldest** and the rest move up, so the
    /// line is a queue and the player can predict which one they are about to
    /// lose.
    var retinue: [Zodiac] = []

    /// The squares Leo has stood on, most recent first.
    ///
    /// ## Why a queue and not an offset
    ///
    /// A follower drawn one square behind the *facing* stands where the lion
    /// would be if it walked backwards — which is not where it came from, and
    /// turning on the spot teleported the whole line around you. Springing them
    /// into place from there only made a stiff thing lag.
    ///
    /// This is the behaviour itself rather than an impression of it: Leo steps,
    /// and each phantom takes the square in front of it in the queue. They walk
    /// the route he walked, single file, one turn apart — which is what
    /// following *is*.
    var trail: [GridPoint] = []

    /// How many phantoms may follow at once, on this plane.
    ///
    /// Two below, one above. Terra is where the lion is strong and where the
    /// board is least forgiving, so the extra body is worth more there — and it
    /// keeps the ability from being simply better on the plane Leo is already
    /// comfortable on.
    static func retinueLimit(on plane: Plane) -> Int {
        plane == .terra ? 2 : 1
    }

    // MARK: Purse

    /// Pentacles Capricorn has banked instead of opening, oldest first.
    ///
    /// Only Celestial Commerce fills it, and only Cosmic Cash-in empties it. It
    /// is a list rather than a set because two Tears banked are two Tears to
    /// spend — quantity is the whole point of a purse.
    ///
    /// It survives a plane change (the money is in your pocket, not on the
    /// board) and not a piece change, since nobody else can spend it.
    var purse: [PickupID] = []

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

    /// Committed moves left of the Astral Bolt's invulnerability. `0` when it
    /// is not running.
    ///
    /// A named field rather than a `buffs` entry for the same reason as the
    /// sanctuary: `buffs` are cleared when the piece changes, and the star is a
    /// state of the *player*, not of whichever sign is carrying it. Change piece
    /// mid-star and the star goes with you.
    var starMoves = 0

    /// True while the Astral Bolt's charge is running.
    var isStarred: Bool { starMoves > 0 }

    /// Committed moves left on the two Essences.
    ///
    /// Named fields rather than `buffs` entries, by the rule the star follows:
    /// a buff belongs to whichever Zodea is carrying it and is cleared when that
    /// changes, and an essence you have absorbed is not undone by the stars
    /// swapping your statue.
    ///
    /// Two counters rather than one signed one, so both can run at once and
    /// cancel for as long as they overlap — which is the honest outcome of
    /// drinking both, and free.
    /// The tile currently shielded by a Nexyial Bastion, and on which plane.
    ///
    /// One at a time: a second Bastion moves the aura rather than stacking, so
    /// the board never has to explain which of two shields absorbed a hit.
    var bastion: GridPoint?
    var bastionPlane: Plane?

    /// True while a Stelluna Sprite is riding along.
    ///
    /// Spent on the first hole stood on, whenever that is. It has no clock —
    /// see `BuffsView`, which draws a count only for the buffs that have one.
    var hasSprite = false

    /// The tile a Match-shift Miasma has marked, and which of the two colours
    /// it is wearing.
    ///
    /// The colour is stored rather than derived so the second coin can be drawn
    /// as the *other* one, which is the whole tell that they are a pair.
    var miasmaMark: GridPoint?
    var miasmaPlane: Plane?
    var miasmaIsWarm = false

    /// True once a Stardar has promised the next reveal.
    var stardarPending = false

    var astralEssenceMoves = 0
    var umbralEssenceMoves = 0

    /// Charge per step from the Essences, `+1`, `-1`, or `0` for none.
    var essenceCharge: Int {
        (astralEssenceMoves > 0 ? 1 : 0) - (umbralEssenceMoves > 0 ? 1 : 0)
    }

    /// Committed moves left of Aquarius' Gone With the Gale. `0` when it is not
    /// running.
    var galeMoves = 0

    /// True when nothing on the board can drop this piece.
    ///
    /// Two states grant it and they are unrelated — the Astral Bolt's star and
    /// Aquarius' gale — so everywhere that asks should ask this rather than
    /// either one.
    var walksOnAir: Bool { isStarred || galeMoves > 0 }

    /// Sagittarius' arrow, if one is stuck in the board.
    ///
    /// A place to warp to, and a promise not to charge until it is spent — see
    /// `SagittariusAstralArrow`.
    var arrow: Arrow?

    /// An arrow planted in a square, waiting to be used.
    struct Arrow: Equatable {
        var point: GridPoint
        var plane: Plane

        /// Committed moves before it rots away.
        ///
        /// Meant never to be reached. The player should experience the arrow as
        /// lasting until they spend it; this exists so that a player who forgets
        /// one on a plane they cannot return to is not locked out of charging
        /// for the rest of the run.
        var movesRemaining: Int
    }

    /// Leo's sun, if one is burning.
    ///
    /// Named like `sanctuary` and for the same reason: it is a *place* with a
    /// lifetime, which `buffs` cannot express.
    var sun: Sun?

    /// A small sun hanging over one square.
    struct Sun: Equatable {
        /// The square it is over.
        ///
        /// It used to be planted and left, back when the Aten's job was to drag
        /// coins toward a fixed point. With the rework it follows Leo — see
        /// `LeoAttractingAten` — so this is updated as the lion moves rather
        /// than being written once.
        var point: GridPoint
        var plane: Plane

        /// Committed moves left before it goes out.
        ///
        /// The Aten no longer runs down on its own — it is lit for exactly as
        /// long as somebody is following, because that is what it means now. See
        /// `SignState.tickTimers()`, which leaves it alone while the retinue is
        /// occupied, and `LeoAttractingAten`.
        var movesRemaining: Int
    }

    /// Polaris, once it has been picked up.
    ///
    /// A fragment of Old Astra is a *thing you carry*, not an effect that fires
    /// on contact — see `PolarisEffect`. Found above it arrives already lit;
    /// found below it is a cold rock that has to be charged before it does
    /// anything.
    enum Polaris: String, Codable, Hashable, Sendable {
        /// Carried, and inert. Needs astral energy.
        case dormant

        /// Lit, and waiting for the player to say when.
        case charged
    }

    /// The fragment being carried, if one is. Nil is the ordinary case.
    var polaris: Polaris?

    /// Which opposing pair of rifts a doorway belongs to.
    ///
    /// The four mirrors are two doorways: north leads to south and east leads to
    /// west. Nothing in the game addresses a single mirror, so this is the
    /// smallest unit worth naming — and being a set means "all of them", "one
    /// pair" and "none" are the same expression rather than three.
    struct RiftAxes: OptionSet, Codable, Hashable, Sendable {

        let rawValue: Int

        init(rawValue: Int) { self.rawValue = rawValue }

        static let northSouth = RiftAxes(rawValue: 1 << 0)
        static let eastWest = RiftAxes(rawValue: 1 << 1)

        /// Both doorways, which is what tearing them open gives you.
        static let both: RiftAxes = [.northSouth, .eastWest]

        /// The pair a move in this direction would cross, if any.
        ///
        /// Diagonals have no rifts — the mirrors sit at the middle of each edge
        /// and are entered head-on — so they answer with the empty set, which
        /// reads as "no doorway" everywhere this is asked.
        static func crossed(by direction: SwipeDirection) -> RiftAxes {
            switch direction {
            case .up, .down: .northSouth
            case .left, .right: .eastWest
            default: []
            }
        }
    }

    /// True once Gemini's rifts have been torn and left behind.
    ///
    /// The rifts are a hole in the world, not a property of the twins: change
    /// piece and they stay open, and whoever is holding the board can use them.
    /// Set when the piece stops being Gemini, and never cleared — you cannot
    /// un-tear a hole in space.
    var riftsLinger = false

    /// Which torn rifts are still open on Terra.
    ///
    /// Gemini's rifts are innate on Astra and endless there. Below, they have to
    /// be *made* — Mirrored Mandate tears all four — and each opposing **pair**
    /// is single-use: step through the north rift and the north-south pair
    /// closes behind you, while the east-west pair stays open for a second
    /// crossing.
    ///
    /// Per pair rather than all four, because a rift and the rift it comes out
    /// of are one doorway seen from both ends — closing that doorway is what
    /// using it costs. The pair on the other axis is a different doorway and was
    /// never entered.
    var terraRifts: RiftAxes = []

    /// Closes whatever is open, on either plane.
    ///
    /// Changing plane closes them; changing piece does not. A rift is a hole in
    /// the world rather than a property of the twins, so it outlives them — but
    /// it does not follow anyone up or down.
    mutating func closeRifts() {
        riftsLinger = false
        terraRifts = []
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
    /// True while the Astral Bolt's star is running.
    ///
    /// Its own name because a great deal keys off it, and `starMoves > 0` read
    /// at a dozen call sites is a fact stated a dozen times.
    var isSuperStar: Bool { starMoves > 0 }

    func isReady(_ key: String) -> Bool {
        // The star ignores cooldowns outright.
        //
        // It already suspends wear, falling and the cost of moving; leaving the
        // once-every-few-turns limits standing was the one place the
        // invulnerability stopped short, and it stopped short at exactly the
        // abilities a player most wants to chain while they are untouchable.
        //
        // Safe as a blanket rule, which is why it is one. No cooldown in the
        // game is load-bearing enough to break if it comes up every turn —
        // Sagittarius' stride, Capricorn's climb, Virgo's old scruple — and the
        // star is itself a countdown, so chaining them is paid for in the only
        // currency it has.
        //
        // Here rather than at each cooldown's own site, so a limit written next
        // year inherits it: every cooldown in the game goes through this one
        // question. See `GameRules.starMoves`.
        if isSuperStar { return true }
        return (cooldowns[key] ?? 0) <= 0
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

        starMoves = max(starMoves - 1, 0)
        galeMoves = max(galeMoves - 1, 0)
        astralEssenceMoves = max(astralEssenceMoves - 1, 0)
        umbralEssenceMoves = max(umbralEssenceMoves - 1, 0)

        if var planted = arrow {
            planted.movesRemaining -= 1
            arrow = planted.movesRemaining > 0 ? planted : nil
        }

        // The Aten burns for as long as somebody is following, and goes out
        // with the last of them. It is the light that says a phantom is here;
        // a light on its own timer would keep going dark while one still was.
        if sun != nil, retinue.isEmpty {
            sun = nil
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

        // A borrowed purse goes with the sign that was carrying it — see
        // `emptyingPurseIfLent(from:)`. Applied before the retinue is cleared,
        // since it is the retinue that decides whether the purse was on loan.
        copy = copy.emptyingPurseIfLent(from: self)

        // The retinue does not make the journey.
        //
        // The alternative was letting phantoms walk over holes while still
        // wearing the ground, which is where this started — but a follower that
        // is lost the moment a tile you advanced reaches badly cracked turns a
        // full meter into a coin flip, and tying them to *falls* drags in Death
        // Dream, Samsaric Shed and every other rescue as special cases.
        //
        // Losing them on any change of plane is one rule with no exceptions,
        // and it is legible before you commit: going down costs you your
        // company. See `GameRules.retinueRefund`.
        copy.retinue = []
        return copy
    }

    /// This state with the purse dropped, if it belonged to a phantom.
    ///
    /// Capricorn's Celestial Commerce banks coins into `purse`, which lives on
    /// the *run* rather than on the sign — so a borrowed Capricorn would fill a
    /// purse that outlived it, and calling another one later would find the
    /// takings still sitting there. A purse you can stockpile across loans is a
    /// bank; the phantom is supposed to be a loan.
    ///
    /// Leo's own purse would be nonsense — the lion has no Commerce — so this
    /// only ever fires for a borrowed one, which is exactly the case that needs
    /// it.
    func emptyingPurseIfLent(from previous: SignState) -> SignState {
        guard previous.retinue.contains(.capricorn) else { return self }
        var copy = self
        copy.purse = []
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

        // So do the things that are on the *board* rather than in the sign's
        // head. A Bastion is consecrated ground and a sun is a body in the sky;
        // neither cares who raised it, and neither should blink out because the
        // player became someone else. This is what makes the abandoned-works
        // bonuses possible — see `GameEngine.claimAbandonedWorks`.
        copy.sanctuary = sanctuary
        copy.sun = sun
        copy.riftsLinger = riftsLinger
        copy.terraRifts = terraRifts
        copy.starMoves = starMoves
        copy.astralEssenceMoves = astralEssenceMoves
        copy.bastion = bastion
        copy.bastionPlane = bastionPlane
        copy.hasSprite = hasSprite
        copy.miasmaMark = miasmaMark
        copy.miasmaPlane = miasmaPlane
        copy.miasmaIsWarm = miasmaIsWarm
        copy.stardarPending = stardarPending
        copy.umbralEssenceMoves = umbralEssenceMoves
        copy.galeMoves = galeMoves
        copy.arrow = arrow
        // **The skin does not survive the swap.**
        //
        // Becoming someone else is the one thing that refreshes Samsaric Shed,
        // so the skin left lying on the board belongs to an ability that has
        // already been given back — a body from a life the run is no longer
        // living. Kept, it was a second shed's worth of insurance sitting in
        // plain sight, and a marker for a rescue that would now come from
        // somewhere else.
        // The retinue is Leo's and nobody else's: a phantom follows the lion,
        // not whoever happens to be holding the board.
        return copy
    }
}
