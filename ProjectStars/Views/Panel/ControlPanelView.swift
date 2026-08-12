//
//  ControlPanelView.swift
//  Project Stars
//
//  The lower square: controls on the front, the sign's rules on the back.
//
//  ## How this file is arranged
//
//  Top to bottom in the order the panel is drawn:
//
//  1. `PanelStyle` — every number, in the same order.
//  2. `ControlPanelView` — the square, and the turn between its two faces.
//  3. The front, row by row: the sign, movement, the Zodiaction.
//  4. The pieces those rows are built from, in the order they are used.
//  5. The back.
//  6. The preview.
//
//  It is one file on purpose. Styling a screen means changing a number and
//  looking at the result, and that is miserable when the number, the view it
//  affects and the thing next to it are in three places. `GameRules` holds only
//  what is tuned *after* testing — how the panel behaves, not how it looks.
//

import SwiftUI

/// The panel's styling, in one place, top to bottom.
///
/// ## Why these are here and not in `GameRules`
///
/// `GameRules` is what the *game* does — how far a piece moves, what a coin
/// pays, how long a buff lasts. None of that is here. This is what the panel
/// *looks like*, and styling a screen means changing ten numbers and looking at
/// the result, which is miserable if they live in another file among four
/// hundred rules.
///
/// The two things that are not here are `GameRules.controlScheme` and
/// `GameRules.badgeStyle`, because those change what the panel *is* rather than
/// how it looks, and other code branches on them.
///
/// ## Order
///
/// Top of the panel to the bottom, matching `ControlPanelView`. Find the thing
/// on screen, find it here at the same relative height.
enum PanelStyle {

    // ─────────────────────────────────────────────────────────────────────
    // MARK: The square itself

    /// Breathing room inside the panel, and between its rows.
    static let padding: CGFloat = 14
    static let rowSpacing: CGFloat = 12

    /// How long the panel takes to turn over, and how much perspective the turn
    /// is drawn with. More perspective reads as a smaller, closer object.
    static let turnDuration: TimeInterval = 0.55
    static let turnPerspective: CGFloat = 0.45

    // ─────────────────────────────────────────────────────────────────────
    // MARK: Row 1 — the sign, and the chrome buttons

    /// Space between the badge, the name and the buttons.
    static let topRowSpacing: CGFloat = 10

    /// Height of the sign's mark, and the element's as a fraction of it.
    static let badgeSize: CGFloat = 52
    static let badgeElementScale: CGFloat = 0.82

    /// Gap between the two marks, as a fraction of the sign's.
    static let badgeGap: CGFloat = 0.34

    /// How much of a badge the glyph fills, leaving room for its surround.
    static let badgeGlyphInset: CGFloat = 0.62

    /// The sign's name. It shrinks rather than truncating, so this is the size
    /// it takes when there is room.
    static let signNameSize: CGFloat = 19
    static let signNameTracking: CGFloat = 2
    static let signNameMinScale: CGFloat = 0.5

    /// The info and pause buttons.
    static let chromeButtonWidth: CGFloat = 44
    static let chromeButtonHeight: CGFloat = 40
    static let chromeGlyphSize: CGFloat = 15

    // ─────────────────────────────────────────────────────────────────────
    // MARK: Row 2 — movement

    /// The stick's diameter, and how far its knob leans while a finger is down.
    /// It homes to centre when released.
    static let joystickSize: CGFloat = 108
    static let joystickLean: CGFloat = 0.20

    /// How big the knob is, as a fraction of the well.
    static let joystickKnobScale: CGFloat = 0.52

    /// The four direction hints, at rest and on the one being pushed.
    static let joystickHintDim: Double = 0.28
    static let joystickHintLit: Double = 1
    static let joystickHintSize: CGFloat = 0.11
    static let joystickHintOrbit: CGFloat = 0.40

    /// Edge length of a direction button in the button scheme, the smaller
    /// special-move arrows beside them, and the gaps between.
    static let directionButtonSize: CGFloat = 62
    static let specialArrowScale: CGFloat = 0.62
    static let directionGap: CGFloat = 0.14
    static let specialGap: CGFloat = 4

