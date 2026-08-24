//
//  Extensions.swift
//  Plentacle
//
//  Created by SorseC0de on 2/28/26.
//

import SwiftUI
import UIKit

// MARK: - Keyboard Dismissal

extension UIApplication {
    /// Resigns first responder on any active text field. Used when the user
    /// navigates away from search mode (opens CardDetail, Settings, WOF, etc.)
    /// so the keyboard doesn't linger behind the new screen.
    static func dismissKeyboard() {
        shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - Icon Labels Environment Key

/// Read-only environment flag so any view can check whether the user has
/// enabled visible icon labels in Settings.  ContentView owns the
/// `@State` and publishes via `.environment(\.iconLabels, iconLabels)`.
private struct IconLabelsKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    var iconLabels: Bool {
        get { self[IconLabelsKey.self] }
        set { self[IconLabelsKey.self] = newValue }
    }
}

/// Tiny overlay text shown beneath an icon when the user has enabled
/// visible icon labels.  Uses `.allowsHitTesting(false)` so it never
/// steals taps from the icon it decorates.
struct IconLabel: View {
    let text: String
    var color: Color = .white
    var blendMode: BlendMode = .normal

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: text.uppercased() == "BACK" ? 12 : 8, weight: .heavy))
            .kerning(0.3)
            .foregroundStyle(color)
            .lineLimit(1)
            .fixedSize()
            .blendMode(blendMode)
            .allowsHitTesting(false)
            .contentTransition(.numericText())
    }
}

// MARK: - Sleeping Planes

/// True while this view's plane is off screen.
///
/// ## Why this exists
///
/// Every row of the world is mounted at once — see `World` — and the window onto
/// them is two squares of a column nine tall. That is what lets a fall travel
/// between planes instead of hiding a swap behind a curtain, and it is worth
/// keeping.
///
/// But **being off screen hides pixels; it does not stop views running.** Astra's clouds
/// carried on asking for sixty frames a second the whole time the player was
/// standing on Terra — ten sprites, six hundred wake-ups a second, for a picture
/// nobody could see. It was comfortably the largest single cost on the board and
/// it was entirely invisible, because nothing about it *drew* anything: a view
/// that is never rebuilt still wakes the main thread every frame if it asked to.
///
/// So the plane that is not being looked at goes to sleep. It stays mounted,
/// keeps its state, and comes back the instant it is needed — it simply stops
/// asking for frames while there is nothing to see.
///
/// ## Why it is not just `plane != visiblePlane`
///
/// Because the camera and the piece are different questions. During a fall
/// **both** planes are on screen, scrolling past each other, and the one being
/// left has to still be alive on the way out — so the answer comes from where
/// the camera is looking and where it is on its way to, not from where the piece
/// happens to be standing. See `GameSession.planeIsAsleep(_:)`, and
/// `World.isVisible(row:sweeping:to:)` for why the journey has to be asked about
/// rather than the instant.
private struct SleepingPlaneKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var planeIsAsleep: Bool {
        get { self[SleepingPlaneKey.self] }
        set { self[SleepingPlaneKey.self] = newValue }
    }
}

// MARK: - Color Extensions

extension Color {
    /// Lightens the color by the specified amount
    /// - Parameter amount: The amount to lighten (0.0 to 1.0)
    /// - Returns: A lightened color
    func lightened(by amount: CGFloat) -> Color {
        return self.adjustBrightness(by: abs(amount))
    }
    
    /// Darkens the color by the specified amount
    /// - Parameter amount: The amount to darken (0.0 to 1.0)
    /// - Returns: A darkened color
    func darkened(by amount: CGFloat) -> Color {
        return self.adjustBrightness(by: -abs(amount))
    }
    
    /// Adjusts the brightness of the color
    /// - Parameter amount: The amount to adjust (-1.0 to 1.0)
    /// - Returns: An adjusted color
    private func adjustBrightness(by amount: CGFloat) -> Color {
        #if canImport(UIKit)
        let uiColor = UIColor(self)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        // Try HSB color space first
        if uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) {
            // For lightening colors that are already bright, reduce saturation instead
            if amount > 0 && brightness > 0.8 {
                let adjustedSaturation = max(saturation - amount * 0.5, 0)
                let adjustedBrightness = min(brightness + amount * 0.3, 1)
                
                return Color(UIColor(
                    hue: hue,
                    saturation: adjustedSaturation,
                    brightness: adjustedBrightness,
                    alpha: alpha
                ))
            } else {
                let adjustedBrightness = min(max(brightness + amount, 0), 1)
                
                return Color(UIColor(
                    hue: hue,
                    saturation: saturation,
                    brightness: adjustedBrightness,
                    alpha: alpha
                ))
            }
        } else {
            // Fallback to RGB if HSB fails
            var red: CGFloat = 0
            var green: CGFloat = 0
            var blue: CGFloat = 0
            
            uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
            
            if amount > 0 {
                // Lightening - blend with white
                let blend = amount
                red = red + (1 - red) * blend
                green = green + (1 - green) * blend
                blue = blue + (1 - blue) * blend
            } else {
                // Darkening - blend with black
                let blend = abs(amount)
                red = red * (1 - blend)
                green = green * (1 - blend)
                blue = blue * (1 - blend)
            }
            
            return Color(UIColor(red: red, green: green, blue: blue, alpha: alpha))
        }
        #elseif canImport(AppKit)
        let nsColor = NSColor(self)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        nsColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        
        // Same logic as iOS
        if amount > 0 && brightness > 0.8 {
            let adjustedSaturation = max(saturation - amount * 0.5, 0)
            let adjustedBrightness = min(brightness + amount * 0.3, 1)
            
            return Color(NSColor(
                hue: hue,
                saturation: adjustedSaturation,
                brightness: adjustedBrightness,
                alpha: alpha
            ))
        } else {
            let adjustedBrightness = min(max(brightness + amount, 0), 1)
            
            return Color(NSColor(
                hue: hue,
                saturation: saturation,
                brightness: adjustedBrightness,
                alpha: alpha
            ))
        }
        #else
        return self
        #endif
    }
}

