//
//  TerraSceneryTuning.swift
//  Project Stars
//
//  Placing the two ridges.
//

import SwiftUI

#if DEBUG

/// Where Terra's two background ridges sit, in art pixels.
///
/// Two knobs rather than one, because they are the same drawing at two depths
/// and how much of each shows above the board is the whole composition — it is
/// not something the geometry can work out.
@Observable
@MainActor
final class TerraSceneryTuning {

    static let shared = TerraSceneryTuning()

    var backY: CGFloat = GameRules.terraBackdropDrop
    var midY: CGFloat = GameRules.terraMidgroundDrop

    /// The flanking rocks: how far each pair is pushed in from the screen's
    /// edges, and how far down it sits. Both in art pixels.
    var nearSpread: CGFloat = GameRules.terraRocksNearSpread
    var nearRockY: CGFloat = GameRules.terraRocksNearY
    var farSpread: CGFloat = GameRules.terraRocksFarSpread
    var farRockY: CGFloat = GameRules.terraRocksFarY

    /// How deep the ground under the board is drawn, in art pixels.
    var floorDepth: CGFloat = GameRules.terraFloorDepth

    var isShown = true

    func dump() {
        print("── terra scenery ──")
        print("  back  \(Int(backY))px")
        print("  mid   \(Int(midY))px")
        print("  rocks near  spread \(Int(nearSpread))  y \(Int(nearRockY))")
        print("  rocks far   spread \(Int(farSpread))  y \(Int(farRockY))")
        print("  floor \(Int(floorDepth))px")
    }
}

/// The bench: one slider per ridge.
struct TerraSceneryControls: View {

    @Bindable var tuning = TerraSceneryTuning.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Toggle("land", isOn: $tuning.isShown)
                    .toggleStyle(.button)
                Button("print") { tuning.dump() }
            }

            row("back Y", value: $tuning.backY)
            row("mid Y", value: $tuning.midY)
            row("near X", value: $tuning.nearSpread)
            row("near Y", value: $tuning.nearRockY)
            row("far X", value: $tuning.farSpread)
            row("far Y", value: $tuning.farRockY)
            row("floor", value: $tuning.floorDepth)
        }
        .font(.system(size: 10, weight: .semibold, design: .monospaced))
        .foregroundStyle(Palette.stone)
        .padding(8)
        .background(Palette.midnight.opacity(0.9), in: RoundedRectangle(cornerRadius: 8))
    }

    private func row(_ label: String, value: Binding<CGFloat>) -> some View {
        HStack(spacing: 6) {
            Text(label).frame(width: 44, alignment: .leading)
            Button("−") { value.wrappedValue -= 1 }
            Slider(value: value, in: -40...112, step: 1).frame(width: 150)
            Button("+") { value.wrappedValue += 1 }
            Text("\(Int(value.wrappedValue))").frame(width: 34, alignment: .trailing)
        }
    }
}

#endif
