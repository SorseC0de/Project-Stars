//
//  GameModeRulesView.swift
//  Project Stars
//
//  What the mode you are about to play does to the ground.
//

import SwiftUI

/// The rules of one mode, drawn rather than written.
///
/// ## Why it draws the real thing
///
/// Because a rules page is where a player finds out what they are looking at,
/// and a picture of a cracked tile that is not *the* cracked tile teaches them
/// the wrong thing. Every cell here is the same view the board uses, at the same
/// scale, dressed with the same state — so what is learned on this page is
/// recognisable the moment the run starts.
///
/// ## Adding a mode
///
/// A `case` in the switch. The rows are per-mode on purpose: what Survival needs
/// explaining is the ground wearing out, and the next mode will need something
/// else entirely rather than the same diagram with different words.
struct GameModeRulesView: View {

    let mode: GameMode

    /// How big one cell is drawn.
    let size: CGFloat

    var body: some View {
        switch mode {
        case .survival: survival
        }
    }

    // MARK: - Survival

    /// Both planes' ground, healthy to gone.
    ///
    /// Astra above Terra, which is how they are stacked in the world — see
    /// `GameScreen.planeSquare(_:side:)`. Reading the two rows top to bottom is
    /// reading the world top to bottom.
    private var survival: some View {
        VStack(spacing: RulesStyle.rowSpacing) {
            HStack(spacing: RulesStyle.cellSpacing) {
                ForEach(TileHealth.allCases, id: \.self) { health in
                    VStack(spacing: 0) {
                        cloud(health)
                    }
                }
            }

            HStack(spacing: RulesStyle.cellSpacing) {
                ForEach(TileHealth.allCases, id: \.self) { health in
                    VStack(spacing: 0) {
                        ground(health)
                    }
                }
            }
        }
    }

    /// One of Astra's clouds at this much wear.
    ///
    /// A cloud does not have a picture for *gone* — there is nothing left to
    /// draw — so the last cell is the mark the cursor wears over a hole, which
    /// is what the player will actually see there.
    @ViewBuilder
    private func cloud(_ health: TileHealth) -> some View {
        if health.isHole {
            // A cloud has no picture for *gone* — there is nothing left to
            // draw — so the last cell is the cross the board already marks a
            // missing Astra square with. `astraHole` rather than a sprite of
            // its own: it is the same statement about the same thing, and it
            // was already on the sheet one cell from where I first looked.
            PixelSprite(id: .astraHole) {
                Rectangle().fill(Palette.red)
            }
            .frame(width: size, height: size)
        } else {
            // **The drawn cloud, not the generated one.**
            //
            // `CloudTileView` builds a cluster out of thirty-nine shapes and is
            // the placeholder from before the sheet had clouds on it — the board
            // stopped using it the moment `CloudSpriteField.hasArt` went true.
            // A rules page is where a player learns what they are looking at, so
            // showing them the stand-in teaches them a picture the game does not
            // draw.
            //
            // `CloudSpriteView` rather than the field, because this is one cloud
            // rather than a plane of them — and it is the view that can run the
            // palette shader, which is what turns one drawing into four stages
            // of wear. See `GameRules.cloudWearSwaps(_:shade:)`.
            CloudSpriteView(
                // A fixed square, so every visit draws the same cloud: the
                // wander *and the shade* are read off the point, and four
                // different ones would come out as four kinds of cloud rather
                // than one wearing down.
                point: RulesStyle.samplePoint,
                health: health,
                metrics: PixelArtMetrics(availableSide: size * CGFloat(GameRules.gridSize)),
                // Held still. This is an infographic — four stages of wear in a
                // row — and a cloud that drifts costs frames to say nothing and
                // can wander far enough to stop lining up with the other three.
                isStill: true
            )
            .frame(width: size, height: size)
        }
    }

    /// One of Terra's tiles at this much wear.
    private func ground(_ health: TileHealth) -> some View {
        TileView(
            tile: Tile(kind: .normal, health: health),
            plane: .terra,
            shade: RulesStyle.shade,
            size: size,
            isPopped: false,
            isFlashing: false,
            healFlash: nil,
            isPressed: false,
            point: RulesStyle.samplePoint,
            drawnByField: false
        )
        .frame(width: size, height: size)
    }
}

// MARK: - Measurements

/// How the rules page is laid out.
enum RulesStyle {

    static let rowSpacing: CGFloat = 10
    static let cellSpacing: CGFloat = 8

    /// The shade every *tile* sample is drawn in. A cloud reads its own off
    /// `samplePoint`, so the two agree only because both are fixed.
    ///
    /// One of the two, not both. The board alternates them so a grid of squares
    /// reads as a grid; a row of samples alternating would read as *two things*
    /// being shown rather than one thing at four stages.
    static let shade: Palette.TileShade = .light

    /// The square every sample claims to be.
    static let samplePoint = GridPoint(3, 3)
}
