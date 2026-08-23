//
//  Extensions.swift
//  Plentacle
//
//  Created by SorseC0de on 2/28/26.
//

import SwiftUI
import UIKit

// MARK: - Keyboard Dismissal

extension UIApplication {
    /// Resigns first responder on any active text field. Used when the user
    /// navigates away from search mode (opens CardDetail, Settings, WOF, etc.)
    /// so the keyboard doesn't linger behind the new screen.
    static func dismissKeyboard() {
        shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - Icon Labels Environment Key

/// Read-only environment flag so any view can check whether the user has
/// enabled visible icon labels in Settings.  ContentView owns the
/// `@State` and publishes via `.environment(\.iconLabels, iconLabels)`.
private struct IconLabelsKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    var iconLabels: Bool {
        get { self[IconLabelsKey.self] }
        set { self[IconLabelsKey.self] = newValue }
    }
}

/// Tiny overlay text shown beneath an icon when the user has enabled
/// visible icon labels.  Uses `.allowsHitTesting(false)` so it never
/// steals taps from the icon it decorates.
struct IconLabel: View {
    let text: String
    var color: Color = .white
    var blendMode: BlendMode = .normal

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: text.uppercased() == "BACK" ? 12 : 8, weight: .heavy))
            .kerning(0.3)
            .foregroundStyle(color)
            .lineLimit(1)
            .fixedSize()
            .blendMode(blendMode)
            .allowsHitTesting(false)
            .contentTransition(.numericText())
    }
}

// MARK: - Color Extensions

extension Color {
    /// Lightens the color by the specified amount
    /// - Parameter amount: The amount to lighten (0.0 to 1.0)
    /// - Returns: A lightened color
    func lightened(by amount: CGFloat) -> Color {
        return self.adjustBrightness(by: abs(amount))
    }
    
    /// Darkens the color by the specified amount
    /// - Parameter amount: The amount to darken (0.0 to 1.0)
    /// - Returns: A darkened color
    func darkened(by amount: CGFloat) -> Color {
        return self.adjustBrightness(by: -abs(amount))
    }
    
    /// Adjusts the brightness of the color
    /// - Parameter amount: The amount to adjust (-1.0 to 1.0)
    /// - Returns: An adjusted color
    private func adjustBrightness(by amount: CGFloat) -> Color {
        #if canImport(UIKit)
        let uiColor = UIColor(self)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        // Try HSB color space first
        if uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) {
            // For lightening colors that are already bright, reduce saturation instead
            if amount > 0 && brightness > 0.8 {
                let adjustedSaturation = max(saturation - amount * 0.5, 0)
                let adjustedBrightness = min(brightness + amount * 0.3, 1)
                
                return Color(UIColor(
                    hue: hue,
                    saturation: adjustedSaturation,
                    brightness: adjustedBrightness,
                    alpha: alpha
                ))
            } else {
                let adjustedBrightness = min(max(brightness + amount, 0), 1)
                
                return Color(UIColor(
                    hue: hue,
                    saturation: saturation,
                    brightness: adjustedBrightness,
                    alpha: alpha
                ))
            }
        } else {
            // Fallback to RGB if HSB fails
            var red: CGFloat = 0
            var green: CGFloat = 0
            var blue: CGFloat = 0
            
            uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
            
            if amount > 0 {
                // Lightening - blend with white
                let blend = amount
                red = red + (1 - red) * blend
                green = green + (1 - green) * blend
                blue = blue + (1 - blue) * blend
            } else {
                // Darkening - blend with black
                let blend = abs(amount)
                red = red * (1 - blend)
                green = green * (1 - blend)
                blue = blue * (1 - blend)
            }
            
            return Color(UIColor(red: red, green: green, blue: blue, alpha: alpha))
        }
        #elseif canImport(AppKit)
        let nsColor = NSColor(self)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        nsColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        
        // Same logic as iOS
        if amount > 0 && brightness > 0.8 {
            let adjustedSaturation = max(saturation - amount * 0.5, 0)
            let adjustedBrightness = min(brightness + amount * 0.3, 1)
            
            return Color(NSColor(
                hue: hue,
                saturation: adjustedSaturation,
                brightness: adjustedBrightness,
                alpha: alpha
            ))
        } else {
            let adjustedBrightness = min(max(brightness + amount, 0), 1)
            
            return Color(NSColor(
                hue: hue,
                saturation: saturation,
                brightness: adjustedBrightness,
                alpha: alpha
            ))
        }
        #else
        return self
        #endif
    }
}