    // ─────────────────────────────────────────────────────────────────────
    // MARK: Row 3 — the Zodiaction

    /// Height of the fire button, and the gap between its name and its meter.
    static let zodiactionButtonHeight: CGFloat = 78
    static let zodiactionStackSpacing: CGFloat = 5

    /// The Zodiaction's name, and how far it is inset from the button's edges.
    static let zodiactionNameSize: CGFloat = 17
    static let zodiactionNameTracking: CGFloat = 1
    static let zodiactionNameMinScale: CGFloat = 0.55
    static let zodiactionLabelInset: CGFloat = 16

    /// One pip of the meter, and how dim an unfilled one is.
    static let meterPipHeight: CGFloat = 9
    static let meterPipSpacing: CGFloat = 3
    static let meterPipCorner: CGFloat = 2
    static let meterEmptyOpacity: Double = 0.22

    // ─────────────────────────────────────────────────────────────────────
    // MARK: The buttons everything is built from

    /// How far a button's face stands above its rim, and how it is cut.
    static let buttonDepth: CGFloat = 5
    static let buttonCorner: CGFloat = 12

    /// The flat highlight across the top: how far in from the edges, and how
    /// deep. One hard-edged plane, never a gradient.
    static let buttonHighlightInset: CGFloat = 3
    static let buttonHighlightHeight: CGFloat = 10

    /// How quickly a press shows and releases.
    static let buttonPressDuration: TimeInterval = 0.06

    // ─────────────────────────────────────────────────────────────────────
    // MARK: The back of the panel

    /// Spacing between blocks on the info face, and its type sizes.
    static let infoSpacing: CGFloat = 12
    static let infoTitleSize: CGFloat = 17
    static let infoSectionSize: CGFloat = 9
    static let infoNameSize: CGFloat = 13
    static let infoDetailSize: CGFloat = 11

    /// The button that turns the panel back over.
    static let backWidth: CGFloat = 84
    static let backHeight: CGFloat = 40
    static let backLabelSize: CGFloat = 12

    // ─────────────────────────────────────────────────────────────────────
    // MARK: Debug row
    //
    // Never ships, but it is on screen while the panel is being designed, so its
    // numbers belong with the rest rather than buried in an `#if`.

    static let debugSignSize: CGFloat = 26
    static let debugSignSpacing: CGFloat = 3
    static let debugSignCorner: CGFloat = 5
    static let debugRowSpacing: CGFloat = 6
    static let debugButtonHeight: CGFloat = 30
    static let debugLabelSize: CGFloat = 10
}

// MARK: - The square

/// Everything in the bottom half of the screen.
///
/// ## Two faces on one board
///
/// The panel turns over. The front carries the controls and nothing else; the
/// back carries what the sign does. They are two sides of one object rather than
/// a sheet sliding over a screen, which is why the whole thing rotates in 3D —
/// the player should feel they turned the board around, and should understand
/// without being told that they cannot play while looking at the back of it.
///
/// ## Why the front is so bare
///
/// Everything a player needs *while moving* and nothing else: where they are
/// pointing, how charged they are, and three buttons. The sign's rules were on
/// screen permanently and do not change fast enough to earn the space.
struct ControlPanelView: View {

    let session: GameSession

    /// Edge length of the square, in points.
    let side: CGFloat

    /// How many times the panel has been turned over.
    ///
    /// A count rather than a flag, so the board keeps rotating the *same way*
    /// each time instead of winding back. Turning something over and then
    /// un-turning it reads as a mistake being undone; turning it again reads as
    /// a board with two sides.
    @State private var turns = 0

    /// Where the in-progress drag points. Owned here rather than by the input
    /// surface so the stick can react while the finger is still down.
    @State private var liveDirection: SwipeDirection?

    private var showingInfo: Bool { !turns.isMultiple(of: 2) }