extension Color {
    init(hex: Int, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 08) & 0xff) / 255,
            blue: Double((hex >> 00) & 0xff) / 255,
            opacity: opacity
        )
    }
}

extension View {
    func multicolorGlow() -> some View {
        ZStack {
            ForEach(0..<2) { i in
                Rectangle()
                    .fill(AngularGradient(gradient:
                        Gradient(colors:
                        [Color.blue,
                         Color.purple,
                         Color.orange,
                         Color.red]), center: .center))
                    .frame(width: 400, height: 300)
                    .mask(self.blur(radius: 20))
                    .overlay(self.blur(radius: 5 - CGFloat(i * 5)))
            }
        }
    }
}
// MARK: - Clipped Window

extension View {
    /// Clips the view to a fixed height with an adjustable window position.
    /// - Parameters:
    ///   - height: The visible frame height.
    ///   - yOffset: Vertical shift applied before clipping. Negative values reveal content further down the source.
    ///   - xOffset: Horizontal shift applied before clipping.
    func clippedWindow(height: CGFloat, yOffset: CGFloat = 0, xOffset: CGFloat = 0) -> some View {
        self
            .offset(x: xOffset, y: yOffset)
            .frame(height: height)
            .clipped()
    }
    
    @inlinable
    public func reverseMask<Mask: View>(alignment: Alignment = .center, @ViewBuilder _ mask: () -> Mask) -> some View {
        self.mask(
            Rectangle()
                .overlay(alignment: alignment) {
                    mask()
                        .blendMode(.destinationOut)
                }
        )
    }
}

// MARK: - Custom Views

struct Dots: View {
    let count: Int
    let dotSize: CGFloat
    let xOffset: CGFloat
    /// When true, each dot pulses in size on its own randomized phase via
    /// `TimelineView(.animation)` instead of marching in lock-step.
    var nonUniformPulse: Bool = false
    /// Palette to randomly sample per-dot shadow colors from. Empty palette
    /// means no shadow.
    var shadowPalette: [Color] = []

    // Per-dot randoms — sealed at init so re-renders don't re-roll them.
    private let perDotPhase: [Double]
    private let perDotShadow: [Color]

    init(count: Int,
         dotSize: CGFloat,
         xOffset: CGFloat,
         nonUniformPulse: Bool = false,
         shadowPalette: [Color] = []) {
        self.count = count
        self.dotSize = dotSize
        self.xOffset = xOffset
        self.nonUniformPulse = nonUniformPulse
        self.shadowPalette = shadowPalette
        // Stable random distributions, sampled once per Dots instance.
        self.perDotPhase = (0..<count).map { _ in Double.random(in: 0..<(2 * .pi)) }
        self.perDotShadow = (0..<count).map { _ in
            shadowPalette.randomElement() ?? .clear
        }
    }

    var body: some View {
        if nonUniformPulse {
            // TimelineView ticks each frame so we can drive per-dot sin phases.
            TimelineView(.animation) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                ringContent(timeOrNil: t)
            }
        } else {
            ringContent(timeOrNil: nil)
        }
    }

    @ViewBuilder
    private func ringContent(timeOrNil: TimeInterval?) -> some View {
        ZStack {
            ForEach(0..<count, id: \.self) { i in
                let scale: CGFloat = {
                    guard let t = timeOrNil else { return 1.0 }
                    // 3 Hz angular freq + per-dot phase → desynced bobble.
                    // Maps sin(-1...1) → 0.4...1.0 so dots don't disappear.
                    return CGFloat(0.7 + 0.3 * sin(t * 3 + perDotPhase[i]))
                }()
                let s = max(0.001, dotSize * scale)
                dot(size: s, shadow: perDotShadow[i])
                    .rotationEffect(.degrees(Double(i * 365 / count)))
            }
        }
    }

    private func dot(size: CGFloat, shadow: Color) -> some View {
        Group {
            // Hidden centerpiece preserves the rotation-around-center geometry
            // the original implementation relied on.
            Circle()
                .frame(width: size, height: size)
                .hidden()
            Circle()
                .frame(width: size, height: size)
                .shadow(color: shadow, radius: 5)
                .offset(x: xOffset)
        }
    }
}

