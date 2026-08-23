//
//  AquariusStormPiece.swift
//  Project Stars
//
//  The sign that is a bluff: a storm built from one band, and the thing inside.
//

import SwiftUI

/// A pointed oval — a football, the shape two overlapping circles share.
///
/// Two curves meeting at a point on the left and a point on the right. The
/// points are the whole reason for it: an ellipse tapers to a round end and
/// reads as a bubble, where this comes to a corner and reads as an eye.
struct Vesica: Shape {

    /// How fat the shape is between its points, as a fraction of its height.
    ///
    /// One fills the frame. Lower is a narrower, meaner eye.
    var fullness: CGFloat = 1

    func path(in rect: CGRect) -> Path {
        let left = CGPoint(x: rect.minX, y: rect.midY)
        let right = CGPoint(x: rect.maxX, y: rect.midY)
        // Beyond the frame, because a quadratic curve reaches only half way to
        // its control point — pulling it to twice the half-height is what makes
        // the curve actually touch the top and bottom of the rect.
        let bulge = rect.height * fullness

        var path = Path()
        path.move(to: left)
        path.addQuadCurve(to: right, control: CGPoint(x: rect.midX, y: rect.midY - bulge))
        path.addQuadCurve(to: left, control: CGPoint(x: rect.midX, y: rect.midY + bulge))
        path.closeSubpath()
        return path
    }
}

/// Aquarius' storm, assembled rather than drawn.
///
/// One band, stacked at several scales and turns, with the sign's own sprite on
/// top as a silhouette and a pair of eyes inside it. Everything about the funnel
/// is a function of `phase`, so the eleven states the meter can be in are eleven
/// arrangements of the same strip rather than eleven drawings — and the wider,
/// faster, taller storm at ten is the same art as the wisp at one.
///
/// - Note: Meant to be flattened once the look is settled. Several rotated,
///   blended copies of a sixteen-frame strip is a lot of composited layers per
///   frame, which is the cost that has bitten this project before.
struct AquariusStorm: View {
    @Environment(\.planeIsAsleep) private var planeIsAsleep



    /// `0` is the bare pot; `10` is the full tornado.
    var phase: Int = 10

    /// How tall the column stands, as a fraction of the square.
    var height: CGFloat = GameRules.aquariusStormHeight

    /// How far apart in the strip consecutive plates start. `1` spreads them
    /// evenly across the whole strip.
    var spread: Double = GameRules.aquariusStormSpread

    /// How many frames to drop off the **end** of the band's strip.
    ///
    /// The tail cells thin out to nothing, and a nearly-empty frame in a looped
    /// stack is a hole that comes round again. One drops the blank; more trims
    /// back into the thinning frames before it.
    /// Frames dropped from the end of each plate's strip, thinning with the
    /// meter — see `GameRules.aquariusStormTaperLeast`.
    var taper: Int {
        let least = Double(GameRules.aquariusStormTaperLeast)
        let most = Double(GameRules.aquariusStormTaperMost)
        return Int((least + (most - least) * strength).rounded())
    }

    /// A multiplier on every plate's width.
    var bladeScale: CGFloat = GameRules.aquariusStormBlade

    /// How far the eye plates turn, either way.
    var eyeTurn: Double = GameRules.aquariusEyeTurn

    /// What fraction of the stack's sway the eye plates take.
    ///
    /// A fraction rather than all of it: the eye is deeper in the column than
    /// the wall around it, and things further away move less.
    var eyeSway: CGFloat = GameRules.aquariusEyeSway

    /// How big the second eye plate is against the first.
    var eyeTwinScale: CGFloat = GameRules.aquariusEyeTwinScale

    /// How much wider an eye plate is than the widest of the stack.
    var eyeScale: CGFloat = GameRules.aquariusEyeScale

    /// Which blade the plates are cut from.
    /// Which blade the plates are cut from. `nil` takes whatever the phase
    /// calls for; the gallery overrides it to compare the two.
    var plate: EffectSprite?

    /// A fixed moment to draw, instead of the running clock.
    ///
    /// What makes the assembly cacheable: with time as an input rather than
    /// something read from the environment, any frame of it can be asked for
    /// out of order and rendered off-screen.
    var frozenAt: TimeInterval?

