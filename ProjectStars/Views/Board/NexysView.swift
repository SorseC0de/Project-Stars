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

    /// How far through the settling rock the island is, or `nil` when it is not
    /// rocking. See `NexysStyle.Rock`.
    var rock: CGFloat?

    /// Whether the flat sprite is standing in for the foreshortened one right
    /// now — which is the whole of the rock. Every rendition swaps; they differ
    /// in for how long, and in what the island is doing underneath while it does.
    private var isRocking: Bool { rock != nil }

    var body: some View {
        PixelSprite(id: NexysStyle.foreshortened && !isRocking ? .nexysDeep : .nexys) {
            placeholder
        }
        // Three cells wide and tall, centred on its own square.
        .frame(width: tileSize * 3, height: tileSize * 3)
        // **Wider for an instant, under the weight.**
        //
        // Swells to the middle of the rock and settles back by the end of it, so
        // the flat sprite is at its widest exactly when it is standing in — and
        // is back to its own width as the foreshortened one returns. Scaled
        // rather than offset: the island is being *pressed*, and a press is a
        // change of shape.
        .scaleEffect(x: squash, y: 1)
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

    /// How much wider the island is at this instant of the rock.
    ///
    /// One art pixel of squash is one art pixel however big the board is, so the
    /// growth is figured against the sprite's own 48-pixel width rather than
    /// against points.
    private var squash: CGFloat {
        guard let rock else { return 1 }

        // **On the island's own curve, or on a curve of its own.**
        //
        // Following the dip puts the widest moment at the deepest one, which is
        // what compression means. A symmetric swell instead peaks at the middle
        // of the hold — later than the bottom, and by a long way when the drop
        // is a tenth of the span — which reads as the island bulging on its way
        // back up rather than under the weight.
        let swell = NexysStyle.squashFollowsDip
            ? CloudMotion.press(Double(rock), attack: NexysStyle.bounceAttack)
            : sin(Double(rock) * .pi)

        return 1 + NexysStyle.rockSquash * CGFloat(swell) / NexysStyle.islandArtWidth
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
            // **Measured from the island, not from the board.**
            //
            // It is a part of the island, so raising the island has to raise it
            // too — see `NexysStyle.islandY`. Placed against the board instead,
            // it would come adrift from the thing it holds up the moment that
            // thing moved, and the numbers below were tuned with the island
            // already nudged.
            .offset(
                x: (NexysStyle.islandX + NexysStyle.pillarX) * scale,
                y: -GameRules.nexysRaise * scale + bob
                    + (NexysStyle.islandY + NexysStyle.pillarY) * scale
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

    /// The island's own nudge, in art pixels from the centre of its square.
    ///
    /// `islandY` is not only the sprite's placement: everything standing on the
    /// island reads it through `BoardView.surfaceOffset(of:bob:metrics:)`, so
    /// raising the island raises whoever is on it. That is the point of it being
    /// a knob rather than a constant — the island has been sitting low since the
    /// perspective rework, and the piece has to come up with it.
    static let defaultIslandX: Double = 0
    static let defaultIslandY: Double = 1

    /// The pillar, measured **from the island** rather than from the board.
    static let defaultPillarX: Double = 4
    static let defaultPillarY: Double = 2

    /// How much higher the cursor sits on the island's square, in art pixels.
    ///
    /// Applies to both sprites: the discrepancy is in `GameRules.nexysRaise`
    /// against the drawn surface, not in either drawing.
    static let defaultCursorLift: Double = 1

    /// How wide the island's art is, in art pixels: three cells of sixteen.
    static let islandArtWidth: CGFloat = CGFloat(GameRules.tilePixelSize * 3)

    // ── The settling rock ─────────────────────────────────────────────

    /// What the island does when somebody lands on it.
    ///
    /// The flat sprite standing in for the foreshortened one reads as the island
    /// tipping under the weight and righting itself — the two drawings are the
    /// same island at two angles, so swapping between them *is* the rock. There
    /// is no third drawing to make and nothing to interpolate.
    ///
    /// Each case is a whole set of numbers rather than a switch, because the
    /// parts of this only mean anything together: a squash that peaks while the
    /// island is on its way back up says something different from one that peaks
    /// at the bottom, whatever either is worth on its own.
    enum Rock: String, CaseIterable {

        /// Settled by eye. A hard slam and a long recovery, with the sprite
        /// coming back while the island is still rising.
        case weight

        /// The same movement, with the squash locked to it.
        ///
        /// Widest exactly when the island is deepest, because that is what being
        /// compressed *is* — and the sprite holds for the whole give, so the
        /// drawn-in-perspective one returns as the island settles rather than
        /// part way up. `weight` peaks its squash at the midpoint of the hold,
        /// which with a tenth-of-a-span drop is well after the bottom.
        case compress

        /// A rock on a chain, which does not stop dead.
        ///
        /// Deeper, slammed harder, and carried past rest on the way back before
        /// it settles. `CloudMotion.dip` was written for cloud and says outright
        /// that neither should twang — that was right while the two shared one
        /// curve, and the island has had its own since. Cloud hangs on nothing;
        /// this is a mass on a tether, and a mass on a tether swings.
        ///
        /// The sprite is back before the rebound, so what rides the swing up is
        /// the island's own drawing rather than the stand-in.
        case swing

        var next: Rock {
            let all = Self.allCases
            return all[(all.firstIndex(of: self)! + 1) % all.count]
        }

        /// How long the flat sprite stands in.
        var hold: Double {
            switch self {
            case .weight: 0.20
            case .compress: 0.30
            case .swing: 0.14
            }
        }

        /// How long the give lasts.
        var bounce: Double {
            switch self {
            case .weight: 0.30
            case .compress: 0.30
            case .swing: 0.42
            }
        }

        /// How far it gives, in art pixels.
        var dip: Double {
            switch self {
            case .weight: 10
            case .compress: 10
            case .swing: 12
            }
        }

        /// The share of the give spent going down.
        var drop: Double {
            switch self {
            case .weight: 0.10
            case .compress: 0.10
            case .swing: 0.08
            }
        }

        /// How many art pixels wider the island gets at the height of it.
        var squash: Double {
            switch self {
            case .weight: 8
            case .compress: 8
            case .swing: 10
            }
        }

        /// Whether the squash rides the dip's own curve instead of a symmetric
        /// swell of its own.
        var squashFollowsDip: Bool { self == .compress }

        /// How far past rest the return carries. Zero stops dead.
        var rebound: Double { self == .swing ? 0.30 : 0 }
    }

    static let defaultRock: Rock = .weight

    /// How long the flat sprite stands in, in seconds.
    static let defaultRockHold: Double = 0.20

    /// How long the island's give lasts, in seconds.
    ///
    /// Its own rather than the shared `GameRules.surfaceBounceDuration`, which
    /// also governs every cloud on Astra — the island is a rock on a chain and
    /// gives differently from a puff of cloud, and the sprite change that goes
    /// with it has to be able to line up with it.
    static let defaultBounceHold: Double = 0.30

    /// The extra lift a piece takes on the drawn-in-perspective island, in art
    /// pixels.
    ///
    /// **The sprite's, not the placement's.** Its surface is drawn a pixel
    /// higher than the flat one's, so this belongs to the drawing rather than to
    /// `GameRules.nexysRideLift` — which is the flat island's number and was
    /// always right.
    static let defaultRideLift: Double = 1

    /// How much of the island's give is spent going down.
    ///
    /// Its own rather than the shared `GameRules.surfaceBounceAttack`, so the
    /// drop and the return can be pulled apart from the sprite change that runs
    /// alongside them.
    static let defaultBounceAttack: Double = 0.10

    /// How far the island gives, in art pixels.
    ///
    /// The shared value is three over a fifth of a second, which on a rock the
    /// size of the island is easy to miss entirely — a cloud that size gives
    /// visibly because it is soft and the eye expects it to.
    static let defaultBounceDepth: Double = 10

    /// How many art pixels wider the island gets at the height of the rock.
    static let defaultRockSquash: Double = 8

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

    /// Settled by eye, and island-relative — see `NexysPillarView`.
    static var pillarX: CGFloat { CGFloat(defaultPillarX) }
    static var pillarY: CGFloat { CGFloat(defaultPillarY) }

    static var cursorLift: CGFloat {
        #if DEBUG
        CGFloat(NexysTuning.shared.cursorLift)
        #else
        CGFloat(defaultCursorLift)
        #endif
    }

    /// Whether the squash rides the dip's curve, and how far the dip carries
    /// past rest. Both belong to the preset rather than to a slider — they are
    /// what makes one rendition a different *idea* from another rather than the
    /// same one at different sizes.
    static var squashFollowsDip: Bool { rock.squashFollowsDip }
    static var rebound: Double { rock.rebound }

    static var rock: Rock {
        #if DEBUG
        NexysTuning.shared.rock
        #else
        defaultRock
        #endif
    }

    static var bounceHold: Double {
        #if DEBUG
        NexysTuning.shared.bounceHold
        #else
        defaultBounceHold
        #endif
    }

    static var bounceDepth: CGFloat {
        #if DEBUG
        CGFloat(NexysTuning.shared.bounceDepth)
        #else
        CGFloat(defaultBounceDepth)
        #endif
    }

    /// Only the drawn-in-perspective island. The flat one is placed correctly by
    /// `GameRules.nexysRideLift` alone.
    static var rideLift: CGFloat {
        foreshortened ? CGFloat(defaultRideLift) : 0
    }

    static var bounceAttack: Double {
        #if DEBUG
        NexysTuning.shared.bounceAttack
        #else
        defaultBounceAttack
        #endif
    }

    static var rockHold: Double {
        #if DEBUG
        NexysTuning.shared.rockHold
        #else
        defaultRockHold
        #endif
    }

    static var rockSquash: CGFloat {
        #if DEBUG
        CGFloat(NexysTuning.shared.rockSquash)
        #else
        CGFloat(defaultRockSquash)
        #endif
    }
}