struct RadialPattern: View {
    let size: CGFloat
    let animate: Bool
    /// When true, each dot pulses on its own random phase (via per-dot
    /// `TimelineView`) instead of all dots beating together. Off by default
    /// to preserve the prior call-site behavior.
    var nonUniformPulse: Bool = false

    @State private var rotDegrees = 0.0
    @State private var dotPulse: CGFloat = 1.0
    @State private var opacity: Double = 1.0

    /// Universal suit colors — sampled per-dot for shadow tinting.
    private static let suitShadowPalette: [Color] = [.purple, .blue, .green, .red, .yellow]

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.clear)
            Dots(count: 20, dotSize: dotPulse / 10, xOffset: size / 2,
                 nonUniformPulse: nonUniformPulse,
                 shadowPalette: Self.suitShadowPalette)
            Dots(count: 20, dotSize: dotPulse / 15, xOffset: size / 2.4,
                 nonUniformPulse: nonUniformPulse,
                 shadowPalette: Self.suitShadowPalette)
                .rotationEffect(.degrees(25))
            Dots(count: 20, dotSize: dotPulse / 20, xOffset: size / 2.9,
                 nonUniformPulse: nonUniformPulse,
                 shadowPalette: Self.suitShadowPalette)
            Dots(count: 20, dotSize: dotPulse / 15, xOffset: size / 1.7,
                 nonUniformPulse: nonUniformPulse,
                 shadowPalette: Self.suitShadowPalette)
                .rotationEffect(.degrees(25))
            Dots(count: 20, dotSize: dotPulse / 20, xOffset: size / 1.6,
                 nonUniformPulse: nonUniformPulse,
                 shadowPalette: Self.suitShadowPalette)
        }
        .rotationEffect(.degrees(rotDegrees))
        .onAppear {
            if animate {
                rotDegrees = 360
                opacity = 0
                dotPulse = size
            }
        }
        .animation(.linear(duration: 3).repeatForever(autoreverses: false), value: rotDegrees)
        .animation(.linear(duration: 0.3).repeatForever(autoreverses: true), value: opacity)
        // Global lock-step pulse stays in place when nonUniformPulse=false; when
        // true, the TimelineView in Dots takes over the per-dot scale.
        .animation(.bouncy(duration: 0.1, extraBounce: 2.0).repeatForever(autoreverses: true), value: dotPulse)
    }
}

// MARK: - Button Styles

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

// MARK: - Button Style Measurements

/// Everything the spectrum look is made of, in one place.
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
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: - Screen Utilities

enum Screen {
    static var bounds: CGRect {
        let scene = UIApplication.shared.connectedScenes
            .first as? UIWindowScene
        return scene?.windows.first?.screen.bounds ?? .zero
    }
    static var size: CGSize { bounds.size }
    static var width: CGFloat { bounds.width }
    static var height: CGFloat { bounds.height }
    static var safeAreaTop: CGFloat {
        let scene = UIApplication.shared.connectedScenes
            .first as? UIWindowScene
        return scene?.windows.first?.safeAreaInsets.top ?? 59
    }
}

// MARK: - Shapes

/// Per-corner rounded rectangle — API-compatible shim around SwiftUI's
/// native `UnevenRoundedRectangle` (iOS 16+). Keeps `UIRectCorner` call
/// sites working while dropping the UIKit `UIBezierPath` dependency.
/// Corner positions are mapped positionally (topLeft → topLeading, etc.),
/// which matches the previous behaviour in LTR layouts.
struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let r = radius
        let radii = RectangleCornerRadii(
            topLeading:     corners.contains(.topLeft)     ? r : 0,
            bottomLeading:  corners.contains(.bottomLeft)  ? r : 0,
            bottomTrailing: corners.contains(.bottomRight) ? r : 0,
            topTrailing:    corners.contains(.topRight)    ? r : 0
        )
        return UnevenRoundedRectangle(cornerRadii: radii, style: .continuous).path(in: rect)
    }
}


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

// MARK: - Strings

extension String {
    func widthWithFont( _ font: UIFont) -> CGFloat {
        let attributes = [NSAttributedString.Key.font: font]
        let size = self.size(withAttributes: attributes)
        return size.width
    }
}

/// Renders inline text with **quoted** segments styled differently.
/// Wrap text in `**` delimiters to mark it as quoted, e.g.:
/// `"Always forgetting what **Nine of Swords** means?"`
struct QuotedText<S1: ShapeStyle, S2: ShapeStyle>: View {
    let fullText: String
    let textStyle: S1
    let quoteTextStyle: S2

    var body: some View {
        parse(fullText)
    }

    private func parse(_ input: String) -> Text {
        let segments = input.components(separatedBy: "**")
        var result = Text("")
        for (index, segment) in segments.enumerated() {
            if segment.isEmpty { continue }
            if index % 2 == 1 {
                // Odd segments are between ** delimiters — quoted style
                result = Text("\(result) \(Text(segment).foregroundStyle(quoteTextStyle).bold())")
            } else {
                result = Text("\(result) \(Text(segment).foregroundStyle(textStyle))")
            }
        }
        return result
    }
}