extension Color {
    init(hex: Int, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 08) & 0xff) / 255,
            blue: Double((hex >> 00) & 0xff) / 255,
            opacity: opacity
        )
    }
}

extension View {
    func multicolorGlow() -> some View {
        ZStack {
            ForEach(0..<2) { i in
                Rectangle()
                    .fill(AngularGradient(gradient:
                        Gradient(colors:
                        [Color.blue,
                         Color.purple,
                         Color.orange,
                         Color.red]), center: .center))
                    .frame(width: 400, height: 300)
                    .mask(self.blur(radius: 20))
                    .overlay(self.blur(radius: 5 - CGFloat(i * 5)))
            }
        }
    }
}
// MARK: - Clipped Window

extension View {
    /// Clips the view to a fixed height with an adjustable window position.
    /// - Parameters:
    ///   - height: The visible frame height.
    ///   - yOffset: Vertical shift applied before clipping. Negative values reveal content further down the source.
    ///   - xOffset: Horizontal shift applied before clipping.
    func clippedWindow(height: CGFloat, yOffset: CGFloat = 0, xOffset: CGFloat = 0) -> some View {
        self
            .offset(x: xOffset, y: yOffset)
            .frame(height: height)
            .clipped()
    }
    
    @inlinable
    public func reverseMask<Mask: View>(alignment: Alignment = .center, @ViewBuilder _ mask: () -> Mask) -> some View {
        self.mask(
            Rectangle()
                .overlay(alignment: alignment) {
                    mask()
                        .blendMode(.destinationOut)
                }
        )
    }
}

// MARK: - Custom Views

struct Dots: View {
    let count: Int
    let dotSize: CGFloat
    let xOffset: CGFloat
    /// When true, each dot pulses in size on its own randomized phase via
    /// `TimelineView(.animation)` instead of marching in lock-step.
    var nonUniformPulse: Bool = false
    /// Palette to randomly sample per-dot shadow colors from. Empty palette
    /// means no shadow.
    var shadowPalette: [Color] = []

    // Per-dot randoms — sealed at init so re-renders don't re-roll them.
    private let perDotPhase: [Double]
    private let perDotShadow: [Color]

    init(count: Int,
         dotSize: CGFloat,
         xOffset: CGFloat,
         nonUniformPulse: Bool = false,
         shadowPalette: [Color] = []) {
        self.count = count
        self.dotSize = dotSize
        self.xOffset = xOffset
        self.nonUniformPulse = nonUniformPulse
        self.shadowPalette = shadowPalette
        // Stable random distributions, sampled once per Dots instance.
        self.perDotPhase = (0..<count).map { _ in Double.random(in: 0..<(2 * .pi)) }
        self.perDotShadow = (0..<count).map { _ in
            shadowPalette.randomElement() ?? .clear
        }
    }

    var body: some View {
        if nonUniformPulse {
            // TimelineView ticks each frame so we can drive per-dot sin phases.
            TimelineView(.animation) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                ringContent(timeOrNil: t)
            }
        } else {
            ringContent(timeOrNil: nil)
        }
    }

    @ViewBuilder
    private func ringContent(timeOrNil: TimeInterval?) -> some View {
        ZStack {
            ForEach(0..<count, id: \.self) { i in
                let scale: CGFloat = {
                    guard let t = timeOrNil else { return 1.0 }
                    // 3 Hz angular freq + per-dot phase → desynced bobble.
                    // Maps sin(-1...1) → 0.4...1.0 so dots don't disappear.
                    return CGFloat(0.7 + 0.3 * sin(t * 3 + perDotPhase[i]))
                }()
                let s = max(0.001, dotSize * scale)
                dot(size: s, shadow: perDotShadow[i])
                    .rotationEffect(.degrees(Double(i * 365 / count)))
            }
        }
    }

    private func dot(size: CGFloat, shadow: Color) -> some View {
        Group {
            // Hidden centerpiece preserves the rotation-around-center geometry
            // the original implementation relied on.
            Circle()
                .frame(width: size, height: size)
                .hidden()
            Circle()
                .frame(width: size, height: size)
                .shadow(color: shadow, radius: 5)
                .offset(x: xOffset)
        }
    }
}

struct RadialPattern: View {
    let size: CGFloat
    let animate: Bool
    /// When true, each dot pulses on its own random phase (via per-dot
    /// `TimelineView`) instead of all dots beating together. Off by default
    /// to preserve the prior call-site behavior.
    var nonUniformPulse: Bool = false

    @State private var rotDegrees = 0.0
    @State private var dotPulse: CGFloat = 1.0
    @State private var opacity: Double = 1.0

