//
//  AquariusStormGallery.swift
//  Project Stars
//
//  Building the storm out of one band, and choosing how it sits on the piece.
//

import SwiftUI

/// A pointed oval — a football, the shape two overlapping circles share.
///
/// Two curves meeting at a point on the left and a point on the right. The
/// points are the whole reason for it: an ellipse tapers to a round end and
/// reads as a bubble, where this comes to a corner and reads as an eye.
struct Vesica: Shape {

    /// How fat the shape is between its points, as a fraction of its height.
    ///
    /// One fills the frame. Lower is a narrower, meaner eye.
    var fullness: CGFloat = 1

    func path(in rect: CGRect) -> Path {
        let left = CGPoint(x: rect.minX, y: rect.midY)
        let right = CGPoint(x: rect.maxX, y: rect.midY)
        // Beyond the frame, because a quadratic curve reaches only half way to
        // its control point — pulling it to twice the half-height is what makes
        // the curve actually touch the top and bottom of the rect.
        let bulge = rect.height * fullness

        var path = Path()
        path.move(to: left)
        path.addQuadCurve(to: right, control: CGPoint(x: rect.midX, y: rect.midY - bulge))
        path.addQuadCurve(to: left, control: CGPoint(x: rect.midX, y: rect.midY + bulge))
        path.closeSubpath()
        return path
    }
}

/// Aquarius' storm, assembled rather than drawn.
///
/// One band, stacked at several scales and turns, with the sign's own sprite on
/// top as a silhouette and a pair of eyes inside it. Everything about the funnel
/// is a function of `phase`, so the eleven states the meter can be in are eleven
/// arrangements of the same strip rather than eleven drawings — and the wider,
/// faster, taller storm at ten is the same art as the wisp at one.
///
/// - Note: Meant to be flattened once the look is settled. Several rotated,
///   blended copies of a sixteen-frame strip is a lot of composited layers per
///   frame, which is the cost that has bitten this project before.
struct AquariusStorm: View {

    /// `0` is the bare pot; `10` is the full tornado.
    var phase: Int = 10

    /// How tall the column stands, as a fraction of the square.
    var height: CGFloat = 0.3

    /// How far apart in the strip consecutive plates start. `1` spreads them
    /// evenly across the whole strip.
    var spread: Double = 1

    /// How many frames to drop off the **end** of the band's strip.
    ///
    /// The tail cells thin out to nothing, and a nearly-empty frame in a looped
    /// stack is a hole that comes round again. One drops the blank; more trims
    /// back into the thinning frames before it.
    var taper: Int = 0

    /// A multiplier on every plate's width.
    var bladeScale: CGFloat = 1

    /// Widens the funnel without making the plates taller — the plates are
    /// square, so scaling them alone raises the column as much as it spreads it.
    var width: CGFloat = 1

    /// How far the eye plates turn, either way.
    var eyeTurn: Double = 4

    /// What fraction of the stack's sway the eye plates take.
    ///
    /// A fraction rather than all of it: the eye is deeper in the column than
    /// the wall around it, and things further away move less.
    var eyeSway: CGFloat = 0.35

    /// How big the second eye plate is against the first.
    var eyeTwinScale: CGFloat = 0.75

    /// How much wider an eye plate is than the widest of the stack.
    var eyeScale: CGFloat = 0.75

    /// How each eye plate sits against the rest. Two of them, because one
    /// darkening pass reads as a stain and two crossing at different heights
    /// read as a gap you are looking through.
    var eyeBlend: BlendMode = .multiply
    var eyeTwinBlend: BlendMode = .multiply

    /// Where each sits, as a fraction of the square.
    var eyeY: CGFloat = 0
    var eyeTwinY: CGFloat = 0.06

    /// Size of the square this fills, in points.
    var side: CGFloat = 96

    /// Whole-pixel scale, for art-pixel measurements.
    var scale: CGFloat = 3

