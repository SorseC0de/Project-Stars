//
//  GrassView.swift
//  Project Stars
//
//  Ground cover, generated rather than drawn.
//

import SwiftUI

/// One speck of bare ground showing through.
struct DirtSpeck: Hashable {
    let x: Int
    let y: Int

    /// True for the paler of the two tones. Most specks are.
    let pale: Bool
}

/// Ten patches of dirt, generated once and dealt out by the squares.
///
/// ## Why they are made up front
///
/// A shader could splotch a tile at draw time, and did — but a shader that runs
/// per pixel per frame to draw a dozen specks is a great deal of machinery for
/// something that never changes once it exists, and the noise it produced was
/// samey enough that every tile looked like the same patch of dirt.
///
/// So the patches are built once, at launch, and each square draws a straw
/// saying which one it wears. Drawing dirt is then a list of a dozen rectangles
/// — no shader, no per-frame work, and ten visibly different patches instead of
/// one blurred idea of a patch.
///
/// A square draws a fresh straw whenever its cover is stripped, so ground that
/// is grassed, trampled and grassed again comes back different. See
/// `Tile.seed`.
enum DirtPatterns {

    /// How many patches exist, how many specks each holds, and how far from the
    /// tile's edge they may sit.
    static let count = 10

    static let all: [[DirtSpeck]] = (0..<count).map { patch(seed: UInt64($0) &+ 1) }

    /// The patch a square wearing `seed` gets, or nothing at all.
    ///
    /// **Most squares have none.** Bare ground everywhere is not ground showing
    /// through grass, it is a dirt field with grass on it — the exception is
    /// what makes it read as wear. Roughly one square in five, decided by the
    /// same straw that picks which patch.
    static func patch(for seed: UInt8) -> [DirtSpeck] {
        // **Two questions, two numbers.**
        //
        // Both used to be `seed % something` on the same value: a square that
        // passed `% 5 == 0` could only ever be 0, 5, 10 … so `% 10` picked
        // patch 0 or patch 5 and the other eight were never drawn. Mixing the
        // seed once and taking different halves of the result keeps them
        // independent.
        let mixed = Int(seed) &* 2_654_435_761
        guard (mixed >> 3) % GameRules.dirtOneTileIn == 0 else { return [] }
        return all[abs(mixed >> 11) % count]
    }

    private static func patch(seed: UInt64) -> [DirtSpeck] {
        var generator = SeededRandom(seed: seed &* 6_364_136)
        let cell = GameRules.tilePixelSize
        let inset = GameRules.dirtInset

        // **One big, one small.** A single large patch with a smaller one
        // beside it reads as ground worn through in one place and starting to
        // in another; several equal clumps read as a pattern. The small one is
        // often adjacent, which is what makes the pair look like one ragged
        // shape rather than two marks.
        let sizes = [
            GameRules.dirtClumpLargest,
            GameRules.dirtClumpSmallest
                + Int(generator.next() % UInt64(
                    GameRules.dirtClumpLargest - GameRules.dirtClumpSmallest + 1
                )),
        ]

        var specks: Set<DirtSpeck> = []

        for size in sizes {
            // **Grown, not stamped.** A clump starts on one pixel and adds a
            // neighbour of something already in it, over and over. That gives
            // the ragged edge bare ground has — a disc or a blob would read as
            // something spilled on the tile rather than as the tile wearing
            // through.
            let span = cell - inset * 2
            var patch: [(x: Int, y: Int)] = [(
                inset + Int(generator.next() % UInt64(span)),
                inset + Int(generator.next() % UInt64(span))
            )]

            while patch.count < size {
                let from = patch[Int(generator.next() % UInt64(patch.count))]
                let step = Int(generator.next() % 4)
                let next = (
                    x: from.x + (step == 0 ? 1 : step == 1 ? -1 : 0),
                    y: from.y + (step == 2 ? 1 : step == 3 ? -1 : 0)
                )

                guard next.x >= inset, next.x < cell - inset,
                      next.y >= inset, next.y < cell - inset
                else { continue }

                if !patch.contains(where: { $0 == next }) { patch.append(next) }
            }

            // One tone per clump, mostly the paler: a patch of ground is one
            // colour with the odd darker pixel, not a stipple of two.
            let pale = generator.next() % 3 != 0
            for pixel in patch {
                let odd = generator.next() % 5 == 0
                specks.insert(
                    DirtSpeck(x: pixel.x, y: pixel.y, pale: odd ? !pale : pale)
                )
            }
        }

        return Array(specks)
    }
}

