//
//  SpriteSheet.swift
//  Project Stars
//
//  Cutting individual sprites out of a sheet.
//

import SwiftUI

/// Loads sprite sheets and crops cells out of them.
///
/// Cropping happens once per sprite and is cached, so a board redraw costs
/// nothing beyond dictionary lookups — the expensive part is decoding the sheet,
/// which happens once per sheet for the life of the process.
///
/// ## Why the sheet's own scale is respected
///
/// A sheet dropped into a `@2x` slot decodes at twice the pixel size, and a cell
/// that should start at pixel 32 actually starts at 64. Rather than forbid that,
/// every crop is multiplied by the loaded image's `scale`. Export the sheet at
/// 1x or 2x, put it in the matching slot, and the atlas numbers stay the same
/// either way.
@MainActor
enum SpriteSheetLoader {

    /// Decoded sheets. `nil` means "looked for it, not there".
    private static var sheets: [String: UIImage?] = [:]

    /// Cropped sprites, keyed by sprite and frame.
    private static var crops: [CropKey: UIImage?] = [:]

    private struct CropKey: Hashable {
        let id: SpriteID
        let frame: Int
    }

    // MARK: - Lookup

    /// One frame of a sprite, cut from its sheet.
    ///
    /// Returns `nil` when the sprite is not in the atlas, when its sheet has not
    /// been added yet, or when the slice falls outside the sheet's bounds — all
    /// of which leave the caller free to fall back to an individual image set or
    /// a placeholder.
    static func image(for id: SpriteID, frame: Int = 0) -> UIImage? {
        let key = CropKey(id: id, frame: frame)
        if let cached = crops[key] { return cached }

        let cropped = crop(id: id, frame: frame)
        crops[key] = cropped
        return cropped
    }

    /// True when `id` has a slice **and** that slice's sheet is present.
    static func hasArt(for id: SpriteID) -> Bool {
        image(for: id) != nil
    }

    /// How many frames a sprite animates over. `1` for a still image.
    static func frameCount(for id: SpriteID) -> Int {
        SpriteAtlas.slice(for: id)?.frames ?? 1
    }

    /// Seconds each frame is held.
    static func frameDuration(for id: SpriteID) -> TimeInterval {
        SpriteAtlas.slice(for: id)?.frameDuration ?? 0.12
    }

    // MARK: - Cropping

    private static func crop(id: SpriteID, frame: Int) -> UIImage? {
        guard let slice = SpriteAtlas.slice(for: id),
              let sheet = sheet(named: slice.sheet),
              let source = sheet.cgImage
        else { return nil }

        // Slices are declared at 1x; a sheet imported at a higher scale simply
        // has proportionally larger everything.
        let s = sheet.scale
        let rect = slice.pixelRect(frame: frame)

        let pixels = CGRect(
            x: CGFloat(rect.x) * s,
            y: CGFloat(rect.y) * s,
            width: CGFloat(rect.width) * s,
            height: CGFloat(rect.height) * s
        )

        // A slice pointing off the edge of the sheet is a layout mistake, not a
        // crash: fall through to the placeholder so the rest of the board still
        // draws and the gap is obvious on screen.
        let bounds = CGRect(x: 0, y: 0, width: source.width, height: source.height)
        guard bounds.contains(pixels), let cut = source.cropping(to: pixels) else {
            return nil
        }

        return UIImage(cgImage: cut, scale: sheet.scale, orientation: .up)
    }

    private static func sheet(named name: String) -> UIImage? {
        if let cached = sheets[name] { return cached }
        let image = UIImage(named: name)
        sheets[name] = image
        return image
    }

    // MARK: - Maintenance

    /// Drops every cached sheet and crop.
    static func invalidate() {
        sheets.removeAll()
        crops.removeAll()
    }

    /// Sheets the atlas expects that have not been added yet.
    ///
    /// Useful while importing art a sheet at a time — anything listed here is
    /// still drawing placeholders.
    static var missingSheets: [String] {
        SpriteAtlas.sheetNames.filter { UIImage(named: $0) == nil }
    }
}