    var body: some View {
        ZStack {
            Palette.panel

            // Both faces stay mounted; the turn hides whichever faces away.
            // Rebuilding them on every flip would restart the meter's animation
            // and drop the drag mid-gesture.
            face(isVisible: !showingInfo, flip: 0) {
                PanelFrontView(
                    session: session,
                    liveDirection: $liveDirection,
                    onInfo: turn
                )
            }

            face(isVisible: showingInfo, flip: 180) {
                PanelBackView(session: session, onBack: turn)
            }
        }
        .frame(width: side, height: side)
        .clipped()
    }

    /// One side of the board, turned to face the player or away.
    ///
    /// Around X, so it tips away like a chalkboard on a frame rather than
    /// swinging like a door. The hidden face stops taking touches as well as
    /// sight — a button on the back of a board should not be pressable through
    /// it.
    private func face<Content: View>(
        isVisible: Bool,
        flip: Double,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .frame(width: side, height: side)
            .opacity(isVisible ? 1 : 0)
            .rotation3DEffect(
                .degrees(Double(turns) * 180 + flip),
                axis: (x: 1, y: 0, z: 0),
                perspective: PanelStyle.turnPerspective
            )
            .allowsHitTesting(isVisible)
    }

    private func turn() {
        withAnimation(.easeInOut(duration: PanelStyle.turnDuration)) { turns += 1 }
    }
}

// MARK: - The front

/// The controls, in the order they appear on screen.
private struct PanelFrontView: View {

    let session: GameSession
    @Binding var liveDirection: SwipeDirection?
    let onInfo: () -> Void

    var body: some View {
        ZStack {
            // The drag surface sits *behind* the content as a sibling, never as
            // its ancestor — see `SwipeInputSurface` for why that matters.
            if GameRules.controlScheme == .joystick {
                SwipeInputSurface(
                    isEnabled: session.acceptsInput,
                    liveDirection: $liveDirection,
                    onCommit: { session.submit($0, reach: $1) },
                    onPreview: { session.preview(direction: $0, reach: $1) },
                    onStepForward: { session.stepForward() }
                )
            }

            VStack(spacing: PanelStyle.rowSpacing) {
                signRow
                Spacer(minLength: 0)
                movementRow
                Spacer(minLength: 0)
                #if DEBUG
                debugRow
                #endif
                zodiactionRow
            }
            .padding(.horizontal, PanelStyle.padding)
            .padding(.top, PanelStyle.padding)
            // Clear of the home indicator: a button under it is a button the
            // system takes the first touch of.
            .padding(.bottom, PanelStyle.padding + safeArea)
        }
    }

    // ── Row 1: the sign ───────────────────────────────────────────────────

    private var signRow: some View {
        HStack(spacing: PanelStyle.topRowSpacing) {
            SignBadge(zodiac: session.zodiac)

            Text(session.zodiac.definition.displayName.uppercased())
                .font(.system(size: PanelStyle.signNameSize, weight: .heavy, design: .rounded))
                .tracking(PanelStyle.signNameTracking)
                .foregroundStyle(Palette.gold)
                // One line, never truncated: it shrinks rather than taking the
                // width it wants and shoving the row off screen.
                .lineLimit(1)
                .minimumScaleFactor(PanelStyle.signNameMinScale)
                .layoutPriority(1)

            Spacer(minLength: 0)

            chromeButton("info", tint: Palette.lightBlue, action: onInfo)
            chromeButton("pause.fill", tint: Palette.stone) { session.togglePause() }
        }
    }

    private func chromeButton(
        _ systemImage: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        CelButton(tint: tint, action: action) {
            Image(systemName: systemImage)
                .font(.system(size: PanelStyle.chromeGlyphSize, weight: .black))
        }
        .frame(width: PanelStyle.chromeButtonWidth, height: PanelStyle.chromeButtonHeight)
    }

    // ── Row 2: movement ───────────────────────────────────────────────────

    @ViewBuilder
    private var movementRow: some View {
        switch GameRules.controlScheme {
        case .joystick:
            Joystick(
                direction: liveDirection ?? session.engine.piece.facing,
                isDragging: liveDirection != nil
            )
            .allowsHitTesting(false)

        case .buttons:
            DirectionPad(session: session)
        }
    }

