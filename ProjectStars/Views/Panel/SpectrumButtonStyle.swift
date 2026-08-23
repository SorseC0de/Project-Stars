//
//  SpectrumButtonStyle.swift
//  Project Stars
//
//  A button lit from behind by a turning spectrum.
//

import SwiftUI

/// A control that reads as light rather than as a moulded key.
///
/// ## What it is made of
///
/// A halo of colour turning behind the whole thing, the same sweep turning
/// again behind frosted glass for the face, a side standing proud below it, and
/// a lit edge round the top. The two sweeps are in phase and at one speed, so
/// the button and the light around it read as one object rather than two things
/// that happen to share a palette.
///
/// ## Why a `ButtonStyle`
///
/// Because it is a *look*, not a button — sign select wants it, and whatever
/// comes after that will want it, and none of them will be the same shape. The
/// shape is handed in, so this draws a pill or a hexagon as readily as a
/// rounded rectangle.
///
/// It also gets the press for free. `CelButton` needs a drag gesture beside its
/// tap because a tap gesture only reports once the tap completes, and a press
/// has to show the instant the finger lands; a `ButtonStyle` is handed
/// `isPressed` on touch-down and needs neither.
struct SpectrumButtonStyle<S: InsettableShape>: ButtonStyle {

    /// The face, the side, and what the lit edge is drawn round.
    let shape: S

    /// The halo's shape, if it should not be the button's own.
    ///
    /// Softer than the face is usually right: a halo that repeats the button's
    /// corners reads as a second button behind the first, where a rounder one
    /// reads as light. Left out, it is the face's shape.
    var halo: AnyShape?

    /// Whether the light is on. Off, this is a dark pane and nothing else —
    /// which is what a button should look like before its screen is ready.
    var isLive: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        SpectrumButtonBody(
            shape: shape,
            halo: halo ?? AnyShape(shape),
            isLive: isLive,
            isPressed: configuration.isPressed,
            label: configuration.label
        )
    }
}

/// The style's body, which needs state the style itself cannot hold.
private struct SpectrumButtonBody<S: InsettableShape, Label: View>: View {

    let shape: S
    let halo: AnyShape
    let isLive: Bool
    let isPressed: Bool
    let label: Label

    @State private var isSwelling = false

    var body: some View {
        let depth = PanelStyle.buttonDepth * SpectrumStyle.depthScale
        let colours = CelPalette(face: Palette.coolBlack)

        ZStack {
            // The side, standing proud below the face.
            shape
                .fill(colours.rim.opacity(SpectrumStyle.rimOpacity))
                .offset(y: depth)

            shape
                .fill(colours.face)
                .overlay {
                    SpectrumPane(isLive: isLive)
                        .clipShape(shape)
                        .allowsHitTesting(false)
                }
                // **No lit plane.** Every moulded button on the panel has one,
                // and it is what makes them look moulded. This is a pane with
                // light behind it, and a hard-edged highlight across the top of
                // glass says the glass is solid.
                .overlay {
                    // Inside the edge rather than centred on it, so the button
                    // keeps its own size.
                    shape.strokeBorder(
                        SpectrumStyle.edgeGradient,
                        lineWidth: SpectrumStyle.edgeWidth
                    )
                }
                .offset(y: isPressed ? depth : 0)

            label
                .foregroundStyle(Palette.white)
                // Hard and straight down: a cast shadow, not a glow. Zero radius
                // keeps the edge, which is what lifts white letters off a face
                // that is never one colour for long.
                .shadow(color: Palette.coolBlack, radius: 0, x: 0,
                        y: SpectrumStyle.labelShadow)
                .offset(y: isPressed ? depth : 0)
        }
        .background {
            SpectrumGlow(shape: halo, isLive: isLive, isSwelling: isSwelling)
        }
        .animation(.easeOut(duration: PanelStyle.buttonPressDuration), value: isPressed)
        .animation(
            .easeInOut(duration: SpectrumStyle.breath).repeatForever(autoreverses: true),
            value: isSwelling
        )
        .onChange(of: isLive, initial: true) { _, live in
            isSwelling = live
        }
    }
}

/// The colours the Start button is lit and painted with.
///
/// A ring rather than a list: the last has to meet the first or the sweep has a
/// seam in it, and a seam travelling round the button is the one thing a
/// continuous glow must not have.
enum Spectrum {

    static let ring: [Color] = hues + hues + [hues[0]]

    /// **Twice round, not once.**
    ///
    /// The bands were reading as quadrants, and the fix is not different
    /// colours — it is more of them. The same run laid twice halves how much of
    /// the circle any one hue owns, so no band is wide enough to be seen as a
    /// side of something, and the sweep still returns to where it began.
    private static let hues: [Color] = [
        Palette.magenta, Palette.pink, Palette.orange, Palette.gold,
        Palette.yellowGreen, Palette.cyan, Palette.sky, Palette.blue,
        Palette.purple, Palette.darkMagenta,
    ]

    /// One turn of the sweep.
    static let period: Double = 4.5

