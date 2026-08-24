//
//  World.swift
//  Project Stars
//
//  The single column everything in the game is stacked in.
//

import CoreGraphics

/// Where every place sits in one tall column of plane-squares.
///
/// ## Why there is a column at all
///
/// The planes used to be separate screens with a cut between them, and every
/// trip between them was something drawn over that cut — a whiteout, a fade, a
/// shrink, a piece that scaled away to nothing and swelled back out of a tile.
/// All of those exist to hide the same fact: that the place you were leaving
/// and the place you were arriving at were never in the same coordinate system,
/// so there was no path between them to travel.
///
/// Here there is. Astra, Terra, the underground and Umbra are rows of one
/// column, with empty sky between them, and a fall is a number going up.
/// Nothing needs hiding because nothing is being swapped.
///
/// ## The column
///
/// ```
///  0   sky          ← the seam: identical to row 8
///  1   ASTRA
///  2   sky
///  3   sky
///  4   TERRA
///  5   the underground
///  6   sky
///  7   UMBRA
///  8   sky          ← the seam: identical to row 0
/// ```
///
/// ## Why the ends are blank, and why that is the whole trick
///
/// Astra to Terra is three rows. Umbra to the seam is one, and the seam to
/// Astra is two — three again. So a piece that falls off the bottom and is put
/// back at the top arrives on Astra having travelled *exactly* as far as it
/// would falling from Astra to Terra, and at the moment it is moved the screen
/// is showing two rows of empty sky either side of the join. Both of those are
/// consequences of rows 0 and 8 being blank and identical, which is why they
/// are structure rather than padding.
///
/// See `World.wrapped(_:)` for the join itself.
enum World {

    /// How tall the column is, in plane-squares.
    static let rows = 9

    /// Where a plane's square sits.
    static func row(of plane: Plane) -> Int {
        switch plane {
        case .astra: 1
        case .terra: 4
        }
    }

    /// What is under Terra: where a piece that falls through the world ends up.
    ///
    /// A row and not a `Plane`, deliberately. Nothing stands on it, nothing is
    /// laid out on it, and no rule asks what is on the square below it — giving
    /// it a `Plane` case would put it in every exhaustive switch in the game as
    /// a place that has a board, which it does not.
    static let underground = 5

    /// Reserved for Umbra, which does not exist yet.
    ///
    /// Held open rather than left to be worked out later: the wrap's arithmetic
    /// depends on where the last plane sits, so a row appended below the seam
    /// afterwards would silently change how far a restart falls. The space is
    /// part of the design; the plane can arrive whenever it is drawn.
    static let umbra = 7

    /// How many rows a piece falls between two places.
    static func drop(from: Int, to: Int) -> Int { to - from }

    /// The camera row, brought back inside the column.
    ///
    /// The join is at the top of row 8, and it moves the camera a whole column
    /// height. Both sides of it show the same two rows of empty sky — row 8 and
    /// what is under it on one side, what is over row 0 and row 0 itself on the
    /// other — so the move cannot be seen, and nothing has to be faded across
    /// it. That is the entire mechanism behind falling out of the bottom of the
    /// world and landing back on Astra without a cut.
    static func wrapped(_ row: Double) -> Double {
        row >= Double(rows - 1) ? row - Double(rows) : row
    }

    /// Whether a square at `row` has any part of it inside the two-square window
    /// a camera at `camera` is looking through.
    ///
    /// The window is the whole screen, not the playfield: the lower square is
    /// behind the control panel, and what is behind the panel is still being
    /// drawn — that is what makes a piece able to fall into the underground
    /// without anything being moved to meet it.
    static func isVisible(row: Int, from camera: Double) -> Bool {
        isVisible(row: row, sweeping: camera, to: camera)
    }

    /// The same question asked of a whole journey rather than an instant.
    ///
    /// **This is the one that gets used**, and the reason is a trap worth
    /// naming. `cameraRow` is animated, which means the *model* reaches its
    /// destination immediately and only the view takes the long way there — so
    /// anything that reads the number to decide whether to run gets the answer
    /// for the end of the trip on the first frame of it. Asked at an instant,
    /// the plane being left goes to sleep while it is still filling the screen,
    /// and the plane being arrived at wakes up two screens away.
    ///
    /// Asked of the sweep, everything the camera will pass over stays awake for
    /// as long as the camera is moving, which is exactly the old rule — "both
    /// planes are awake while falling" — without the old rule's assumption that
    /// falling is the only way to travel.
    static func isVisible(row: Int, sweeping from: Double, to: Double) -> Bool {
        let lowest = min(from, to)
        let highest = max(from, to)
        return Double(row) < highest + 2 && Double(row) + 1 > lowest
    }
}
