//
//  GridPadView.swift
//  Project Stars
//
//  Control scheme 3: a flat copy of the board, down where your thumb is.
//

import SwiftUI

/// A duplicate of the board laid out in the control area, tapped to move and to
/// answer any question that needs a square.
///
/// ## Why a second board and not the real one
///
/// The real board is at the top of the screen, which is where a phone is least
/// reachable and where your hand covers exactly what you are trying to look at.
/// This is the same seven-by-seven, in the same arrangement, under your thumb —
/// so aiming at a distant square is a tap rather than a stretch, and the board
/// you are aiming *at* stays visible the whole time.
///
/// It also solves the teleport controls, which had no home: warping is a
/// question about a square, and now every question about a square is asked in
/// the same place with the same gesture.
///
/// ## Why it is flat
///
/// It is a control, not a view of the game. Pixel art down here would compete
/// with the board above it and invite the player to watch the wrong one — so it
/// is plain blocks in the tile colours, non-animated, with a cursor. Everything
/// worth watching happens on the real board.
///
/// ## Two taps, at any speed
///
/// The first tap aims and the second commits. Deliberately **not** a double-tap:
/// there is no timer, so tapping a square, looking at what the cursor says, and
/// then tapping it again a full second later works exactly as well as tapping
/// twice quickly. Tapping a different square moves the aim there instead, and
/// the confirm button does the same job for anyone who would rather press it.
///
/// The reason is misfires. A single-tap-to-move grid on a phone turns every
/// stray thumb into a committed move on a board where one wrong step ends runs.
struct GridPadView: View {

    let session: GameSession

    /// Edge length of the whole pad, in points.
    let side: CGFloat

    /// The square currently aimed at while choosing a move.
    ///
    /// A question's aim lives on the session instead — the board has to draw it,
    /// and a `@State` here would be invisible to it. See `GameSession.targetAim`.
    @State private var moveAim: GridPoint?

    /// Whichever aim is in play.
    private var aim: GridPoint? {
        session.isChoosingTile ? session.targetAim : moveAim
    }

    private func setAim(_ point: GridPoint?) {
        if session.isChoosingTile {
            session.aimTarget(point)
        } else {
            moveAim = point
        }
    }

    var body: some View {
        let board = session.visibleBoard
        let cell = side / CGFloat(board.size)
        // Built **once** per render and handed down.
        //
        // `reachableSquares` resolves every option in every direction, and
        // asking for it inside `isLegal` meant rebuilding the whole map forty-
        // nine times a frame — and twice more for the confirm button. It is the
        // same answer every time; it should be computed like it.
        let reach = session.isChoosingTile ? [:] : session.reachableSquares

        HStack(alignment: .center, spacing: PanelStyle.gridPadGap) {
            grid(board: board, cell: cell, reach: reach)

            confirmButton(reach: reach)
        }
        .frame(height: side)
        // A question about a square is a different question from "where do you
        // want to move", so an aim taken under one must not survive into the
        // other.
        .onChange(of: session.isChoosingTile) { _, _ in moveAim = nil }
    }

    // MARK: - The grid

    private func grid(board: Board, cell: CGFloat, reach: Reach) -> some View {
        VStack(spacing: 0) {
            ForEach(0..<board.size, id: \.self) { y in
                HStack(spacing: 0) {
                    ForEach(0..<board.size, id: \.self) { x in
                        square(GridPoint(x, y), board: board, cell: cell, reach: reach)
                    }
                }
            }
        }
        .background(Palette.coolBlack)
        .overlay(
            RoundedRectangle(cornerRadius: PanelStyle.gridPadCorner)
                .strokeBorder(Palette.outline, lineWidth: 2)
        )
        .clipShape(RoundedRectangle(cornerRadius: PanelStyle.gridPadCorner))
        .frame(width: side, height: side)
    }

