//
//  LowPolyMesh.swift
//  Project Stars
//
//  Blocky geometry, assembled from boxes and drawn without a 3D engine.
//

import CoreGraphics
import Foundation
import simd

/// A shape built out of axis-aligned boxes.
///
/// ## Why boxes, and why no SceneKit
///
/// A spectral head is on screen for well under a second, translucent, tinted to
/// one colour ramp, and perhaps 60 points tall. Topology and texture quality are
/// invisible at that size — silhouette and motion are the whole read. Boxes are
/// the one 3D form that can be *written* rather than sculpted, which makes twelve
/// of them a tractable list rather than an art commission.
///
/// Rendering them in a `Canvas` rather than SceneKit is deliberate too. The head
/// has to composite additively with the board underneath it and draw only in
/// palette colours; both are trivial here and awkward through a `SceneView`.
/// Flat-shaded quads with painter's-algorithm sorting is a hundred lines and
/// produces exactly the faceted look the style wants — no lighting model to
/// fight, no smooth normals to soften the edges.
struct LowPolyMesh {

    /// One box in head-local space, where `1` is roughly the head's half-height.
    struct Box {
        var center: SIMD3<Float>
        var size: SIMD3<Float>

        /// Rotation about the Z axis, in radians. Enough to angle a horn or a
        /// jaw without needing full transforms.
        var roll: Float = 0

        init(_ center: SIMD3<Float>, _ size: SIMD3<Float>, roll: Float = 0) {
            self.center = center
            self.size = size
            self.roll = roll
        }
    }

    var boxes: [Box]

    /// The mesh mirrored across X and appended to itself.
    ///
    /// Nearly every head is symmetrical, so horns, ears and eyes are authored
    /// once on one side.
    func mirrored() -> LowPolyMesh {
        LowPolyMesh(boxes: boxes + boxes.map { box in
            Box(
                SIMD3(-box.center.x, box.center.y, box.center.z),
                box.size,
                roll: -box.roll
            )
        })
    }

    // MARK: - Faces

    /// A single quad, ready to sort and fill.
    struct Face {
        var points: [CGPoint]

        /// Distance from the camera, for painter's ordering.
        var depth: Float

        /// Which of the three ramp tones this face takes.
        var tone: Int
    }

    /// The eight corners of a unit cube.
    private static let corners: [SIMD3<Float>] = [
        SIMD3(-1, -1, -1), SIMD3(1, -1, -1), SIMD3(1, 1, -1), SIMD3(-1, 1, -1),
        SIMD3(-1, -1, 1), SIMD3(1, -1, 1), SIMD3(1, 1, 1), SIMD3(-1, 1, 1),
    ]

    /// Its six faces, and the tone each takes.
    ///
    /// Tone is picked by which way a face points rather than by any light: up is
    /// brightest, sides mid, down and back deepest. That is what gives a flat
    /// palette fill its sense of form.
    private static let faces: [(indices: [Int], tone: Int)] = [
        ([3, 2, 6, 7], 2),   // top
        ([0, 1, 5, 4], 0),   // bottom
        ([4, 5, 6, 7], 1),   // front
        ([1, 0, 3, 2], 0),   // back
        ([0, 4, 7, 3], 1),   // left
        ([5, 1, 2, 6], 1),   // right
    ]

    /// Projects the mesh to 2D, furthest face first.
    ///
    /// - Parameters:
    ///   - yaw: Rotation about the vertical axis, in radians.
    ///   - pitch: Rotation about the horizontal axis.
    ///   - scale: Points per mesh unit.
    ///   - perspective: How strongly nearer geometry enlarges. `0` is isometric.
    func projected(
        yaw: Float,
        pitch: Float,
        scale: CGFloat,
        perspective: Float = 0.22
    ) -> [Face] {
        let cy = cos(yaw), sy = sin(yaw)
        let cp = cos(pitch), sp = sin(pitch)

        var out: [Face] = []
        out.reserveCapacity(boxes.count * 6)

        for box in boxes {
            let cr = cos(box.roll), sr = sin(box.roll)

            // Corner positions after the box's own roll, its offset, then the
            // whole mesh's yaw and pitch.
            let world: [SIMD3<Float>] = Self.corners.map { corner in
                var p = corner * box.size * 0.5

                // Roll about Z.
                p = SIMD3(p.x * cr - p.y * sr, p.x * sr + p.y * cr, p.z)
                p += box.center

                // Yaw about Y.
                p = SIMD3(p.x * cy + p.z * sy, p.y, -p.x * sy + p.z * cy)

                // Pitch about X.
                return SIMD3(p.x, p.y * cp - p.z * sp, p.y * sp + p.z * cp)
            }

            for face in Self.faces {
                let vertices = face.indices.map { world[$0] }

                // No back-face culling, deliberately. Getting the winding sign
                // right depends on the handedness of the projection and the
                // screen's flipped Y, and getting it backwards silently draws
                // *nothing*. Painter's ordering already hides the far side:
                // faces are opaque within the canvas and later ones overwrite
                // earlier ones.
                //
                // This is also why the translucency and the additive blend are
                // applied to the finished canvas rather than per face — inner
                // faces would otherwise accumulate and wash the shape out.
                let depth = vertices.reduce(Float(0)) { $0 + $1.z } / Float(vertices.count)

                let points = vertices.map { vertex -> CGPoint in
                    let shrink = 1 / (1 + (vertex.z + 2) * perspective * 0.25)
                    return CGPoint(
                        x: CGFloat(vertex.x * shrink) * scale,
                        y: CGFloat(-vertex.y * shrink) * scale
                    )
                }

                out.append(Face(points: points, depth: depth, tone: face.tone))
            }
        }

        // Painter's algorithm: furthest first. Good enough for convex-ish boxes
        // that never interpenetrate.
        return out.sorted { $0.depth > $1.depth }
    }
}
