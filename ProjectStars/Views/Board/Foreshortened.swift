//
//  Foreshortened.swift
//  Project Stars
//
//  Laying the board down into the distance.
//

import SwiftUI

extension View {

    /// Tilts this view away from the viewer, so its far edge sits deeper in the
    /// picture than its near one.
    ///
    /// The board is drawn flat-on, which is honest about the grid and says
    /// nothing about the world. Foreshortening it lays the plane *down*: rows
    /// further from the player are narrower and closer together, so the board
    /// reads as ground receding rather than as a chart. It also gives the
    /// horizon below Astra something to be a horizon *of* — a flat board
    /// floating above a distant floor is two unrelated pictures.
    ///
    /// - Parameter depth: How much narrower the far edge is than the near one,
    ///   as a fraction. `0` leaves the view alone.
    /// - Parameter size: The view's own size. Passed in rather than measured.
    ///   A `GeometryReader` here is greedy — it expands to fill whatever it is
    ///   placed in and lays its content out top-leading — so measuring from
    ///   inside the modifier moved everything it touched. That is what sent the
    ///   piece floating off its square and lifted the horizon off the bottom of
    ///   the sky.
    /// - Parameter over: The height the tilt is measured against, in points.
    ///   Defaults to the view's own height, which is right for the board.
    ///
    ///   This is what puts everything on **one camera**. The convergence rate is
    ///   `depth / over`, so a view that measures against its own height
    ///   converges at a rate set by how tall it happens to be — the board and
    ///   the horizon band, same `depth`, taper toward two different vanishing
    ///   points. Passing the board's height for both makes them agree, which is
    ///   the difference between two tilted things and one scene.
    func foreshortened(
        _ depth: CGFloat = GameRules.boardForeshorten,
        size: CGSize,
        over reference: CGFloat? = nil
    ) -> some View {
        modifier(Foreshortened(depth: depth, size: size, reference: reference ?? size.height))
    }
}

extension PixelArtMetrics {

    /// Where a square's centre lands once the board has been laid down, and how
    /// much anything standing there has shrunk.
    ///
    /// ## Why objects are placed by this rather than passed through the tilt
    ///
    /// A keystone works about the **board's** centre. Anything drawn inside it
    /// is therefore sheared by how far it sits from the middle — leaning one way
    /// at the left edge and the other at the right — squashed vertically by the
    /// square of its depth, and bent so its top is narrower than its bottom.
    /// None of that can be undone from inside, because a correction applied to
    /// an object only knows about the object.
    ///
    /// So objects are never put through the projection at all. The floor is —
    /// it *is* a floor — and everything standing on it asks the floor where it
    /// should be and how big, then draws itself flat. Position and size come
    /// from the perspective; shape never does.
    func projected(
        _ point: GridPoint,
        depth: CGFloat = GameRules.boardForeshorten,
        zoom: CGFloat = GameRules.boardForeshortenScale,
        lift: CGFloat = GameRules.boardForeshortenLift
    ) -> (position: CGPoint, scale: CGFloat) {
        let flat = center(of: point)

        // The divisor is taken at the point being mapped, exactly as the board's
        // own keystone takes it per pixel. Using the square's *feet* instead put
        // every object a row or so further back than the tile it stands on —
        // the island and the piece floated up the board while the cursor, drawn
        // with the floor, stayed put.
        let up = boardSize - flat.y
        let w = 1 + depth * (up / boardSize)

        let x = boardSize / 2 + (flat.x - boardSize / 2) / w
        let y = boardSize + (flat.y - boardSize) / w

        // Then the two framing steps the board takes afterwards, in order: the
        // zoom about the near edge, and the lift up the square.
        return (
            CGPoint(
                x: boardSize / 2 + (x - boardSize / 2) * zoom,
                y: boardSize + (y - boardSize) * zoom - boardSize * lift
            ),
            zoom / w
        )
    }
}

extension View {