    // ── Row 3: the Zodiaction ─────────────────────────────────────────────

    private var zodiactionRow: some View {
        ZodiactionButton(session: session)
    }

    // ── Debug ─────────────────────────────────────────────────────────────

    #if DEBUG
    /// Every sign at once, plus the two look toggles.
    ///
    /// All twelve rather than a stepper: picking the one you want is a glance
    /// and a tap, where cycling is a count. Drawn with the real marks, so it
    /// doubles as a look at all twelve together. Never ships.
    private var debugRow: some View {
        VStack(spacing: PanelStyle.debugRowSpacing) {
            HStack(spacing: PanelStyle.debugSignSpacing) {
                ForEach(Zodiac.allCases) { sign in
                    let isCurrent = sign == session.zodiac

                    Image("Signs/\(sign.rawValue)")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .padding(4)
                        .foregroundStyle(isCurrent ? Palette.warmBlack : Palette.lightGray)
                        .frame(width: PanelStyle.debugSignSize, height: PanelStyle.debugSignSize)
                        .background {
                            RoundedRectangle(cornerRadius: PanelStyle.debugSignCorner)
                                .fill(isCurrent ? Palette.gold : Palette.midnight)
                        }
                        .onTapGesture { session.debugSwapSign(to: sign) }
                }
            }

            HStack(spacing: 8) {
                debugButton("CTRL", width: 64) { session.debugCycleControls() }
                debugButton("BADGE", width: 74) { session.debugCycleBadge() }
            }
        }
    }

    private func debugButton(
        _ title: String,
        width: CGFloat,
        action: @escaping () -> Void
    ) -> some View {
        CelButton(tint: Palette.stone, action: action) {
            Text(title)
                .font(.system(size: PanelStyle.debugLabelSize, weight: .heavy, design: .monospaced))
        }
        .frame(width: width, height: PanelStyle.debugButtonHeight)
    }
    #endif

    /// How much of the bottom of the screen belongs to the system.
    ///
    /// Read rather than guessed: 34pt on a phone with a home indicator, 0 on one
    /// with a button, and hardcoding either is wrong on the other.
    private var safeArea: CGFloat {
        #if canImport(UIKit)
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow?.safeAreaInsets.bottom }
            .max() ?? 0
        #else
        0
        #endif
    }
}

// MARK: - Row 1: the sign's marks

/// The sign's mark and its element's, drawn from the flat vector icons.
///
/// ## Why three treatments
///
/// The icons are deliberately flat monochrome so presentation is a separate
/// decision from the art. Which reads best on a phone, against a dark panel, at
/// a glance, is a thing to be looked at rather than reasoned out — so all three
/// are here, switched by `GameRules.badgeStyle`.
///
/// The element is never named in words. It is one of four marks a player learns
/// in a minute, and spelling it out costs a line of panel forever to save a
/// minute once.
struct SignBadge: View {

    let zodiac: Zodiac
    var size: CGFloat = PanelStyle.badgeSize

    var body: some View {
        HStack(spacing: size * PanelStyle.badgeGap) {
            mark(Image("Signs/\(zodiac.rawValue)"), tint: Palette.gold, side: size)
            mark(
                Image("Elements/\(zodiac.element.rawValue)"),
                tint: ElementFX.ramp(for: zodiac.element).bright,
                side: size * PanelStyle.badgeElementScale
            )
        }
    }

    @ViewBuilder
    private func mark(_ icon: Image, tint: Color, side: CGFloat) -> some View {
        // `.template` is what lets a flat vector take a palette entry rather
        // than whatever it was exported as — the whole reason they are drawn
        // monochrome.
        let glyph = icon
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: side * PanelStyle.badgeGlyphInset,
                   height: side * PanelStyle.badgeGlyphInset)
            .foregroundStyle(tint)

