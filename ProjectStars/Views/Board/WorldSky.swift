//
//  WorldSky.swift
//  Project Stars
//
//  One sky, the whole height of the world.
//

import SwiftUI

/// The backdrop behind every row of the column at once.
///
/// ## Why one sky and not one per plane
///
/// There used to be two: a night sky for Astra and a daylight one for Terra,
/// each the size of its own square, each ending abruptly at its own edge. Two
/// skies cannot be travelled between — the moment the camera left one square it
/// would be looking at the join. That is why every trip between planes needed
/// something drawn over it.
///
/// This is one field the height of the world. Falling out of Astra takes you
/// down through it and into Terra, and the reason that reads as one continuous
/// place is that it *is* one: the same rectangle, the same gradient, seen from
/// further down.
///
/// ## What is in it
///
/// A single vertical gradient, dark at both ends and daylight in the middle
/// where Terra sits — so depth reads as *distance from the light*, which is the
/// same thing the world's layout says. On top of that, two decorated bands,
/// each confined to the row it belongs to and each asleep when that row is off
/// screen: stars over Astra, clouds over Terra.
///
/// Everything below the underground is dark again, which is what makes the seam
/// work — see `World.wrapped(_:)`.
struct WorldSky: View {

    /// Edge length of one plane-square, in points.
    let side: CGFloat

    /// Where the camera is, in rows. Only used to decide what may sleep.
    let camera: Double

    /// The ambient clock, which stops while the game waits on the player.
    var clock: (TimeInterval) -> TimeInterval = { $0 }

    var body: some View {
        ZStack(alignment: .top) {
            LinearGradient(stops: Self.stops, startPoint: .top, endPoint: .bottom)
                .frame(width: side, height: side * CGFloat(World.rows))

            // Each band is a square the size of a plane-square, placed at its
            // own row. Inside one, everything is drawn against `side` exactly as
            // it was when a sky *was* one square — which is the point: neither
            // field had to be re-tuned to move into the column.
            band(row: World.row(of: .astra)) { stars }
            band(row: World.row(of: .terra)) { clouds }
        }
        .frame(width: side, height: side * CGFloat(World.rows), alignment: .top)
        .allowsHitTesting(false)
    }

    /// One decorated row, in its place.
    @ViewBuilder
    private func band<Content: View>(
        row: Int,
        @ViewBuilder content: () -> Content
    ) -> some View {
        // Mounted only while it is being looked at. A canvas asking for sixty
        // frames a second behind a row nobody can see is the bug that cost this
        // project a week, and a column nine rows tall has seven more places for
        // it to hide than a screen with two squares did.
        if World.isVisible(row: row, from: camera) {
            content()
                .frame(width: side, height: side)
                .clipped()
                .offset(y: CGFloat(row) * side)
        }
    }

    // MARK: - The gradient

    /// Dark, daylight, dark — with the light where Terra is.
    ///
    /// Every stop is a row index divided by the column's height, so the sky
    /// cannot drift out of step with the layout it is describing. The only two
    /// chosen numbers are how far the light reaches above and below Terra's own
    /// square, and they are in plane-squares because that is the unit the rest
    /// of this file thinks in.
    private static var stops: [Gradient.Stop] {
        let rows = Double(World.rows)
        let terra = Double(World.row(of: .terra))

        return [
            .init(color: Palette.coolBlack, location: 0),
            .init(color: Palette.coolBlack, location: (terra - dawn) / rows),
            .init(color: Palette.cyan, location: (terra + 0.5) / rows),
            .init(color: Palette.coolBlack, location: (terra + 1 + dusk) / rows),
            .init(color: Palette.coolBlack, location: 1),
        ]
    }

    /// How far above Terra's square the daylight begins, in plane-squares.
    ///
    /// More than below it: you can see the light you are falling towards from
    /// further away than you can see it behind you once you are past.
    static let dawn: Double = 1.5

    /// And how far below it the dark closes back in.
    static let dusk: Double = 0.75

    // MARK: - Astra's band

