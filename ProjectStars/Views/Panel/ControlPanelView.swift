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
    /// The passive marks under the sign's name.
    static let passiveMarkSize: CGFloat = 48
    static let passiveMarkSpacing: CGFloat = 10

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

    /// The word on a chrome button, and the line under a mode's name.
    static let chromeLabelSize: CGFloat = 13
    static let summarySize: CGFloat = 12

    /// One sample square on the rules page.
    ///
    /// Bigger than the board draws them. The board is showing you where things
    /// *are*; this page is showing you what they *look like*, and a 16-pixel
    /// sprite at board scale is too small to tell two stages of cracking apart.
    static let rulesCellSize: CGFloat = 52
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
    static let guideArrowLit = Palette.sky
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
        Palette.purple, Palette.sky,
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
    static let guideChevronDim = Palette.coffee

    /// Overall strength of a guide, pushed and idle.
    static let guideOpacityLit: Double = 1
    static let guideOpacityDim: Double = 0.33

    // ── The direction pad ─────────────────────────────────────────────────

    /// The box one arrow is drawn in. Square: the silhouette turns inside it
    /// rather than the box turning with it.
    /// How long a passive mark takes to light or go out.
    ///
    /// Slow enough that a state which changes twice in quick succession reads
    /// as one movement rather than as a blink.
    /// How long a flashing mark stays lit before letting go.
    ///
    /// Long enough to be caught out of the corner of an eye while a move is
    /// still resolving, short enough that it is plainly an event rather than a
    /// state. See `ZodiacPassive.flashes(in:)`.
    static let passiveFlashHold: TimeInterval = 0.6

    static let passiveMarkFade: Double = 0.25

    static let padArrowSize: CGFloat = 96

    /// How much smaller each arrow is drawn once the corners are out.
    ///
    /// Eight arrows in the space four were laid out for run into each other at
    /// full size. Applied to the whole set rather than to the diagonals alone —
    /// a pad where the corners are visibly smaller than the cardinals reads as
    /// the corners mattering less, and they are the same move.
    static let padDiagonalShrink: CGFloat = 0.76

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

    // ── The start screen ──────────────────────────────────────────────

    /// A chrome button two wide, spanning the gap between them.
    ///
    /// Derived rather than typed out: it is *by definition* two of the buttons
    /// beside it plus the space between, and a literal here would go quietly
    /// wrong the first time either of those changed.
    static var wideChromeWidth: CGFloat { chromeButtonWidth * 2 + topRowSpacing }

    /// How much of the panel's width the Start button takes.
    static let startButtonLength: CGFloat = 0.66

    /// The word on the way in, and the words either side of it. How far its
    /// shadow falls belongs to the style that draws it.
    static let startLabelSize: CGFloat = 30
    static let wideLabelSize: CGFloat = 15

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
    /// How long the gold band takes to cross the Zodiaction button, and how
    /// wide it is as a fraction of that crossing.
    ///
    /// Slow, and narrow. It is a statement that something is held rather than
    /// an animation asking to be watched — at any speed that catches the eye it
    /// competes with the board for attention every turn it is on screen.

    static let meterCoinSize: CGFloat = 16.5
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

    /// How faint a Zodiaction's name is while it cannot be fired.
    static let zodiactionIdleOpacity: Double = 0.45

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

    /// Leaving the run entirely, from the start screen's way back.
    let onQuit: () -> Void

    /// How many times the panel has been turned over.
    ///
    /// A count rather than a flag, so the board keeps rotating the *same way*
    /// each time instead of winding back. Turning something over and then
    /// un-turning it reads as a mistake being undone; turning it again reads as
    /// a board with two sides.
    ///
    /// Starts at zero: the run opens on the start screen, which shares the near
    /// side with the controls it hands over to, so there is nothing to turn.
    @State private var turns = 0

    /// Where the in-progress drag points, and how far past the commit threshold
    /// it has run.
    ///
    /// Owned here rather than by the input surface so the stick and its guide
    /// can react while the finger is still down — the guide's whole job is to
    /// say what *would* happen if the finger lifted now.
    @State private var liveDirection: SwipeDirection?
    @State private var liveReach = 0

    /// Which of the three faces the player is looking at.
    ///
    /// Derived rather than stored. The start screen is not a third position on
    /// the same axis — it is the near face while the run has not begun, and the
    /// controls the moment it has. Storing that as well as `turns` would be two
    /// answers to one question, and they would disagree the first time a run was
    /// restarted from the back.
    private var showing: PanelFace {
        // First, because it outranks everything: a lost run is not awaiting a
        // start and has no live controls, and the panel should not spend a
        // frame showing either while the piece is falling past Terra.
        if session.phase == .gameOver { return .death }
        if session.isAwaitingStart { return showingRules ? .rules : .start }
        return turns.isMultiple(of: 2) ? .front : .back
    }

    private var showingInfo: Bool { showing == .back }

    /// Whether the start screen has been turned over to read the mode's rules.
    ///
    /// A flag beside `turns` rather than a fourth position on it, for the same
    /// reason the start screen is: the rules are the far side of the *start*
    /// screen, not a further step round from the controls. Which face is showing
    /// stays one question with one answer.
    @State private var showingRules = false

    enum PanelFace { case start, front, back, rules, death }

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
                    VStack(alignment: .leading, spacing: PanelStyle.passiveMarkSpacing) {
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
                        }
                        .padding(.horizontal)
                        .padding(.top)

                        // The sign's passives, as marks rather than controls.
                        //
                        // Flat, untinted and unpressable on purpose: everything
                        // else in this panel that looks like a face with an
                        // edge does something when touched, so a row of
                        // buttons here would promise an interaction that does
                        // not exist. These are a statement of what the sign
                        // *is* — the same category as the name above them.
                        HStack(spacing: PanelStyle.passiveMarkSpacing) {
                            let snapshot = session.engine.passiveSnapshot
                            // Nothing of the run's state on the start screen —
                            // it says what you are about to play, not how it is
                            // going.
                            let marks = showing == .start ? [] : session.zodiac.passives
                                .compactMap { passive -> PassiveMark.Entry? in
                                    guard let mark = passive.icon(in: snapshot) else {
                                        return nil
                                    }
                                    return PassiveMark.Entry(
                                        mark: mark,
                                        lit: passive.isLit(in: snapshot),
                                        flashes: passive.flashes(in: snapshot)
                                    )
                                }

                            ForEach(Array(marks.enumerated()), id: \.offset) { _, entry in
                                PassiveMark(
                                    entry: entry,
                                    tint: ElementFX.ramp(for: session.zodiac.element).bright
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.bottom),
                    alignment: .topLeading
                )
            
            // Both faces stay mounted; the turn hides whichever faces away.
            // Rebuilding them on every flip would restart the meter's animation
            // and drop the drag mid-gesture.
            face(.front) {
                PanelFrontView(
                    session: session,
                    liveDirection: $liveDirection,
                    liveReach: $liveReach,
                    onInfo: turn
                )
            }

            face(.back) {
                PanelBackView(session: session, onBack: turn)
            }

            // Shares the far side with the back, and never shares a moment with
            // it: one belongs to a run that has not started and the other to one
            // that has.
            face(.start) {
                PanelStartView(
                    session: session,
                    onStart: { session.startRun() },
                    onRules: {
                        showingRules = true
                        turn()
                    },
                    onQuit: onQuit
                )
            }
            // Where a run ends. Shares the far side with the start screen it
            // will hand back to — the two are the same face of the device, one
            // asking to begin and one asking to begin again.
            face(.death) {
                PanelDeathView(
                    session: session,
                    // Straight back into the fall, no card. See
                    // `GameSession.restartRunSeamlessly`.
                    onRestart: { session.restartRunSeamlessly() },
                    onChangeSign: onQuit
                )
            }

            // The start screen's far side. It shares the even side with the
            // controls and never shares a moment with them, the same way the
            // start screen shares the odd side with the back.
            face(.rules) {
                PanelRulesView(session: session) {
                    showingRules = false
                    turn()
                }
            }
        }
        .frame(width: side, height: side)
        .clipped()
        // **A live run shows the controls.**
        //
        // Both ways in: pressing START, and coming back from a lost run.
        // Pressing the button used to be what turned the panel, which made the
        // *button* the cause rather than the run — so a run begun from the
        // keyboard, or resumed without a card, left the panel on the info page.
        //
        // Which face, not which way up. The corrector below owns orientation,
        // and the two questions are kept apart on purpose: answering both from
        // one handler is what put the panel upside down in the first place.
        .onChange(of: session.isRunning) { _, running in
            if running, !turns.isMultiple(of: 2) { turn() }
        }
        // **One owner for which way up the panel is.**
        //
        // `turns` answers two questions at once — which face is showing, and
        // which way up it is — and for the two faces derived from it, the
        // controls and the info page, those answers can never disagree. The
        // other three are chosen by the run's state instead, so when one of them
        // comes up the parity has to be brought round to meet it.
        //
        // That used to be done by two handlers watching two different signals,
        // each written as if the other were still. A restart from a lost run
        // changes both in the same transaction, they gave opposite answers, and
        // the panel came back at an odd multiple of 180° — upside down. Asking
        // the *face* instead of the signals that produced it is the whole fix:
        // there is only one question, so there is only one place to answer it.
        .onChange(of: showing) { _, face in
            guard turns.isMultiple(of: 2) == isFar(face) else { return }

            // Turned when there is nothing else to look at, straightened when
            // there is. A card arriving over the board or a run ending should
            // not have to share the moment with the panel flipping over — but
            // coming back to the controls is the moment, and it should be seen.
            if face == .front || face == .back { turn() } else { turns += 1 }
        }
    }

    /// Which side of the panel a face is mounted on.
    ///
    /// `true` is the far side: the one that is only right way up when `turns` is
    /// odd, because `face` adds a further half turn to it. Both the rotation and
    /// the parity correction read this, so the two cannot fall out of step.
    private func isFar(_ face: PanelFace) -> Bool {
        switch face {
        // **The start screen is the near side, with the controls.**
        //
        // It used to be the far side, which meant beginning a run turned the
        // panel over — and that was never anything the flip was *for*. The
        // panel turns to show you the other side of something: the controls and
        // the sign's information, the start screen and its rules. A run
        // beginning is not the other side of anything, it is the same side
        // getting on with it, so the start screen hands straight over to the
        // controls without moving.
        //
        // The same for a run ending. The card is coming up over the board at
        // that moment and it should have it.
        case .front, .start, .death: false
        case .back, .rules: true
        }
    }

    /// One side of the board, turned to face the player or away.
    ///
    /// Around X, so it tips away like a chalkboard on a frame rather than
    /// swinging like a door. The hidden face stops taking touches as well as
    /// sight — a button on the back of a board should not be pressable through
    /// it.
    private func face<Content: View>(
        _ which: PanelFace,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let isVisible = showing == which
        return content()
            .frame(width: side, height: side)
            .opacity(isVisible ? 1 : 0)
            .rotation3DEffect(
                .degrees(Double(turns) * 180 + (isFar(which) ? 180 : 0)),
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

    #if DEBUG
    /// What the spawner is holding, before a square is picked.
    ///
    /// - TODO: **Debug only.** Never ships.
    @State private var spawning: PickupID?
    #endif

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
                    onStepForward: {
                        // A tap is a stick input like any other, and was the
                        // only one landing without the knock.
                        Haptics.step()
                        session.stepForward()
                    }
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
            controlSchemeButton
                .padding()
        }
        .overlay(alignment: .topLeading) {
            #if DEBUG
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

            #if DEBUG
            spawnerButton
            #endif

            // The sign's own writing, not a lowercase i. A scroll says "read
            // about this" where the SF glyph says "there is a caveat here".
            CelButton(tint: Palette.sky, action: onInfo) {
                Image("scroll")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: PanelStyle.chromeGlyphSize * 1.3)
            }
            .frame(width: PanelStyle.chromeButtonWidth,
                   height: PanelStyle.chromeButtonHeight)
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

    #if DEBUG
    /// Puts any Pentacle anywhere, for testing.
    ///
    /// Deliberately off the panel's palette — purple face, yellow-green plane,
    /// blue side — because every other button here derives its three faces from
    /// one tint. A control that will never ship should be visible as *not part
    /// of the set* without having to be read.
    ///
    /// - TODO: **Debug only.** Never ships.
    private var spawnerButton: some View {
        iMAPicker(items: PickupID.allCases, selection: $spawning) {
            // The face, drawn by `CelButton` with no action of its own.
            //
            // A button inside a button never gets the tap it looks like it
            // should — the inner one takes it — so this one does nothing and
            // the picker around it is the only control. It still derives its
            // three faces from the one tint like every other button here.
            CelButton(tint: Palette.magenta) {} label: {
                Image(systemName: "wand.and.sparkles")
                    .font(.system(size: PanelStyle.chromeGlyphSize, weight: .black))
            }
            .frame(width: PanelStyle.chromeButtonWidth,
                   height: PanelStyle.chromeButtonHeight)
            .disabled(true)
            .contentShape(Rectangle())
        } row: { id, isSelected in
            HStack(spacing: 12) {
                PickupIconView(effect: PickupCatalog.effect(for: id), size: 22)

                // A name is a name: it shrinks rather than wrapping. A second
                // line makes this row taller than its neighbours and walks the
                // whole list out of alignment.
                Text(PickupCatalog.effect(for: id).displayName)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(Palette.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Spacer(minLength: 0)

                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Palette.lime)
                }
            }
            .padding(.vertical, 6)
        }
        // **Choosing the coin is the whole action.**
        //
        // It overwrites whatever Pentacle is already out, so the way to test one
        // is to pick it and walk into it. Naming a square first was a second
        // answer to a question that has an obvious default — the coin you can
        // already see.
        .onChange(of: spawning) { _, chosen in
            guard let chosen else { return }
            session.debugBecome(chosen)
            spawning = nil
        }
    }
    #endif

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
        #if DEBUG
        // The spawner's board takes the row while it is holding something, for
        // the same reason the real pad does: the question is *which square*,
        // and the board on screen is at the top where the thumb is not.
        if session.debugSpawning != nil {
            DebugSpawnGrid(session: session, side: PanelStyle.movementRowHeight)
        } else if session.isChoosingTile {
            GridPadView(session: session, side: PanelStyle.movementRowHeight)
        } else {
            movementScheme
        }
        #else
        if session.isChoosingTile {
            GridPadView(session: session, side: PanelStyle.movementRowHeight)
        } else {
            movementScheme
        }
        #endif
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
            //
            // **Polaris is not in it.** The fragment moved out to the lift's
            // stack — it is chrome for the run rather than a super — and this
            // was left still counting it, so a lit Polaris shrank the biggest
            // control on the panel to make room for a button that is drawn
            // somewhere else entirely. The rule is what the column *contains*,
            // which is the only thing that can take its third.
            let hasColumn = !session.retinue.isEmpty
                || session.canRecallArrow

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
        Image("sagittarius_zaction")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: PanelStyle.zodiactionRecallGlyphSize * 1.4)
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
                    // South-**west**, not straight down. A pentacle is a star
                    // rather than a slab, so a shadow directly beneath it reads
                    // as a doubled sprite; offset on both axes it reads as one
                    // shape lit from the upper right, which is where every
                    // other face in the panel is lit from.
                    .offset(x: -PanelStyle.buttonDepth, y: PanelStyle.buttonDepth)

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

            // Typed, not dragged.
            //
            // A slider cannot reliably stop on a value: 108 points across a
            // range is a couple of hundredths per pixel, so landing on 1.02
            // rather than 1.01 or 1.04 is luck. The slider stays for sweeping
            // to find roughly the right place; the field is for saying exactly
            // where.
            TextField("", value: value, format: .number.precision(.fractionLength(0...3)))
                .textFieldStyle(.plain)
                .keyboardType(.numbersAndPunctuation)
                .multilineTextAlignment(.trailing)
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .foregroundStyle(Palette.white)
                .frame(width: 44)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Palette.midnight.opacity(0.6))
                )

            Text(unit)
                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                .foregroundStyle(Palette.textSecondary)
                .frame(width: 16, alignment: .leading)
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
        // Everything shrinks together once there are eight of them.
        let box = session.movesDiagonally
            ? PanelStyle.padArrowSize * PanelStyle.padDiagonalShrink
            : PanelStyle.padArrowSize

        return ZStack {
            VStack(spacing: PanelStyle.padGapVertical) {
                PadArrow(session: session, direction: .up, box: box)
                PadArrow(session: session, direction: .down, box: box)
            }

            HStack(spacing: PanelStyle.padGapHorizontal) {
                PadArrow(session: session, direction: .left, box: box)
                Color.clear.frame(width: box, height: 1)
                PadArrow(session: session, direction: .right, box: box)
            }

            // **The corners, for whoever has them.**
            //
            // The pad was four arrows because four was every direction the game
            // had when it was written. The diagonals arrived with Virgo and only
            // the stick and the grid learned about them, so playing her on the
            // arrows meant losing half her movement — the one scheme where what
            // you can press *is* what you can do.
            //
            // Shown per direction rather than per sign: a borrowed diagonal from
            // Leo's company is the same question, and asking the movement means
            // nothing here has to know whose it is.
            if session.movesDiagonally {
                VStack(spacing: PanelStyle.padGapVertical) {
                    HStack(spacing: PanelStyle.padGapHorizontal) {
                        PadArrow(session: session, direction: .upLeft, box: box)
                        Color.clear.frame(width: box, height: 1)
                        PadArrow(session: session, direction: .upRight, box: box)
                    }
                    HStack(spacing: PanelStyle.padGapHorizontal) {
                        PadArrow(session: session, direction: .downLeft, box: box)
                        Color.clear.frame(width: box, height: 1)
                        PadArrow(session: session, direction: .downRight, box: box)
                    }
                }
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

    /// The square this arrow is drawn in. Smaller once the corners are out —
    /// see `PanelStyle.padDiagonalShrink`.
    var box: CGFloat = PanelStyle.padArrowSize

    @State private var isPressed = false

    var body: some View {
        let special = session.specialReach(for: direction)

        DirectionArrow(direction: direction, hasSpecial: special != nil, box: box)
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
                palette: zodiactionPalette(ready: ready),
                // Availability decides the colour; the move in progress decides
                // only whether a touch lands. Tying both to `acceptsInput` made
                // this flash grey on every step of every move.
                isEnabled: ready,
                // The palette above already answers this, in full. Letting the
                // button substitute as well is two things deciding one colour.
                dimsWhenDisabled: false,
                acceptsTouch: session.acceptsInput
            ) {
                Haptics.zodiaction()
                session.fireZodiaction()
            } label: {
                label(charged: pipColour, ready: ready)
            }
            .frame(height: PanelStyle.zodiactionButtonHeight)
            .background {
                if ready { readyGlow(element.bright, at: timeline.date) }
            }
        }
    }

    /// What a lit pip is coloured.
    ///
    /// The element's **mid**, which is the shade the rest of the game uses for
    /// a sign's own colour — except air, whose mid is a purple dark enough to
    /// disappear against the button beneath it. That one takes `bright`, which
    /// is also what its badge is drawn in.
    ///
    /// One exception rather than moving everyone to `bright`: the others read
    /// correctly at mid, and lightening all four to fix one is trading a real
    /// problem on one element for a slightly wrong colour on three.
    private var pipColour: Color {
        let ramp = ElementFX.ramp(for: session.zodiac.element)
        return session.zodiac.element == .air ? ramp.bright : ramp.mid
    }

    /// What the Zodiaction button is made of.
    ///
    /// Gold when it can be fired, stone when it cannot — **for every sign,
    /// including the one whose meter runs backwards.**
    ///
    /// Aquarius was briefly given his own colours here, on the reasoning that
    /// grey says *nothing here yet* and he is never without power. That is true
    /// about the sign and wrong about the button: this control answers one
    /// question, *can you press it*, and a face that looks alive while the
    /// answer is no is the button lying. What he is holding is said by the
    /// storm, the aura and the meter — three places that are about him, where
    /// this one is about the input.
    private func zodiactionPalette(ready: Bool) -> CelPalette {
        // Grey for every sign at every unready phase, ramp and all.
        //
        // Which is what it always was: the old code derived the face from
        // `isEnabled ? tint : Palette.gray`, so the purple it named for
        // Aquarius was never once drawn. Saying it outright is the difference
        // between a colour that is chosen and one that happens.
        //
        // Aquarius briefly had a face of his own here, on the reasoning that
        // grey says *nothing here yet* and he is never without power. True
        // about the sign, wrong about the button: this control answers one
        // question — can you press it — and anything that looks alive while
        // the answer is no is the button contradicting itself. What he is
        // holding is said by the storm, the aura and the meter, three places
        // that are about him. This one is about the input.
        ready ? CelPalette(face: Palette.yellow) : .disabled
    }


    /// The word, the name, and the meter.
    private func label(charged: Color, ready: Bool) -> some View {
        VStack(spacing: PanelStyle.zodiactionStackSpacing) {
            if !isCompact {
                // Always the same weight of black.
                //
                // It is a heading rather than a state — it says what the button
                // is, which does not change with whether it can be pressed. The
                // same goes for ZC against the meter.
                Text("ZODIACTION")
                    .font(.system(size: PanelStyle.zodiactionLabelSize,
                                  weight: .heavy, design: .rounded))
                    .foregroundStyle(Palette.warmBlack)
                    .tracking(PanelStyle.zodiactionLabelTracking)
                    .lineLimit(1)
                    .minimumScaleFactor(PanelStyle.zodiactionNameMinScale)
            }

            // The **name** is what fades.
            //
            // Of the three lines this is the only one describing something you
            // might do: the heading names the control and ZC labels the meter,
            // and neither of those becomes less true while you wait. Fading the
            // name says the move is out of reach without greying the words that
            // explain the button.
            Text(session.zodiac.definition.zodiaction.displayName.uppercased())
                .font(.system(size: PanelStyle.zodiactionNameSize,
                              weight: .heavy, design: .rounded))
                .foregroundStyle(
                    Palette.warmBlack.opacity(ready ? 1 : PanelStyle.zodiactionIdleOpacity)
                )
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
            // Capricorn's meter is a purse, and the coins in it are spent
            // rather than discharged. Calling them charge is the one label that
            // could make a player think the shop runs on the same stuff every
            // other sign's Zodiaction does.
            Text(session.zodiac == .capricorn ? "P" : "ZC")
                .font(.system(size: PanelStyle.meterLabelSize,
                              weight: .black, design: .rounded))
                .foregroundStyle(Palette.warmBlack)
                .fixedSize()

            pips(charged: charged)
        }
    }

    /// The meter itself.
    @ViewBuilder
    private func pips(charged rawCharged: Color) -> some View {
        let filled = session.zodiactionMeter

        // The element's own colour, for everyone.
        //
        // A meter that empties toward firing lights the pips it has *left*
        // rather than the ones it has gained — which is a difference in what
        // the count means, not in what colour says it. Aquarius briefly had
        // purple here for that reason and it only made air look like two
        // elements, since purple is the same ramp's middle.
        let charged = rawCharged

        if session.zodiac == .capricorn {
            // **Always ten slots, on both planes.**
            //
            // Terra only asks for eight, and shortening the row to match hides
            // the discount instead of showing it — the player sees a smaller
            // purse rather than a cheaper one. Ten slots with the last two
            // greened says the same fact the other way round: this is what it
            // costs everywhere else, and down here you keep these.
            let slots = GameRules.capricornPurseAstra
            let needed = session.zodiactionMeterMax

            HStack(spacing: PanelStyle.meterCoinSpacing) {
                ForEach(0..<slots, id: \.self) { index in
                    PixelSprite(id: .pentacle(.still)) { Color.clear }
                        .frame(width: PanelStyle.meterCoinSize,
                               height: PanelStyle.meterCoinSize)
                        .modifier(
                            MeterCoin(
                                held: index < filled,
                                free: index >= needed
                            )
                        )
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

    /// How one of Capricorn's coins is drawn: held, spent, or free.
    private struct MeterCoin: ViewModifier {

        /// True once the purse has reached this slot.
        let held: Bool

        /// True for the slots Terra never charges for.
        let free: Bool

        func body(content: Content) -> some View {
            if !held {
                // A silhouette, not a dimmed coin. Faded gold still reads as
                // gold and so as *something you have*, which is the one thing
                // an empty slot must not say.
                content
                    .colorEffect(ShaderLibrary.flatSilhouette(.color(Palette.iron)))
            } else if free {
                // Bright enough to read as *a different coin* at a glance.
                // The first pass swapped the gold ramp for greens a step or two
                // down it, which at this size looked like gold in shadow rather
                // than like something else — and the whole point of the pair is
                // that you can see them without counting.
                content.paletteSwap([
                    PaletteSwap(Palette.pentacleHighlight, Palette.yellowGreen),
                    PaletteSwap(Palette.pentacle, Palette.neonGreen),
                    PaletteSwap(Palette.pentacleEdge, Palette.green)
                ])
            } else {
                content
            }
        }
    }

    /// A thin band of gold travelling across the button, on a diagonal.
    ///
    /// Its position is a moving pair of gradient stops rather than an offset
    /// view, so the band is genuinely *part of* the face rather than something
    /// sliding over it — the edges blend into the purple either side instead of
    /// having a boundary of their own.
    ///
    /// Leading to trailing, looping, and 45 degrees so it crosses the long axis
    /// rather than running down it.
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
/// The three colours a cel-shaded button is made of.
///
/// ## Why this is a set rather than one tint
///
/// Because deriving all three from a face colour is only right while nothing
/// wants to disagree with it. The moment something does — a debug control that
/// should not look like the panel, a sign whose face is purple while its element
/// is air — the choice is to add another override or to accept the wrong
/// colour, and this has collected several of the former.
///
/// A caller that wants the ordinary look passes a face and gets a ramp. A caller
/// that wants something else says so, in one place, without the button growing
/// a parameter for it.
struct CelPalette {

    /// The button's own colour.
    var face: Color

    /// The side standing proud beneath it.
    var rim: Color

    /// The hard-edged lit plane across the top.
    var highlight: Color

    /// A face, with its rim and highlight taken from the palette's ramp.
    ///
    /// The default, and what nearly every button wants — the ramp is what makes
    /// them look like one set of controls rather than a collection.
    init(face: Color, rim: Color? = nil, highlight: Color? = nil) {
        self.face = face
        self.rim = rim ?? face.celShadow
        self.highlight = highlight ?? face.celHighlight
    }

    /// Greyed out. Not a colour choice so much as the absence of one.
    static let disabled = CelPalette(face: Palette.gray)

    /// A sign's own, from its element.
    ///
    /// The switch lives here rather than inside the button, because which
    /// colours an element wears is a fact about the game and not about how a
    /// button is drawn.
    static func forElement(_ element: ZodiacElement) -> CelPalette {
        CelPalette(face: ElementFX.ramp(for: element).mid)
    }
}

struct CelButton<Label: View>: View {

    var palette: CelPalette = CelPalette(face: Palette.gold)
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

    /// Whether an unavailable button greys itself out.
    ///
    /// True for the ordinary case: most buttons are one colour and grey is how
    /// they say *not now*. False for anything whose palette already describes
    /// the state — the Zodiaction hands over a different set of colours for
    /// waiting than for ready, and greying it discards the answer it was given.
    var dimsWhenDisabled = true

    /// Drawn over the face and its lit plane, **under** the label.
    ///
    /// For anything that is part of the button's surface rather than sitting on
    /// it — Aquarius' travelling band of gold. As an outer `.overlay` it covered
    /// the words and the meter, which reads as something passing in front of the
    /// button instead of moving across it.
    var surface: (() -> AnyView)?

    @State private var isPressed = false

    /// The full form: every colour said outright.
    init(
        palette: CelPalette,
        depth: CGFloat = PanelStyle.buttonDepth,
        isEnabled: Bool = true,
        dimsWhenDisabled: Bool = true,
        acceptsTouch: Bool = true,
        action: @escaping () -> Void,
        @ViewBuilder label: @escaping () -> Label,
        surface: (() -> AnyView)? = nil
    ) {
        self.palette = palette
        self.depth = depth
        self.isEnabled = isEnabled
        self.dimsWhenDisabled = dimsWhenDisabled
        self.acceptsTouch = acceptsTouch
        self.action = action
        self.label = label
        self.surface = surface
    }

    /// A button in one flat colour, with its ramp derived. See `CelPalette`.
    init(
        tint: Color,
        depth: CGFloat = PanelStyle.buttonDepth,
        isEnabled: Bool = true,
        dimsWhenDisabled: Bool = true,
        acceptsTouch: Bool = true,
        action: @escaping () -> Void,
        @ViewBuilder label: @escaping () -> Label,
        surface: (() -> AnyView)? = nil
    ) {
        self.init(
            palette: CelPalette(face: tint),
            depth: depth,
            isEnabled: isEnabled,
            dimsWhenDisabled: dimsWhenDisabled,
            acceptsTouch: acceptsTouch,
            action: action,
            label: label,
            surface: surface
        )
    }

    var body: some View {
        let colours = (isEnabled || !dimsWhenDisabled) ? palette : .disabled

        ZStack {
            // The rim, standing proud below the face. Its own shape rather than
            // a border, so the button has a genuine side.
            RoundedRectangle(cornerRadius: PanelStyle.buttonCorner)
                .fill(colours.rim)
                .offset(y: depth)

            RoundedRectangle(cornerRadius: PanelStyle.buttonCorner)
                .fill(colours.face)
                // The face's own colouring, **beneath** the lit plane.
                //
                // Above it, a travelling band covers the highlight and the
                // button loses the one edge that makes it look raised. The
                // surface is part of the face; the highlight is light falling
                // on it, and light falls on whatever is there.
                .overlay {
                    if let surface {
                        surface()
                            .clipShape(
                                RoundedRectangle(cornerRadius: PanelStyle.buttonCorner)
                            )
                            .allowsHitTesting(false)
                    }
                }
                .overlay {
                    // One hard-edged lighter plane across the top, not a sheen.
                    RoundedRectangle(cornerRadius: PanelStyle.buttonCorner)
                        .fill(colours.highlight)
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

            CelButton(tint: Palette.sky, action: onBack) {
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
                .foregroundStyle(Palette.sky)
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

            ControlPanelView(session: session, side: side, onQuit: {})
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

// MARK: - The start screen

/// What a run opens on: the sign you drew, and the button that begins.
///
/// Deliberately almost empty. Everything the panel normally carries — the
/// stick, the passives, the Zodiaction, pause — belongs to a run in progress,
/// and putting them here would offer them before there is anything to use them
/// on. The sign's element and name are already drawn as the panel's own chrome,
/// so this face adds only what is missing: a way in, a way out, and a way to
/// read the rules first.
private struct PanelStartView: View {

    let session: GameSession
    let onStart: () -> Void
    let onRules: () -> Void
    let onQuit: () -> Void

    /// Whether the glow is at its wide end. Flipped once on appear and left to
    /// breathe on a repeating animation — a pulse SwiftUI runs itself, rather
    /// than a clock this view has to be woken up by.
    @State private var isSwelling = false


    var body: some View {
        VStack(spacing: PanelStyle.rowSpacing) {
            // Sits where the scroll and pause do on the front, and takes
            // exactly their combined width.
            HStack(spacing: PanelStyle.topRowSpacing) {
                Spacer(minLength: 0)
                wideButton("RULES", tint: Palette.sky, action: onRules)
            }

            Spacer(minLength: 0)

            start

            Spacer(minLength: 0)

            HStack(spacing: PanelStyle.topRowSpacing) {
                wideButton("BACK", tint: Palette.red, action: onQuit)
                Spacer(minLength: 0)
            }
            // **Lifted, not padded.** A bottom padding would make the stack
            // taller and push everything above it up; an offset moves the
            // button and nothing else, which is the whole request.
            .offset(y: -PanelStyle.chromeButtonHeight)
        }
        .padding(.horizontal, PanelStyle.padding)
        .padding(.top, PanelStyle.padding)
        .padding(.bottom, PanelStyle.padding)
    }

    /// The way in. As tall as the Zodiaction button it will be replaced by, and
    /// two thirds as long — the biggest thing on the panel without being the
    /// whole panel.
    private var start: some View {
        Button(action: onStart) {
            Text("START")
                .font(.system(size: PanelStyle.startLabelSize, weight: .black, design: .rounded))
                .tracking(PanelStyle.signNameTracking)
        }
        .buttonStyle(
            SpectrumButtonStyle(
                shape: RoundedRectangle(cornerRadius: PanelStyle.buttonCorner),
                halo: AnyShape(RoundedRectangle(cornerRadius: SpectrumStyle.haloCorner)),
                isLive: session.modeCardHasLanded
            )
        )
        .frame(height: PanelStyle.zodiactionButtonHeight)
        .containerRelativeFrame(.horizontal) { width, _ in
            width * PanelStyle.startButtonLength
        }
    }

    /// A word on a button two chrome-buttons wide.
    private func wideButton(
        _ word: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        CelButton(tint: tint, action: action) {
            Text(word)
                .font(.system(size: PanelStyle.wideLabelSize, weight: .heavy, design: .rounded))
                .tracking(PanelStyle.signNameTracking)
                .foregroundStyle(Palette.warmBlack)
        }
        .frame(width: PanelStyle.wideChromeWidth, height: PanelStyle.chromeButtonHeight)
    }
}

/// One passive's mark, lit or dim.
///
/// Its own view because a flashing mark has to remember when it lit, and that
/// is state — inline in the row it would have been one piece of state shared by
/// every mark, which is exactly the bug where lighting one dims another.
private struct PassiveMark: View {

    struct Entry: Equatable {
        let mark: String
        let lit: Bool
        let flashes: Bool
    }

    let entry: Entry
    let tint: Color

    /// Whether this mark is currently showing lit.
    ///
    /// For a span this is just `entry.lit`. For a flash it is raised when
    /// `entry.lit` *becomes* true and lowered a moment later on its own, so a
    /// condition that stays true — a streak that survives the move that paid
    /// for it — does not leave the mark burning until the next step.
    @State private var showing = false

    var body: some View {
        Image(entry.mark)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: PanelStyle.passiveMarkSize, height: PanelStyle.passiveMarkSize)
            // Lit in the sign's own element, dim otherwise. See
            // `ZodiacPassive.isLit(in:)` for why most of these are spans, and
            // `ZodiacPassive.flashes(in:)` for the ones that are not.
            .foregroundStyle(showing ? tint : Palette.textSecondary)
            .animation(.easeInOut(duration: PanelStyle.passiveMarkFade), value: showing)
            .task(id: entry.lit) {
                guard entry.flashes else {
                    showing = entry.lit
                    return
                }
                guard entry.lit else { return }

                showing = true
                try? await Task.sleep(
                    nanoseconds: UInt64(PanelStyle.passiveFlashHold * 1_000_000_000)
                )
                // Cancelled means the condition changed under us and a newer
                // run of this task owns the mark. Leaving it lit is that run's
                // business, not this one's.
                guard !Task.isCancelled else { return }
                showing = false
            }
    }
}

// MARK: - The death face

/// The way out of a lost run.
///
/// Deliberately the start screen's twin — the same three places filled with the
/// same three kinds of thing, because they answer the same question at opposite
/// ends of a run. RESTART sits exactly where START did, so the player's thumb is
/// already there.
///
/// The run's numbers are here rather than on the death screen because the death
/// screen is a picture of falling, and a scoreboard drawn over it would be a
/// second thing asking to be read at the same time.
private struct PanelDeathView: View {

    let session: GameSession
    let onRestart: () -> Void
    let onChangeSign: () -> Void

    var body: some View {
        VStack(spacing: PanelStyle.rowSpacing) {
            HStack(spacing: PanelStyle.topRowSpacing) {
                Spacer(minLength: 0)
                wideButton("ZODEA", tint: Palette.sky, action: onChangeSign)
            }

            Spacer(minLength: 0)

            tally

            restart

            Spacer(minLength: 0)

            HStack(spacing: PanelStyle.topRowSpacing) {
                wideButton("BACK", tint: Palette.red, action: onChangeSign)
                Spacer(minLength: 0)
            }
            .offset(y: -PanelStyle.chromeButtonHeight)
        }
        .padding(.horizontal, PanelStyle.padding)
        .padding(.top, PanelStyle.padding)
        .padding(.bottom, PanelStyle.padding)
    }

    /// What the run came to.
    private var tally: some View {
        HStack(spacing: PanelStyle.topRowSpacing * 2) {
            count("MOVES", session.engine.moveCount)
            count("PICKUPS", session.engine.pickupsCollected)
        }
        .padding(.bottom, PanelStyle.rowSpacing)
    }

    private func count(_ label: String, _ value: Int) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.system(size: PanelStyle.startLabelSize, weight: .black, design: .rounded))
                .foregroundStyle(Palette.gold)
            Text(label)
                .font(.system(size: PanelStyle.wideLabelSize, weight: .heavy, design: .rounded))
                .tracking(PanelStyle.signNameTracking)
                .foregroundStyle(Palette.textSecondary)
        }
    }

    /// The way back in. Takes START's exact size and place.
    private var restart: some View {
        Button(action: onRestart) {
            Text("RESTART")
                .font(.system(size: PanelStyle.startLabelSize, weight: .black, design: .rounded))
                .tracking(PanelStyle.signNameTracking)
        }
        .buttonStyle(
            SpectrumButtonStyle(
                shape: RoundedRectangle(cornerRadius: PanelStyle.buttonCorner),
                halo: AnyShape(RoundedRectangle(cornerRadius: SpectrumStyle.haloCorner)),
                isLive: true
            )
        )
        .frame(height: PanelStyle.zodiactionButtonHeight)
        .containerRelativeFrame(.horizontal) { width, _ in
            width * PanelStyle.startButtonLength
        }
    }

    private func wideButton(
        _ word: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        CelButton(tint: tint, action: action) {
            Text(word)
                .font(.system(size: PanelStyle.wideLabelSize, weight: .heavy, design: .rounded))
                .tracking(PanelStyle.signNameTracking)
                .foregroundStyle(Palette.warmBlack)
        }
        .frame(width: PanelStyle.wideChromeWidth, height: PanelStyle.chromeButtonHeight)
    }
}

// MARK: - The rules page

/// What the mode about to be played does, drawn.
///
/// The page itself is `GameModeRulesView`; this is the panel around it — the
/// heading, and the way back. Kept apart so the diagram can be shown anywhere
/// the mode needs explaining without dragging a panel's chrome along with it.
private struct PanelRulesView: View {

    let session: GameSession
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // **Where RULES was.** The button that brought you here and the one
            // that takes you back are the same button seen from two sides, so
            // they get the same corner and the same size — a back button that
            // moves is one the thumb has to go looking for.
            HStack(spacing: PanelStyle.topRowSpacing) {
                Spacer(minLength: 0)
                CelButton(tint: Palette.red, action: onBack) {
                    Text("BACK")
                        .font(.system(size: PanelStyle.wideLabelSize,
                                      weight: .heavy, design: .rounded))
                        .tracking(PanelStyle.signNameTracking)
                        .foregroundStyle(Palette.warmBlack)
                }
                .frame(width: PanelStyle.wideChromeWidth,
                       height: PanelStyle.chromeButtonHeight)
            }
            .padding(.horizontal, PanelStyle.padding)
            .padding(.top, PanelStyle.padding)

            Text(session.mode.title)
                .font(.system(size: PanelStyle.signNameSize, weight: .black, design: .rounded))
                .tracking(PanelStyle.signNameTracking)
                .foregroundStyle(Palette.textPrimary)

            Text(session.mode.blurb)
                .font(.system(size: PanelStyle.summarySize, weight: .medium))
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, PanelStyle.padding)
                .padding(.top, 4)

            Spacer(minLength: 0)

            GameModeRulesView(mode: session.mode, size: PanelStyle.rulesCellSize)

            Spacer(minLength: 0)

            Spacer(minLength: 0)
                .frame(height: PanelStyle.chromeButtonHeight)
        }
    }
}
