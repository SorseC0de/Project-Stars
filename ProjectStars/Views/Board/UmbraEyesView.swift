//
//  UmbraEyesView.swift
//  Project Stars
//
//  Something is looking up through the hole.
//

import SwiftUI

/// Nilyth's eyes, seen through the umbra hole on Terra.
///
/// ## What this is for
///
/// It is the tell. One tile on Terra is the way down to Umbra and every other
/// hole is death, so the difference has to be *visible* once the hole opens —
/// otherwise the plane is reached by accident and never by decision. Two slanted yellow
/// eyes blinking in the dark say "something is down there" without saying what, which is the whole of the intended read: the glow tells you where to
/// look, not what you will find.
///
/// The slant is Aries' — the ram's statue wears the same angled eyes, so the
/// shape already means *this thing is not friendly* in this game's own language
/// rather than in general pixel-art shorthand.
///
/// ## Why it is drawn rather than sprited
///
/// Because it is four pixels that move. A sprite strip would need a frame for
/// every position and every stage of a blink, and the interesting part — that
/// the eyes wander, hold, blink at odd moments and go away again — is exactly
/// what a fixed strip cannot do. Drawn, the whole behaviour is a handful of
/// numbers and it never repeats the same way twice.
///
/// ## Why it is deterministic
///
/// Everything here is hashed off the tile and the appearance number rather than
/// rolled. A view that called `random()` would re-roll on every frame and the
/// eyes would seethe; hashing means they hold still between look-steps, and two
/// holes on the same board blink out of step with each other for free.
struct UmbraEyesView: View {

    /// The square this hole is, which seeds the pattern. Two holes never share
    /// a rhythm.
    let point: GridPoint

    /// Size of a board cell, in points.
    let tileSize: CGFloat

    /// Points per art pixel, so every offset lands on the grid.
    let scale: CGFloat

    /// The colour they glow. Nilyth's yellow by default; Aquarius' storm wants
    /// its own.
    var tint: Color = Palette.yellow

    /// Pixels of dark between the two, and how far the pair drifts. Defaulted to
    /// Nilyth's, which is Aries' spacing — see `GameRules.umbraEyeGap`.
    var gap: Int = GameRules.umbraEyeGap
    var wander: Int = GameRules.umbraEyeWander

    /// How long a full cycle of appearing, looking about and going takes. A
    /// creature that is *always* watching wants this shorter than one that
    /// surfaces now and then.
    var cycle: TimeInterval = GameRules.umbraEyesCycle
    var dwell: TimeInterval = GameRules.umbraEyesDwell

    /// Seconds, stopped whenever the game is — see `AmbientClock`.
    @Environment(\.ambientClock) private var ambientClock

    var body: some View {
        TimelineView(.animation) { timeline in
            let now = ambientClock(timeline.date.timeIntervalSinceReferenceDate)
            let look = gaze(at: now)

            ZStack {
                ForEach([-1, 1], id: \.self) { side in
                    // Each eye is two pixels on a diagonal, falling **toward**
                    // the centre as it descends — `\` on the left, `/` on the
                    // right, which is a brow coming down at the nose.
                    //
                    // Two upright pillars were the first attempt and they read
                    // as *curious*: a pair of parallel bars is a face paying
                    // attention, not a face that means you harm. The slant is
                    // the entire difference, and it costs the same two pixels —
                    // so the blink is unchanged.
                    ForEach(0..<look.rows, id: \.self) { row in
                        Rectangle()
                            .fill(tint)
                            .frame(width: scale, height: scale)
                            .offset(
                                x: CGFloat(side) * eyeInset
                                    // Inward as it drops. `row` counts down
                                    // from the top, and the bottom pixel is the
                                    // one nearer the middle.
                                    - CGFloat(side) * CGFloat(row) * scale
                                    + look.offset.width,
                                y: CGFloat(row) * scale + look.offset.height
                            )
                    }
                }
            }
            .frame(width: tileSize, height: tileSize)
        }
        .allowsHitTesting(false)
    }

