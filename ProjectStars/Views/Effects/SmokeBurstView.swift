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

    /// Varies the scatter so consecutive landings do not produce identical
    /// bursts.
    let seed: Int

    /// Size multiplier. `1` for an ordinary hop; a fall lands far harder.
    var magnitude: CGFloat = 1

    @State private var progress: CGFloat = 0

    var body: some View {
        ZStack {
            ForEach(0..<GameRules.smokePuffCount, id: \.self) { index in
                puff(index)
            }
        }
        .frame(width: tileSize, height: tileSize)
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.easeOut(duration: GameRules.smokeDuration)) {
                progress = 1
            }
        }
    }

    private func puff(_ index: Int) -> some View {
        let layout = geometry(for: index)

        return Circle()
            .fill(Palette.smokePuff)
            // Puffs start small, swell, then thin out as they fade.
            .frame(width: layout.size, height: layout.size)
            .offset(x: layout.x, y: layout.y)
            .opacity(layout.opacity)
    }

    /// Where one puff sits and how big it is, at the current `progress`.
    ///
    /// Broken out of the view body deliberately: as one chained expression the
    /// type checker gives up on it.
    private func geometry(for index: Int) -> (x: CGFloat, y: CGFloat, size: CGFloat, opacity: Double) {
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
