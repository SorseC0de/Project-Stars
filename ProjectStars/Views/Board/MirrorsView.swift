//
//  MirrorsView.swift
//  Project Stars
//
//  Gemini's four mirrors, hanging off the edges of Astra.
//

import SwiftUI

/// Draws the four mirrors beyond the middle of each edge.
///
/// They are floating ovals rather than tiles because they are not part of the
/// board — they hang outside it, which is exactly what makes them readable as
/// doorways rather than squares. `BoardView` is deliberately unclipped so they
/// can sit past the grid's frame.
///
/// The positions come from `GeminiMirrors.portals(size:)`, the same table the
/// movement rule reads, so what is drawn can never drift from what works.
///
/// Astra only, and only while Gemini is the piece — see `GeminiMirrors`.
struct MirrorsView: View {

    let metrics: PixelArtMetrics

    /// Tint, taken from the sign so the mirrors read as Gemini's own.
    let accent: Color

    @State private var shimmer = false

    /// How far beyond the board edge a mirror floats, as a fraction of a tile.
    private let standoff: CGFloat = 0.62

    var body: some View {
        ZStack {
            ForEach(Array(portals.enumerated()), id: \.offset) { index, portal in
                mirror(edge: portal.edge, anchor: portal.from)
                    // Staggered so the four breathe out of step with each other.
                    .animation(
                        .easeInOut(duration: 1.6)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.2),
                        value: shimmer
                    )
            }
        }
        .onAppear { shimmer = true }
        .allowsHitTesting(false)
    }

    private var portals: [(edge: SwipeDirection, from: GridPoint, to: GridPoint)] {
        GeminiMirrors.portals(size: metrics.gridSize)
    }

    /// One oval, sitting just outside the edge square it serves.
    private func mirror(edge: SwipeDirection, anchor: GridPoint) -> some View {
        let tile = metrics.tileSize
        let base = metrics.center(of: anchor)
        let push = tile * standoff

        // Ovals lie across the edge they hang off: wide on the horizontal edges,
        // tall on the vertical ones.
        let isVerticalEdge = edge == .up || edge == .down
        let width = isVerticalEdge ? tile * 0.72 : tile * 0.34
        let height = isVerticalEdge ? tile * 0.34 : tile * 0.72

        let offset = switch edge {
        case .up: CGSize(width: 0, height: -push)
        case .down: CGSize(width: 0, height: push)
        case .left: CGSize(width: -push, height: 0)
        case .right: CGSize(width: push, height: 0)
        }

        return Ellipse()
            .fill(
                // A glassy sheen rather than a flat fill, so it reads as a
                // surface you pass *through* rather than a marker.
                LinearGradient(
                    colors: [
                        accent.opacity(0.85),
                        Palette.textPrimary.opacity(0.55),
                        accent.opacity(0.85),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Ellipse().strokeBorder(Palette.textPrimary.opacity(0.9), lineWidth: max(1, tile * 0.04))
            )
            .frame(width: width, height: height)
            .shadow(color: accent.opacity(0.8), radius: tile * 0.16)
            .scaleEffect(shimmer ? 1.0 : 0.86)
            .opacity(shimmer ? 1.0 : 0.7)
            .position(x: base.x + offset.width, y: base.y + offset.height)
    }
}
