//
//  Constellation.swift
//  Project Stars
//
//  The sign written in stars, hanging in the air above the piece.
//

import CoreGraphics
import Foundation
import simd

/// A sign's constellation: stars in 3D, and the lines drawn between them.
///
/// ## Why this replaced the low-poly heads
///
/// A spectral animal head is a modelling problem twelve times over, and boxes —
/// the only 3D form that can be *written* rather than sculpted — read as
/// Minecraft rather than as N64. A constellation sidesteps the whole question:
/// it is points and lines, which is exactly what can be authored in a list, and
/// it is what a zodiac sign literally *is*. Nothing here has a silhouette to get
/// wrong.
///
/// ## Why it is still 3D
///
/// Flat, it would read as a decal stuck to the board. Turning slowly in space
/// above the piece, the depth is legible from the parallax alone — near stars
/// swing wider than far ones — and the figure reads as hanging in the air rather
/// than painted on it.
///
/// ## Coordinates
///
/// `1` is roughly the figure's half-height. X is right, Y is up, Z is toward the
/// viewer. Stars are authored in the plane the sign is normally drawn in, then
/// pushed to different depths so the rotation has something to reveal.
struct Constellation {

    /// One star, and how bright it burns.
    struct Star {
        var position: SIMD3<Float>

        /// Relative brightness and size. Real constellations have a few
        /// dominant stars and a lot of faint ones, and matching that is most of
        /// what makes a pattern read as a constellation rather than as a
        /// connect-the-dots.
        var magnitude: Float

        init(_ x: Float, _ y: Float, _ z: Float = 0, _ magnitude: Float = 1) {
            self.position = SIMD3(x, y, z)
            self.magnitude = magnitude
        }
    }

    var stars: [Star]

    /// Which stars are joined, as index pairs into `stars`.
    ///
    /// Order matters: the figure draws itself along these in sequence, so they
    /// are authored in the order a hand would trace them.
    var lines: [(Int, Int)]

    // MARK: - Projection

    /// A star projected to the canvas.
    struct PlacedStar {
        var point: CGPoint
        var depth: Float
        var magnitude: Float

        /// How much nearer stars are enlarged, already folded in.
        var scale: CGFloat
    }

    /// Projects every star, using the same camera the meshes used.
    ///
    /// - Parameters:
    ///   - yaw: Rotation about the vertical axis, in radians.
    ///   - pitch: Rotation about the horizontal axis.
    ///   - scale: Points per unit.
    ///   - perspective: How strongly nearer stars enlarge. `0` is isometric.
    func projected(
        yaw: Float,
        pitch: Float,
        scale: CGFloat,
        perspective: Float = 0.22
    ) -> [PlacedStar] {
        let cy = cos(yaw), sy = sin(yaw)
        let cp = cos(pitch), sp = sin(pitch)

        return stars.map { star in
            var p = star.position

            // Yaw about Y, then pitch about X. Same order as the meshes used,
            // so anything authored against that camera still reads the same.
            p = SIMD3(p.x * cy + p.z * sy, p.y, -p.x * sy + p.z * cy)
            p = SIMD3(p.x, p.y * cp - p.z * sp, p.y * sp + p.z * cp)

            let shrink = 1 / (1 + (p.z + 2) * perspective * 0.25)

            return PlacedStar(
                point: CGPoint(
                    x: CGFloat(p.x * shrink) * scale,
                    y: CGFloat(-p.y * shrink) * scale
                ),
                depth: p.z,
                magnitude: star.magnitude,
                scale: CGFloat(shrink)
            )
        }
    }
}

// MARK: - The twelve

extension Constellation {

    /// Stand-in for a sign with nothing authored yet.
    ///
    /// One star and no lines: it draws, it is obviously not a constellation, and
    /// it cannot be mistaken for a finished figure.
    static let placeholder = Constellation(
        stars: [Star(0, 0, 0, 1.4)],
        lines: []
    )

    /// The figure for a sign.
    ///
    /// Each is declared in that sign's own file, alongside its passives and its
    /// Zodiaction — this is only the dispatcher.
    static func figure(for zodiac: Zodiac) -> Constellation {
        zodiac.definition.constellation
    }
}
