//
//  TurnCounterView.swift
//  Project Stars
//
//  How far you have got, in the corner of the sky.
//

import SwiftUI

/// The turn count, drawn from the sheet.
///
/// Testers said they did not know what they were playing *for*, and a number
/// that only goes up is the smallest possible answer to that: it says the run
/// is a distance and you are somewhere along it. Deliberately rudimentary —
/// this is the seed of a progress display rather than the finished one.
///
/// ## Why the plate is three sprites
///
/// It is an end, a **repeating middle**, and an end. A counter is therefore as
/// wide as the number standing in it — one digit at the start of a run, four
/// deep into one — and the art never stretches. Scaling a nine-pixel-tall plate
/// to fit a fourth digit would have bent the only thing on screen that is
/// supposed to look printed.
///
/// ## Why the digits are laid out as plain cells
///
/// Each numeral is drawn against the bottom right of its own cell on the sheet,
/// so the spacing between them is part of the art. The layout puts down square
/// cells in a row and lets the glyphs sit where they were drawn — no kerning
/// table, no per-digit nudge, and a redraw of the font changes the look without
/// touching this file.
struct TurnCounterView: View {

    /// The number to show. Clamped at zero — a run cannot be on turn minus one.
    let turn: Int

    /// Whole-number pixel scale, from `PixelArtMetrics`.
    let scale: CGFloat

    /// Where each piece sits, in **art pixels**, measured from the slot it
    /// would otherwise occupy. Found on the bench — see `TurnCounterTuning`.
    ///
    /// The counter is far more compact than a row of separate sprites: the
    /// pieces overlap, and the numbers sit *inside* the plate rather than
    /// beside it. These are the numbers that make that true.
    private enum Place {
        static let plateLeft = CGPoint(x: -13, y: 6)
        static let plateMiddle = CGPoint(x: -13, y: 6)
        // The right end hugs the last digit rather than closing a box around
        // the number, which is why it sits further left than its siblings.
        static let plateRight = CGPoint(x: -20, y: 6)
        static let digits = CGPoint(x: -21, y: 1)
        static let cap = CGPoint(x: -42, y: 3)
    }

    /// How many numerals are always shown.
    ///
    /// Three. Fifty turns go by in the first few seconds of a run, so two would
    /// have been outgrown almost immediately — and a counter that grows a cell
    /// mid-run shifts everything beside it at the least interesting moment.
    /// Turn zero reads `000` and the width never changes until a run reaches
    /// four figures, which is a problem worth having.
    private static let leastDigits = 3

    /// How wide a numeral is drawn, in art pixels, and how much air it wants
    /// beside it.
    ///
    /// Each glyph is drawn against the **bottom right** of a 16-pixel cell and
    /// is eight across. Laying those cells edge to edge therefore leaves eight
    /// pixels of nothing between one numeral and the next — the counter read as
    /// three digits standing well apart rather than as a number. The advance is
    /// the glyph plus one, and the cells overlap to make up the difference.
    private static let digitWidth: CGFloat = 8
    /// Zero: the glyphs were drawn with their own breathing room inside the
    /// cell, so a gap on top of that is a gap twice over.
    private static let digitGap: CGFloat = 0

    /// The gap actually used, which the bench may be overriding.
    private var gap: CGFloat {
        #if DEBUG
        TurnCounterTuning.shared.digitGap
        #else
        Self.digitGap
        #endif
    }

    /// How many digits the plate's two ends cover between them.
    ///
    /// Separate from `leastDigits` because they answer different questions:
    /// this is a fact about the *drawing*, that one is a choice about the
    /// *number*. Tying them together is what would make a change to either one
    /// silently resize the plate.
    private static let digitsCoveredByEnds = 2

    /// One sheet cell, at this scale.
    private var cell: CGFloat { CGFloat(GameRules.tilePixelSize) * scale }

    /// How far one numeral moves the next one along.
    private var digitAdvance: CGFloat { (Self.digitWidth + gap) * scale }

    private var digits: [Int] {
        let value = max(turn, 0)
        let written = value == 0 ? "0" : String(value)
        let padded = String(repeating: "0", count: max(Self.leastDigits - written.count, 0))
            + written
        return padded.compactMap { $0.wholeNumberValue }
    }

    /// How many repeats of the plate's middle are needed.
    ///
    /// The ends cover two digits between them; everything past that is a
    /// middle. At the standard three that is one repeat, and a run that reaches
    /// four figures grows another without anything else being touched.
    private var middles: Int { max(digits.count - Self.digitsCoveredByEnds, 0) }

    var body: some View {
        HStack(spacing: 0) {
            sprite(.turnLabel, cells: 2, at: .zero, tuned: .label)

            ZStack {
                HStack(spacing: 0) {
                    sprite(.turnPlateLeft, at: Place.plateLeft, tuned: .plateLeft)
                    ForEach(0..<middles, id: \.self) { _ in
                        sprite(.turnPlateMiddle, at: Place.plateMiddle, tuned: .plateMiddle)
                    }
                    sprite(.turnPlateRight, at: Place.plateRight, tuned: .plateRight)
                }

                // Negative spacing: the *cells* overlap so the numerals inside
                // them land a pixel apart. See `digitWidth`.
                HStack(spacing: digitAdvance - cell) {
                    ForEach(digits.indices, id: \.self) { index in
                        sprite(.digit(digits[index]), at: Place.digits, tuned: .digits)
                    }
                }
            }

            sprite(.turnCap, at: Place.cap, tuned: .cap)
        }
        .tuned(.whole, scale: scale)
        .allowsHitTesting(false)
    }

    private func sprite(
        _ id: SpriteID,
        cells: CGFloat = 1,
        at place: CGPoint,
        tuned piece: TunedPiece
    ) -> some View {
        PixelSprite(id: id) { Color.clear }
            .frame(width: cell * cells, height: cell)
            // Placement first, bench second — so a value read off the bench is
            // a value *added* to what is written here, and can be folded in by
            // adding the two numbers.
            .offset(x: place.x * scale, y: place.y * scale)
            .tuned(piece, scale: scale)
    }
}

// MARK: - Placing the pieces

#if DEBUG
typealias TunedPiece = TurnCounterTuning.Piece
#else
/// A stand-in with the same shape, so the counter reads identically in a build
/// that has no bench. The names are the pieces; in Release they mean nothing
/// and the modifier below does nothing.
enum TunedPiece {
    case whole, label, plateLeft, plateMiddle, plateRight, digits, cap
}
#endif

private extension View {
    /// Applies the bench's placement for this piece, and nothing at all in a
    /// shipped build.
    ///
    /// The call sites are identical either way so the drawing code never grows
    /// a `#if` of its own — six of those inside one `HStack` would be harder to
    /// read than the layout they are decorating.
    @ViewBuilder
    func tuned(_ piece: TunedPiece, scale: CGFloat) -> some View {
        #if DEBUG
        let adjust = TurnCounterTuning.shared[piece]
        // The bench works in art pixels; one of those is `scale` points.
        scaleEffect(CGFloat(adjust.scale))
            .offset(x: adjust.x * scale, y: adjust.y * scale)
        #else
        self
        #endif
    }
}
