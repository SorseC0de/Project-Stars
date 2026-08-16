//
//  BoardBands.swift
//  Project Stars
//
//  The board as a stack of rows, back to front.
//

import SwiftUI

// - TODO: **Falls should use the rows.** Enhance a fall with a zoom-in, a
//   y-offset and the board going transparent as the piece drops through it.
//   Per-row Z-ordering was adopted partly to make this possible: a falling
//   piece can slide down *behind* the row in front of it and be swallowed by
//   the floor, instead of faking a shrink. See `GameRules.fallDuration`.

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
    /// Taken from the **measured distance to the next row**, corrected for the
    /// lean's own squeeze, and then overdrawn a hair.
    ///
    /// Not from `1/w²`: the square is the right shape but a hair short, and
    /// short bands leave hairline seams of sky between rows. Measuring the gap
    /// the band actually has to fill closes them at every depth and board size.
    ///
    /// Plus the art's own two-pixel border — see `GameRules.tileBorderPixels`.
    /// The tiles are drawn to overlap their neighbours by that much, so the bare
    /// geometric gap is short by exactly two pixels on every row.
    /// The square is the right shape but a hair short, and short bands leave
    /// hairline seams of sky between rows. Measuring the gap the band actually
    /// has to fill closes them exactly, at every depth and every board size.
    let groundScale: CGFloat

    /// Where the row's centre sits, in points down the board.
    let centreY: CGFloat

    /// How much the band's far edge is narrowed, as the keystone wants it.
    let lean: CGFloat

    /// Where the row's *ground* frame must be centred.
    ///
    /// Not the same as `centreY`, and conflating them is what left seams even
    /// once the heights were exact. The frame is always one tile tall — a
    /// projection does not change layout — while the ground drawn inside it is
    /// the band's own height, so the two are only aligned at the edge the scale
    /// is anchored to. Anchoring at the **bottom** pins the near edge, which is
    /// the edge shared with the row in front, so consecutive bands meet exactly.
    let groundCentreY: CGFloat

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
        // A band spans the ground between two **edges**, and its height is the
        // distance between them. Measuring centre-to-centre instead — which is
        // what this did — asks for half of this band plus half of the one
        // behind it, and the one behind it is smaller, so every band came out
        // short. Short by more toward the front, where the difference between
        // neighbouring bands is largest, which is exactly the shape of the seam
        // that no single multiplier could close.
        let top = edgeY(row, metrics: metrics, depth: depth, zoom: zoom, lift: lift)
        let bottom = edgeY(row + 1, metrics: metrics, depth: depth, zoom: zoom, lift: lift)
        let height = bottom - top

        // The taper is applied by a keystone that divides by `1 + lean`, so the
        // far edge is `1 / (1 + lean)` of the near one — meaning the lean that
        // narrows this band's back to the width of the row behind it is the
        // *ratio of the divisors*, not one minus its reciprocal. The two agree
        // to first order and drift a few percent apart at this depth.
        let front = edgeDivisor(row + 1, gridSize: metrics.gridSize, depth: depth)
        let back = edgeDivisor(row, gridSize: metrics.gridSize, depth: depth)
        let lean = back / front - 1

        // That same divide shortens the band as well as narrowing it: its top
        // is pulled down to `1 / (1 + lean)` of its height. Pre-stretching by
        // `1 + lean` lands it on exactly the height measured above — which is
        // what the STRETCH dial had been standing in for.
        // The row's centre for anything *standing* on it is where the square's
        // middle actually projects, which is not the midpoint of the two edges
        // — the near half of a receding square covers more screen than the far
        // half. Objects use this; the ground uses its edges.
        let board = metrics.boardSize
        let up = board - (CGFloat(row) + 0.5) * metrics.tileSize
        let mid = board - GameRules.boardCamera * depth * up / divisor(row: row, gridSize: metrics.gridSize, depth: depth)

        return BoardBand(
            scale: zoom / front,
            groundScale: height * (1 + lean) / metrics.tileSize,
            centreY: board + (mid - board) * zoom - board * lift,
            lean: lean,
            groundCentreY: bottom - metrics.tileSize / 2
        )
    }

    /// The divisor at an **edge** — `0` is the board's far edge, `gridSize` its
    /// near one — as opposed to `divisor(row:)`, which answers at a row's centre.
    static func edgeDivisor(
        _ edge: Int,
        gridSize: Int = GameRules.gridSize,
        depth: CGFloat = GameRules.boardForeshorten
    ) -> CGFloat {
        1 + depth * (1 - CGFloat(edge) / CGFloat(max(gridSize, 1)))
    }

    /// Where an edge lands on screen, through the same map the ground itself is
    /// drawn with, so bands and tiles cannot disagree.
    static func edgeY(
        _ edge: Int,
        metrics: PixelArtMetrics,
        depth: CGFloat = GameRules.boardForeshorten,
        zoom: CGFloat = GameRules.boardForeshortenScale,
        lift: CGFloat = GameRules.boardForeshortenLift
    ) -> CGFloat {
        let board = metrics.boardSize
        let up = board - CGFloat(edge) * metrics.tileSize
        let w = edgeDivisor(edge, gridSize: metrics.gridSize, depth: depth)
        let y = board - GameRules.boardCamera * depth * up / w

        // Rounded to a whole point, because a band is rasterised, not merely
        // computed. Two neighbours already share this exact edge as a `CGFloat`
        // — but a band whose height lands on a fraction has its last row of
        // pixels blended to half coverage, and half coverage over sky is a
        // hairline of sky. Integer edges make every band an integer number of
        // points tall, so there is nothing left to blend.
        return ((board + (y - board) * zoom - board * lift)).rounded()
    }

}

