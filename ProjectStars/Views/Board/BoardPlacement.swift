//
//  BoardPlacement.swift
//  Project Stars
//
//  Where a thing standing on the tilted board belongs.
//

import SwiftUI

/// The board's perspective, expressed as arithmetic rather than as a transform.
///
/// ## Why this is not a keystone
///
/// The floor is genuinely keystoned — it is a floor, and it should taper, shear
/// and squash. Anything *standing* on it should not: a sprite is a flat drawing
/// of an upright thing, and passing it through the same transform bends it,
/// squats it, and leans it by however far it sits from the board's middle.
///
/// Correcting that from inside the projection cannot work, because a correction
/// applied to an object only knows about the object — and the shear depends on
/// where the object is. So objects are drawn **above** the tilt and placed here.
///
/// ## The model
///
/// Linear, in two numbers per axis. Given the near row's spacing and scale and
/// the far row's, everything between is `t = row / (gridSize - 1)`:
///
/// - `y` steps evenly from the far row's centre to the near row's.
/// - `x` is the centre plus `(column - middle) × spacing(row)`.
/// - `scale` steps evenly from the far row's to the near row's.
///
/// The art is on a sixteen-pixel grid, so a correct model lands on whole
/// numbers. A value that refuses to sit on an integer is a sign the model is
/// wrong rather than that it wants another decimal.
struct BoardPlacement {

    /// Where the far row (`0`) and the near row sit, as fractions of the board
    /// measured from its top.
    var farY: CGFloat
    var nearY: CGFloat

    /// How far apart column centres are on each of those rows, as fractions of
    /// a tile.
    var farSpacing: CGFloat
    var nearSpacing: CGFloat

    /// And how big something standing there is drawn.
    var farScale: CGFloat
    var nearScale: CGFloat

    /// Where a square's *centre* is, and the scale of anything standing on it.
    func place(
        _ point: GridPoint,
        metrics: PixelArtMetrics,
        gridSize: Int = GameRules.gridSize
    ) -> (position: CGPoint, scale: CGFloat) {
        let last = CGFloat(max(gridSize - 1, 1))
        let t = CGFloat(point.y) / last
        let middle = last / 2

        let spacing = (farSpacing + (nearSpacing - farSpacing) * t) * metrics.tileSize
        let y = (farY + (nearY - farY) * t) * metrics.boardSize
        let x = metrics.boardSize / 2 + (CGFloat(point.x) - middle) * spacing

        return (
            CGPoint(x: x, y: y),
            farScale + (nearScale - farScale) * t
        )
    }

    /// The home square's centre is the **source of truth**.
    ///
    /// Once `(3,3)` is homed, everything else is measured from it rather than
    /// tuned on its own: the board's lift is applied to it, the island's float
    /// is its `y` less four art pixels, and every other square is a whole
    /// number of steps away along the row and column. Nothing downstream gets
    /// its own number.
    func home(metrics: PixelArtMetrics) -> CGPoint {
        place(GameRules.nexysPoint, metrics: metrics).position
    }

    /// The starting guess, to be homed on device.
    ///
    /// Derived from the floor's own tilt so the rig opens somewhere sane rather
    /// than at zero: the near row keeps a full tile of spacing and full size,
    /// and the far row is narrowed and shrunk by the keystone's divisor there.
    static var initial: BoardPlacement {
        let w = 1 + GameRules.boardForeshorten
        return BoardPlacement(
            farY: 0.16,
            nearY: 0.94,
            farSpacing: 1 / w,
            nearSpacing: 1,
            farScale: GameRules.boardForeshortenScale / w,
            nearScale: GameRules.boardForeshortenScale
        )
    }
}

extension View {

    /// Stands this view on `point`, flat and upright, at that row's size.
    func standing(
        on point: GridPoint,
        metrics: PixelArtMetrics,
        placement: BoardPlacement
    ) -> some View {
        let spot = placement.place(point, metrics: metrics)
        return scaleEffect(spot.scale).position(spot.position)
    }
}

