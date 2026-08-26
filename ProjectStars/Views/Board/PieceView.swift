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
    @Environment(\.planeIsAsleep) private var planeIsAsleep



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

    /// Gold regardless of plane or charge.
    ///
    /// A piece falling between planes is neither on the one it left nor the one
    /// it is going to, and drawing it in either plane's material is a claim
    /// about where it is. Gold is what it wears while it belongs to nowhere, and
    /// the moment it lands is the moment it takes the new plane's material — see
    /// where the fall hands it over.
    var forcesGold: Bool = false

    /// How far the shadow is lifted against the perspective's seating drop, in
    /// art pixels. Handed in so it can be tuned live.
    var shadowLift: CGFloat = GameRules.pieceShadowPerspectiveLift

    /// Which of Gemini's twins this is, or `nil` for a whole piece.
    ///
    /// Handed in rather than inferred from being split: which twin is holding
    /// the turn changes every turn, and either of them can be the one that fell.
    var twin: GeminiHalf?

    /// Whether this figure gives off light: the aura behind it, and the bloom
    /// on its lit gem.
    ///
    /// **Off for afterimages**, and it covers every bloom rather than just the
    /// halo, because they are one idea. A ghost is a picture of what was
    /// standing somewhere; light is not part of the figure, it is something the
    /// living one is doing. Three glows trailing behind read as four charged
    /// pieces rather than one leaving a mark.
    ///
    /// The gem still lights — that is a swapped palette entry, and part of what
    /// the figure looked like. It simply does not bloom.
    ///
    /// And it is the whole of what the piece is expensive to draw. Every bloom
    /// here is a silhouette taken through a shader and then a Gaussian blur,
    /// which is an offscreen pass apiece; a charged sign dragging a trail was
    /// paying for eight of them a frame, and only while walking, which is
    /// exactly the shape the frame rate had.
    var emitsLight = true

    /// Whether the pool of shadow under the figure is drawn.
    ///
    /// Off for afterimages: a ghost is a picture of the figure, and a trail of
    /// shadows would be a trail of things claiming to be standing there.
    var showsShadow = true

    /// Which part of Libra's assembly this copy draws. See `LibraPieceView.Part`.
    var part: LibraPieceView.Part = .whole

    /// How white the figure still is as it arrives, `1`…`0`.
    ///
    /// A wash over the finished figure rather than a different drawing: the
    /// piece resolves *into* itself, which is the entrance every game with a
    /// spawn animation uses because it says "this is you" before it says
    /// anything about which sign you are.
    var spawnWash: Double = 0

    /// Which drawing this piece is right now.
    /// True when this copy is the pan drawn a row ahead of her, which brings
    /// none of the rest of the figure with it.
    private var isFrontPanOnly: Bool { part == .frontPan }

    private var spriteID: SpriteID {
        if zodiac.hasOwnHalves, let twin { return .geminiHalf(twin) }
        // **Every sign is drawn from every side.** This used to be a Cancer
        // exception with everyone else a statue seen from the front however it
        // was facing. Gemini still is one — its column spends its slots on the
        // halves, so all four of its facings point at the same drawing.
        return .pieceFacing(zodiac, facing)
    }

    /// True when this drawing is the mirror of one on the sheet.
    ///
    /// East is west flipped — three drawings covering four sides, for everyone
    /// except Gemini, whose one drawing faces south whichever way it walks.
    private var isMirrored: Bool { zodiac != .gemini && facing == .right }

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
            //
            // **About the body's middle, not the frame's.** The figure is two
            // cells tall and drawn shifted up out of its own layout box, so the
            // box's centre — which is what a rotation takes by default — sits
            // down at the middle of the *lower* cell, roughly where the feet
            // are. A piece turning about its feet does not tumble, it swings,
            // which is what has always looked slightly wrong about this.
            .rotationEffect(.degrees(spin), anchor: bodyCentre)
        }
        .offset(y: carryOffset)
        .allowsHitTesting(false)
    }

    /// The middle of the drawn figure, in the units of its own layout box.
    ///
    /// The box is `tileSize` by `tileSize * 2`; the figure inside it is offset
    /// up by half a tile plus the seating lift. Undoing exactly that in unit
    /// space is what puts the anchor back on the body.
    private var bodyCentre: UnitPoint {
        let rise = tileSize / 2 + GameRules.pieceLift * scale
        return UnitPoint(x: 0.5, y: 0.5 - rise / (tileSize * 2))
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
                .colorFlash(Palette.white, amount: spawnWash)
                // **Outside the material, on purpose.**
                //
                // Stone and moss are what the *figure* is made of. A gem is not
                // — it is a cut stone floating near one, and Terra was growing
                // moss on it because it happened to be drawn inside the view
                // the moss pass covers. Out here it keeps its own colours on
                // both planes, which is what a gem is for.
                .background(alignment: .top) { virgoGems(behind: true) }
                .overlay(alignment: .top) { virgoGems(behind: false) }
                .overlay(alignment: .top) { sagittariusArrow }
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
        // Read here, into `let`s, and iterated over an array.
        //
        // `ForEach(0..<n)` is the *constant range* initialiser: SwiftUI captures
        // it on the first build and never looks again, so a bench knob wired
        // into it moves nothing. An array is the dynamic one — and taking all
        // three values out as locals makes sure each is touched while the body
        // is being evaluated, which is what registers the observation that
        // redraws this when a slider moves.
        let layers = AuraStyle.layers
        let radius = AuraStyle.radius
        let opacity = AuraStyle.opacity

        return ZStack {
            ForEach(Array(0..<layers), id: \.self) { step in
                material
                    .colorEffect(
                        ShaderLibrary.flatSilhouette(.color(GameRules.stormGlowTint))
                    )
                    .blur(radius: radius * scale * CGFloat(step + 1))
                    .opacity(opacity / Double(step + 1))
            }
        }
        .allowsHitTesting(false)
    }

    /// The ordinary charged look: gold, with the gem lit and blooming.
    ///
    /// Named so the doubled version below can reuse it rather than restate it —
    /// two copies of this drifted apart the moment Leo's threshold went in.
    @ViewBuilder
    private func charged(intensity: Double = 1) -> some View {
        // The lit sprite itself, which a ghost still gets: the gem is a swapped
        // palette entry and part of the picture. Only the bloom over it is
        // light, and only the living figure is giving any off.
        let core = material.paletteSwap([PaletteSwap(gem.dim, gem.lit)])

        if !emitsLight {
            core
        } else {
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
                radius: AuraStyle.glowRadius * scale,
                // And harder, because a gem blooms from two pixels and a mane
                // from a hundred: the same intensity reads as a glow on one and
                // nothing on the other.
                intensity: zodiac == .leo ? GameRules.maneGlowIntensity : intensity,
                trail: AuraStyle.glowTrail
            ) {
                // The eyes keep the old rule — the sign's element, on both
                // planes — while the body stays gold.
                //
                // The eyes keep the old rule — the sign's element, on both
                // planes — while the body stays gold.
                core
            }
        }
    }

    /// The sprite with its gem lit, before any flash is laid over it.
    @ViewBuilder
    private var lit: some View {
        // A ghost of a backwards sign is still a ghost — see `emitsLight`. It
        // keeps the charged assembly and drops the purple halo, the same way it
        // keeps the lit gem and drops the bloom over it.
        if isCharged, zodiac.zodiaction.firesAtEmpty, emitsLight {
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
            .background { if emitsLight { aura } }
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
    private var isGilded: Bool { isCharged || starElement != nil || forcesGold }

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
                part: part,
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
            Group {
                if isCharged {
                    // **The star's motion**, not a private one: bob, turn and
                    // breathe together. It was three hand-written curves that
                    // happened to describe the same idea Polaris already had a
                    // name for — see `HoverStyle`.
                    PixelSprite(id: .piscesFishCharged) { Color.clear }
                        .rotationEffect(fishTurn)
                        .scaleEffect(x: 1, y: fishSquash)
                        .offset(y: fishSquashDrop)
                        .modifier(Hovering(style: .star, clock: clock))
                        .offset(
                            y: (GameRules.piscesFishDrop - GameRules.piscesFishLift)
                                * scale
                        )
                } else {
                    // Still, and stone. The fish is part of him until the meter
                    // fills; only then does it come loose.
                    PixelSprite(id: .piscesFish) { Color.clear }
                        .rotationEffect(fishTurn)
                        .scaleEffect(x: 1, y: fishSquash)
                        .offset(y: fishSquashDrop)
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
            TimelineView(.animation(paused: planeIsAsleep)) { timeline in
                #if DEBUG
                let _ = RenderTally.tick("Piece#1")
                #endif
                let now = clock(timeline.date.timeIntervalSinceReferenceDate)
                // Still while he is stone. The float is the shot being *ready*,
                // and an arrow drifting over a dark statue promises something
                // the sign cannot do yet.
                let rise = isCharged
                    ? (1 - cos(now / GameRules.sagittariusArrowPeriod * 2 * .pi)) / 2
                    : 0

                PixelSprite(id: .sagittariusArrowRest(SpriteAxis(facing: facing))) { Color.clear }
                    .scaleEffect(x: facing == .right ? -1 : 1, y: 1)
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
                            PixelSprite(id: .sagittariusArrowRest(SpriteAxis(facing: facing))) { Color.clear }
                    .scaleEffect(x: facing == .right ? -1 : 1, y: 1)
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
            TimelineView(.animation(paused: planeIsAsleep)) { timeline in
                #if DEBUG
                let _ = RenderTally.tick("Piece#2")
                #endif
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

            PixelSprite(id: .sagittariusArrowRest(SpriteAxis(facing: facing))) { Color.clear }
                    .scaleEffect(x: facing == .right ? -1 : 1, y: 1)
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


    @ViewBuilder
    private func virgoGems(behind: Bool) -> some View {
        virgoGemLayer(behind: behind)
    }

    @ViewBuilder
    private func virgoGemLayer(behind: Bool) -> some View {
        if zodiac == .virgo {
            TimelineView(.animation(paused: planeIsAsleep)) { timeline in
                #if DEBUG
                let _ = RenderTally.tick("Piece#3")
                #endif
                let now = clock(timeline.date.timeIntervalSinceReferenceDate)
                let swing = now / GameRules.virgoGemPeriod * 2 * .pi
                let bob = now / GameRules.virgoGemFloatPeriod * 2 * .pi

                // `1 - cos` rather than `sin`: it is zero at the start of the
                // circuit and never negative, so the drawn position is the top
                // of the path and every other moment is below it.
                let dip = (1 - cos(swing)) / 2
                let across = sin(swing)

                let cast = gemCast
                // Falling and swelling together, so it reads as coming toward
                // the viewer rather than sliding down.
                let drop = (1 - cos(bob)) / 2

                ZStack {
                    // The left gem runs anticlockwise, the right one clockwise,
                    // so the pair opens and closes together rather than sliding
                    // across her in step. Side-on they are not a pair at all:
                    // one is behind her and one in front, each its own drawing.
                    if cast.backBehind == behind {
                        outerGem(
                            cast.back, across: -across, dip: dip, at: cast.backAt,
                            // Half a turn apart, so one rises as the other
                            // falls and the pair reads as a ring rather than as
                            // two gems bobbing together.
                            // Half a turn apart unless the cast asks for them
                            // together — facing away, opposite phases read as
                            // two gems arguing rather than as one ring.
                            orbit: cast.pairOrbits
                                ? swing + (cast.pairInPhase ? 0 : .pi)
                                : nil,
                            swingsWide: cast.pairSwingsWide,
                            rise: cast.pairRise,
                            swingX: cast.pairSwingX
                        )
                    }
                    if cast.frontBehind == behind {
                        outerGem(
                            cast.front, across: across, dip: dip,
                            mirrored: cast.frontIsMirrored, at: cast.frontAt,
                            orbit: cast.pairOrbits ? swing : nil,
                            swingsWide: cast.pairSwingsWide,
                            rise: cast.pairRise,
                            depthSwing: cast.frontDepthSwing,
                            depthBack: cast.frontDepthBack,
                            swingX: cast.pairSwingX
                        )
                    }
                    if cast.middleBehind == behind {
                        middleGem(cast, drop: drop, swing: swing)
                    }
                }
                // The gems are overlaid after the figure is mirrored, so they
                // have to take the flip themselves or her right-facing set
                // would be her left-facing one.
                .scaleEffect(x: isMirrored ? -1 : 1, y: 1)
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
    private func outerGem(
        _ gem: VirgoGem,
        across: Double,
        dip: Double,
        mirrored: Bool = false,
        at place: CGSize = .zero,
        orbit: Double? = nil,
        swingsWide: Bool = false,
        rise: CGFloat = GameRules.virgoGemOrbitRise,
        depthSwing: CGFloat = 0,
        depthBack: CGFloat = 0,
        swingX: CGFloat = GameRules.virgoGemSwingX
    ) -> some View {
        // **A dip is not an orbit.** `(1 - cos) / 2` is never negative, so the
        // pair only ever sagged below where it was drawn and never rose above
        // it. Facing her, that reads as weight. Side-on, where the ring is seen
        // edge-on, it has to go both ways — so there the height is a sine and
        // the sideways swing is left out, since depth is doing that work.
        let rise = orbit.map { -sin($0) * rise * scale }
        let sideways = orbit == nil || swingsWide
            ? across * swingX * scale
            : 0

        // Round the back of the circuit and out again, a quarter turn off the
        // height — which is what makes a gem side-on read as going *behind* her
        // rather than bobbing beside her.
        // **Further back than forward, and still one curve.**
        //
        // The circuit is not symmetric to look at: it should go further round
        // behind her than it comes toward the viewer. Swapping the amplitude at
        // the halfway point does that arithmetically and *jerks* — the reach
        // changes size the instant the gem crosses the middle. So the two ends
        // are turned into a span and a centre instead, which reaches exactly as
        // far each way and never steps.
        //
        // A gem with no depth at either end stays exactly where it was put.
        let depth = orbit.map { turn -> CGFloat in
            let span = (depthSwing + depthBack) / 2
            let centre = (depthBack - depthSwing) / 2
            return (-cos(turn) * span + centre) * scale
        } ?? 0

        return PixelSprite(id: .virgoGem(gem)) { Color.clear }
            .scaleEffect(x: mirrored ? -1 : 1, y: 1)
            .scaleEffect(1 + dip * GameRules.virgoGemFloatGrowth)
            .offset(
                x: sideways + depth + place.width * scale,
                y: (rise ?? dip * GameRules.virgoGemSwingY * scale) + place.height * scale
            )
    }

    /// The gem that floats on its own, in front of her or behind her head.
    private func middleGem(_ cast: GemCast, drop: Double, swing: Double) -> some View {
        // **Side-on it is going round her, not up and down.**
        //
        // A ring seen edge-on: it rises to the top of the circuit shrinking as
        // it goes, is smallest at the far side halfway through, swells again on
        // the way down, and is back to full size where it started. One cosine
        // for the size and one sine for the height, a quarter turn apart, is
        // the whole of it.
        let orbits = cast.middleOrbits
        let size = orbits
            ? GameRules.virgoGemOrbitFar
                + (1 - GameRules.virgoGemOrbitFar) * (1 + cos(swing)) / 2
            : 1 + drop * GameRules.virgoGemFloatGrowth
        let rise = orbits
            ? -sin(swing) * GameRules.virgoGemMiddleRise * scale
            : drop * GameRules.virgoGemFloat * scale

        return PixelSprite(id: .virgoGem(cast.middle)) { Color.clear }
            .scaleEffect(size)
            .offset(
                x: cast.middleAt.width * scale,
                y: rise + cast.middleAt.height * scale
            )
    }



    /// The gem places, from the bench while one is running.
    private var westBack: CGSize { GameRules.virgoGemWestBack }

    private var westFront: CGSize { GameRules.virgoGemWestFront }

    private var westMiddle: CGSize { GameRules.virgoGemWestMiddle }

    private var northPair: CGSize { GameRules.virgoGemNorthPair }

    private var northMiddle: CGSize { GameRules.virgoGemNorthMiddle }

    /// How much the fish flattens, seen from the side.
    ///
    /// Turned a quarter, the drawing's length runs up and down the screen —
    /// which makes a fish that is as tall as it is long. Squashing it back
    /// gives the side view the proportions the front one has.
    private var fishSquash: CGFloat {
        facing == .left || facing == .right ? GameRules.piscesFishSideSquash : 1
    }

    /// How far the squashed fish drops to keep its underside where it was.
    ///
    /// A scale about the centre takes half the lost height off each end, so the
    /// bottom rises by half of it — pushing it back down by exactly that much
    /// leaves the fish sitting where the unsquashed one sat.
    private var fishSquashDrop: CGFloat {
        (1 - fishSquash) * tileSize / 2
    }

    /// How far the fish is turned from the drawing, which faces south.
    ///
    /// Counter-clockwise, a quarter at a time: east a quarter, north a half,
    /// west three quarters.
    ///
    /// Applied to the sprite rather than to the box it sits in — the box also
    /// carries the drop that puts the fish on his body, and turning that swung
    /// the fish around him instead of spinning it where it stood.
    private var fishTurn: Angle {
        switch facing {
        case .right: .degrees(-90)
        case .up: .degrees(-180)
        case .left: .degrees(-270)
        default: .zero
        }
    }

    /// Which of the five gem drawings this facing uses, and how they sit.
    ///
    /// Five drawings, three arrangements. South and north are symmetrical, so
    /// each spends one drawing on the pair and mirrors it. Side-on there is no
    /// symmetry to spend: one gem is behind her, one is in front, and the
    /// middle sits further out than either.
    private struct GemCast {
        /// The gem drawn first — her left, or the one behind her side-on.
        let back: VirgoGem

        /// Her right, or the one in front of her side-on.
        let front: VirgoGem

        /// Whether the front one is the back one flipped rather than its own
        /// drawing.
        let frontIsMirrored: Bool

        let middle: VirgoGem

        /// Where each gem sits, in art pixels from where it was drawn.
        ///
        /// Zero all round for south — those were placed when they were drawn.
        /// The other two arrangements are found on the bench; see
        /// `VirgoGemTuning`.
        let backAt: CGSize
        let frontAt: CGSize
        let middleAt: CGSize

        /// Which gems draw behind her rather than over her.
        ///
        /// Facing away they all do — every one of them is on the far side of
        /// her head. Side-on only the back one does, which is what makes it the
        /// back one.
        let backBehind: Bool
        let frontBehind: Bool
        let middleBehind: Bool

        /// Whether the middle gem swings round her on a ring seen edge-on,
        /// growing and shrinking as it comes and goes.
        let middleOrbits: Bool

        /// Whether the pair rides a real circuit rather than the front view's
        /// one-way sag, and whether that circuit keeps its sideways swing.
        ///
        /// Facing away it does, which makes a vertical oval. Side-on it does
        /// not, because depth is already doing the sideways work.
        let pairOrbits: Bool
        let pairSwingsWide: Bool

        /// Whether the pair runs together rather than half a turn apart.
        var pairInPhase = false

        /// How far the pair rises and falls, in art pixels.
        var pairRise = GameRules.virgoGemOrbitRise

        /// How far the front gem comes toward the viewer, in art pixels.
        var frontDepthSwing: CGFloat = 0

        /// How far it goes the other way, round behind her.
        var frontDepthBack: CGFloat = 0

        /// How wide the pair swings sideways, in art pixels.
        var pairSwingX = GameRules.virgoGemSwingX
    }

    private var gemCast: GemCast {
        switch facing {
        case .up:
            GemCast(
                back: .northWest, front: .northWest, frontIsMirrored: true,
                middle: .north,
                backAt: CGSize(width: -northPair.width, height: northPair.height),
                frontAt: northPair,
                middleAt: northMiddle,
                backBehind: true, frontBehind: true, middleBehind: true,
                middleOrbits: false, pairOrbits: true, pairSwingsWide: true,
                pairInPhase: true, pairRise: GameRules.virgoGemNorthRise,
                pairSwingX: GameRules.virgoGemNorthSwingX
            )
        case .left, .right:
            GemCast(
                back: .northWest, front: .southWest, frontIsMirrored: false,
                middle: .west,
                backAt: westBack, frontAt: westFront, middleAt: westMiddle,
                backBehind: true, frontBehind: false, middleBehind: false,
                middleOrbits: true, pairOrbits: true, pairSwingsWide: false,
                frontDepthSwing: GameRules.virgoGemFrontDepthSwing,
                frontDepthBack: GameRules.virgoGemBackDepthSwing
            )
        // Facing the viewer. Diagonals do not reach here — a diagonal move
        // resolves to a cardinal facing first, see `SwipeDirection.facing(from:)`.
        default:
            GemCast(
                back: .southWest, front: .southWest, frontIsMirrored: true,
                middle: .south,
                backAt: .zero, frontAt: .zero, middleAt: .zero,
                backBehind: false, frontBehind: false, middleBehind: false,
                middleOrbits: false, pairOrbits: false, pairSwingsWide: false
            )
        }
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

// MARK: - Landing

/// What a piece arriving from the plane above is dressed in.
@MainActor
enum FallStyle {

    /// The flash thrown at the moment of impact.
    ///
    /// Every one of these is an existing strip recoloured to the sign's own
    /// element — see `EffectSpriteView.recoloured` — so choosing between them is
    /// choosing a shape rather than commissioning a drawing.
    enum Arrival: String, CaseIterable {

        /// `absorb`, run backwards: energy arriving rather than leaving.
        case absorb

        /// The plate's shockwave.
        case plate

        /// A coin coming apart.
        case coin

        /// The slower of the two fireworks.
        case firework

        /// The larger sparkle burst.
        case sparkle

        var next: Arrival {
            let all = Self.allCases
            return all[(all.firstIndex(of: self)! + 1) % all.count]
        }

        var effect: EffectSprite {
            switch self {
            case .absorb: .absorb
            case .plate: .plateBurst
            case .coin: .coinExplosion
            case .firework: .fireworkSlow
            case .sparkle: .sparkleBurstThree
            }
        }

        /// `absorb` is the one that means the opposite of itself reversed.
        var runsBackwards: Bool { self == .absorb }
    }

    static let defaultArrival: Arrival = .absorb

    static var arrival: Arrival {
        #if DEBUG
        FallTuning.shared.arrival
        #else
        defaultArrival
        #endif
    }
}

/// What the charged halo is made of.
///
/// On a bench because it is the game's biggest single cost — each layer is a
/// silhouette through a shader and then a blur, and a blur is an offscreen
/// pass. See `AuraTuning`.
@MainActor
enum AuraStyle {

    static var layers: Int {
        #if DEBUG
        max(Int(AuraTuning.shared.layers), 0)
        #else
        defaultLayers
        #endif
    }

    static var radius: CGFloat {
        #if DEBUG
        CGFloat(AuraTuning.shared.radius)
        #else
        CGFloat(defaultRadius)
        #endif
    }

    static var opacity: Double {
        #if DEBUG
        AuraTuning.shared.opacity
        #else
        defaultOpacity
        #endif
    }

    /// The charged bloom's spread and how many copies trail behind it.
    ///
    /// **This is the one that matters for most signs.** `aura` is Aquarius
    /// only; every other charged piece is `PaletteGlow`, and a trail of two
    /// means three copies, each rebuilding the sprite, running the palette
    /// shader over it and blurring the result.
    static var glowRadius: CGFloat {
        #if DEBUG
        CGFloat(AuraTuning.shared.glowRadius)
        #else
        CGFloat(defaultGlowRadius)
        #endif
    }

    static var glowTrail: Int {
        #if DEBUG
        max(Int(AuraTuning.shared.glowTrail), 0)
        #else
        defaultGlowTrail
        #endif
    }

    static let defaultGlowRadius: Double = 2
    static let defaultGlowTrail = 2

    static let defaultLayers = 2
    static let defaultRadius: Double = 3
    static let defaultOpacity: Double = 0.85
}