    var body: some View {
        TimelineView(.animation) { timeline in
            let now = timeline.date.timeIntervalSinceReferenceDate

            ZStack {
                ForEach(0..<bands, id: \.self) { band in
                    EffectSpriteView(
                        effect: .aquariusArmor,
                        tileSize: bandSize(band),
                        start: .distantPast,
                        loops: true,
                        // Each plate a different way through the strip.
                        //
                        // The band ends on an empty cell, so plates in step all
                        // vanish on the same frame and the tornado blinks. Held
                        // apart, there is always something at every height.
                        clock: { $0 + self.stagger(band) },
                        frameCount: self.played
                    )
                    .rotationEffect(.degrees(turn(band, at: now) + self.tilt(band)))
                    .offset(x: sway(band, at: now), y: rise(band))
                }

                // The eye of the storm.
                //
                // One more plate, wider than any below it, near the top, and
                // deliberately **still** — everything else shakes, so the one
                // thing that does not is where the eye goes. Darkened against
                // the stack rather than drawn darker, so it reads as depth
                // through the wall of air instead of as a hole cut in it.
                if bands > 0 {
                    eyePlate(
                        blend: eyeBlend, at: eyeY, size: 1,
                        turn: eyeTurn, speed: 0.9, at: now
                    )
                    eyePlate(
                        blend: eyeTwinBlend, at: eyeTwinY, size: eyeTwinScale,
                        turn: -eyeTurn * 1.3, speed: 1.3, at: now
                    )
                }
            }
            .frame(width: side, height: side)
            .scaleEffect(x: width, y: 1)
        }
    }

    // MARK: - The shape of the storm, from one number

    /// How much of a storm there is at all, `0`…`1`.
    private var strength: Double { Double(min(max(phase, 0), 10)) / 10 }

    /// How many plates are in the stack. A fuller meter is a taller, denser
    /// storm — they overlap, so more of them fills the column in as well as
    /// raising it.
    private var bands: Int {
        phase <= 0 ? 0 : max(Int((strength * 13).rounded()), 3)
    }

    /// One of the two plates that make the eye of the storm.
    ///
    /// They turn, but barely and out of step with each other — immobile was
    /// wrong, because the stack behind them never stops and a still shape in
    /// front of moving ones reads as a decal rather than as a part of it.
    @ViewBuilder
    private func eyePlate(
        blend: BlendMode,
        at height: CGFloat,
        size: CGFloat,
        turn: Double,
        speed: Double,
        at now: TimeInterval
    ) -> some View {
        EffectSpriteView(
            effect: .aquariusArmor,
            tileSize: bandSize(bands - 1) * eyeScale * size,
            start: .distantPast,
            loops: true,
            clock: { $0 + self.stagger(bands - 1) * (speed > 1 ? 0.35 : 0.6) },
            frameCount: played
        )
        .colorEffect(ShaderLibrary.flatSilhouette(.color(Palette.midnight)))
        .rotationEffect(.degrees(sin(now * speed) * turn))
        // Riding the same sway as the plates around it, and then some: an eye
        // that holds still while the wall of air moves reads as a hole in the
        // picture rather than a hole in the storm.
        .offset(
            x: sway(bands - 1, at: now) * eyeSway,
            y: rise(bands - 1) + side * height
        )
        .blendMode(blend)
    }

    /// Frames actually played, after the taper.
    private var played: Int {
        max(EffectSprite.aquariusArmor.frames - max(taper, 0), 1)
    }

    /// Where in the strip this plate starts, in seconds.
    ///
    /// Spread across the strip's whole length rather than by a fixed step, so
    /// however many plates there are they still cover it evenly.
    private func stagger(_ band: Int) -> TimeInterval {
        // Measured on what is *played*, not on what was drawn — trimming the
        // tail shortens the loop, and a stagger spread over the old length
        // would leave the plates bunched.
        let length = Double(played) * EffectSprite.aquariusArmor.rate.frameDuration
        return length * spread * Double(band) / Double(max(bands, 1))
    }

