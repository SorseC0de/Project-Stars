//
//  PixelSprite.swift
//  Project Stars
//
//  Draws a sprite if the art exists, and something legible if it doesn't.
//

import SwiftUI

/// Renders a `SpriteID` at pixel-art quality, with a graceful fallback.
///
/// Art is resolved in three steps, first hit wins:
///
/// 1. **A sheet slice** — `SpriteAtlas` says where the sprite lives and
///    `SpriteSheetLoader` cuts it out. The recommended route.
/// 2. **An individual image set** named `id.assetName`, for anything not worth
///    putting on a sheet (the 112px plane backdrops) or not yet moved onto one.
/// 3. **The placeholder** passed in by the caller.
///
/// Because the fallback is per-sprite, a half-finished import is not a broken
/// build — art can come over one sheet, or one row, at a time and everything
/// still runs.
///
/// Whatever is drawn uses nearest-neighbour interpolation with antialiasing off,
/// which is what keeps 16x16 art crisp when scaled up by `PixelArtMetrics`.
struct PixelSprite<Placeholder: View>: View {

    @Environment(\.ambientClock) private var ambientClock

    let id: SpriteID

    /// Pins the sprite to one frame instead of cycling it.
    ///
    /// For one-shot effects: a burst has to play through once and stop, driven
    /// by how far along the burst is. Left `nil`, a multi-frame sprite loops on
    /// a wall clock, which is right for ambient things and wrong for events.
    var frame: Int?

    /// Drawn when no art exists for this sprite yet.
    @ViewBuilder let placeholder: () -> Placeholder

    var body: some View {
        if let frame {
            if let image = SpriteSheetLoader.image(for: id, frame: frame) {
                pixels(image)
            } else {
                placeholder()
            }
        } else if SpriteSheetLoader.frameCount(for: id) > 1, SpriteSheetLoader.hasArt(for: id) {
            animated
        } else if let image = SpriteLoader.image(for: id) {
            pixels(image)
        } else {
            placeholder()
        }
    }

    /// A multi-frame sprite, cycled on a wall clock.
    ///
    /// Ambient animation only — sparkles shimmering, a coin glinting. It never
    /// drives a rule; the game stays strictly move-based.
    private var animated: some View {
        let frames = SpriteSheetLoader.frameCount(for: id)
        let duration = SpriteSheetLoader.frameDuration(for: id)

        return TimelineView(.animation) { timeline in
            // The ambient clock, so every animated sprite in the game holds its
            // pose together while the board is waiting. See `AmbientClock`.
            let now = ambientClock(timeline.date.timeIntervalSinceReferenceDate)
            let tick = Int(now / duration)
            if let image = SpriteSheetLoader.image(for: id, frame: tick % frames) {
                pixels(image)
            } else {
                placeholder()
            }
        }
    }

    private func pixels(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .interpolation(.none)
            .antialiased(false)
    }
}

// MARK: - SpriteLoader

/// Resolves a `SpriteID` to an image, caching both hits and misses.
///
/// The cache matters because the board asks for dozens of sprites every frame
/// and `UIImage(named:)` hits the filesystem on a miss.
@MainActor
enum SpriteLoader {

    /// `nil` value means "checked, and it isn't there".
    private static var cache: [SpriteID: UIImage?] = [:]

    /// The first frame of a sprite, from whichever source has it.
    static func image(for id: SpriteID) -> UIImage? {
        if let cached = cache[id] { return cached }

        // Sheet first: it is the route that scales, and the one that cannot be
        // broken by a filename typo.
        let image = SpriteSheetLoader.image(for: id) ?? UIImage(named: id.assetName)
        cache[id] = image
        return image
    }

    /// True when the real art for this sprite has been imported.
    ///
    /// Views use this to decide whether to draw their own decoration (crack
    /// marks, glow) or leave it to the sprite.
    static func hasAsset(for id: SpriteID) -> Bool {
        image(for: id) != nil
    }

    /// Drops every cache, sheets included.
    static func invalidate() {
        cache.removeAll()
        SpriteSheetLoader.invalidate()
    }

    // MARK: - Import progress

    /// Sprites still drawing placeholders, by asset name.
    ///
    /// Reads through the same resolution order the views use, so it is an honest
    /// account of what is left rather than a guess.
    static var missingSprites: [String] {
        SpriteID.allSprites
            .filter { image(for: $0) == nil }
            .map(\.assetName)
            .sorted()
    }

    /// Sheets named by the atlas that have not been added yet.
    static var missingSheets: [String] {
        SpriteSheetLoader.missingSheets
    }
}
