//
//  PassivePromptView.swift
//  Project Stars
//
//  A small card that says a passive just fired.
//

import SwiftUI

/// One announcement, waiting its turn or taking it.
struct PassivePrompt: Identifiable, Equatable {

    let id = UUID()

    /// The passive's own name, as the info panel writes it.
    let name: String

    /// Already sliding out. Kept so the queue knows which one has had its turn.
    var isLeaving = false

}

/// The mode card's upper bar, shrunk down and sent across the top of the board.
///
/// ## Why it is the same shape
///
/// Because it is the same voice. The card says what the run is; this says what
/// the run just did. Drawn as its own thing it would be a second visual language
/// on the same screen, where a smaller copy of a shape the player has already
/// been shown reads immediately as *the game telling you something*.
///
/// It keeps the mother shape's slant and its tail taper, and it travels the way
/// she does — in from the leading edge, out past the trailing one. It never
/// comes back the way it came.
///
/// ## Why it is gone before the middle of the screen
///
/// Because the board is underneath it and a move is probably being played. It
/// holds where it can be read, then leaves fast: the slide carries on at the
/// same speed, and the fade is much quicker than the travel, so what the player
/// sees is a shape leaving rather than a shape crossing the board.
struct PassivePromptView: View {

    let prompt: PassivePrompt

    /// How far out it flies: the turn counter's trailing edge.
    let reach: CGFloat

    /// Told once it has committed to sliding out.
    let onLeaving: () -> Void

    /// Told once it has gone, whichever way it went.
    let onFinished: () -> Void

    @State private var stage: Stage = .offstage

    /// Where it is, and what it is doing.
    private enum Stage {
        /// Off the leading edge, waiting.
        case offstage

        /// Out at the counter's edge, being read.
        case held

        /// Carrying on past the trailing edge.
        case leaving
    }

    /// When the card began leaving, or `nil` while it is still arriving or held.
    @State private var leftAt: Date?

