//
//  SmokeSpriteView.swift
//  Project Stars
//
//  The drawn smoke strip, played once.
//

import SwiftUI

/// A puff of drawn smoke, played through once and then gone.
///
/// ## Why this replaced the drawn-by-code version
///
/// `SmokeBurstView` scattered flat discs outward and faded them, and carried a
/// note saying it should become a sprite the moment real art arrived. It has.
/// The art is three tones of pixel smoke, which is a shape no amount of
/// expanding circles was going to reach.
///
/// The programmatic version stays in the project — it is still what draws when a
/// sheet is missing, and it is the only version that works at a size the strip
/// was not authored for.
///
/// ## Why it is recoloured rather than redrawn per plane
///
/// One strip, swapped into whatever the situation calls for. Astra's cloud comes
/// apart in the violets it is made of; the same three tones sent somewhere else
/// would be the same smoke wearing that place's colours. Drawing a second strip
/// per destination would be paying in art for something the palette already
/// does — see `PaletteSwap`.
struct SmokeSpriteView: View {

    /// Which plane's strip to play.
    let plane: Plane

    /// Size of a board cell, in points.
    let tileSize: CGFloat

    /// When the puff began.
    let start: Date

    /// Size multiplier. `1` for an ordinary hop; a fall lands far harder.
    var magnitude: CGFloat = 1

    /// Recolouring applied to the strip's three tones, if any.
    var swaps: [PaletteSwap] = []

    /// A wholesale colour for the puff, overriding the swaps.
    ///
    /// Blunter than a palette swap and meant to be: this is smoke that is
    /// saying something rather than smoke that belongs to a place.
    var tint: Color?

    /// True when the strip is present for this plane.
    static func hasArt(on plane: Plane) -> Bool {
        SpriteSheetLoader.hasArt(for: .smoke(plane))
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            let elapsed = timeline.date.timeIntervalSince(start)
            let frame = Int(elapsed / GameRules.smokeRate.frameDuration)

            // Past its last frame it draws nothing rather than holding the final
            // one: smoke that stopped dispersing and stayed would read as a bug.
            if elapsed >= 0, frame < GameRules.smokeFrameCount {
                recoloured(
                    PixelSprite(id: .smoke(plane), frame: frame) { EmptyView() }
                        .frame(width: side, height: side)
                )
            }
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func recoloured(_ art: some View) -> some View {
        if let tint {
            // Lifted before it is multiplied.
            //
            // `colorMultiply` can only ever *darken* — grey art times a green
            // is a dark green however bright the green is, which is why picking
            // a lighter one never helped and the puff kept reading as poison.
            // Raising the art toward white first means the multiply lands near
            // the colour asked for instead of somewhere under it.
            art.brightness(GameRules.smokeTintLift).colorMultiply(tint)
        } else if swaps.isEmpty {
            art
        } else {
            art.paletteSwap(swaps)
        }
    }

    /// The strip is two cells square.
    private var side: CGFloat {
        tileSize * 2 * magnitude
    }
}

// MARK: - Recolourings

extension SmokeSpriteView {

    /// The strip's own three tones, lightest first.
    ///
    /// Read off the art rather than guessed: `spr_darksmoke.png` is exactly
    /// these three and nothing else, which is what makes a clean swap possible.
    static let sourceTones: [Color] = [
        Color(hex: 0xC0CBDC),
        Color(hex: 0x8B9BB4),
        Color(hex: 0x5A6988),
    ]

    /// Cloudstuff coming apart: the violets Astra is drawn in.
    ///
    /// Lightest to darkest against lightest to darkest, so the smoke keeps its
    /// own internal shading and only changes hue. Swapping them out of order
    /// turns a rounded puff inside out.
    static let cloudSwaps: [PaletteSwap] = zip(
        sourceTones,
        [Palette.pink, Palette.magenta, Palette.purple]
    ).map(PaletteSwap.init)

    /// The *lifted* cloud coming apart: the blues it was recoloured into.
    ///
    /// A raised square is blue while it is up — see
    /// `CloudSpriteView.raisedSwaps` — so the smoke it makes on the way down has
    /// to be blue as well. Magenta smoke off a blue cloud reads as two different
    /// squares, one of them somewhere behind the other.
    static let raisedCloudSwaps: [PaletteSwap] = zip(
        sourceTones,
        [Palette.cyan, Palette.sky, Palette.blue]
    ).map(PaletteSwap.init)
}
