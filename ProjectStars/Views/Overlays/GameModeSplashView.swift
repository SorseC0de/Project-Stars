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

    /// What the card says, in capitals across the seam.
    let title: String

    /// The line under it.
    let subtitle: String

    /// The colour the **name** is drawn in. Red says the run is over; white says
    /// it is beginning. The card is the same card either way — a thing
    /// announcing itself — and only its words change.
    var ink: Color = ModeCardStyle.ink

    /// And the colour of the line under it, which stays the card's own.
    ///
    /// Separate from `ink` because the two lines are not saying the same thing.
    /// The name is the announcement and takes the announcement's colour; the
    /// subtitle is the explanation, and an explanation in alarm red reads as a
    /// second alarm. On a game over that would be the reason you died shouting
    /// as loudly as the fact that you did.
    var subtitleInk: Color = ModeCardStyle.ink

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
                bars(bar: bar, width: width)

                // **The view through the card, not a pattern on it.**
                //
                // Drawn once across the whole assembly and masked by it, rather
                // than once per bar: the wormhole has a single vanishing point,
                // and a vanishing point per bar is two tunnels seen at once.
                // The mask is the bars' own tapered fill, so the tunnel thins
                // out at their tips exactly as they do.
                WormholeField()
                    .frame(width: width, height: bar.height * 2)
                    // **Last, not first.**
                    //
                    // The card arrives, the name lands, and only then does the
                    // tunnel come up behind it. All three at once is three
                    // things starting in the same instant and no order to read
                    // them in.
                    .opacity(said)
                    .animation(
                        stage == .gathered
                            ? .easeIn(duration: ModeCardStyle.warpFade)
                                .delay(ModeCardStyle.warpDawn)
                            : .easeOut(duration: ModeCardStyle.departure),
                        value: said
                    )
                    .mask { bars(bar: bar, width: width) }

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

    /// The pair, in their places.
    ///
    /// One view rather than two statements, because it is used twice — as the
    /// card itself, and as the shape the wormhole is seen through. Written out
    /// twice they would drift apart, and the tunnel would show through
    /// somewhere the bars are not.
    private func bars(bar: ModeCardStyle.Bar, width: CGFloat) -> some View {
        ZStack {
            slat(.upper, bar: bar, width: width)
                .offset(y: -bar.height / 2)

            slat(.lower, bar: bar, width: width)
                .offset(y: bar.height / 2)
        }
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
        Text(title)
            .font(ModeCardStyle.titleFont(ModeCardStyle.titleSize * bar.height))
            .tracking(ModeCardStyle.titleTracking * bar.height)
            // The tracking is applied after the last letter too, which walks the
            // whole line left of centre by half a gap.
            .padding(.leading, ModeCardStyle.titleTracking * bar.height)
            .foregroundStyle(ink)
            //.foregroundStyle(.ultraThinMaterial)
            //.environment(\.colorScheme, .light)
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
        Text(subtitle)
            .font(ModeCardStyle.blurbFont(ModeCardStyle.blurbSize * bar.height))
            .foregroundStyle(subtitleInk)
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

    /// How bright the tunnel is.
    ///
    /// **Settled, and its own.** This read the bench's `warp` until that knob
    /// was handed to the passive prompt — after which the card's tunnel was
    /// being dimmed by a slider that had stopped being about the card at all.
    /// A shared knob is fine right up until one of the two things it drives
    /// moves out.
    static let warp: Double = 0.66

    /// How many streaks are in flight at once.
    static let warpCount = 34

    /// A streak's length and speed, as shares of the bar's own length — and how
    /// short and slow the meekest of them is allowed to be, as a share of the
    /// longest and fastest. A spread is what makes a field read as depth; all
    /// one length and one speed reads as a moving pattern.

    static let warpShortest: Double = 0.18
    static let warpSlowest: Double = 0.35

    /// How faint the dimmest streak is.
    static let warpFaintest: Double = 0.15

    /// How thick a capsule is at the rim. Settled, and the card's own — see
    /// `warp` for what sharing one with the prompt cost.
    static var thickness: CGFloat { CGFloat(defaultThickness) }

    /// The hole at the middle of the tunnel, as a share of the reach.
    ///
    /// Streaks begin here rather than at a point. Everything converging on one
    /// pixel reads as an explosion; a small clear eye with the light starting
    /// around it reads as distance.
    static var core: Double { defaultCore }

    /// How many of the tunnel's marks are stars rather than streaks.
    static var stars: Double { defaultStars }

    /// How the tunnel is laid over the bars.
    static var blend: BlendMode { defaultBlend }

    static let defaultThickness: Double = 4.50
    static let defaultCore: Double = 0.10
    static let defaultStars: Double = 0.66
    static let defaultBlend: BlendMode = .plusLighter

    /// How bright each colour is against the others, evened out.
    ///
    /// **The counts were right and the picture was gold.** Four streaks in blue
    /// to one in gold is the mix that was asked for, but the light a streak
    /// adds is the light of *its colour* — and gold and white carry far more of
    /// it than blue and magenta do, so a tenth of the streaks were throwing a
    /// third of the brightness. These pull each colour back to the weight its
    /// share was supposed to give it.
    static func gain(of colour: Color) -> Double {
        switch colour {
        case Palette.white: 0.44
        case Palette.gold: 0.60
        default: 1
        }
    }

    // ── The wormhole ──────────────────────────────────────────────────

    /// How many streaks are in the tunnel.
    static let wormholeCount = 90

    /// How far past the corners a streak travels before it wraps.
    ///
    /// Well past, not just clear of. A streak accelerates, so it is still only
    /// three quarters of the way out when it begins fading — measured to the
    /// corner exactly, the tunnel fills its middle and leaves the ends of the
    /// bars empty. The bars are also wider than the screen, and this is
    /// measured against the screen.
    static let wormholeReach: CGFloat = 3.0

    /// How fast the tunnel runs, and how much slower the slowest streak is.
    static let wormholeSpeed: Double = 0.42
    static let wormholeSlowest: Double = 0.45

    /// How sharply a streak accelerates outward. `1` would be a constant crawl;
    /// above `2` the middle is nearly still and the rim is a blur.
    static let wormholeCurve: Double = 2.4

    /// How long a streak is at the rim, as a share of the reach.
    static let wormholeStretch: Double = 0.34

    /// How thin a streak is at the centre, as a share of its width at the rim.
    static let wormholeThinnest: Double = 0.25

    /// How big a star is against the capsule width it replaces, and how far a
    /// twinkle's spikes reach past its body.
    static let starSize: CGFloat = 0.9
    static let sparkleReach: CGFloat = 2.4

    /// When the tunnel starts coming up, and how long it takes — timed so it
    /// is fully there about as the name finishes settling.
    static let warpDawn: Double = 0.30
    static let warpFade: Double = 0.55

    /// How wide the band is that marks start in, as a share of the eye. The
    /// spread either side of it is what softens the hole's edge.
    static let eyeRagged: Double = 0.5

    /// The shortest a streak may be, as a share of the longest.
    static let stretchLeast: Double = 0.22

    /// How hard the brightness roll bunches toward the dim end. `1` is flat;
    /// higher makes the bright ones rarer and the contrast wider.
    static let glowBunching: Double = 2.2

    /// How much of a streak's life is spent fading in, and out.
    static let wormholeDawn: Double = 0.18
    static let wormholeDusk: Double = 0.12

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
    static var length: CGFloat { CGFloat(defaultLength) }

    /// How much further apart the two bars sit, in bar-thicknesses.
    ///
    /// A move, not a resize: each bar goes half of this along its own heading,
    /// so the pair opens up while both stay exactly as long as they were.
    static var spread: CGFloat { CGFloat(defaultSpread) }

    /// Where the fully-clear run ends, as a share of a bar's length in from its
    /// outer edge. `0` starts the ramp at the very tip.
    static var fadeFrom: CGFloat { CGFloat(defaultFadeFrom) }

    /// Where the ramp reaches full black, measured the same way.
    static var fadeTo: CGFloat { CGFloat(defaultFadeTo) }

    static let defaultLength: Double = 2.22
    static let defaultSpread: Double = -0.20
    static let defaultFadeFrom: Double = 0.30
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

    static var arrival: Double { defaultArrival }

    static var departure: Double { defaultDeparture }

    static let defaultArrival: Double = 0.30
    static let defaultDeparture: Double = 0.30

    // ── The words' timing ─────────────────────────────────────────────
    //
    // Separate on purpose. The words can wait for the bars to settle, or beat
    // them there, without either being re-timed to suit the other.

    /// How long after the bars start moving the words begin.
    static var textDelay: Double { defaultTextDelay }

    /// The spring's period — smaller is snappier.
    static var textResponse: Double { defaultTextResponse }

    /// How much it overshoots. Below 1 springs past and settles back; at 1 it
    /// arrives without any overshoot at all.
    static var textBounce: Double { defaultTextBounce }

    static let defaultTextDelay: Double = 0.15
    static let defaultTextResponse: Double = 0.35
    static let defaultTextBounce: Double = 0.50
}

