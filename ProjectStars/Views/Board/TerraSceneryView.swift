//
//  TerraSceneryView.swift
//  Project Stars
//
//  The land Terra's board is sitting in.
//

import SwiftUI

/// Which piece of Terra's scenery this is.
enum TerraScenery: String, Hashable, CaseIterable {

    /// The ridge behind the board. Drawn under everything, over the sky.
    case backdrop

    /// The same ridge again, drawn over the first and **still behind** the
    /// board.
    ///
    /// Two rows of hills at different heights read as distance; one row reads
    /// as a wall. It sits above the far ridge in the stack and below everything
    /// the board draws, so nothing it overlaps is ever the game.
    case midground

    /// The rocks that flank the board, left and right.
    ///
    /// Drawn in front of the board and behind the rock at the bottom, so they
    /// frame the play area without ever covering the row a piece is standing
    /// on. Two of each are drawn — see `TerraMidRocks` — because one pair reads
    /// as a border and two read as a gorge.
    case midLeft
    case midRight

    /// The rock in front of the board.
    ///
    /// Drawn over **everything**, the piece included: it is nearer the camera
    /// than the board is, so a piece walking the front row passing behind it is
    /// the whole point of it being there.
    case foreground
}

/// One piece of Terra's scenery, spanning the screen.
///
/// Both are seven cells wide and are stretched to the full width of the square
/// rather than being placed on the grid — they are landscape, not board. The
/// height follows from the art's own proportions so nothing is squashed.
struct TerraSceneryView: View {

    let part: TerraScenery

    /// The side of the square the board is drawn in.
    let side: CGFloat

    /// True while the piece is standing behind this — the front rock thins out
    /// so the player can see themselves through it. See
    /// `GameRules.terraForegroundFaded`.
    var isHiding = false

    /// True while the board's edges have to be visible.
    ///
    /// **Aquarius dies off the sides**, so the one sign that can leave the
    /// board is the one sign that cannot have scenery standing over the edge
    /// she might leave by. Everything retreats the way it came — the front rock
    /// down, the ridges up — rather than fading on the spot, so it reads as the
    /// land drawing back rather than as art being switched off.
    var isRetreated = false

    /// How far this piece travels to get out of the way, in art pixels.
    private var retreat: CGFloat {
        guard isRetreated else { return 0 }
        return part == .foreground
            ? GameRules.terraSceneryRetreat
            : -GameRules.terraSceneryRetreat
    }

    /// How many cells tall each piece is drawn.
    private var cells: CGFloat {
        switch part {
        case .backdrop, .midground: 3
        case .midLeft, .midRight: 2
        case .foreground: 2
        }
    }

    /// How far down this piece sits, in art pixels.
    ///
    /// The two ridges are placed independently — they are the same drawing at
    /// two depths, and how much of each shows is the composition.
    private var drop: CGFloat {
        #if DEBUG
        switch part {
        case .backdrop: TerraSceneryTuning.shared.backY
        case .midground: TerraSceneryTuning.shared.midY
        default: 0
        }
        #else
        switch part {
        case .backdrop: GameRules.terraBackdropDrop
        case .midground: GameRules.terraMidgroundDrop
        default: 0
        }
        #endif
    }

    /// Cells across. Seven, as drawn.
    private static let across: CGFloat = 7

    var body: some View {
        PixelSprite(id: .terraScenery(part)) { EmptyView() }
            .frame(width: side, height: side * cells / Self.across)
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: part == .foreground ? .bottom : .top
            )
            // The ridge sits where it is told; the rock is flush with the floor
            // of the screen and has nothing to tune.
            // In art pixels, so a nudge means the same thing at any screen size.
            .offset(
                y: (drop + retreat) * side
                    / (Self.across * CGFloat(GameRules.tilePixelSize))
            )
            .opacity(isRetreated ? 0 : (isHiding ? GameRules.terraForegroundFaded : 1))
            .animation(
                .easeInOut(duration: GameRules.terraSceneryRetreatTime),
                value: isRetreated
            )
            .animation(.easeInOut(duration: GameRules.terraForegroundFade), value: isHiding)
            .allowsHitTesting(false)
    }
}


/// The pair of rocks that flank the board, drawn twice.
///
/// Each set has its own **spread** — how far the two are pushed in from the
/// edges of the screen — and its own height. Two sets rather than one because a
/// single pair reads as a frame around the board; a second pair at a different
/// spread and height reads as depth, the same trick the two ridges behind use.
struct TerraMidRocks: View {

    /// Which of the two sets this is.
    let set: Int

    let side: CGFloat

    /// True while the board's edges have to be clear — see
    /// `TerraSceneryView.isRetreated`. These leave the way they came in, out
    /// through the sides.
    var isRetreated = false

    /// Two cells square, as drawn.
    private var span: CGFloat {
        side * 2 / (7 * CGFloat(GameRules.tilePixelSize)) * CGFloat(GameRules.tilePixelSize)
    }

    private var spread: CGFloat {
        #if DEBUG
        set == 0 ? TerraSceneryTuning.shared.nearSpread : TerraSceneryTuning.shared.farSpread
        #else
        set == 0 ? GameRules.terraRocksNearSpread : GameRules.terraRocksFarSpread
        #endif
    }

    private var drop: CGFloat {
        #if DEBUG
        set == 0 ? TerraSceneryTuning.shared.nearRockY : TerraSceneryTuning.shared.farRockY
        #else
        set == 0 ? GameRules.terraRocksNearY : GameRules.terraRocksFarY
        #endif
    }

    /// How far out of frame these travel when they retreat, in art pixels.
    private var away: CGFloat {
        isRetreated ? GameRules.terraSceneryRetreat : 0
    }

    /// One art pixel, in points.
    private var pixel: CGFloat {
        side / (7 * CGFloat(GameRules.tilePixelSize))
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            rock(.midLeft)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .offset(x: (spread - away) * pixel, y: drop * pixel)

            rock(.midRight)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .offset(x: (-spread + away) * pixel, y: drop * pixel)
        }
        .opacity(isRetreated ? 0 : 1)
        .animation(
            .easeInOut(duration: GameRules.terraSceneryRetreatTime),
            value: isRetreated
        )
        .allowsHitTesting(false)
    }

    /// The far pair is drawn smaller, because it is further away.
    private var size: CGFloat {
        span * (set == 0 ? 1 : GameRules.terraRocksFarScale)
    }

    private func rock(_ part: TerraScenery) -> some View {
        PixelSprite(id: .terraScenery(part)) { EmptyView() }
            .frame(width: size, height: size)
    }
}
