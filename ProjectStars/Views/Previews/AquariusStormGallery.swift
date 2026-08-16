//
//  AquariusStormGallery.swift
//  Project Stars
//
//  Building the storm out of one band, and choosing how it sits on the piece.
//

import SwiftUI

/// A lens: the shape two overlapping circles share.
///
/// Drawn as two arcs rather than an ellipse because the point of a vesica is the
/// two corners — an ellipse tapers to nothing and reads as a cat's eye, where
/// this comes to a point and reads as something looking at you.
struct Vesica: Shape {

    /// How far apart the two circles sit, as a fraction of their radius.
    ///
    /// Lower is fatter. At `1` the circles pass through each other's centres,
    /// which is the classical vesica piscis.
    var separation: CGFloat = 1

    func path(in rect: CGRect) -> Path {
        let height = rect.height
        let width = max(rect.width, 0.001)

        // Radius of the two circles, from the lens' own proportions: a lens of
        // this width and height is cut by circles of this radius, sitting this
        // far either side of the middle.
        let half = height / 2
        let radius = (width * width / 4 + half * half) / max(width, 0.001)
        let centre = CGPoint(x: rect.midX, y: rect.midY)
        let offset = radius - width / 2

        var path = Path()
        let sweep = asin(min(max(half / radius, -1), 1))

        path.addArc(
            center: CGPoint(x: centre.x - offset, y: centre.y),
            radius: radius,
            startAngle: .radians(-Double(sweep)),
            endAngle: .radians(Double(sweep)),
            clockwise: false
        )
        path.addArc(
            center: CGPoint(x: centre.x + offset, y: centre.y),
            radius: radius,
            startAngle: .radians(.pi - Double(sweep)),
            endAngle: .radians(.pi + Double(sweep)),
            clockwise: false
        )
        path.closeSubpath()

        // Drawn on its side: the lens' long axis is vertical, so an eye is
        // taller than it is wide before it is slanted.
        return path.applying(
            CGAffineTransform(translationX: -centre.x, y: -centre.y)
                .concatenating(CGAffineTransform(rotationAngle: .pi / 2))
                .concatenating(CGAffineTransform(translationX: centre.x, y: centre.y))
        )
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

    /// How the storm sits on the figure.
    var blend: BlendMode = .plusLighter

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
                        loops: true
                    )
                    .rotationEffect(.degrees(turn(band, at: now)))
                    .offset(y: rise(band))
                    .opacity(fade(band))
                }
            }
            .frame(width: side, height: side)
            .blendMode(blend)
        }
    }

    // MARK: - The shape of the storm, from one number

    /// How much of a storm there is at all, `0`…`1`.
    private var strength: Double { Double(min(max(phase, 0), 10)) / 10 }

    /// More bands the fuller the meter — the funnel thickens rather than simply
    /// growing, so ten does not read as one at a larger size.
    private var bands: Int { max(Int((strength * 5).rounded()), phase > 0 ? 1 : 0) }

    /// Each band wider than the one below it, so the stack tapers into a funnel.
    private func bandSize(_ band: Int) -> CGFloat {
        let step = 1 + CGFloat(band) * (0.22 + 0.18 * strength)
        return side * 0.42 * step * (0.7 + 0.3 * strength)
    }

    /// Higher bands sit higher, which is what makes a cone out of rings.
    private func rise(_ band: Int) -> CGFloat {
        side * 0.16 - CGFloat(band) * side * 0.11 * (0.6 + 0.4 * strength)
    }

    /// Each band turns at its own rate, and the top ones faster.
    ///
    /// One speed for all of them reads as a single object spinning; a gradient
    /// reads as air moving at different speeds, which is what a funnel is.
    private func turn(_ band: Int, at now: TimeInterval) -> Double {
        let speed = (40 + Double(band) * 26) * (0.4 + 0.6 * strength)
        let direction: Double = band.isMultiple(of: 2) ? 1 : -1
        return now * speed * direction
    }

    /// The outermost band is the thinnest — the storm frays at its edge.
    private func fade(_ band: Int) -> Double {
        1 - Double(band) / Double(max(bands, 1)) * 0.45
    }
}

/// The pair of eyes inside the funnel.
struct StormEyes: View {

    /// How wide one eye is, in points.
    var width: CGFloat = 16

    /// How far apart they sit, centre to centre.
    var spacing: CGFloat = 20

    /// Slanted **toward** each other, which is what makes a pair of shapes read
    /// as a glare rather than as two marks.
    var slant: Double = 18

    var tint: Color = Palette.cyan

    var body: some View {
        HStack(spacing: spacing - width) {
            eye(turned: slant)
            eye(turned: -slant)
        }
    }

    private func eye(turned: Double) -> some View {
        Vesica()
            .fill(tint)
            .frame(width: width, height: width * 0.62)
            .rotationEffect(.degrees(turned))
            .shadow(color: tint.opacity(0.9), radius: width * 0.35)
            .shadow(color: tint.opacity(0.6), radius: width * 0.8)
    }
}

// MARK: - Gallery

/// Somewhere to try the storm's eleven phases and the ways it can sit on the
/// piece, without playing a run to a full meter eleven times.
struct AquariusStormGallery: View {

    @State private var phase = 10
    @State private var blend: BlendMode = .plusLighter
    @State private var showsEyes = true
    @State private var showsSilhouette = true

    private let blends: [(String, BlendMode)] = [
        ("LIGHTEN", .plusLighter),
        ("NORMAL", .normal),
        ("SCREEN", .screen),
        ("OVERLAY", .overlay),
        ("MULTIPLY", .multiply),
    ]

    var body: some View {
        VStack(spacing: 16) {
            Text("AQUARIUS — STORM")
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .tracking(4)
                .foregroundStyle(Palette.textSecondary)

            ZStack {
                Palette.coolBlack
                stack
            }
            .frame(width: 220, height: 220)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            controls
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.background)
    }

    /// The silhouette under the storm, the storm, and the eyes inside it.
    ///
    /// The figure goes **under** rather than over: the funnel is meant to be in
    /// front of the piece, which is what lets an additive blend read as light
    /// passing across it rather than as a decal stuck to it.
    private var stack: some View {
        ZStack {
            if showsSilhouette {
                PixelSprite(id: .piece(.aquarius)) { Color.clear }
                    .frame(width: 48, height: 96)
                    .colorEffect(ShaderLibrary.flatSilhouette(.color(Palette.midnight)))
                    .offset(y: -12)
            }

            if showsEyes {
                StormEyes(width: 18, spacing: 24)
                    .offset(y: -26)
            }

            AquariusStorm(phase: phase, blend: blend, side: 180, scale: 3)
        }
    }

    private var controls: some View {
        VStack(spacing: 12) {
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

            Picker("Blend", selection: $blend) {
                ForEach(blends, id: \.1) { name, mode in
                    Text(name).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            HStack(spacing: 16) {
                Toggle("EYES", isOn: $showsEyes)
                Toggle("BODY", isOn: $showsSilhouette)
            }
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .fixedSize()
        }
    }
}

#Preview {
    AquariusStormGallery()
}
