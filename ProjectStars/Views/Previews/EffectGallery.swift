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

    var item: GalleryEffect = .single(.ariesZodiaction)
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

            // Drawn exactly as the game composites it — stacked layers stacked,
            // sequenced layers delayed. Looking at a layer on its own says very
            // little about the effect it is half of.
            ForEach(Array(item.layers.enumerated()), id: \.offset) { _, layer in
                EffectSpriteView(
                    effect: layer.effect,
                    tileSize: tileSize,
                    start: Date().addingTimeInterval(layer.delay)
                )
                .position(position(of: centre))
            }
            .id(take)
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

    @State private var item: GalleryEffect = .single(.ariesZodiaction)
    @State private var plane: Plane = .astra
    @State private var take = 0
    @State private var looping = true

    var body: some View {
        VStack(spacing: 16) {
            Text("EFFECTS")
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .tracking(4)
                .foregroundStyle(Palette.textSecondary)

            EffectPreview(item: item, plane: plane, take: take, tileSize: 72)

            VStack(spacing: 10) {
                Picker("Effect", selection: $item) {
                    ForEach(GalleryEffect.all, id: \.self) { item in
                        Text(item.previewName).tag(item)
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
                    nanoseconds: UInt64(item.duration * 1_000_000_000)
                )
                guard !Task.isCancelled else { return }
                take += 1
            }
        }
    }

    /// Restarts the loop when either the strip or the toggle changes.
    private var loopKey: String { "\(item.previewName)-\(looping)" }

    private var details: String {
        item.layers.map { layer in
            let effect = layer.effect
            let fps = Int((Double(effect.frames) / effect.duration).rounded())
            let ground = effect.isGrounded ? " · grounded" : ""
            let delay = layer.delay > 0
                ? " · starts +\(String(format: "%.2f", layer.delay))s"
                : ""
            return "\(effect.assetName) — \(effect.frames)f · \(fps)fps · "
                + "\(String(format: "%.1f", effect.span))t\(ground)\(delay)"
        }
        .joined(separator: "\n")
    }
}

// MARK: - What the gallery can show

/// One thing worth looking at: a strip, or a composite the game actually draws.
enum GalleryEffect: Hashable {
    case single(EffectSprite)
    case cancerBastion
    case leoSun

    /// One layer of it, and how far into the composite it starts.
    ///
    /// `delay` is seconds *after* the composite begins. `EffectSpriteView` draws
    /// nothing before its start date, so a delayed layer simply waits.
    struct Layer {
        let effect: EffectSprite
        let delay: TimeInterval
    }

    var layers: [Layer] {
        switch self {
        case let .single(effect):
            [Layer(effect: effect, delay: 0)]

        case .cancerBastion:
            EffectSprite.cancerBastion.map { Layer(effect: $0, delay: 0) }

        case .leoSun:
            // All three at once, which is how `SunView` draws it.
            (EffectSprite.leoSun + [.leoZodiactionSummon]).map { Layer(effect: $0, delay: 0) }
        }
    }

    /// How long the whole composite runs, so the loop waits for all of it.
    var duration: TimeInterval {
        layers.map { $0.delay + $0.effect.duration }.max() ?? 0
    }

    /// The composites first, then every strip on its own for checking the art.
    static var all: [GalleryEffect] {
        [.cancerBastion, .leoSun] + EffectSprite.allCases.map { GalleryEffect.single($0) }
    }

    var previewName: String {
        switch self {
        case .cancerBastion: "Cancer — Bubble Bastion (stacked)"
        case .leoSun: "Leo — Sun (all three stacked)"
        case let .single(effect): effect.previewName
        }
    }
}

private extension EffectSprite {
    /// Readable name for the picker.
    var previewName: String {
        switch self {
        case .ariesZodiaction: "Aries — Brazen Blaze trail"
        case .astralBlaze: "Astral Blaze"
        case .explosion: "Explosion (unassigned)"
        case .lightning1: "Astral Bolt — strike 1"
        case .lightning2: "Astral Bolt — strike 2"
        case .lightning3: "Astral Bolt — strike 3"
        case .lightning4: "Astral Bolt — strike 4"
        case .crabWalk: "Cancer — Seafoam Scuttle"
        case .waterSplash: "Splash (unassigned)"
        case .astralBloom: "Astral Blossom"
        case .leoPridefulLanding: "Leo — Prideful Landing"
        case .leoZodiactionOne: "Leo — Sun (layer 1)"
        case .leoZodiactionTwo: "Leo — Sun (layer 2)"
        case .leoZodiactionSummon: "Leo — Sun summon"
        case .fireMisc: "Aries — charge gain"
        case .sagittariusJump: "Sagittarius — leap"
        case .cancerZodiaction: "Cancer — Bubble Bastion"
        case .cancerZodiactionAlternate: "Cancer — Bastion (alt)"
        case .libraZodiaction: "Libra — Zodiaction"
        }
    }
}