    /// How each eye plate sits against the rest. Two of them, because one
    /// darkening pass reads as a stain and two crossing at different heights
    /// read as a gap you are looking through.
    var eyeBlend: BlendMode = .hardLight
    var eyeTwinBlend: BlendMode = .multiply

    /// Where each sits, as a fraction of the square.
    var eyeY: CGFloat = GameRules.aquariusEyeY
    var eyeTwinY: CGFloat = GameRules.aquariusEyeTwinY

    /// Size of the square this fills, in points.
    var side: CGFloat = 96

    /// Whole-pixel scale, for art-pixel measurements.
    var scale: CGFloat = 3

    var body: some View {
        TimelineView(.animation(paused: frozenAt != nil || planeIsAsleep)) { timeline in
            #if DEBUG
            let _ = RenderTally.tick("AquariusStormPiece#1")
            #endif
            let now = frozenAt ?? timeline.date.timeIntervalSinceReferenceDate

            ZStack {
                ForEach(0..<bands, id: \.self) { band in
                    EffectSpriteView(
                        effect: plate ?? GameRules.aquariusPlate(atPhase: phase),
                        tileSize: bandSize(band),
                        start: .distantPast,
                        loops: true,
                        // Each plate a different way through the strip.
                        //
                        // The band ends on an empty cell, so plates in step all
                        // vanish on the same frame and the tornado blinks. Held
                        // apart, there is always something at every height.
                        clock: { $0 + self.stagger(band) },
                        frameCount: self.played
                    )
                    .rotationEffect(.degrees(turn(band, at: now) + self.tilt(band)))
                    .offset(x: sway(band, at: now), y: rise(band))
                }

                // The eye of the storm.
                //
                // One more plate, wider than any below it, near the top, and
                // deliberately **still** — everything else shakes, so the one
                // thing that does not is where the eye goes. Darkened against
                // the stack rather than drawn darker, so it reads as depth
                // through the wall of air instead of as a hole cut in it.
                if bands > 0 {
                    eyePlate(
                        blend: eyeBlend, at: eyeY, size: 1,
                        turn: eyeTurn, speed: 0.9, at: now
                    )
                    eyePlate(
                        blend: eyeTwinBlend, at: eyeTwinY, size: eyeTwinScale,
                        turn: -eyeTurn * 1.3, speed: 1.3, at: now
                    )
                }
            }
            .frame(width: side, height: side)
        }
    }

    // MARK: - The shape of the storm, from one number

    /// How much of a storm there is at all, `0`…`1`.
    private var strength: Double { Double(min(max(phase, 0), 10)) / 10 }

    /// How many plates are in the stack. A fuller meter is a taller, denser
    /// storm — they overlap, so more of them fills the column in as well as
    /// raising it.
    private var bands: Int {
        guard phase > 0 else { return 0 }
        let least = Double(GameRules.aquariusStormBandsLeast)
        let most = Double(GameRules.aquariusStormBandsMost)
        return Int((least + (most - least) * strength).rounded())
    }

    /// One of the two plates that make the eye of the storm.
    ///
    /// They turn, but barely and out of step with each other — immobile was
    /// wrong, because the stack behind them never stops and a still shape in
    /// front of moving ones reads as a decal rather than as a part of it.
    @ViewBuilder
    private func eyePlate(
        blend: BlendMode,
        at height: CGFloat,
        size: CGFloat,
        turn: Double,
        speed: Double,
        at now: TimeInterval
    ) -> some View {
        EffectSpriteView(
            effect: plate ?? GameRules.aquariusPlate(atPhase: phase),
            tileSize: bandSize(bands - 1) * eyeScale * size,
            start: .distantPast,
            loops: true,
            clock: { $0 + self.stagger(bands - 1) * (speed > 1 ? 0.35 : 0.6) },
            frameCount: played
        )
        .colorEffect(ShaderLibrary.flatSilhouette(.color(Palette.midnight)))
        .opacity(GameRules.aquariusEyeOpacity)
        .rotationEffect(.degrees(sin(now * speed) * turn))
        // Riding the same sway as the plates around it, and then some: an eye
        // that holds still while the wall of air moves reads as a hole in the
        // picture rather than a hole in the storm.
        .offset(
            x: sway(bands - 1, at: now) * eyeSway,
            y: rise(bands - 1) + side * height
        )
        .blendMode(blend)
    }

