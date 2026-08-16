//
//  iMAPicker.swift
//  Rota
//
//  A drop-in picker that imitates Apple's pre-iOS 26 iMessage App picker:
//
//    • Full-screen black overlay (slight blur on prior content).
//    • Options render in a scrollable leading VStack with ~40% top padding
//      for thumb-reachability.
//    • Each row blurs progressively as it scrolls off either edge.
//    • On activation, rows "fan out" from the source button — each starts
//      at the source frame with (scale ≈ 0.25, opacity 0, blur ≈ 12) and
//      springs to its natural position with a staggered delay. The source
//      button simultaneously opacity-fades, scales up, and blurs out.
//
//  Usage:
//
//    1. Attach the host once, somewhere above every picker site (app root is
//       the typical spot — `ContentView`'s outer ZStack):
//
//         someRootView.iMAPickerHost()
//
//    2. Use `iMAPicker` as a Button replacement anywhere below that:
//
//         iMAPicker(items: cards, selection: $chosen) {
//             // Trigger appearance (what the user sees in the list/row).
//             Image(systemName: "rectangle.stack")
//         } row: { card, isSelected in
//             // How each option renders in the overlay list.
//             HStack {
//                 Text(card.name)
//                 if isSelected { Image(systemName: "checkmark") }
//             }
//         }
//
//  Note: the lowercase type name (`iMAPicker`) is intentional due to inspiration
//
//  Brought over from Rota. Three things it depended on there and does not have
//  here — `SquishButtonStyle`, `Screen`, and an environment default that can be
//  built off the main actor — are supplied at the bottom of this file rather
//  than by editing the picker itself, so it can be diffed against its original.
//

import SwiftUI

// MARK: - Controller

/// Shared state for the picker overlay. One instance lives on the host
/// modifier and is injected through the environment.
@MainActor @Observable
final class iMAPickerController {
    fileprivate var isPresented: Bool = false
    fileprivate var sourceFrame: CGRect = .zero
    fileprivate var sourceID: UUID? = nil
    fileprivate var overlayContent: AnyView? = nil

    fileprivate func present(
        from frame: CGRect,
        id: UUID,
        @ViewBuilder content: () -> some View
    ) {
        self.sourceFrame = frame
        self.sourceID = id
        self.overlayContent = AnyView(content())
        withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
            self.isPresented = true
        }
    }

    fileprivate func dismiss() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            isPresented = false
        }
        // Clear source-ID slightly after the transition so the source button
        // reappears in sync with the overlay fading out.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            guard let self, !self.isPresented else { return }
            self.sourceID = nil
            self.overlayContent = nil
        }
    }
}

// MARK: - Environment plumbing

extension EnvironmentValues {
    // Optional, with `nil` as the default.
    //
    // The controller is `@MainActor`, so building one as an environment default
    // means calling a main-actor initialiser from a nonisolated context — which
    // is what broke the app's start-up. The host modifier makes the real one and
    // puts it in; anything reading this before that has nothing to talk to, and
    // says so.
    @Entry fileprivate var imaPicker: iMAPickerController?
}

// MARK: - Host modifier

/// Attach once at (or above) the root of everything that might present a
/// picker. This is where the overlay actually renders — the picker buttons
/// themselves only publish state; they cannot escape their own clip bounds
/// (e.g. a ScrollView row), so the host has to live higher up the tree.
private struct iMAPickerHostModifier: ViewModifier {
    @State private var controller = iMAPickerController()

    func body(content: Content) -> some View {
        ZStack {
            content
                .environment(\.imaPicker, controller)
                .blur(radius: controller.isPresented ? 3 : 0)
                .allowsHitTesting(!controller.isPresented)
                .animation(.easeInOut(duration: 0.6), value: controller.isPresented)

            if controller.isPresented {
                // Dim layer — taps dismiss.
                Color.black
                    .opacity(0.66)
                    .ignoresSafeArea()
                    .transition(.opacity.animation(.easeInOut(duration: 0.6)))
                    .contentShape(Rectangle())
                    .onTapGesture { controller.dismiss() }

                if let overlay = controller.overlayContent {
                    overlay
                        .transition(.opacity)
                }
            }
        }
    }
}

extension View {
    /// Install the iMAPicker overlay host. Attach once, high in the tree.
    func iMAPickerHost() -> some View {
        modifier(iMAPickerHostModifier())
    }
}

// MARK: - Trigger

/// A Button-like view that presents its `items` in the iMAPicker overlay.
/// Generic over any `Hashable` item plus user-provided label and row builders.
struct iMAPicker<Item: Hashable, Label: View, Row: View>: View {
    let items: [Item]
    @Binding var selection: Item?
    @ViewBuilder let label: () -> Label
    /// `(item, isSelected) -> Row`. Selected state lets callers draw a
    /// checkmark / highlight without threading `selection` through themselves.
    @ViewBuilder let row: (Item, Bool) -> Row

    @Environment(\.imaPicker) private var controller
    @State private var sourceFrame: CGRect = .zero
    @State private var id = UUID()