        switch GameRules.badgeStyle {
        case .flat:
            glyph.frame(width: side, height: side)

        case .emblem:
            // Struck into a coin, using the same flat planes the buttons do.
            ZStack {
                Circle().fill(Palette.gold.celShadow)
                Circle().fill(Palette.gold).padding(side * 0.09)
                glyph
            }
            .frame(width: side, height: side)

        case .constellationPlate:
            // A dark plate with the mark lit on it, like a window onto the sky —
            // which is what the board above already is.
            ZStack {
                RoundedRectangle(cornerRadius: side * 0.26).fill(Palette.midnight)
                RoundedRectangle(cornerRadius: side * 0.26)
                    .strokeBorder(Palette.gold, lineWidth: max(1, side * 0.05))
                glyph
            }
            .frame(width: side, height: side)
        }
    }
}

// MARK: - Row 2: the joystick

/// A golden stick that leans the way the piece is about to go.
///
/// Not an input control — the whole panel is the input surface, and this reports
/// what it is hearing. Which is the honest arrangement for a thumb-sized target:
/// the player drags anywhere comfortable and this says what that meant, rather
/// than asking them to find and hold a small circle.
struct Joystick: View {

    /// Where the drag points, or the piece's facing when nobody is dragging.
    let direction: SwipeDirection

    /// True while a finger is down, which is when the stick commits to a lean.
    let isDragging: Bool

    var body: some View {
        let side = PanelStyle.joystickSize
        let step = direction.unitOffset

        // Homes when released. A stick left leaning where the last drag ended
        // looks stuck; one that returns to centre is obviously a control at
        // rest, and the piece's facing is already shown by the piece.
        let lean = isDragging ? PanelStyle.joystickLean : 0

        ZStack {
            Circle()
                .fill(Palette.midnight)
                .frame(width: side, height: side)

            Circle()
                .strokeBorder(Palette.dusk, lineWidth: max(2, side * 0.03))
                .frame(width: side, height: side)

            // Four faint arrows, so it reads as a thing you push without being
            // mistaken for four buttons. The one being pushed lights up.
            ForEach(SwipeDirection.allCases) { hint in
                Image(systemName: "arrowtriangle.up.fill")
                    .font(.system(size: side * PanelStyle.joystickHintSize, weight: .black))
                    .foregroundStyle(Palette.gold)
                    .opacity(isDragging && hint == direction
                        ? PanelStyle.joystickHintLit
                        : PanelStyle.joystickHintDim)
                    .offset(y: -side * PanelStyle.joystickHintOrbit)
                    .rotationEffect(.degrees(hint.iconRotation))
            }

            // The knob, with its own rim under it so it stands out of the well
            // rather than being painted on.
            ZStack {
                Circle().fill(Palette.gold.celShadow).offset(y: PanelStyle.buttonDepth)
                Circle().fill(Palette.gold)
                Circle()
                    .fill(Palette.gold.celHighlight)
                    .padding(side * 0.14)
                    .mask(alignment: .top) { Rectangle().frame(maxHeight: side * 0.12) }
            }
            .frame(width: side * PanelStyle.joystickKnobScale,
                   height: side * PanelStyle.joystickKnobScale)
            .offset(x: CGFloat(step.dx) * side * lean, y: CGFloat(step.dy) * side * lean)
        }
        .animation(.spring(response: 0.18, dampingFraction: 0.7), value: direction)
        .animation(.spring(response: 0.22, dampingFraction: 0.75), value: isDragging)
    }
}

// MARK: - Row 2: the direction pad

/// A keyboard cross of direction buttons, with a sign's special moves beside
/// them.
///
/// ## Why a keyboard cross rather than a diamond
///
/// Up on its own row, then left/down/right together. It is the shape every
/// keyboard already uses, it is what a thumb expects, and it costs one row less
/// than a diamond — which on a phone is the difference between buttons being big
/// enough and not.
///
/// ## Why the special moves are separate buttons
///
/// A sign with a two-square sidestep cannot express that with a tap: the
/// direction is the same, only the distance differs. The joystick gets it from
/// how far the drag went; here it needs its own button, so the longer move
/// appears as a smaller arrow beside the direction it extends — present only
/// when that sign can actually make it.
struct DirectionPad: View {

    let session: GameSession