    /// Half the distance between the two pillars, in points.
    ///
    /// `umbraEyeGap` is the space *between* them, so each sits half a gap plus
    /// half its own width from centre — which with a one-pixel pillar and an odd
    /// gap comes out on whole pixels exactly.
    private var eyeInset: CGFloat {
        (CGFloat(gap) + 1) / 2 * scale
    }

    // MARK: - Behaviour

    /// Where the eyes are and how open they are, right now.
    private func gaze(at now: TimeInterval) -> (offset: CGSize, rows: Int) {
        // Which appearance this is, and how far into it. The cycle length is
        // jittered per appearance so the eyes are never metronomic — a thing
        // that arrives exactly on the beat is a mechanism, not a creature.
        let index = Int(floor(now / cycle))
        let jitter = fraction(index, 1) * GameRules.umbraEyesCycleJitter
        let into = now - Double(index) * cycle - jitter

        // Shut and gone for most of the cycle.
        guard into >= 0, into < dwell else { return (.zero, 0) }

        // Within an appearance the eyes hold a direction for a beat, then move.
        let step = Int(into / GameRules.umbraEyesLookInterval)
        let range = wander
        let dx = Double(Int(fraction(index, step * 2 + 2) * Double(range * 2 + 1)) - range)
        let dy = Double(Int(fraction(index, step * 2 + 3) * Double(range * 2 + 1)) - range)

        return (
            CGSize(width: CGFloat(dx) * scale, height: CGFloat(dy) * scale),
            rows(index: index, step: step, into: into)
        )
    }

    /// How many pixels of each eye are lit: two open, one mid-blink, none shut.
    ///
    /// A blink is taken a pixel at a time rather than faded, because an eye is
    /// two pixels and there is nothing between lit and unlit at that size.
    /// Opening and closing are the same two frames in reverse.
    ///
    /// The pixel that survives a half-blink is the **lower** one, since `row`
    /// counts from the top — a lid coming down, and on a slanted eye it leaves
    /// the inner corner, which is the angry half.
    private func rows(index: Int, step: Int, into: TimeInterval) -> Int {
        let open = GameRules.umbraEyeRows

        // The appearance itself opens and closes: nothing, one row, two.
        let entering = into
        let leaving = dwell - into
        if entering < GameRules.umbraBlinkFrame { return 1 }
        if leaving < GameRules.umbraBlinkFrame { return 1 }
        if leaving < GameRules.umbraBlinkFrame * 2 { return open - 1 }

        // And blinks at odd moments in between.
        guard fraction(index, step * 2 + 4) < GameRules.umbraBlinkChance else { return open }

        let within = into - Double(step) * GameRules.umbraEyesLookInterval
        switch within {
        case ..<GameRules.umbraBlinkFrame: return open - 1
        case ..<(GameRules.umbraBlinkFrame * 2): return 0
        case ..<(GameRules.umbraBlinkFrame * 3): return open - 1
        default: return open
        }
    }

    /// A stable `0`…`1` from the tile, the appearance and a salt.
    ///
    /// The same integer hash `paletteMoss` uses, for the same reason: it has to
    /// be repeatable frame to frame and different everywhere else.
    private func fraction(_ index: Int, _ salt: Int) -> Double {
        var h = UInt64(bitPattern: Int64(point.x &* 73_856_093))
        h ^= UInt64(bitPattern: Int64(point.y &* 19_349_663))
        h ^= UInt64(bitPattern: Int64(index &* 83_492_791))
        h ^= UInt64(bitPattern: Int64(salt &* 2_654_435_761))
        h = (h ^ (h >> 33)) &* 0xFF51_AFD7_ED55_8CCD
        h = (h ^ (h >> 33)) &* 0xC4CE_B9FE_1A85_EC53
        return Double((h ^ (h >> 33)) % 10_000) / 10_000
    }
}