    /// Universal suit colors — sampled per-dot for shadow tinting.
    private static let suitShadowPalette: [Color] = [.purple, .blue, .green, .red, .yellow]

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.clear)
            Dots(count: 20, dotSize: dotPulse / 10, xOffset: size / 2,
                 nonUniformPulse: nonUniformPulse,
                 shadowPalette: Self.suitShadowPalette)
            Dots(count: 20, dotSize: dotPulse / 15, xOffset: size / 2.4,
                 nonUniformPulse: nonUniformPulse,
                 shadowPalette: Self.suitShadowPalette)
                .rotationEffect(.degrees(25))
            Dots(count: 20, dotSize: dotPulse / 20, xOffset: size / 2.9,
                 nonUniformPulse: nonUniformPulse,
                 shadowPalette: Self.suitShadowPalette)
            Dots(count: 20, dotSize: dotPulse / 15, xOffset: size / 1.7,
                 nonUniformPulse: nonUniformPulse,
                 shadowPalette: Self.suitShadowPalette)
                .rotationEffect(.degrees(25))
            Dots(count: 20, dotSize: dotPulse / 20, xOffset: size / 1.6,
                 nonUniformPulse: nonUniformPulse,
                 shadowPalette: Self.suitShadowPalette)
        }
        .rotationEffect(.degrees(rotDegrees))
        .onAppear {
            if animate {
                rotDegrees = 360
                opacity = 0
                dotPulse = size
            }
        }
        .animation(.linear(duration: 3).repeatForever(autoreverses: false), value: rotDegrees)
        .animation(.linear(duration: 0.3).repeatForever(autoreverses: true), value: opacity)
        // Global lock-step pulse stays in place when nonUniformPulse=false; when
        // true, the TimelineView in Dots takes over the per-dot scale.
        .animation(.bouncy(duration: 0.1, extraBounce: 2.0).repeatForever(autoreverses: true), value: dotPulse)
    }
}

// MARK: - Screen Utilities

enum Screen {
    static var bounds: CGRect {
        let scene = UIApplication.shared.connectedScenes
            .first as? UIWindowScene
        return scene?.windows.first?.screen.bounds ?? .zero
    }
    static var size: CGSize { bounds.size }
    static var width: CGFloat { bounds.width }
    static var height: CGFloat { bounds.height }
    static var safeAreaTop: CGFloat {
        let scene = UIApplication.shared.connectedScenes
            .first as? UIWindowScene
        return scene?.windows.first?.safeAreaInsets.top ?? 59
    }
}

// MARK: - Shapes

/// Per-corner rounded rectangle — API-compatible shim around SwiftUI's
/// native `UnevenRoundedRectangle` (iOS 16+). Keeps `UIRectCorner` call
/// sites working while dropping the UIKit `UIBezierPath` dependency.
/// Corner positions are mapped positionally (topLeft → topLeading, etc.),
/// which matches the previous behaviour in LTR layouts.
struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let r = radius
        let radii = RectangleCornerRadii(
            topLeading:     corners.contains(.topLeft)     ? r : 0,
            bottomLeading:  corners.contains(.bottomLeft)  ? r : 0,
            bottomTrailing: corners.contains(.bottomRight) ? r : 0,
            topTrailing:    corners.contains(.topRight)    ? r : 0
        )
        return UnevenRoundedRectangle(cornerRadii: radii, style: .continuous).path(in: rect)
    }
}


// MARK: - Strings

extension String {
    func widthWithFont( _ font: UIFont) -> CGFloat {
        let attributes = [NSAttributedString.Key.font: font]
        let size = self.size(withAttributes: attributes)
        return size.width
    }
}

/// Renders inline text with **quoted** segments styled differently.
/// Wrap text in `**` delimiters to mark it as quoted, e.g.:
/// `"Always forgetting what **Nine of Swords** means?"`
struct QuotedText<S1: ShapeStyle, S2: ShapeStyle>: View {
    let fullText: String
    let textStyle: S1
    let quoteTextStyle: S2

    var body: some View {
        parse(fullText)
    }

    private func parse(_ input: String) -> Text {
        let segments = input.components(separatedBy: "**")
        var result = Text("")
        for (index, segment) in segments.enumerated() {
            if segment.isEmpty { continue }
            if index % 2 == 1 {
                // Odd segments are between ** delimiters — quoted style
                result = Text("\(result) \(Text(segment).foregroundStyle(quoteTextStyle).bold())")
            } else {
                result = Text("\(result) \(Text(segment).foregroundStyle(textStyle))")
            }
        }
        return result
    }
}
