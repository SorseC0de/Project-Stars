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

        // A swell of its own rather than the dip's curve. Tying the two puts
        // the widest moment at the deepest, which is what compression *is* —
        // and it lost anyway, because matching the dip means holding the
        // stand-in for the whole give, and the lip snapping back after that
        // long is a cut you cannot help seeing.
        let swell = sin(Double(rock) * .pi)

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

    /// The same fade the island takes when the piece is behind it. It is part of
    /// the island; a solid pillar in front of a half-transparent rock reads as
    /// two objects.
    let isFaded: Bool

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
            .opacity(isFaded ? GameRules.nexysFadedOpacity : 1)
            .animation(.easeInOut(duration: 0.2), value: isFaded)
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
    static let defaultForeshortened = true

    /// The island's own nudge, in art pixels from the centre of its square.
    ///
    /// `islandY` is not only the sprite's placement: everything standing on the
    /// island reads it through `BoardView.surfaceOffset(of:bob:metrics:)`, so
    /// raising the island raises whoever is on it. That is the point of it being
    /// a knob rather than a constant — the island has been sitting low since the
    /// perspective rework, and the piece has to come up with it.
    static let defaultIslandX: Double = 0
    static let defaultIslandY: Double = -6

    /// The pillar, measured **from the island** rather than from the board.
    static let defaultPillarX: Double = 4
    static let defaultPillarY: Double = 2

    /// How much higher the cursor sits on the island's square, in art pixels.
    ///
    /// Applies to both sprites: the discrepancy is in `GameRules.nexysRaise`
    /// against the drawn surface, not in either drawing.
    static let defaultCursorLift: Double = 3

    /// How wide the island's art is, in art pixels: three cells of sixteen.
    static let islandArtWidth: CGFloat = CGFloat(GameRules.tilePixelSize * 3)

    // ── The settling rock ─────────────────────────────────────────────

    // ── The settling ─────────────────────────────────────────────────
    //
    // **One shape, and one knob to run it faster or slower.**
    //
    // The parts of this only mean anything together — a squash peaking while
    // the island is on its way back up says something quite different from one
    // peaking at the bottom — so they are written as a set and scaled as a set.
    // Pulling any single duration would break the relationships that make it
    // read as weight rather than as five things happening near each other.
    //
    // Two other renditions were tried and are not kept. One tied the squash to
    // the dip so the widest moment was the deepest, which is what compression
    // *is* and still lost: the sprite came back at the end of the whole give,
    // and the island's lip snapping to its other drawing after that long a hold
    // is a cut you cannot help seeing. What survives holds the stand-in for a
    // third of the give and is gone well before the interesting part.

    /// How far past rest the return carries before it settles.
    ///
    /// `CloudMotion.dip` says outright that neither cloud nor island should
    /// twang. That was written while the two shared one curve; the island has
    /// had its own since, and they are not the same thing — cloud hangs on
    /// nothing, and this hangs on a chain. A mass on a chain does not stop dead.
    static let rebound: Double = 0.30

    /// How fast the whole settling runs. `1` is the shape as it was tuned.
    static let defaultSpeed: Double = 0.80

    /// How long the flat sprite stands in, in seconds.
    static let defaultRockHold: Double = 0.14

    /// How long the island's give lasts, in seconds.
    ///
    /// Its own rather than the shared `GameRules.surfaceBounceDuration`, which
    /// also governs every cloud on Astra — the island is a rock on a chain and
    /// gives differently from a puff of cloud, and the sprite change that goes
    /// with it has to be able to line up with it.
    static let defaultBounceHold: Double = 0.42

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
    static let defaultBounceAttack: Double = 0.08

    /// How far the island gives, in art pixels.
    ///
    /// The shared value is three over a fifth of a second, which on a rock the
    /// size of the island is easy to miss entirely — a cloud that size gives
    /// visibly because it is soft and the eye expects it to.
    static let defaultBounceDepth: Double = 12

    /// How many art pixels wider the island gets at the height of the rock.
    static let defaultRockSquash: Double = 10

    static var foreshortened: Bool {
        #if DEBUG
        NexysTuning.shared.foreshortened
        #else
        defaultForeshortened
        #endif
    }

    static var islandX: CGFloat { CGFloat(defaultIslandX) }

    static var islandY: CGFloat { CGFloat(defaultIslandY) }

    /// Settled by eye, and island-relative — see `NexysPillarView`.
    static var pillarX: CGFloat { CGFloat(defaultPillarX) }
    static var pillarY: CGFloat { CGFloat(defaultPillarY) }

    static var cursorLift: CGFloat { CGFloat(defaultCursorLift) }

    /// **The one knob.** Every duration is divided by it and every distance is
    /// left alone, so the settling runs faster or slower without any part of it
    /// changing shape relative to any other.
    static var speed: Double {
        #if DEBUG
        max(NexysTuning.shared.speed, 0.05)
        #else
        defaultSpeed
        #endif
    }

    static var bounceHold: Double { defaultBounceHold / speed }

    static var bounceDepth: CGFloat { CGFloat(defaultBounceDepth) }

    /// Only the drawn-in-perspective island. The flat one is placed correctly by
    /// `GameRules.nexysRideLift` alone.
    static var rideLift: CGFloat {
        foreshortened ? CGFloat(defaultRideLift) : 0
    }

    /// A *share* of the give rather than a length, so it is already
    /// proportional and the speed leaves it alone.
    static var bounceAttack: Double { defaultBounceAttack }

    static var rockHold: Double { defaultRockHold / speed }

    static var rockSquash: CGFloat { CGFloat(defaultRockSquash) }
}