/// # The rule for anything with a grid position
///
/// **If a thing has a grid X and Y, it takes its row's scale and its row's Z.**
/// Both. Always. On both planes.
///
/// Not a guideline applied object by object — that is how the cursor, the
/// facing arrow, the raised tiles and the edges each ended up needing their own
/// fix. There is one way onto the board and it is this modifier: it asks the
/// row how big and where, and `BoardObject.draw` sorts by row so the answer to
/// "who covers whom" is never written down anywhere else.
///
/// Anything that reaches for `metrics.center(of:)` and `.position` directly is
/// bypassing the rule, and will be right by accident until the perspective
/// changes.
///
/// Puts an object on its square using its plane's own camera.
///
/// A `ViewModifier` rather than a method so the framing is resolved once, where
/// the plane is known, instead of at every call site.
struct PlacedOnPlane: ViewModifier {

    let point: GridPoint
    let metrics: PixelArtMetrics
    let framing: (emphasis: CGFloat, zoom: CGFloat, lift: CGFloat, pivot: CGFloat, spacing: CGSize)

    /// For content that has already placed itself absolutely — see
    /// `OnBoard`, where a sheared Terra mark does exactly that.
    var isDisabled = false

    func body(content: Content) -> some View {
        if isDisabled {
            content
        } else {
            placed(content)
        }
    }

    private func placed(_ content: Content) -> AnyView {
        // Terra's ground is drawn in bands, so anything standing on it is
        // centred on the band rather than on where the square projects to. See
        // `BoardBand.drawnCentreY`.
        if framing.pivot == 1 {
            let band = BoardBand.at(row: point.y, metrics: metrics)
            let spot = metrics.projected(
                point,
                zoom: framing.zoom,
                lift: framing.lift,
                emphasis: framing.emphasis,
                pivot: framing.pivot,
                spacing: framing.spacing
            )

            // Feet on the band's **bottom edge**, not centres together.
            //
            // The two shrink at different rates — see `BoardBand.heightY` — so
            // matching centres leaves an object hanging lower in its tile the
            // further back it is. Matching the edge it stands on is the only
            // alignment that holds at every depth, and it is also the true one:
            // what a piece shares with its square is the ground, not a midpoint.
            // Centred on the band, plus the one thing the content cannot know.
            //
            // A view drawn to stand on a tile already offsets itself by half a
            // **tile** — `PieceView` does exactly that, and it is right to. But
            // a band is not a tile: it is shorter, and shorter the further back
            // it is, because the ground is foreshortened and the sprite is not.
            //
            // So the content places itself against `tileSize * scale` while the
            // ground it is standing on is only `heightY` deep, and the gap
            // between those two is the whole error — a constant number of
            // pixels at the front, and a growing share of the tile toward the
            // back. Handing that difference back is the correction, and it
            // falls out of the geometry rather than being tuned.
            // **Half** the difference, which is the measured answer.
            //
            // Centring on the band alone sinks the figure toward the back;
            // handing back the whole difference lifts it toward the back. Both
            // errors grow with depth, so the truth sits between them — and that
            // it lands on a half is the tell: the sprite and the ground each
            // give up one of the two heights, so each owes half the gap between
            // them rather than either owing all of it.
            let mismatch = (band.heightY - metrics.tileSize * spot.scale)
                / 2 * GameRules.standOnBandShare

            return AnyView(
                content
                    .scaleEffect(spot.scale)
                    .position(x: spot.position.x, y: band.drawnCentreY + mismatch)
            )
        }

        return AnyView(content.placed(
            at: point,
            metrics: metrics,
            emphasis: framing.emphasis,
            zoom: framing.zoom,
            lift: framing.lift,
            pivot: framing.pivot,
            spacing: framing.spacing
        ))
    }
}
