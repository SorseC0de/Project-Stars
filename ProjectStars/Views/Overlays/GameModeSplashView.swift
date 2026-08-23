//
//  GameModeSplashView.swift
//  Project Stars
//
//  The title card a round opens with.
//

import SwiftUI

/// Two slanted bars that cross the screen, meet in the middle to name the mode,
/// and carry on out the other side.
///
/// ## The move
///
/// The upper bar travels right to left, the lower one left to right. They are
/// the same shape, so as they pass they line up into a single Z — one diagonal
/// running through the middle of the screen — and that is the moment the card
/// exists. They settle a little past centre, each overshooting the other's
/// side, hold while the name is read, then continue the way they were already
/// going. Nothing reverses: they arrive and they leave.
///
/// ## Why it animates itself
///
/// No `TimelineView`. The card has three moments — arrive, hold, leave — and
/// SwiftUI can interpolate between them without anything being woken sixty
/// times a second to be told the bars are still where they were. A title card
/// that costs frames while the board behind it is loading is the wrong trade,
/// and this game has just paid for one of those.
struct GameModeSplashView: View {

    let mode: GameMode

    /// Raised when the player presses Start. The bars leave on it.
    let isLeaving: Bool

    /// Told once the bars have stopped, so the panel knows it may move.
    let onLanded: () -> Void

    /// Called once the bars are gone. The card removes itself.
    let onFinished: () -> Void

    @State private var stage: Stage = .offstage

    /// Where the bars are.
    ///
    /// Three positions, not an animation curve — the whole sequence is these in
    /// order, and each leg carries its own timing.
    private enum Stage {
        /// Waiting off screen, each on the side it enters from.
        case offstage

        /// Crossed and settled, forming the Z.
        case gathered

        /// Gone out the far side, still travelling the way they came in.
        case parted
    }

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let bar = ModeCardStyle.bar(across: width)

