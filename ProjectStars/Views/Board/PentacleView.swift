//
//  PentacleView.swift
//  Project Stars
//
//  The gold coin a pickup appears as on the board.
//

import SwiftUI

/// A **Pentacle**: the gold coin that every pickup appears as.
///
/// Identical for every common, uncommon and rare effect. The coin is a loot box:
/// the player learns what is inside by opening it, never by looking at it, which
/// is what makes committing to a move to reach one a real decision. The two
/// legendaries break that on purpose and carry their own `PentacleAppearance`.
///
/// ## Why it is three tiles wide
///
/// The coin itself is one cell, but its sparkle spills a full cell in every
/// direction, so the art is 48x48 with the coin in the middle. Drawing it at one
/// tile would crop the sparkle off; drawing it at three and centring on the tile
/// puts the coin exactly where it belongs and lets the sparkle overhang.
///
/// Contrast `PentacleIntroView`, which *does* show the effect's own glyph,
/// because by then the coin is open.
struct PentacleView: View {

    /// How this coin looks.
    var appearance: PentacleAppearance = .standard

    /// Size of a board cell, in points. The view draws itself larger than this.
    let size: CGFloat

    /// Whole-pixel scale, for art-pixel offsets.
    var scale: CGFloat = 1

    /// The ambient clock, which stops while the game waits on the player. See
    /// `GameSession.ambientClock(at:)`.
    var clock: (TimeInterval) -> TimeInterval = { $0 }

    /// Shifts this coin's whole cycle, in seconds.
    ///
    /// One coin on the board never needs it. Several do: Pisces' bubbles all
    /// ride the same clock, so without a shift they rise and fall in unison and
    /// read as one object with several parts rather than as a scatter. Applied
    /// to the phase itself, so the bob, the orbit and the pool of light stay in
    /// step with each other while drifting against the next bubble's.
    var phaseOffset: TimeInterval = 0

    /// Recolouring applied to the coin, if any. See `ringSwaps`.
    var swaps: [PaletteSwap] = []

    /// True for a coin that is not a coin: cold Polaris on Terra, which sits on
    /// the ground in the middle of its tile and does nothing at all.
    ///
    /// Everything the hover is made of says *this is a prize*: the bob, the
    /// orbit, the pool of light beneath it, the lift off the tile. A dormant
    /// fragment is a rock, and a rock that bobs is a rock nobody believes is
    /// dormant — so it declines all of it rather than doing a quieter version.
    private var isInert: Bool { appearance == .dormant }

    var body: some View {
        if isInert {
            ZStack {
                // An ordinary occluding shadow, not the additive pool the lit
                // coins throw. It is a rock lying on a tile, and it should sit
                // on that tile the way anything else resting on the ground does.
                PieceShadowView(
                    tileSize: size,
                    widthFraction: 0.34,
                    opacity: GameRules.pentacleShadowOpacity
                )
                .offset(y: GameRules.pentacleShadowDrop * scale)

                coin(phase: 0)
            }
            .transition(.scale(scale: 0.2).combined(with: .opacity))
            .allowsHitTesting(false)
        } else {
            hovering
        }
    }

