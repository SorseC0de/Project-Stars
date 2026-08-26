//
//  BenchPanel.swift
//  Project Stars
//
//  A bench you can fold away.
//

import SwiftUI

#if DEBUG

/// Wraps a bench in a header that collapses it.
///
/// Benches accumulate: there is one for the aura, one for the streaks, one for
/// the layers, and they sit over the board they are used to judge. Folded, a
/// bench is its own name and nothing else, and it remembers which way it was
/// left.
struct BenchPanel<Content: View>: View {

    private let title: String
    private let content: Content
    @AppStorage private var isOpen: Bool

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
        _isOpen = AppStorage(wrappedValue: false, "bench.open.\(title)")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Button {
                isOpen.toggle()
            } label: {
                HStack(spacing: 4) {
                    Text(isOpen ? "▾" : "▸")
                    Text(title)
                }
                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                .foregroundStyle(Palette.gold)
                // The whole header, not the two glyphs in it.
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isOpen { content }
        }
        .padding(6)
        .background(Palette.midnight.opacity(0.9), in: RoundedRectangle(cornerRadius: 8))
    }
}

#endif
