//
//  GameMode.swift
//  Project Stars
//
//  Which game is being played.
//

import Foundation

/// The rules a run is played under.
///
/// ## Why this exists before there is more than one
///
/// There is one mode today and the game has always played it, so nothing here
/// changes what happens on the board. What it does is give the *question* a
/// place to live: a run now knows what it is, which is what the title card
/// announces and what a second mode will select against.
///
/// Adding one is a case and its two lines of copy. Anything that should differ
/// between modes asks the mode rather than growing a flag — see the note in
/// `_Design/project-stars-architecture.md` about rules having one owner.
enum GameMode: String, CaseIterable, Identifiable, Codable {

    /// The floor breaks under you and you stay off it. The game as it stands.
    case survival

    var id: String { rawValue }

    /// Announced in capitals on the card, so it is written the way it is read.
    var title: String {
        switch self {
        case .survival: "SURVIVAL"
        }
    }

    /// One line, said to somebody who has never played it.
    ///
    /// Short on purpose: it shares a card with the name and the card is on
    /// screen for about a second and a half. Anything longer is not read, and
    /// a mode that needs a paragraph to explain is a mode that needs a better
    /// name.
    var blurb: String {
        switch self {
        case .survival: "Avoid falling as the floor breaks beneath you!"
        }
    }
}
