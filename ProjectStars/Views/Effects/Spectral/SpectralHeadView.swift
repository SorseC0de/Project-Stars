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

// MARK: - Previews

/// Every sign's apparition at once, each in its own element's colours.
///
/// The authoring tool for these. A head is a box assembly in
/// `SpectralHeads`, and iterating on one by firing a Zodiaction in-game is
/// hopeless — this shows all twelve turning side by side, so a change to a horn
/// or a muzzle can be judged against its neighbours immediately.
#Preview("All twelve") {
    let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 4)

    return ScrollView {
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(Zodiac.allCases) { sign in
                VStack(spacing: 2) {
                    SpectralHeadPreview(zodiac: sign, tileSize: 44)
                        .frame(height: 110)

                    Text(sign.displayName.uppercased())
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                        .foregroundStyle(Palette.textSecondary)

                    Text(sign.element.displayName.uppercased())
                        .font(.system(size: 6, design: .monospaced))
                        .foregroundStyle(ElementFX.ramp(for: sign.element).mid)
                }
            }
        }
        .padding(8)
    }
    .background(Palette.coolBlack)
}

/// One head, large, for working on a single mesh.
#Preview("Aries, large") {
    SpectralHeadPreview(zodiac: .aries, tileSize: 120)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.coolBlack)
}

/// A head turning on the spot, with none of the summon's rise or fade.
///
/// Deliberately not `SpectralHeadView`: that one is built to appear and die on a
/// timer, which is exactly wrong for looking at geometry. This holds the pose
/// steady and only spins.
private struct SpectralHeadPreview: View {

    let zodiac: Zodiac
    let tileSize: CGFloat

    var body: some View {
        let ramp = ElementFX.ramp(for: zodiac.element)
        let mesh = SpectralHeads.mesh(for: zodiac)

        TimelineView(.animation) { timeline in
            let yaw = Float(timeline.date.timeIntervalSinceReferenceDate) * GameRules.spectralHeadSpin

            Canvas { context, size in
                let origin = CGPoint(x: size.width / 2, y: size.height / 2)

                for face in mesh.projected(
                    yaw: yaw,
                    pitch: GameRules.spectralHeadPitch,
                    scale: tileSize * GameRules.spectralHeadScale
                ) {
                    var path = Path()
                    path.move(to: CGPoint(x: origin.x + face.points[0].x, y: origin.y + face.points[0].y))
                    for point in face.points.dropFirst() {
                        path.addLine(to: CGPoint(x: origin.x + point.x, y: origin.y + point.y))
                    }
                    path.closeSubpath()
                    context.fill(path, with: .color(ramp.tones[face.tone]))
                }
            }
            .opacity(GameRules.spectralHeadOpacity)
        }
    }
}