    /// True while THIS picker's overlay is the one currently presented.
    private var isActive: Bool {
        controller?.isPresented == true && controller?.sourceID == id
    }

    var body: some View {
        Button {
            controller?.present(from: sourceFrame, id: id) {
                iMAPickerList(
                    items: items,
                    selectedItem: selection,
                    sourceFrame: sourceFrame,
                    row: row,
                    onSelect: { item in
                        selection = item
                        controller?.dismiss()
                    },
                    onDismiss: { controller?.dismiss() }
                )
            }
        } label: {
            label()
        }
        .buttonStyle(SquishButtonStyle())
        // Source-button vanish effect: fade + scale-up + blur.
        .opacity(isActive ? 0 : 1)
        .scaleEffect(isActive ? 1.35 : 1)
        .blur(radius: isActive ? 10 : 0)
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: isActive)
        // Track source frame in global space so the overlay can originate
        // its fan-out animation from here.
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { sourceFrame = geo.frame(in: .global) }
                    .onChange(of: geo.frame(in: .global)) { _, new in
                        sourceFrame = new
                    }
            }
        )
    }
}

// MARK: - Overlay list

private struct iMAPickerList<Item: Hashable, Row: View>: View {
    let items: [Item]
    let selectedItem: Item?
    let sourceFrame: CGRect
    let row: (Item, Bool) -> Row
    let onSelect: (Item) -> Void
    let onDismiss: () -> Void

    /// Flips true after first layout to kick off the "fan out from source"
    /// animation. Before it's true, rows render at the source position.
    @State private var fannedOut = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(Array(items.enumerated()), id: \.element) { index, item in
                    iMAPickerRow(
                        index: index,
                        sourceFrame: sourceFrame,
                        fannedOut: fannedOut
                    ) {
                        Button {
                            onSelect(item)
                        } label: {
                            row(item, item == selectedItem)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, iMAPickerScreen.height * 0.4)
            .padding(.bottom, iMAPickerScreen.height * 0.2)
            .frame(maxWidth: .infinity, alignment: .leading)
            // Tap-to-dismiss on empty overlay space. Row Buttons absorb
            // their own taps before this ever fires.
            .contentShape(Rectangle())
            .onTapGesture { onDismiss() }
        }
        .scrollClipDisabled()
        .onAppear {
            // One async hop so each row's GeometryReader has captured its
            // final frame before we flip the animation flag.
            DispatchQueue.main.async { fannedOut = true }
        }
    }
}

/// One row in the overlay. Reads its own rendered frame so it knows the
/// delta between its natural position and the source — that delta is the
/// offset we reverse-animate on appearance.
private struct iMAPickerRow<Content: View>: View {
    let index: Int
    let sourceFrame: CGRect
    let fannedOut: Bool
    @ViewBuilder let content: () -> Content

    @State private var finalFrame: CGRect = .zero

    private var dx: CGFloat {
        guard finalFrame != .zero else { return 0 }
        return sourceFrame.midX - finalFrame.midX
    }
    private var dy: CGFloat {
        guard finalFrame != .zero else { return 0 }
        return sourceFrame.midY - finalFrame.midY
    }

    var body: some View {
        content()
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onAppear { finalFrame = geo.frame(in: .global) }
                        .onChange(of: geo.frame(in: .global)) { _, new in
                            // Only update while we're still pre-animation; once
                            // fanned out, reading scroll-induced frame changes
                            // would tug the animation.
                            if !fannedOut { finalFrame = new }
                        }
                }
            )
            // Pre-animation state: sitting on top of the source, small + blurry.
            .scaleEffect(fannedOut ? 1 : 0.3, anchor: .center)
            .opacity(fannedOut ? 1 : 0)
            .blur(radius: fannedOut ? 0 : 14)
            .offset(x: fannedOut ? 0 : dx, y: fannedOut ? 0 : dy)
            .animation(
                .spring(response: 0.6, dampingFraction: 0.7),
                    //.delay(Double(index) * 0.045),
                value: fannedOut
            )
            // Depth-of-field: rows scrolling off the top/bottom blur out.
            .scrollTransition(.animated, axis: .vertical) { content, phase in
                content
                    .blur(radius: phase.isIdentity ? 0 : abs(phase.value) * 8)
                    .opacity(phase.isIdentity ? 1 : 1 - abs(phase.value) * 0.5)
            }
    }
}


// MARK: - What Rota supplied

/// The screen, for the picker's proportional padding.
///
/// Rota had this as a shared helper; here it is only the picker that wants it,
/// so it lives with the picker.
enum iMAPickerScreen {
    static var height: CGFloat { UIScreen.main.bounds.height }
    static var width: CGFloat { UIScreen.main.bounds.width }
}

/// A button that gives under the thumb.
///
/// The one piece of Rota's look the picker actually reaches for. Kept small and
/// local rather than folded into `PanelStyle`, because the panel's buttons are
/// drawn as two stacked faces and this is a scale — they are different ideas
/// and merging them would make both harder to change.
struct SquishButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.spring(response: 0.24, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