    /// How soft the glow is at each end of the breath.
    ///
    /// The blur was never the problem — how far the light *reached* was, which
    /// is the halo's size rather than its softness and lives on the button's
    /// own bench as `SpectrumStyle.haloSpread`.
    static let bloomNear: CGFloat = 10
    static let bloomFar: CGFloat = 26
    static let strength: Double = 0.85

    /// The blobs on the parked face: how many, how big, how soft, and how far
    /// they wander as a share of the button.
    static let blobs = 9
    static let blobSoftness: CGFloat = 20
    static let blobDrift: CGFloat = 0.85
    static let faceStrength: Double = 0.75

    /// The smallest and largest a blob is, against the button's *height*.
    ///
    /// The large end is deliberately past 1: a blob wider than the button is
    /// tall has no visible edge inside it, so what shows is a field of colour
    /// rather than a circle crossing. All the same size — any size — reads as a
    /// row of dots on a conveyor.
    static let blobSmallest: CGFloat = 0.9
    static let blobLargest: CGFloat = 3.4

    /// How long a blob takes to cross and back, and how much that varies.
    static let driftPeriod: Double = 5.2
    static let driftSpread: Double = 3.4
}

/// The glow: the spectrum travelling clockwise around the button.
///
/// An angular gradient turned by a repeating animation, blurred well past the
/// button's edge so what shows is the light rather than the ring making it.
/// The pulse is left alone — it is the button's heartbeat and the sweep is its
/// colour, and they are on different clocks on purpose.
private struct SpectrumGlow: View {

    /// What the light is cut to. Rounder than the face is usually right — a
    /// halo repeating the button's corners reads as a second button behind the
    /// first, where a rounder one reads as light.
    let shape: AnyShape

    let isLive: Bool
    let isSwelling: Bool

    @State private var turned = false

    var body: some View {
        GeometryReader { geometry in
            // **Turned, not re-angled.**
            //
            // An `AngularGradient`'s angle is not something SwiftUI can
            // interpolate — handed a new one it draws the new one, so a sweep
            // built that way advances in steps and visibly catches on each
            // repeat. `rotationEffect` is animatable, so the same colours turned
            // by it run continuously and the loop closes where it opened.
            //
            // Square, and as wide as the halo's diagonal, so no corner of it can
            // swing into view as it turns.
            let halo = CGSize(
                width: geometry.size.width + SpectrumStyle.haloSpread * 2,
                height: geometry.size.height + SpectrumStyle.haloSpread * 2
            )
            let side = hypot(halo.width, halo.height)

            Rectangle()
                .fill(AngularGradient(colors: Spectrum.ring, center: .center))
                .frame(width: side, height: side)
                .rotationEffect(.degrees(turned ? 360 : 0))
                .frame(width: halo.width, height: halo.height)
                .mask {
                    shape.frame(width: halo.width, height: halo.height)
                }
                .blur(radius: isSwelling ? Spectrum.bloomFar : Spectrum.bloomNear)
                .opacity(isLive ? Spectrum.strength : 0)
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                .animation(
                    .linear(duration: Spectrum.period).repeatForever(autoreverses: false),
                    value: turned
                )
        }
        .onChange(of: isLive, initial: true) { _, live in
            if live { turned = true }
        }
        .allowsHitTesting(false)
    }
}

/// The face: the same spectrum, seen through frosted glass.
///
/// ## Why this and not the blobs
///
/// Because the blobs had to come back. Anything crossing a button has to
/// return to where it started, and `autoreverses` is the only honest way to do
/// that with a repeating animation — which means every blob spends half its
/// life going the other way. No amount of staggering hides it: the whole field
/// reverses, and a field that reverses is a field you can see turning round.
///
/// A rotation has no such problem. The same sweep that lights the halo turns
/// behind the glass, in phase with it and at the same speed, so the button and
/// the light around it are one object rather than two things that happen to
/// share a palette. And it never comes back — it only ever goes round.
///
/// The material is asked for dark explicitly. It takes its cue from the
/// environment otherwise, and this panel is dark whatever the phone is set to.
private struct SpectrumPane: View {

    let isLive: Bool

    @State private var turned = false