// MARK: - The tunnels

/// A fixed number in `0..<1` for this streak and this question.
///
/// Each streak's lane, length and speed come from a hash of its own index, so
/// they are scattered but **fixed** — the field looks the same every time the
/// card is shown, and nothing has to be kept between frames to hold it steady.
/// A real generator would need seeding, storing and restoring, and would make
/// every showing subtly different for no gain.
///
/// The usual trick: take something irrational-looking, multiply, keep the
/// fraction. It is not a good random number and does not need to be. It needs
/// to be scattered, and it needs to be the same every time.
/// Shared with `FallStreaks`, which scatters its own field the same way. A
/// second copy of a hash is a second field that drifts the first time either is
/// touched.
func scatter(_ index: Int, _ question: Int) -> Double {
    let n = sin(Double(index) * 12.9898 + Double(question) * 78.233) * 43758.5453
    return n - n.rounded(.down)
}

/// One streak's colour, drawn from the four in the weights they were asked for.
///
/// Blue is the field and the other three are the exceptions in it — a spread of
/// four colours in equal numbers reads as confetti, where four in a lopsided mix
/// reads as one colour with sparks through it.
func streakColour(_ roll: Double) -> Color {
    switch roll * 10 {
    case ..<4: Palette.blue
    case ..<7: Palette.white
    case ..<9: Palette.magenta
    default: Palette.gold
    }
}

