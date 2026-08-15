//
//  CloudFieldView.swift
//  Project Stars
//
//  All of Astra's cloud, in one pass.
//

import SwiftUI

/// Every ordinary Astra square, drawn as a single `Canvas`.
///
/// ## Why the whole plane and not a view per square
///
/// `CloudTileView` already moved one cluster's 39 shapes off SwiftUI's view
/// system and into a `Canvas`, which is what a cluster needs. What was left is
/// structural: **49 separate `TimelineView`s**, each waking its own subtree
/// every frame, each producing its own `Canvas`, each composited separately.
/// That is 49 invalidations and 49 layers per frame for something the player
/// reads as one surface.
///
/// One `TimelineView` and one `Canvas` for the whole field is one invalidation
/// and one layer. The drawing is identical — both routes call
/// `CloudCluster.paint` — so nothing about how a cloud looks depends on which
/// of them drew it.
///
/// ## What still draws itself
///
/// The raised square under a Pentacle. It is depth-sorted with the pieces rather
/// than laid down with the board, so it has to be a view of its own; it is
/// excluded here and `CloudTileView` handles it. Structural squares — the island
/// and its chasm — are not cloud at all and never came through here.
///
/// ## Why it runs at its own frame rate
///
/// `TimelineView(.animation)` redraws at whatever the display does, which on a
/// ProMotion device is 120Hz. Astra is roughly two thousand primitives a pass
/// against Terra's handful of sprites, so it was paying four times over for
/// motion nothing can perceive: the clouds drift on a five-second period and the
/// puffs breathe over seconds. `GameRules.cloudFrameRate` holds it to thirty,
/// which is more than the movement needs and more than pixel art has ever
/// wanted.
///
/// ## Why wear easing is kept by hand
///
/// A `Canvas` has no per-square view to hang an implicit animation on, and with
/// one canvas for the field there is not even a view per square to hold `@State`.
/// So the field keeps its own small table of what each square was and when it
/// changed, and eases between the two. Same approach as everything else here:
/// a timestamp and a curve, never a stranded animation.
struct CloudFieldView: View {

    let board: Board
    let metrics: PixelArtMetrics

    /// Squares flashing because they just changed state.
    var flashing: Set<GridPoint> = []

    /// A stopped clock, while a move plays out.
    ///
    /// Handed a time rather than told to stop: every cluster is a pure function
    /// of a timestamp, so freezing them is a matter of passing the same one
    /// twice. See `GameSession.ambientFreeze`.
    var freeze: TimeInterval?

    /// The raised squares, which draw themselves. See the note above.
    var excluding: Set<GridPoint> = []

    /// Stops the field's clock. See `GameRules.cloudFrameRate`.
    var isPaused = false

    /// Paint only this row, or every row when `nil`.
    ///
    /// The field is one `Canvas` over all forty-nine squares, which is the
    /// cheapest way to draw them and the one thing that cannot be put on a
    /// band — a band is a row. Splitting the work by row costs seven canvases
    /// instead of one and changes nothing about how much is painted.
    var onlyRow: Int?

    /// What each square was before its current state, and when it changed.
    @State private var wearing: [GridPoint: Ease] = [:]

    private struct Ease: Equatable {
        var from: CGFloat
        var startedAt: Date
    }

    var body: some View {
        TimelineView(
            .animation(minimumInterval: 1 / GameRules.cloudFrameRate, paused: isPaused)
        ) { timeline in
            let now = freeze ?? timeline.date.timeIntervalSinceReferenceDate

            Canvas { context, _ in
                for point in board.allPoints {
                    guard onlyRow == nil || point.y == onlyRow else { continue }
                    guard !excluding.contains(point) else { continue }

                    let tile = board[point]
                    guard tile.kind == .normal else { continue }

                    let shade = Palette.TileShade.at(point)

                    // Each square gets its own copy of the context: `paint`
                    // leaves its transform where it finished, and unwinding that
                    // 48 times is both slower and easier to get wrong.
                    // Where this square's row puts it, and how big that row
                    // draws it. A cluster is already drawn in perspective, so
                    // it wants a size and a place and nothing else.
                    let spot = metrics.projected(point)

                    var square = context
                    CloudCluster.paint(
                        CloudCluster.Brush(
                            centre: spot.position,
                            point: point,
                            wear: wear(at: point, health: tile.health, now: now),
                            tones: Palette.cloudTones(shade),
                            speckleTones: Palette.speckleTones(raised: false),
                            scale: metrics.scale * spot.scale,
                            size: metrics.tileSize * spot.scale,
                            isFlashing: flashing.contains(point)
                        ),
                        into: &square,
                        at: now
                    )
                }
            }
        }
        .frame(width: metrics.boardSize, height: metrics.boardSize)
        .allowsHitTesting(false)
        // The clusters are functions of the clock; nobody else may interpolate
        // them. See the same note on `CloudTileView`.
        .transaction { $0.animation = nil }
        .onChange(of: healths) { previous, current in
            for (point, health) in current where previous[point] != health {
                wearing[point] = Ease(
                    from: GameRules.cloudScale(previous[point] ?? .healthy),
                    startedAt: .now
                )
            }
        }
    }

    /// How much of a square's cluster is left, easing toward its new state.
    private func wear(at point: GridPoint, health: TileHealth, now: TimeInterval) -> CGFloat {
        let target = GameRules.cloudScale(health)
        guard let ease = wearing[point] else { return target }

        let elapsed = now - ease.startedAt.timeIntervalSinceReferenceDate
        let linear = min(max(elapsed / GameRules.cloudWearDuration, 0), 1)
        let eased = CGFloat(linear * linear * (3 - 2 * linear))

        return ease.from + (target - ease.from) * eased
    }

    /// The board reduced to what this view actually cares about, so a change
    /// anywhere else does not restart every square's shrink.
    private var healths: [GridPoint: TileHealth] {
        var map: [GridPoint: TileHealth] = [:]
        for point in board.allPoints where board[point].kind == .normal {
            map[point] = board[point].health
        }
        return map
    }
}