    /// Puts this view on the square `point`, sized for the depth it stands at.
    ///
    /// The replacement for `.position(metrics.center(of:))` on anything that is
    /// an *object* rather than ground. See `PixelArtMetrics.projected(_:)`.
    func placed(at point: GridPoint, metrics: PixelArtMetrics) -> some View {
        let spot = metrics.projected(point)
        return scaleEffect(spot.scale).position(spot.position)
    }

    /// Stands an object up on the tilted board without taking it out of the
    /// perspective.
    ///
    /// ## What is kept and what is undone
    ///
    /// The keystone does two things to anything inside it: it **scales** by how
    /// far back the object stands, and it **tapers** — squeezing the top of a
    /// tall sprite more than its bottom.
    ///
    /// The scale is kept. It is what makes a piece at the far edge smaller than
    /// the island at the near one, and removing it was the bug: Aries came out
    /// full size on a board where everything else had receded, and dwarfed the
    /// Nexys.
    ///
    /// The taper is undone. A sprite is a flat drawing of a thing that stands
    /// upright; bending it into a trapezoid reads as the figure *lying down with
    /// the floor*, which is the one part of the perspective that should not
    /// apply to it. Position and size come from the world, shape does not.
    /// - Parameter tilesTall: How many board squares the object stands. The
    ///   keystone tapers anything with height — narrower at the head than at the
    ///   feet — and a uniform scale restores the *size* while leaving the
    ///   *shape* wrong. This is what unbends it.
    /// - Parameter column: Where the object stands across the board. The
    ///   keystone works about the **board's** centre, so it drags the top of a
    ///   sprite toward the middle by an amount proportional to how far out it
    ///   stands — clockwise on the left of the board, anticlockwise on the
    ///   right, and nothing at all in the middle column. That lean is
    ///   predictable, so it is cancelled here rather than lived with.
    func upright(
        row: Int,
        column: Int,
        tileSize: CGFloat,
        tilesTall: CGFloat = 2,
        drop: CGFloat = GameRules.uprightFeetDrop,
        gridSize: Int = GameRules.gridSize,
        depth: CGFloat = GameRules.boardForeshorten
    ) -> some View {
        let size = CGSize(width: tileSize, height: tileSize * tilesTall)

        // Where the object actually stands, as a fraction of its own frame.
        //
        // Not the frame's bottom. A two-tile sprite is centred on a one-tile
        // square, so its frame hangs half a tile *below* the ground it is
        // standing on — anchoring the corrections there pivots everything about
        // a point in mid-air, and the error grows with the size of the
        // correction. Which is why row 6 was perfect: there the correction is
        // identity, so a wrong anchor costs nothing.
        let feetAnchor = UnitPoint(
            x: 0.5,
            y: (tilesTall / 2 + 0.5) / tilesTall
        )
        let feet = Foreshortened.shrink(
            row: CGFloat(row), gridSize: gridSize, depth: depth
        )
        let head = Foreshortened.shrink(
            row: CGFloat(row) - tilesTall, gridSize: gridSize, depth: depth
        )

        // Magnify the top edge by exactly as much as the board shrank it.
        let taper = head > 0 ? feet / head : 1

        // Two corrections, because the keystone does two different things.
        //
        // **The bend**, undone by the inverse keystone: the top of a tall sprite
        // is squeezed more than its bottom, and a drawing of something upright
        // should not come out a trapezoid. Measured against its own height,
        // because this is unbending *this object* rather than placing it in the
        // scene.
        //
        // **The squat**, undone by the stretch: a projective divide scales `x`
        // by `1/w` and `y` by `1/w²`, so vertical shrinks *quadratically* with
        // depth while horizontal shrinks linearly. Everything inside gets
        // steadily squatter the further back it stands, which is inherent to
        // the transform rather than a number needing tuning. Multiplying height
        // by `w` again puts both axes back on the same factor.
        //
        // What survives both is a single, even scale by the row's own depth —
        // exactly what should happen to something standing there.
        // How far the head is dragged toward the middle, in points: the same
        // horizontal offset seen at two different depths.
        let out = (CGFloat(column) - CGFloat(gridSize - 1) / 2) * tileSize
        let drag = out * (feet - head)
        let lean = atan2(drag, size.height)

        return foreshortened(1 / taper - 1, size: size, over: size.height)
            .scaleEffect(x: 1, y: 1 / feet, anchor: feetAnchor)
            // Turned back by however far the board leaned it. A shear rather
            // than a true rotation, but over something two tiles tall the
            // difference is well under a pixel, and a rotation is one modifier
            // instead of a second projection.
            .rotationEffect(.radians(Double(lean)), anchor: feetAnchor)
            // And down by the constant the corrections leave behind.
            //
            // Measured rather than derived: four art pixels, everywhere. The
            // anchor puts the pivot at the feet of a sprite standing directly
            // on its square, but the ones riding something — the piece on the
            // island above all — carry an extra lift that the anchor does not
            // know about, and it comes out as the same small rise every time.
            .offset(y: tileSize * drop)
    }
}