/// A four-pointed twinkle: four spikes with the waist pulled in to the centre.
///
/// Not a five-pointed star. A star drawn with five straight points is a sheriff
/// or a rating; the shape a light makes when it flares is four spikes on the
/// axes with concave sides between them, and it is the concavity that does it —
/// the same four points joined by straight lines is a diamond.
private func sparkle(at centre: CGPoint, reach: CGFloat) -> Path {
    var path = Path()
    let points = [
        CGPoint(x: centre.x, y: centre.y - reach),
        CGPoint(x: centre.x + reach, y: centre.y),
        CGPoint(x: centre.x, y: centre.y + reach),
        CGPoint(x: centre.x - reach, y: centre.y),
    ]

    path.move(to: points[0])
    for next in points.dropFirst() + [points[0]] {
        // Both control points at the middle, which is what pinches the waist.
        path.addQuadCurve(to: next, control: centre)
    }
    path.closeSubpath()
    return path
}

/// Seen from behind the ship: streaks flying outward from a vanishing point.
///
/// ## What makes it read as depth rather than as a firework
///
/// Two things, both of them acceleration. A streak's distance from the centre
/// goes up faster than time does, so nothing crawls near the middle and
/// everything tears past at the rim; and its length and width grow with that
/// distance, so a streak arriving at the edge is long and thick where the same
/// streak leaving the centre was a point. Together they are what a camera
/// pointed down a tunnel actually shows.
///
/// ## Why one canvas
///
/// Ninety views each asking for a frame is ninety timelines, which is the cost
/// that took a week out of this project to find. A `Canvas` has no children: one
/// view, one clock, and ninety draw calls that never touch the view tree.
private struct WormholeField: View {

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                guard ModeCardStyle.warp > 0 else { return }
                // Between the marks themselves. How the tunnel as a whole
                // meets the bars is the picker's business — see the modifier
                // on this view.
                context.blendMode = .plusLighter

                let now = timeline.date.timeIntervalSinceReferenceDate
                let centre = CGPoint(x: size.width / 2, y: size.height / 2)

                // Past the corners, so a streak is still travelling when it
                // leaves rather than stopping at the edge of the picture.
                let reach = hypot(size.width, size.height) / 2
                    * ModeCardStyle.wormholeReach

