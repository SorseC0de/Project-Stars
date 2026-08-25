//
//  AfterimageView.swift
//  Project Stars
//
//  The colours a piece leaves behind it.
//

import SwiftUI

/// One afterimage of the piece, in an element's colours.
///
/// Two states leave a trail, and they say different things with it:
///
/// - **A full meter** trails the sign's own element. The piece itself stays gold
///   — this is what carries the state, streaming off it.
/// - **The star** cycles all four, and each copy wears the colour from when it
///   was there: copy `step` takes the element `step` places back in the cycle,
///   which makes the trail a readable record of the last half second rather than
///   a smear of one hue.
///
/// ## Why it remembers rather than lags
///
/// The first version placed every copy at the piece's *current* square under its
/// own slower spring. That is a smear, not an afterimage: the ghosts are always
/// somewhere between two squares, sliding continuously, and they read as one
/// blurred object being dragged.
///
/// An afterimage is a snapshot. Each copy is pinned to a square the piece
/// **actually stood on** and does not move at all — it appears where the piece
/// was, holds, and fades. The result is deliberately choppy, one ghost per
/// square, which is what makes it read as a trail of images rather than motion
/// blur.
struct AfterimageView: View {

    let zodiac: Zodiac

    /// How much storm Aquarius was wearing, `0` for everyone else.
    var stormPhase: Int = 0

    /// Which plane the figure was on, since that decides what it is made of.
    var plane: Plane = .astra

    /// Whether it was lit, since several signs are assembled differently when
    /// they are.
    var isCharged = false

    /// The element this copy wears.
    let element: ZodiacElement

    /// Size of a board cell, in points.
    let tileSize: CGFloat

    /// Whole-pixel scale, for art-pixel offsets.
    let scale: CGFloat

    /// How far back in the trail this copy is. `0` is the square just left.
    /// Which way the figure is looking.
    ///
    /// Passed rather than defaulted: `PieceView` starts at `.up`, so every
    /// ghost of every sign was the north drawing regardless of which way the
    /// piece it is a record of was facing.
    var facing: SwipeDirection = .down

    let step: Int

    /// How far through its life this ghost is, `0` fresh to `1` gone.
    let age: Double

    var body: some View {
        #if DEBUG
        // Counted because a trail is three more of the most complicated view in
        // the game, drawn only while something is moving — which is the one
        // time there is no frame to spare for it.
        let _ = RenderTally.tick("ghost")
        #endif
        // **The assembled figure**, not a bare sprite.
        //
        // A ghost is a picture of what was standing there, and what is standing
        // there is rarely just `piece(zodiac)`: Pisces has a fish riding on him,
        // Virgo has gems, the archer has an arrow, Libra has arms and scales,
        // Aquarius is a storm. Drawing the base sprite meant every one of those
        // trailed a figure that does not exist — and it had to be patched sign
        // by sign as each one grew a part, which is a list that only gets
        // longer.
        //
        // Asking `PieceView` costs a rebuild of the assembly per ghost and is
        // the only version that cannot fall behind: a sign that gains a part
        // tomorrow gets correct afterimages for free.
        PieceView(
            zodiac: zodiac,
            tileSize: tileSize,
            scale: scale,
            plane: plane,
            isCharged: isCharged,
            // A ghost is not a source of light — see `PieceView.emitsLight`.
            emitsLight: false,
            // Nor a thing standing on the square.
            showsShadow: false,
            facing: facing,
            stormPhase: stormPhase
        )
        .frame(width: tileSize, height: tileSize * 2)
            .paletteSwap(
                zip(Palette.pieceGoldTones, Palette.trailTones(for: element))
                    .map(PaletteSwap.init)
            )
            // Fades on its own clock as well as by distance, so a ghost never
            // outlives the moment it is a record of.
            .opacity(pow(GameRules.afterimageFalloff, Double(step + 1)) * (1 - age))
            // Matches `PieceView`'s figure box, so the ghost sits where the
            // piece was rather than near it.
            .offset(y: -tileSize / 2 - GameRules.pieceLift * scale)
            .allowsHitTesting(false)
    }
}