    /// A fixed few degrees of lean, different for every plate.
    ///
    /// Deterministic rather than random-per-frame: a plate that re-rolls its
    /// angle every draw flickers. This is the plate being *built* crooked, and
    /// the shake happens on top of it.
    private func tilt(_ band: Int) -> Double {
        let hash = sin(Double(band) * 12.9898) * 43_758.5453
        return (hash - hash.rounded(.down)) * 14 - 7
    }

    /// **Widest at the top.** A tornado is a cone standing on its point, so
    /// band `0` at the bottom is the narrow end and each one above it is wider.
    private func bandSize(_ band: Int) -> CGFloat {
        let up = CGFloat(band) / CGFloat(max(bands - 1, 1))
        let narrow = side * 0.30
        let wide = side * (0.86 + 0.30 * strength)
        return (narrow + (wide - narrow) * up) * bladeScale
    }

    /// The funnel's own horizontal stretch, applied to the stack as a whole.
    fileprivate var spreadWide: CGFloat { width }

    /// Stacked close together — the plates touch, so the stack reads as one
    /// column of air rather than as a set of separate rings.
    private func rise(_ band: Int) -> CGFloat {
        let step = side * height / CGFloat(max(bands - 1, 1))
        return side * 0.22 - CGFloat(band) * step
    }

    /// **Shaking, not spinning.**
    ///
    /// Each plate jitters a few degrees either side of straight, on its own
    /// count, rather than turning continuously. A spin reads as a solid object
    /// rotating; a shake reads as the plate being buffeted, and a stack of them
    /// slightly out of step with each other is what makes the column look like
    /// it is being driven from below.
    private func turn(_ band: Int, at now: TimeInterval) -> Double {
        let amplitude = (3 + Double(band) * 0.8) * (0.4 + 0.6 * strength)
        let speed = 7 + Double(band) * 1.7
        let phaseOffset = Double(band) * 1.1
        return sin(now * speed + phaseOffset) * amplitude
    }

    /// And a matching sway across, so a plate is not shaking on the spot.
    private func sway(_ band: Int, at now: TimeInterval) -> CGFloat {
        let amplitude = side * 0.012 * CGFloat(1 + band) * CGFloat(0.4 + 0.6 * strength)
        return CGFloat(cos(now * (5.5 + Double(band) * 1.3) + Double(band) * 0.7)) * amplitude
    }

}

/// The pair of eyes inside the funnel.
struct StormEyes: View {

    /// How wide one eye is, in points.
    var width: CGFloat = 16

    /// How far apart they sit, centre to centre.
    var spacing: CGFloat = 20

    /// Slanted so the **inner** ends drop, which is a scowl. Settled at 35.
    var slant: Double = 35

    /// How narrow the eye is closed, as a fraction of its width. Settled.
    var slit: CGFloat = 0.35

    /// How hard they burn, against the settled look.
    var glow: CGFloat = 1

    /// Purple: air's colour everywhere else in the game.
    var tint: Color = ElementFX.ramp(for: .air).bright

    var body: some View {
        HStack(spacing: spacing - width) {
            // Left eye's inner end is its right one, so a positive turn drops
            // it. The right eye is the mirror.
            eye(turned: slant)
            eye(turned: -slant)
        }
    }

    private func eye(turned: Double) -> some View {
        // A flat fill with blurred copies of *itself* stacked behind it,
        // additively. `shadow` could only ever darken outward from the shape,
        // which is why turning the knob up did nothing to the purple in the
        // middle — the fill was never part of what was glowing.
        let shape = Vesica(fullness: 0.72)
            .fill(tint)
            .frame(width: width, height: width * slit)
            .rotationEffect(.degrees(turned))

        return ZStack {
            // Each copy added to the ones under it, not just the finished stack
            // added to the board. Inside a group the layers composite normally,
            // so however many were piled up the middle never got past the
            // purple it started at — which is why turning the knob up only ever
            // grew the halo.
            ForEach(0..<3, id: \.self) { step in
                shape
                    .blur(radius: width * (0.18 + CGFloat(step) * 0.35) * max(glow, 0))
                    .opacity(Double(glow) / Double(step + 1))
                    .blendMode(.plusLighter)
            }

            shape.blendMode(.plusLighter)

            // A white core that comes up with the knob, so the middle burns out
            // rather than merely getting a brighter surround. Purple added to
            // purple is a brighter purple and stops there; reaching white takes
            // the other two channels.
            shape
                .foregroundStyle(Palette.white)
                .opacity(max(Double(glow) - 0.6, 0) * 0.5)
                .blendMode(.plusLighter)
        }
        .compositingGroup()
    }
}

