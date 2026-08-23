//
//  TurnCounterView.swift
//  Project Stars
//
//  How far you have got, in the corner of the sky.
//

import SwiftUI

/// The turn counter: a label, a plate, and however many numerals the number
/// needs.
///
/// ## How it is laid out
///
/// **One origin, and the numerals are the spine.** Every piece is placed in art
/// pixels from the counter's top-left, and the plate's right end and the cap are
/// measured from *where the numerals actually end* rather than from slots in a
/// row. That is what lets the number gain a place without anything having to be
/// re-found: `runRightArt` moves, and the end, the cap and the middle's width
/// all follow it.
///
/// An earlier version laid the pieces out in an `HStack` and corrected each with
/// its own offset. An offset moves a drawing without moving what comes after it,
/// so every piece had to be told the same correction and any one of them
/// disagreeing opened a gap in the plate.
struct TurnCounterView: View {

    /// The number to show.
    let turn: Int

    /// Whole-number pixel scale, from `PixelArtMetrics`.
    let scale: CGFloat

    // MARK: - Placement

    /// **The settled layout**, found on the bench 2026-08-19.
    ///
    /// Two kinds of number, and the distinction is the point: `plateLeftX`,
    /// `digitsX` and the `y` values are absolute, from the counter's origin.
    /// `rightHug` and `capHug` are relative to where the numerals end.
    private enum Place {
        static let plateLeftX: CGFloat = 19
        static let plateY: CGFloat = 6

        static let digitsX: CGFloat = 17
        static let digitsY: CGFloat = -3

        /// The plate's end, from the last numeral's right edge.
        static let rightHug: CGFloat = 5

        /// The cap, from the last numeral's bottom-right corner.
        static let capHug: CGFloat = -1
        static let capY: CGFloat = 7
    }

    /// The numerals share an outline with their neighbour — the overlap is how
    /// they were drawn, not a rounding error.
    static let shippedDigitGap: CGFloat = -1

    /// How much bigger the numerals are than everything around them.
    static let shippedDigitScale: CGFloat = 1.5

    /// **Two, and it grows on its own.** The layout follows the count, so
    /// starting narrow costs nothing and the counter earns its width.
    static let shippedLeastDigits = 2

    /// One numeral's ink, in art pixels — eight inside a sixteen pixel cell.
    private static let digitWidth: CGFloat = 8

    // MARK: - Flourish

    /// **The drawn turn-over.** See `TurnFlourish`.
    static let shippedFlourish: TurnFlourish = .roll

    private var flourish: TurnFlourish {
        #if DEBUG
        TurnCounterTuning.shared.flourish
        #else
        Self.shippedFlourish
        #endif
    }

    /// Every timing runs through here, so one bench knob paces all of them.
    private func paced(_ duration: TimeInterval) -> TimeInterval {
        #if DEBUG
        duration / Double(max(TurnCounterTuning.shared.speed, 0.05))
        #else
        duration
        #endif
    }

    private var leastDigits: Int {
        #if DEBUG
        TurnCounterTuning.shared.leastDigits
        #else
        Self.shippedLeastDigits
        #endif
    }

    private var baseY: CGFloat {
        #if DEBUG
        TurnCounterTuning.shared.baseY * scale
        #else
        0
        #endif
    }

    // MARK: - Animation state

    /// The numerals as they were last drawn, so a change can be told from a
    /// redraw. Only what actually changed animates.
    @State private var settled: [Int] = []

    /// Which positions are mid-flourish.
    @State private var leaping: Set<Int> = []

    /// 0 at rest, 1 at the extremity, for the styles that interpolate.
    @State private var lift: CGFloat = 0

    /// Which drawn frame is showing, for the styles that play the sheet.
    ///
    /// Stepped by its own task rather than read off `lift`: `withAnimation`
    /// interpolates *animatable modifiers*, and a state value read inside a
    /// conditional is not one — it arrives at its final value immediately.
    @State private var flipFrame: Int?

    /// True while the numerals should still be drawn as they were, for the
    /// styles that change the number out of sight.
    @State private var showsOld = false

    /// Which entry of `chargePalette` is showing.
    ///
    /// **Rest is the last entry, not the first.** Zero is the silhouette the
    /// charge cools into, so resting there meant picking the style painted the
    /// whole number yellow-green before anything had happened. The palette's
    /// final entry is what the art was drawn as, which is what "nothing is
    /// happening" should look like.
    @State private var chargeStage = TurnCounterView.restStage