    private var hovering: some View {
        TimelineView(.animation) { timeline in
            // One phase drives everything, so the coin, its orbit and its pool
            // of light can never drift out of step with each other.
            let phase = clock(timeline.date.timeIntervalSinceReferenceDate) + phaseOffset
            let rise = riseFraction(at: phase)
            let orbit = orbitOffset(at: phase)

            ZStack {
                // The shadow stays put on the tile while the coin drifts above
                // it — that separation is what sells the hover.
                // Not a shadow so much as a pool of light: the coin glows, so
                // what lands on the tile beneath it is additive white rather
                // than an occluding dark ellipse.
                PieceShadowView(
                    tileSize: size,
                    widthFraction: 0.34,
                    opacity: GameRules.pentacleShadowOpacity,
                    color: poolColor,
                    blendMode: .plusLighter
                )
                // Shrinks as the coin rises and swells as it dips — a pool of
                // light narrows the further its source gets from the ground, and
                // that change in size reads as height far more strongly than the
                // coin's own drift does.
                .scaleEffect(1 - GameRules.pentacleShadowScaleSwing * rise)
                .offset(
                    x: orbit.width,
                    y: orbit.height + GameRules.pentacleShadowDrop * scale
                )

                if appearance == .radiant {
                    PolarisSparksView(size: size, scale: scale, phase: phase, layer: .behind)
                        .offset(x: orbit.width, y: float(at: timeline.date) - GameRules.pentacleLift * scale)
                }

                coin(phase: phase)
                    // And shrinks as it goes, by the same reasoning the pool
                    // grows: at the top of the bob it is further away.
                    .scaleEffect(1 - GameRules.pentacleRiseScaleSwing * rise)
                    // Floats clear of its own glow, then drifts — the gap
                    // between coin and pool is what sells the hover.
                    .offset(
                        x: orbit.width,
                        y: float(at: timeline.date) - GameRules.pentacleLift * scale
                    )

                if appearance == .radiant {
                    PolarisSparksView(size: size, scale: scale, phase: phase, layer: .inFront)
                        .offset(x: orbit.width, y: float(at: timeline.date) - GameRules.pentacleLift * scale)
                }

            }
        }
        .transition(.scale(scale: 0.2).combined(with: .opacity))
        .allowsHitTesting(false)
    }

    /// Where the coin is in its bob, `0` at the bottom and `1` at the top.
    ///
    /// The shadow reads this rather than the raw offset so its response stays
    /// correct if the float is ever re-shaped.
    private func riseFraction(at phase: TimeInterval) -> CGFloat {
        let turns = phase / GameRules.pentacleFloatPeriod
        return CGFloat(sin(turns * 2 * .pi) + 1) / 2
    }

    /// The coin's position around its orbit of the tile centre.
    ///
    /// Flattened vertically: a circle drawn in perspective on the ground is an
    /// ellipse, and a coin circling level would otherwise look like it was
    /// bobbing twice.
    private func orbitOffset(at phase: TimeInterval) -> CGSize {
        let turns = phase / GameRules.pentacleOrbitPeriod * 2 * .pi
        let radius = GameRules.pentacleOrbitRadius * scale
        return CGSize(
            width: CGFloat(cos(turns)) * radius,
            height: CGFloat(sin(turns)) * radius * 0.4
        )
    }

    /// What the coin spills onto the tile beneath it.
    ///
    /// Shadow Work pools `midnight` rather than white — it is the one coin whose
    /// light is an absence.
    private var poolColor: Color {
        switch appearance {
        case .standard, .still: Palette.white
        case .shadow: Palette.midnight
        case .radiant: Palette.sky
        // Its light is the sky it belongs to: Libra is air, and the hammer is a
        // storm front rather than a coin.
        case .gavel: Palette.cyan
        case .droplet, .bubble: Palette.cyan
        // A rock casts a shadow, not a pool of light — see `isInert`.
        case .dormant: Palette.coolBlack
        }
    }

    // MARK: - The coin itself

