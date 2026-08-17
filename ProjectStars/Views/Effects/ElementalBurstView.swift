//
//  ElementalBurstView.swift
//  Project Stars
//
//  The Metal burst played when an elemental effect resolves.
//

import SwiftUI

/// Plays one elemental burst over the board.
///
/// A thin wrapper over the `elementalBurst` shader in `Elemental.metal`. The
/// shader owns everything about how each element looks; this owns only *where*
/// and *for how long*, so retuning the visuals never means touching Swift.
///
/// The four Astral Essences drive it today, but nothing here is Pentacle-specific
/// — a Zodiaction or a passive can play one by asking `GameSession` for it. That
/// is why the burst is keyed on `ZodiacElement` rather than on `PickupID`.
/// Which picture the burst draws.
///
/// The four elements, plus the ones that are a *shape* rather than an element.
/// Leo's magnetic pulse is water's ripples in red: it belongs to no element, and
/// forcing it to borrow one would have meant either a burning ring or a wet
/// lion, both of which say something the effect does not mean.
enum BurstKind: Equatable {
    case element(ZodiacElement)
    case magneticPulse

    /// The branch this takes inside `elementalBurst`.
    var shaderIndex: Int {
        switch self {
        case let .element(element): element.shaderIndex
        case .magneticPulse: 4
        }
    }
}

struct ElementalBurstView: View {

    let kind: BurstKind

    /// Origin, in the board's own coordinate space.
    let center: CGPoint

    /// How far the burst reaches, in points.
    let radius: CGFloat

    /// When it began. Progress is measured from here rather than from
    /// `onAppear`, so a burst that starts mid-move is not restarted by an
    /// unrelated redraw.
    let start: Date

    var body: some View {
        TimelineView(.animation) { timeline in
            let elapsed = timeline.date.timeIntervalSince(start)
            let progress = min(max(elapsed / GameRules.elementalBurstDuration, 0), 1)

            Rectangle()
                .fill(.white)
                .colorEffect(
                    ShaderLibrary.elementalBurst(
                        .float2(center),
                        .float(radius),
                        .float(progress),
                        .float(Double(kind.shaderIndex))
                    )
                )
                // Additive, so the burst reads as light thrown over the board
                // rather than paint laid on top of it.
                .blendMode(.plusLighter)
                .opacity(progress >= 1 ? 0 : 1)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Element → shader index

extension ZodiacElement {

    /// The branch this element takes inside `elementalBurst`.
    ///
    /// Must match the `kind` comparisons in `Elemental.metal`. Kept next to the
    /// view that passes it rather than on the enum itself, because it is a
    /// detail of one shader and not a property of the element.
    var shaderIndex: Int {
        switch self {
        case .fire: 0
        case .water: 1
        case .air: 2
        case .earth: 3
        }
    }
}
