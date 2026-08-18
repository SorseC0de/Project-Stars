//
//  StormCloudView.swift
//  Project Stars
//
//  A Pentacle Aquarius' storm left behind, drawn as a cloud rather than a coin.
//

import SwiftUI

/// One of the Wipeout's storm clouds: a scrap of cloudstuff holding a rolled
/// effect, hanging wherever the squall put it.
///
/// ## Why it is a cloud and not a coin
///
/// Because it is not one of the hunt's Pentacles and must not be read as one.
/// The sparkle phase does not wait on these, they can be taken in any order and
/// at any time, and they hang over holes — a coin that behaved that way while
/// looking like every other coin would teach the player the wrong rule four
/// times a run.
///
/// ## The same sprite as the ground, recoloured
///
/// It is `SpriteID.astraCloud` — the art Astra's own squares are drawn from —
/// through a palette swap, which is what makes it read as *a piece of this
/// plane* rather than as a new object that happens to be cloud-shaped. Drawn at
/// one tile rather than the sheet's three, so it is a scrap rather than a
/// square.
///
/// The sprite's light row is authored outline → shadow → highlight as
/// `darkMagenta → magenta → pink` (see `GameRules.cloudWearSwaps`), and those
/// three are what the storm's colours replace.
struct StormCloudView: View {

    /// Rendered edge length in points.
    let size: CGFloat

    /// The board's clock, so a squall holds still with everything else while
    /// the game waits on the player.
    var clock: (TimeInterval) -> TimeInterval = { $0 }

    /// Whole-pixel scale, for art-pixel distances.
    private var scale: CGFloat { size / CGFloat(GameRules.tilePixelSize) }

    var body: some View {
        cloud
            // **Purple over the top, added.**
            //
            // A flat colour in `plusLighter` rather than a blurred copy of the
            // cloud: a copy carries the gold with it, and gold smeared into
            // purple additively comes out brown. One colour laid over the whole
            // shape lifts the dark body toward violet and leaves the gold as
            // the one warm thing in it.
            //
            // Masked to the sprite so the light stops at its edge — these hang
            // over open holes, and colour outside the shape would read as the
            // hole glowing.
            .overlay {
                GameRules.stormCloudGlowTint
                    .mask { cloud }
                    .opacity(GameRules.stormCloudGlow)
                    // **Outermost, and that is the whole of it.**
                    //
                    // A blend mode composites a view against what is *beneath*
                    // it, so it has to be the last thing applied. Written
                    // inside the mask it was blending against the mask's own
                    // layer instead of against the cloud, which is a flat
                    // purple sheet laid on top — exactly what it looked like.
                    .blendMode(.plusLighter)
            }
            .frame(width: size, height: size)
            // The sheet's cloud does not sit in the middle of its own cell — it
            // is drawn low, so that a 48px cloud hangs off the bottom of the
            // 16px square it belongs to. Scaled down to one tile that offset
            // comes with it, and the scrap sits below the square it is on.
            .offset(y: -GameRules.stormCloudLift * scale)
            .allowsHitTesting(false)
    }

    private var cloud: some View {
        PixelSprite(id: .astraCloud(.light)) { EmptyView() }
            .paletteSwap(GameRules.stormCloudSwaps)
            .frame(width: size, height: size)
    }
}