            ZStack {
                slat(.upper, bar: bar, width: width)
                    .offset(y: -bar.height / 2)

                slat(.lower, bar: bar, width: width)
                    .offset(y: bar.height / 2)

                // **Both words over both bars.**
                //
                // Carried by the bar each sits on, the name went under the lower
                // bar the moment that bar arrived — the card is two overlapping
                // shapes, and anything belonging to the one behind is behind
                // them both. The words are the message; nothing in the card
                // should ever be in front of them.
                title(on: bar)
                    .offset(y: -bar.height / 2 + ModeCardStyle.titleDrop * bar.height)

                blurb(on: bar)
                    .offset(y: bar.height / 2 + ModeCardStyle.blurbDrop * bar.height)
            }
            .frame(width: width, height: geometry.size.height)
        }
        .allowsHitTesting(false)
        .task { await arrive() }
        .task(id: isLeaving) {
            guard isLeaving else { return }
            await leave()
        }
    }

    // MARK: - The bars

    /// Which of the two, and with it which way it travels and which end fades.
    enum Slat {
        case upper, lower

        /// Which way the bar is going: the upper one leading to trailing, the
        /// lower one the other way.
        var heading: CGFloat { self == .upper ? 1 : -1 }

        /// Which side of the card the bar belongs to.
        ///
        /// **Not the same question as `heading`, though it was.** One sign used
        /// to answer both, which is why reversing the travel also mirrored where
        /// the bars sat, which end their length was added to, and which end
        /// faded — four changes from one, when only the first was wanted.
        ///
        /// A bar now enters from the side it leans away from, drifts to rest
        /// just past centre, and carries on out the far side. It passes
        /// *through* the card rather than arriving at it, and the composition
        /// it passes through is the one that was drawn.
        var outward: CGFloat { self == .upper ? -1 : 1 }
    }

    /// One bar, at its current place along its own line of travel.
    ///
    /// It fades out at its **outer** edge — leading for the upper bar, trailing
    /// for the lower — so the card has no hard end where it runs off toward the
    /// screen's edge, while the inner ends stay solid and hold the Z.
    private func slat(_ slat: Slat, bar: ModeCardStyle.Bar, width: CGFloat) -> some View {
        Parallelogram(lean: ModeCardStyle.lean)
            .fill(ModeCardStyle.taper(towards: slat))
            .frame(width: bar.width, height: bar.height)
            // Streaks running the way the bar is headed, cut to the bar's own
            // shape *and* its own fade — masked by the same tapered fill, so
            // they thin out at the tip exactly as the bar does rather than
            // stopping at a hard edge inside it.
            .overlay {
                WarpStreaks(slat: slat, bar: bar)
                    .mask {
                        Parallelogram(lean: ModeCardStyle.lean)
                            .fill(ModeCardStyle.taper(towards: slat))
                            .frame(width: bar.width, height: bar.height)
                    }
            }
            // **Two different moves, both outward.**
            //
            // `length` has already gone into `bar.width`, and a frame grows from
            // its middle — so half of it has to be pushed back out, or the bar
            // gets longer at the seam as well as at the tip. The inner end is
            // what holds the Z, and it must not move.
            //
            // `spread` moves the bar without resizing it: the two slide apart
            // along their own headings, which is a different picture from either
            // of them being longer.
            .offset(x: travel(slat, width: width, bar: bar)
                + slat.outward * (ModeCardStyle.length + ModeCardStyle.spread)
                * bar.height / 2)
    }

    /// How far this bar is from centre right now.
    ///
    /// One function for both bars and all three moments, because the two are the
    /// same movement mirrored — anything that made them separate journeys would
    /// need keeping in agreement, and they are only ever a Z when they agree.
    private func travel(_ slat: Slat, width: CGFloat, bar: ModeCardStyle.Bar) -> CGFloat {
        // Half a screen plus the whole bar, so however far it has been widened
        // it still waits and leaves completely out of sight.
        let away = width / 2 + bar.width + ModeCardStyle.spread * bar.height
        let settled = ModeCardStyle.overshoot * bar.height

        return switch stage {
        // Where it comes from and where it goes: the line of travel.
        case .offstage: -slat.heading * away
        case .parted: slat.heading * away
        // Where it rests: its own side of the card.
        case .gathered: slat.outward * settled
        }
    }

    // MARK: - The words

    /// The mode's name, sitting across the join.
    ///
    /// Straddling the seam rather than centred in the upper bar: the two bars
    /// read as one card while they overlap, and a title that respects the seam
    /// draws attention back to the fact that they are two.
    private func title(on bar: ModeCardStyle.Bar) -> some View {
        Text(mode.title)
            .font(ModeCardStyle.titleFont(ModeCardStyle.titleSize * bar.height))
            .tracking(ModeCardStyle.titleTracking * bar.height)
            // The tracking is applied after the last letter too, which walks the
            // whole line left of centre by half a gap.
            .padding(.leading, ModeCardStyle.titleTracking * bar.height)
            .foregroundStyle(ModeCardStyle.ink)
            .lineLimit(1)
            .minimumScaleFactor(ModeCardStyle.textSqueeze)
            .frame(maxWidth: ModeCardStyle.textWidth * bar.height)
            .scaleEffect(said)
            .opacity(said)
            // Its own spring, not the bars' easing. The words do not travel
            // with the card — they arrive on it — so they get a curve that
            // overshoots and settles rather than one built for a slide.
            .animation(ModeCardStyle.pop, value: said)
    }

    /// The one-line description, under the name on the lower bar.
    private func blurb(on bar: ModeCardStyle.Bar) -> some View {
        Text(mode.blurb)
            .font(ModeCardStyle.blurbFont(ModeCardStyle.blurbSize * bar.height))
            .foregroundStyle(ModeCardStyle.ink)
            .lineLimit(1)
            .minimumScaleFactor(ModeCardStyle.textSqueeze)
            .frame(maxWidth: ModeCardStyle.textWidth * bar.height)
            .scaleEffect(said)
            .opacity(said)
            // Its own spring, not the bars' easing. The words do not travel
            // with the card — they arrive on it — so they get a curve that
            // overshoots and settles rather than one built for a slide.
            .animation(ModeCardStyle.pop, value: said)
    }

    /// Whether the words are showing.
    ///
    /// They belong to the gathered moment alone. Carried in on a bar they would
    /// arrive skewed and leave skewed, and the point of the card is the instant
    /// the two bars are one thing.
    private var said: Double { stage == .gathered ? 1 : 0 }

    // MARK: - The sequence

    /// Arrives, and stays.
    ///
    /// The card used to time its own exit. It does not any more: it is the thing
    /// a run opens with, and a run opens when the player says so — see
    /// `isLeaving`, which the Start button raises.
    private func arrive() async {
        withAnimation(.easeOut(duration: ModeCardStyle.arrival)) { stage = .gathered }
        await sleep(ModeCardStyle.arrival)
        onLanded()
    }

    /// Leaves, and reports that it has gone.
    private func leave() async {
        withAnimation(.easeIn(duration: ModeCardStyle.departure)) { stage = .parted }
        await sleep(ModeCardStyle.departure)
        onFinished()
    }

    private func sleep(_ seconds: Double) async {
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
}

