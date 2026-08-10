//
//  SpectralHeads.swift
//  Project Stars
//
//  The apparition each sign summons when its Zodiaction fires.
//

import Foundation
import simd

/// Blocky heads, one per sign, authored as box assemblies.
///
/// Units are head-local: roughly `-1…1` across, with `0` at the centre of the
/// skull. Only one side of a symmetrical head is written — `mirrored()` supplies
/// the other, so a horn is authored once.
///
/// - Note: Aries is built. The rest fall back to `placeholder`, which is a
///   recognisable-but-generic muzzle — enough to see the effect working on every
///   sign before all twelve are drawn.
enum SpectralHeads {

    static func mesh(for zodiac: Zodiac) -> LowPolyMesh {
        switch zodiac {
        case .aries: ram
        default: placeholder
        }
    }

    // MARK: - Aries, the Ram

    /// Heavy brow, blunt muzzle, and the horns curling back and down.
    ///
    /// The horns are stepped boxes rather than a curve — a spiral written as six
    /// blocks reads as a spiral at this size, and stepping it keeps the faceting
    /// consistent with everything else.
    static let ram: LowPolyMesh = {
        var boxes: [LowPolyMesh.Box] = [
            // Skull.
            .init(SIMD3(0, 0.05, 0), SIMD3(0.95, 0.85, 0.9)),
            // Brow ridge, jutting forward over the eyes.
            .init(SIMD3(0, 0.34, 0.42), SIMD3(1.0, 0.26, 0.3)),
            // Muzzle.
            .init(SIMD3(0, -0.28, 0.5), SIMD3(0.55, 0.42, 0.6)),
            // Nose, a small step down at the end of the muzzle.
            .init(SIMD3(0, -0.42, 0.78), SIMD3(0.38, 0.22, 0.2)),
        ]

        // One horn, curling out then back. Mirrored for the other side.
        let horn: [(SIMD3<Float>, SIMD3<Float>, Float)] = [
            (SIMD3(0.52, 0.42, 0.05), SIMD3(0.3, 0.3, 0.3), 0.0),
            (SIMD3(0.74, 0.30, -0.05), SIMD3(0.28, 0.28, 0.28), 0.3),
            (SIMD3(0.82, 0.04, -0.14), SIMD3(0.25, 0.25, 0.25), 0.6),
            (SIMD3(0.72, -0.18, -0.18), SIMD3(0.22, 0.22, 0.22), 0.9),
            (SIMD3(0.52, -0.28, -0.12), SIMD3(0.19, 0.19, 0.19), 1.2),
            (SIMD3(0.36, -0.20, 0.02), SIMD3(0.15, 0.15, 0.15), 1.5),
        ]
        boxes += horn.map { .init($0.0, $0.1, roll: $0.2) }

        // Ear, tucked under the horn's root.
        boxes.append(.init(SIMD3(0.46, 0.02, -0.1), SIMD3(0.34, 0.16, 0.2), roll: -0.35))

        return LowPolyMesh(boxes: boxes).mirrored()
    }()

    // MARK: - Placeholder

    /// A generic muzzle, for signs whose head has not been authored yet.
    ///
    /// Deliberately plain rather than absent: an effect that only fires for one
    /// of twelve signs cannot be judged or tuned.
    static let placeholder: LowPolyMesh = {
        let boxes: [LowPolyMesh.Box] = [
            .init(SIMD3(0, 0.05, 0), SIMD3(0.9, 0.8, 0.85)),
            .init(SIMD3(0, -0.25, 0.45), SIMD3(0.5, 0.4, 0.55)),
            .init(SIMD3(0.42, 0.42, -0.05), SIMD3(0.22, 0.36, 0.22), roll: 0.25),
        ]
        return LowPolyMesh(boxes: boxes).mirrored()
    }()
}
