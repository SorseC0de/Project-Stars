//
//  TrappedBubbleView.swift
//  Project Stars
//
//  A prize suspended in one of Cancer's bubbles.
//

import SwiftUI

/// Something caught in a bubble, floating over the square it was caught on.
///
/// Cancer fires these and they trap what they meet — a coin, or a glow sparkle
/// that may turn out to hold nothing. See the Cancer design note. The prize sits
/// *inside* the bubble rather than behind it, which is why the sprite has to be
/// bigger than a Pentacle and why the bubble's middle has to be see-through.
///
/// ## How the inside is made see-through
///
/// Not by fading the whole sprite, which would take the rim with it and leave a
/// ghost rather than a bubble. A soft hole is punched through the middle
/// instead: a circle filled with a radial gradient, composited with
/// `destinationOut`, so the rim stays fully solid and the centre thins out.
///
/// The reason to prefer this over recolouring the fill is that it is
/// **art-agnostic** — it needs to know nothing about which palette entries the
/// bubble is drawn in, so it keeps working if the sprite is ever redrawn.
///
/// ## What moves and what does not
///
/// The bubble turns and breathes; the prize inside only breathes. A prize that
/// rotated with its container would read as *tumbling*, where one that swells
/// and shrinks with the glass reads as being magnified by it, which is what
/// looking through a real bubble does.
struct TrappedBubbleView<Prize: View>: View {

    /// Size of a board cell, in points.
    let tileSize: CGFloat

    /// Points per art pixel.
    let scale: CGFloat

    /// The bubble itself. Defaulted to the Pentacle-sized one; Cancer's wants
    /// the **big** sprite, which has no atlas entry yet.
    var bubble: SpriteID = .pentacle(.bubble)

    /// Whatever is caught in it.
    @ViewBuilder var prize: () -> Prize

    /// Seconds, stopped whenever the game is.
    @Environment(\.ambientClock) private var ambientClock

    var body: some View {
        TimelineView(.animation) { timeline in
            let now = ambientClock(timeline.date.timeIntervalSinceReferenceDate)

            // Never touching the tile. The float runs between two heights
            // rather than around a midpoint, so the bubble is always clear of
            // the ground — a bubble that dips to zero has landed.
            let bob = Style.floatLow
                + (Style.floatHigh - Style.floatLow)
                * (sin(now / Style.floatPeriod * 2 * .pi) + 1) / 2

            let breath = 1 + Style.swell * CGFloat(sin(now / Style.swellPeriod * 2 * .pi))
            let turn = Style.turn * sin(now / Style.turnPeriod * 2 * .pi)

            ZStack {
                // On the ground, where the bubble is not.
                PieceShadowView(
                    tileSize: tileSize,
                    widthFraction: Style.shadowWidth,
                    opacity: Style.shadowOpacity
                )
                .offset(y: tileSize / 2 - GameRules.pieceShadowDrop * scale)

                ZStack {
                    // Magnified by the glass: the prize takes the swell and
                    // refuses the spin.
                    prize()
                        .frame(width: tileSize * Style.prizeSize,
                               height: tileSize * Style.prizeSize)

                    glass
                        .rotationEffect(.degrees(turn))
                }
                .scaleEffect(breath)
                .offset(y: -bob * scale)
            }
            .frame(width: tileSize, height: tileSize)
        }
        .allowsHitTesting(false)
    }

    /// The bubble, with its middle thinned out.
    private var glass: some View {
        PixelSprite(id: bubble) { Color.clear }
            .frame(width: tileSize, height: tileSize)
            .overlay {
                // Erases rather than covers. `destinationOut` takes the alpha of
                // this shape *out* of what is behind it, so the gradient's
                // opaque centre becomes the clearest part of the bubble and its
                // clear edge leaves the rim untouched.
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Palette.coolBlack.opacity(Style.clarity),
                                Palette.coolBlack.opacity(0),
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: tileSize * Style.windowSize / 2
                        )
                    )
                    .frame(width: tileSize * Style.windowSize,
                           height: tileSize * Style.windowSize)
                    .blendMode(.destinationOut)
            }
            // Without this the erase would punch through the board as well as
            // through the bubble.
            .compositingGroup()
    }

}

/// Tuning for `TrappedBubbleView`.
///
/// Outside the view rather than nested in it: a generic type cannot hold static
/// storage, and these are constants about bubbles rather than about any one
/// prize.
private enum Style {
    /// How far above the tile the bubble rides, in art pixels, low and high.
    static let floatLow: CGFloat = 2
    static let floatHigh: CGFloat = 4
    static let floatPeriod: TimeInterval = 2.6

    /// How much it breathes, and how fast. Small — a bubble that pulses
    /// hard reads as a heartbeat rather than as surface tension.
    static let swell: CGFloat = 0.05
    static let swellPeriod: TimeInterval = 1.7

    /// And how far it turns either way.
    static let turn: Double = 6
    static let turnPeriod: TimeInterval = 3.1

    /// How much of the bubble's width the see-through middle covers, and
    /// how clear it gets at the very centre.
    static let windowSize: CGFloat = 0.7
    static let clarity: Double = 0.8

    /// The prize sits well inside the glass.
    static let prizeSize: CGFloat = 0.55

    static let shadowWidth: CGFloat = 0.4
    static let shadowOpacity: Double = 0.3
}
