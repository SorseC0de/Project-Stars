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

    // MARK: - The bump
    //
    // The placement is settled and baked into `TurnCounterView.Place`, so the
    // per-piece knobs are gone. What is being tuned now is the reaction.

    /// **How the jump plays.** Stepped is two held states, the way the rest of
    /// the game's pixel animation behaves; sliding interpolates between them.
    var isStepped = false

    /// How far the changing numeral leaps, in art pixels. Vertical only — a
    /// number that also moved sideways would read as being knocked rather than
    /// as counting.
    var numberJump: CGFloat = 2

    /// A shared vertical nudge for the numerals **and** the cap, in art pixels.
    ///
    /// The one placement knob kept: those two sit on a line together, and
    /// moving them as a pair is a different question from where either sits
    /// relative to the plate. Added on top of the baked `Place` values — hand
    /// me a number and it gets folded into those.
    /// Zero: everything it found is baked into `TurnCounterView.Place`.
    var baseY: CGFloat = 0

    /// How fast whatever is playing runs, as a multiple of its shipped timing.
    ///
    /// Below one is slower. Applied to every flourish at once rather than per
    /// style — the question being asked is "is this the right *pace*", and
    /// answering it separately five times is five chances to settle on five
    /// different answers to the same question.
    var speed: CGFloat = 1

    /// Which reaction plays when the number changes.
    var flourish: TurnFlourish = TurnCounterView.shippedFlourish

    /// How many numerals are shown. The layout is supposed to follow this
    /// rather than assume three — this is how that gets proved.
    var leastDigits: Int = TurnCounterView.shippedLeastDigits

    /// How far the cap is shoved, in art pixels. Horizontal only, for the same
    /// reason in reverse: it is being pushed out of the number's way.
    var capJump: CGFloat = 2

    subscript(piece: Piece) -> Adjust {
        get { pieces[piece] ?? Adjust() }
        set { pieces[piece] = newValue }
    }

    /// The current arrangement, in a form that can be pasted into the view.
    func dump() {
        print("── turn counter ──")
        for piece in Piece.allCases where self[piece] != Adjust() {
            let a = self[piece]
            print(String(
                format: "  %-11@ x %+.0f   y %+.0f",
                piece.rawValue as NSString, a.x, a.y
            ))
        }
        print("  style       \(flourish.title)")
        print("  speed       \(String(format: "%.2f", speed))x")
        print("  mode        \(isStepped ? "stepped" : "slide")")
        print("  base Y      \(Int(baseY))px")
        print("  number jump \(Int(numberJump))px")
        print("  cap jump    \(Int(capJump))px")
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
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Toggle("turn", isOn: $tuning.isShown)
                    .toggleStyle(.button)

                Button(tuning.isStepped ? "stepped" : "slide") {
                    tuning.isStepped.toggle()
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Palette.gold, in: RoundedRectangle(cornerRadius: 4))
                .foregroundStyle(Palette.coolBlack)

                Button(tuning.flourish.title) {
                    let all = TurnFlourish.allCases
                    let next = (all.firstIndex(of: tuning.flourish) ?? 0) + 1
                    tuning.flourish = all[next % all.count]
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Palette.lime, in: RoundedRectangle(cornerRadius: 4))
                .foregroundStyle(Palette.coolBlack)

                Button("print") { tuning.dump() }
                Button("reset") { tuning[tuning.selected] = .init() }
            }

            // Which piece the x/y below are pointed at. Applied on top of the
            // baked `Place` values, so a number read off here is added to what
            // is written in `TurnCounterView`.
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

            row("x", value: Binding(
                get: { tuning[tuning.selected].x },
                set: { tuning[tuning.selected].x = $0.rounded() }
            ), range: -60...60, step: 1)

            row("y", value: Binding(
                get: { tuning[tuning.selected].y },
                set: { tuning[tuning.selected].y = $0.rounded() }
            ), range: -30...30, step: 1)

            // Halves, and far enough either side to find the edges of taste
            // rather than the edges of the slider.
            row("speed", value: $tuning.speed, range: 0.5...12, step: 0.5)

            row("places", value: Binding(
                get: { CGFloat(tuning.leastDigits) },
                set: { tuning.leastDigits = max(Int($0.rounded()), 1) }
            ), range: 1...6, step: 1)

            row("base Y", value: $tuning.baseY, range: -12...12, step: 1)
            row("num Y", value: $tuning.numberJump, range: 0...12, step: 1)
            row("cap X", value: $tuning.capJump, range: 0...12, step: 1)
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
