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
                // The upper bar, and the mode's name across it.
                slat(bar: bar, travel: travel(.upper, width: width, bar: bar))
                    .overlay { title(on: bar) }
                    .offset(y: -bar.height / 2)

                // The lower bar, carrying the line underneath.
                slat(bar: bar, travel: travel(.lower, width: width, bar: bar))
                    .overlay { blurb(on: bar) }
                    .offset(y: bar.height / 2)
            }
            .frame(width: width, height: geometry.size.height)
        }
        .allowsHitTesting(false)
        .task { await play() }
    }

    // MARK: - The bars

    private enum Slat { case upper, lower }

    /// One bar, at its current place along its own line of travel.
    private func slat(bar: ModeCardStyle.Bar, travel: CGFloat) -> some View {
        Parallelogram(lean: ModeCardStyle.lean)
            .fill(ModeCardStyle.face)
            .frame(width: bar.width, height: bar.height)
            .offset(x: travel)
    }

    /// How far this bar is from centre right now.
    ///
    /// One function for both bars and all three moments, because the two are the
    /// same movement mirrored — anything that made them separate journeys would
    /// need keeping in agreement, and they are only ever a Z when they agree.
    private func travel(_ slat: Slat, width: CGFloat, bar: ModeCardStyle.Bar) -> CGFloat {
        let away = ModeCardStyle.entrance * width
        let settled = ModeCardStyle.overshoot * bar.height

        // The upper bar comes from the trailing edge and keeps going leading;
        // the lower one does the opposite.
        let heading: CGFloat = slat == .upper ? -1 : 1

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
            .font(.system(size: ModeCardStyle.titleSize * bar.height, weight: .black))
            .fontWidth(.compressed)
            .tracking(ModeCardStyle.titleTracking * bar.height)
            // The tracking is applied after the last letter too, which walks the
            // whole line left of centre by half a gap.
            .padding(.leading, ModeCardStyle.titleTracking * bar.height)
            .foregroundStyle(ModeCardStyle.ink)
            .lineLimit(1)
            .minimumScaleFactor(ModeCardStyle.textSqueeze)
            .frame(maxWidth: ModeCardStyle.textWidth * bar.height)
            .offset(y: ModeCardStyle.titleDrop * bar.height)
            .opacity(said)
    }

    /// The one-line description, under the name on the lower bar.
    private func blurb(on bar: ModeCardStyle.Bar) -> some View {
        Text(mode.blurb)
            .font(.system(size: ModeCardStyle.blurbSize * bar.height, weight: .medium))
            .foregroundStyle(ModeCardStyle.ink)
            .lineLimit(1)
            .minimumScaleFactor(ModeCardStyle.textSqueeze)
            .frame(maxWidth: ModeCardStyle.textWidth * bar.height)
            .offset(y: ModeCardStyle.blurbDrop * bar.height)
            .opacity(said)
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
enum ModeCardStyle {

    /// The face of both bars.
    static let face = Palette.coolBlack

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

    /// How far off centre a bar waits, and how far past it leaves.
    ///
    /// Comfortably more than half a screen plus half a bar, so a slow device
    /// showing the first frame late still shows it empty.
    static let entrance: CGFloat = 1

    /// How far each bar settles past centre, into the other's side.
    ///
    /// This is what makes it a Z rather than a stack: dead centre, the two would
    /// sit one directly above the other and the slants would read as a single
    /// leaning block.
    static let overshoot: CGFloat = 0.24

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
    static let hold: Double = 1.35
    static let departure: Double = 0.42

    /// The whole card, start to finish.
    static var duration: Double { arrival + hold + departure }
}
