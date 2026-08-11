//
//  ControlPanelView.swift
//  Project Stars
//
//  The lower square: information above, input below.
//

import SwiftUI

/// Everything in the bottom half of the screen.
///
/// Doubles as the input zone — the entire square accepts the swipe gesture, so
/// the player's thumb never covers the board. Information is laid out above the
/// thumb's natural resting area and the swipe hint sits directly under it.
struct ControlPanelView: View {

    let session: GameSession

    /// Edge length of the square, in points.
    let side: CGFloat

    /// Where the in-progress drag points. Owned here rather than by the input
    /// surface so the direction hint can react while the finger is still down.
    @State private var liveDirection: SwipeDirection?

    var body: some View {
        ZStack {
            Palette.panel

            // The swipe surface sits *behind* the content as a sibling, never as
            // its ancestor — see `SwipeInputSurface` for why that matters.
            SwipeInputSurface(
                isEnabled: session.acceptsInput,
                liveDirection: $liveDirection,
                onCommit: { session.submit($0, reach: $1) },
                onPreview: { session.preview(direction: $0, reach: $1) },
                onZodiaction: { session.fireZodiaction() },
                onStepForward: { session.stepForward() }
            )

            VStack(spacing: 10) {
                // Everything read-only opts out of hit testing so drags started
                // on top of it still reach the surface behind. Only real
                // controls stay interactive.
                HUDView(session: session)
                    .allowsHitTesting(false)

                Divider()
                    .overlay(Palette.outline)
                    .allowsHitTesting(false)

                infoRow
                    .allowsHitTesting(false)

                // Interactive: contains the super's fire button.
                ZodiactionMeterView(session: session)

                Spacer(minLength: 4)

                swipeZone(liveDirection: liveDirection)
                    .allowsHitTesting(false)

                #if DEBUG
                developerSignPicker
                #endif
            }
            .padding(14)

            // Pause lives down here with the rest of the controls rather than on
            // the board. The board half is the thing being looked at; the panel
            // is the thing being touched.
            PauseButton { session.togglePause() }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(10)
        }
        .frame(width: side, height: side)
        .overlay(
            Rectangle()
                .strokeBorder(Palette.outline, lineWidth: 1)
                .allowsHitTesting(false)
        )
    }

    // MARK: - Information

    /// Piece on the left, pickup status and the plane-below preview on the right.
    private var infoRow: some View {
        HStack(alignment: .top, spacing: 12) {
            pieceCard
            Spacer(minLength: 0)
            statusColumn
        }
    }

    private var pieceCard: some View {
        let definition = session.zodiac.definition
        let empowered = definition.empoweredPlane == session.visiblePlane

        return HStack(alignment: .top, spacing: 8) {
            PieceIconView(zodiac: definition.sign, size: 34)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(definition.displayName.uppercased())
                        .font(.system(size: 13, weight: .heavy, design: .monospaced))
                        .foregroundStyle(Palette.textPrimary)

                    // Signs are stronger on one plane than the other, so the
                    // panel says which side of that split you are on right now.
                    if empowered {
                        Text("STRONG")
                            .font(.system(size: 7, weight: .heavy, design: .monospaced))
                            .foregroundStyle(Palette.background)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(definition.accentColor))
                    }
                }

                Text("\(definition.element.displayName) · \(definition.movement.name)")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(Palette.textSecondary)

                // Every passive the sign carries — two or three. All are
                // placeholders right now; showing them keeps the slots visible
                // while the designs are written.
                ForEach(Array(definition.passives.enumerated()), id: \.offset) { _, passive in
                    Text("· \(passive.summary)")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(Palette.textSecondary.opacity(0.8))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var statusColumn: some View {
        VStack(alignment: .trailing, spacing: 6) {
            pickupStatus

            // Only meaningful on Astra — on Terra there is nothing below.
            if let below = session.boardBelow, let plane = session.planeBelow {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("BELOW")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(Palette.textSecondary)
                    MiniBoardView(
                        board: below,
                        plane: plane,
                        side: 52,
                        highlight: session.engine.piece.point
                    )
                }
            }
        }
    }

    /// Reflects which half of the cycle the board is in: sparkles out and the
    /// pickup hidden, or sparkles gone and the pickup on the board.
    private var pickupStatus: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text("PENTACLE")
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(Palette.textSecondary)

