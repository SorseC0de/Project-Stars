//
//  ConstellationGallery.swift
//  Project Stars
//
//  All twelve signs written in stars, for judging them.
//
//  Lives under Views/Previews rather than Views/Effects: this is a tool for
//  looking at the game, not a part of it.
//

import SwiftUI

/// One sign's constellation over a patch of board.
///
/// Shown on real tiles rather than on black, because that is what it has to be
/// legible against — an additive figure reads very differently over Astra's
/// magenta cloud than over Terra's earth.
struct ConstellationPreview: View {

    var zodiac: Zodiac = .aries
    var plane: Plane = .astra

    /// Bumping this restarts the summon.
    var take: Int = 0

    var tileSize: CGFloat = 64

    private var scale: CGFloat { tileSize / CGFloat(GameRules.tilePixelSize) }
    private let span = 5

    var body: some View {
        ZStack {
            grid { point in
                TileView(
                    tile: Tile(),
                    plane: plane,
                    shade: .at(point),
                    size: tileSize,
                    point: point
                )
            }

            // The piece it hangs over, so the size relationship is honest.
            PieceView(zodiac: zodiac, tileSize: tileSize, scale: scale, plane: plane)
                .position(position(of: centre))

            ConstellationView(zodiac: zodiac, tileSize: tileSize, start: .now)
                .id(take)
                .position(position(of: centre))
                .offset(y: -GameRules.constellationRise * scale)
        }
        .frame(width: tileSize * CGFloat(span), height: tileSize * CGFloat(span))
        .clipped()
    }

    private var centre: GridPoint { GridPoint(span / 2, span / 2) }

    private func position(of point: GridPoint) -> CGPoint {
        CGPoint(
            x: (CGFloat(point.x) + 0.5) * tileSize,
            y: (CGFloat(point.y) + 0.5) * tileSize
        )
    }

    private func grid<Content: View>(
        @ViewBuilder content: @escaping (GridPoint) -> Content
    ) -> some View {
        ForEach(0..<(span * span), id: \.self) { index in
            let point = GridPoint(index % span, index / span)
            content(point).position(position(of: point))
        }
    }
}

// MARK: - Previews

#Preview("Constellations") {
    ConstellationGallery()
}

/// The interactive shell: the patch, plus which sign, which plane, and replay.
struct ConstellationGallery: View {

    @State private var zodiac: Zodiac = .aries
    @State private var plane: Plane = .astra
    @State private var take = 0
    @State private var looping = true

    var body: some View {
        VStack(spacing: 14) {
            Text("CONSTELLATIONS")
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .tracking(4)
                .foregroundStyle(Palette.textSecondary)

            ConstellationPreview(zodiac: zodiac, plane: plane, take: take, tileSize: 64)

            VStack(spacing: 10) {
                Picker("Sign", selection: $zodiac) {
                    ForEach(Zodiac.allCases, id: \.self) { sign in
                        Text("\(sign.definition.glyph.monochromeGlyph)  \(sign.definition.displayName)")
                            .tag(sign)
                    }
                }
                .pickerStyle(.menu)

                Picker("Plane", selection: $plane) {
                    ForEach(Plane.allCases) { plane in
                        Text(plane.displayName.uppercased()).tag(plane)
                    }
                }
                .pickerStyle(.segmented)

                HStack(spacing: 12) {
                    Button("REPLAY") { take += 1 }
                        .font(.system(size: 10, weight: .bold, design: .monospaced))

                    Toggle(isOn: $looping) {
                        Text("LOOP")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(Palette.textSecondary)
                    }
                    .fixedSize()
                }

                Text(details)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(Palette.textSecondary)
            }
            .padding(.horizontal, 24)
        }
        .padding(.vertical, 22)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(plane == .astra ? Palette.coolBlack : Palette.darkBlue)
        .task(id: loopKey) {
            guard looping else { return }
            while !Task.isCancelled {
                try? await Task.sleep(
                    nanoseconds: UInt64(GameRules.constellationDuration * 1_000_000_000)
                )
                guard !Task.isCancelled else { return }
                take += 1
            }
        }
    }

    private var loopKey: String { "\(zodiac.rawValue)-\(looping)" }

    private var details: String {
        let figure = Constellation.figure(for: zodiac)
        let trace = Double(figure.lines.count) * GameRules.constellationTracePerLine
        return "\(figure.stars.count) stars · \(figure.lines.count) lines · "
            + "traces in \(String(format: "%.2f", trace))s"
    }
}
