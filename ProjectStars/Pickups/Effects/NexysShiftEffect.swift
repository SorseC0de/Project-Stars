//
//  NexysShiftEffect.swift
//  Project Stars
//
//  Uncommon Pentacle: bring the island to you, or go to the island.
//

import Foundation

/// Closes the distance between the piece and the Nexys island, whichever way
/// round that happens to be.
///
/// One Pentacle, two behaviours, decided entirely by where the island already
/// is:
///
/// - **Island on the other plane** → it moves to yours. You are not carried; it
///   comes to you.
/// - **Island already on your plane** → you warp onto it.
///
/// That makes it self-sequencing rather than conditional-and-often-useless.
/// Stranded on a decaying Terra with the island above, the first one you open
/// calls it down and the second puts you on it — and landing on the island in
/// Terra rides it back up to a freshly restored Astra
/// (`GameRules.nexysAscendsFromTerra`). On Astra it is simply a free trip to the
/// safest square on the board.
///
/// Warping onto it is a landing like any other, so every landing check runs —
/// which is exactly what makes the second step ascend rather than needing a
/// special case here.
struct NexysShiftEffect: PickupEffect {

    let id: PickupID = .nexysShift
    let rarity: PickupRarity = .uncommon
    let displayName = "Nexys Shift"
    let summary = "Brings the Nexys island to your plane, or warps you onto it if it is already here."
    let glyph = "◈"

    func plan(
        context: PickupContext,
        choice: PickupChoiceResult?,
        generator: inout SeededRandom
    ) -> [GameEvent] {
        // Island elsewhere: call it down (or up) to you. `carryingPiece: false`
        // — the island travels alone, you are already where you are.
        guard context.nexysPlane == context.plane else {
            return [.nexysMoved(to: context.plane, carryingPiece: false)]
        }

        // Island here: go to it.
        guard context.piecePoint != GameRules.nexysPoint else { return [] }

        return [
            .pieceTeleported(
                from: context.piecePoint,
                to: GameRules.nexysPoint,
                fromPlane: context.plane,
                toPlane: context.plane
            )
        ]
    }
}