            if !session.visiblePickups.isEmpty {
                // Pentacle phase. The coin is on the board but sealed, so the
                // panel must not name what is inside it either.
                Text("ON BOARD")
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    .foregroundStyle(Palette.pentacle)
            } else if let sparkles = session.visibleSparkles {
                // Sparkle phase: the player only learns the shape of the search,
                // and whether the shape came out broken.
                Text("\(sparkles.pattern.symbol) \(sparkles.pattern.displayName.uppercased())")
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    .foregroundStyle(Palette.sparkle)

                if sparkles.isPartial {
                    Text("\(sparkles.points.count) TILES")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(Palette.sparkle.opacity(0.7))
                }
            } else {
                Text("—")
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    .foregroundStyle(Palette.textSecondary)
            }
        }
    }

    // MARK: - Input zone

    /// The swipe affordance. Highlights the direction the current drag resolves
    /// to, and dims any direction with no legal destination.
    /// The line above the compass, saying what the zone is currently for.
    private var hintText: String {
        guard session.acceptsInput else { return "…" }
        return session.engine.isZodiactionReady
            ? "SWIPE TO MOVE · HOLD TO POP"
            : "SWIPE TO MOVE"
    }

    private func swipeZone(liveDirection: SwipeDirection?) -> some View {
        let legal = session.engine.legalDestinations
        let options = session.previewOptions

        return VStack(spacing: 6) {
            Text(hintText)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(2)
                .foregroundStyle(Palette.textSecondary)

            // A simple compass. This is a *hint*, not a control — the gesture is
            // on the whole square, not on these glyphs.
            HStack(spacing: 18) {
                ForEach(SwipeDirection.allCases) { direction in
                    let isLive = liveDirection == direction
                    let isLegal = legal[direction] != nil

                    PixelSprite(id: .directionArrow(direction)) {
                        Text(direction.arrow)
                            .font(.system(size: 26, weight: .bold, design: .monospaced))
                            .foregroundStyle(Palette.textSecondary)
                    }
                    .frame(width: 26, height: 26)
                    // The arrows are drawn white; the state they are in is said
                    // with brightness and scale rather than by recolouring them,
                    // since the palette is fixed and there is only one arrow set.
                    .opacity(isLive ? 1 : (isLegal ? 0.7 : 0.25))
                    .scaleEffect(isLive ? 1.25 : 1)
                    .animation(.spring(response: 0.2, dampingFraction: 0.6), value: liveDirection)
                }
            }

            // Distance selector, for the signs that have a choice to make.
            //
            // The cursor on the board already previews the destination, but the
            // board is at the top of the screen and the thumb is at the bottom —
            // watching one while dragging the other is what made picking an exact
            // move hard. This puts the same information under the finger.
            if options.count > 1 {
                reachSelector(options: options)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Palette.background.opacity(0.5))
        )
        .animation(.easeOut(duration: 0.12), value: options.count)
    }

    /// One chip per available distance, the selected one lit.
    ///
    /// Labelled with both the distance and how it travels, because for
    /// Sagittarius the difference between a two-square stride and a three-square
    /// leap is not the range — it is that one wears everything it crosses and the
    /// other wears nothing.
    private func reachSelector(options: [MovementPattern.MoveOption]) -> some View {
        let accent = session.zodiac.definition.accentColor
        let selected = session.previewOptionIndex

        return HStack(spacing: 5) {
            ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                let isSelected = index == selected

                VStack(spacing: 0) {
                    Text("\(option.distance)")
                        .font(.system(size: 13, weight: .heavy, design: .monospaced))
                    Text(option.style == .jump ? "LEAP" : "STEP")
                        .font(.system(size: 6, weight: .bold, design: .monospaced))
                }
                .foregroundStyle(isSelected ? Palette.background : Palette.textSecondary)
                .frame(width: 34, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected ? accent : Palette.panel.opacity(0.9))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(isSelected ? accent : Palette.outline, lineWidth: 1)
                )
                .scaleEffect(isSelected ? 1.08 : 1)
            }

            Text("DRAG FURTHER")
                .font(.system(size: 6, weight: .bold, design: .monospaced))
                .foregroundStyle(Palette.textSecondary.opacity(0.7))
                .padding(.leading, 2)
        }
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: selected)
        .transition(.opacity)
    }

    // MARK: - Dev
    //
    // Not part of the game. A quick way to see all twelve signs on the board
    // while the real piece-selection flow does not exist yet. Delete this whole
    // section once it does.

    #if DEBUG
    private var developerSignPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(Zodiac.allCases) { sign in
                    Button {
                        session.newGame(zodiac: sign)
                    } label: {
                        Text(sign.glyph.monochromeGlyph)
                            .font(.system(size: 15))
                            .foregroundStyle(
                                sign == session.zodiac ? Palette.textPrimary : Palette.textSecondary
                            )
                            .frame(width: 26, height: 22)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(sign == session.zodiac
                                          ? sign.definition.accentColor.opacity(0.4)
                                          : Palette.background.opacity(0.5))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    #endif
}