/// The keystone that does it.
///
/// ## Why a projection and not a 3D rotation
///
/// The same reason Libra's pans are keystoned rather than rotated: a perspective
/// divide is not symmetric and cannot be aimed. `rotation3DEffect` gives a
/// magnification that has to be corrected back out, and at whole-pixel art the
/// correction is worse than the problem. A projective transform states the
/// answer directly — *the far edge is this much narrower* — and everything else
/// follows from it.
private struct Foreshortened: ViewModifier {

    let depth: CGFloat
    let size: CGSize

    /// The height the convergence is measured against — see `foreshortened`.
    let reference: CGFloat

    /// How much the keystone shrinks things standing on `row`, where row `0` is
    /// the far edge.
    ///
    /// The transform divides by `1 - q·y` with y measured up from the near edge,
    /// so a row's factor depends only on how far up the board it is.
    /// `row` is fractional on purpose. Rounding it to an `Int` meant anything
    /// shorter than one tile — the board's front face is a quarter of one —
    /// asked about its own row, got the same factor back, and ended up with no
    /// correction at all.
    static func shrink(row: CGFloat, gridSize: Int, depth: CGFloat) -> CGFloat {
        guard gridSize > 0 else { return 1 }
        // Feet, not centre: an object stands at the bottom of its square.
        let up = (CGFloat(gridSize) - row - 1) / CGFloat(gridSize)
        return 1 / (1 + depth * up)
    }

    func body(content: Content) -> some View {
        // Negative is meaningful — it leans the far edge *toward* the viewer,
        // which is how the piece unbends itself. Only exactly zero is a no-op.
        if depth == 0 {
            content
        } else {
            content.projectionEffect(keystone(in: size))
        }
    }

    /// Measured from the **bottom** edge, which is the one nearest the viewer
    /// and therefore the one that must not move. Anchoring at the centre would
    /// push the near edge toward the player as the far edge receded, and the
    /// board would appear to grow downward off the screen.
    private func keystone(in size: CGSize) -> ProjectionTransform {
        guard size.width > 0, size.height > 0 else { return ProjectionTransform() }

        // Everything above the bottom edge has a negative y here, so dividing by
        // `1 - q·y` shrinks it — more the higher it is, and magnifies instead
        // when `depth` is negative.
        let q = depth / max(reference, 1)

        var core = ProjectionTransform()
        core.m11 = 1
        core.m22 = 1
        core.m23 = -q
        core.m33 = 1

        let toBase = ProjectionTransform(
            CGAffineTransform(translationX: -size.width / 2, y: -size.height)
        )
        let back = ProjectionTransform(
            CGAffineTransform(translationX: size.width / 2, y: size.height)
        )
        return toBase.concatenating(core).concatenating(back)
    }
}
