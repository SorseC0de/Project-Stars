//
//  ProjectStarsApp.swift
//  Project Stars
//
//  App entry point.
//

import SwiftUI

@main
struct ProjectStarsApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                // Pixel art reads as intended on a dark field; the palette is
                // built for it, so the system appearance is pinned.
                .preferredColorScheme(.dark)
                .persistentSystemOverlays(.hidden)
        }
    }
}
