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

    /// Asked to go away in place, because something newer wants the spot.
    var isShrinking = false

    /// Already sliding out, and past being asked to do anything else.
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

        /// Going away in place, because something newer arrived.
        case shrinking
    }

    var body: some View {
        let size = PromptStyle.size(reaching: reach)

        shape(size)
            .frame(width: size.width, height: size.height)
            .scaleEffect(stage == .shrinking ? 0 : 1, anchor: .center)
            .opacity(opacity)
            .offset(x: offset(size))
            .frame(maxWidth: .infinity, alignment: .leading)
            .allowsHitTesting(false)
            .task { await arrive() }
            .task(id: prompt.isShrinking) {
                guard prompt.isShrinking, stage != .leaving else { return }
                await shrink()
            }
    }

    // MARK: - The shape

    private func shape(_ size: CGSize) -> some View {
        face
            .overlay { streaks }
            .overlay { word(size) }
    }

    private var face: some View {
        Parallelogram(lean: ModeCardStyle.lean).fill(PromptStyle.taper)
    }

    /// Cut to the shape *and* its fade, so they thin out with the tail.
    private var streaks: some View {
        SideStreaks().mask { face }
    }

    private func word(_ size: CGSize) -> some View {
        Text(prompt.name.uppercased())
            .font(.system(
                size: size.height * PromptStyle.labelSize,
                weight: .heavy,
                design: .rounded
            ))
            .tracking(size.height * PromptStyle.labelTracking)
            .foregroundStyle(ModeCardStyle.ink)
            .lineLimit(1)
            .minimumScaleFactor(PromptStyle.labelSqueeze)
            .padding(.horizontal, size.height * ModeCardStyle.lean)
            .opacity(wordOpacity)
    }

    // MARK: - Where it is

    private func offset(_ size: CGSize) -> CGFloat {
        switch stage {
        // Its trailing edge at the counter's, which is what `reach` means.
        case .held, .shrinking: reach - size.width
        case .offstage: -size.width
        // Far enough that the shape itself is gone, though the fade will have
        // finished long before it gets there.
        case .leaving: reach + size.width
        }
    }

    private var opacity: Double {
        switch stage {
        case .offstage: 0
        case .held, .shrinking: 1
        case .leaving: 0
        }
    }

    /// Whether the word is still showing.
    ///
    /// **The A/B.** With `wordsRideOut` the word is part of the shape and leaves
    /// with it; without, it is gone the moment the shape commits to leaving and
    /// what slides away is a blank. See `ModeCardTuning.wordsRideOut`.
    private var wordOpacity: Double {
        guard stage == .leaving, !PromptStyle.wordsRideOut else { return 1 }
        return 0
    }

    // MARK: - What it does

    private func arrive() async {
        withAnimation(.easeOut(duration: PromptStyle.arrival)) { stage = .held }
        await sleep(PromptStyle.arrival + PromptStyle.hold)

        // Shrinking already, or gone: not this one's business any more.
        guard stage == .held else { return }

        onLeaving()
        withAnimation(.easeIn(duration: PromptStyle.departure)) { stage = .leaving }
        await sleep(PromptStyle.departure)
        onFinished()
    }

    private func shrink() async {
        withAnimation(.easeIn(duration: PromptStyle.shrink)) { stage = .shrinking }
        await sleep(PromptStyle.shrink)
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

    /// How tall it is against how far it flies.
    static let heightOfReach: CGFloat = 0.34

    /// How much of its length is the flat part, before the slant.
    static let widthOfReach: CGFloat = 0.96

    static func size(reaching reach: CGFloat) -> CGSize {
        CGSize(width: reach * widthOfReach, height: reach * heightOfReach)
    }

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

    /// The word inside it.
    static let labelSize: CGFloat = 0.36
    static let labelTracking: CGFloat = 0.02
    static let labelSqueeze: CGFloat = 0.5

    /// In, read, out — and the third way out, when something newer arrives.
    static let arrival: Double = 0.28
    static let hold: Double = 1.6
    static let departure: Double = 0.5
    static let shrink: Double = 0.18

    /// Whether the word leaves with the shape or goes first. The bench's A/B.
    static var wordsRideOut: Bool {
        #if DEBUG
        ModeCardTuning.shared.wordsRideOut
        #else
        true
        #endif
    }

    // ── The streaks passing through it ────────────────────────────────
    //
    // The card's tunnel is settled and its numbers are written down; these are
    // the ones still being looked at, so they are the ones on the bench.

    /// How bright the streaks are. Zero turns them off.
    static var warp: Double {
        #if DEBUG
        ModeCardTuning.shared.warp
        #else
        defaultWarp
        #endif
    }

    /// How thick a streak is.
    static var thickness: CGFloat {
        #if DEBUG
        CGFloat(ModeCardTuning.shared.thickness)
        #else
        CGFloat(defaultThickness)
        #endif
    }

    /// How long and how fast, as shares of the shape's own length.
    static var streakLength: CGFloat {
        #if DEBUG
        CGFloat(ModeCardTuning.shared.streakLength)
        #else
        CGFloat(defaultStreakLength)
        #endif
    }

    static var streakSpeed: CGFloat {
        #if DEBUG
        CGFloat(ModeCardTuning.shared.streakSpeed)
        #else
        CGFloat(defaultStreakSpeed)
        #endif
    }

    static let defaultWarp: Double = 0.66
    static let defaultThickness: Double = 3
    static let defaultStreakLength: Double = 0.30
    static let defaultStreakSpeed: Double = 0.55
}
