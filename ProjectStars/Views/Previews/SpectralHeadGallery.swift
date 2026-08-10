//
//  SpectralHeadGallery.swift
//  Project Stars
//
//  Every sign's apparition, side by side, for authoring the meshes.
//
//  Lives under Views/Previews rather than beside the effect: this is a tool for
//  looking at the game, not a part of it.
//

import SwiftUI

/// All twelve heads turning at once.
///
/// The authoring tool for `SpectralHeads`. A head is a box assembly, and
/// iterating on one by firing a Zodiaction in a real session is hopeless — this
/// shows every sign at once so a change to a horn or a muzzle can be judged
/// against its neighbours immediately.
struct SpectralHeadGallery: View {

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 4)

    var body: some View {
        VStack(spacing: 14) {
            Text("SPECTRAL HEADS")
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .tracking(4)
                .foregroundStyle(Palette.textSecondary)

            ScrollView {
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

        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.coolBlack)
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
    SpectralHeadGallery()
}

/// Kept for quick access to the grid alone.
#Preview("Grid only") {
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
struct SpectralHeadPreview: View {

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