    var body: some View {
        let size = PromptStyle.size(reaching: reach)

        // Ticking only while it is leaving. Nothing else here needs a frame
        // clock, and a clock that runs the whole time the card is up is a clock
        // running for nothing.
        TimelineView(.animation(paused: leftAt == nil)) { timeline in
            ZStack(alignment: .leading) {
                face
                    .overlay { streaks }
                    .frame(width: size.width, height: size.height)

                word(burning: burn(at: timeline.date, rate: wordRate))
            }
            // Arriving: animated by the transaction that changes the stage.
            .opacity(stage == .offstage ? 0 : 1)
            // Leaving: **not animated at all.** Opacity is spent per tick, at a
            // rate of its own, so how fast the card disappears has nothing to do
            // with how fast it travels. An animation here governs the whole
            // subtree, which is how the fade ended up retiming the slide.
            .opacity(burn(at: timeline.date, rate: PromptStyle.fadeRate))
            .offset(x: offset(size))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .allowsHitTesting(false)
        .task { await arrive() }
    }

    /// What is left of the card, given how long it has been going.
    ///
    /// One over `rate` seconds from full to nothing. Full until it leaves.
    private func burn(at now: Date, rate: Double) -> Double {
        guard let leftAt else { return 1 }
        return max(0, 1 - now.timeIntervalSince(leftAt) * rate)
    }

    /// How fast the word goes.
    ///
    /// The A/B: with the shape, or ahead of it.
    private var wordRate: Double {
        PromptStyle.wordsRideOut
            ? PromptStyle.fadeRate
            : PromptStyle.fadeRate * PromptStyle.wordHaste
    }

    // MARK: - The shape

    private var face: some View {
        Parallelogram(lean: ModeCardStyle.lean).fill(PromptStyle.taper)
    }

    /// Cut to the shape *and* its fade, so they thin out with the tail.
    private var streaks: some View {
        SideStreaks().mask { face }
    }

    /// The passive's name, over the card.
    ///
    /// Stretched horizontally only. A name is a word rather than a picture, and
    /// squashing it in both directions to make it fit makes it *smaller* where
    /// what is wanted is *narrower* — so the vertical scale is pinned at one and
    /// only the width gives.
    private func word(burning left: Double) -> some View {
        Text(prompt.name.uppercased())
            .font(.system(size: PromptStyle.labelSize, weight: .heavy, design: .rounded))
            .tracking(PromptStyle.labelTracking)
            .foregroundStyle(ModeCardStyle.ink)
            .lineLimit(1)
            .fixedSize()
            .scaleEffect(x: PromptStyle.labelStretch, y: 1, anchor: .leading)
            .offset(x: PromptStyle.labelX)
            .opacity(left)
    }

    // MARK: - Where it is

    private func offset(_ size: CGSize) -> CGFloat {
        switch stage {
        // Its trailing edge at the counter's, which is what `reach` means.
        case .held: reach - size.width
        case .offstage: -size.width
        // Far enough that the shape itself is gone, though the fade will have
        // finished long before it gets there.
        case .leaving: reach + size.width
        }
    }

    // MARK: - What it does

    private func arrive() async {
        withAnimation(.easeOut(duration: PromptStyle.arrival)) { stage = .held }
        await sleep(PromptStyle.arrival + PromptStyle.hold)

        onLeaving()
        leftAt = .now

        // **Linear, not eased in.** Easing in spends the first stretch barely
        // moving, and the first stretch is the only part anyone sees — the card
        // appeared to stall and vanish, then do its travelling invisibly. It
        // was stationary a moment ago, so a constant speed is a small lie; a
        // card that visibly *goes* somewhere is worth it.
        withAnimation(.linear(duration: PromptStyle.departure)) { stage = .leaving }
        await sleep(PromptStyle.departure)
        onFinished()
    }

    private func sleep(_ seconds: Double) async {
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
}

// MARK: - Measurements

/// The prompt's proportions and pacing.
///
/// Sized from the distance it flies rather than from the screen: what makes it
/// read as *under the turn counter* is that it lines up with the counter, and
/// the counter's own width is the only thing that knows how wide that is.
@MainActor
enum PromptStyle {

    /// How tall it is and how long, against how far it flies.
    static var height: CGFloat { CGFloat(defaultHeight) }
    static var length: CGFloat { CGFloat(defaultLength) }

    /// How far below the turn counter it sits, in points.
    static var drop: CGFloat { CGFloat(defaultDrop) }

    static func size(reaching reach: CGFloat) -> CGSize {
        CGSize(width: reach * length, height: reach * height)
    }

    static let defaultHeight: Double = 0.20
    static let defaultLength: Double = 1.60
    static let defaultDrop: Double = -8

    /// Solid at the front, gone at the tail — the mother shape's taper, on the
    /// end that trails as it flies out.
    static var taper: LinearGradient {
        LinearGradient(
            gradient: Gradient(stops: [
                .init(color: .clear, location: 0),
                .init(color: .clear, location: CGFloat(ModeCardStyle.fadeFrom)),
                .init(color: ModeCardStyle.face, location: CGFloat(ModeCardStyle.fadeTo)),
                .init(color: ModeCardStyle.face, location: 1),
            ]),
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    /// The word over it: how big, how wide, and where it starts.
    static var labelSize: CGFloat { CGFloat(defaultLabelSize) }
    static var labelStretch: CGFloat { CGFloat(defaultLabelStretch) }
    static var labelX: CGFloat { CGFloat(defaultLabelX) }

    static let labelTracking: CGFloat = 0.5
    static let defaultLabelSize: Double = 10
    static let defaultLabelStretch: Double = 0.85
    static let defaultLabelX: Double = 75

    /// In, read, out. **One way out, whatever else arrives** — an exit that can
    /// be interrupted looks like a mistake, and letting it run looks like two
    /// things having happened, which is what did.
    /// How long the slide in takes.
    static let arrival: Double = 0.20
    static let hold: Double = 1.6

    /// How long the slide out takes — how *fast* it goes, not how long it is
    /// seen for. The fade decides that, and the two are separate on purpose.
    static let departure: Double = 0.40

    /// How much opacity the card loses per second on its way out.
    ///
    /// A *rate*, not a duration, and nothing animates it — the card is simply
    /// worth less each tick. Which is the only way it can be set without also
    /// setting how fast the card travels: an animation attached here would
    /// govern the offset beside it, and that is what kept happening.
    static let fadeRate: Double = 4

    /// How much faster the word goes than the card, when it is not riding out.
    static let wordHaste: Double = 2.8

    /// Whether the word leaves with the shape or goes first.
    ///
    /// It goes first. The word is the message and the shape is the envelope —
    /// once the message has been read there is no reason to keep showing it,
    /// and a name still legible halfway across the board is a name competing
    /// with the move underneath it.
    static let wordsRideOut = false

    // ── The streaks passing through it ────────────────────────────────
    //
    // The card's tunnel is settled and its numbers are written down; these are
    // the ones still being looked at, so they are the ones on the bench.

    /// How bright the streaks are. Zero turns them off.
    static var warp: Double { defaultWarp }

    /// How thick a streak is.
    static var thickness: CGFloat { CGFloat(defaultThickness) }

    /// How long and how fast, as shares of the shape's own length.
    static var streakLength: CGFloat { CGFloat(defaultStreakLength) }

    static var streakSpeed: CGFloat { CGFloat(defaultStreakSpeed) }

    static let defaultWarp: Double = 0.66
    static let defaultThickness: Double = 1
    static let defaultStreakLength: Double = 0.15
    static let defaultStreakSpeed: Double = 2
}