    /// The cap's own travel for the charge, 0 out to 1 and back.
    ///
    /// Separate from `lift`, which the charge uses for the *drop* and which
    /// stays at 1 until the end — so a cap driven off it slid out and then
    /// snapped home when the animation reset. The cap has its own there-and-
    /// back because it is making room and then closing up again.
    @State private var capLift: CGFloat = 0

    /// True for the instant after the numeral lands.
    ///
    /// Wider and shorter, then back — the shape a thing makes when it arrives
    /// with weight. Mega Man's teleport-in does exactly this, and it is what
    /// separates *landed* from *appeared*.
    @State private var squashing = false

    /// The animation in flight, so a new one can cancel it. Turns land faster
    /// than a flourish takes, and blending a new rise into a running fall is
    /// what made numerals overshoot.
    @State private var arc: Task<Void, Never>?

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .topLeading) {
            // **Static, always.** The label was lit and then knocked, and both
            // times it pulled the eye off the number — which is the only thing
            // on this counter that changed. Labels hold still.
            piece(.turnLabel, x: 0, y: 0, width: cell * 2, tuned: .label)

            piece(.turnPlateLeft, x: plateLeftX, y: Place.plateY, tuned: .plateLeft)

            // Spans its two neighbours exactly, so it cannot fall short of the
            // end however wide the number gets.
            piece(
                .turnPlateMiddle,
                x: plateLeftX + cellArt, y: Place.plateY,
                width: max(plateRightX - (plateLeftX + cellArt), 0) * scale,
                tuned: .plateMiddle
            )

            piece(.turnPlateRight, x: plateRightX, y: Place.plateY, tuned: .plateRight)

            // **The numbers squash, and only the numbers.** The plate they sit
            // on and the word beside them are furniture; furniture does not
            // react to a numeral landing on it. Anchored on the run's own
            // baseline so the squash presses down onto the plate rather than
            // sliding the number about.
            ZStack(alignment: .topLeading) {
                ForEach(shown.indices, id: \.self) { index in
                    numeral(at: index)
                }

                // The numeral dropping in for the charge.
                //
                // **Mounted the whole time**, not inserted when its stage
                // starts: a view that appears part-way through its own
                // animation has nothing to animate *from*, so the drop arrived
                // as a jump. Opacity decides when it is seen.
                if flourish == .flash, let target = leaping.max() {
                    numeralFace(digits[safe: target] ?? 0, at: target)
                        .offset(y: -GameRules.turnChargeDrop * scale * (1 - lift))
                        // **While the silhouette is up**, which is stage zero.
                        // This still said stage two, from before the palette
                        // became a table — and stage two is now the `midnight`
                        // beat, long after the drop is over, so the numeral
                        // appeared already landed and never travelled.
                        .opacity(chargeStage == 0 ? 1 : 0)
                }
            }
            .animatedPaletteSwap(chargeSwaps)
            // **Given the counter's own box before it is scaled.**
            //
            // The numerals are placed with `offset`, and an offset does not
            // change a view's bounds — so this stack measured one cell wide
            // however far the number ran, and `squashAnchor`'s fraction landed
            // somewhere near the first numeral instead of the middle of the
            // run. Everything then stretched away from that point, which is the
            // squash appearing to go only right.
            .frame(
                width: (runRightArt + cellArt) * scale,
                height: cell * 2,
                alignment: .topLeading
            )
            .scaleEffect(
                x: squashing ? GameRules.turnChargeSquashX : 1,
                y: squashing ? GameRules.turnChargeSquashY : 1,
                anchor: squashOrigin
            )

            piece(
                .turnCap,
                x: runRightArt + Place.capHug + capShove / scale,
                y: Place.capY + baseY / scale,
                tuned: .cap
            )
        }
        .frame(
            width: (runRightArt + cellArt) * scale,
            height: cell * 2,
            alignment: .topLeading
        )
        .tuned(.whole, scale: scale)
        .allowsHitTesting(false)
        .onAppear { settled = digits }
        .onChange(of: turn) { _, _ in play() }
    }

    /// One numeral, with every drawn frame mounted behind it.
    ///
    /// **All ten views exist at once**, and only opacity picks between them.
    /// Swapping which `SpriteID` a single view draws changes its identity, and
    /// SwiftUI answers that by cross-fading — which is why the drawn turn played
    /// as a blur. Same arrangement as Aquarius' storm reels.
    private func numeral(at index: Int) -> some View {
        ZStack {
            numeralFace(shown[index], at: index)
                .opacity(rollFrame(at: index) == nil ? 1 : 0)

            ForEach(0..<GameRules.turnFlipFrames, id: \.self) { frame in
                piece(
                    .turnRoll(frame),
                    x: digitsX + CGFloat(index) * advanceArt,
                    y: Place.digitsY + baseY / scale,
                    width: digitCell,
                    height: digitCell,
                    tuned: .digits
                )
                .opacity(rollFrame(at: index) == frame ? 1 : 0)
            }
        }
        // The opacity switch is a **cut**. An eased one is the cross-fade
        // coming back by another door.
        .transaction { $0.animation = nil }
        .offset(digitOffset(at: index))
        .opacity(digitOpacity(at: index))
        .rotation3DEffect(
            .degrees(digitAngle(at: index)),
            axis: (x: 1, y: 0, z: 0),
            perspective: GameRules.turnRollPerspective
        )
    }

    private func numeralFace(_ value: Int, at index: Int) -> some View {
        piece(
            .digit(value),
            x: digitsX + CGFloat(index) * advanceArt,
            y: Place.digitsY + baseY / scale,
            width: digitCell,
            height: digitCell,
            tuned: .digits
        )
    }

    /// Where the squash presses from, as a fraction of the counter's box.
    ///
    /// **Measured against the same box the group is framed in.** The numerals
    /// are positioned with `offset`, so they contribute nothing to their
    /// container's bounds — the group is given the counter's own frame first,
    /// and this fraction is taken against exactly that.
    private var squashOrigin: UnitPoint {
        let box = runRightArt + cellArt
        let runMiddle = digitsX + (runRightArt - digitsX) / 2
        let baseline = Place.digitsY + cellArt * digitScale
        return UnitPoint(x: runMiddle / box, y: baseline / (cellArt * 2))
    }

    /// One sprite, placed in art pixels from the counter's own origin.
    private func piece(
        _ id: SpriteID,
        x: CGFloat,
        y: CGFloat,
        width: CGFloat? = nil,
        height: CGFloat? = nil,
        tuned adjust: TunedPiece
    ) -> some View {
        PixelSprite(id: id) { Color.clear }
            .frame(width: width ?? cell, height: height ?? cell)
            .offset(x: x * scale, y: y * scale)
            .tuned(adjust, scale: scale)
    }

    // MARK: - Geometry, all in art pixels
    //
    // `piece(x:y:)` multiplies by `scale`, so nothing handed to it may have been
    // scaled already — mixing the two units threw the numerals across the screen
    // once, because an advance already in points got scaled a second time.

    private var cell: CGFloat { CGFloat(GameRules.tilePixelSize) * scale }
    private var cellArt: CGFloat { CGFloat(GameRules.tilePixelSize) }

    private var gap: CGFloat { Self.shippedDigitGap }
    private var digitScale: CGFloat { Self.shippedDigitScale }
    private var digitCell: CGFloat { cell * digitScale }

    /// How far one numeral moves the next along.
    private var advanceArt: CGFloat { (Self.digitWidth + gap) * digitScale }

    private var digitsX: CGFloat { Place.digitsX }
    private var plateLeftX: CGFloat { Place.plateLeftX }

    /// The right edge of the numerals' **ink** — what the plate's end hugs.
    private var runRightArt: CGFloat {
        digitsX
            + CGFloat(max(shown.count - 1, 0)) * advanceArt
            + Self.digitWidth * digitScale
    }

    private var plateRightX: CGFloat { runRightArt + Place.rightHug }

    /// The number, padded to at least `leastDigits` places.
    private var digits: [Int] {
        let value = max(turn, 0)
        let written = value == 0 ? "0" : String(value)
        let padded = String(repeating: "0", count: max(leastDigits - written.count, 0))
            + written
        return padded.compactMap { $0.wholeNumberValue }
    }

    /// What is on screen right now — the old face while a style is hiding the
    /// change, the new one otherwise.
    private var shown: [Int] {
        showsOld && !settled.isEmpty ? settled : digits
    }

    // MARK: - What each style does

    /// How far through its landing the counter is, 0 to 1 to 0.
    ///
    /// Frame-derived for the styles that play drawn frames, so the motion and
    /// the art cannot drift apart.
    private var impactArc: CGFloat {
        if flourish == .flash { return capLift }
        if let frame = flipFrame {
            let last = CGFloat(max(GameRules.turnFlipFrames - 1, 1))
            return sin(.pi * CGFloat(frame) / last)
        }
        return lift
    }

    /// The cap, shoved aside as the numeral turns.
    ///
    /// **Every style.** The cap hugs the last numeral, so whenever that numeral
    /// is doing something the cap has to make room.
    private var capShove: CGFloat {
        guard !leaping.isEmpty else { return 0 }
        return Self.capJump * scale * impactArc
    }

    /// How far the cap is shoved, in art pixels. The bench overrides it.
    ///
    /// Read through here rather than off the bench directly — the bench does
    /// not exist in a shipped build, and a `#if DEBUG` around one expression
    /// inside a view body is how Release breaks while Debug looks fine.
    private static var capJump: CGFloat {
        #if DEBUG
        TurnCounterTuning.shared.capJump
        #else
        GameRules.turnCapShove
        #endif
    }

    /// Which drawn frame a numeral is showing, if any.
    private func rollFrame(at index: Int) -> Int? {
        switch flourish {
        case .roll, .slide:
            return leaping.contains(index) ? flipFrame : nil
        default:
            return nil
        }
    }

    /// A numeral's displacement, in points.
    private func digitOffset(at index: Int) -> CGSize {
        switch flourish {
        case .slide:
            // Everything after the first goes out of sight while the first one
            // turns, then comes back.
            guard index > 0, lift > 0 else { return .zero }
            return CGSize(width: -advanceArt * scale * CGFloat(index + 1) * lift, height: 0)
        default:
            return .zero
        }
    }

    /// How visible a numeral is.
    private func digitOpacity(at index: Int) -> Double {
        switch flourish {
        case .flicker:
            // `lift` is the blink itself — set with animations disabled, so
            // this is a cut rather than a fade.
            return leaping.contains(index) && lift > 0 ? 0 : 1
        case .slide:
            // **Transparent for a beat on the way back in.** The drawn frames
            // shrink the numeral's height, so they cannot cover a numeral
            // sliding underneath them — it would appear through the gap before
            // its turn.
            return index > 0 && lift > 0 ? 0 : 1
        default:
            return 1
        }
    }

    /// How far a numeral has turned, for the transform style.
    private func digitAngle(at index: Int) -> Double {
        guard flourish == .flip, leaping.contains(index) else { return 0 }
        return lift <= 0.5 ? -180 * lift : 180 * (1 - lift)
    }

    // MARK: - The charge

    /// Purple, magenta and cyan — the number cooling and coming back.
    private var chargedSwaps: [PaletteSwap] {
        [
            PaletteSwap(Palette.midnight, Palette.purple),
            PaletteSwap(Palette.sakura, Palette.magenta),
            PaletteSwap(Palette.yellowGreen, Palette.cyan),
        ]
    }

    /// All three tones to one, so the number reads as a solid shape.
    private var silhouetteSwaps: [PaletteSwap] {
        [
            PaletteSwap(Palette.midnight, Palette.purple),
            PaletteSwap(Palette.sakura, Palette.purple),
            PaletteSwap(Palette.yellowGreen, Palette.purple),
        ]
    }

    /// The charge's colours, in order.
    ///
    /// **A list, not a switch.** The sequence is the whole design here — cool,
    /// wash, spend, wash again, and let the inside come back before the outline
    /// does — and written as branches it was one edit away from losing a step,
    /// which is exactly what happened when the `midnight` beat went in.
    ///
    /// Each entry is outline, mid, light. `withAnimation` travels between
    /// consecutive entries; see `AnimatablePaletteSwap`.
    /// The entry that means "nothing is happening" — the drawn colours.
    static var restStage: Int { chargePalette.count - 1 }

    private static let chargePalette: [(Color, Color, Color)] = [
        // Cooled to a shape. The new numeral falls into this.
        (Palette.yellowGreen, Palette.yellowGreen, Palette.yellowGreen),
        // It lands.
        (Palette.blush, Palette.blush, Palette.blush),
        // Spent.
        (Palette.midnight, Palette.midnight, Palette.midnight),
        // And lit again from there.
        (Palette.blush, Palette.blush, Palette.blush),
        // The inside returns first; the outline holds the wash a beat longer.
        (Palette.blush, Palette.yellowGreen, Palette.yellowGreen),
        // What it was drawn as.
        (Palette.midnight, Palette.sakura, Palette.yellowGreen),
    ]

    /// Which entry of `chargePalette` is showing, and what the squish does to
    /// it.
    ///
    /// A full silhouette brightens while it is compressed — `yellowGreen` to
    /// `yellow`, `blush` to `sakura`. A shape holding still is a shape; one
    /// that lifts a tone as it is squeezed is a shape being hit.
    private var chargeSwaps: [PaletteSwap] {
        guard flourish == .flash else { return [] }

        let entry = Self.chargePalette[
            min(max(chargeStage, 0), Self.chargePalette.count - 1)
        ]
        var (outline, mid, light) = entry

        let isSilhouette = outline == mid && mid == light
        if squashing, isSilhouette {
            let lifted = outline == Palette.blush ? Palette.sakura : Palette.yellow
            outline = lifted
            mid = lifted
            light = lifted
        }

        return [
            PaletteSwap(Palette.midnight, outline),
            PaletteSwap(Palette.sakura, mid),
            PaletteSwap(Palette.yellowGreen, light),
        ]
    }

    // MARK: - Playing

    private func play() {
        let now = digits
        let changed = Set(
            now.indices.filter { index in
                index >= settled.count || settled[index] != now[index]
            }
        )
        guard !changed.isEmpty else { settled = now; return }

        arc?.cancel()
        var immediate = Transaction()
        immediate.disablesAnimations = true
        withTransaction(immediate) {
            lift = 0
            capLift = 0
            flipFrame = nil
            showsOld = false
            chargeStage = Self.restStage
            squashing = false
        }
        leaping = changed

        switch flourish {
        case .roll:
            settled = now
            arc = playFrames(from: now, immediate: immediate)

        case .slide:
            settled = now
            arc = playSlide(from: now, immediate: immediate)

        case .flip:
            showsOld = true
            let half = paced(GameRules.turnRollDuration) / 2
            withAnimation(.easeIn(duration: half)) { lift = 0.5 }
            arc = Task { @MainActor in
                try? await Task.sleep(for: .seconds(half))
                guard !Task.isCancelled else { return }
                withTransaction(immediate) { settled = now; showsOld = false }
                withAnimation(.easeOut(duration: half)) { lift = 1 }
                try? await Task.sleep(for: .seconds(half))
                guard !Task.isCancelled else { return }
                withTransaction(immediate) { lift = 0; leaping = [] }
            }

        case .flicker:
            settled = now
            arc = Task { @MainActor in
                let beat = paced(GameRules.turnFlickerDuration)
                    / Double(GameRules.turnFlickerBlinks * 2)
                for blink in 0..<(GameRules.turnFlickerBlinks * 2) {
                    guard !Task.isCancelled else { return }
                    withTransaction(immediate) { lift = blink.isMultiple(of: 2) ? 1 : 0 }
                    try? await Task.sleep(for: .seconds(beat))
                }
                guard !Task.isCancelled else { return }
                withTransaction(immediate) { lift = 0; leaping = [] }
            }

        case .flash:
            showsOld = true
            arc = playCharge(from: now, immediate: immediate)
        }
    }

    /// The drawn frames, one at a time, swapping the face at the midpoint while
    /// the middle frames hide it.
    private func playFrames(
        from now: [Int],
        immediate: Transaction,
        thenSlideBack: Bool = false
    ) -> Task<Void, Never> {
        Task { @MainActor in
            let frames = GameRules.turnFlipFrames
            let hold = paced(GameRules.turnFlipDuration) / Double(frames)

            for frame in 0..<frames {
                guard !Task.isCancelled else { return }
                withTransaction(immediate) { flipFrame = frame }
                if frame == frames / 2 {
                    withTransaction(immediate) { settled = now; showsOld = false }
                }
                try? await Task.sleep(for: .seconds(hold))
            }

            guard !Task.isCancelled else { return }
            withTransaction(immediate) { flipFrame = nil }

            if thenSlideBack {
                withAnimation(.easeOut(duration: paced(GameRules.turnSlideBack))) {
                    lift = 0
                }
                try? await Task.sleep(for: .seconds(paced(GameRules.turnSlideBack)))
            }

            guard !Task.isCancelled else { return }
            withTransaction(immediate) { leaping = [] }
        }
    }

    /// Out, turn, back: the others clear the way, the first one rolls, and they
    /// return.
    private func playSlide(from now: [Int], immediate: Transaction) -> Task<Void, Never> {
        withAnimation(.easeIn(duration: paced(GameRules.turnSlideOut))) { lift = 1 }
        return Task { @MainActor in
            try? await Task.sleep(for: .seconds(paced(GameRules.turnSlideOut)))
            guard !Task.isCancelled else { return }
            _ = await playFrames(from: now, immediate: immediate, thenSlideBack: true).value
        }
    }

    /// Cool to a silhouette, drop the new numeral in, and warm back up.
    ///
    /// Walks `chargePalette` a step at a time, animating between entries. The
    /// numeral falls during the first entry and lands on the second, which is
    /// where the squash is.
    private func playCharge(from now: [Int], immediate: Transaction) -> Task<Void, Never> {
        Task { @MainActor in
            // Its own duration rather than a share of the drawn turn's: the
            // charge is a piece of theatre and the turn is a mechanism, and
            // pacing the first off the second made it flash past.
            let stage = paced(GameRules.turnChargeStage)

            withAnimation(.easeInOut(duration: stage)) { chargeStage = 0 }
            try? await Task.sleep(for: .seconds(stage))
            guard !Task.isCancelled else { return }

            // The drop, eased out so it arrives rather than accelerates.
            withTransaction(immediate) { lift = 0 }
            withAnimation(.easeInOut(duration: stage)) { capLift = 1 }
            withAnimation(.easeOut(duration: stage)) { lift = 1 }
            try? await Task.sleep(for: .seconds(stage))
            guard !Task.isCancelled else { return }

            // Touchdown: the face becomes the new one behind the silhouette,
            // the shape squashes, and the wash comes up.
            withTransaction(immediate) {
                settled = now
                showsOld = false
                squashing = true
            }
            withAnimation(.easeOut(duration: stage)) { chargeStage = 1 }
            withAnimation(.easeOut(duration: paced(GameRules.turnChargeSquash))) {
                squashing = false
            }
            try? await Task.sleep(for: .seconds(stage))

            // And the rest of the table, one beat each.
            for step in 2..<Self.chargePalette.count {
                guard !Task.isCancelled else { return }
                withAnimation(.easeInOut(duration: stage)) { chargeStage = step }
                if step == Self.chargePalette.count - 1 {
                    withAnimation(.easeInOut(duration: stage)) { capLift = 0 }
                }
                try? await Task.sleep(for: .seconds(stage))
            }

            guard !Task.isCancelled else { return }
            withTransaction(immediate) {
                lift = 0
                capLift = 0
                squashing = false
                leaping = []
            }
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - TurnFlourish

/// How the counter reacts to its own number changing.
///
/// A named set rather than a hard-coded animation, because this is headed for
/// the settings screen: the player picks one, and the default is whichever reads
/// best.
enum TurnFlourish: String, CaseIterable, Identifiable, Codable {

    /// **The drawn turn-over**, nine frames off the sheet. The default.
    ///
    /// Named for what it is: the art turns the numeral over like a wheel. Only
    /// the numeral and the cap move — no colour anywhere.
    case roll

    /// The same idea as a `rotation3DEffect`.
    ///
    /// Kept because it is a different motion rather than a worse one: a
    /// transform is evenly weighted, so it reads like a paper calendar page
    /// going over rather than a wheel turning.
    case flip

    /// The changing numeral blinks out and back, holding each state.
    case flicker

    /// The numerals after the first clear out of sight, the first one rolls,
    /// and they slide back.
    case slide

    /// The number cools to a purple silhouette, the new numeral drops into it
    /// from above, and the colour comes back the way it left.
    case flash

    var id: String { rawValue }

    var title: String {
        switch self {
        case .roll: "roll"
        case .flip: "flip"
        case .flicker: "flicker"
        case .slide: "slide"
        case .flash: "flash"
        }
    }
}

#if DEBUG
typealias TunedPiece = TurnCounterTuning.Piece
#else
enum TunedPiece {
    case whole, label, plateLeft, plateMiddle, plateRight, digits, cap
}
#endif

private extension View {
    /// The bench's per-piece nudge, in art pixels.
    @ViewBuilder
    func tuned(_ piece: TunedPiece, scale: CGFloat) -> some View {
        #if DEBUG
        let adjust = TurnCounterTuning.shared[piece]
        scaleEffect(CGFloat(adjust.scale))
            .offset(x: adjust.x * scale, y: adjust.y * scale)
        #else
        self
        #endif
    }
}