    /// A dark field with stars of three brightnesses, each twinkling on its own
    /// clock.
    private var stars: some View {
        TimelineView(
            .animation(minimumInterval: 1 / GameRules.ambientFrameRate)
        ) { timeline in
            Canvas { context, size in
                let now = clock(timeline.date.timeIntervalSinceReferenceDate)

                for star in Self.starField {
                    let twinkle = sin(now / star.period * 2 * .pi + star.phase)
                    // Never fully out — a star that vanishes reads as a dropped
                    // frame rather than as twinkling.
                    let brightness = 0.45 + 0.55 * (twinkle + 1) / 2

                    // Faded by how far down the band it sits, computed here
                    // rather than by masking the canvas.
                    //
                    // A `.mask` forces the whole thing through an offscreen
                    // pass, and this canvas redraws every frame — so it cost an
                    // extra full-size render sixty times a second for a fade
                    // that is one multiply per star.
                    let gone = max(0.01, GameRules.astraSkyFade - GameRules.astraSkyFadeWidth)
                    let depth = 1 - min(max((star.y - gone * 0.5) / (gone * 0.5), 0), 1)
                    guard depth > 0 else { continue }

                    let point = CGPoint(x: star.x * size.width, y: star.y * size.height)
                    let radius = star.size * (0.85 + 0.3 * brightness)

                    context.fill(
                        Path(ellipseIn: CGRect(
                            x: point.x - radius, y: point.y - radius,
                            width: radius * 2, height: radius * 2
                        )),
                        with: .color(star.colour.opacity(brightness * depth))
                    )
                }
            }
        }
    }

    /// One star's fixed place and its own rhythm.
    private struct Star {
        let x: Double
        let y: Double
        let size: Double
        let period: Double
        let phase: Double
        let colour: Color
    }

    /// Generated once from a fixed seed, so the sky is the same every launch —
    /// a constellation that reshuffled on each run would read as noise.
    private static let starField: [Star] = {
        var rng = SeededRandom(seed: 0x5EED_57A5)
        func unit() -> Double { Double(rng.next() % 10_000) / 10_000 }

        return (0..<GameRules.astraStarCount).map { _ in
            let roll = unit()
            let colour: Color = roll < 0.7 ? Palette.white
                : (roll < 0.9 ? Palette.lightGray : Palette.cyan)

            return Star(
                x: unit(),
                y: unit(),
                size: 0.6 + unit() * 1.4,
                period: 1.6 + unit() * 3.4,
                phase: unit() * 2 * .pi,
                colour: colour
            )
        }
    }()

    // MARK: - Terra's band

    /// Clouds drifting across the daylight.
    private var clouds: some View {
        TimelineView(.animation) { timeline in
            #if DEBUG
            let _ = RenderTally.tick("Sky")
            #endif
            let now = clock(timeline.date.timeIntervalSinceReferenceDate)

            ZStack {
                ForEach(Array(Self.cloudField.enumerated()), id: \.offset) { _, cloud in
                    CloudShape()
                        .fill(cloud.colour)
                        .frame(width: side * cloud.width, height: side * cloud.width * 0.42)
                        .position(x: drift(cloud: cloud, at: now), y: side * cloud.y)
                }
            }
        }
    }

    private struct Cloud {
        let y: Double
        let width: Double
        let speed: Double
        let offset: Double
        let colour: Color
    }

    private static let cloudField: [Cloud] = {
        var rng = SeededRandom(seed: 0xC10D_5EED)
        func unit() -> Double { Double(rng.next() % 10_000) / 10_000 }

        return (0..<GameRules.terraCloudCount).map { index in
            Cloud(
                y: 0.08 + unit() * 0.8,
                width: 0.28 + unit() * 0.34,
                speed: 0.004 + unit() * 0.008,
                offset: unit(),
                colour: index % 3 == 0 ? Palette.ice : Palette.white
            )
        }
    }()

    /// Wraps a cloud around the band so it never runs out of them.
    private func drift(cloud: Cloud, at now: TimeInterval) -> CGFloat {
        let span = side * (1 + cloud.width * 2)
        let travelled = (now * cloud.speed + cloud.offset).truncatingRemainder(dividingBy: 1)
        return CGFloat(travelled) * span - side * CGFloat(cloud.width)
    }
}

// MARK: - CloudShape

/// A cloud built from overlapping circles, in the shape pixel art tends to use:
/// a flat base with a few lumps above it.
///
/// Moved here whole when the two per-plane skies became one column-tall one —
/// the drawing did not change, only what is behind it.
struct CloudShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let base = rect.maxY
        let unit = rect.width

        // Flat underside.
        path.addRect(CGRect(
            x: rect.minX + unit * 0.08,
            y: base - rect.height * 0.42,
            width: unit * 0.84,
            height: rect.height * 0.42
        ))

        // Lumps, largest in the middle.
        let lumps: [(x: Double, r: Double)] = [(0.24, 0.22), (0.5, 0.32), (0.74, 0.24)]
        for lump in lumps {
            let radius = unit * lump.r
            path.addEllipse(in: CGRect(
                x: rect.minX + unit * lump.x - radius,
                y: base - rect.height * 0.42 - radius + rect.height * 0.16,
                width: radius * 2,
                height: radius * 2
            ))
        }
        return path
    }
}
