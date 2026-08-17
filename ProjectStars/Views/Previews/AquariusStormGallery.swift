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

    /// The bloom's colour and how it is laid on — the two being tried.
    @State private var glowTint: Color = GameRules.stormGlowTint
    @State private var glowBlend: BlendMode = GameRules.stormGlowTintBlend

    /// Gold core or grey.
    @State private var greyPlates = false


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
            // Room for the whole assembly.
            //
            // The funnel is drawn on a 300-point canvas and the figure hangs
            // above its middle, so a frame the same size as the canvas cuts his
            // head off. Judged against a viewport that clips, every decision
            // about his size is a decision about the wrong picture.
            .frame(width: 420, height: 460)
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
            // Lit exactly as the board lights it, so what is judged here is
            // what ships. The two knobs are the only difference.
            PaletteGlow(
                radius: GameRules.stormGlowRadius,
                intensity: GameRules.stormGlowIntensity,
                tint: glowTint,
                tintBlend: glowBlend
            ) {
                AquariusStorm(
                    phase: phase,
                    plate: greyPlates ? .aquariusArmorGrey : .aquariusArmor,
                    side: 300,
                    scale: 4
                )
            }

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


    /// The colours worth trying on a storm.
    private static let tints: [Color] = [
        Palette.purple,
        Palette.darkMagenta,
        Palette.magenta,
        Palette.pink,
        Palette.lavender,
        Palette.cyan,
        Palette.white
    ]

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
                Toggle("GREY", isOn: $greyPlates)
            }
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .fixedSize()

            // Every mode, not a shortlist. Which of them reads as wind carrying
            // its own charge is not something that can be reasoned to — the
            // answer depends on what is under the halo, and that changes with
            // the phase.
            Picker("GLOW BM", selection: $glowBlend) {
                ForEach(Array(BlendMode.pickable.enumerated()), id: \.offset) { _, mode in
                    Text(String(describing: mode)).tag(mode)
                }
            }
            .pickerStyle(.menu)
            .tint(Palette.white)

            HStack(spacing: 8) {
                ForEach(Array(Self.tints.enumerated()), id: \.offset) { _, swatch in
                    Circle()
                        .fill(swatch)
                        .frame(width: 22, height: 22)
                        .overlay {
                            Circle().strokeBorder(
                                Palette.white,
                                lineWidth: swatch == glowTint ? 2 : 0
                            )
                        }
                        .onTapGesture { glowTint = swatch }
                }
            }
        }
    }
}

/// - Note: Not a `CaseIterable` conformance. Declaring one on an imported type
///   is a promise SwiftUI may break by adding its own, and this is a gallery's
///   picker rather than anything the game relies on.
extension BlendMode {
    static let pickable: [BlendMode] = [
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