/// The dirt under a patch of grass.
///
/// Draws the patch this square drew a straw for — see `DirtPatterns`. One art
/// pixel per speck, which is as small as the board can express and what stops
/// them reading as blotches.
struct GrassDirt: View {

    let shade: Palette.TileShade
    let seed: UInt8
    let size: CGFloat

    /// Light tiles show `slate` over `stone`; dark ones `stone` over `steel`.
    private var tones: (pale: Color, deep: Color) {
        switch shade {
        case .light: (Palette.slate, Palette.stone)
        case .dark: (Palette.stone, Palette.steel)
        }
    }

    var body: some View {
        let pixel = size / CGFloat(GameRules.tilePixelSize)

        Canvas { context, _ in
            for speck in DirtPatterns.patch(for: seed) {
                context.fill(
                    Path(
                        CGRect(
                            x: CGFloat(speck.x) * pixel,
                            y: CGFloat(speck.y) * pixel,
                            width: pixel,
                            height: pixel
                        )
                    ),
                    with: .color(speck.pale ? tones.pale : tones.deep)
                )
            }
        }
        .frame(width: size, height: size)
        .allowsHitTesting(false)
    }
}

/// The blades themselves: short runs of pixels standing on the tile.
///
/// **Drawn outside the board's skew.** Everything on the ground is sheared into
/// the row it belongs to; grass is not on the ground, it is standing up out of
/// it, and shearing it would lay it flat like everything else. It is placed the
/// way a piece is — scaled by its row, upright.
///
/// Each blade is one to three pixels tall, and the top pixel or two may lean a
/// pixel to either side, which is what stops a patch reading as a barcode.
struct GrassBlades: View {

    let shade: Palette.TileShade
    let point: GridPoint
    let size: CGFloat

    /// Art pixels per point, so a blade is drawn on the same grid as the tile.
    var pixel: CGFloat { size / CGFloat(GameRules.tilePixelSize) }

    /// How far through its sway the whole board is, in turns.
    ///
    /// **Handed in, and deliberately coarse.** Every patch used to own a
    /// `TimelineView`, which is forty-nine schedulers asking for forty-nine
    /// Canvas redraws every frame — and a Canvas full of blades is not cheap.
    /// One clock now drives all of them, quantised so the value only changes a
    /// few times a second: when it does not change, this view does not change,
    /// and SwiftUI skips the whole patch.
    let sway: Double

    /// Light tiles get the bright greens, dark ones the deep ones — the same
    /// division the dirt makes, for the same reason.
    /// The greens a blade runs through, darkest first.
    ///
    /// **Both shades of tile use all four.** Splitting them into a light set
    /// and a dark set made the two look like two different plants; what differs
    /// is the *proportion* — see `bias`.
    private static let ramp: [Color] = [
        Palette.darkGreen, Palette.green, Palette.jade, Palette.neonGreen,
    ]

    /// Which way this tile leans along the ramp.
    ///
    /// A dark tile sits a step lower — more `darkGreen`, still a little
    /// `neonGreen` — and a light tile a step higher, so each keeps a trace of
    /// the other's greens instead of owning a set of its own.
    private var bias: Double {
        switch shade {
        case .light: GameRules.grassLightBias
        case .dark: GameRules.grassDarkBias
        }
    }

    var body: some View {
        Canvas { context, _ in
            paint(sway: sway, in: &context)
        }
        .frame(width: size, height: size)
        .allowsHitTesting(false)
    }

    /// Draws this square's blades into `context`, in tile-local coordinates.
    ///
    /// Split out so a whole row can be painted into **one** canvas — see
    /// `GrassRow`. A patch per square is a view, a layer and a draw context per
    /// square, and at forty-nine of them that is the most expensive thing on
    /// the board by a distance.
    func paint(sway: Double, in context: inout GraphicsContext) {
        let blades = GameRules.grassClumpsPerTile * GameRules.grassBladesPerClump
        for blade in 0..<blades {
            draw(blade: blade, sway: sway, in: &context)
        }
    }