    var body: some View {
        VStack(spacing: PanelStyle.directionButtonSize * PanelStyle.directionGap) {
            row([.up])
            row([.left, .down, .right])
        }
    }

    private func row(_ directions: [SwipeDirection]) -> some View {
        HStack(spacing: PanelStyle.directionButtonSize * PanelStyle.directionGap) {
            ForEach(directions) { direction in
                HStack(spacing: PanelStyle.specialGap) {
                    button(direction)
                    special(direction)
                }
            }
        }
    }

    /// The ordinary one-square move.
    private func button(_ direction: SwipeDirection) -> some View {
        CelButton(isEnabled: session.acceptsInput) {
            session.submit(direction, reach: 0)
        } label: {
            arrow(direction, tint: Palette.warmBlack)
                .frame(width: PanelStyle.directionButtonSize * 0.46,
                       height: PanelStyle.directionButtonSize * 0.46)
        }
        .frame(width: PanelStyle.directionButtonSize, height: PanelStyle.directionButtonSize)
    }

    /// The sign's longer move that way, when it has one.
    @ViewBuilder
    private func special(_ direction: SwipeDirection) -> some View {
        if let reach = session.specialReach(for: direction) {
            let side = PanelStyle.directionButtonSize * PanelStyle.specialArrowScale

            CelButton(tint: Palette.lightBlue, isEnabled: session.acceptsInput) {
                session.submit(direction, reach: reach)
            } label: {
                arrow(direction, tint: Palette.midnight)
                    .frame(width: side * 0.5, height: side * 0.5)
            }
            .frame(width: side, height: side)
        }
    }

    /// One sprite rotated rather than four, which is also how the sheet is laid
    /// out — the cursor's brackets do the same thing.
    private func arrow(_ direction: SwipeDirection, tint: Color) -> some View {
        PixelSprite(id: .directionArrow(direction)) {
            Image(systemName: "arrowtriangle.up.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(tint)
                .rotationEffect(.degrees(direction.iconRotation))
        }
    }
}

/// Degrees to turn an up-pointing arrow by.
extension SwipeDirection {
    var iconRotation: Double {
        switch self {
        case .up: 0
        case .right: 90
        case .down: 180
        case .left: 270
        }
    }
}

// MARK: - Row 3: the Zodiaction

/// The Zodiaction button: its name, and how charged it is, as one control.
///
/// ## Why the meter is inside the button
///
/// They are the same fact. A separate bar above a separate button asks the
/// player to connect two things that are always about each other; putting the
/// charge *on* the thing it charges says it once.
///
/// The button names the Zodiaction and nothing else. What it does is on the back
/// of the panel and on the selection screen — mid-run a player needs to know it
/// is ready and what it is called.
struct ZodiactionButton: View {

    let session: GameSession

    var body: some View {
        // Read from the session rather than reaching into the engine, so the
        // button tracks the meter however it changed — including from a debug
        // key, which is where it was previously found lagging.
        let ready = session.isZodiactionReady

        CelButton(
            tint: ready ? Palette.yellow : Palette.stone,
            isEnabled: ready && session.acceptsInput
        ) {
            session.fireZodiaction()
        } label: {
            VStack(spacing: PanelStyle.zodiactionStackSpacing) {
                Text(session.zodiac.definition.zodiaction.displayName.uppercased())
                    .font(.system(size: PanelStyle.zodiactionNameSize,
                                  weight: .heavy, design: .rounded))
                    .tracking(PanelStyle.zodiactionNameTracking)
                    .minimumScaleFactor(PanelStyle.zodiactionNameMinScale)
                    .lineLimit(1)

                meter
            }
            .padding(.horizontal, PanelStyle.zodiactionLabelInset)
        }
        .frame(height: PanelStyle.zodiactionButtonHeight)
    }