extension View {

    /// Puts this view on the given row, without scaling it.
    func onBoardRow(
        _ row: Int,
        metrics: PixelArtMetrics,
        zoom: CGFloat = GameRules.boardForeshortenScale
    ) -> some View {
        position(
            x: metrics.boardSize / 2,
            y: BoardBand.at(row: row, metrics: metrics, zoom: zoom).centreY
        )
    }

    /// Draws this view as the given row's **ground**: narrowed toward the back,
    /// and exactly as tall as the gap between the two edges it spans.
    func asBoardRow(
        _ row: Int,
        metrics: PixelArtMetrics,
        zoom: CGFloat = GameRules.boardForeshortenScale
    ) -> some View {
        let band = BoardBand.at(row: row, metrics: metrics, zoom: zoom)
        return foreshortened(
            band.lean,
            size: CGSize(width: metrics.boardSize, height: metrics.tileSize)
        )
            // Grown from the **top**, so the extra height only ever reaches
            // toward the viewer. From the centre it would reach back over the
            // row behind, which with bands drawn back to front is what ate the
            // far rows' borders while the near ones looked right.
            // Anchored at the **bottom**, so the near edge — the one shared
            // with the row in front — never moves however the band is scaled.
            // Any overdraw then reaches away from the viewer, into ground the
            // row behind has already covered.
            .scaleEffect(x: band.scale, y: band.groundScale, anchor: .bottom)
            .position(x: metrics.boardSize / 2, y: band.groundCentreY)
    }

    /// Places a **board-sized** layer so that `row`'s squares land on `row`'s
    /// band, scaled evenly and not tapered at all.
    ///
    /// For art that is already drawn in perspective — Astra's clouds are, so
    /// putting them through a keystone would foreshorten them twice. All they
    /// want from the board is how big to be, where to sit, and who covers whom.
    ///
    /// The offset is the whole trick. A board-sized layer scales about its own
    /// centre, so a row away from the middle is carried away from wherever it
    /// was told to go, by its distance from that centre times the scale. Undoing
    /// that is what lets the layer keep board coordinates inside — every square
    /// still paints itself at `metrics.center(of:)` and knows nothing about any
    /// of this.
    func asFlatBoardRow(_ row: Int, metrics: PixelArtMetrics) -> some View {
        let band = BoardBand.at(row: row, metrics: metrics)
        let middle = metrics.boardSize / 2
        let flat = (CGFloat(row) + 0.5) * metrics.tileSize
        return scaleEffect(band.scale)
            .position(x: middle, y: band.centreY - (flat - middle) * band.scale)
    }

    /// One **square** of ground, taking its row's shape.
    ///
    /// The band treatment for a single tile rather than a whole row: same lean,
    /// same squash, same near-edge anchor. Anything that is *ground* wants this
    /// — a lifted tile is still ground, and so is a mark painted on it.
    ///
    /// The difference from `standingOnBoardRow` is the vertical squash. A figure
    /// standing on a row must never take it or it comes out squat; a tile must
    /// always take it or it comes out flat against a floor that is lying down.
    func asBoardSquare(_ point: GridPoint, metrics: PixelArtMetrics) -> some View {
        let band = BoardBand.at(row: point.y, metrics: metrics)
        let middle = metrics.boardSize / 2
        let flat = metrics.center(of: point)
        // The lean pulls toward the **board's** centre, not the square's.
        //
        // A whole row is one box `boardSize` wide, so its keystone narrows
        // everything toward the middle of the board. The same keystone over a
        // box one tile wide narrows toward the middle of that tile — which is
        // no movement at all for the tile itself, and leaves a square in an
        // outer column sitting further out than the ground it belongs to. The
        // further from centre, the further out, which is why it read as the
        // outer columns drifting.
        //
        // Measured at the square's own middle height, where the taper is half
        // applied: the band's near edge is untouched and its far edge takes the
        // whole lean, so the centre takes half.
        let drawnIn = 1 + band.lean / 2

        return foreshortened(
            band.lean,
            size: CGSize(width: metrics.tileSize, height: metrics.tileSize)
        )
            .scaleEffect(x: band.scale, y: band.groundScale, anchor: .bottom)
            .position(
                x: middle + (flat.x - middle) * band.scale / drawnIn,
                y: band.groundCentreY
            )
    }

    /// And this view as something *standing* on it: evenly scaled, never
    /// squashed, and sized at the row's centre rather than its front edge —
    /// which is where the object's feet actually are.
    func standingOnBoardRow(
        _ row: Int,
        metrics: PixelArtMetrics,
        zoom: CGFloat = GameRules.boardForeshortenScale
    ) -> some View {
        let w = BoardBand.divisor(row: row, gridSize: metrics.gridSize)
        return scaleEffect(GameRules.boardForeshortenScale / w)
            .onBoardRow(row, metrics: metrics, zoom: zoom)
    }
}