    /// Frames actually played, after the taper.
    private var played: Int {
        max(EffectSprite.aquariusArmor.frames - max(taper, 0), 1)
    }

    /// Where in the strip this plate starts, in seconds.
    ///
    /// Spread across the strip's whole length rather than by a fixed step, so
    /// however many plates there are they still cover it evenly.
    private func stagger(_ band: Int) -> TimeInterval {
        // Measured on what is *played*, not on what was drawn — trimming the
        // tail shortens the loop, and a stagger spread over the old length
        // would leave the plates bunched.
        let length = Double(played) * EffectSprite.aquariusArmor.rate.frameDuration
        return length * spread * Double(band) / Double(max(bands, 1))
    }

    /// A fixed few degrees of lean, different for every plate.
    ///
    /// Deterministic rather than random-per-frame: a plate that re-rolls its
    /// angle every draw flickers. This is the plate being *built* crooked, and
    /// the shake happens on top of it.
    private func tilt(_ band: Int) -> Double {
        let hash = sin(Double(band) * 12.9898) * 43_758.5453
        return (hash - hash.rounded(.down)) * 14 - 7
    }

    /// **Widest at the top.** A tornado is a cone standing on its point, so
    /// band `0` at the bottom is the narrow end and each one above it is wider.
    private func bandSize(_ band: Int) -> CGFloat {
        let up = CGFloat(band) / CGFloat(max(bands - 1, 1))
        let narrow = side * 0.30
        let wide = side * (0.86 + 0.30 * strength)
        return (narrow + (wide - narrow) * up) * bladeScale
    }


    /// Stacked close together — the plates touch, so the stack reads as one
    /// column of air rather than as a set of separate rings.
    private func rise(_ band: Int) -> CGFloat {
        let step = side * height / CGFloat(max(bands - 1, 1))
        return side * 0.22 - CGFloat(band) * step
    }

    /// **Shaking, not spinning.**
    ///
    /// Each plate jitters a few degrees either side of straight, on its own
    /// count, rather than turning continuously. A spin reads as a solid object
    /// rotating; a shake reads as the plate being buffeted, and a stack of them
    /// slightly out of step with each other is what makes the column look like
    /// it is being driven from below.
    private func turn(_ band: Int, at now: TimeInterval) -> Double {
        let amplitude = (3 + Double(band) * 0.8) * (0.4 + 0.6 * strength)
        let speed = 7 + Double(band) * 1.7
        let phaseOffset = Double(band) * 1.1
        return sin(now * speed + phaseOffset) * amplitude
    }

    /// And a matching sway across, so a plate is not shaking on the spot.
    private func sway(_ band: Int, at now: TimeInterval) -> CGFloat {
        let amplitude = side * 0.012 * CGFloat(1 + band) * CGFloat(0.4 + 0.6 * strength)
        return CGFloat(cos(now * (5.5 + Double(band) * 1.3) + Double(band) * 0.7)) * amplitude
    }

}

/// The pair of eyes inside the funnel.
struct StormEyes: View {

    /// How wide one eye is, in points.
    var width: CGFloat = 16

    /// How far apart they sit, centre to centre.
    var spacing: CGFloat = 20

    /// Slanted so the **inner** ends drop, which is a scowl. Settled at 35.
    var slant: Double = 35

    /// How narrow the eye is closed, as a fraction of its width. Settled.
    var slit: CGFloat = 0.35

    /// How hard they burn, against the settled look.
    var glow: CGFloat = 1

    /// How soft the pair is, in points. See `GameRules.aquariusEyeHaze`.
    var haze: CGFloat = 0

    /// Purple: air's colour everywhere else in the game.
    var tint: Color = ElementFX.ramp(for: .air).bright

    var body: some View {
        HStack(spacing: spacing - width) {
            // Left eye's inner end is its right one, so a positive turn drops
            // it. The right eye is the mirror.
            eye(turned: slant)
            eye(turned: -slant)
        }
        .blur(radius: haze)
    }

