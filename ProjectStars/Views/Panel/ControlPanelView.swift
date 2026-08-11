//
//  ControlPanelView.swift
//  Project Stars
//
//  The lower square: controls on the front, the sign's rules on the back.
//

import SwiftUI

/// Everything in the bottom half of the screen.
///
/// ## Two faces on one board
///
/// The panel turns over. The front carries the controls and nothing else; the
/// back carries what the sign does. They are the two sides of one object rather
/// than a sheet sliding over a screen, which is why the whole thing rotates in
/// 3D — the player should feel they turned the board around, and should
/// understand without being told that they cannot play while looking at the back
/// of it.
///
/// ## Why the controls are so bare
///
/// Everything a player needs *while moving* is here and nothing else: where they
/// are pointing, how charged they are, and the three buttons. The sign's rules,
/// the plane, the coin — all of that was on screen permanently and none of it
/// changes fast enough to earn the space. It is one press away instead.
struct ControlPanelView: View {

    let session: GameSession

    /// Edge length of the square, in points.
    let side: CGFloat

    /// How many times the panel has been turned over.
    ///
    /// A count rather than a flag, so the board keeps rotating the *same way*
    /// each time instead of winding back the way it came. Turning something over
    /// and then un-turning it reads as a mistake being undone; turning it again
    /// reads as a board with two sides.
    @State private var turns = 0

    private var showingInfo: Bool { turns.isMultiple(of: 2) == false }

    /// Where the in-progress drag points. Owned here rather than by the input
    /// surface so the stick can react while the finger is still down.
    @State private var liveDirection: SwipeDirection?

    var body: some View {
        ZStack {
            Palette.panel

            // Both faces are always present; the turn hides whichever is facing
            // away. Rebuilding them on every flip would restart the meter's
            // animation and drop the drag mid-gesture.
            face(isVisible: !showingInfo, flip: 0) {
                MainFaceView(
                    session: session,
                    liveDirection: $liveDirection,
                    onInfo: { turn() }
                )
            }

            face(isVisible: showingInfo, flip: 180) {
                ZStack(alignment: .topTrailing) {
                    InfoFaceView(session: session)

                    CelButton(tint: Palette.lightBlue) { turn() } label: {
                        Text("BACK")
                            .font(.system(size: 12, weight: .heavy, design: .rounded))
                            .tracking(1)
                    }
                    .frame(width: 84, height: 40)
                    .padding(GameRules.panelPadding)
                }
            }
        }
        .frame(width: side, height: side)
        .clipped()
    }

    /// One side of the board, turned to face the player or away.
    ///
    /// `.rotation3DEffect` around Y with a little perspective, so it reads as a
    /// solid thing turning rather than a rectangle being squashed. The hidden
    /// face stops taking touches as well as sight — a button on the back of a
    /// board should not be pressable through it.
    private func face<Content: View>(
        isVisible: Bool,
        flip: Double,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .frame(width: side, height: side)
            .opacity(isVisible ? 1 : 0)
            // Around X, so it tips away from the player like a chalkboard on
            // a frame rather than swinging like a door.
            .rotation3DEffect(
                .degrees(Double(turns) * 180 + flip),
                axis: (x: 1, y: 0, z: 0),
                perspective: GameRules.panelTurnPerspective
            )
            .allowsHitTesting(isVisible)
    }

    /// Turns the panel over, and stops the piece taking orders while it is
    /// facing away.
    private func turn() {
        withAnimation(.easeInOut(duration: GameRules.panelTurnDuration)) {
            turns += 1
        }
    }
}

// MARK: - The front

/// The controls, and only the controls.
private struct MainFaceView: View {

    let session: GameSession
    @Binding var liveDirection: SwipeDirection?
    let onInfo: () -> Void

