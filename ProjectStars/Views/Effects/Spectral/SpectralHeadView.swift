//
//  SpectralHeadView.swift
//  Project Stars
//
//  The apparition that rises over a piece when its Zodiaction fires.
//

import SwiftUI

/// Draws a `LowPolyMesh` as a translucent, additive apparition.
///
/// Software-rendered into a `Canvas`: the mesh is projected, painter-sorted and
/// filled with flat palette colours. No lighting model, because the tone of a
/// face comes from which way it points — which is what keeps a 3D form reading
/// as part of a fixed-palette pixel-art game rather than as an import from a
/// different one.
///
/// The whole thing is a pure function of elapsed time, like every other effect
/// here, so a Zodiaction interrupted mid-flourish leaves nothing stranded.
struct SpectralHeadView: View {

    let zodiac: Zodiac

    /// Size of a board cell, in points.
    let tileSize: CGFloat

    /// When the apparition was summoned.
    let start: Date

    var body: some View {
        let ramp = ElementFX.ramp(for: zodiac.element)
        let mesh = SpectralHeads.mesh(for: zodiac)

        TimelineView(.animation) { timeline in
            let elapsed = timeline.date.timeIntervalSince(start)
            let progress = min(max(elapsed / GameRules.spectralHeadDuration, 0), 1)
            let pose = pose(progress: progress, elapsed: elapsed)

            Canvas { context, size in
                let origin = CGPoint(x: size.width / 2, y: size.height / 2)

                for face in mesh.projected(
                    yaw: pose.yaw,
                    pitch: GameRules.spectralHeadPitch,
                    scale: tileSize * GameRules.spectralHeadScale * CGFloat(pose.scale)
                ) {
                    var path = Path()
                    path.move(to: origin.offset(by: face.points[0]))
                    for point in face.points.dropFirst() {
                        path.addLine(to: origin.offset(by: point))
                    }
                    path.closeSubpath()

                    context.fill(path, with: .color(ramp.tones[face.tone]))
                }
            }
            .frame(width: tileSize * 4, height: tileSize * 4)
            .opacity(pose.opacity)
            // Normal blending, unlike the sparks and beams.
            //
            // Additive is right for small bright motes, which are usually seen
            // against the dark. A head is a large *form* over a pale board, and
            // added to cream tiles the fire ramp saturates straight to white —
            // the silhouette survives but the colour does not. Alpha keeps the
            // ramp readable on both planes; the ghostliness comes from the
            // translucency and the rise, not from the blend.
            // Rises off the piece as it fades.
            .offset(y: -tileSize * (GameRules.spectralHeadRise + CGFloat(progress) * 0.6))
        }
        .allowsHitTesting(false)
    }

    /// How the apparition looks at this moment.
    ///
    /// It snaps in, holds while it turns, then fades — a long fade-in would read
    /// as something arriving rather than as something *summoned*.
    private func pose(progress: Double, elapsed: TimeInterval) -> (yaw: Float, scale: Double, opacity: Double) {
        let appear = min(progress / 0.15, 1)
        let fade = progress < 0.55 ? 1 : 1 - (progress - 0.55) / 0.45

        return (
            // Turns to face the player, overshooting slightly and settling.
            yaw: Float(elapsed) * GameRules.spectralHeadSpin,
            // Overshoots on the way in, which is what makes it land rather than
            // inflate.
            scale: appear * (1 + 0.18 * sin(appear * .pi)),
            opacity: fade * GameRules.spectralHeadOpacity
        )
    }
}

private extension CGPoint {
    func offset(by delta: CGPoint) -> CGPoint {
        CGPoint(x: x + delta.x, y: y + delta.y)
    }
}