    private func eye(turned: Double) -> some View {
        // A flat fill with blurred copies of *itself* stacked behind it,
        // additively. `shadow` could only ever darken outward from the shape,
        // which is why turning the knob up did nothing to the purple in the
        // middle — the fill was never part of what was glowing.
        let shape = Vesica(fullness: 0.72)
            .fill(tint)
            .frame(width: width, height: width * slit)
            .rotationEffect(.degrees(turned))

        return ZStack {
            // Each copy added to the ones under it, not just the finished stack
            // added to the board. Inside a group the layers composite normally,
            // so however many were piled up the middle never got past the
            // purple it started at — which is why turning the knob up only ever
            // grew the halo.
            ForEach(0..<3, id: \.self) { step in
                shape
                    .blur(radius: width * (0.18 + CGFloat(step) * 0.35) * max(glow, 0))
                    .opacity(Double(glow) / Double(step + 1))
                    .blendMode(.plusLighter)
            }

            shape.blendMode(.plusLighter)

            // A white core that comes up with the knob, so the middle burns out
            // rather than merely getting a brighter surround. Purple added to
            // purple is a brighter purple and stops there; reaching white takes
            // the other two channels.
            shape
                .foregroundStyle(Palette.white)
                .opacity(max(Double(glow) - 0.6, 0) * 0.5)
                .blendMode(.plusLighter)
        }
        .compositingGroup()
    }
}

/// The figure, carried by the storm rather than standing in it.
///
/// Turning, rising and breathing, all on their own periods so none of the
/// three ever lines up with another — three motions in step read as one
/// motion, which is the thing that makes something look mechanical.
struct FloatingAquarius: View {
    @Environment(\.planeIsAsleep) private var planeIsAsleep



    let blend: BlendMode

    /// Drawn with him, so they turn, rise and breathe as he does.
    ///
    /// Kept outside the blend but inside the transform: the eyes are his,
    /// not the storm's, and eyes that stay level while the head they belong
    /// to leans are the fastest way to make something look pasted on.
    var showsEyes = true
    var eyeOffset: CGFloat = GameRules.aquariusEyeGlowY

    /// How much of the figure's shrink the eyes follow. See below.
    var follow: CGFloat = GameRules.aquariusEyeFollow

    /// How small he gets at an empty meter, against `aquariusFigureShrink`.
    ///
    /// The shrink runs the whole way from phase 10 to phase 0, so by phase
    /// one he is already nearly as small as the pot — which leaves no
    /// difference between "the storm is nearly gone" and "the storm is
    /// gone", and the reveal is the whole sign.
    var floor: CGFloat = GameRules.aquariusFigureShrink

    /// How far he turns either way, in degrees.
    var turn: Double = GameRules.aquariusFigureTurn

    /// How big he is drawn, against the storm around him.
    var size: CGFloat = GameRules.aquariusFigureScale

    /// `0`…`1`, how full the meter is. The figure shrinks as it fills —
    /// see `GameRules.aquariusFigureShrink`.
    var strength: Double = 1

    /// A fixed moment to draw. See `AquariusStorm.frozenAt`.
    var frozenAt: TimeInterval?

    /// Where he hangs, as points from the middle.
    var height: CGFloat = GameRules.aquariusFigureY