    var body: some View {
        GeometryReader { geometry in
            // Square and diagonal-wide, so no corner swings into view.
            let side = hypot(geometry.size.width, geometry.size.height)

            ZStack {
                Rectangle()
                    .fill(AngularGradient(colors: Spectrum.ring, center: .center))
                    .frame(width: side, height: side)
                    .rotationEffect(.degrees(turned ? 360 : 0))
                    .blur(radius: SpectrumStyle.paneSoftness)
                    .opacity(isLive ? SpectrumStyle.paneStrength : 0)
                    .animation(
                        .linear(duration: Spectrum.period).repeatForever(autoreverses: false),
                        value: turned
                    )

                Rectangle()
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .onChange(of: isLive, initial: true) { _, live in
            if live { turned = true }
        }
    }
}

/// The face: soft blobs of colour drifting across each other.
///
/// **Parked.** Kept because the trick is a good one and something that is not a
/// button will want it — a field where nothing has to return to its starting
/// place. See `SpectrumPane` for why it could not stay here.
///
/// ## Why blobs and a blur rather than a gradient
///
/// Because a gradient between two points is a straight line of colour however
/// it is animated, and what this wants is colour that *moves through* other
/// colour. A handful of heavily blurred circles overlapping do that on their
/// own: where two meet, the blur has already mixed them, and the mixture moves
/// when they do. It is the trick from Plentacle, and it is a better fit here
/// than a mesh would be — a mesh needs its control points driven every frame,
/// where these are each on a repeating animation SwiftUI runs by itself.
///
/// Each blob has its own period and its own delay, so they never line up into a
/// single pulse. All of it is one `onAppear`; nothing here is on a clock.
private struct SpectrumFace: View {

    let isLive: Bool

    @State private var drifted = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(0..<Spectrum.blobs, id: \.self) { index in
                    // Scattered rather than stepped, so size does not march up
                    // the row in order with position.
                    let seed = wobble(index, 1)
                    let lane = wobble(index, 2)
                    let colour = Spectrum.ring[index % Spectrum.ring.count]
                    let reach = geometry.size.width * Spectrum.blobDrift

                    Circle()
                        .fill(colour)
                        .frame(
                            width: geometry.size.height
                                * (Spectrum.blobSmallest
                                    + seed * (Spectrum.blobLargest - Spectrum.blobSmallest))
                        )
                        // **All of them the same way.**
                        //
                        // Alternating the direction made two of them pass each
                        // other, which reads as things crossing rather than as
                        // one field moving. A conveyor only looks like a
                        // conveyor if nothing on it is going the other way.
                        // **Each on its own run, all of them the same way.**
                        //
                        // Same direction or it stops being a conveyor; different
                        // ends or they travel as one row however their timings
                        // differ, because a shared start and a shared finish is
                        // a formation whatever happens in between.
                        .position(
                            x: geometry.size.width / 2
                                + (drifted ? reach * (0.5 + lane) : -reach * (0.5 + seed)),
                            y: geometry.size.height * (0.15 + 0.7 * lane)
                        )
                        .scaleEffect(drifted ? 1.2 : 0.8)
                        .animation(
                            .easeInOut(duration: Spectrum.driftPeriod + seed * Spectrum.driftSpread)
                                .repeatForever(autoreverses: true),
                            value: drifted
                        )
                }
            }
            .blur(radius: Spectrum.blobSoftness)
            // The blur reaches past the button; the clip outside puts it back.
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .opacity(isLive ? Spectrum.faceStrength : 0)
        .onChange(of: isLive, initial: true) { _, live in
            if live { drifted = true }
        }
    }

    /// A fixed number in `0..<1` for this blob and this question.
    private func wobble(_ index: Int, _ question: Int) -> CGFloat {
        let n = sin(Double(index) * 12.9898 + Double(question) * 78.233) * 43758.5453
        return CGFloat(n - n.rounded(.down))
    }
}

// MARK: - Measurements

/// Everything the look is made of, in one place.
///
/// Settled by eye at the bench that used to drive them. They are written down
/// rather than left on sliders because the button is finished — and because the
/// next thing to wear this style should get the same button, not whatever the
/// sliders were left at.
@MainActor
enum SpectrumStyle {

    /// The light behind the glass, and how soft its bands are.
    static let paneStrength: Double = 0.85
    static let paneSoftness: CGFloat = 33

    /// How tall the button's side is against the panel's usual, and how solid.
    static let depthScale: CGFloat = 2
    static let rimOpacity: Double = 0.66

    /// How far the halo reaches past the button, and how round it is by
    /// default.
    ///
    /// **Nothing, and very.** What shows is light *on* the button rather than a
    /// shape behind it, so there is nothing left for a reach to do — and with no
    /// reach, the roundness is all that separates the halo's edge from the
    /// face's.
    static let haloSpread: CGFloat = 0
    static let haloCorner: CGFloat = 60

    /// One breath of the halo.
    static let breath: Double = 1.1

    /// How far the label's shadow falls.
    static let labelShadow: CGFloat = 4

    /// The lit edge round the face.
    static let edgeWidth: CGFloat = 3

    /// The lit edge: white where the light comes from, gone by the far side.
    ///
    /// Four stops, of which only the first carries anything in the end — the
    /// edge that looked right turned out to be a short bright run and then
    /// nothing, rather than a ramp. The other three are kept because they are
    /// what makes that a *decision*: a two-stop gradient could not have been
    /// tuned to this, and could not be tuned away from it either.
    static var edgeGradient: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: Palette.white.opacity(0.33 * 0.50), location: 0),
                .init(color: Palette.white.opacity(0), location: 0.50),
                .init(color: Palette.white.opacity(0), location: 0.75),
                .init(color: Palette.white.opacity(0), location: 1),
            ],
            startPoint: .topLeading,
            endPoint: .bottom
        )
    }
}
