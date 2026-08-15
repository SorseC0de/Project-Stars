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

    /// How far down the vault badge sits, clear of the sign row above it.
    static let vaultBadgeTop: CGFloat = 62
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

    /// How far out from the centre each part of a guide sits, as a fraction of
    /// the well. The arrow clears the rim; the chevron sits beyond it.
    ///
    /// Two distances rather than a stack, so a direction with no longer move
    /// still puts its arrow in exactly the same place.
    static let guideArrowOrbit: CGFloat = 0.62
    static let guideChevronOrbit: CGFloat = 0.72

    /// The ordinary-step arrow, and the longer-move chevron above it.
    static let guideArrowSize = CGSize(width: 30, height: 12.5)
    static let guideChevronSize = CGSize(width: 25, height: 15)
    static let guideSpacing: CGFloat = 2

    /// Arrow colours: the direction being pushed, and the rest.
    static let guideArrowLit = Palette.lightBlue
    static let guideArrowDim = Palette.blue

    /// The tap-a-square pad. See `GridPadView`.
    static let gridPadCorner: CGFloat = 8
    static let gridPadGap: CGFloat = 12
    static let gridPadDim: Double = 0.45

    /// The outline on a slab's footprint squares, in points.
    static let gridPadSlabEdge: CGFloat = 1.5

    /// The lit seam where the panel meets the board.
    ///
    /// Thin enough to be a seam rather than a stripe — at anything more it stops
    /// closing the join and starts being a third thing between the two screens.
    static let seamHeight: CGFloat = 2

    /// Its colours, warm to cool across the diagonal.
    ///
    /// The elemental ramps in order — fire, earth, air, water — which is the
    /// same journey the sign wheel makes and the same one the board makes from
    /// Terra up to Astra. On-palette throughout, so the one gradient in the game
    /// is still made of the forty-seven.
    static let seamTones: [Color] = [
        Palette.gold, Palette.orange, Palette.magenta,
        Palette.purple, Palette.lightBlue,
    ]

    /// How much bigger the slab's type token is than a square on the pad.
    static let gridPadTokenScale: CGFloat = 2.2
    static let gridPadConfirmWidth: CGFloat = 64
    static let gridPadConfirmHeight: CGFloat = 64
    static let gridPadCheckSize: CGFloat = 26
    static let gridPadDeclineSize: CGFloat = 12

    /// The four stops only Virgo has.
    static let guideDiagonalLit = Palette.pink
    static let guideDiagonalDim = Palette.magenta

    /// Chevron colours: lit only once the drag has passed the ordinary step.
    static let guideChevronLit = Palette.magenta
    static let guideChevronDim = Palette.plum

    /// Overall strength of a guide, pushed and idle.
    static let guideOpacityLit: Double = 1
    static let guideOpacityDim: Double = 0.33

    // ── The direction pad ─────────────────────────────────────────────────

    /// The box one arrow is drawn in. Square: the silhouette turns inside it
    /// rather than the box turning with it.
    static let padArrowSize: CGFloat = 96

    /// How thick each plate is — how far its dark side shows below the top face.
    ///
    /// Per direction, because they are not seen at the same angle. The pair
    /// pointing away show more of their edge than the pair crossing the board,
    /// and north shows most of all: its tail is turned back-to-the-viewer, so
    /// what would be top face there is side instead.
    ///
    /// Thickness is also the only thing that makes the four differ in *shape* —
    /// it always falls straight down the screen while the arrow turns — so these
    /// are the numbers to reach for when one of them reads wrong.
    static func padThickness(_ direction: SwipeDirection) -> CGFloat {
        switch direction {
        case .up: 6
        case .down: 12
        // The diagonals have no plate of their own — they are stops on the
        // joystick, not buttons — so they never reach here.
        default: 12
        }
    }

    /// How the pair pointing away from the viewer differ from the pair crossing
    /// the board: broader, and shorter along the way they point.
    ///
    /// They are seen at a shallower angle, so they foreshorten. The horizontal
    /// pair are seen side-on and keep their proportions.
    static let padAwayWiden: CGFloat = 1.08
    static let padAwayShorten: CGFloat = 0.86

    /// How much of north's tail is wall rather than top face, as a fraction of
    /// the box.
    ///
    /// Pointing away, the tail is turned so its *back* faces the viewer — and a
    /// back is side, not top. The top face gives this height up and the side
    /// takes it, so the arrow ends in the same place with more of its end dark.
    static let padNorthTailToSide: CGFloat = 0.10

    /// The magenta mark on the head of an arrow with a longer move, as
    /// fractions of the box.
    ///
    /// Wide and flat, echoing the head it sits inside. A mark shaped unlike its
    /// surroundings reads as a sticker on the arrow rather than part of it.
    static let padSpecialMarkWidth: CGFloat = 0.36
    static let padSpecialMarkHeight: CGFloat = 0.16
    static let padSpecialMark = Palette.magenta

    /// How long an arrow must be held to take the longer move.
    ///
    /// Half a second, which is what iOS settled on for haptic touch once 3D
    /// Touch went away — so it is already the length a thumb expects to wait.
    static let padHoldDuration: Double = 0.5

    /// Gaps within the cross.
    ///
    /// Two, not one. The vertical pair sit closer than the horizontal, and a
    /// single value has to suit whichever needs more.
    static let padGapVertical: CGFloat = 0
    static let padGapHorizontal: CGFloat = -6

    /// The top face and the side, matching the joystick's guide so the two
    /// schemes read as one game.
    static let padLight = Palette.gold
    static let padShadow = Palette.orange

    // ─────────────────────────────────────────────────────────────────────
    // MARK: Row 3 — the Zodiaction

    /// Height of the fire button, and the gap between its stacked lines.
    static let zodiactionButtonHeight: CGFloat = 78

    /// The full height of the Zodiaction row, which the lift panel sits above.
    ///
    /// Named separately from the button's own height so the two can diverge —
    /// the row already carries padding the button does not know about, and a
    /// panel positioned off the button alone drifts into it.
    static var zodiactionRowHeight: CGFloat { zodiactionButtonHeight }
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

    /// Capricorn's meter, drawn as coins. Ten of them on Astra, so they are
    /// small — but round and rimmed, which is enough to read as money at a
    /// glance and to be counted without reading anything.
    static let meterCoinSize: CGFloat = 11
    static let meterCoinSpacing: CGFloat = 3
    static let meterCoinRim: CGFloat = 1.5

    /// A phantom's button. Short, since it sits above the real one.
    static let retinueButtonHeight: CGFloat = 40
    static let retinueSpacing: CGFloat = 8

    /// How wide the borrowed-Zodiaction column is: a third of the row.
    static let retinueColumnWidth: CGFloat = 118
    static let retinueGlyphGap: CGFloat = 5

    /// Pip gap when the button is sharing its row. Ten pips in two thirds of the
    /// width need to give something up, and the gap is the part nobody reads.
    static let meterPipSpacingCompact: CGFloat = 2

    /// The "ZC" against the meter: how far off it sits, how big, and how far it
    /// stays back. Quiet on purpose — it is a label on the bar, not a heading
    /// over it, and a bright one would compete with the pips it is naming.
    static let meterLabelGap: CGFloat = 5
    static let meterLabelSize: CGFloat = 14
    static let meterLabelOpacity: Double = 0.9
    static let retinueGlyphSize: CGFloat = 58
    static let retinueGlyphOpacity: Double = 0.5

    /// How far the mark is held off the button's edge.
    static let retinueGlyphInset: CGFloat = 4
    static let retinueLabelSize: CGFloat = 13

    /// The bow, for Sagittarius' recall.
    static let zodiactionRecallGlyphSize: CGFloat = 34

    /// Polaris' own button. Bigger than a glyph, because it is a sprite.
    static let polarisButtonSize: CGFloat = 52

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
                // A hairline along the top edge.
                //
                // The panel and the board meet at a hard colour change with
                // nothing between them, which reads as two screens bolted
                // together rather than one device. A lit seam is what a handheld
                // has there — and running the twelve signs' own hues across it,
                // gold through to blue, makes the join say what the game is
                // about rather than just closing the gap.
                .overlay(alignment: .top) {
                    LinearGradient(
                        colors: PanelStyle.seamTones,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(height: PanelStyle.seamHeight)
                }
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
            if session.controlScheme == .joystick {
                SwipeInputSurface(
                    isEnabled: session.acceptsGesture,
                    includingDiagonals: session.movesDiagonally,
                    liveDirection: $liveDirection,
                    onCommit: {
                        // The stick gets the same knock the buttons do, so the
                        // two schemes feel like one game.
                        Haptics.step()
                        session.submit($0, reach: $1)
                    },
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
        .overlay(alignment: .topLeading) {
            // North-west of the stick, where nothing else sits.
            if session.showsVault {
                VaultBadgeView(session: session)
                    .padding(.leading, PanelStyle.padding)
                    .padding(.top, PanelStyle.vaultBadgeTop)
            }
        }
        .overlay(alignment: .trailing) {
            controlSchemeButton
                .padding()
        }
        .overlay(alignment: .topLeading) {
            #if DEBUG
            perspectiveDials.padding(.leading, 8).padding(.top, 44)
            #endif
        }
        .overlay(alignment: .bottomLeading) {
            // An overlay, so it costs the layout nothing.
            //
            // As a row in the stack it pushed the whole panel up and shoved the
            // bottom of it off the screen — the panel is a fixed square and
            // every row in it is already spoken for. Lifted clear of the
            // Zodiaction button by that button's own height, so it sits above it
            // rather than on it.
            // Beside the lift, not inside the Zodiaction's row.
            //
            // It lived in the retinue column, which is a third of the super
            // button — so carrying a fragment shrank the biggest control on the
            // panel. This is chrome for the run, like the lift, and belongs with
            // it rather than taking room from something else.
            VStack(alignment: .leading, spacing: PanelStyle.rowSpacing) {
                if session.canFirePolaris { polarisButton }
                if session.showsNexysCall {
                    NexysCallView(session: session)
                    .padding(.leading, PanelStyle.padding)
                    // Measured off the row it has to clear rather than guessed.
                    //
                    // A hand-totalled offset is right on exactly one device: it
                    // was overlapping everywhere except a Pro Max at Display
                    // Zoom, which is the size it happened to be tuned against.
                    // Aligning to the Zodiaction row's own height means it moves
                    // when that row does.
                }
            }
            .padding(.leading, PanelStyle.padding)
            .padding(.bottom, PanelStyle.zodiactionRowHeight
                + PanelStyle.rowSpacing * 2)
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

    /// Cycles how you steer, showing what you would be steering with.
    ///
    /// ## Why it wears its destination rather than its current state
    ///
    /// Because the current state is already the largest thing on the panel. The
    /// joystick, the cross of buttons and the grid are right there under the
    /// player's thumb, filling a third of the screen — an icon repeating that
    /// back in twenty points tells them nothing they are not already looking at.
    /// What they cannot see is what is behind the button, so that is what it
    /// shows: press this and become this.
    ///
    /// Replaced with a symbol effect on the change, because the glyph moves on
    /// at the same moment the panel beneath it does. Without the transition the
    /// icon reads as having been redrawn; with it, the button hands its old face
    /// to the panel and takes the next one.
    private var controlSchemeButton: some View {
        CelButton(tint: Palette.yellow) { session.cycleControls() } label: {
            Image(systemName: glyph(for: session.nextControlScheme))
                .font(.system(size: PanelStyle.chromeGlyphSize, weight: .black))
                .contentTransition(.symbolEffect(.replace))
        }
        .frame(width: PanelStyle.chromeButtonWidth, height: PanelStyle.chromeButtonHeight)
        .animation(.snappy, value: session.controlScheme)
        .accessibilityLabel(Text("Switch to \(name(for: session.nextControlScheme)) controls"))
    }

    /// One glyph per scheme, each naming the thing your thumb actually touches.
    private func glyph(for scheme: GameRules.ControlScheme) -> String {
        switch scheme {
        case .joystick: "l.joystick.fill"
        case .buttons: "dpad.fill"
        case .grid: "square.grid.3x3.fill"
        }
    }

    private func name(for scheme: GameRules.ControlScheme) -> String {
        switch scheme {
        case .joystick: "joystick"
        case .buttons: "button"
        case .grid: "grid"
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
        // A question about a square is answered on the pad whatever the control
        // scheme is. Aiming a warp with a joystick means projecting a *move*,
        // which is the one thing a free choice of square is not — and the board
        // is at the top of the screen where the answer is hardest to reach.
        if session.isChoosingTile {
            GridPadView(session: session, side: PanelStyle.movementRowHeight)
        } else {
            movementScheme
        }
    }

    @ViewBuilder
    private var movementScheme: some View {
        switch session.controlScheme {
        case .joystick:
            Joystick(
                direction: liveDirection ?? session.engine.piece.facing,
                isDragging: liveDirection != nil,
                reach: liveReach,
                available: session.availableDirections,
                specialReach: session.specialReach(for:)
            )
            .allowsHitTesting(false)

        case .buttons:
            DirectionPad(session: session)

        case .grid:
            GridPadView(session: session, side: PanelStyle.movementRowHeight)
        }
    }

    // ── Row 3: the Zodiaction ─────────────────────────────────────────────

    private var zodiactionRow: some View {
        HStack(spacing: PanelStyle.retinueSpacing) {
            // Two thirds when there is company, all of it when there is not.
            //
            // The followers' buttons were a row of their own, which pushed the
            // whole panel up and shoved the pause and info buttons out of place
            // — the panel is a fixed square and every row in it is already
            // spoken for. Taking a third of the Zodiaction button instead costs
            // nothing that was not already there.
            // The column holds the borrowed supers *and* the arrow recall, so
            // the main button gives up its third for either.
            let hasColumn = !session.retinue.isEmpty
                || session.canRecallArrow
                || session.polaris != nil

            ZodiactionButton(session: session, isCompact: hasColumn)
                .frame(maxWidth: .infinity)
                .layoutPriority(hasColumn ? 0 : 1)

            if hasColumn {
                retinueColumn
            }
        }
        .frame(height: PanelStyle.zodiactionButtonHeight)
    }

    /// The borrowed Zodiactions, stacked in the third beside Leo's own.
    ///
    /// One follower fills the height; two split it. Which means the column is
    /// always the same size and the buttons inside it are what change — a
    /// control that resizes its container is a control that moves everything
    /// else, which is the mistake this replaced.
    /// The recall button's face.
    ///
    /// No words and no meter: the shot is paid for, nothing is charging, and
    /// the only thing this button does is call it back. A bow says that in less
    /// space than a sentence would.
    private var recallLabel: some View {
        Image(systemName: "figure.archery")
            .font(.system(size: PanelStyle.zodiactionRecallGlyphSize, weight: .black))
            .foregroundStyle(Palette.warmBlack)
    }

    /// Polaris, spendable.
    ///
    /// The sprite at button size rather than a glyph on a face: it is a specific
    /// object the player went and found, and a star symbol would make it generic
    /// — the same icon any game would use for "special".
    ///
    /// The depth comes from an opaque copy of the sprite in its own darkest
    /// tone, offset beneath it. That is what the panel's other buttons do with
    /// their rims, and doing it from the art means the drop shadow is the
    /// fragment's own colour rather than a grey somebody picked. `Palette.purple`
    /// is sampled from the sprite, not chosen — see `flatSilhouette`.
    private var polarisButton: some View {
        Button {
            Haptics.zodiaction()
            session.firePolaris()
        } label: {
            ZStack {
                // Both copies framed **square**, inside a taller box.
                //
                // The frame carried the depth as extra height and the sprites
                // stretched to fill it, so the fragment came out taller than it
                // is drawn — which read as the board's foreshortening leaking
                // into the panel. Only the box is taller now; the art is not.
                PixelSprite(id: .pentacle(.radiant)) { Color.clear }
                    .frame(width: PanelStyle.polarisButtonSize,
                           height: PanelStyle.polarisButtonSize)
                    .colorEffect(ShaderLibrary.flatSilhouette(.color(Palette.purple)))
                    .offset(y: PanelStyle.buttonDepth)

                PixelSprite(id: .pentacle(.radiant)) { Color.clear }
                    .frame(width: PanelStyle.polarisButtonSize,
                           height: PanelStyle.polarisButtonSize)
            }
            .frame(width: PanelStyle.polarisButtonSize,
                   height: PanelStyle.polarisButtonSize + PanelStyle.buttonDepth,
                   alignment: .top)
        }
        .buttonStyle(.plain)
        .disabled(!session.acceptsInput)
        .frame(maxHeight: .infinity)
        .accessibilityLabel(Text("Spend Polaris"))
    }

    private var retinueColumn: some View {
        VStack(spacing: PanelStyle.retinueSpacing) {
            // The arrow, first, because it is the one that is already paid for.
            //
            // Its own button rather than a second face on the Zodiaction: an
            // arrow outlives the archer who fired it, so with a different sign
            // holding the board the old arrangement took that sign's super away
            // and handed back a control that did nothing. See
            // `GameEngine.planArrowRecall()`.
            // Only once it can actually be spent.
            //
            // A greyed button for something you cannot use is a control that
            // lies about being a control — the *carrying* is already stated up
            // on the board, beside the plane's name, which is where facts about
            // your run belong. Down here means "you may do this now".
            if session.canRecallArrow {
                CelButton(
                    tint: Palette.red,
                    isEnabled: true,
                    acceptsTouch: session.acceptsInput
                ) {
                    Haptics.zodiaction()
                    session.recallArrow()
                } label: {
                    recallLabel
                }
                .frame(maxHeight: .infinity)
            }

            ForEach(session.retinue, id: \.self) { follower in
                CelButton(
                    tint: ElementFX.ramp(for: follower.element).mid,
                    // Greyed when its own conditions refuse it — the ring beside
                    // a wall, the shop with an empty purse — so a phantom cannot
                    // be spent on nothing.
                    isEnabled: session.canFireRetinue(follower),
                    acceptsTouch: session.acceptsInput
                ) {
                    Haptics.zodiaction()
                    session.fireRetinueZodiaction(follower)
                } label: {
                    // The sign's own mark, not an emoji.
                    //
                    // There is a drawn icon for all twelve and it is what the
                    // rest of the panel uses; a system glyph here made the
                    // borrowed supers look like they belonged to a different
                    // game from the one that lent them.
                    ZStack {
                        // The mark, filling the face and half faded.
                        //
                        // Beside the text it had to be small enough to leave
                        // room, which made it decoration nobody could read.
                        // Behind the text it can be as large as the button and
                        // still not compete: the sign is what the button *is*,
                        // and the name is what it does.
                        // The image directly, not `PieceIconView`.
                        //
                        // That view frames itself to a fixed `size`, so asking it
                        // to fill afterwards had nothing to grow — and a
                        // `scaledToFit` on top of an already-framed view
                        // collapsed it to nothing, which is why the mark
                        // vanished entirely.
                        //
                        // It has to fill rather than take a number, because the
                        // button's height depends on how many phantoms share the
                        // column: one takes the whole row, two take half each.
                        Image("Signs/\(follower.rawValue)")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(ElementFX.ramp(for: follower.element).deep)
                            .padding(PanelStyle.retinueGlyphInset)
                            .opacity(PanelStyle.retinueGlyphOpacity)

                        Text(follower.definition.zodiaction.displayName.uppercased())
                            .font(.system(size: PanelStyle.retinueLabelSize,
                                          weight: .heavy, design: .rounded))
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.7)
                            .padding(.horizontal, 4)
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
        .frame(width: PanelStyle.retinueColumnWidth)
    }

    /// Live dials for seating the piece on the island. Read the numbers off the
    /// labels and hand them back; they fold into `GameRules` afterwards.
    ///
    /// - TODO: **Temporary.** Delete with `GameSession.debugFeetDrop` and
    ///   `debugCarryFollow`.
    private var perspectiveDials: some View {
        VStack(alignment: .leading, spacing: 2) {
            dial("NEAR Y", value: bind(\.nearY), range: 0.5...1.2, unit: "")
            dial("FAR GAP", value: bind(\.farSpacing), range: 0.3...1.2, unit: "t")
            dial("NEAR GAP", value: bind(\.nearSpacing), range: 0.6...1.6, unit: "t")
            dial("FAR SIZE", value: bind(\.farScale), range: 0.3...1.4, unit: "x")
            dial("NEAR SIZE", value: bind(\.nearScale), range: 0.6...1.8, unit: "x")
        }
        .padding(8)
        .background(Palette.midnight.opacity(0.85), in: RoundedRectangle(cornerRadius: 8))
    }

    /// One field of the placement, as something a slider can drive.
    private func bind(_ key: WritableKeyPath<BoardPlacement, CGFloat>) -> Binding<Double> {
        Binding(
            get: { Double(session.placement[keyPath: key]) },
            set: { session.placement[keyPath: key] = CGFloat($0) }
        )
    }

    private func dial(
        _ name: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        unit: String
    ) -> some View {
        HStack(spacing: 6) {
            Text(name)
                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                .foregroundStyle(Palette.textSecondary)
                .frame(width: 62, alignment: .leading)

            Slider(value: value, in: range)
                .frame(width: 108)
                .tint(Palette.yellow)

            Text(String(format: "%.2f\(unit)", value.wrappedValue))
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .foregroundStyle(Palette.white)
                .frame(width: 56, alignment: .trailing)
        }
    }

    // ── Debug ─────────────────────────────────────────────────────────────

    #if DEBUG
    /// Every sign at once, plus the two look toggles.
    ///
    /// All twelve rather than a stepper: picking the one you want is a glance
    /// and a tap, where cycling is a count. Drawn with the real marks, so it
    /// doubles as a look at all twelve together. Never ships.
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
        // No outer frame: this is a background, and it has to be free to take
        // whatever size it is given — including being scaled up on the info
        // face. Clamping it to a fixed box is what shrank it to nothing.
        Image("Signs/\(zodiac.rawValue)")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .foregroundStyle(PanelStyle.signWatermarkTint)
            .opacity(PanelStyle.signWatermarkOpacity)
            .frame(width: PanelStyle.signWatermarkSize,
                   height: PanelStyle.signWatermarkSize)
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

    /// Which directions this piece actually has a move in.
    ///
    /// The guides are drawn for these and no others. A ring of eight arrows on
    /// a sign that can use four of them is not a guide, it is a lie.
    var available: Set<SwipeDirection> = Set(SwipeDirection.cardinals)

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
            ForEach(SwipeDirection.allCases.filter(available.contains)) { hint in
                guide(for: hint)
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

        // Each sits at its own distance rather than stacking, so whether the
        // chevron exists cannot move the arrow. Stacked, a direction with no
        // special produced a shorter stack that fell inside the well and
        // disappeared behind it — which is why the arrows went missing.
        ZStack {
            Image(systemName: "arrowtriangle.up.fill")
                .resizable()
                .frame(width: PanelStyle.guideArrowSize.width,
                       height: PanelStyle.guideArrowSize.height)
                // The diagonals are magenta throughout, lit or not: they are a
                // property of the *sign* rather than of the drag, and a player
                // who has just picked Virgo should be able to see at a glance
                // that this stick has eight stops rather than four.
                .foregroundStyle(hint.isCardinal
                    ? (isPushed ? PanelStyle.guideArrowLit : PanelStyle.guideArrowDim)
                    : (isPushed ? PanelStyle.guideDiagonalLit : PanelStyle.guideDiagonalDim))
                .offset(y: -PanelStyle.joystickSize * PanelStyle.guideArrowOrbit)

            if special != nil {
                Image(systemName: "chevron.compact.up")
                    .resizable()
                    .frame(width: PanelStyle.guideChevronSize.width,
                           height: PanelStyle.guideChevronSize.height)
                    .foregroundStyle(takesSpecial
                        ? PanelStyle.guideChevronLit
                        : PanelStyle.guideChevronDim)
                    .offset(y: -PanelStyle.joystickSize * PanelStyle.guideChevronOrbit)
            }
        }
        .opacity(isPushed ? PanelStyle.guideOpacityLit : PanelStyle.guideOpacityDim)
    }

    /// Length of an offset, never zero.
    private func hypot(_ step: GridOffset) -> CGFloat {
        max(Foundation.hypot(CGFloat(step.dx), CGFloat(step.dy)), 1)
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
        // Normalised, so a diagonal lean is the same distance from centre as a
        // cardinal one. Without it the stick reaches 41% further into the
        // corners and the well stops looking round.
        .offset(
            x: CGFloat(step.dx) / hypot(step) * side * lean,
            // Sits a little high at rest, so the well's core shows beneath it.
            y: CGFloat(step.dy) / hypot(step) * side * lean - PanelStyle.joystickKnobRise
        )
    }
}

// MARK: - Row 2: the direction pad

/// The arrow's outline, as points, before anything is drawn with it.
///
/// Kept as points rather than a `Path` because two shapes are built from it —
/// the top face and the side wall — and the wall needs the individual edges, not
/// a finished path.
struct ArrowProfile {

    /// Where the silhouette's corners sit, as fractions of its box.
    var tipY: CGFloat = 0.02
    var barbX: CGFloat = 0.98
    var barbY: CGFloat = 0.46
    var tailX: CGFloat = 0.71
    var tailY: CGFloat = 0.80

    /// Stretched across and squashed along its length, before it is turned.
    ///
    /// The pair pointing away from the viewer are seen at a shallower angle than
    /// the pair crossing the board, so they are shorter and broader. Applied in
    /// the arrow's own space, so it survives the rotation.
    var widen: CGFloat = 1
    var shorten: CGFloat = 1

    /// Extra side height, in fractions of the box, taken off the top face.
    ///
    /// North is the one that needs it: pointing away, the tail is turned so its
    /// *back* is toward the viewer, and a back is side, not top. So the yellow
    /// gives that height up and the orange takes it — the arrow ends in the same
    /// place, but more of its end is wall.
    var sideBonus: CGFloat = 0

    /// The one for a given direction.
    static func of(_ direction: SwipeDirection) -> ArrowProfile {
        switch direction {
        case .up:
            ArrowProfile(tailY: 0.80 - PanelStyle.padNorthTailToSide,
                         widen: PanelStyle.padAwayWiden,
                         shorten: PanelStyle.padAwayShorten,
                         sideBonus: PanelStyle.padNorthTailToSide)
        case .down:
            ArrowProfile(widen: PanelStyle.padAwayWiden,
                         shorten: PanelStyle.padAwayShorten)
        // Only the four plates exist; a diagonal is a joystick stop.
        default:
            ArrowProfile()
        }
    }

    /// How deep this arrow's side is, in points.
    ///
    /// The direction's own depth, plus whatever the top face gave up to it.
    func thickness(_ direction: SwipeDirection, in rect: CGRect) -> CGFloat {
        PanelStyle.padThickness(direction) + rect.height * sideBonus * shorten
    }

    /// The seven corners, stretched, turned, and placed in `rect`.
    func corners(in rect: CGRect, turn: Double) -> [CGPoint] {
        let local: [(CGFloat, CGFloat)] = [
            (0.50, tipY),           // tip
            (barbX, barbY),         // right barb
            (tailX, barbY),         // right shoulder
            (tailX, tailY),         // tail, right
            (1 - tailX, tailY),     // tail, left
            (1 - tailX, barbY),     // left shoulder
            (1 - barbX, barbY),     // left barb
        ]

        let centre = CGPoint(x: rect.midX, y: rect.midY)
        let turned = CGAffineTransform(translationX: centre.x, y: centre.y)
            .rotated(by: turn * .pi / 180)
            .translatedBy(x: -centre.x, y: -centre.y)

        return local.map { x, y in
            // Stretch about the middle of the box while it still points up.
            let sx = 0.5 + (x - 0.5) * widen
            let sy = 0.5 + (y - 0.5) * shorten
            return CGPoint(x: rect.minX + rect.width * sx,
                           y: rect.minY + rect.height * sy)
                .applying(turned)
        }
    }
}

/// The arrow's top face.
struct ArrowGlyph: Shape {

    var direction: SwipeDirection

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addLines(ArrowProfile.of(direction).corners(in: rect, turn: direction.iconRotation))
        path.closeSubpath()
        return path
    }
}

/// The arrow's side: the wall its thickness makes, seen from above.
///
/// ## Why this is not the top face drawn again lower down
///
/// A copy offset downward gives the right angles and a hollow plate — nothing
/// joins the two faces, so at a barb's point the dark simply stops and the pair
/// read as two stickers. A real extrusion stands a wall on every edge, meeting
/// the top face along its whole length.
struct ArrowSide: Shape {

    var direction: SwipeDirection

    func path(in rect: CGRect) -> Path {
        let profile = ArrowProfile.of(direction)
        let corners = profile.corners(in: rect, turn: direction.iconRotation)
        let drop = profile.thickness(direction, in: rect)

        var path = Path()
        path.addLines(wound(corners.map { CGPoint(x: $0.x, y: $0.y + drop) }))
        path.closeSubpath()

        // Every edge is swept, not only those facing the viewer — the rest end
        // up behind the top face, cost nothing, and save deciding which is which.
        for index in corners.indices {
            let a = corners[index]
            let b = corners[(index + 1) % corners.count]

            path.addLines(wound([
                a, b,
                CGPoint(x: b.x, y: b.y + drop),
                CGPoint(x: a.x, y: a.y + drop),
            ]))
            path.closeSubpath()
        }

        return path
    }

    /// The same polygon, always wound the same way round.
    ///
    /// Without this the walls come out in whichever order their edge happened to
    /// run, and a non-zero fill *subtracts* a shape wound against its neighbour —
    /// which is why the side once vanished entirely rather than merely looking
    /// wrong. Every piece wound alike means every overlap adds.
    private func wound(_ points: [CGPoint]) -> [CGPoint] {
        var twice: CGFloat = 0
        for index in points.indices {
            let a = points[index]
            let b = points[(index + 1) % points.count]
            twice += a.x * b.y - b.x * a.y
        }
        return twice < 0 ? points.reversed() : points
    }
}

/// The mark inside an arrow's head saying it has a longer move.
///
/// Inside the head rather than beside the arrow: a second button next to the
/// first says "another control", and this is the *same* control held down. A
/// mark on the face says "there is more in here".
struct SpecialMark: Shape {

    var direction: SwipeDirection

    func path(in rect: CGRect) -> Path {
        let profile = ArrowProfile.of(direction)
        let width = rect.width * PanelStyle.padSpecialMarkWidth
        let height = rect.height * PanelStyle.padSpecialMarkHeight

        // Sat in the head rather than the middle of the box: the head is where
        // the eye goes, and the tail is too narrow to hold it.
        let headCentre = CGPoint(
            x: rect.midX,
            y: rect.minY + rect.height * (profile.tipY + profile.barbY) / 2 * profile.shorten
                + rect.height * (1 - profile.shorten) / 2
        )

        var path = Path()
        path.move(to: CGPoint(x: headCentre.x, y: headCentre.y - height / 2))
        path.addLine(to: CGPoint(x: headCentre.x + width / 2, y: headCentre.y + height / 2))
        path.addLine(to: CGPoint(x: headCentre.x - width / 2, y: headCentre.y + height / 2))
        path.closeSubpath()

        let centre = CGPoint(x: rect.midX, y: rect.midY)
        return path.applying(
            CGAffineTransform(translationX: centre.x, y: centre.y)
                .rotated(by: direction.iconRotation * .pi / 180)
                .translatedBy(x: -centre.x, y: -centre.y)
        )
    }
}

/// One direction's arrow: a flat plate with real thickness, seen from above.
///
/// ## What the dark is
///
/// Not an outline and not shading — it is the side of a solid object lying on
/// the board, lit from above. What shows of it is whatever faces down the
/// screen, which is why pointing up shows the undersides of the barbs and the
/// tail, pointing down shows the two long diagonals, and pointing across shows
/// the lower diagonal and the underside of the shaft.
struct DirectionArrow: View {

    let direction: SwipeDirection

    /// True when this sign has a longer move this way, which the mark announces
    /// and a long press takes.
    var hasSpecial: Bool = false

    var light: Color = PanelStyle.padLight
    var shadow: Color = PanelStyle.padShadow
    var box: CGFloat = PanelStyle.padArrowSize

    var body: some View {
        ZStack {
            // Non-zero winding, with every piece wound alike, so the walls and
            // the far face merge into one solid — see `ArrowSide.wound`.
            ArrowSide(direction: direction)
                .fill(shadow, style: FillStyle(eoFill: false))

            ArrowGlyph(direction: direction).fill(light)

            if hasSpecial {
                SpecialMark(direction: direction).fill(PanelStyle.padSpecialMark)
            }
        }
        .frame(width: box, height: box)
    }
}

/// A keyboard cross of arrows. Tap to step; hold for a sign's longer move.
///
/// ## Why the longer move is a hold rather than a second button
///
/// It is the same direction — only the distance differs — so it is the same
/// control, and a second button beside the first said otherwise. Holding is also
/// what the joystick already does: drag further and you get more. A magenta
/// triangle on the head says there is something to hold *for*.
struct DirectionPad: View {

    let session: GameSession

    var body: some View {
        // The horizontal pair sit level with the middle of the vertical pair
        // rather than in a row with south. Laying them over the column is what
        // achieves that without opening the gap between north and south.
        ZStack {
            VStack(spacing: PanelStyle.padGapVertical) {
                PadArrow(session: session, direction: .up)
                PadArrow(session: session, direction: .down)
            }

            HStack(spacing: PanelStyle.padGapHorizontal) {
                PadArrow(session: session, direction: .left)
                Color.clear.frame(width: PanelStyle.padArrowSize, height: 1)
                PadArrow(session: session, direction: .right)
            }
        }
    }
}

/// One arrow on the pad, with the press the rest of the panel has.
///
/// ## Why it is its own view
///
/// For the press state. Four arrows built by one function share whatever that
/// function closes over, so the pressed one cannot be told apart from its
/// neighbours — each needs its own.
private struct PadArrow: View {

    let session: GameSession
    let direction: SwipeDirection

    @State private var isPressed = false

    var body: some View {
        let special = session.specialReach(for: direction)

        DirectionArrow(direction: direction, hasSpecial: special != nil)
            // Pushed down rather than dimmed.
            //
            // These had no press state at all. What looked like one was the
            // whole pad fading on `acceptsInput`, which goes false the instant a
            // move starts — so pressing an arrow appeared to switch it off, and
            // during a fast sequence the pad spent most of its life grey. A
            // button on this panel depresses; see `CelButton`, whose depth this
            // borrows so the two feel like the same hardware.
            .offset(y: isPressed ? PanelStyle.buttonDepth : 0)
            .animation(.easeOut(duration: PanelStyle.buttonPressDuration), value: isPressed)
            // Dimmed only when the pad genuinely cannot be used — paused, or the
            // run is over. A move in progress no longer counts, because an input
            // during one is buffered and played rather than dropped, so greying
            // the arrows would be the panel lying about what it will accept.
            .opacity(session.acceptsGesture || session.phase == .resolvingMove ? 1 : 0.4)
            .contentShape(Rectangle())
            // The hold is registered first, so a press that becomes a hold does
            // not also fire the tap when it lifts. Its `pressing` callback is
            // also where the depress comes from — one gesture, so the visual
            // cannot disagree with what the button is doing.
            .onLongPressGesture(minimumDuration: PanelStyle.padHoldDuration) {
                // `acceptsGesture`, like the tap beside it: holding an arrow
                // is reaching for a control, and reaching for a control is how
                // the splash is dismissed. `submit` spends it doing that.
                guard session.acceptsGesture, let reach = special else { return }
                Haptics.longer()
                session.submit(direction, reach: reach)
            } onPressingChanged: { pressing in
                isPressed = pressing
            }
            .onTapGesture {
                guard session.acceptsGesture || session.phase == .resolvingMove else { return }
                Haptics.step()
                session.submit(direction, reach: 0)
            }
    }
}

/// Degrees to turn an up-pointing shape by.
extension SwipeDirection {
    var iconRotation: Double {
        switch self {
        case .up: 0
        case .upRight: 45
        case .right: 90
        case .downRight: 135
        case .down: 180
        case .downLeft: 225
        case .left: 270
        case .upLeft: 315
        }
    }
}

// MARK: - Feel

/// The taps the panel makes.
///
/// One place, so the game speaks with a consistent hand: a light knock for an
/// ordinary move, a heavier one for firing, and the two-beat pattern for a hold
/// that paid off — which is the same shape iOS uses for a completed haptic
/// touch, so it is already familiar.
enum Haptics {

    /// An ordinary step, by button or by stick.
    static func step() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }

    /// A hold that produced the longer move: two beats, not one.
    static func longer() {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }

    /// Spending the meter. The heaviest thing the panel does.
    static func zodiaction() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        #endif
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

    /// True when the button is sharing its row with borrowed Zodiactions.
    ///
    /// It gives up a third of its width, so it gives up the things that need
    /// width: the word ZODIACTION, which is a label for a button nobody has to
    /// be told the purpose of by then, and the meter's generous pips.
    var isCompact = false

    var body: some View {
        // Read from the session rather than reaching into the engine, so the
        // button tracks the meter however it changed — including from a debug
        // key, which is where it was previously found lagging.
        let ready = session.isZodiactionReady
        let element = ElementFX.ramp(for: session.zodiac.element)

        TimelineView(.animation) { timeline in
            CelButton(
                tint: ready ? Palette.yellow : Palette.stone,
                // Availability decides the colour; the move in progress decides
                // only whether a touch lands. Tying both to `acceptsInput` made
                // this flash grey on every step of every move.
                isEnabled: ready,
                acceptsTouch: session.acceptsInput
            ) {
                Haptics.zodiaction()
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
            if !isCompact {
                Text("ZODIACTION")
                    .font(.system(size: PanelStyle.zodiactionLabelSize,
                                  weight: .heavy, design: .rounded))
                    .tracking(PanelStyle.zodiactionLabelTracking)
                    .lineLimit(1)
                    .minimumScaleFactor(PanelStyle.zodiactionNameMinScale)
            }

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
    ///
    /// Capricorn counts Pentacles rather than deeds, so its meter is drawn as
    /// coins. Same variable, same maths — see `CapricornCelestialCommerce`.
    @ViewBuilder
    private func meter(charged: Color) -> some View {
        HStack(spacing: PanelStyle.meterLabelGap) {
            // Named, because the meter alone did not say what it was.
            //
            // A tester read a filling bar under the word ZODIACTION as gaining
            // *Zodiactions* — plural, one per pip — which is a reasonable thing
            // to conclude from a row of ten pips beneath a title. The word
            // "charge" was in the tooltips and nowhere they were looking. Two
            // letters against the meter itself is the cheapest place to put it,
            // and it is why every Pentacle now says ZC too.
            Text("ZC")
                .font(.system(size: PanelStyle.meterLabelSize,
                              weight: .black, design: .rounded))
                .foregroundStyle(Palette.warmBlack.opacity(PanelStyle.meterLabelOpacity))
                .fixedSize()

            pips(charged: charged)
        }
    }

    /// The meter itself.
    @ViewBuilder
    private func pips(charged: Color) -> some View {
        let filled = session.zodiactionMeter

        if session.zodiac == .capricorn {
            HStack(spacing: PanelStyle.meterCoinSpacing) {
                ForEach(0..<session.zodiactionMeterMax, id: \.self) { index in
                    Circle()
                        .fill(index < filled
                            ? Palette.pentacle
                            : Palette.warmBlack.opacity(PanelStyle.meterEmptyOpacity))
                        .overlay {
                            // A rim only on the coins that are actually there,
                            // so an empty slot stays a hole rather than becoming
                            // a second, duller coin.
                            if index < filled {
                                Circle().strokeBorder(
                                    Palette.pentacleEdge,
                                    lineWidth: PanelStyle.meterCoinRim
                                )
                            }
                        }
                        .frame(width: PanelStyle.meterCoinSize,
                               height: PanelStyle.meterCoinSize)
                }
            }
            .animation(.easeOut(duration: 0.18), value: filled)
        } else {
            HStack(spacing: isCompact
                ? PanelStyle.meterPipSpacingCompact
                : PanelStyle.meterPipSpacing) {
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

    /// The same bloom, held still. See `body` for why it does not breathe.
    private func staticGlow(_ colour: Color) -> some View {
        RoundedRectangle(cornerRadius: PanelStyle.buttonCorner)
            .fill(colour)
            .blur(radius: PanelStyle.readyGlowRadius)
            .opacity(PanelStyle.readyGlowMax)
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

    /// Whether a touch would land *right now*.
    ///
    /// Separate from `isEnabled` because they answer different questions. A
    /// button is disabled when the thing it does is unavailable, and it goes
    /// grey to say so. It merely stops taking touches while a move is playing
    /// out — and greying for that made the Zodiaction button flash grey and back
    /// to gold on every single step, which read as the charge draining.
    var acceptsTouch: Bool = true

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
        .onTapGesture { if isEnabled, acceptsTouch { action() } }
        // A press has to show the instant the finger lands, which a tap gesture
        // alone cannot do — it only reports once the tap completes.
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in if isEnabled, acceptsTouch { isPressed = true } }
                .onEnded { _ in isPressed = false }
        )
        .disabled(!isEnabled || !acceptsTouch)
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
        .onChange(of: scheme) {
            GameRules.controlScheme = scheme
            session.controlScheme = scheme
        }
    }

    #if DEBUG
    private func nextSign() {
        let all = Zodiac.allCases
        let index = all.firstIndex(of: session.zodiac) ?? 0
        session.debugSwapSign(to: all[(index + 1) % all.count])
    }
    #endif
}