    var body: some View {
        TimelineView(.animation(paused: planeIsAsleep)) { timeline in
            #if DEBUG
            let _ = RenderTally.tick("AquariusStormPiece#2")
            #endif
            let now = timeline.date.timeIntervalSinceReferenceDate
            let sway = sin(now / 5.2 * 2 * .pi) * turn
            let lift = sin(now / 3.7 * 2 * .pi) * 14
            let breath = 1 + sin(now / 4.3 * 2 * .pi) * 0.1

            // The bluff. A full storm hides the smallest figure, so the most
            // frightening it looks is the moment it can do the least.
            let shrink = floor + (1 - floor) * CGFloat(strength)
            // Swinging all the way to nothing and back: a light that never
            // goes out is a lamp, one that does is something blinking.
            let pulse = (1 - cos(now / GameRules.aquariusEyeGlowPeriod * 2 * .pi)) / 2
            let burn = GameRules.aquariusEyeGlowPeak * CGFloat(pulse)

            ZStack {
                // At zero there is no storm, so there is nothing for a
                // silhouette to be inside — it is just the statue, gold, as
                // any other sign's would be. The whole sign is this swap:
                // everything above zero is a shape in weather, and zero is
                // the little pot that was in there the whole time.
                let bare = strength <= 0

                PixelSprite(id: .piece(.aquarius)) { Color.clear }
                    .frame(width: 132 * size * shrink, height: 264 * size * shrink)
                    .colorEffect(
                        ShaderLibrary.flatSilhouette(.color(Palette.midnight)),
                        isEnabled: !bare
                    )
                    .blendMode(bare ? .normal : blend)

                if showsEyes, !bare {
                    // Sized as they were before they were attached to him.
                    //
                    // They ride his transform now, which already scales
                    // them — multiplying by his size as well applied it
                    // twice, and at 1.5 that is more than double.
                    // The float is cancelled, the bob is not.
                    //
                    // `height` is where he hangs in the funnel, and the
                    // eyes are placed in the picture rather than on him —
                    // so they should not be carried up by it. The bob and
                    // the turn they *do* take, because those are him
                    // moving rather than him being put somewhere.
                    // How much of the shrink they follow, as a knob.
                    //
                    // His feet are pinned, so his **centre** drops by half
                    // of what he loses and his **head** drops by all of it
                    // — twice as far. The eyes sit between the two and I
                    // have guessed wrong in both directions, so this is the
                    // term itself: 0 keeps them level, 1 rides his centre,
                    // 2 rides his head.
                    // Hazy at ten, sharp by one. He is a shape in weather
                    // while the storm holds and something looking at you
                    // when it thins, so the eyes come into focus as the
                    // cover goes.
                    StormEyes(
                        width: 40 * shrink,
                        spacing: 46 * shrink,
                        glow: burn,
                        haze: GameRules.aquariusEyeHaze
                            * CGFloat(max(strength * 10 - 1, 0) / 9)
                    )
                        .offset(
                            y: eyeOffset - height
                                + (follow - 1) * 132 * size * (1 - shrink)
                                    * GameRules.aquariusFigureSink
                        )
                }
            }
            .scaleEffect(breath)
            .rotationEffect(.degrees(sway))
            // Raised: he hangs in the funnel rather than standing under it,
            // which is the whole picture — something held up by the storm,
            // not something the storm is happening around.
            // Dropped as he shrinks, so his feet stay where they were.
            //
            // The sprite is centred, so half of everything it loses comes
            // off the bottom — without this he rises out of the funnel as
            // the meter empties, which is the opposite of settling into a
            // pot on the floor.
            .offset(
                y: height + lift
                    + 132 * size * (1 - shrink) * GameRules.aquariusFigureSink
            )
        }
    }
}


/// Aquarius on a square: the storm, the figure inside it, and the eyes.
///
/// **Phase zero is the plain piece.** Not a still storm, not a figure with the
/// weather turned off — the ordinary sprite, at the ordinary size, doing
/// nothing. Everything the storm does to him is something it is doing *to* him,
/// so when it goes there is nothing left over: no float, no turn, no breath, no
/// eyes. That is what makes the reveal a reveal rather than a fade.
struct AquariusStormPiece: View {
    @Environment(\.planeIsAsleep) private var planeIsAsleep



    /// `0`…`10`, how full the meter is.
    var phase: Int = 10

    /// The frames drawn for each phase so far. See `AquariusStormFilm`.
    var film: AquariusStormFilm?

    /// The phase that just ended, and when — so the plate it lost can be seen
    /// leaving. See `partingPlate(at:)`.
    @State private var parting: (from: Int, to: Int, at: Date)?

    /// What the bloom is coloured, and how that colour is applied.
    var glowTint: Color = GameRules.stormGlowTint
    var glowTintBlend: BlendMode = GameRules.stormGlowTintBlend

    /// Size of a board cell, in points.
    var tileSize: CGFloat

    /// The whole assembly against the square.
    var scale: CGFloat = GameRules.aquariusStormScale

