//
//  PolarisBadgeView.swift
//  Project Stars
//
//  The fragment of Old Astra you are carrying, in the HUD.
//

import SwiftUI

/// Polaris, shown beside the plane's name while it is being carried.
///
/// ## Why it is outlined rather than plated
///
/// The plane badge sits on a filled capsule because it is text and text needs a
/// ground to be legible against. This is a sprite, and a sprite on a plate reads
/// as an icon in a slot — a piece of interface — where the thing itself reads as
/// an object you are holding. A one-pixel white ring gives it the separation the
/// plate was providing, over cloud and over stone alike, without the box.
///
/// See `View.pixelOutline(_:scale:)`.
struct PolarisBadgeView: View {

    /// The fragment, or `nil` when none is carried.
    let polaris: SignState.Polaris?

    /// Points per art pixel, so the ring is exactly one pixel thick.
    let scale: CGFloat

    /// When the fragment lit, for the burst. Nil until it does.
    @State private var litAt: Date?

    var body: some View {
        if let polaris {
            PixelSprite(
                id: .pentacle(polaris == .charged ? .radiant : .dormant)
            ) { Color.clear }
                .frame(width: Style.size, height: Style.size)
                .pixelOutline(scale: scale)
                // Dimmed while it is a rock. Still worth showing — half the
                // interest of finding one below is knowing you are carrying
                // something you cannot use yet — but it must not read as ready.
                .opacity(polaris == .charged ? 1 : Style.dormantOpacity)
                .animation(.easeOut(duration: 0.25), value: polaris)
                // The moment it wakes, and only that moment.
                //
                // Charging happens somewhere else entirely — a Zodiaction fired
                // across the board, a coin opened, a plane arrived at — so
                // without a mark here the player has no reason to look at the
                // corner where the thing they are carrying just became usable.
                .overlay {
                    if let litAt {
                        PolarisChargeBurst(start: litAt, size: Style.size)
                    }
                }
                .onChange(of: polaris) { _, now in
                    litAt = now == .charged ? .now : nil
                }
                .accessibilityLabel(
                    Text(polaris == .charged ? "Polaris, charged" : "Polaris, dormant")
                )
        }
    }

    private enum Style {
        /// Matched to the plane badge's own height — twelve-point text with five
        /// points of padding above and below — so the two sit as a pair rather
        /// than as a big thing next to a small one.
        static let size: CGFloat = 22
        static let dormantOpacity: Double = 0.55
    }
}

/// The one-shot flash when a dormant fragment takes charge.
///
/// ## Why it is drawn rather than sprited
///
/// Because it is over in half a second and never seen twice in a run. A strip
/// would be four cells of art for one moment; a dozen shards thrown outward on
/// a curve costs nothing and can take Polaris' own five colours straight from
/// the sprite it is bursting out of.
///
/// The colours are sampled from the art — `#64468D`, `#AE57A4`, `#EA71BD`,
/// `#42CAFD`, `#FFCE00` — rather than chosen, so the burst is made of the same
/// palette entries as the thing that made it.
private struct PolarisChargeBurst: View {

    let start: Date
    let size: CGFloat

    var body: some View {
        TimelineView(.animation) { timeline in
            let elapsed = timeline.date.timeIntervalSince(start)
            let progress = min(max(elapsed / Style.duration, 0), 1)

            if progress < 1 {
                Canvas { context, canvas in
                    let centre = CGPoint(x: canvas.width / 2, y: canvas.height / 2)

                    for index in 0..<Style.shards {
                        let angle = Double(index) / Double(Style.shards) * 2 * .pi
                        // Eased out, so they leave fast and drift to a stop —
                        // an explosion decelerating is the whole read.
                        let travel = (1 - pow(1 - progress, 3)) * Style.reach * size
                        let fade = 1 - progress

                        let point = CGPoint(
                            x: centre.x + cos(angle) * travel,
                            y: centre.y + sin(angle) * travel
                        )
                        let side = Style.shardSize * size * fade

                        context.fill(
                            Path(ellipseIn: CGRect(
                                x: point.x - side / 2, y: point.y - side / 2,
                                width: side, height: side
                            )),
                            with: .color(Style.colours[index % Style.colours.count]
                                .opacity(fade))
                        )
                    }
                }
                .blendMode(.plusLighter)
                .allowsHitTesting(false)
            }
        }
    }

    private enum Style {
        static let duration: TimeInterval = 0.55
        static let shards = 12

        /// How far a shard travels, as a multiple of the badge.
        static let reach: CGFloat = 1.1
        static let shardSize: CGFloat = 0.22

        /// Polaris' own five, in the order they ring outward.
        static let colours: [Color] = [
            Palette.yellow, Palette.sky, Palette.pink,
            Palette.magenta, Palette.purple,
        ]
    }
}