    private func square(
        _ point: GridPoint,
        board: Board,
        cell: CGFloat,
        reach: Reach
    ) -> some View {
        let tile = board[point]
        let isAimed = aim == point
        let legal = isLegal(point, reach: reach)

        return Rectangle()
            .fill(face(tile, at: point))
            .frame(width: cell, height: cell)
            .overlay {
                // The piece's own square, so the pad is orientable at a glance
                // without having to look up at the board.
                if point == session.engine.piece.point,
                   session.visiblePlane == session.engine.piece.plane {
                    Circle()
                        .fill(session.zodiac.definition.accentColor)
                        .padding(cell * 0.3)
                }
            }
            .overlay {
                if isAimed {
                    Rectangle()
                        .strokeBorder(legal ? Palette.jade : Palette.red, lineWidth: 2)
                } else if !legal {
                    // Unreachable squares are dimmed rather than hidden: the pad
                    // is a map first and a control second, and a map with holes
                    // punched in it is harder to read than a dim one.
                    Rectangle().fill(Palette.coolBlack.opacity(PanelStyle.gridPadDim))
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { tap(point, reach: reach) }
    }

    private func face(_ tile: Tile, at point: GridPoint) -> Color {
        switch tile.kind {
        case .normal: Palette.tileFace(tile.health, on: session.visiblePlane, shade: .at(point))
        case .nexys: Palette.nexysFace
        case .chasm: Palette.chasm
        case .pool: Palette.blue
        }
    }

    // MARK: - Confirming

    private func confirmButton(reach: Reach) -> some View {
        CelButton(
            tint: Palette.jade,
            isEnabled: aim.map { isLegal($0, reach: reach) } == true,
            acceptsTouch: session.acceptsInput || session.isChoosingTile
        ) {
            commit(reach: reach)
        } label: {
            Image(systemName: "checkmark")
                .font(.system(size: PanelStyle.gridPadCheckSize, weight: .black))
        }
        .frame(width: PanelStyle.gridPadConfirmWidth, height: PanelStyle.gridPadConfirmHeight)
    }

    // MARK: - Behaviour

    /// Where the piece can go, and the swipe that gets it there.
    typealias Reach = [GridPoint: (direction: SwipeDirection, reach: Int)]

    /// Whether this square is something the pad will accept right now.
    ///
    /// A question's answer is the session's rule, so the cursor and the pad
    /// cannot disagree; a move's is this pad's own business.
    private func isLegal(_ point: GridPoint, reach: Reach) -> Bool {
        session.isChoosingTile
            ? session.isLegalTarget(point)
            : reach.keys.contains(point)
    }

    private func tap(_ point: GridPoint, reach: Reach) {
        // A question outranks the phase: `acceptsInput` is false while one is
        // outstanding, and the pad is where it is being answered.
        guard session.isChoosingTile || session.acceptsGesture else { return }

        guard isLegal(point, reach: reach) else {
            // A tap on an unreachable square clears the aim rather than being
            // ignored, so the pad never leaves a stale cursor behind after a
            // change of mind.
            setAim(nil)
            return
        }

        if aim == point {
            commit(reach: reach)
        } else {
            setAim(point)
            Haptics.step()
            previewAim(point, reach: reach)
        }
    }

    private func commit(reach: Reach) {
        guard let target = aim, isLegal(target, reach: reach) else { return }
        setAim(nil)

        if let slab = session.placingSlab {
            session.resolvePickupChoice(.place(slab, target))
            return
        }
        if session.isChoosingTile {
            session.resolvePickupChoice(.tile(target))
            return
        }

        guard let move = reach[target] else { return }
        Haptics.step()
        session.preview(direction: nil, reach: 0)
        session.submit(move.direction, reach: move.reach)
    }

    /// Shows the aim on the real board, which is where the player is looking for
    /// the consequences of it.
    private func previewAim(_ point: GridPoint, reach: Reach) {
        guard !session.isChoosingTile, let move = reach[point] else { return }
        session.preview(direction: move.direction, reach: move.reach)
    }
}
