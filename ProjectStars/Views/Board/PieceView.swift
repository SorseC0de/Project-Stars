//
//  PieceView.swift
//  Project Stars
//
//  The player's zodiac piece.
//

import SwiftUI

/// Draws the controlled piece.
///
/// A piece sprite is **16x32 — twice a tile's height**. Its box rests with the
/// bottom edge on the bottom of the tile, so the figure rises out of its square
/// rather than sitting inside it, and the art can overlap whatever is behind.
/// `GameRules.pieceLift` nudges that resting point without touching this file.
///
/// - Note: Every sign currently points at the same sprite. That is one line in
///   `SpriteAtlas`, not a limitation here.
struct PieceView: View {

    let zodiac: Zodiac

    /// Size of a board cell, in points.
    let tileSize: CGFloat


    /// Whole-pixel scale, for art-pixel offsets.
    let scale: CGFloat

    /// Which plane the piece is standing on.
    ///
    /// Decides its material: gold in the sky, mossy stone once it has fallen.
    var plane: Plane = .astra

    /// True when the Zodiaction is charged or firing, which lights the gem.
    var isCharged: Bool = false

    /// Which way the piece is looking.
    var facing: SwipeDirection = .up

    /// True while the piece is dropping between planes.
    var isFalling: Bool = false

    /// Extra vertical offset in points — how the piece rides the Nexys' drift
    /// while standing on it.
    var carryOffset: CGFloat = 0

    /// How the piece is deformed and lifted right now. `.rest` when still.
    var pose: HopPose = .rest

    /// Running total of fall rotation, in degrees. Only ever decreases, so the
    /// spin reads as one continuous counter-clockwise turn.
    var spin: Double = 0

    /// Vertical offset applied to the **sprite only**, for falling in from
    /// off-screen. The shadow deliberately does not move with it.
    var dropOffset: CGFloat = 0

    /// Size of the shadow relative to its resting size. Swells from small to
    /// full as a falling piece nears the ground.
    var shadowScale: CGFloat = 1

    /// How hard the piece is currently flashing its element's colour, `0`…`1`.
    /// Driven by charge gain — see `GameSession.chargeFlashStartedAt`.
    var chargeFlash: Double = 0

    /// The element the Astral Bolt's star is currently wearing, or `nil` when
    /// the star is not running.
    ///
    /// Cycling through all four rather than settling on one: nothing is attuned
    /// to lightning, so the star belongs to every element and none.
    var starElement: ZodiacElement?

    var body: some View {
        ZStack {
            // The shadow stays on the tile while the figure rises off it, which
            // is what anchors a two-cell-tall sprite to a one-cell square — and
            // during an arrival it is the *only* thing on the destination
            // square, growing to announce where the piece is about to land.
            PieceShadowView(tileSize: tileSize)
                // Two effects multiply: the arrival's swell, and the hop's own
                // narrowing as the piece leaves the ground.
                .scaleEffect(shadowScale * hopShadowScale)
                .offset(y: GameRules.pieceShadowDrop * scale)
                .opacity(isFalling ? 0 : 1)

            figure
            .frame(width: tileSize, height: tileSize * 2)
            // Box bottom on the tile bottom: shift up by half a box height minus
            // half a tile.
            .offset(y: -tileSize / 2 - GameRules.pieceLift * scale)
            // Anchored at the feet, so squashing spreads the piece outward
            // along the ground instead of sinking it through the tile.
            .scaleEffect(x: pose.scaleX, y: pose.scaleY, anchor: .bottom)
            .offset(y: -pose.lift * scale)
            // Spin and drop apply to the sprite alone, so the shadow stays put
            // on the square being fallen onto.
            .rotationEffect(.degrees(spin))
            .offset(y: dropOffset)
        }
        .offset(y: carryOffset)
        // The drop: shrink and fade leaving one plane, reverse arriving at the
        // other.
        .scaleEffect(isFalling ? 0.25 : 1)
        .opacity(isFalling ? 0 : 1)
        .allowsHitTesting(false)
    }

    // MARK: - Material

    /// The sprite, in whichever material this plane calls for, with its gem lit
    /// if the piece is charged.
    ///
    /// All of it is generated from the one gold sheet. Only Pisces was ever
    /// drawn in stone; every other sign gets its stone form from here, which is
    /// eleven sprites nobody has to draw twice.
    private var figure: some View {
        lit.colorFlash(ElementFX.ramp(for: zodiac.element).mid, amount: chargeFlash)
    }

    /// The sprite with its gem lit, before any flash is laid over it.
    @ViewBuilder
    private var lit: some View {
        if isCharged {
            // The gold blooms, and the eyes with it. Both entries, not just the
            // gem: a charged piece should look lit from inside rather than
            // wearing two bright pixels.
            PaletteGlow(
                radius: GameRules.gemGlowRadius * scale,
                trail: GameRules.gemGlowTrail
            ) {
                // The eyes keep the old rule — the sign's element, on both
                // planes — while the body stays gold.
                material.paletteSwap([PaletteSwap(gem.dim, gem.lit)])
            }
        } else {
            material
        }
    }

