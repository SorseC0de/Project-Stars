//
//  EffectGallery.swift
//  Project Stars
//
//  Every imported effect strip, on a patch of board, for judging it.
//
//  Lives under Views/Previews rather than Views/Effects: this is a tool for
//  looking at the game, not a part of it.
//

import SwiftUI

/// One effect playing over a three-by-three patch of board.
///
/// Built to match what a real session draws — the same two-pass tiles, the same
/// `EffectSpriteView` with its own bloom at its own span — so what is judged
/// here is what ships. The strips are 64px against 16px tiles, and how big that
/// reads is the whole question, which is why it is shown on tiles rather than on
/// a flat background.
struct EffectPreview: View {

    var effect: EffectSprite = .ariesZodiaction
    var plane: Plane = .astra

    /// Restarting the strip. Bumping it gives the view a new `.id`, which is
    /// what makes a one-shot animation play again.
    var take: Int = 0

    /// Rendered size of one cell, in points.
    var tileSize: CGFloat = 64

    private var scale: CGFloat { tileSize / CGFloat(GameRules.tilePixelSize) }
    private let span = 3

    var body: some View {
        ZStack {
            edges
            faces

            EffectSpriteView(effect: effect, tileSize: tileSize, start: .now)
                .id(take)
                .position(position(of: centre))
        }
        .frame(width: tileSize * CGFloat(span), height: tileSize * CGFloat(span))
    }

    private var edges: some View {
        grid { point in
            TileEdgeView(plane: plane, shade: .at(point), size: tileSize)
                .offset(y: GameRules.tileEdgeDrop * scale)
        }
    }

    private var faces: some View {
        grid { point in
            TileView(
                tile: Tile(),
                plane: plane,
                shade: .at(point),
                size: tileSize,
                point: point
            )
        }
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

/// Every imported effect, switchable, on either plane.
#Preview("Effects") {
    EffectGallery()
}

/// The interactive shell: the patch, plus controls for which strip, which plane,
/// and replaying it.
struct EffectGallery: View {

    @State private var effect: EffectSprite = .ariesZodiaction
    @State private var plane: Plane = .astra
    @State private var take = 0
    @State private var looping = true

    var body: some View {
        VStack(spacing: 16) {
            Text("EFFECTS")
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .tracking(4)
                .foregroundStyle(Palette.textSecondary)

            EffectPreview(effect: effect, plane: plane, take: take, tileSize: 72)

            VStack(spacing: 10) {
                Picker("Effect", selection: $effect) {
                    ForEach(EffectSprite.allCases, id: \.self) { effect in
                        Text(effect.previewName).tag(effect)
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

                // What is actually on the sheet, so a strip that plays wrong can
                // be told apart from one whose frame count was read wrong.
                Text(details)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(Palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 24)
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(plane == .astra ? Palette.coolBlack : Palette.darkBlue)
        // A one-shot strip is over in about a second, which is no use for
        // judging it. Looping re-runs it on its own duration.
        .task(id: loopKey) {
            guard looping else { return }
            while !Task.isCancelled {
                try? await Task.sleep(
                    nanoseconds: UInt64(effect.duration * 1_000_000_000)
                )
                guard !Task.isCancelled else { return }
                take += 1
            }
        }
    }

    /// Restarts the loop when either the strip or the toggle changes.
    private var loopKey: String { "\(effect.rawValue)-\(looping)" }

    private var details: String {
        let fps = effect.duration > 0
            ? Double(effect.frames) / effect.duration
            : 0
        return """
        \(effect.assetName)
        \(effect.frames) frames · \(Int(fps.rounded()))fps · \
        \(String(format: "%.2f", effect.duration))s · \
        \(String(format: "%.1f", effect.span)) tiles
        """
    }
}

private extension EffectSprite {
    /// Readable name for the picker.
    var previewName: String {
        switch self {
        case .ariesZodiaction: "Aries — Blaze Path trail"
        case .astralBlaze: "Astral Blaze"
        case .leoPridefulLanding: "Leo — Prideful Landing"
        case .leoZodiactionOne: "Leo — Sun (layer 1)"
        case .leoZodiactionTwo: "Leo — Sun (layer 2)"
        case .leoZodiactionSummon: "Leo — Sun summon"
        case .fireMisc: "Aries — charge gain"
        case .sagittariusJump: "Sagittarius — leap"
        case .cancerZodiaction: "Cancer — Astral Bastion"
        case .cancerZodiactionAlternate: "Cancer — Bastion (alt)"
        case .libraZodiaction: "Libra — Zodiaction"
        }
    }
}