    private func draw(blade: Int, sway: Double, in context: inout GraphicsContext) {
        // Deterministic per square and per blade: the same tile grows the same
        // grass every time it is drawn, which keeps a patch from seething as
        // the board redraws.
        let seed = point.x * 977 + point.y * 613 + blade * 149
        let cell = GameRules.tilePixelSize

        // **Clumped, and rooted anywhere in the tile.**
        //
        // Every blade used to stand on the tile's bottom edge, which is a line
        // along the border — so a grassed square looked like a square someone
        // had drawn a fringe around. Grass grows *in* the ground, so a blade
        // takes a root anywhere on the tile, and the blades gather in twos and
        // threes around a few roots rather than being spread evenly. Even
        // spacing is the one arrangement nothing in nature has.
        let clump = blade / GameRules.grassBladesPerClump
        let clumpSeed = point.x * 3_119 + point.y * 1_777 + clump * 353

        let spread = GameRules.grassClumpSpread
        let height = 1 + hash(seed, 1) % GameRules.grassBladeTallest

        // **Kept inside its own tile.**
        //
        // A root near an edge threw blades past it, and a Canvas does not clip
        // — so grass grew off the back row into the sky and off the right
        // column into the water. The root is placed with room for the spread
        // and the blade's own height, which is cheaper than clipping and keeps
        // every pixel on the square that owns it.
        let inset = spread
        let span = max(cell - inset * 2, 1)
        let rootX = CGFloat(inset + hash(clumpSeed, 0) % span)

        let tall = height + spread
        let rows = max(cell - tall, 1)
        let rootY = CGFloat(tall + hash(clumpSeed, 1) % rows)

        let column = rootX + CGFloat(hash(seed, 0) % (spread * 2 + 1)) - CGFloat(spread)
        let base = min(rootY + CGFloat(hash(seed, 4) % (spread + 1)), CGFloat(cell - 1))
        let lean = CGFloat(hash(seed, 3) % 3) - 1

        // A blade bends more the further from its root, and the sway runs a
        // little later on each column so a patch ripples rather than pivoting.
        let phase = sway + Double(column) * GameRules.grassSwayStagger
        let bend = CGFloat(sin(phase * 2 * .pi)) * GameRules.grassSwayReach

        for step in 0..<height {
            let up = CGFloat(step)
            let tip = Double(up / CGFloat(max(height - 1, 1)))
            let drift = (step >= height - 2 ? lean : 0) + bend * tip

            // **Dark at the root, light at the tip.**
            //
            // The tone is a property of *how far up the blade a pixel is*, not
            // of the blade: grass is shaded by what the light reaches, so the
            // bottom pixel of every blade is the darkest green and the top is
            // the brightest, whatever tile it stands on. The tile's shade only
            // tilts where along that ramp the blade sits.
            let along = tip + bias + Double(hash(seed, 5) % 3 - 1) * 0.15
            let index = min(
                max(Int((along * Double(Self.ramp.count - 1)).rounded()), 0),
                Self.ramp.count - 1
            )

            context.fill(
                Path(
                    CGRect(
                        x: (column + drift) * pixel,
                        y: (base - up) * pixel,
                        width: pixel,
                        height: pixel
                    )
                ),
                with: .color(Self.ramp[index])
            )
        }
    }

    /// A small integer hash — the same shape `paletteMoss` uses, so the dirt
    /// and the blades scatter from the same kind of noise.
    private func hash(_ seed: Int, _ salt: Int) -> Int {
        // Unsigned, because the mixing constants do not fit in a signed word —
        // and because a hash wants wrapping arithmetic rather than a trap.
        var value = UInt64(bitPattern: Int64(seed &* 6_364_136_223_846_793))
        value = value &+ UInt64(bitPattern: Int64(salt &* 1_442_695_040_888_963))
        value ^= value >> 33
        value = value &* 0xFF51_AFD7_ED55_8CCD
        value ^= value >> 33
        return Int(value % 1_000_003)
    }
}


/// Every grassed square in one row, painted into a single canvas.
///
/// **One canvas, not one per square.** Each patch used to be its own view with
/// its own clock, its own layer and its own drawing context; the board carried
/// forty-nine of them and spent most of a frame on grass. A row is the natural
/// batch because the row is what the board sorts by — the blades still draw
/// between the ground behind them and the piece in front of them, because the
/// row's object says so.
///
/// The canvas covers the whole board and places each square by the projection,
/// so nothing here needs a placement modifier of its own.
struct GrassRow: View {

    let row: Int
    let squares: [GridPoint]
    let metrics: PixelArtMetrics
    let sway: Double

    var body: some View {
        Canvas { context, _ in
            for point in squares {
                let placed = metrics.projected(point)
                let side = metrics.tileSize * placed.scale

                var square = context
                square.translateBy(
                    x: placed.position.x - side / 2,
                    y: placed.position.y - side / 2
                )
                square.scaleBy(x: placed.scale, y: placed.scale)

                GrassBlades(
                    shade: .at(point),
                    point: point,
                    size: metrics.tileSize,
                    sway: sway
                )
                .paint(sway: sway, in: &square)
            }
        }
        .frame(width: metrics.boardSize, height: metrics.boardSize)
        .allowsHitTesting(false)
    }
}