    /// Gold in the sky, mossy stone on the ground.
    @ViewBuilder
    private var material: some View {
        // Colour burns the stone off: gold on both planes for as long as it
        // lasts, which is most of how you can tell at a glance that something is
        // up — and the gold is then swapped for whichever element is being worn.
        switch isGilded ? .astra : plane {
        case .astra:
            recoloured(sprite)

        case .terra:
            sprite
                .paletteSwap(stoneSwaps)
                .paletteMoss(
                    colors: Palette.mossTones,
                    // The gem survives the overgrowth: it is the one pixel that
                    // has to stay readable.
                    keeping: [gem.dim, gem.lit],
                    viewSize: CGSize(width: tileSize, height: tileSize * 2),
                    artSize: CGSize(
                        width: GameRules.tilePixelSize,
                        height: GameRules.tilePixelSize * 2
                    ),
                    // Seeded per sign, so no two are overgrown alike.
                    seed: Float(abs(zodiac.rawValue.hashValue % 10_000)),
                    coverage: GameRules.pieceMossCoverage
                )
        }
    }

    /// The sprite redrawn in whichever element it is currently wearing.
    ///
    /// Two states put a piece in colour, and they never overlap in practice:
    ///
    /// - **The star**, cycling all four — see `starElement`.
    /// - **A full meter**, in the sign's own element. This is the readable
    ///   version of what the lit gems were meant to say and never did: three or
    ///   four pixels of eye cannot carry a state this important, and the whole
    ///   figure changing colour can.
    ///
    /// Three entries swapped, not four: `midnight` is the outline, and an
    /// outline that changes colour stops reading as an outline.
    @ViewBuilder
    private func recoloured(_ art: some View) -> some View {
        if let element = wornElement {
            art.paletteSwap(
                zip(Palette.pieceGoldTones, Palette.pieceTones(for: element))
                    .map(PaletteSwap.init)
            )
        } else {
            art
        }
    }

    /// The element the piece's *body* is dressed in, if any.
    ///
    /// Only the star. A charged piece stays gold — its element is carried by the
    /// lit eyes and by the trail streaming off it, which is a louder signal than
    /// recolouring the figure and leaves the star's recolour meaning one thing
    /// and one thing only.
    private var wornElement: ZodiacElement? { starElement }

    /// Whether the figure is drawn in gold rather than its plane's material.
    ///
    /// Both a full meter and the star burn the stone off, on both planes.
    private var isGilded: Bool { isCharged || starElement != nil }

    @ViewBuilder
    private var sprite: some View {
        if zodiac == .libra {
            // Assembled rather than drawn — see `LibraPieceView`. It goes here
            // so everything wrapped around a piece sprite still applies: the
            // gold swap, the charge glow, the hop's squash, the fall's spin.
            LibraPieceView(
                facing: facing,
                tileSize: tileSize,
                scale: scale,
                isCharged: isGilded
            )
            // Flattened before anything downstream shades it.
            //
            // The moss and the stone swap are `colorEffect`s, and a shader over
            // a stack is applied to each layer in its own coordinate space — so
            // the arms and pans were being mossed as though each sat at the
            // origin, ignoring every offset that puts them where they belong.
            // One layer in, one shader over it, and the overgrowth lands on the
            // figure as drawn.
            .drawingGroup()
        } else {
            PixelSprite(id: .piece(zodiac)) {
                placeholder
            }
        }
    }

    private var gem: GemTones { .forElement(zodiac.element) }

    private var stoneSwaps: [PaletteSwap] {
        zip(Palette.pieceGoldTones, Palette.pieceStoneTones).map(PaletteSwap.init)
    }

    /// How much the shadow shrinks at this point in the hop.
    ///
    /// Read from the pose's own lift rather than from the clock, so it stays in
    /// step with the piece even if the hop curve is reshaped.
    private var hopShadowScale: CGFloat {
        guard GameRules.hopArcHeight > 0 else { return 1 }
        let height = min(pose.lift / GameRules.hopArcHeight, 1)
        return 1 - GameRules.pieceShadowLiftSwing * height
    }

    // MARK: - Placeholder

    private var placeholder: some View {
        let definition = zodiac.definition
        return ZStack {
            RoundedRectangle(cornerRadius: tileSize * 0.22)
                .fill(definition.accentColor)
            RoundedRectangle(cornerRadius: tileSize * 0.22)
                .strokeBorder(.white.opacity(0.65), lineWidth: max(1, tileSize * 0.05))
            Text(definition.glyph.monochromeGlyph)
                .font(.system(size: tileSize * 0.60, weight: .bold))
                .foregroundStyle(.white)
        }
        .padding(tileSize * 0.10)
        .frame(width: tileSize, height: tileSize)
        .frame(maxHeight: .infinity, alignment: .bottom)
    }
}