    /// Pips rather than a bar: the meter is a whole number of charges and the
    /// player counts them, which a continuous fill hides.
    ///
    /// Charged pips take the sign's element, so the meter says *whose* charge it
    /// is as well as how much — the same colour the piece wears when full.
    private var meter: some View {
        let filled = session.zodiactionMeter
        let charged = ElementFX.ramp(for: session.zodiac.element).mid

        return HStack(spacing: PanelStyle.meterPipSpacing) {
            ForEach(0..<session.zodiactionMeterMax, id: \.self) { index in
                RoundedRectangle(cornerRadius: PanelStyle.meterPipCorner)
                    .fill(index < filled
                        ? charged
                        : Palette.warmBlack.opacity(PanelStyle.meterEmptyOpacity))
                    .frame(height: PanelStyle.meterPipHeight)
            }
        }
        .animation(.easeOut(duration: 0.18), value: filled)
    }
}

// MARK: - The button everything is built from

/// A big, obviously-pressable button drawn the way the game is drawn.
///
/// ## Why no gradients
///
/// The game is a fixed 47-colour palette and pixel art. A gradient is thousands
/// of colours none of which are in it, and it reads as a different piece of
/// software sitting under the board. Depth here comes from *flat planes* at
/// different tones — a lit face, a darker rim, a highlight — which is how the
/// pieces themselves are shaded.
///
/// ## Why the press moves it
///
/// The lift is real: the face sits `depth` above the rim, and pressing drops it
/// onto it. Nothing fades, nothing dims — the button physically goes down, which
/// on a phone is the clearest confirmation that a touch landed.
struct CelButton<Label: View>: View {

    var tint: Color = Palette.gold
    var depth: CGFloat = PanelStyle.buttonDepth
    var isEnabled: Bool = true

    let action: () -> Void
    @ViewBuilder let label: () -> Label

    @State private var isPressed = false

    var body: some View {
        let face = isEnabled ? tint : Palette.gray

        ZStack {
            // The rim, standing proud below the face. Its own shape rather than
            // a border, so the button has a genuine side.
            RoundedRectangle(cornerRadius: PanelStyle.buttonCorner)
                .fill(face.celShadow)
                .offset(y: depth)

            RoundedRectangle(cornerRadius: PanelStyle.buttonCorner)
                .fill(face)
                .overlay {
                    // One hard-edged lighter plane across the top, not a sheen.
                    RoundedRectangle(cornerRadius: PanelStyle.buttonCorner)
                        .fill(face.celHighlight)
                        .padding(PanelStyle.buttonHighlightInset)
                        .mask(alignment: .top) {
                            Rectangle().frame(maxHeight: PanelStyle.buttonHighlightHeight)
                        }
                }
                .offset(y: isPressed ? depth : 0)

            label()
                .foregroundStyle(isEnabled ? Palette.warmBlack : Palette.darkGray)
                .offset(y: isPressed ? depth : 0)
        }
        .animation(.easeOut(duration: PanelStyle.buttonPressDuration), value: isPressed)
        .contentShape(Rectangle())
        .onTapGesture { if isEnabled { action() } }
        // A press has to show the instant the finger lands, which a tap gesture
        // alone cannot do — it only reports once the tap completes.
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in if isEnabled { isPressed = true } }
                .onEnded { _ in isPressed = false }
        )
        .disabled(!isEnabled)
    }
}

/// Flat shading for a face: one step lighter, one step darker.
///
/// Looked up in the palette rather than computed — darkening a colour
/// arithmetically lands between entries, and the whole point of a fixed palette
/// is that nothing does. See `PaletteRamp`.
extension Color {
    var celShadow: Color { PaletteRamp.darker(self) }
    var celHighlight: Color { PaletteRamp.lighter(self) }
}

// MARK: - The back

/// The sign's rules, with the way back.
private struct PanelBackView: View {

    let session: GameSession
    let onBack: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            rules

