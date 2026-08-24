//
//  PlaneBadgeView.swift
//  Project Stars
//
//  Which plane the board is showing.
//

import SwiftUI

/// The plane's name, on its own drawn plaque.
///
/// The plaque is art now rather than a tinted capsule — Astra's is a night sky
/// with stars in it, Terra's a hill under cloud. Both are busy, which is a
/// problem for a label: white text over a starfield is white text with holes in
/// it. A flat `midnight` wash between the two fixes that without flattening the
/// drawing, and it is deliberately weak enough that the art still reads through.
/// Everything both copies of the name share, so the shadow cannot drift away
/// from the letters it is under.
private struct BadgeLabel: ViewModifier {

    /// Whole-pixel scale, so the lift below is an art pixel rather than a point.
    let scale: CGFloat

    func body(content: Content) -> some View {
        content
            .font(.system(size: 12, weight: .heavy, design: .monospaced))
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .tracking(GameRules.planeBadgeTracking)
            // **Up one art pixel.**
            //
            // The word centres in the plaque's whole frame, and the plaque is
            // not symmetrical — its border is eight pixels at the top and nine
            // at the bottom, so the middle of the box is half a pixel below the
            // middle of the *panel*. Rounded to whole pixels that reads as one
            // pixel low, which on a two-row plaque is plainly visible.
            .offset(y: -GameRules.planeBadgeLabelLift * scale)
    }
}

struct PlaneBadgeView: View {

    let plane: Plane

    /// How big the plaque is, in cells: seven across, two down.
    ///
    /// The art is centred inside those two rows, so the frame has to be the
    /// full two — cropping it to one cuts the top off the drawing.
    private static let cells = CGSize(width: 7, height: 2)

    /// Point size of one art pixel here.
    ///
    /// **Chrome, not board art.** The board draws at three or four points a
    /// pixel because it is the thing being looked at; this is a caption in the
    /// corner, and at the board's scale a seven-cell plaque is a third of the
    /// screen wide. One and a half puts it at the size the capsule it replaced
    /// used to be.
    var scale: CGFloat = GameRules.planeBadgeScale

    var body: some View {
        PixelSprite(id: .planeBadge(plane)) { EmptyView() }
            .frame(
                width: CGFloat(GameRules.tilePixelSize) * Self.cells.width * scale,
                height: CGFloat(GameRules.tilePixelSize) * Self.cells.height * scale
            )
            .overlay {
                // **A rectangle, because the field genuinely is one.**
                //
                // The plaque is a drawn border around a flat panel, and it is
                // only the panel that should dim — washing the border too took
                // the colour out of the frame. Inset by its thickness, so the
                // border keeps its own colour and the name still has something
                // dark to sit on.
                //
                // Worth being explicit, since a rectangle was the *wrong*
                // answer here an hour ago: it was wrong when it stood in for
                // the badge's whole silhouette, and it is right now because the
                // region being described is a rectangle. The shape of the
                // solution has to match the shape of the thing.
                Rectangle()
                    .fill(Palette.midnight)
                    .opacity(GameRules.planeBadgeWash)
                    .padding(.horizontal, GameRules.planeBadgeBorder * scale)
                    .padding(.top, GameRules.planeBadgeBorderTop * scale)
                    .padding(.bottom, GameRules.planeBadgeBorderBottom * scale)

                // A hard pixel shadow, one art pixel down and right.
                //
                // No blur and no softening: this is pixel art, and a blurred
                // drop shadow is the one thing that reads as belonging to a
                // different medium than everything around it.
                Text(plane.displayName.uppercased())
                    .foregroundStyle(Palette.coolBlack)
                    .offset(
                        x: GameRules.planeBadgeShadow * scale,
                        y: GameRules.planeBadgeShadow * scale
                    )
                    .modifier(BadgeLabel(scale: scale))

                Text(plane.displayName.uppercased())
                    .foregroundStyle(Palette.textPrimary)
                    .modifier(BadgeLabel(scale: scale))
            }
            .animation(.easeInOut(duration: 0.25), value: plane)
            .allowsHitTesting(false)
    }
}
