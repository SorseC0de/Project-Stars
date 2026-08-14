//
//  PaletteRecolour.swift
//  Project Stars
//
//  Swapping palette entries in a bitmap, once, and keeping the result.
//

import SwiftUI
import UIKit

/// Recolours a sprite by exact palette entry, ahead of time.
///
/// ## Why this exists alongside the shader
///
/// `paletteSwap` is a `colorEffect`, which only views can run. Astra's clouds
/// are drawn in a `Canvas` — one pass for the whole plane, which is what made
/// the plane affordable — and a `Canvas` draws images, not views. So a cloud
/// that needs its colours changed cannot use the shader at all.
///
/// The alternative was approximating the target with hue and saturation
/// filters, which a `Canvas` *can* do. That gets close and lands off-palette,
/// and the whole point of a fixed forty-seven colour palette is that nothing
/// lands between two of them.
///
/// So the swap happens once, on the bitmap, and the result is cached. There are
/// only ever a handful — six cloud frames times a few wear states — and they are
/// built the first time they are asked for and kept for the life of the process.
@MainActor
enum PaletteRecolour {

    private static var cache: [Key: UIImage] = [:]

    private struct Key: Hashable {
        let id: SpriteID
        let frame: Int
        let swaps: [PaletteSwap]
    }

    /// `image` with every `from` colour replaced by its `to`.
    ///
    /// Returns the original when there is nothing to swap, so callers do not
    /// need to branch.
    static func image(_ id: SpriteID, frame: Int, swaps: [PaletteSwap]) -> UIImage? {
        guard let source = SpriteSheetLoader.image(for: id, frame: frame) else { return nil }
        guard !swaps.isEmpty else { return source }

        let key = Key(id: id, frame: frame, swaps: swaps)
        if let cached = cache[key] { return cached }

        let recoloured = redraw(source, swaps: swaps) ?? source
        cache[key] = recoloured
        return recoloured
    }

    /// Walks the pixels once, replacing exact matches.
    ///
    /// Exact rather than nearest: these are palette entries, so a pixel either
    /// *is* one of them or is something the swap was not talking about. A
    /// tolerance would catch the sprite's own outline and anti-aliasing, neither
    /// of which is supposed to move.
    private static func redraw(_ source: UIImage, swaps: [PaletteSwap]) -> UIImage? {
        guard let cg = source.cgImage else { return nil }

        let width = cg.width
        let height = cg.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)

        guard let context = CGContext(
            data: &pixels,
            width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))

        let table = swaps.map { (from: $0.from.rgb8, to: $0.to.rgb8) }

        for index in stride(from: 0, to: pixels.count, by: 4) {
            let alpha = pixels[index + 3]
            guard alpha > 0 else { continue }

            // Premultiplied: undo it before comparing, since a half-transparent
            // pixel of a colour is stored darker than the colour itself.
            let scale = 255.0 / Double(alpha)
            let rgb = (
                UInt8(min(255, Double(pixels[index]) * scale)),
                UInt8(min(255, Double(pixels[index + 1]) * scale)),
                UInt8(min(255, Double(pixels[index + 2]) * scale))
            )

            guard let match = table.first(where: { $0.from == rgb }) else { continue }

            let back = Double(alpha) / 255.0
            pixels[index] = UInt8(Double(match.to.0) * back)
            pixels[index + 1] = UInt8(Double(match.to.1) * back)
            pixels[index + 2] = UInt8(Double(match.to.2) * back)
        }

        guard let output = context.makeImage() else { return nil }
        return UIImage(cgImage: output, scale: source.scale, orientation: .up)
    }
}

private extension Color {
    /// This colour as eight-bit components, for comparing against a bitmap.
    var rgb8: (UInt8, UInt8, UInt8) {
        let parts = shaderComponents
        return (
            UInt8((parts.count > 0 ? parts[0] : 0) * 255),
            UInt8((parts.count > 1 ? parts[1] : 0) * 255),
            UInt8((parts.count > 2 ? parts[2] : 0) * 255)
        )
    }
}