    /// One frame of the filmed funnel, lit, with him inside it.
    ///
    /// Its own function because the branch above got long enough that the type
    /// checker gave up inferring the `TimelineView`'s content — and because the
    /// glow has to be applied *here*, at the canvas's own size, rather than
    /// around the finished piece. `PaletteGlow` rasterises into its content's
    /// **layout** bounds, and the piece is laid out at one tile while drawing
    /// across three, so wrapping the outside clips the mask to a tile-wide
    /// column. That is the light pillar this has produced before.
    ///
    /// Lit the whole time there is a storm, which is the inverse of every other
    /// sign: his meter runs backwards, so the state worth announcing is *having*
    /// power rather than being ready to spend it. At zero the glow goes and the
    /// pot is left plain, which is exactly when he can fire.
    @ViewBuilder
    private func filmed<Funnel: View>(@ViewBuilder _ funnel: @escaping () -> Funnel) -> some View {
        PaletteGlow(
            radius: GameRules.stormGlowRadius,
            intensity: GameRules.stormGlowIntensity,
            tint: glowTint,
            tintBlend: glowTintBlend
        ) {
            ZStack {
                funnel()

                // Live, on top of the filmed funnel — see `AquariusStormStill`
                // for why these two are split.
                FloatingAquarius(
                    blend: .exclusion,
                    strength: Double(min(max(phase, 0), 10)) / 10
                )
            }
        }
    }

    /// How much the 300-point assembly is shrunk to reach the board.
    ///
    /// Named once because two things need it and they must agree: what the
    /// storm is scaled by on screen, and what its reel is filmed at.
    private var drawnScale: CGFloat {
        scale * tileSize * GameRules.aquariusStormTiles / 300
    }

    /// The plate the storm just gained or lost, in the moment it moves.
    ///
    /// The filmed funnel can only cut between phases — ten reels are ten
    /// finished pictures with nothing between them — so the change is carried
    /// by a single live plate drawn over the top: **spreading outward and
    /// fading as it leaves, arriving tight and solid from spread and clear.**
    ///
    /// One sprite, so it costs nothing next to the thirteen underneath it. The
    /// same split the figure already uses: cache what is expensive and let what
    /// has to move smoothly be drawn live.
    @ViewBuilder
    private func partingPlate(at elapsed: TimeInterval) -> some View {
        if let parting {
            let age = Date.now.timeIntervalSince(parting.at) / GameRules.stormPlateParting

            if age < 1 {
                // Leaving spreads and fades; arriving does the same in reverse,
                // which is the same curve read backwards.
                let leaving = parting.to < parting.from
                let progress = leaving ? age : 1 - age

                // Where the plate it lost stood: the top of the stack, which is
                // its widest. Measured against the gallery's 300, like every
                // other number inside this assembly.
                let top = max(parting.from, parting.to)
                let bands = GameRules.aquariusStormBandsLeast
                    + Int((Double(GameRules.aquariusStormBandsMost
                        - GameRules.aquariusStormBandsLeast)
                        * Double(top) / 10).rounded())
                let strength = Double(top) / 10
                let width = 300 * (0.86 + 0.30 * strength) * GameRules.aquariusStormBlade
                let step = 300 * GameRules.aquariusStormHeight / CGFloat(max(bands - 1, 1))

                EffectSpriteView(
                    effect: GameRules.aquariusPlate(atPhase: top),
                    tileSize: width,
                    start: .distantPast,
                    loops: true
                )
                .scaleEffect(1 + progress * GameRules.stormPlateSpread)
                .opacity(1 - progress)
                .offset(y: 300 * 0.22 - CGFloat(bands - 1) * step)
                .allowsHitTesting(false)
            }
        }
    }