    /// The sprite, recoloured and lit according to which coin this is.
    @ViewBuilder
    private func coin(phase: TimeInterval) -> some View {
        switch appearance {
        case .standard:
            PaletteGlow(radius: GameRules.pentacleGlowRadius * scale,
                        intensity: GameRules.pentacleGlowIntensity) {
                sprite
            }

        // No bloom and no spin. It is a tally mark, not a coin on the floor.
        case .still:
            sprite

        case .shadow:
            // The same sheet as the gold coin, five entries swapped. No bloom:
            // a shadow that glowed would not be one.
            sprite.paletteSwap(shadowSwaps)

        case .radiant:
            // Polaris turns as well as drifting, and turns the other way — the
            // orbit is clockwise, so a counter-clockwise spin keeps the two
            // motions from reading as one.
            PaletteGlow(radius: GameRules.pentacleGlowRadius * scale,
                        intensity: GameRules.polarisGlowIntensity) {
                sprite
            }
            .rotationEffect(.degrees(spin(at: phase)))

        case .dormant:
            // No bloom, no spin, no swap. It is the sprite and nothing else,
            // which is the entire characterisation: everything the other coins
            // do to announce themselves, this one declines.
            sprite

        case .gavel:
            // Lit hard, and swung. See `gavelSwing(at:)`.
            PaletteGlow(radius: GameRules.pentacleGlowRadius * scale,
                        intensity: GameRules.gavelGlowIntensity) {
                gavelSprite(at: phase)
            }

        case .droplet, .bubble:
            // Drawn rather than sprited, and drawn as *not a coin*: the whole
            // point of a boon is that it is not part of the hunt, and a player
            // who has to look twice to tell it from a Pentacle has been misled
            // about what is on the board.
            //
            // A bubble is the same bead, hollow and paler — it is the same
            // substance as a droplet and worth a fraction as much, and reading
            // as *less water* is exactly right.
            droplet
        }
    }

    /// A bead of water: a teardrop of colour with a highlight on its shoulder.
    ///
    /// A bubble borrows it at a paler tone and hollowed out — the same substance
    /// as a droplet and worth a fraction as much, so reading as *less water* is
    /// exactly right.
    private var droplet: some View {
        ZStack {
            // The outer fill only. The highlight, the glint and the bloom
            // behind it are all left alone — the stack is what makes the thing
            // read as water, and the shape is the one part of it that was
            // saying "ball" instead of "drop".
            Droplet()
                .fill(appearance == .bubble ? Palette.sky.opacity(0.5) : Palette.blue)
                .frame(
                    width: size * 0.44,
                    height: size * 0.44 * (1 + GameRules.dropletPull)
                )
                // The extra height is all above the ball, so without this the
                // whole thing sits low by half of it and the highlight drifts
                // off centre.
                .offset(y: -size * 0.44 * GameRules.dropletPull / 2)

            Circle()
                .fill(Palette.sky)
                .frame(width: size * 0.30, height: size * 0.30)
                .offset(y: size * 0.02)

            Circle()
                .fill(Palette.ice)
                .frame(width: size * 0.10, height: size * 0.10)
                .offset(x: -size * 0.07, y: -size * 0.09)
        }
        // The same additive bloom the coins carry, so it sits in the same light
        // as everything else hovering over the board.
        .background {
            Circle()
                .fill(Palette.cyan)
                .frame(width: size * 0.5, height: size * 0.5)
                .blur(radius: GameRules.pentacleGlowRadius * scale)
                .blendMode(.plusLighter)
        }
    }

    /// The gavel, mid-swing.
    ///
    /// ## Why it is animated here rather than drawn
    ///
    /// It is one frame of art. A hammer that never moves is a hammer nobody
    /// reads as a hammer — it looks like a shape — and the motion is cheap to
    /// describe and expensive to draw: rotation, scale and a squash, all pure
    /// functions of the clock, which is how every other effect in this game
    /// works anyway.
    ///
    /// ## The swing
    ///
    /// Held still for most of the loop, then wound back anticlockwise and
    /// slightly smaller, then brought round fast and clockwise, overshooting
    /// past the rest angle and flattening on the way through — the pancake is
    /// what sells an impact when there is nothing to hit. It hangs at the bottom
    /// for a beat, because a swing that rebounds immediately reads as a bounce
    /// rather than a blow, and then eases back.
    ///
    /// The long still stretch is deliberate: this thing sits on the board
    /// waiting to be picked up, and something swinging without pause is
    /// wallpaper.
    private func gavelSprite(at now: TimeInterval) -> some View {
        let swing = gavelSwing(at: now)

        return PixelSprite(id: .gavel) { placeholder }
            .frame(width: size * spriteSpan, height: size * spriteSpan)
            // Its own shadow, in the deepest tone it is drawn in. The coins get
            // a pool of light because they glow; a hammer is a solid object and
            // wants weight under it instead.
            .shadow(
                color: Palette.darkMagenta.opacity(GameRules.gavelShadowOpacity),
                radius: GameRules.gavelShadowRadius * scale,
                y: GameRules.gavelShadowDrop * scale
            )
            .scaleEffect(x: swing.scale * swing.squash, y: swing.scale / swing.squash)
            .rotationEffect(.degrees(swing.angle), anchor: .bottom)
    }