// MARK: - The shape

/// A rectangle with its top edge pushed right.
///
/// `lean` is the shift as a share of the height, so the slant holds its angle
/// whatever the bar is scaled to — a fixed number of points would stand up
/// straighter on a tall bar and lie flatter on a short one, and the two bars
/// only line up into a Z while their slants match exactly.
struct Parallelogram: Shape {

    var lean: CGFloat

    func path(in rect: CGRect) -> Path {
        let shift = rect.height * lean
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + shift, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - shift, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Measurements

/// Everything about the card's proportions, in shares of the screen's width.
///
/// **Width, not height.** The card is a horizontal move across a shape whose
/// slant is set by its own height, so every part of it has to scale together or
/// the Z stops meeting. Tied to height instead, the same card would be a stripe
/// on a short screen and a slab on a tall one.
@MainActor
enum ModeCardStyle {

    /// The face of both bars.
    ///
    /// **Not from the palette.** The card is a systems-level thing rather than
    /// part of the world, so it does not answer to the world's colours — and
    /// the palette's near-blacks are close enough to Astra's night sky that the
    /// bars sank into it.
    static let face = Color.black.opacity(faceOpacity)

    /// How solid the bars ever get. Just short of opaque, so the board is
    /// always faintly there behind them rather than cut out of the screen.
    static let faceOpacity: Double = 0.90

    /// One bar's fill: solid at its inner end, gone at its outer one.
    ///
    /// **Four stops, two to a colour** — where the clear run ends, and where the
    /// black run begins. Between them is the ramp; outside them the bar is
    /// simply one colour or the other. One stop each was a fade that started at
    /// the very tip whether or not it should, with no way to hold the end fully
    /// clear before it began.
    static func taper(towards slat: GameModeSplashView.Slat) -> LinearGradient {
        // Ordered whatever the two knobs are set to. A gradient whose stops run
        // backwards does not warn — it draws something else.
        let from = min(fadeFrom, fadeTo)
        let to = max(fadeFrom, fadeTo)

        let stops = [
            Gradient.Stop(color: .clear, location: 0),
            Gradient.Stop(color: .clear, location: from),
            Gradient.Stop(color: face, location: to),
            Gradient.Stop(color: face, location: 1),
        ]

        // Drawn from the fading end inward, so `fade` always reads as "how far
        // in from the outer edge", whichever bar is asking.
        return LinearGradient(
            gradient: Gradient(stops: stops),
            startPoint: slat == .upper ? .leading : .trailing,
            endPoint: slat == .upper ? .trailing : .leading
        )
    }

    // ── The streaks ───────────────────────────────────────────────────

    /// How bright the warp streaks are. Zero turns them off entirely.
    static var warp: Double {
        #if DEBUG
        ModeCardTuning.shared.warp
        #else
        defaultWarp
        #endif
    }

    static let defaultWarp: Double = 0.22

    /// How many streaks are in flight at once.
    static let warpCount = 34

    /// A streak's length and speed, as shares of the bar's own length — and how
    /// short and slow the meekest of them is allowed to be, as a share of the
    /// longest and fastest. A spread is what makes a field read as depth; all
    /// one length and one speed reads as a moving pattern.
    static let warpLength: CGFloat = 0.30
    static let warpSpeed: CGFloat = 0.55
    static let warpShortest: Double = 0.18
    static let warpSlowest: Double = 0.35

    /// How faint the dimmest streak is, and how thick any of them are.
    static let warpFaintest: Double = 0.15
    static let warpThickness: CGFloat = 1.5

    /// The curve the words arrive on, and leave on.
    ///
    /// Built from its own three knobs rather than shared with the bars: the
    /// words do not travel with the card, they land on it, and the two want
    /// different shapes.
    static var pop: Animation {
        .spring(response: textResponse, dampingFraction: textBounce)
        .delay(textDelay)
    }

    /// The words on them.
    static let ink = Palette.textPrimary

    /// Horizontal shift of a bar's top edge, as a share of its height.
    static let lean: CGFloat = 0.97

    /// One bar's size for a given screen width.
    static func bar(across width: CGFloat) -> Bar {
        let height = barHeight * width
        return Bar(width: height * (CGFloat(barAspect) + length), height: height)
    }

    struct Bar {
        let width: CGFloat
        let height: CGFloat
    }

    /// The bar's thickness, as a share of the screen's width.
    ///
    /// **The one number that sizes the card.** Everything below is a share of
    /// *this* rather than of the screen, so the whole thing grows and shrinks
    /// together and the drawing's proportions survive being moved to a screen
    /// shaped nothing like the one it was drawn on.
    ///
    /// It is larger than the sequence suggests on purpose. The card was drawn
    /// across a 16:9 frame, where a bar a tenth of the width tall is a bold
    /// band; the same share of a phone's width is a badge adrift in the middle
    /// of a tall screen with a caption too small to read. The proportions of the
    /// card are the drawing's; how much of the screen it takes is the screen's.
    private static let barHeight: CGFloat = 0.175

    /// How much longer than it is thick a bar is, straight off the sequence.
    private static let barAspect: Double = 5.18

    /// How much longer each bar is, in bar-thicknesses. Negative shortens it.
    ///
    /// All of it is added at the outer end — the end that fades — because the
    /// inner end is the seam the two bars share, and a bar that grows at the
    /// seam pushes the Z apart instead of reaching further across the screen.
    static var length: CGFloat {
        #if DEBUG
        CGFloat(ModeCardTuning.shared.length)
        #else
        CGFloat(defaultLength)
        #endif
    }

    /// How much further apart the two bars sit, in bar-thicknesses.
    ///
    /// A move, not a resize: each bar goes half of this along its own heading,
    /// so the pair opens up while both stay exactly as long as they were.
    static var spread: CGFloat {
        #if DEBUG
        CGFloat(ModeCardTuning.shared.spread)
        #else
        CGFloat(defaultSpread)
        #endif
    }

    /// Where the fully-clear run ends, as a share of a bar's length in from its
    /// outer edge. `0` starts the ramp at the very tip.
    static var fadeFrom: CGFloat {
        #if DEBUG
        CGFloat(ModeCardTuning.shared.fadeFrom)
        #else
        CGFloat(defaultFadeFrom)
        #endif
    }

    /// Where the ramp reaches full black, measured the same way.
    static var fadeTo: CGFloat {
        #if DEBUG
        CGFloat(ModeCardTuning.shared.fadeTo)
        #else
        CGFloat(defaultFadeTo)
        #endif
    }

    /// The length that was tuned, and a tenth of the whole bar on top of it.
    ///
    /// Written as the sum rather than the total so both halves stay legible:
    /// the number that was arrived at by looking, and the widening asked for
    /// afterwards. Outward, like the knob — see `length`.
    static let defaultLength: Double = tunedLength + (barAspect + tunedLength) * 0.10

    private static let tunedLength: Double = 2.0
    static let defaultSpread: Double = -0.30
    static let defaultFadeFrom: Double = 0.25
    static let defaultFadeTo: Double = 0.50

    /// How far each bar settles past centre, into the other's side.
    ///
    /// This is what makes it a Z rather than a stack: dead centre, the two would
    /// sit one directly above the other and the slants would read as a single
    /// leaning block.
    static let overshoot: CGFloat = 0.24

    /// The face the mode's name is set in.
    ///
    /// A function rather than a size, so swapping the whole card onto a drawn
    /// face is this line and nothing else — `.custom("YourFace", size: size)`.
    /// The system's compressed black is a stand-in for the squared-off display
    /// lettering in the sequence, and stand-ins are worth being easy to replace.
    static func titleFont(_ size: CGFloat) -> Font {
        .system(size: size, weight: .black).width(.compressed)
    }

    /// The face the description is set in. Same idea.
    static func blurbFont(_ size: CGFloat) -> Font {
        .system(size: size, weight: .medium)
    }

    /// The name's size, and the air between its letters.
    static let titleSize: CGFloat = 0.63
    static let titleTracking: CGFloat = 0.046

    /// Where the name sits, measured down from the upper bar's middle.
    ///
    /// It lands very nearly on the seam, which is the point — see `title`.
    static let titleDrop: CGFloat = 0.45

    /// The description's size and its place under the name.
    static let blurbSize: CGFloat = 0.155
    static let blurbDrop: CGFloat = 0.03

    /// The widest either line may be before it is squeezed to fit.
    ///
    /// A bar is not as wide as it looks — the slant eats a bar's height off each
    /// end — and a mode with a longer name than SURVIVAL should lose a little
    /// size rather than hang out over the edge of the card carrying it.
    static let textWidth: CGFloat = 3.9
    static let textSqueeze: CGFloat = 0.6

    // ── The shapes' timing ────────────────────────────────────────────
    //
    // How long the bars take to arrive and how long they take to leave. There
    // is no third number: the card is held until the player presses Start, and
    // a duration for that would be a duration for how long somebody takes to
    // decide.

    static var arrival: Double {
        #if DEBUG
        ModeCardTuning.shared.arrival
        #else
        defaultArrival
        #endif
    }

    static var departure: Double {
        #if DEBUG
        ModeCardTuning.shared.departure
        #else
        defaultDeparture
        #endif
    }

    static let defaultArrival: Double = 0.30
    static let defaultDeparture: Double = 0.30

    // ── The words' timing ─────────────────────────────────────────────
    //
    // Separate on purpose. The words can wait for the bars to settle, or beat
    // them there, without either being re-timed to suit the other.

    /// How long after the bars start moving the words begin.
    static var textDelay: Double {
        #if DEBUG
        ModeCardTuning.shared.textDelay
        #else
        defaultTextDelay
        #endif
    }

    /// The spring's period — smaller is snappier.
    static var textResponse: Double {
        #if DEBUG
        ModeCardTuning.shared.textResponse
        #else
        defaultTextResponse
        #endif
    }

    /// How much it overshoots. Below 1 springs past and settles back; at 1 it
    /// arrives without any overshoot at all.
    static var textBounce: Double {
        #if DEBUG
        ModeCardTuning.shared.textBounce
        #else
        defaultTextBounce
        #endif
    }

    static let defaultTextDelay: Double = 0.15
    static let defaultTextResponse: Double = 0.35
    static let defaultTextBounce: Double = 0.50
}

// MARK: - The streaks

/// Light drawn past the bar in the direction it is travelling.
///
/// The look is the one every ship jumping to lightspeed has: thin streaks,
/// stretched along the direction of travel, at a spread of lengths, speeds and
/// brightnesses so the field reads as depth rather than as a moving pattern.
///
/// ## Why one canvas rather than a view per streak
///
/// Forty views each asking for a frame is forty timelines, which is the cost
/// that took a week out of this project to find. A `Canvas` has no children: it
/// is one view, one clock, and forty draw calls that never touch the view tree.
///
/// ## Why the randomness is arithmetic
///
/// Each streak's lane, length and speed come from a hash of its own index, so
/// they are scattered but *fixed* — the field looks the same every time the
/// card is shown, and nothing has to be stored between frames to keep it
/// stable. A real random number generator would need seeding, keeping and
/// restoring, and would make every showing subtly different for no gain.
private struct WarpStreaks: View {

    let slat: GameModeSplashView.Slat
    let bar: ModeCardStyle.Bar

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                guard ModeCardStyle.warp > 0 else { return }

                context.blendMode = .plusLighter
                let now = timeline.date.timeIntervalSinceReferenceDate

                for index in 0..<ModeCardStyle.warpCount {
                    let lane = scatter(index, 1)
                    let span = scatter(index, 2)
                    let pace = scatter(index, 3)
                    let glow = scatter(index, 4)

                    let length = size.width * ModeCardStyle.warpLength
                        * (ModeCardStyle.warpShortest + span)
                    let speed = size.width * ModeCardStyle.warpSpeed
                        * (ModeCardStyle.warpSlowest + pace)

                    // Wrapped over the bar's width plus one streak, so a streak
                    // leaves one end and returns at the other with no moment
                    // where it is half-drawn at both.
                    let run = size.width + length
                    let travelled = (now * speed + Double(index) * 97).truncatingRemainder(
                        dividingBy: run
                    )
                    // With the bar, not against it.
                    let x = slat.heading < 0 ? size.width - travelled : travelled - length

                    let y = lane * size.height
                    let streak = CGRect(
                        x: x, y: y - ModeCardStyle.warpThickness / 2,
                        width: length, height: ModeCardStyle.warpThickness
                    )

                    context.fill(
                        Capsule().path(in: streak),
                        with: .color(
                            .white.opacity(ModeCardStyle.warp * (ModeCardStyle.warpFaintest + glow))
                        )
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }

    /// A fixed number in `0..<1` for this streak and this question.
    ///
    /// The usual trick: take something irrational-looking, multiply, and keep
    /// the fraction. It is not a good random number and does not need to be —
    /// it needs to be *scattered* and *the same every time*.
    private func scatter(_ index: Int, _ question: Int) -> Double {
        let n = sin(Double(index) * 12.9898 + Double(question) * 78.233) * 43758.5453
        return n - n.rounded(.down)
    }
}
