//
//  SkyView.swift
//  Project Stars
//
//  What sits behind the board on each plane.
//

import SwiftUI

/// The backdrop for a plane, filling the whole upper square.
///
/// Astra is night: the palette's darkest colour with stars twinkling in it.
/// Terra is daylight seen from below the clouds.
///
/// **Everything here is a flat palette colour.** No gradients — interpolating
/// between two palette entries produces colours that are in neither, and the
/// upper half of the screen is meant to be strictly on-palette. Depth comes from
/// bands and layering instead.
struct SkyView: View {

    let plane: Plane

    /// Edge length of the square this fills, in points.
    let side: CGFloat

    /// The ambient clock, which stops while the game waits on the player.
    ///
    /// Ambient motion carrying on under a frozen game is the clearest possible
    /// signal that nothing is waiting on anything. See
    /// `GameSession.ambientClock(at:)`.
    var clock: (TimeInterval) -> TimeInterval = { $0 }


    var body: some View {
        ZStack {
            switch plane {
            case .astra: night
            case .terra: day
            }
        }
        .frame(width: side, height: side)
        .clipped()
        .allowsHitTesting(false)
    }

    // MARK: - Astra

    /// A dark field with stars of three brightnesses, each twinkling on its own
    /// clock.
    ///
    /// `coolBlack` rather than true black: the palette's darkest entry, so the
    /// board never sits on a colour the art could not contain.
    private var night: some View {
        ZStack {
            Palette.coolBlack

            TimelineView(.animation) { timeline in
                Canvas { context, size in
                    let now = clock(timeline.date.timeIntervalSinceReferenceDate)

                    for star in Self.stars {
                        let twinkle = sin(now / star.period * 2 * .pi + star.phase)
                        // Never fully out — a star that vanishes reads as a
                        // dropped frame rather than as twinkling.
                        let brightness = 0.45 + 0.55 * (twinkle + 1) / 2

                        let point = CGPoint(x: star.x * size.width, y: star.y * size.height)
                        let radius = star.size * (0.85 + 0.3 * brightness)

                        context.fill(
                            Path(ellipseIn: CGRect(
                                x: point.x - radius, y: point.y - radius,
                                width: radius * 2, height: radius * 2
                            )),
                            with: .color(star.colour.opacity(brightness))
                        )
                    }
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
    private static let stars: [Star] = {
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

    // MARK: - Terra

    /// Daylight, in two flat bands with clouds drifting across them.
    private var day: some View {
        ZStack {
            Palette.lightBlue

            // A paler band up top, where the sky would be brightest. A hard edge
            // rather than a gradient keeps it on-palette.
            VStack(spacing: 0) {
                Palette.cyan.frame(height: side * 0.34)
                Color.clear
            }

            TimelineView(.animation) { timeline in
                let now = clock(timeline.date.timeIntervalSinceReferenceDate)

                ZStack {
                    ForEach(Array(Self.clouds.enumerated()), id: \.offset) { _, cloud in
                        CloudShape()
                            .fill(cloud.colour)
                            .frame(width: side * cloud.width, height: side * cloud.width * 0.42)
                            .position(
                                x: drift(cloud: cloud, at: now),
                                y: side * cloud.y
                            )
                    }
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

    private static let clouds: [Cloud] = {
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

    /// Wraps a cloud around the square so the sky never runs out of them.
    private func drift(cloud: Cloud, at now: TimeInterval) -> CGFloat {
        let span = side * (1 + cloud.width * 2)
        let travelled = (now * cloud.speed + cloud.offset).truncatingRemainder(dividingBy: 1)
        return CGFloat(travelled) * span - side * CGFloat(cloud.width)
    }
}

// MARK: - CloudShape

/// A cloud built from overlapping circles, in the shape pixel art tends to use:
/// a flat base with a few lumps above it.
private struct CloudShape: Shape {
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
