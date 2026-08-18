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

    /// How far the shadow is lifted against the perspective's seating drop, in
    /// art pixels. Handed in so it can be tuned live.
    var shadowLift: CGFloat = GameRules.pieceShadowPerspectiveLift

    /// Which of Gemini's twins this is, or `nil` for a whole piece.
    ///
    /// Handed in rather than inferred from being split: which twin is holding
    /// the turn changes every turn, and either of them can be the one that fell.
    var twin: GeminiHalf?

    /// Whether the pool of shadow under the figure is drawn.
    ///
    /// Off for afterimages: a ghost is a picture of the figure, and a trail of
    /// shadows would be a trail of things claiming to be standing there.
    var showsShadow = true

    /// Which drawing this piece is right now.
    private var spriteID: SpriteID {
        if zodiac.hasOwnHalves, let twin { return .geminiHalf(twin) }
        // Cancer is drawn from every side. Everyone else is one statue seen
        // from the front, however it is facing.
        if zodiac == .cancer { return .cancerFacing(facing) }
        return .piece(zodiac)
    }

    /// True when this drawing is the mirror of one on the sheet.
    ///
    /// Cancer's east is its west flipped — three drawings covering four sides.
    private var isMirrored: Bool { zodiac == .cancer && facing == .right }

    /// The movement playing out, if any. See `GameSession.Movement`.
    var movement: GameSession.Movement?

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

    /// The ambient clock, which stops while the game waits on the player.
    var clock: (TimeInterval) -> TimeInterval = { $0 }

    /// How much storm Aquarius is wearing, `0`…`10`.
    ///
    /// Zero is the bare statue, which is what every other sign always is.
    var stormPhase: Int = 0

    /// The cached frames of that storm, if there are any yet.
    var stormFilm: AquariusStormFilm?

    var body: some View {
        ZStack {
            // The shadow stays on the tile while the figure rises off it, which
            // is what anchors a two-cell-tall sprite to a one-cell square — and
            // during an arrival it is the *only* thing on the destination
            // square, growing to announce where the piece is about to land.
            if showsShadow {
                PieceShadowView(tileSize: tileSize)
                // Two effects multiply: the arrival's swell, and the hop's own
                // narrowing as the piece leaves the ground.
                .scaleEffect(shadowScale * hopShadowScale)
                // Lifted back by what the perspective's seating pushed down.
                //
                // `upright` drops the whole piece to seat it on its square, and
                // the shadow is inside the piece, so it went down too — but the
                // shadow was already on the ground and had nothing to correct.
                // It is the figure that needed moving, not the mark under it.
                .offset(y: (GameRules.pieceShadowDrop - shadowLift) * scale)
                .opacity(isFalling ? 0 : 1)
            }

            figure
            .frame(width: tileSize, height: tileSize * 2)
            // Box bottom on the tile bottom: shift up by half a box height minus
            // half a tile.
            .offset(y: -tileSize / 2 - GameRules.pieceLift * scale)
            // Anchored at the feet, so squashing spreads the piece outward
            // along the ground instead of sinking it through the tile.
            //
            // Skipped for a piece that squashes its own body — see
            // `posesItself`. Squashing the whole assembly here and having the
            // hanging parts each invert it back is not the same as not squashing
            // them: the outer scale is animated by whoever set the pose and the
            // inner one is re-read every frame by a `TimelineView`, so the two
            // run on different curves and the "cancelled" transform pumps.
            .scaleEffect(
                x: posesItself ? 1 : pose.scaleX,
                y: posesItself ? 1 : pose.scaleY,
                anchor: .bottom
            )
            .offset(y: -pose.lift * scale)
            // Spin and drop apply to the sprite alone, so the shadow stays put
            // on the square being fallen onto.
            .rotationEffect(.degrees(spin))
            .offset(y: dropOffset)
        }
        .offset(y: carryOffset)
        // The drop: **down and out**, not smaller.
        //
        // The shrink was doing depth's job on a board that had none — back when
        // Terra was drawn flat, getting smaller was the only way to say
        // "further away". The rows say it now, and a piece that shrinks *and*
        // travels through a perspective is being sent away twice.
        //
        // So it falls: driven down past the bottom of its square and faded, and
        // the plane below catches it. Distance is the board's job.
        .offset(y: isFalling ? GameRules.fallDrop * scale : 0)
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
    @ViewBuilder
    private var figure: some View {
        // Aquarius is not a statue with an effect on it — above zero he *is*
        // the storm, and the statue is what is left when it goes. So the whole
        // material path is skipped rather than layered under: no stone, no
        // gold, no gem, because none of those are visible through a funnel.
        if zodiac == .aquarius, stormPhase > 0 {
            AquariusStormPiece(phase: stormPhase, film: stormFilm, tileSize: tileSize)
        } else {
            lit.colorFlash(ElementFX.ramp(for: zodiac.element).mid, amount: chargeFlash)
        }
    }

    /// A soft coloured shape behind the piece.
    ///
    /// Built from the sprite's own silhouette rather than from a shader mask, so
    /// it is exactly his shape however he is posed — and drawn in the plain,
    /// with no blend mode, because an aura is not light interacting with the
    /// board. It is a soft thing behind a hard thing.
    ///
    /// Two copies at different spreads: one tight enough to read as an edge and
    /// one wide enough to reach past him. A single blur is either a halo or a
    /// wash and cannot be both.
    private var aura: some View {
        ZStack {
            ForEach(0..<2, id: \.self) { step in
                material
                    .colorEffect(
                        ShaderLibrary.flatSilhouette(.color(GameRules.stormGlowTint))
                    )
                    .blur(radius: GameRules.auraRadius * scale * CGFloat(step + 1))
                    .opacity(GameRules.auraOpacity / Double(step + 1))
            }
        }
        .allowsHitTesting(false)
    }

    /// The ordinary charged look: gold, with the gem lit and blooming.
    ///
    /// Named so the doubled version below can reuse it rather than restate it —
    /// two copies of this drifted apart the moment Leo's threshold went in.
    private func charged(intensity: Double = 1) -> some View {
            // The gold blooms, and the eyes with it. Both entries, not just the
            // gem: a charged piece should look lit from inside rather than
            // wearing two bright pixels.
            PaletteGlow(
                // **Leo's red has to be let through.**
                //
                // The bloom keys on luminance, and the default threshold was
                // chosen for gold and for two-pixel gems — red sits under it,
                // so the largest lit thing in the game was the one thing not
                // glowing. Dropping the threshold for him lights the mane
                // itself rather than adding anything to it, which is the
                // difference between fire and pixels scattered on fur.
                threshold: zodiac == .leo
                    ? GameRules.maneGlowThreshold
                    : GameRules.glowLuminanceThreshold,
                radius: GameRules.gemGlowRadius * scale,
                // And harder, because a gem blooms from two pixels and a mane
                // from a hundred: the same intensity reads as a glow on one and
                // nothing on the other.
                intensity: zodiac == .leo ? GameRules.maneGlowIntensity : intensity,
                trail: GameRules.gemGlowTrail
            ) {
                // The eyes keep the old rule — the sign's element, on both
                // planes — while the body stays gold.
                //
                // The eyes keep the old rule — the sign's element, on both
                // planes — while the body stays gold.
                material.paletteSwap([PaletteSwap(gem.dim, gem.lit)])
            }
    }

    /// The sprite with its gem lit, before any flash is laid over it.
    @ViewBuilder
    private var lit: some View {
        if isCharged, zodiac.zodiaction.firesAtEmpty {
            // **Behind him, not over him.**
            //
            // `PaletteGlow` hangs its halo in an `.overlay`, so nesting one
            // inside another makes the outer mask read the *inner glow* rather
            // than the sprite — which is why three attempts at this changed only
            // the body and left the outside bare.
            //
            // An aura is a shape behind the figure: his own silhouette,
            // flattened to one colour, blurred, and sat underneath. Nothing to
            // blend against and nothing to be swallowed by.
            // **Gold and purple at once.**
            //
            // A backwards meter is at full power at both ends of itself: ten is
            // everything he is holding and zero is everything he is about to
            // spend. The gold says *ready*, like every other sign, and the
            // purple says the power is still his — which is the one thing an
            // empty bar would otherwise be denying.
            PaletteGlow(
                radius: GameRules.gemGlowRadius * scale,
                intensity: GameRules.stormGlowIntensity,
                trail: GameRules.gemGlowTrail,
                tint: GameRules.stormGlowTint,
                // **Not additive.**
                //
                // `plusLighter` climbs past white and clips, so over anything
                // bright the purple stops being purple and becomes glare — the
                // same thing that made the water droplets read as white rings.
                // The storm's own bloom already uses this mode for the phases
                // where the colour has to survive.
                // Laid on plainly.
                //
                // Every clever mode has now failed this halo in its own way:
                // additive clipped it to white, `plusDarker` swallowed it, and
                // `hardLight` cancelled it against a mid-tone board. The halo
                // already carries its own falloff in alpha, so drawing it as
                // itself is what makes a coloured aura — the softness is the
                // blur, not the blend.
                tintBlend: .normal
            ) {
                charged(intensity: GameRules.aquariusBodyGlowShare)
            }
            .background { aura }
        } else if isCharged {
            charged()
        } else if let resting = gem.resting {
            // Shown as its resting colour, which is not the entry it is drawn
            // with — see `GemTones.resting`.
            material.paletteSwap([PaletteSwap(gem.dim, resting)])
        } else {
            material
        }
    }

    /// Gold in the sky, mossy stone on the ground.
    @ViewBuilder
    private var material: some View {
        // Libra shades her own five parts and must not be shaded again here.
        //
        // Doing both is what kept the moss off her arms: the per-part pass put
        // it where it belonged and this one then laid a second, whole-figure
        // coat over the top in the composite's coordinate space — which is the
        // misaligned one, and the one on screen.
        if zodiac == .libra {
            sprite
        } else {
            // Colour burns the stone off: gold on both planes for as long as it
            // lasts, which is most of how you can tell at a glance that
            // something is up — and the gold is then swapped for whichever
            // element is being worn.
            switch isGilded ? .astra : plane {
            case .astra:
                recoloured(sprite)

            case .terra:
                stoned(sprite, cells: 2)
            }
        }
    }

    /// Stone and overgrowth, over one sprite.
    ///
    /// Takes the sprite's own height in cells because the moss shader maps
    /// screen position onto art pixels: hand it the wrong size and the
    /// overgrowth is scattered on a grid that does not line up with the drawing.
    /// A piece is two cells tall and Libra's arms and pans are one each, which
    /// is why this is a parameter rather than a constant.
    func stoned(_ art: some View, cells: CGFloat) -> some View {
        art
            .paletteSwap(stoneSwaps)
            .paletteMoss(
                colors: Palette.mossTones,
                // The gem survives the overgrowth: it is the one pixel that
                // has to stay readable.
                keeping: [gem.dim, gem.lit],
                viewSize: CGSize(width: tileSize, height: tileSize * cells),
                artSize: CGSize(
                    width: CGFloat(GameRules.tilePixelSize),
                    height: CGFloat(GameRules.tilePixelSize) * cells
                ),
                // Seeded per sign, so no two are overgrown alike.
                seed: Float(abs(zodiac.rawValue.hashValue % 10_000)),
                coverage: GameRules.pieceMossCoverage
            )
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

    /// True when the figure squashes itself rather than being squashed whole.
    ///
    /// Libra is five sprites, only one of which is a body. A pan on a string is
    /// rigid — it swings, it does not flatten — so the pose has to be applied to
    /// the part that pushes off the ground and to nothing else.
    private var posesItself: Bool { zodiac == .libra }

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
                isCharged: isGilded,
                pose: pose,
                movement: movement,
                // Whatever this piece is made of right now, applied one part at
                // a time. Gold in the sky, mossy stone on the ground — the same
                // choice `material` makes for everyone else, handed down instead
                // of applied over the top.
                stone: (isGilded ? .astra : plane) == .terra
                    ? { AnyView(stoned($0, cells: $1)) }
                    : { part, _ in AnyView(recoloured(part)) }
            )
            // Deliberately *not* flattened.
            //
            // `drawingGroup()` rasterises into the view's layout bounds, and
            // Libra's arms and pans are drawn outside hers on purpose — so
            // flattening cut them off at the body's edge. It was an attempt to
            // give the moss shader one layer to work on; the fix for that has to
            // be one that does not clip, since the whole assembly is defined by
            // reaching past its own frame.
        } else {
            // Gemini has three drawings: the pair, and each of them alone.
            //
            // Split, the piece is only one of the two — drawing the pair would
            // put both twins on the square while the other one is standing
            // somewhere else on the board.
            // At a full meter Pisces' stone fish is replaced by an energy one,
            // so the two halves are drawn separately. Every other case — and
            // Pisces at any other meter — is the one composite.
            Group {
                if zodiac == .pisces {
                    // One cell, in the lower half of the two-cell box every
                    // piece is drawn in — otherwise it stretches to fill it.
                    PixelSprite(id: spriteID) { placeholder }
                        .frame(width: tileSize, height: tileSize)
                        .frame(width: tileSize, height: tileSize * 2, alignment: .bottom)
                } else {
                    PixelSprite(id: spriteID) {
                        placeholder
                    }
                }
            }
            // East is west, mirrored — see `isMirrored`.
            .scaleEffect(x: isMirrored ? -1 : 1, y: 1)
            .overlay(alignment: .top) { virgoGems }
            .overlay(alignment: .top) { sagittariusArrow }
            .overlay(alignment: .top) { leoEmbers }
            .overlay(alignment: .top) { piscesFish }
        }
    }

    /// Virgo's three floating gems.
    ///
    /// Drawn on the sheet a cell above and a cell below her and aligned to her
    /// **upper tile**, so they need no offset of their own — laying them over
    /// the top half of the figure box puts them exactly where they were drawn.
    ///
    /// The outer one is a single drawing used twice, the second mirrored. The
    /// middle draws in front of both.
    ///
    /// - TODO: Static for now. They are meant to move; this is the resting
    ///   arrangement to check the placement against first.
    /// Pisces' fish, once it is made of energy.
    ///
    /// Only at a full meter, and only then: the stone fish is part of the
    /// composite and needs nothing drawn over it. Guarding on `isCharged` alone
    /// is what keeps this off every other event that lights a piece.
    ///
    /// **A tight circle, anticlockwise, resting at the bottom of it.** The
    /// drawn position is the bottom of the path for the same reason Virgo's
    /// gems and the archer's arrow rest at theirs — the arrangement checked
    /// against the sheet stays a real position in the motion rather than the
    /// average of two wrong ones. The spin is slower than the orbit, so the two
    /// never resolve into one motion.
    ///
    /// - TODO: `piscesFishDrop` is a first guess. The art rests between two
    ///   cells, so the seam is not where the cell boundary is.
    @ViewBuilder
    private var piscesFish: some View {
        if zodiac == .pisces {
            TimelineView(.animation) { timeline in
                let now = clock(timeline.date.timeIntervalSinceReferenceDate)

                if isCharged {
                    // A trail, drawn from where it **was**.
                    //
                    // The board's own afterimages are left by moving between
                    // squares, and this fish never leaves its square — it turns
                    // and circles in place, which is motion the trail system
                    // cannot see. So each ghost is the same sprite wound back a
                    // few moments along its own two clocks: not a copy placed
                    // behind it, but where it genuinely was.
                    fish(at: now, step: 0)
                } else {
                    // Still, and stone. The fish is part of him until the meter
                    // fills; only then does it come loose.
                    PixelSprite(id: .piscesFish) { Color.clear }
                        .offset(y: GameRules.piscesFishDrop * scale)
                }
            }
            .frame(width: tileSize, height: tileSize)
            .allowsHitTesting(false)
        }
    }

    /// The archer's arrow, hanging over him.
    ///
    /// **Drawn position is the bottom of its travel**, so it rises and settles
    /// back rather than sinking below where the art puts it. Same reasoning as
    /// Virgo's gems: the arrangement that was checked against the sheet stays a
    /// real position in the motion instead of becoming the average of two wrong
    /// ones.
    ///
    /// Slow, and slower than her gems. It is a nocked shot waiting to be taken,
    /// not something orbiting him — anything quick would read as agitation.
    @ViewBuilder
    private var sagittariusArrow: some View {
        if zodiac == .sagittarius {
            TimelineView(.animation) { timeline in
                let now = clock(timeline.date.timeIntervalSinceReferenceDate)
                // Still while he is stone. The float is the shot being *ready*,
                // and an arrow drifting over a dark statue promises something
                // the sign cannot do yet.
                let rise = isCharged
                    ? (1 - cos(now / GameRules.sagittariusArrowPeriod * 2 * .pi)) / 2
                    : 0

                PixelSprite(id: .sagittariusArrowRest) { Color.clear }
                    // A smaller copy of itself, flattened to yellow, sitting
                    // inside the drawn one.
                    //
                    // Drawn **here** rather than over the finished piece, so it
                    // is inside everything that comes after — the gold swap, the
                    // charge flash, and the bloom above all. A core added after
                    // the glow would sit on top of the light instead of being
                    // the thing casting it.
                    // A smaller copy of itself, lit and flickering inside
                    // the drawn shaft.
                    //
                    // Drawn **here** rather than over the finished piece, so it
                    // sits under the gold swap, the charge flash and the bloom.
                    // A core added after the glow would be on top of the light
                    // rather than the thing casting it.
                    .overlay {
                        if isCharged {
                            PixelSprite(id: .sagittariusArrowRest) { Color.clear }
                                .scaleEffect(GameRules.sagittariusArrowCoreScale)
                                .modifier(Flickering(now: now, scale: scale))
                                .offset(y: GameRules.sagittariusArrowCoreDrop * scale)
                        }
                    }
                    .offset(y: -rise * GameRules.sagittariusArrowFloat * scale)
            }
            .frame(width: tileSize, height: tileSize)
            .allowsHitTesting(false)
        }
    }

    /// The lion's mane, alight.
    ///
    /// Only while charged, and only Leo. Same object as the archer's core —
    /// see `Flickering` — which is what makes the two read as the same fire
    /// rather than two effects that happen to be yellow.
    @ViewBuilder
    private var leoEmbers: some View {
        if zodiac == .leo, isCharged {
            TimelineView(.animation) { timeline in
                maneEmbers(at: clock(timeline.date.timeIntervalSinceReferenceDate))
            }
            .frame(width: tileSize, height: tileSize * 2)
            .allowsHitTesting(false)
        }
    }

    /// The flicker itself, as a modifier.
    ///
    /// Everything that makes the archer's core read as fire — the stepped
    /// wander, the breath, the softening, the additive light — with nothing in
    /// it about arrows. So the same object can be scattered through Leo's mane,
    /// which is the other place in the game that wants heat inside a solid
    /// shape rather than light around one.
    ///
    /// - Parameter seed: Which flame this is. Two embers on one seed move
    ///   together and read as one thing in two places.
    private struct Flickering: ViewModifier {

        let now: TimeInterval
        let scale: CGFloat
        var seed: Int = 0

        /// The brightest this flame ever gets.
        ///
        /// The archer has one core inside a dark shaft and can afford to be
        /// subtle; the lion's are small and scattered over gold, where the same
        /// value disappears into what is under them.
        var ceiling: Double = GameRules.sagittariusArrowCoreOpacity

        func body(content: Content) -> some View {
            let tick = (now / GameRules.sagittariusArrowCoreTick).rounded(.down)
            let shake = GameRules.jitter(tick, salt: seed * 3 + 1)
            let sway = GameRules.jitter(tick, salt: seed * 3 + 2)
            let pulse = (sin(
                (now + Double(seed) * GameRules.emberStagger)
                    / GameRules.sagittariusArrowCorePulse * 2 * .pi
            ) + 1) / 2

            return content
                .colorEffect(ShaderLibrary.flatSilhouette(.color(Palette.yellow)))
                .blur(radius: GameRules.sagittariusArrowCoreBlur * scale)
                // The tuned opacity is the **top** of the swing rather than its
                // middle: it was settled by eye as the brightest this should
                // ever be, so pulsing about it would spend half the loop
                // brighter than what was chosen.
                .opacity(
                    ceiling * (1 - GameRules.sagittariusArrowCoreDip * pulse)
                )
                .blendMode(.plusLighter)
                .offset(
                    x: shake * GameRules.sagittariusArrowCoreJitter * scale,
                    y: sway * GameRules.sagittariusArrowCoreJitter * scale
                )
        }
    }

    /// Embers through the lion's mane.
    ///
    /// The archer's core, scattered — same flicker, smaller, and several of
    /// them on their own seeds so they wander and breathe independently. Each
    /// is a copy of his **own silhouette**, which is what keeps them inside the
    /// figure: a circle would sit over the mane, and this is lit *by* it.
    ///
    /// Sizes and places are hashed rather than chosen, so adding one is
    /// changing a count.
    @ViewBuilder
    private func maneEmbers(at now: TimeInterval) -> some View {
        ForEach(0..<GameRules.maneEmberCount, id: \.self) { ember in
            // **The arrowhead**, which is already the right shape.
            //
            // Flattened it is a diamond, and a diamond is what an ember looks
            // like. Reaching for Leo's own silhouette gave four yellow lions,
            // and a circle would have been a fifth thing to keep in step with
            // the other two — this is the same drawing the archer's core is cut
            // from, which is what makes them one effect.
            let size = GameRules.maneEmberScale
                * (GameRules.emberSmallest
                    + (1 - GameRules.emberSmallest)
                        * (GameRules.jitter(Double(ember), salt: 7) + 1) / 2)

            PixelSprite(id: .sagittariusArrowRest) { Color.clear }
                .scaleEffect(size)
                .modifier(
                    Flickering(
                        now: now,
                        scale: scale,
                        seed: ember + 1,
                        ceiling: GameRules.maneEmberOpacity
                    )
                )
                // **A V, opening upward.**
                //
                // How deep this ember sits decides how far out it may sit: at
                // the top of the mane the hair is at its widest, and it narrows
                // toward the face. One spread for both axes gave a column —
                // tightening the band vertically pulled it in horizontally too,
                // which is the mohawk.
                .offset(
                    x: GameRules.jitter(Double(ember), salt: 11)
                        * (GameRules.maneEmberWide
                            + (GameRules.maneEmberNarrow - GameRules.maneEmberWide)
                                * abs(GameRules.jitter(Double(ember), salt: 13)))
                        * scale,
                    // Up into the mane, and never below it.
                    //
                    // The scatter is clamped rather than centred: an ember is
                    // allowed to drift further into the hair but not down out
                    // of it, because the first thing under the mane is his
                    // face. A symmetric spread put one there about a quarter of
                    // the time.
                    // Measured from the **top** of the mane downward, so the
                    // clamp is a ceiling rather than a floor.
                    //
                    // Written as a rise with a one-sided scatter, the highest
                    // ember was the anchor and every other one hung below it —
                    // which meant raising them off his face lifted the whole
                    // band off his head. Anchoring at the top instead lets them
                    // fill the hair downward from a fixed line.
                    y: GameRules.maneEmberTop * scale
                        + abs(GameRules.jitter(Double(ember), salt: 13))
                            * GameRules.maneEmberDepth * scale
                )
        }
    }

    /// The energy fish, wound back `step` moments along its own two clocks.
    ///
    /// Its position is a function of time, so a ghost is simply the same view
    /// asked about the past — the trail curves with the orbit and turns with the
    /// spin rather than trailing in a straight line behind it.
    private func fish(at now: TimeInterval, step: Int) -> some View {
        let past = now - Double(step) * GameRules.piscesFishTrailGap
        let orbit = past / GameRules.piscesFishOrbitPeriod * 2 * .pi
        let spin = past / GameRules.piscesFishSpinPeriod * 360

        return PixelSprite(id: .piscesFishCharged) { Color.clear }
            .rotationEffect(.degrees(-spin))
            .offset(
                x: sin(orbit) * GameRules.piscesFishOrbit * scale,
                y: (cos(orbit) - 1) / 2 * GameRules.piscesFishOrbit * scale
                    + GameRules.piscesFishDrop * scale
            )
    }

    @ViewBuilder
    private var virgoGems: some View {
        if zodiac == .virgo {
            TimelineView(.animation) { timeline in
                let now = clock(timeline.date.timeIntervalSinceReferenceDate)
                let swing = now / GameRules.virgoGemPeriod * 2 * .pi
                let bob = now / GameRules.virgoGemFloatPeriod * 2 * .pi

                // `1 - cos` rather than `sin`: it is zero at the start of the
                // circuit and never negative, so the drawn position is the top
                // of the path and every other moment is below it.
                let dip = (1 - cos(swing)) / 2
                let across = sin(swing)

                ZStack {
                    // The left gem runs anticlockwise, the right one clockwise,
                    // so the pair opens and closes together rather than sliding
                    // across her in step.
                    outerGem(across: -across, dip: dip)
                    outerGem(across: across, dip: dip, mirrored: true)

                    // Falling and swelling together, so it reads as coming
                    // toward the viewer rather than sliding down.
                    let drop = (1 - cos(bob)) / 2
                    PixelSprite(id: .virgoGem(.middle)) { Color.clear }
                        .scaleEffect(1 + drop * GameRules.virgoGemFloatGrowth)
                        .offset(y: drop * GameRules.virgoGemFloat * scale)
                }
            }
            .frame(width: tileSize, height: tileSize)
            .allowsHitTesting(false)
        }
    }

    /// One of the pair, at a point on its oval.
    ///
    /// Grows as it falls, like the middle one — the near half of the oval is
    /// the half closest to the viewer, so the swell is what makes the path read
    /// as a ring rather than as a slide left and right.
    private func outerGem(across: Double, dip: Double, mirrored: Bool = false) -> some View {
        PixelSprite(id: .virgoGem(.outer)) { Color.clear }
            .scaleEffect(x: mirrored ? -1 : 1, y: 1)
            .scaleEffect(1 + dip * GameRules.virgoGemFloatGrowth)
            .offset(
                x: across * GameRules.virgoGemSwingX * scale,
                y: dip * GameRules.virgoGemSwingY * scale
            )
    }

    private var gem: GemTones { .forElement(zodiac.element) }

    private var stoneSwaps: [PaletteSwap] {
        // Gemini's silver half is already most of the way to stone, so the gold
        // ramp alone leaves it untouched on Terra — one twin turns to rock and
        // the other stays bright, which reads as the recolour failing rather
        // than as two materials.
        //
        // It gets its own ramp down: the silvers step to the same stone tones,
        // one rung darker than the golds land on, so the pair still tell each
        // other apart down there without either of them staying metallic.
        let silver = zip(Palette.pieceSilverTones, Palette.pieceSilverStoneTones)
            .map(PaletteSwap.init)

        return zip(Palette.pieceGoldTones, Palette.pieceStoneTones).map(PaletteSwap.init)
            + (zodiac == .gemini ? silver : [])
    }

    /// How much the shadow shrinks at this point in the hop.
    ///
    /// Read from the pose's own lift rather than from the clock, so it stays in
    /// step with the piece even if the hop curve is reshaped.
    ///
    /// ## Why it is not clamped to one arc's worth
    ///
    /// It was, and that quietly ate every long jump. A two-square vault lifts
    /// well past `hopArcHeight`, and dividing by that and clamping meant the
    /// shadow bottomed out at exactly the height an ordinary step reaches —
    /// so the piece went higher and the ground said nothing about it. The
    /// shadow is most of how height reads at all; a bigger arc under a shadow
    /// that stops reacting is a bigger arc nobody sees.
    ///
    /// Left unclamped instead, with the swing limited by the pose. A jump twice
    /// as high now throws a shadow twice as small.
    private var hopShadowScale: CGFloat {
        guard GameRules.hopArcHeight > 0 else { return 1 }
        let height = pose.lift / GameRules.hopArcHeight
        return max(1 - GameRules.pieceShadowLiftSwing * height, GameRules.pieceShadowFloor)
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