    /// How much of the bottom of the screen belongs to the system.
    ///
    /// Read rather than guessed: it is 34pt on a phone with a home indicator and
    /// 0 on one with a button, and hardcoding either is wrong on the other.
    private var safeArea: CGFloat {
        #if canImport(UIKit)
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow?.safeAreaInsets.bottom }
            .max() ?? 0
        #else
        0
        #endif
    }

    var body: some View {
        ZStack {
            // Scheme A's surface sits *behind* the content as a sibling, never
            // as its ancestor — see `SwipeInputSurface` for why that matters.
            if GameRules.controlScheme == .joystick {
                SwipeInputSurface(
                    isEnabled: session.acceptsInput,
                    liveDirection: $liveDirection,
                    onCommit: { session.submit($0, reach: $1) },
                    onPreview: { session.preview(direction: $0, reach: $1) },
                    onStepForward: { session.stepForward() }
                )
            }

            VStack(spacing: GameRules.panelSpacing) {
                topRow
                Spacer(minLength: 0)
                movement
                Spacer(minLength: 0)
                #if DEBUG
                debugRow
                #endif
                ZodiactionBarView(session: session)
            }
            .padding(.horizontal, GameRules.panelPadding)
            .padding(.top, GameRules.panelPadding)
            // Clear of the home indicator: a button under it is a button the
            // system takes the first touch of.
            .padding(.bottom, GameRules.panelPadding)
            .padding(.bottom, safeArea)
        }
    }

    /// Sign, plane, and the two chrome buttons.
    private var topRow: some View {
        HStack(spacing: 10) {
            SignBadgeView(zodiac: session.zodiac)

            Text(session.zodiac.definition.displayName.uppercased())
                .font(.system(size: 19, weight: .heavy, design: .rounded))
                .tracking(2)
                .foregroundStyle(Palette.gold)
                // One line, never truncated. It shrinks to fit rather than
                // taking the width it wants — `fixedSize` made SAGITTARIUS push
                // the badge off one edge and the buttons off the other.
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .layoutPriority(1)

            Spacer(minLength: 0)

            CelButton(tint: Palette.lightBlue, action: onInfo) {
                Image(systemName: "info")
                    .font(.system(size: 15, weight: .black))
            }
            .frame(width: 44, height: 40)

            CelButton(tint: Palette.stone) { session.togglePause() } label: {
                Image(systemName: "pause.fill")
                    .font(.system(size: 14, weight: .black))
            }
            .frame(width: 44, height: 40)
        }
        // Text opts out so a drag started on it still reaches the surface
        // behind; the buttons stay live.
        .allowsHitTesting(true)
    }

    #if DEBUG
    /// Every sign at once, plus the two look toggles.
    ///
    /// All twelve rather than a stepper: picking the one you want to try is a
    /// glance and a tap, where cycling is a count. Uses the real sign marks, so
    /// it doubles as a look at all twelve of them together.
    ///
    /// Kept out of release builds entirely rather than hidden behind a flag —
    /// the panel is being designed around what the player sees, and a row that
    /// shipped would change that layout.
    private var debugRow: some View {
        VStack(spacing: 6) {
            HStack(spacing: 3) {
                ForEach(Zodiac.allCases) { sign in
                    let isCurrent = sign == session.zodiac

                    Image("Signs/\(sign.rawValue)")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .padding(4)
                        .foregroundStyle(isCurrent ? Palette.warmBlack : Palette.lightGray)
                        .frame(width: 26, height: 26)
                        .background {
                            RoundedRectangle(cornerRadius: 5)
                                .fill(isCurrent ? Palette.gold : Palette.midnight)
                        }
                        .onTapGesture { session.debugSwapSign(to: sign) }
                }
            }

            HStack(spacing: 8) {
                CelButton(tint: Palette.stone) { session.debugCycleControls() } label: {
                    Text("CTRL").font(.system(size: 10, weight: .heavy, design: .monospaced))
                }
                .frame(width: 64, height: 30)

                CelButton(tint: Palette.stone) { session.debugCycleBadge() } label: {
                    Text("BADGE").font(.system(size: 10, weight: .heavy, design: .monospaced))
                }
                .frame(width: 74, height: 30)

                // The keyboard has Z for this; a phone does not.
                CelButton(tint: Palette.stone) { session.debugFillZodiaction() } label: {
                    Text("FILL").font(.system(size: 10, weight: .heavy, design: .monospaced))
                }
                .frame(width: 60, height: 30)
            }
        }
    }
    #endif

    /// Whichever control scheme is in play.
    @ViewBuilder
    private var movement: some View {
        switch GameRules.controlScheme {
        case .joystick:
            JoystickView(direction: liveDirection ?? session.engine.piece.facing,
                         isDragging: liveDirection != nil)
                .allowsHitTesting(false)

        case .buttons:
            DirectionPadView(session: session)
        }
    }
}
