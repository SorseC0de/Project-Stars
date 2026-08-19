//
//  PlaneBadgeView.swift
//  Project Stars
//
//  Which plane the board is showing.
//

import SwiftUI

/// A pill naming the plane, in that plane's own colour.
///
/// Lives on the board rather than in the panel. It describes what is being
/// looked at, not what can be pressed — and the panel's top row is a row of
/// controls plus the sign's name, which a third label was crowding out.
///
/// The colour is the information; the word only confirms it.
struct PlaneBadgeView: View {

    let plane: Plane

    var body: some View {
        Text(plane.displayName.uppercased())
            .font(.system(size: 12, weight: .heavy, design: .monospaced))
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .tracking(2)
            .foregroundStyle(Palette.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            // Fill and nothing else. The outline was a hairline drawn at screen
            // resolution over art that is drawn at whole pixels, so it read as
            // a different material from everything else on the board.
            .background(Capsule().fill(Palette.planeTint(plane)))
            .animation(.easeInOut(duration: 0.25), value: plane)
            .allowsHitTesting(false)
    }
}
