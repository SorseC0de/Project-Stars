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
        .task { await play() }
    }

    // MARK: - The bars

    /// Which of the two, and with it which way it travels and which end fades.
    enum Slat {
        case upper, lower

        /// The upper bar comes from the trailing edge and keeps going leading;
        /// the lower one does the opposite. Every asymmetry in the card is this
        /// one number, so the two can never disagree about which way is out.
        var heading: CGFloat { self == .upper ? -1 : 1 }
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
            // **Outward only.** Widening a centred bar moves both ends, and the
            // inner end is the one holding the seam — so the extra length is
            // pushed entirely out toward the edge the bar fades into.
            .offset(x: travel(slat, width: width, bar: bar)
                + slat.heading * ModeCardStyle.spread * bar.height / 2)
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

        let heading = slat.heading

        return switch stage {
        case .offstage: -heading * away
        case .gathered: heading * settled
        case .parted: heading * away
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

    private func play() async {
        withAnimation(.easeOut(duration: ModeCardStyle.arrival)) { stage = .gathered }
        await sleep(ModeCardStyle.arrival + ModeCardStyle.hold)

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
    static let face = Color.black

    /// One bar's fill: solid at its inner end, gone at its outer one.
    ///
    /// **Three stops and no more** — the two ends and the place the colours
    /// meet. A gradient with spare stops in it is a gradient nobody can tune,
    /// because moving the one that matters no longer moves the edge.
    static func taper(towards slat: GameModeSplashView.Slat) -> LinearGradient {
        let meet = fade

        let stops = [
            Gradient.Stop(color: .clear, location: 0),
            Gradient.Stop(color: face, location: meet),
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

    /// The curve the words arrive on.
    static let pop = Animation.spring(response: 0.34, dampingFraction: 0.52)

    /// The words on them.
    static let ink = Palette.textPrimary

    /// Horizontal shift of a bar's top edge, as a share of its height.
    static let lean: CGFloat = 0.97

    /// One bar's size for a given screen width.
    static func bar(across width: CGFloat) -> Bar {
        let height = barHeight * width
        return Bar(width: height * barAspect, height: height)
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
    private static let barAspect: CGFloat = 5.18

    /// Extra length on each bar, in bar-thicknesses, all of it added outward.
    ///
    /// Reaches toward the screen's edges rather than growing the card from its
    /// middle: the inner ends make the Z and must not move.
    static var spread: CGFloat {
        #if DEBUG
        ModeCardTuning.shared.spread
        #else
        defaultSpread
        #endif
    }

    /// How far in from a bar's outer edge the fade finishes, as a share of its
    /// length. `0` is no fade at all; `0.5` fades across half the bar.
    static var fade: CGFloat {
        #if DEBUG
        ModeCardTuning.shared.fade
        #else
        defaultFade
        #endif
    }

    static let defaultSpread: CGFloat = 0
    static let defaultFade: CGFloat = 0.2

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

    /// How long the bars take to arrive, how long they are read, and how long
    /// they take to leave.
    static let arrival: Double = 0.42
    static let hold: Double = 1.9
    static let departure: Double = 0.42

    /// The whole card, start to finish.
    static var duration: Double { arrival + hold + departure }
}
