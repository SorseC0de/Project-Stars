//
//  StormCloudView.swift
//  Project Stars
//
//  A Pentacle Aquarius' storm left behind, drawn as a cloud rather than a coin.
//

import SwiftUI

/// One of the Wipeout's storm clouds: a square of cloudstuff holding a rolled
/// effect, hanging wherever the squall put it.
///
/// ## Why it is a cloud and not a coin
///
/// Because it is not one of the hunt's Pentacles and must not be read as one.
/// The sparkle phase does not wait on these, they can be taken in any order and
/// at any time, and they hang over holes — a coin that behaved that way while
/// looking like every other coin would be teaching the player the wrong rule
/// four times a run.
///
/// It is made from `CloudTileView`, which is the material Astra is built out
/// of, so it inherits the cluster generation, the wear shapes and the glints
/// without any of it being written twice. Only the palette changes.
struct StormCloudView: View {

    /// Which square this is, so the cluster is its own and stays put.
    let point: GridPoint

    /// Rendered edge length in points.
    let size: CGFloat

    /// Whole-pixel scale, for art-pixel distances.
    private var scale: CGFloat { size / CGFloat(GameRules.tilePixelSize) }

    var body: some View {
        cloud
            // **Lit from inside.** A blurred copy of itself, masked back to its
            // own silhouette, so the light stays within the cloud rather than
            // haloing it — these hang over open holes, and a bloom around one
            // would read as the hole glowing.
            .overlay {
                cloud
                    .blur(radius: GameRules.stormCloudGlowRadius * scale)
                    .blendMode(.plusLighter)
                    .opacity(GameRules.stormCloudGlow)
                    .mask { cloud }
            }
            .frame(width: size, height: size)
            .allowsHitTesting(false)
    }

    private var cloud: some View {
        CloudTileView(
            health: .healthy,
            shade: .light,
            point: point,
            size: size,
            toneOverride: GameRules.stormCloudTones
        )
    }
}