    /// Where the swing is, as angle, scale and squash.
    private func gavelSwing(at now: TimeInterval) -> (angle: Double, scale: CGFloat, squash: CGFloat) {
        let period = GameRules.gavelSwingPeriod
        let phase = (now.truncatingRemainder(dividingBy: period) + period)
            .truncatingRemainder(dividingBy: period) / period

        let rest = GameRules.gavelRestFraction        // sitting still
        let cock = GameRules.gavelCockFraction        // winding back
        let strike = GameRules.gavelStrikeFraction    // coming round
        let hang = GameRules.gavelHangFraction        // held at the bottom

        func ease(_ x: Double) -> Double { x * x * (3 - 2 * x) }

        if phase < rest {
            return (0, 1, 1)
        }

        if phase < rest + cock {
            let k = ease((phase - rest) / cock)
            return (
                -GameRules.gavelCockAngle * k,
                1 - (1 - GameRules.gavelCockScale) * CGFloat(k),
                1
            )
        }

        if phase < rest + cock + strike {
            // Not eased: the strike is the one part that should feel like it got
            // away from you.
            let k = (phase - rest - cock) / strike
            let angle = -GameRules.gavelCockAngle
                + (GameRules.gavelCockAngle + GameRules.gavelOvershoot) * k
            return (
                angle,
                GameRules.gavelCockScale
                    + (GameRules.gavelStrikeScale - GameRules.gavelCockScale) * CGFloat(k),
                1 + (GameRules.gavelPancake - 1) * CGFloat(k)
            )
        }

        if phase < rest + cock + strike + hang {
            return (GameRules.gavelOvershoot, GameRules.gavelStrikeScale, GameRules.gavelPancake)
        }

        let k = ease((phase - rest - cock - strike - hang)
            / max(1 - rest - cock - strike - hang, 0.001))
        return (
            GameRules.gavelOvershoot * (1 - k),
            GameRules.gavelStrikeScale + (1 - GameRules.gavelStrikeScale) * CGFloat(k),
            GameRules.gavelPancake + (1 - GameRules.gavelPancake) * CGFloat(k)
        )
    }

    private var sprite: some View {
        let art = PixelSprite(id: .pentacle(appearance)) {
            placeholder
        }
        .frame(width: size * spriteSpan, height: size * spriteSpan)

        return Group {
            if swaps.isEmpty { art } else { art.paletteSwap(swaps) }
        }
    }

    /// The colours a coin dealt by Virgo's ring wears.
    ///
    /// Pink for the gold, and the white highlight to yellow-green. The ring's
    /// sparkles are already pink; matching the coin to them is what makes the
    /// promise legible without a word of UI — and the highlight has to move too,
    /// or the coin reads as an ordinary Pentacle somebody spilled paint on.
    static let ringSwaps: [PaletteSwap] = [
        PaletteSwap(Palette.white, Palette.yellowGreen),
        PaletteSwap(Palette.yellowGreen, Palette.sakura),
        PaletteSwap(Palette.yellow, Palette.pink),
        PaletteSwap(Palette.gold, Palette.magenta),
        PaletteSwap(Palette.orange, Palette.darkMagenta),
    ]