    var body: some View {
        if phase <= 0 {
            PixelSprite(id: .piece(.aquarius)) { Color.clear }
                .frame(width: tileSize, height: tileSize * 2)
        } else if let film, film.reel(for: phase)?.isEmpty == false {
            // The cached loop. Costs a texture swap a frame, whatever the piece
            // is doing — which is the whole point, since the live version is
            // rebuilt from scratch the moment anything under it moves.
            TimelineView(.animation(paused: planeIsAsleep)) { timeline in
                #if DEBUG
                let _ = RenderTally.tick("AquariusStormPiece#3")
                #endif
                let elapsed = timeline.date.timeIntervalSinceReferenceDate

                // **Every phase mounted at once, all but one at zero.**
                //
                // Swapping which reel is drawn changes the view's identity, and
                // SwiftUI answers that by cross-fading one image into another —
                // which is the dissolve between phases. Mounting them all and
                // moving opacity leaves the identities alone: nothing is built
                // or torn down when the meter moves, so what is seen is the
                // storm thickening rather than one picture becoming another.
                //
                // A hidden image is not rasterised, and the reels already exist
                // for whatever phases the run has passed through.
                filmed {
                    ZStack {
                        ForEach(1...10, id: \.self) { stage in
                            if let reel = film.reel(for: stage), !reel.isEmpty {
                                let step = Int(
                                    elapsed / GameRules.aquariusStormFilmPeriod
                                        * Double(reel.count)
                                ) % reel.count

                                reel[max(step, 0)]
                                    .resizable()
                                    .interpolation(.none)
                                    .antialiased(false)
                                    .frame(
                                        width: GameRules.aquariusStormCanvas,
                                        height: GameRules.aquariusStormCanvas
                                    )
                                    .opacity(stage == phase ? 1 : 0)
                                    // **Cut, never dissolve.**
                                    //
                                    // The ten reels are ten different pictures,
                                    // so animating between two of them can only
                                    // cross-fade — there is no in-between funnel
                                    // to show, and a dissolve of the whole storm
                                    // reads as the sprite glitching. The figure
                                    // inside looks smooth because it is driven by
                                    // a continuous number and genuinely has
                                    // in-between states.
                                    //
                                    // Adjacent phases differ by about one plate,
                                    // so a cut is a plate appearing — which is
                                    // what is actually happening.
                                    .transaction { $0.animation = nil }
                            }
                        }
                    }
                }
                .overlay { partingPlate(at: elapsed) }
                .compositingGroup()
                .scaleEffect(drawnScale)
                .frame(width: tileSize, height: tileSize * 2)
            }
            .onChange(of: phase) { was, now in
                guard was != now else { return }
                parting = (from: was, to: now, at: .now)
            }
        } else {
            // Built at the size it was tuned at, then scaled to the square.
            //
            // Every number inside is a fraction of `side` or a point offset
            // measured against the gallery's 300, so handing it a tile-derived
            // side re-proportions the whole assembly — the plates come out
            // tile-sized and the figure does not, which is why it read as one
            // blob rather than a stack. Build at 300, scale once, and the
            // arrangement is the arrangement that was settled.
            ZStack {
                AquariusStorm(phase: phase, side: 300, scale: 4)
                FloatingAquarius(
                    blend: .exclusion,
                    strength: Double(min(max(phase, 0), 10)) / 10
                )
            }
            .frame(
                width: GameRules.aquariusStormCanvas,
                height: GameRules.aquariusStormCanvas
            )
            // Flattened to one texture per frame.
            //
            // Thirteen plates, two eye plates, the silhouette and three glow
            // copies are twenty-odd separately blended layers, and every one of
            // them is composited on its own every frame. Grouping collapses the
            // lot into a single offscreen pass — the same fix the gem trail
            // needed, and the reason the doc note said to flatten once the look
            // was settled.
            //
            // Safe at 300 because that is the space the assembly was built in:
            // nothing in it reaches past that square, so there is nothing for
            // the group's bounds to cut off. Flattening *after* the scale would
            // clip it, which is the mistake the charge bloom made.
            .drawingGroup()
            .compositingGroup()
            .scaleEffect(drawnScale)
            // Laid out as a piece, not as the 300-point square it is built in.
            //
            // `scaleEffect` does not change layout, so without this the view
            // still *measures* 300 across — and anything upstream that sizes
            // itself to its content, or scales a row by what it is given, is
            // working from a box four times too big.
            .frame(width: tileSize, height: tileSize * 2)
                .onAppear {
                    // **At the size it lands on screen, not the size it is
                    // built in.**
                    //
                    // The canvas is 620 points of headroom that then gets
                    // scaled down to about three tiles. Filming it at the
                    // screen's own scale meant every frame was a 1860px square
                    // — 13MB each, 317MB for one phase's twenty-four — for
                    // something drawn a third of that across. The reel is
                    // pixel-exact at the scale it is displayed at, and every
                    // pixel past that is memory bandwidth spent on detail no
                    // screen can show.
                    film?.prepare(
                        phase,
                        side: GameRules.aquariusStormCanvas,
                        scale: UIScreen.main.scale * drawnScale
                    )
                    film?.forget(farFrom: phase)
                }
        }
    }
}
