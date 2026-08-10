//
//  SmokeBurstView.swift
//  Project Stars
//
//  The puff kicked up where a piece lands.
//

import SwiftUI

/// A short burst of smoke puffs, thrown outward from a landing.
///
/// Drawn rather than sprited. Each puff is a flat `Palette.smoke` disc that
/// expands, drifts outward and slightly upward, and fades — no gradients and no
/// blur, so it stays inside the fixed palette and reads as pixel art rather than
/// as a modern particle system pasted over it.
///
/// Retriggered by giving it a new `.id` per hop rather than by toggling state:
/// two landings in quick succession have to play two bursts, not merge into one.
///
/// - Note: If a hand-drawn smoke sprite arrives, this becomes a `PixelSprite`
///   with a `frames:` count and the scatter below can go.
struct SmokeBurstView: View {

    /// Size of a board cell, in points.
    let tileSize: CGFloat

    /// Whole-pixel scale, for art-pixel distances.
    let scale: CGFloat

    /// Which plane's dust this is. Astra kicks up cloud, Terra kicks up earth.
    let plane: Plane

    /// Varies the scatter so consecutive landings do not produce identical
    /// bursts.
    let seed: Int

    /// Size multiplier. `1` for an ordinary hop; a fall lands far harder.
    var magnitude: CGFloat = 1

    /// When the puff began.
    ///
    /// Driven by a timestamp rather than `onAppear` + `withAnimation`, matching
    /// every other effect here. A view that starts its own animation on appear
    /// only works if it is genuinely re-created each time — which is fragile the
    /// moment anything upstream decides to reuse it.
    let start: Date

    var body: some View {
        TimelineView(.animation) { timeline in
            let progress = CGFloat(progress(at: timeline.date))

            Group {
                if plane == .astra {
                    // Astra has no ground to kick dust off. What a landing
                    // disturbs there is the cloudstuff itself.
                    ZStack {
                        ForEach(0..<GameRules.smokePuffCount, id: \.self) { index in
                            swirl(index, progress: progress)
                        }
                    }
                    .blendMode(.plusLighter)
                } else if usesSprite {
                    sprite(progress: progress)
                } else {
                    ZStack {
                        ForEach(0..<GameRules.smokePuffCount, id: \.self) { index in
                            puff(index, progress: progress)
                        }
                    }
                }
            }
            .frame(width: tileSize, height: tileSize)
        }
        .allowsHitTesting(false)
    }

    /// How far through its life the puff is, `0`…`1`.
    ///
    /// Offset by `GameRules.smokeLeadIn` so it begins partway in rather than
    /// from nothing — see that constant for why.
    private func progress(at date: Date) -> Double {
        let elapsed = date.timeIntervalSince(start) / GameRules.smokeDuration
        let lead = min(max(GameRules.smokeLeadIn, 0), 0.95)
        return min(max(lead + elapsed * (1 - lead), 0), 1)
    }

    /// Whether the hand-drawn puff fits this landing.
    ///
    /// It is one fixed shape at one fixed size — right for a footfall, too tidy
    /// for a body hitting the ground after falling a whole plane. Heavy landings
    /// fall back to the scatter, which can be thrown as wide as it needs to be.
    private var usesSprite: Bool {
        magnitude <= GameRules.smokeSpriteMaxMagnitude
            && SpriteLoader.hasAsset(for: .smoke(plane))
    }

    /// The drawn puff, stepped through its frames once.
    private func sprite(progress: CGFloat) -> some View {
        let frames = SpriteSheetLoader.frameCount(for: .smoke(plane))
        // Clamped, not wrapped: this plays through and stops.
        let frame = min(Int(progress * CGFloat(frames)), frames - 1)

        // Natural size is two cells; `smokeSpriteScale` brings it down to sit
        // under a piece rather than swallow it.
        let side = tileSize * 2 * GameRules.smokeSpriteScale * magnitude

        return PixelSprite(id: .smoke(plane), frame: frame) { EmptyView() }
            .frame(width: side, height: side)
            // Sits low: dust kicks up from the ground, not from the piece's
            // middle.
            .offset(y: GameRules.smokeDrop * scale)
    }

    private func puff(_ index: Int, progress: CGFloat) -> some View {
        let layout = geometry(for: index, progress: progress)

        return Circle()
            .fill(Palette.smokePuff)
            // Puffs start small, swell, then thin out as they fade.
            .frame(width: layout.size, height: layout.size)
            .offset(x: layout.x, y: layout.y)
            .opacity(layout.opacity)
    }

    /// One curl of disturbed cloudstuff, thrown along the same arc a dust puff
    /// would take but unwinding as it goes.
    private func swirl(_ index: Int, progress: CGFloat) -> some View {
        let layout = geometry(for: index, progress: progress)
        let tones = Palette.astraSmokeTones
        let span = layout.size * GameRules.smokeSwirlScale

        // Alternating sign so a burst unwinds both ways at once.
        let spin = Double(progress) * GameRules.smokeSwirlSpin
            * (index.isMultiple(of: 2) ? 1 : -1)

        return CloudGlintSpiral(turns: GameRules.smokeSwirlTurns)
            .stroke(
                tones[index % tones.count],
                style: StrokeStyle(
                    lineWidth: GameRules.smokeSwirlThickness * scale,
                    lineCap: .round
                )
            )
            .frame(width: span, height: span)
            .rotationEffect(.degrees(spin))
            .offset(x: layout.x, y: layout.y)
            .opacity(layout.opacity)
    }

    /// Where one puff sits and how big it is, at the current `progress`.
    ///
    /// Broken out of the view body deliberately: as one chained expression the
    /// type checker gives up on it.
    private func geometry(for index: Int, progress: CGFloat) -> (x: CGFloat, y: CGFloat, size: CGFloat, opacity: Double) {
        // Deterministic scatter: a hash of the puff and the hop, so a burst is
        // varied but never flickers between frames.
        let mixed = (index &* 2_654_435_761) &+ (seed &* 40_503)
        let hash = Double(abs(mixed) % 1_000) / 1_000

        // Fanned to the sides rather than evenly around: a landing throws smoke
        // outward along the ground, not up in a ring.
        let spread: Double = .pi * 0.9
        let step = Double(index) / Double(GameRules.smokePuffCount) - 0.5
        let angle: Double = -.pi / 2 + step * 2 * spread + (hash - 0.5) * 0.5

        let reach: CGFloat = GameRules.smokeSpread * scale * magnitude
        let distance: CGFloat = reach * CGFloat(0.55 + 0.45 * hash) * progress
        let base: CGFloat = GameRules.smokePuffSize * scale * magnitude * CGFloat(0.6 + 0.7 * hash)
        let size: CGFloat = base * (0.35 + progress)

        let x: CGFloat = CGFloat(cos(angle)) * distance
        // Biased downward at rest so the burst sits at the piece's feet, then
        // lifts slightly as it disperses.
        let drift: CGFloat = CGFloat(sin(angle)) * distance * 0.45
        let foot: CGFloat = tileSize * 0.30
        let rise: CGFloat = progress * 2 * scale
        let y: CGFloat = drift + foot - rise

        // Holds near-solid, then fades late — fading linearly from the first
        // frame made the puffs read as a faint haze rather than as dust.
        let fade = 1 - Double(progress) * Double(progress)
        return (x, y, size, fade * GameRules.smokeOpacity)
    }
}