            CelButton(tint: Palette.lightBlue, action: onBack) {
                Text("BACK")
                    .font(.system(size: PanelStyle.backLabelSize, weight: .heavy, design: .rounded))
                    .tracking(1)
            }
            .frame(width: PanelStyle.backWidth, height: PanelStyle.backHeight)
            .padding(PanelStyle.padding)
        }
    }

    /// Everything about the sign in play.
    ///
    /// The old panel carried this at all times, which squeezed the controls
    /// around something a player reads twice and then never again. This is the
    /// fighting-game answer: the move list is one press away and you stop
    /// playing to read it. The same text is on the selection screen, so nobody
    /// meets a sign here for the first time.
    private var rules: some View {
        VStack(alignment: .leading, spacing: PanelStyle.infoSpacing) {
            HStack(spacing: 10) {
                SignBadge(zodiac: session.zodiac)
                Text(session.zodiac.definition.displayName.uppercased())
                    .font(.system(size: PanelStyle.infoTitleSize, weight: .heavy, design: .rounded))
                    .tracking(2)
                    .foregroundStyle(Palette.gold)
            }

            let definition = session.zodiac.definition

            entry("MOVEMENT", definition.movement.name, definition.movement.summary)
            entry("ZODIACTION", definition.zodiaction.displayName, definition.zodiaction.summary)

            ForEach(Array(definition.passives.enumerated()), id: \.offset) { index, passive in
                entry(index == 0 ? "PASSIVES" : nil, passive.displayName, passive.summary)
            }

            Spacer(minLength: 0)
        }
        .padding(PanelStyle.padding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// One titled block. The section label appears only on the first of a run,
    /// so three passives read as one list rather than three headings.
    @ViewBuilder
    private func entry(_ section: String?, _ name: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            if let section {
                Text(section)
                    .font(.system(size: PanelStyle.infoSectionSize,
                                  weight: .heavy, design: .monospaced))
                    .tracking(3)
                    .foregroundStyle(Palette.lightBlue)
                    .padding(.bottom, 2)
            }

            Text(name)
                .font(.system(size: PanelStyle.infoNameSize, weight: .bold, design: .rounded))
                .foregroundStyle(Palette.white)

            Text(detail)
                .font(.system(size: PanelStyle.infoDetailSize, design: .rounded))
                .foregroundStyle(Palette.lightGray)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Preview

/// The panel at the size it really gets, with everything worth switching.
#Preview("Control panel") {
    ControlPanelPreview()
}

/// The panel, plus the controls for looking at its variants.
struct ControlPanelPreview: View {

    @State private var session = GameSession(zodiac: .sagittarius)
    @State private var scheme = GameRules.controlScheme
    @State private var badge = GameRules.badgeStyle

    /// A phone's width, since the board and the panel are two squares stacked.
    var side: CGFloat = 393

    var body: some View {
        VStack(spacing: 14) {
            Text("CONTROL PANEL")
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .tracking(4)
                .foregroundStyle(Palette.textSecondary)

            ControlPanelView(session: session, side: side)
                .border(Palette.outline)

            VStack(spacing: 10) {
                Picker("Controls", selection: $scheme) {
                    Text("JOYSTICK").tag(GameRules.ControlScheme.joystick)
                    Text("BUTTONS").tag(GameRules.ControlScheme.buttons)
                }
                .pickerStyle(.segmented)

                Picker("Badge", selection: $badge) {
                    Text("FLAT").tag(GameRules.BadgeStyle.flat)
                    Text("EMBLEM").tag(GameRules.BadgeStyle.emblem)
                    Text("PLATE").tag(GameRules.BadgeStyle.constellationPlate)
                }
                .pickerStyle(.segmented)

                // The two shortcuts are debug-only, so this is too — a
                // preview still compiles in Release.
                #if DEBUG
                HStack(spacing: 12) {
                    Button("FILL METER") { session.debugFillZodiaction() }
                    Button("NEXT SIGN") { nextSign() }
                }
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                #endif
            }
            .padding(.horizontal, 24)
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.background)
        // The two choices are global rather than per-view, so the preview writes
        // them and redraws — the same way the debug buttons work on a device.
        .onChange(of: scheme) { GameRules.controlScheme = scheme }
        .onChange(of: badge) { GameRules.badgeStyle = badge }
    }

    #if DEBUG
    private func nextSign() {
        let all = Zodiac.allCases
        let index = all.firstIndex(of: session.zodiac) ?? 0
        session.debugSwapSign(to: all[(index + 1) % all.count])
    }
    #endif
}
