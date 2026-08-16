//
//  AquariusStormGallery.swift
//  Project Stars
//
//  Building the storm out of one band, and choosing how it sits on the piece.
//

import SwiftUI

// MARK: - Gallery

/// Somewhere to try the storm's eleven phases and the ways it can sit on the
/// piece, without playing a run to a full meter eleven times.
struct AquariusStormGallery: View {

    @State private var phase = 10
    @State private var showsEyes = true
    @State private var showsSilhouette = true


    var body: some View {
        VStack(spacing: 10) {
            Text("AQUARIUS — STORM")
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .tracking(4)
                .foregroundStyle(Palette.textSecondary)

            ZStack {
                Palette.coolBlack
                // Real tiles behind it, at the size the board draws them, so
                // "how big is this" has an answer in the picture rather than in
                // a number — a storm that looks right against nothing can still
                // be three squares wide.
                boardGrid
                stack
            }
            .frame(width: 330, height: 330)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            // The knobs scroll; the storm does not.
            //
            // Every knob added pushed the thing being judged further off the
            // screen, which is the one part of a gallery that must never move.
            ScrollView {
                controls.padding(.bottom, 24)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.background)
    }

    /// A patch of Terra at board scale, to judge the storm against.
    private var boardGrid: some View {
        let tile: CGFloat = 66
        return VStack(spacing: 0) {
            ForEach(0..<5, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<5, id: \.self) { column in
                        TileView(
                            tile: Tile(),
                            plane: .terra,
                            shade: .at(GridPoint(column, row)),
                            size: tile
                        )
                        .frame(width: tile, height: tile)
                    }
                }
            }
        }
        .opacity(0.5)
    }

    /// The silhouette under the storm, the storm, and the eyes inside it.
    ///
    /// The figure goes **under** rather than over: the funnel is meant to be in
    /// front of the piece, which is what lets an additive blend read as light
    /// passing across it rather than as a decal stuck to it.
    private var stack: some View {
        ZStack {
            AquariusStorm(phase: phase, side: 300, scale: 4)

            // **The silhouette is on top and it is the thing that blends.**
            //
            // Under a mode like multiply a black shape drawn over the funnel
            // darkens what is behind it instead of covering it, which is what
            // makes the figure look like it is *inside* the storm rather than
            // standing in front of a picture of one. Blending the wind instead
            // — with the piece behind it — can only ever look like weather
            // painted over a statue.
            if showsSilhouette {
                // Big. The storm is a bluff about how large the thing inside
                // it is, and a small silhouette gives that away before the
                // reveal does.
                FloatingAquarius(
                    blend: .exclusion,
                    showsEyes: showsEyes,
                    strength: Double(min(max(phase, 0), 10)) / 10
                )
            }
        }
        // Grouped first, then scaled as one.
        //
        // The whole assembly against the board is a different question from any
        // of its parts against each other — a funnel that reads right on its own
        // can still be the wrong size for a square. Scaling the group keeps
        // every proportion inside it exactly as tuned.
        .compositingGroup()
        .scaleEffect(GameRules.aquariusStormScale)
    }


    private var controls: some View {
        VStack(spacing: 10) {
            HStack {
                Text("PHASE \(phase)")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .foregroundStyle(Palette.white)
                    .frame(width: 78, alignment: .leading)

                Slider(
                    value: Binding(
                        get: { Double(phase) },
                        set: { phase = Int($0.rounded()) }
                    ),
                    in: 0...10,
                    step: 1
                )
                .tint(Palette.cyan)
            }

            HStack(spacing: 16) {
                Toggle("EYES", isOn: $showsEyes)
                Toggle("BODY", isOn: $showsSilhouette)
            }
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .fixedSize()
        }
    }
}

extension BlendMode: CaseIterable {
    public static var allCases: [BlendMode] = [
        .normal,
        .multiply,
        .screen,
        .overlay,
        .darken,
        .lighten,
        .colorDodge,
        .colorBurn,
        .softLight,
        .hardLight,
        .difference,
        .exclusion,
        .hue,
        .saturation,
        .color,
        .luminosity,
        .plusDarker,
        .plusLighter
    ]
}

#Preview {
    AquariusStormGallery()
}
