//
//  BoardBands.swift
//  Project Stars
//
//  The board as a stack of rows, back to front.
//

import SwiftUI

/// Where one row of the board sits and how big it is drawn.
///
/// ## Why rows instead of a projection
///
/// Because a projection cannot be undone from inside itself. Anything drawn
/// within a keystone is sheared by how far it sits from the board's middle,
/// squashed by the square of its depth, and bent so its top is narrower than
/// its base — and a correction applied to a sprite only knows about the sprite,
/// never about where on the board it stands. Every constant that accumulated
/// while chasing that — a feet drop, a float follow, a shadow lift, a whole
/// `upright` modifier — was compensation for the wrong shape.
///
/// A band is a plain rectangle at a plain scale. There is no shear to cancel, no
/// taper to undo, and no squash: everything standing on a row shares one uniform
/// scale and that is the entire transform.
///
/// ## What it buys beyond correctness
///
/// **Depth sorts itself.** Rows are drawn back to front, so a nearer row covers
/// what is behind it — no sort key, no special case for the island's overhang,
/// no rule about the piece standing north of it. A cloud bobbing up in front
/// genuinely occludes the feet of a piece behind it, which is real depth out of
/// motion that already existed. A piece falling can slide down *behind* the row
/// in front of it and be swallowed by the floor rather than faking a shrink.
///
/// **Pixel art gets sharper.** A row takes one scale rather than being warped
/// continuously across its width, so it can land on whole pixels — the one thing
/// a projection can never offer.
///
/// ## Matching what the keystone drew
///
/// These are not new numbers to taste. They are the keystone sampled once per
/// row: `w` is the same divisor, so the bands reproduce the image the projection
/// produced. The only difference is *within* a row, where a band does not taper
/// — a fraction of a pixel across one row at this size.
struct BoardBand {

    /// How much smaller everything standing on this row is drawn.
    let scale: CGFloat

    /// And how much shorter the row's *ground* is drawn.
    ///
    /// Not the same number. A projective divide pushes row centres apart by
    /// `1/w²` while narrowing them by `1/w`, so a band scaled evenly ends up
    /// shorter than the space it has to fill and a gap opens between rows —
    /// wider the further back you look.
    ///
    /// Squashing the ground closes it, and it is the truth about a floor
    /// anyway: seen at an angle, a square of ground is shorter than it is wide.
    /// What must *not* take the squash is anything standing on the row, which is
    /// why the two scales are separate.
    ///
    /// Taken from the **measured distance to the next row**, and then
    /// overdrawn a little — see `GameRules.boardBandOverlap`.
    ///
    /// Measuring alone is not quite enough, because the lean compresses a band
    /// vertically *before* this scale is applied, so a band sized to the gap
    /// still lands short of it. Rather than chase that factor, each band simply
    /// reaches past its neighbour: rows are drawn back to front, so the row in
    /// front covers the overlap and nothing of it is ever seen.
    ///
    /// Not from `1/w²`.
    /// The square is the right shape but a hair short, and short bands leave
    /// hairline seams of sky between rows. Measuring the gap the band actually
    /// has to fill closes them exactly, at every depth and every board size.
    let groundScale: CGFloat

    /// Where the row's centre sits, in points down the board.
    let centreY: CGFloat

    /// The keystone's divisor for `row`, counting `0` as the far edge.
    static func divisor(
        row: Int,
        gridSize: Int = GameRules.gridSize,
        depth: CGFloat = GameRules.boardForeshorten
    ) -> CGFloat {
        let last = CGFloat(max(gridSize - 1, 1))
        let back = 1 - CGFloat(row) / last
        return 1 + depth * back
    }

    /// How much narrower this row's **far** edge is than its near one.
    ///
    /// A band is a rectangle, so a stack of them steps at the sides like a
    /// ziggurat however well the heights line up. Leaning each one — its back
    /// edge pulled in to exactly the width of the row behind it — makes the
    /// silhouette continuous again, and the board reads as one angled plane
    /// rather than seven shelves.
    ///
    /// It is a taper on the *ground* only. Nothing standing on the row is put
    /// through it, which is the whole reason for drawing in bands.
    static func lean(
        row: Int,
        gridSize: Int = GameRules.gridSize,
        depth: CGFloat = GameRules.boardForeshorten
    ) -> CGFloat {
        let here = divisor(row: row, gridSize: gridSize, depth: depth)
        let behind = divisor(row: row - 1, gridSize: gridSize, depth: depth)
        guard behind > 0 else { return 0 }
        return 1 - here / behind
    }

    /// The band for `row`, matching what the projection drew there.
    static func at(
        row: Int,
        metrics: PixelArtMetrics,
        depth: CGFloat = GameRules.boardForeshorten,
        zoom: CGFloat = GameRules.boardForeshortenScale,
        lift: CGFloat = GameRules.boardForeshortenLift
    ) -> BoardBand {
        let w = divisor(row: row, gridSize: metrics.gridSize, depth: depth)

        let centre = centreY(row: row, metrics: metrics, depth: depth, zoom: zoom, lift: lift)
        let behind = centreY(row: row - 1, metrics: metrics, depth: depth, zoom: zoom, lift: lift)

        // Exactly the space this band has to fill, so no sky can show between
        // it and the row behind it. Doubled because the gap is measured to the
        // neighbour's *centre*, which is half a band away.
        let reach = abs(centre - behind)

        return BoardBand(
            scale: zoom / w,
            groundScale: reach / metrics.tileSize * GameRules.boardBandOverlap,
            centreY: centre
        )
    }

    /// Where a row's centre lands, through the same three steps the board takes:
    /// the keystone's divide about the near edge, the zoom about it, and the
    /// lift up the square.
    ///
    /// Answers for `-1` too — the row that would sit behind the far edge — which
    /// is what lets the back band measure its own reach.
    private static func centreY(
        row: Int,
        metrics: PixelArtMetrics,
        depth: CGFloat,
        zoom: CGFloat,
        lift: CGFloat
    ) -> CGFloat {
        let board = metrics.boardSize
        let w = divisor(row: row, gridSize: metrics.gridSize, depth: depth)
        let flat = (CGFloat(row) + 0.5) * metrics.tileSize
        let keystoned = board + (flat - board) / w
        return board + (keystoned - board) * zoom - board * lift
    }
}

extension View {

    /// Puts this view on the given row, without scaling it.
    ///
    /// The two things a row carries scale differently — see
    /// `BoardBand.groundScale` — so they are scaled separately and only their
    /// *placement* is shared.
    func onBoardRow(_ row: Int, metrics: PixelArtMetrics) -> some View {
        position(x: metrics.boardSize / 2, y: BoardBand.at(row: row, metrics: metrics).centreY)
    }

    /// Draws this view as the given row's **ground**: narrowed, and squashed by
    /// the square so it meets the rows either side of it.
    func asBoardRow(_ row: Int, metrics: PixelArtMetrics) -> some View {
        let band = BoardBand.at(row: row, metrics: metrics)
        return foreshortened(
            BoardBand.lean(row: row, gridSize: metrics.gridSize),
            size: CGSize(width: metrics.boardSize, height: metrics.tileSize)
        )
            .scaleEffect(x: band.scale, y: band.groundScale)
            .onBoardRow(row, metrics: metrics)
    }

    /// And this view as something *standing* on it: evenly scaled, never
    /// squashed.
    func standingOnBoardRow(_ row: Int, metrics: PixelArtMetrics) -> some View {
        scaleEffect(BoardBand.at(row: row, metrics: metrics).scale)
            .onBoardRow(row, metrics: metrics)
    }
}