                for index in 0..<ModeCardStyle.wormholeCount {
                    let angle = scatter(index, 1) * 2 * .pi
                    let pace = ModeCardStyle.wormholeSlowest + scatter(index, 2)

                    let turn = now * ModeCardStyle.wormholeSpeed * pace
                        + scatter(index, 3)
                    let phase = turn - turn.rounded(.down)

                    // Out faster than time goes.
                    // **Out of the eye, and not all from the same ring.**
                    //
                    // Every mark starting at exactly the same radius drew the
                    // eye as a hard black disc — the edge was not a colour, it
                    // was the line where the light began. Each mark now starts
                    // somewhere in a band around the eye, and brightness comes
                    // up across that band rather than at it, which is the
                    // radial gradient the hole was missing.
                    let eye = reach * ModeCardStyle.core
                        * (ModeCardStyle.eyeRagged + scatter(index, 7))
                    let head = eye + (reach - eye) * pow(phase, ModeCardStyle.wormholeCurve)

                    // Length varies per streak as well as with distance, so the
                    // field is a spread of lengths at every radius instead of
                    // one length that happens to grow.
                    let stretch = ModeCardStyle.wormholeStretch
                        * (ModeCardStyle.stretchLeast
                            + scatter(index, 8) * (1 - ModeCardStyle.stretchLeast))
                    let tail = max(eye, head - reach * stretch * phase)

                    let direction = CGPoint(x: cos(angle), y: sin(angle))
                    let width = ModeCardStyle.thickness
                        * (ModeCardStyle.wormholeThinnest + phase)

                    // In from nothing, out before it stops — a mark that
                    // appears or vanishes at full brightness is a mark you
                    // notice being drawn.
                    let entering = min(1, phase / ModeCardStyle.wormholeDawn)
                    let leaving = min(1, (1 - phase) / ModeCardStyle.wormholeDusk)
                    let colour = streakColour(scatter(index, 5))

                    // **Its own brightness, then the master.**
                    //
                    // Raised to a power so the roll bunches low: most marks are
                    // faint and a few are not, which is a field with depth in
                    // it. A flat roll gives every mark a middling brightness and
                    // the whole thing reads as one grey sheet.
                    //
                    // `warp` multiplies the lot afterwards, so turning it down
                    // dims everything in proportion and keeps the spread — the
                    // group volume, not a level every mark is set to.
                    let own = ModeCardStyle.warpFaintest
                        + pow(scatter(index, 4), ModeCardStyle.glowBunching)
                        * (1 - ModeCardStyle.warpFaintest)

                    let glow = ModeCardStyle.warp * entering * leaving * own
                        * ModeCardStyle.gain(of: colour)

                    let shading = GraphicsContext.Shading.color(colour.opacity(glow))

                    // Some of the tunnel is stars rather than streaks: they sit
                    // where they are instead of stretching, which is what tells
                    // you the streaks are moving.
                    let roll = scatter(index, 6)
                    if roll < ModeCardStyle.stars {
                        let at = CGPoint(
                            x: centre.x + direction.x * head,
                            y: centre.y + direction.y * head
                        )
                        let size = width * ModeCardStyle.starSize

                        // Half of them round, half of them twinkling.
                        if roll < ModeCardStyle.stars / 2 {
                            context.fill(
                                Path(ellipseIn: CGRect(
                                    x: at.x - size, y: at.y - size,
                                    width: size * 2, height: size * 2
                                )),
                                with: shading
                            )
                        } else {
                            context.fill(sparkle(at: at, reach: size * ModeCardStyle.sparkleReach),
                                         with: shading)
                        }
                    } else {
                        var path = Path()
                        path.move(to: CGPoint(
                            x: centre.x + direction.x * tail,
                            y: centre.y + direction.y * tail
                        ))
                        path.addLine(to: CGPoint(
                            x: centre.x + direction.x * head,
                            y: centre.y + direction.y * head
                        ))

                        context.stroke(
                            path,
                            with: shading,
                            style: StrokeStyle(lineWidth: width, lineCap: .round)
                        )
                    }
                }
            }
        }
        .blendMode(ModeCardStyle.blend)
        .allowsHitTesting(false)
    }
}

/// Seen from the side: streaks running the way the shape they are in is headed.
///
/// Not the card's tunnel — that one looks out of the front — but the right thing
/// for a shape that is *passing*, which is what the passives prompt does. The
/// upper half of the field runs one way and the lower half the other, so a
/// two-bar assembly gets both and a single bar gets whichever half it covers.
struct SideStreaks: View {

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                guard PromptStyle.warp > 0 else { return }
                // Between the marks themselves. How the tunnel as a whole
                // meets the bars is the picker's business — see the modifier
                // on this view.
                context.blendMode = .plusLighter

                let now = timeline.date.timeIntervalSinceReferenceDate
                let half = size.height / 2

                for index in 0..<ModeCardStyle.warpCount {
                    let isUpper = index.isMultiple(of: 2)
                    // The same headings the bars themselves take.
                    let heading: CGFloat = isUpper ? 1 : -1

                    let span = scatter(index, 2)
                    let pace = scatter(index, 3)

                    let length = size.width * PromptStyle.streakLength
                        * (ModeCardStyle.warpShortest + span)
                    let speed = size.width * PromptStyle.streakSpeed
                        * (ModeCardStyle.warpSlowest + pace)

                    // Wrapped over the width plus one streak, so a streak leaves
                    // one end and returns at the other with no moment where it
                    // is half-drawn at both.
                    let run = size.width + length
                    let travelled = (now * speed + Double(index) * 97)
                        .truncatingRemainder(dividingBy: run)
                    let x = heading < 0 ? size.width - travelled : travelled - length

                    let y = scatter(index, 1) * half + (isUpper ? 0 : half)
                    let streak = CGRect(
                        x: x,
                        y: y - PromptStyle.thickness / 2,
                        width: length,
                        height: PromptStyle.thickness
                    )

                    let colour = streakColour(scatter(index, 5))
                    let glow = PromptStyle.warp
                        * (ModeCardStyle.warpFaintest + scatter(index, 4))
                        * ModeCardStyle.gain(of: colour)

                    context.fill(
                        Capsule().path(in: streak),
                        with: .color(colour.opacity(glow))
                    )
                }
            }
        }
        .blendMode(.plusLighter)
        .allowsHitTesting(false)
    }
}
