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

        HStack(alignment: .top, spacing: PanelStyle.gridPadGap) {
            // What the slab is made of, north-west of the map.
            //
            // The footprint on the grid says *where* and the board above says
            // what it will look like there; this says **what it is**, once,
            // large enough to read without hunting. Drawn as the real thing in
            // the real wear state, with an edge under it on Terra so it reads as
            // a slab of ground rather than a coloured square.
            if let slab = session.placingSlab {
                slabToken(slab, cell: cell)
            }

            grid(board: board, cell: cell, reach: reach)

            VStack(spacing: PanelStyle.gridPadGap) {
                confirmButton(reach: reach)

                // An offer that can be walked away from says so down here, next
                // to the button that accepts it. It used to sit over the middle
                // of the board, which is the one place nothing is allowed to be
                // pressed.
                if session.choiceIsDeclinable { declineButton }
            }
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
                // The slab's footprint, in the colour of the ground it carries.
                //
                // Every square the shape would occupy, not just the one under
                // the finger — placing a four-tile L on a seven-wide board is a
                // question about the whole shape, and a single bracket answers
                // the wrong one.
                if let slab = session.placingSlab, footprint.contains(point) {
                    Rectangle()
                        .fill(slabColour(slab, legal: legal))
                        .overlay {
                            Rectangle()
                                .strokeBorder(
                                    slabEdge(slab, legal: legal),
                                    lineWidth: PanelStyle.gridPadSlabEdge
                                )
                        }
                } else if isAimed {
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

    /// The single tile or cloud the slab is made of, shown beside the map.
    ///
    /// Deliberately bigger than a square on the pad — it is one thing to be
    /// read, not part of the map, and at map scale a wear state is a few pixels
    /// of colour difference.
    private func slabToken(_ slab: GavelSlab, cell: CGFloat) -> some View {
        let side = cell * PanelStyle.gridPadTokenScale

        return VStack(spacing: 0) {
            ZStack {
                if session.visiblePlane == .astra {
                    CloudSpriteView(
                        point: GridPoint(0, 0),
                        health: slab.health,
                        metrics: PixelArtMetrics(
                            availableSide: side * CGFloat(GameRules.gridSize)
                        )
                    )
                } else {
                    // The edge under it, exactly as the board draws one, so a
                    // Terra slab reads as something with thickness.
                    // The front row's drop — nothing sits in front of a token
                    // to hide the usual gap. See `SlabPhantomView`.
                    TileEdgeView(plane: .terra, shade: .light, size: side)
                        .offset(y: GameRules.tileFrontEdgeDrop
                            * (side / CGFloat(GameRules.tilePixelSize)))

                    TileView(
                        tile: Tile(kind: .normal, health: slab.health),
                        plane: .terra,
                        shade: .light,
                        size: side,
                        point: GridPoint(0, 0)
                    )
                }
            }
            .frame(width: side, height: side)
        }
        .frame(width: side, height: side)
        .allowsHitTesting(false)
    }

    /// Every square the slab would cover from where it is currently aimed.
    ///
    /// Computed once per render and asked per square, since the shape does not
    /// change between them.
    private var footprint: Set<GridPoint> {
        guard let slab = session.placingSlab, let target = aim else { return [] }
        return Set(slab.squares(anchoredAt: target))
    }

    /// What the slab's squares are painted.
    ///
    /// **One colour, everywhere it will fit.** It used to run the board's own
    /// ladder — green healthy, yellow cracked, orange badly cracked, black a
    /// hole — on the reasoning that the footprint should say what is about to
    /// be dropped. On a pad that spends the rest of its time saying where you
    /// may and may not go, four colours read as four permissions: the shape
    /// looked refused on some squares and allowed on others when in fact the
    /// Gavel overwrites whatever is there and every square is the same answer.
    ///
    /// What is being dropped is said once, properly, by the token beside the
    /// map — drawn as the tile itself rather than as a swatch — so the map is
    /// left to answer the only question it is being asked. Red is kept for the
    /// one thing that is genuinely refused: a shape hanging off the board.
    private func slabColour(_ slab: GavelSlab, legal: Bool) -> Color {
        legal ? Palette.yellow : Palette.red
    }

    /// Its outline: a darker shade of itself.
    private func slabEdge(_ slab: GavelSlab, legal: Bool) -> Color {
        legal ? Palette.gold : Palette.darkRed
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

    /// The way to walk past an offer. See `PickupChoice.among`.
    private var declineButton: some View {
        CelButton(tint: Palette.stone) {
            session.resolvePickupChoice(.declined)
        } label: {
            Text("STAY")
                .font(.system(size: PanelStyle.gridPadDeclineSize,
                              weight: .heavy, design: .monospaced))
                .tracking(1)
        }
        .frame(width: PanelStyle.gridPadConfirmWidth,
               height: PanelStyle.gridPadConfirmHeight * 0.7)
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
            session.notePlacedSlab(slab, at: target)
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
