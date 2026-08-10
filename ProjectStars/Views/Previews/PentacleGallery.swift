//
//  PentacleGallery.swift
//  Project Stars
//
//  A Pentacle on a raised tile, in isolation, for judging its art.
//
//  Lives under Views/Previews rather than Views/Board: this is a tool for
//  looking at the game, not a part of it.
//

import SwiftUI

/// A three-by-three patch of board with a Pentacle on the raised centre tile.
///
/// Built to match what a real session draws, not to approximate it: the same
/// two-pass tile rendering, the same lift, the same coin view with its float,
/// its orbit and its pool of light. If it looks right here it looks right in
/// play — which is the only reason a preview like this earns its keep.
///
/// No piece and no cursor. Both would sit on the centre tile and cover the
/// thing being looked at.
///
/// Deliberately a real `View` rather than code inside `#Preview`, so it can be
/// dropped into a debug screen later without being rewritten.
struct PentaclePreview: View {

    /// Which coin to show.
    var appearance: PentacleAppearance = .standard

    /// Which plane's tiles to draw it on.
    var plane: Plane = .astra

    /// Rendered size of one cell, in points.
    var tileSize: CGFloat = 64

    /// Whole-pixel scale, for art-pixel offsets. Matches what
    /// `PixelArtMetrics` would derive at this cell size.
    private var scale: CGFloat { tileSize / CGFloat(GameRules.tilePixelSize) }

    /// The patch is three cells square, centred on the coin's tile.
    private let span = 3

    var body: some View {
        ZStack {
            edges
            faces
            coin
        }
        .frame(width: tileSize * CGFloat(span), height: tileSize * CGFloat(span))
    }

    // MARK: - Board

    /// Pass one, exactly as `BoardView` does it: a full grid of edge strips,
    /// pushed down so the raised tile uncovers one.
    private var edges: some View {
        grid { point in
            TileEdgeView(plane: plane, shade: .at(point), size: tileSize)
                .offset(y: GameRules.tileEdgeDrop * scale)
        }
    }

    /// Pass two: the faces, with the centre one raised.
    private var faces: some View {
        grid { point in
            let isCentre = point == centre

            TileView(
                tile: Tile(),
                plane: plane,
                shade: .at(point),
                size: tileSize,
                isPopped: isCentre
            )
            .offset(y: isCentre ? -GameRules.tilePopLift * scale : 0)
        }
    }

    private var coin: some View {
        PentacleView(appearance: appearance, size: tileSize, scale: scale)
            .position(position(of: centre))
            .offset(y: -GameRules.tilePopLift * scale)
    }

    // MARK: - Layout

    private var centre: GridPoint { GridPoint(span / 2, span / 2) }

    private func position(of point: GridPoint) -> CGPoint {
        CGPoint(
            x: (CGFloat(point.x) + 0.5) * tileSize,
            y: (CGFloat(point.y) + 0.5) * tileSize
        )
    }

    /// Lays a view over every square of the patch.
    ///
    /// Shades alternate from the real board's parity so the centre tile keeps
    /// the tone it would have at the middle of a 7x7 grid.
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

/// Every on-map coin, switchable, on either plane.
#Preview("Pentacle on a tile") {
    PentacleGallery()
}

/// The interactive shell: the patch, plus controls for which coin and which
/// plane.
///
/// A real `View` rather than code inside `#Preview`, so the canvas has something
/// named to render and so it can be composed into a larger sheet later.
struct PentacleGallery: View {


    @State private var appearance: PentacleAppearance = .standard
    @State private var plane: Plane = .astra

    var body: some View {
        VStack(spacing: 20) {
            Text("PENTACLE")
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .tracking(4)
                .foregroundStyle(Palette.textSecondary)

            PentaclePreview(appearance: appearance, plane: plane, tileSize: 72)

            VStack(spacing: 12) {
                Picker("Coin", selection: $appearance) {
                    ForEach(PentacleAppearance.allCases, id: \.self) { appearance in
                        Text(appearance.previewName).tag(appearance)
                    }
                }
                .pickerStyle(.segmented)

                Picker("Plane", selection: $plane) {
                    ForEach(Plane.allCases) { plane in
                        Text(plane.displayName.uppercased()).tag(plane)
                    }
                }
                .pickerStyle(.segmented)

                Text(appearance.previewNote)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(Palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 24)

        }
        .padding(.vertical, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(plane == .astra ? Palette.coolBlack : Palette.darkBlue)
    }
}

private extension PentacleAppearance {
    var previewName: String {
        switch self {
        case .standard: "Gold"
        case .shadow: "Shadow"
        case .radiant: "Polaris"
        }
    }

    /// What wears this coin, so the picker means something.
    var previewNote: String {
        switch self {
        case .standard:
            "Every common, uncommon and rare. The coin is a loot box — it must not hint at what is inside."
        case .shadow:
            "Shadow Work only. Spawns in place of an ordinary Pentacle."
        case .radiant:
            "Polaris only. Spawns from a sparkle on the north-middle tile."
        }
    }
}