// MARK: - Gallery

/// Somewhere to try the storm's eleven phases and the ways it can sit on the
/// piece, without playing a run to a full meter eleven times.
struct AquariusStormGallery: View {

    @State private var phase = 10
    @State private var blend: BlendMode = .exclusion
    @State private var showsEyes = true
    @State private var showsSilhouette = true
    @State private var glow: Double = 1
    @State private var eyeScale: Double = 0.75
    @State private var eyeBlend: BlendMode = .hardLight
    @State private var figureScale: Double = 1.5
    @State private var figureTurn: Double = 5
    @State private var groupScale: Double = 0.75
    @State private var width: Double = 1
    @State private var eyeTurn: Double = 8
    @State private var eyeTwinScale: Double = 0.75
    @State private var eyeSway: Double = 0.35
    @State private var eyeOffset: Double = -54
    @State private var figureY: Double = -125
    @State private var eyeY: Double = -0.05
    @State private var eyeTwinY: Double = -0.1
    @State private var eyeTwinBlend: BlendMode = .plusDarker
    @State private var spread: Double = 2
    @State private var height: Double = 0.15
    @State private var taper: Double = 5
    @State private var bladeScale: Double = 0.8

    private let blends: [(String, BlendMode)] = [
        ("LIGHTEN", .plusLighter),
        ("NORMAL", .normal),
        ("SCREEN", .screen),
        ("OVERLAY", .overlay),
        ("MULTIPLY", .multiply),
    ]