    /// How many cells the sprite covers.
    ///
    /// The gold and shadow coins carry their own sparkle and need three; Polaris
    /// is a single star and supplies its motion from the view instead.
    private var spriteSpan: CGFloat {
        switch appearance {
        // Authored 48 across — three cells — like the coins.
        case .standard, .shadow, .gavel: GameRules.pentacleCellSpan
        case .radiant, .dormant, .droplet, .bubble, .still: 1
        }
    }

    /// The gold coin's entries paired with Shadow Work's, in order.
    private var shadowSwaps: [PaletteSwap] {
        zip(Palette.pentacleTones, Palette.pentacleShadowTones).map(PaletteSwap.init)
    }

    /// Polaris' rotation. The period is negative, which is what turns it
    /// counter-clockwise.
    private func spin(at phase: TimeInterval) -> Double {
        phase / GameRules.polarisSpinPeriod * 360
    }

    private func float(at date: Date) -> CGFloat {
        let phase = clock(date.timeIntervalSinceReferenceDate) / GameRules.pentacleFloatPeriod
        return CGFloat(sin(phase * 2 * .pi)) * GameRules.pentacleFloatAmplitude * scale
    }

    // MARK: - Placeholder art

    /// Drawn only while the sprite is missing. Sized to the middle cell, since
    /// the placeholder has no sparkle to spill.
    private var placeholder: some View {
        ZStack {
            Circle().fill(faceColor)
            Circle().strokeBorder(edgeColor, lineWidth: max(1, size * 0.06))
            Image(systemName: "star.fill")
                .font(.system(size: size * 0.4))
                .foregroundStyle(edgeColor)
        }
        .frame(width: size, height: size)
    }

    private var faceColor: Color {
        switch appearance {
        case .standard, .still: Palette.pentacle
        case .shadow: Palette.pentacleShadow
        case .radiant: Palette.pentacleRadiant
        // The fallback face, for a build with no sprite sheet. Stone, because
        // that is what a cold fragment reads as.
        case .dormant: Palette.stone
        case .droplet, .gavel: Palette.sky
        case .bubble: Palette.cyan
        }
    }

    private var edgeColor: Color {
        switch appearance {
        case .standard, .still: Palette.pentacleEdge
        case .shadow: Palette.pentacleShadowEdge
        case .radiant: Palette.sky
        case .dormant: Palette.iron
        case .droplet, .gavel: Palette.cyan
        case .bubble: Palette.sky
        }
    }
}

/// A ball with its top drawn up into a point.
///
/// The bottom is a true circle, so anything sitting inside it — the highlight,
/// the glint — lands where it did when this was a `Circle`. Only the top half
/// is redrawn, as two curves meeting at an apex above the ball.
///
/// A shape rather than a stretched circle because a drop is not an ellipse: the
/// widest part stays low and the taper is all in the last third, which is what
/// separates *falling water* from *an egg*.
struct Droplet: Shape {

    func path(in rect: CGRect) -> Path {
        let radius = rect.width / 2
        let centre = CGPoint(x: rect.midX, y: rect.maxY - radius)
        let apex = CGPoint(x: rect.midX, y: rect.minY)

        var path = Path()
        path.move(to: apex)

        // Down the right side into the ball, and back up the left. The control
        // points sit low and close to the centre line, which keeps the curve
        // hugging the ball until it turns — a control point further out gives a
        // teardrop that bulges at the shoulders.
        path.addQuadCurve(
            to: CGPoint(x: centre.x + radius, y: centre.y),
            control: CGPoint(x: centre.x + radius * 0.6, y: centre.y - radius * 0.75)
        )
        path.addArc(
            center: centre,
            radius: radius,
            startAngle: .degrees(0),
            endAngle: .degrees(180),
            clockwise: false
        )
        path.addQuadCurve(
            to: apex,
            control: CGPoint(x: centre.x - radius * 0.6, y: centre.y - radius * 0.75)
        )

        path.closeSubpath()
        return path
    }
}
