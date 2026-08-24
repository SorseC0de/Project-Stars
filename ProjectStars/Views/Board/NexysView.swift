//
//  NexysView.swift
//  Project Stars
//
//  The floating island at the centre of the board.
//

import SwiftUI

/// Draws the Nexys island.
///
/// The sprite is 48x48 — three cells — but only its **middle cell is the tile**.
/// The overhang is rim and greenery spilling past the square it occupies, which
/// is what makes it read as an island rather than a stone slab.
///
/// It rests slightly above where a tile would sit (`GameRules.nexysRaise`) and
/// drifts up and down around that. The drift is supplied by the caller rather
/// than generated here, because the piece standing on the island has to ride the
/// same offset — one clock, two views.
struct NexysView: View {

    /// Size of a single board cell, in points.
    let tileSize: CGFloat

    /// Whole-pixel scale factor, for converting art pixels to points.
    let scale: CGFloat

    /// Current bob offset in points, negative being up. Comes from
    /// `BoardView.nexysOffset(at:)`.
    let bob: CGFloat

    /// True while the piece stands on one of the three squares directly north,
    /// where a fully opaque island would cover it.
    let isFaded: Bool

    var body: some View {
        PixelSprite(id: NexysStyle.foreshortened ? .nexysDeep : .nexys) {
            placeholder
        }
        // Three cells wide and tall, centred on its own square.
        .frame(width: tileSize * 3, height: tileSize * 3)
        // The nudge is in art pixels, so it survives every board size — see
        // `NexysStyle`. Only the drawn-in-perspective island uses it; the flat
        // one is already placed.
        .offset(
            x: NexysStyle.foreshortened ? NexysStyle.islandX * scale : 0,
            y: -GameRules.nexysRaise * scale + bob
                + (NexysStyle.foreshortened ? NexysStyle.islandY * scale : 0)
        )
        .opacity(isFaded ? GameRules.nexysFadedOpacity : 1)
        .animation(.easeInOut(duration: 0.2), value: isFaded)
        .allowsHitTesting(false)
    }

    /// Stand-in while the sheet is missing: the old carved-slab drawing, sized
    /// to the middle cell only.
    private var placeholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: tileSize * 0.12)
                .fill(Palette.nexysFace)
                .overlay(
                    RoundedRectangle(cornerRadius: tileSize * 0.12)
                        .strokeBorder(Palette.nexysEdge, lineWidth: max(1, tileSize * 0.06))
                )
                .frame(width: tileSize, height: tileSize)
                .shadow(color: Palette.nexysEdge.opacity(0.7), radius: tileSize * 0.14)
        }
    }
}

/// The pillar under the foreshortened island's near corner.
///
/// A view of its own because it is drawn at a different *depth* from the island
/// it belongs to: the island is behind whoever is standing on it and the pillar
/// is in front of them, which is one object in two places as far as the sort is
/// concerned. See `BoardObjectKind.nexysPillar`.
struct NexysPillarView: View {

    let tileSize: CGFloat
    let scale: CGFloat

    /// The island's drift, so the pillar rides with it rather than staying put
    /// while the thing it holds up moves.
    let bob: CGFloat

    var body: some View {
        PixelSprite(id: .nexysPillar) { EmptyView() }
            .frame(width: tileSize, height: tileSize)
            .offset(
                x: NexysStyle.pillarX * scale,
                y: -GameRules.nexysRaise * scale + bob + NexysStyle.pillarY * scale
            )
            .allowsHitTesting(false)
    }
}

// MARK: - Measurements

/// Which island is drawn, and where it and its pillar sit.
///
/// Art pixels rather than points, like everything else placed on this board: a
/// number in points means something different at every board size, and the whole
/// point of whole-pixel scaling is that art never lands between pixels.
@MainActor
enum NexysStyle {

    /// Shipped flat until the drawn-in-perspective version has been placed.
    ///
    /// The sprite exists either way — see `SpriteID.nexysDeep`. What is not
    /// settled is where it goes, and shipping an unplaced sprite is shipping a
    /// misplaced one.
    static let defaultForeshortened = false

    static let defaultIslandX: Double = 0
    static let defaultIslandY: Double = 0
    static let defaultPillarX: Double = 0
    static let defaultPillarY: Double = 0

    static var foreshortened: Bool {
        #if DEBUG
        NexysTuning.shared.foreshortened
        #else
        defaultForeshortened
        #endif
    }

    static var islandX: CGFloat {
        #if DEBUG
        CGFloat(NexysTuning.shared.islandX)
        #else
        CGFloat(defaultIslandX)
        #endif
    }

    static var islandY: CGFloat {
        #if DEBUG
        CGFloat(NexysTuning.shared.islandY)
        #else
        CGFloat(defaultIslandY)
        #endif
    }

    static var pillarX: CGFloat {
        #if DEBUG
        CGFloat(NexysTuning.shared.pillarX)
        #else
        CGFloat(defaultPillarX)
        #endif
    }

    static var pillarY: CGFloat {
        #if DEBUG
        CGFloat(NexysTuning.shared.pillarY)
        #else
        CGFloat(defaultPillarY)
        #endif
    }
}