    var body: some View {
        VStack(spacing: 10) {
            Text("AQUARIUS — STORM")
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .tracking(4)
                .foregroundStyle(Palette.textSecondary)

            ZStack {
                Palette.coolBlack
                // Real tiles behind it, at the size the board draws them, so
                // "how big is this" has an answer in the picture rather than in
                // a number — a storm that looks right against nothing can still
                // be three squares wide.
                boardGrid
                stack
            }
            .frame(width: 330, height: 330)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            // The knobs scroll; the storm does not.
            //
            // Every knob added pushed the thing being judged further off the
            // screen, which is the one part of a gallery that must never move.
            ScrollView {
                controls.padding(.bottom, 24)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.background)
    }

    /// The figure, carried by the storm rather than standing in it.
    ///
    /// Turning, rising and breathing, all on their own periods so none of the
    /// three ever lines up with another — three motions in step read as one
    /// motion, which is the thing that makes something look mechanical.
    private struct FloatingSilhouette: View {

        let blend: BlendMode

        /// Drawn with him, so they turn, rise and breathe as he does.
        ///
        /// Kept outside the blend but inside the transform: the eyes are his,
        /// not the storm's, and eyes that stay level while the head they belong
        /// to leans are the fastest way to make something look pasted on.
        var showsEyes = true
        var glow: CGFloat = 1
        var eyeOffset: CGFloat = -54

        /// How far he turns either way, in degrees.
        var turn: Double = 12

        /// How big he is drawn, against the storm around him.
        var size: CGFloat = 1

        /// Where he hangs, as points from the middle.
        var height: CGFloat = -74

        var body: some View {
            TimelineView(.animation) { timeline in
                let now = timeline.date.timeIntervalSinceReferenceDate
                let sway = sin(now / 5.2 * 2 * .pi) * turn
                let lift = sin(now / 3.7 * 2 * .pi) * 14
                let breath = 1 + sin(now / 4.3 * 2 * .pi) * 0.1

                ZStack {
                    PixelSprite(id: .piece(.aquarius)) { Color.clear }
                        .frame(width: 132 * size, height: 264 * size)
                        .colorEffect(ShaderLibrary.flatSilhouette(.color(Palette.midnight)))
                        .blendMode(blend)

                    if showsEyes {
                        StormEyes(width: 40 * size, spacing: 46 * size, glow: glow)
                            .offset(y: eyeOffset * size)
                    }
                }
                .scaleEffect(breath)
                .rotationEffect(.degrees(sway))
                // Raised: he hangs in the funnel rather than standing under it,
                // which is the whole picture — something held up by the storm,
                // not something the storm is happening around.
                .offset(y: height + lift)
            }
        }
    }

    /// A patch of Terra at board scale, to judge the storm against.
    private var boardGrid: some View {
        let tile: CGFloat = 66
        return VStack(spacing: 0) {
            ForEach(0..<5, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<5, id: \.self) { column in
                        TileView(
                            tile: Tile(),
                            plane: .terra,
                            shade: .at(GridPoint(column, row)),
                            size: tile
                        )
                        .frame(width: tile, height: tile)
                    }
                }
            }
        }
        .opacity(0.5)
    }

    /// The silhouette under the storm, the storm, and the eyes inside it.
    ///
    /// The figure goes **under** rather than over: the funnel is meant to be in
    /// front of the piece, which is what lets an additive blend read as light
    /// passing across it rather than as a decal stuck to it.
    private var stack: some View {
        ZStack {
            AquariusStorm(
                phase: phase,
                height: CGFloat(height),
                spread: spread,
                taper: Int(taper.rounded()),
                bladeScale: CGFloat(bladeScale),
                width: CGFloat(width),
                eyeTurn: eyeTurn,
                eyeSway: CGFloat(eyeSway),
                eyeTwinScale: CGFloat(eyeTwinScale),
                eyeScale: CGFloat(eyeScale),
                eyeBlend: eyeBlend,
                eyeTwinBlend: eyeTwinBlend,
                eyeY: CGFloat(eyeY),
                eyeTwinY: CGFloat(eyeTwinY),
                side: 300,
                scale: 4
            )

            // **The silhouette is on top and it is the thing that blends.**
            //
            // Under a mode like multiply a black shape drawn over the funnel
            // darkens what is behind it instead of covering it, which is what
            // makes the figure look like it is *inside* the storm rather than
            // standing in front of a picture of one. Blending the wind instead
            // — with the piece behind it — can only ever look like weather
            // painted over a statue.
            if showsSilhouette {
                // Big. The storm is a bluff about how large the thing inside
                // it is, and a small silhouette gives that away before the
                // reveal does.
                FloatingSilhouette(
                    blend: blend,
                    showsEyes: showsEyes,
                    glow: CGFloat(glow),
                    eyeOffset: CGFloat(eyeOffset),
                    turn: figureTurn,
                    size: CGFloat(figureScale),
                    height: CGFloat(figureY)
                )
            }
        }
        // Grouped first, then scaled as one.
        //
        // The whole assembly against the board is a different question from any
        // of its parts against each other — a funnel that reads right on its own
        // can still be the wrong size for a square. Scaling the group keeps
        // every proportion inside it exactly as tuned.
        .compositingGroup()
        .scaleEffect(CGFloat(groupScale))
    }

    /// One labelled slider with the number beside it.
    private func knob(
        _ name: String,
        _ value: Binding<Double>,
        _ range: ClosedRange<Double>,
        _ unit: String,
        step: Double? = nil
    ) -> some View {
        HStack(spacing: 8) {
            Text(name)
                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                .foregroundStyle(Palette.textSecondary)
                .frame(width: 58, alignment: .leading)

            // A count of frames is a count. Without the step the slider lands
            // on 1.37 frames, which the taper then has to round anyway — so the
            // number on screen disagrees with what is being drawn.
            if let step {
                Slider(value: value, in: range, step: step).tint(Palette.purple)
            } else {
                Slider(value: value, in: range).tint(Palette.purple)
            }

            // Typed, for the same reason the board's dials needed it: a slider
            // is a couple of hundredths per pixel across its track, so landing
            // on a chosen value is luck.
            TextField(
                "",
                value: value,
                format: .number.precision(.fractionLength(step == nil ? 0...3 : 0...0))
            )
            .textFieldStyle(.plain)
            .keyboardType(.numbersAndPunctuation)
            .multilineTextAlignment(.trailing)
            .font(.system(size: 9, weight: .heavy, design: .monospaced))
            .foregroundStyle(Palette.white)
            .frame(width: 42)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(RoundedRectangle(cornerRadius: 4).fill(Palette.midnight.opacity(0.6)))

            Text(unit)
                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                .foregroundStyle(Palette.textSecondary)
                .frame(width: 12, alignment: .leading)
        }
    }

    private var controls: some View {
        VStack(spacing: 6) {
            HStack {
                Text("PHASE \(phase)")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .foregroundStyle(Palette.white)
                    .frame(width: 78, alignment: .leading)

                Slider(
                    value: Binding(
                        get: { Double(phase) },
                        set: { phase = Int($0.rounded()) }
                    ),
                    in: 0...10,
                    step: 1
                )
                .tint(Palette.cyan)
            }

            // Homed on the settled values, with room either side of each.
            knob("GLOW", $glow, 0...3, "x")
            knob("STAGGER", $spread, 0.5...3.5, "x")
            knob("HEIGHT", $height, 0.02...0.3, "x")
            knob("BLADE", $bladeScale, 0.4...1.2, "x")
            knob("TAPER", $taper, 2...8, "f", step: 1)
            knob("EYE", $eyeScale, 0.8...2.2, "x")
            knob("FIGURE", $figureScale, 0.6...2.4, "x")
            knob("TURN", $figureTurn, 0...40, "°")
            knob("WIDTH", $width, 0.6...2, "x")
            knob("EYE TURN", $eyeTurn, 0...30, "°")
            knob("EYE2", $eyeTwinScale, 0.4...1.4, "x")
            knob("EYE SWAY", $eyeSway, 0...1, "x")
            knob("GLOW Y", $eyeOffset, -140...20, "pt")
            knob("EYE Y", $eyeY, -0.3...0.3, "x")
            knob("EYE2 Y", $eyeTwinY, -0.3...0.3, "x")
            knob("BODY Y", $figureY, -160...40, "pt")
            knob("ALL", $groupScale, 0.3...2, "x")

            Picker("Blend", selection: $blend) {
                ForEach(BlendMode.allCases, id: \.self) { mode in
                    Text(String(describing: mode)).tag(mode)
                }
            }

            Picker("Eye blend", selection: $eyeBlend) {
                ForEach(BlendMode.allCases, id: \.self) { mode in
                    Text(String(describing: mode)).tag(mode)
                }
            }

            Picker("Eye 2 blend", selection: $eyeTwinBlend) {
                ForEach(BlendMode.allCases, id: \.self) { mode in
                    Text(String(describing: mode)).tag(mode)
                }
            }
            //.pickerStyle(.segmented)

            HStack(spacing: 16) {
                Toggle("EYES", isOn: $showsEyes)
                Toggle("BODY", isOn: $showsSilhouette)
            }
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .fixedSize()
        }
    }
}

extension BlendMode: CaseIterable {
    public static var allCases: [BlendMode] = [
        .normal,
        .multiply,
        .screen,
        .overlay,
        .darken,
        .lighten,
        .colorDodge,
        .colorBurn,
        .softLight,
        .hardLight,
        .difference,
        .exclusion,
        .hue,
        .saturation,
        .color,
        .luminosity,
        .plusDarker,
        .plusLighter
    ]
}

#Preview {
    AquariusStormGallery()
}
