//
//  TurnCounterTuning.swift
//  Project Stars
//
//  A bench for placing the turn counter's pieces.
//

import SwiftUI

#if DEBUG

/// Live placement for every piece of the counter.
///
/// The assembly is six sprites that have to sit together exactly, and guessing
/// at six sets of offsets in source and rebuilding between each guess is the
/// slow way to find them. This puts every one of them on a control and prints
/// the answer when it looks right.
///
/// **Scale is whole numbers only.** Pixel art at 1.5x is pixel art with some
/// pixels bigger than others, so the control steps by one and cannot express a
/// fraction — the same rule `PixelArtMetrics` follows for the board.
@Observable
@MainActor
final class TurnCounterTuning {

    static let shared = TurnCounterTuning()

    /// One addressable piece of the counter.
    enum Piece: String, CaseIterable, Identifiable {
        case whole
        case label
        case plateLeft
        case plateMiddle
        case plateRight
        case digits
        case cap

        var id: String { rawValue }

        var title: String {
            switch self {
            case .whole: "ALL"
            case .label: "TURN"
            case .plateLeft: "L"
            case .plateMiddle: "MID"
            case .plateRight: "R"
            case .digits: "0-9"
            case .cap: "CAP"
            }
        }
    }

    struct Adjust: Equatable {
        /// Whole multiples only. See the note on the class.
        var scale = 1

        /// In **art pixels**, not points.
        ///
        /// A point is a different distance on every device and half of one is
        /// not a thing pixel art can express. Tuning in the art's own units
        /// means a value found here is the value that goes in the source, and
        /// it lands identically at every screen scale.
        var x: CGFloat = 0
        var y: CGFloat = 0
    }

    var pieces: [Piece: Adjust] = Dictionary(
        uniqueKeysWithValues: Piece.allCases.map { ($0, Adjust()) }
    )

    var selected: Piece = .whole
    var isShown = true

    /// Air between one numeral and the next, in art pixels.
    ///
    /// Its own control rather than a piece offset: it applies *between* the
    /// digits rather than to any one of them, and it is the number most likely
    /// to want judging by eye against a real turn count.
    var digitGap: CGFloat = 0

    subscript(piece: Piece) -> Adjust {
        get { pieces[piece] ?? Adjust() }
        set { pieces[piece] = newValue }
    }

    /// The current arrangement, in a form that can be pasted into the view.
    func dump() {
        print("── turn counter ──")
        print("  digit gap  \(Int(digitGap))px")
        for piece in Piece.allCases {
            let a = self[piece]
            guard a != Adjust() else { continue }
            print(String(
                format: "  %-11@ scale %d   x %+.0fpx   y %+.0fpx",
                piece.rawValue as NSString, a.scale, a.x, a.y
            ))
        }
    }
}

/// The bench itself: pick a piece, move it, scale it.
struct TurnCounterTunerControls: View {

    @Bindable var tuning = TurnCounterTuning.shared

    /// How far a piece can be pushed, in art pixels. Deliberately far — the
    /// counter is being placed against a whole screen, not nudged within a box.
    /// At a scale of three this reaches most of the way across one.
    private let reach: CGFloat = 160

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Toggle("turn", isOn: $tuning.isShown)
                    .toggleStyle(.button)
                Button("print") { tuning.dump() }
                Button("reset") { tuning[tuning.selected] = .init() }
            }

            // Which piece the controls below are pointed at.
            HStack(spacing: 3) {
                ForEach(TurnCounterTuning.Piece.allCases) { piece in
                    Button(piece.title) { tuning.selected = piece }
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(
                            tuning.selected == piece ? Palette.gold : Palette.coolBlack,
                            in: RoundedRectangle(cornerRadius: 4)
                        )
                        .foregroundStyle(
                            tuning.selected == piece ? Palette.coolBlack : Palette.stone
                        )
                }
            }

            row("scale", value: Binding(
                get: { CGFloat(tuning[tuning.selected].scale) },
                set: { tuning[tuning.selected].scale = max(Int($0.rounded()), 1) }
            ), range: 1...8, step: 1)

            row("x px", value: Binding(
                get: { tuning[tuning.selected].x },
                set: { tuning[tuning.selected].x = $0.rounded() }
            ), range: -reach...reach, step: 1)

            row("gap px", value: Binding(
                get: { tuning.digitGap },
                set: { tuning.digitGap = $0.rounded() }
            ), range: -4...10, step: 1)

            row("y px", value: Binding(
                get: { tuning[tuning.selected].y },
                set: { tuning[tuning.selected].y = $0.rounded() }
            ), range: -reach...reach, step: 1)
        }
        .font(.system(size: 10, weight: .semibold, design: .monospaced))
        .foregroundStyle(Palette.stone)
        .padding(8)
        .background(Palette.midnight.opacity(0.9), in: RoundedRectangle(cornerRadius: 8))
    }

    private func row(
        _ label: String,
        value: Binding<CGFloat>,
        range: ClosedRange<CGFloat>,
        step: CGFloat
    ) -> some View {
        HStack(spacing: 6) {
            Text(label).frame(width: 34, alignment: .leading)

            Button("−") { value.wrappedValue = max(value.wrappedValue - step, range.lowerBound) }
            Slider(value: value, in: range, step: step).frame(width: 150)
            Button("+") { value.wrappedValue = min(value.wrappedValue + step, range.upperBound) }

            Text("\(Int(value.wrappedValue))").frame(width: 34, alignment: .trailing)
        }
    }
}

#endif
