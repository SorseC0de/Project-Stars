//
//  RiftPreviewDebug.swift
//  Project Stars
//
//  A bench for looking at Gemini's rift on the board.
//

import SwiftUI

#if DEBUG

/// What the rift bench is currently showing.
///
/// A singleton, and deliberately not part of `GameSession`: none of this is game
/// state, nothing here survives the decision it exists to settle, and threading
/// two art questions through the session would put them somewhere they would
/// later have to be taken out of. This comes out whole once the rift is drawn
/// for real.
@MainActor
@Observable
final class RiftPreviewDebug {

    static let shared = RiftPreviewDebug()

    /// Whether the two drawings are on the board at all.
    var isShown = true

    /// How they composite. The thing actually being chosen.
    var blend: BlendMode = .normal

    private init() {}

    /// The candidates, named — `BlendMode` is not enumerable, and most of it is
    /// not worth looking at for this.
    static let candidates: [(name: String, mode: BlendMode)] = [
        ("normal", .normal),
        ("plusLighter", .plusLighter),
        ("plusDarker", .plusDarker),
        ("screen", .screen),
        ("overlay", .overlay),
        ("softLight", .softLight),
        ("hardLight", .hardLight),
        ("multiply", .multiply),
        ("colorDodge", .colorDodge),
        ("colorBurn", .colorBurn),
        ("luminosity", .luminosity),
        ("color", .color),
        ("difference", .difference),
        ("exclusion", .exclusion),
    ]

    var blendName: String {
        Self.candidates.first { $0.mode == blend }?.name ?? "?"
    }
}

/// The picker, small enough to sit in a corner of the board.
struct RiftPreviewControls: View {

    @Bindable var bench = RiftPreviewDebug.shared

    var body: some View {
        HStack(spacing: 6) {
            Toggle("rift", isOn: $bench.isShown)
                .toggleStyle(.button)

            Menu(bench.blendName) {
                ForEach(RiftPreviewDebug.candidates, id: \.name) { candidate in
                    Button(candidate.name) { bench.blend = candidate.mode }
                }
            }
        }
        .font(.system(size: 11, weight: .bold, design: .monospaced))
        .tint(Palette.gold)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(Palette.midnight.opacity(0.85)))
    }
}

#endif
