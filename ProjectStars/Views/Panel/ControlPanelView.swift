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
/// The one thing that is not here is `GameRules.controlScheme`, because it
/// changes what the panel *is* rather than how it looks, and other code branches
/// on it.
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

    /// The sign's own mark, drawn large and faint behind the row.
    ///
    /// A watermark rather than an icon: at this size it is texture, and the name
    /// beside it is what actually identifies the sign. Its tint and opacity are
    /// what keep it from competing with the text over it.
    static let signWatermarkSize: CGFloat = 150
    static let signWatermarkOpacity: Double = 0.33
    static let signWatermarkTint = Palette.outline

    /// The element's mark, small and lit, at full strength.
    static let elementMarkSize: CGFloat = 28

    /// How much of a mark's box the glyph fills.
    static let markInset: CGFloat = 0.62

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
    //
    // Both schemes are given the same height, so switching between them cannot
    // move anything else on the panel.

    /// The room movement gets, whichever scheme is in play.
    static let movementRowHeight: CGFloat = 150

    // ── The joystick ──────────────────────────────────────────────────────

    /// The well's diameter, and the knob as a fraction of it.
    static let joystickSize: CGFloat = 108
    static let joystickKnobScale: CGFloat = 0.52

    /// The flat core behind the knob, which shows around it as it leans.
    static let joystickCoreScale: CGFloat = 0.33

    /// How far the knob leans while a finger is down, as a fraction of the well,
    /// and how far it sits above centre at rest.
    static let joystickLean: CGFloat = 0.20
    static let joystickKnobRise: CGFloat = 7

    /// The rim, and what it becomes while being dragged.
    static let joystickRimWidth: CGFloat = 0.03
    static let joystickRimColour = Palette.dusk
    static let joystickRimActive = Palette.magenta

    // ── The direction guide ───────────────────────────────────────────────
    //
    // One guide per direction, sitting outside the well: an arrow for the
    // ordinary step, and above it a chevron for the sign's longer move that way.
    // The chevron is only drawn where such a move exists.

    /// How far out from the centre a guide sits, as a fraction of the well.
    static let guideOrbit: CGFloat = 0.40

    /// The ordinary-step arrow, and the longer-move chevron above it.
    static let guideArrowSize = CGSize(width: 30, height: 12.5)
    static let guideChevronSize = CGSize(width: 25, height: 15)
    static let guideSpacing: CGFloat = 2

    /// Arrow colours: the direction being pushed, and the rest.
    static let guideArrowLit = Palette.lightBlue
    static let guideArrowDim = Palette.blue

    /// Chevron colours: lit only once the drag has passed the ordinary step.
    static let guideChevronLit = Palette.magenta
    static let guideChevronDim = Palette.plum

    /// Overall strength of a guide, pushed and idle.
    static let guideOpacityLit: Double = 1
    static let guideOpacityDim: Double = 0.33

    // ── The direction pad ─────────────────────────────────────────────────

    /// The bare arrow buttons: no plate behind them, just the sprite.
    static let padArrowSize: CGFloat = 62

    /// The longer-move arrow, which sits *outside* its direction — above up,
    /// left of left — so the pair reads as one control extending outward.
    static let padSpecialScale: CGFloat = 0.62

    /// Gaps between the cross's buttons, and between a button and its special.
    static let padGap: CGFloat = 8
    static let padSpecialGap: CGFloat = 2

    // ─────────────────────────────────────────────────────────────────────
    // MARK: Row 3 — the Zodiaction

    /// Height of the fire button, and the gap between its stacked lines.
    static let zodiactionButtonHeight: CGFloat = 78
    static let zodiactionStackSpacing: CGFloat = 5

    /// The small word above the name, and the name itself.
    static let zodiactionLabelSize: CGFloat = 12
    static let zodiactionLabelTracking: CGFloat = 4
    static let zodiactionNameSize: CGFloat = 19
    static let zodiactionNameTracking: CGFloat = 2
    static let zodiactionNameMinScale: CGFloat = 0.5

    /// How far the label is inset from the button's edges.
    static let zodiactionLabelInset: CGFloat = 16

    /// One pip of the meter, and how dim an unfilled one is.
    static let meterPipHeight: CGFloat = 9
    static let meterPipSpacing: CGFloat = 3
    static let meterPipCorner: CGFloat = 2
    static let meterEmptyOpacity: Double = 0.22

    /// The breath the button takes while it is ready to fire.
    ///
    /// A slow pulse rather than a flash: the meter being full is a standing
    /// state, not an event, and something that blinks at you for a whole minute
    /// stops reading as an invitation and starts reading as an alarm.
    static let readyPulsePeriod: TimeInterval = 1.6
    static let readyGlowRadius: CGFloat = 14
    static let readyGlowMin: Double = 0.15
    static let readyGlowMax: Double = 0.55

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
    static let infoTitleSize: CGFloat = 26
    static let infoSectionSize: CGFloat = 9
    static let infoNameSize: CGFloat = 13
    static let infoDetailSize: CGFloat = 11

    /// The button that turns the panel back over.
    static let backWidth: CGFloat = 84
    static let backHeight: CGFloat = 40
    static let backLabelSize: CGFloat = 24

    // ─────────────────────────────────────────────────────────────────────
    // MARK: Debug row
    //
    // Never ships, but it is on screen while the panel is being designed, so its
    // numbers belong with the rest rather than buried in an `#if`.

    static let debugSignSize: CGFloat = 26
    static let debugSignSpacing: CGFloat = 3
    static let debugSignCorner: CGFloat = 5
    static let debugRowSpacing: CGFloat = 16
    static let debugButtonHeight: CGFloat = 35
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

    /// Where the in-progress drag points, and how far past the commit threshold
    /// it has run.
    ///
    /// Owned here rather than by the input surface so the stick and its guide
    /// can react while the finger is still down — the guide's whole job is to
    /// say what *would* happen if the finger lifted now.
    @State private var liveDirection: SwipeDirection?
    @State private var liveReach = 0

    private var showingInfo: Bool { !turns.isMultiple(of: 2) }

    var body: some View {
        ZStack {
            Palette.panel
                .overlay(
                    SignBadge(zodiac: session.zodiac).scaleEffect(showingInfo ? 3 : 1),
                    alignment: showingInfo ? .center : .topLeading)
                .overlay(
                    HStack {
                        Image("Elements/\(session.zodiac.element.rawValue)")
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(ElementFX.ramp(for: session.zodiac.element).bright)
                            .frame(width: PanelStyle.elementMarkSize)
                        
                        let nameSize: CGFloat = showingInfo ? PanelStyle.infoTitleSize : PanelStyle.signNameSize
                        Text(session.zodiac.definition.displayName.uppercased())
                            .font(.system(size: nameSize, weight: .heavy, design: .rounded))
                            .tracking(PanelStyle.signNameTracking)
                            .foregroundStyle(Palette.gold)
                        // One line, never truncated: it shrinks rather than taking the
                        // width it wants and shoving the row off screen.
                            .lineLimit(1)
                            .minimumScaleFactor(PanelStyle.signNameMinScale)
                            .layoutPriority(1)
                            .animation(.bouncy(extraBounce: 0.2), value: nameSize)
                    }.padding(),
                    alignment: .topLeading
                )
            
            // Both faces stay mounted; the turn hides whichever faces away.
            // Rebuilding them on every flip would restart the meter's animation
            // and drop the drag mid-gesture.
            face(isVisible: !showingInfo, flip: 0) {
                PanelFrontView(
                    session: session,
                    liveDirection: $liveDirection,
                    liveReach: $liveReach,
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
    @Binding var liveReach: Int
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
                    onPreview: {
                        liveReach = $1
                        session.preview(direction: $0, reach: $1)
                    },
                    onStepForward: { session.stepForward() }
                )
            }

            VStack(spacing: PanelStyle.rowSpacing) {
                signRow
                Spacer(minLength: 0)
                movementRow
                Spacer(minLength: 0)
                zodiactionRow
                #if DEBUG
                debugZodiacRow
                #endif
            }
            .padding(.horizontal, PanelStyle.padding)
            .padding(.top, PanelStyle.padding)
            // Clear of the home indicator: a button under it is a button the
            // system takes the first touch of.
            //.padding(.bottom, PanelStyle.padding + safeArea)
            .padding(.bottom, PanelStyle.padding)
        }
        .overlay(alignment: .trailing) {
            #if DEBUG
            debugMainRow
                .padding()
            #endif
        }
    }

    // ── Row 1: the sign ───────────────────────────────────────────────────

    private var signRow: some View {
        HStack(spacing: PanelStyle.topRowSpacing) {
            //SignBadge(zodiac: session.zodiac)

            

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

    /// Both schemes get the same height, so switching between them cannot move
    /// anything else on the panel — which it did, because a joystick and a
    /// three-row cross are not naturally the same size.
    private var movementRow: some View {
        movementControl
            .frame(height: PanelStyle.movementRowHeight)
    }

    @ViewBuilder
    private var movementControl: some View {
        switch GameRules.controlScheme {
        case .joystick:
            Joystick(
                direction: liveDirection ?? session.engine.piece.facing,
                isDragging: liveDirection != nil,
                reach: liveReach,
                specialReach: session.specialReach(for:)
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
    private var debugMainRow: some View {
        VStack(spacing: PanelStyle.debugRowSpacing) {
            debugButton("CTRL", width: 40) { session.debugCycleControls() }
        }
    }
    
    private var debugZodiacRow: some View {
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

/// The sign's mark as a watermark, with the element's lit beside it.
///
/// ## Why they are sized so differently
///
/// The sign's name is already written next to this, so the sign's own mark has
/// nothing left to say — it is texture, and it earns its place by being large
/// and faint rather than small and loud. The element is not written anywhere, so
/// it is the one that has to be legible.
struct SignBadge: View {

    let zodiac: Zodiac

    var body: some View {
        ZStack {
            mark(
                Image("Signs/\(zodiac.rawValue)"),
                tint: PanelStyle.signWatermarkTint,
                side: PanelStyle.signWatermarkSize
            )
            .opacity(PanelStyle.signWatermarkOpacity)

            mark(
                Image("Elements/\(zodiac.element.rawValue)"),
                tint: ElementFX.ramp(for: zodiac.element).bright,
                side: PanelStyle.elementMarkSize
            )
        }
        .frame(width: PanelStyle.elementMarkSize, height: PanelStyle.elementMarkSize)
    }

    /// One flat vector, tinted.
    ///
    /// `.template` is what lets a monochrome export take a palette entry — the
    /// whole reason the icons are drawn flat.
    private func mark(_ icon: Image, tint: Color, side: CGFloat) -> some View {
        icon
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .foregroundStyle(tint)
            .frame(width: side * PanelStyle.markInset, height: side * PanelStyle.markInset)
            .frame(width: side, height: side)
    }
}

// MARK: - Row 2: the joystick

/// A golden stick that leans the way the piece is about to go, ringed by a
/// guide to what each direction offers.
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

    /// How far past the commit threshold the drag has run.
    let reach: Int

    /// The reach a sign's longer move that way needs, or `nil` if it has none.
    let specialReach: (SwipeDirection) -> Int?

    var body: some View {
        let side = PanelStyle.joystickSize
        let step = direction.unitOffset

        // Homes when released. A stick left leaning where the last drag ended
        // looks stuck; one that returns to centre is obviously a control at
        // rest, and the piece's facing is already shown by the piece.
        let lean = isDragging ? PanelStyle.joystickLean : 0

        ZStack {
            ForEach(SwipeDirection.allCases) { hint in
                guide(for: hint)
                    .offset(y: -side * PanelStyle.guideOrbit)
                    .rotationEffect(.degrees(hint.iconRotation))
            }

            Circle()
                .fill(Palette.midnight)
                .frame(width: side, height: side)

            Circle()
                .strokeBorder(
                    isDragging ? PanelStyle.joystickRimActive : PanelStyle.joystickRimColour,
                    lineWidth: max(2, side * PanelStyle.joystickRimWidth)
                )
                .frame(width: side, height: side)

            // A flat core, so the well still reads as a socket when the knob
            // leans off it.
            Circle()
                .fill(Palette.blue)
                .frame(width: side * PanelStyle.joystickCoreScale,
                       height: side * PanelStyle.joystickCoreScale)

            knob(side: side, step: step, lean: lean)
        }
        .animation(.spring(response: 0.18, dampingFraction: 0.7), value: direction)
        .animation(.spring(response: 0.22, dampingFraction: 0.75), value: isDragging)
        .animation(.easeOut(duration: 0.12), value: reach)
    }

    /// What one direction offers, and what the current drag would take.
    ///
    /// The arrow is the ordinary step and is always there. The chevron above it
    /// is the sign's longer move, drawn **only where one exists** — an empty
    /// promise on the other three directions would be worse than no guide at
    /// all — and lit only once the drag has run far enough to take it. So a lit
    /// arrow under a dim chevron means a normal step is what will happen.
    @ViewBuilder
    private func guide(for hint: SwipeDirection) -> some View {
        let isPushed = isDragging && hint == direction
        let special = specialReach(hint)
        let takesSpecial = isPushed && special.map { reach >= $0 } == true

        VStack(spacing: PanelStyle.guideSpacing) {
            if special != nil {
                Image(systemName: "chevron.compact.up")
                    .resizable()
                    .frame(width: PanelStyle.guideChevronSize.width,
                           height: PanelStyle.guideChevronSize.height)
                    .foregroundStyle(takesSpecial
                        ? PanelStyle.guideChevronLit
                        : PanelStyle.guideChevronDim)
            }

            Image(systemName: "arrowtriangle.up.fill")
                .resizable()
                .frame(width: PanelStyle.guideArrowSize.width,
                       height: PanelStyle.guideArrowSize.height)
                .foregroundStyle(isPushed
                    ? PanelStyle.guideArrowLit
                    : PanelStyle.guideArrowDim)
        }
        .opacity(isPushed ? PanelStyle.guideOpacityLit : PanelStyle.guideOpacityDim)
    }

    /// The stick itself, with its own rim under it so it stands out of the well
    /// rather than being painted on.
    private func knob(side: CGFloat, step: GridOffset, lean: CGFloat) -> some View {
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
        .offset(
            x: CGFloat(step.dx) * side * lean,
            // Sits a little high at rest, so the well's core shows beneath it.
            y: CGFloat(step.dy) * side * lean - PanelStyle.joystickKnobRise
        )
    }
}

// MARK: - Row 2: the direction pad

/// A keyboard cross of bare arrows, with a sign's longer moves outside them.
///
/// ## Why the arrows have no plate
///
/// They are pixel art, and a rounded button behind a sprite is two visual
/// languages in one control. The arrow *is* the button: it is big, it is lit,
/// and the whole cell takes the tap.
///
/// ## Why a keyboard cross rather than a diamond
///
/// Up on its own row, then left/down/right together. It is the shape every
/// keyboard already uses, and it costs one row less than a diamond — which on a
/// phone is the difference between the buttons being big enough and not.
///
/// ## Why the longer moves sit outside
///
/// Above up, left of left, right of right, below down. A sign with a two-square
/// sidestep cannot express that with a tap — the direction is the same, only the
/// distance differs — so it needs its own button, and putting it *further out*
/// in the same direction is the arrangement that says "same way, more of it".
struct DirectionPad: View {

    let session: GameSession

    var body: some View {
        VStack(spacing: PanelStyle.padSpecialGap) {
            special(.up)

            VStack(spacing: PanelStyle.padGap) {
                arrow(.up)

                HStack(spacing: PanelStyle.padSpecialGap) {
                    special(.left)

                    HStack(spacing: PanelStyle.padGap) {
                        arrow(.left)
                        arrow(.down)
                        arrow(.right)
                    }

                    special(.right)
                }
            }

            special(.down)
        }
    }

    /// The ordinary one-square move: the sprite, and nothing else.
    private func arrow(_ direction: SwipeDirection) -> some View {
        PixelSprite(id: .directionArrow(direction)) {
            Image(systemName: "arrowtriangle.up.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(Palette.white)
                .rotationEffect(.degrees(direction.iconRotation))
        }
        .frame(width: PanelStyle.padArrowSize, height: PanelStyle.padArrowSize)
        .opacity(session.acceptsInput ? 1 : 0.4)
        .contentShape(Rectangle())
        .onTapGesture {
            if session.acceptsInput { session.submit(direction, reach: 0) }
        }
    }

    /// The sign's longer move that way, when it has one.
    ///
    /// Always laid out, even when absent, so the cross does not shift as the
    /// piece changes sign — an empty space of the same size is invisible, and a
    /// pad that jumps about is not.
    @ViewBuilder
    private func special(_ direction: SwipeDirection) -> some View {
        let side = PanelStyle.padArrowSize * PanelStyle.padSpecialScale

        if let reach = session.specialReach(for: direction) {
            PixelSprite(id: .specialArrow(direction)) {
                Image(systemName: "chevron.up")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(Palette.lightBlue)
                    .rotationEffect(.degrees(direction.iconRotation))
            }
            .frame(width: side, height: side)
            .opacity(session.acceptsInput ? 1 : 0.4)
            .contentShape(Rectangle())
            .onTapGesture {
                if session.acceptsInput { session.submit(direction, reach: reach) }
            }
        } else {
            Color.clear.frame(width: side, height: side)
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
/// ## Why it breathes when it is ready
///
/// A full meter is a standing state, not an event — it can sit there for a
/// minute while the player decides. So it pulses slowly rather than flashing:
/// enough to catch an eye returning to the panel, not enough to nag. The glow
/// takes the sign's element, matching the pips and the piece itself.
struct ZodiactionButton: View {

    let session: GameSession

    var body: some View {
        // Read from the session rather than reaching into the engine, so the
        // button tracks the meter however it changed — including from a debug
        // key, which is where it was previously found lagging.
        let ready = session.isZodiactionReady
        let element = ElementFX.ramp(for: session.zodiac.element)

        TimelineView(.animation) { timeline in
            CelButton(
                tint: ready ? Palette.yellow : Palette.stone,
                isEnabled: ready && session.acceptsInput
            ) {
                session.fireZodiaction()
            } label: {
                label(charged: element.mid)
            }
            .frame(height: PanelStyle.zodiactionButtonHeight)
            .background {
                if ready { readyGlow(element.bright, at: timeline.date) }
            }
        }
    }

    /// The word, the name, and the meter.
    private func label(charged: Color) -> some View {
        VStack(spacing: PanelStyle.zodiactionStackSpacing) {
            Text("ZODIACTION")
                .font(.system(size: PanelStyle.zodiactionLabelSize,
                              weight: .heavy, design: .rounded))
                .tracking(PanelStyle.zodiactionLabelTracking)
                .lineLimit(1)
                .minimumScaleFactor(PanelStyle.zodiactionNameMinScale)

            Text(session.zodiac.definition.zodiaction.displayName.uppercased())
                .font(.system(size: PanelStyle.zodiactionNameSize,
                              weight: .heavy, design: .rounded))
                .tracking(PanelStyle.zodiactionNameTracking)
                .lineLimit(1)
                .minimumScaleFactor(PanelStyle.zodiactionNameMinScale)

            meter(charged: charged)
        }
        .padding(.horizontal, PanelStyle.zodiactionLabelInset)
    }

    /// Pips rather than a bar: the meter is a whole number of charges and the
    /// player counts them, which a continuous fill hides.
    ///
    /// Charged pips take the sign's element, so the meter says *whose* charge it
    /// is as well as how much — the same colour the piece wears when full.
    private func meter(charged: Color) -> some View {
        let filled = session.zodiactionMeter

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

    /// The breath: a blurred copy of the button's own shape, behind it.
    ///
    /// Driven off the clock rather than a repeating animation, like every other
    /// effect in this game — a repeat left running is a repeat that can be left
    /// stranded when the state it belongs to goes away.
    private func readyGlow(_ colour: Color, at date: Date) -> some View {
        let phase = date.timeIntervalSinceReferenceDate / PanelStyle.readyPulsePeriod
        let breath = (sin(phase * 2 * .pi) + 1) / 2
        let strength = PanelStyle.readyGlowMin
            + (PanelStyle.readyGlowMax - PanelStyle.readyGlowMin) * breath

        return RoundedRectangle(cornerRadius: PanelStyle.buttonCorner)
            .fill(colour)
            .blur(radius: PanelStyle.readyGlowRadius)
            .opacity(strength)
            .allowsHitTesting(false)
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
                //Text("BACK")
                Image(systemName: "arrowkeys.fill")
                    .font(.system(size: PanelStyle.backLabelSize, weight: .heavy, design: .rounded))
                    //.tracking(1)
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
            Spacer(minLength: 0)
            let definition = session.zodiac.definition

            entry("MOVEMENT", definition.movement.name, definition.movement.summary)

            ForEach(Array(definition.passives.enumerated()), id: \.offset) { index, passive in
                entry(index == 0 ? "PASSIVES" : nil, passive.displayName, passive.summary)
            }
            
            entry("ZODIACTION", definition.zodiaction.displayName, definition.zodiaction.summary)
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
                HStack(spacing: 3) {
                    Spacer()
                    Capsule().frame(height: 2).padding(.trailing, 4).opacity(0.5)
                    Text(section)
                        .font(.system(size: PanelStyle.infoSectionSize,
                                      weight: .heavy, design: .monospaced))
                        .tracking(3)
                        
                        .padding(.bottom, 2)
                    Capsule().frame(height: 2).opacity(0.5)
                    Spacer()
                }
                .foregroundStyle(Palette.lightBlue)
            }

            Text(name)
                .font(.system(size: PanelStyle.infoNameSize * 1.2, weight: .bold, design: .rounded))
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
    }

    #if DEBUG
    private func nextSign() {
        let all = Zodiac.allCases
        let index = all.firstIndex(of: session.zodiac) ?? 0
        session.debugSwapSign(to: all[(index + 1) % all.count])
    }
    #endif
}
