//
//  ShadowWorkEffect.swift
//  Project Stars
//
//  Legendary Pentacle: your own reflection, turned loose.
//

import Foundation

/// Shadow Work — spawns a mirrored double of your piece.
///
/// - TODO: **Scaffolded, not implemented.** `weight` is `0`, so it cannot spawn
///   and the game stays coherent without it. Unlike every other effect in the
///   catalogue this one is not a single burst of events — it introduces a
///   second entity that persists and acts every turn, which the engine has no
///   concept of yet. The full spec is recorded below so none of it is lost.
///
/// ## The Pentacle itself
///
/// Appears as a desaturated, dark coin (`appearance == .shadow`), spawning very
/// rarely *in place of* an ordinary Pentacle. Once it is on the board it does
/// not sit still: every move the player makes, it moves one square **toward**
/// them, until it is caught.
///
/// ## What opening it does
///
/// Spawns a shadow copy of the player's piece on the Nexys. If the Nexys is not
/// on the player's plane, it instead spawns a **visual-only** shadow duplicate of
/// the island at the centre — one the player cannot step on — and puts the
/// shadow piece there.
///
/// ## The shadow's behaviour
///
/// It mirrors the player exactly: move west one square, it moves east one. It
/// wears tiles on landing precisely as the player does, so it roughly doubles
/// the rate the board is destroyed.
///
/// ## Getting rid of it
///
/// - **Collide with it** → it vanishes and the Zodiaction meter fills completely.
/// - **Drive it into a hole**, or **into a Pentacle** → destroyed, half meter.
///
/// ## The one exception
///
/// If the shadow spawned on a *shadow* Nexys — i.e. the real island was on the
/// other plane — then driving it into the centre chasm does **not** work: it
/// lands safely on its shadow island instead. Deliberate. The chasm is a
/// guaranteed hole on every board, which would otherwise make disposing of the
/// shadow trivial.
///
/// ## What building it needs
///
/// 1. Engine state: shadow position/plane, and the shadow-Nexys marker.
/// 2. Events: shadow spawned, stepped, destroyed — plus reusing `.tileDamaged`
///    for the wear it causes.
/// 3. A hook in the move pipeline to mirror the player's committed offset and
///    settle the shadow, after the player's own travel resolves.
/// 4. A hook for the Pentacle's own pre-collection movement, which is the first
///    thing in the game that moves a revealed Pentacle.
struct ShadowWorkEffect: PickupEffect {

    let id: PickupID = .shadowWork
    let rarity: PickupRarity = .legendary
    let displayName = "Shadow Work"
    let summary = "A mirrored shadow of your piece appears and copies every move you make."
    let glyph = "☾"

    /// Desaturated and dark, so it is recognisable on sight.
    let appearance: PentacleAppearance = .shadow

    /// Out of rotation until the shadow entity exists.
    let weight = 0

    func plan(
        context: PickupContext,
        choice: PickupChoiceResult?,
        generator: inout SeededRandom
    ) -> [GameEvent] {
        []
    }
}
