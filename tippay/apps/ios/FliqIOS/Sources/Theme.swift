import SwiftUI

// MARK: - Brand Colors (legacy palette — kept for any remaining call sites)

extension Color {
    static let fliqIndigo   = Color(hex: "6C5CE7")   // mapped to brand accent
    static let fliqPurple   = Color(hex: "5A4BD1")
    static let fliqTeal     = Color(hex: "00B894")   // mapped to success
    static let fliqAmber    = Color(hex: "FDCB6E")
    static let fliqGreen    = Color(hex: "00B894")
    static let fliqLilac    = Color(hex: "A29BFE")
    static let fliqDark     = Color(hex: "2D3436")
    static let fliqDarkMid  = Color(hex: "636E72")

    // Legacy aliases — all map to the new light-theme palette
    static let nothingRed    = Color.dsAccent
    static let nothingBorder = Color.dsBorder
    static let nothingMuted  = Color.dsSecondary
    static let nothingSubtle = Color.dsAccentTint

    static let fliqBlue   = Color.dsAccent
    static let fliqMint   = Color(hex: "00B894")
    static let fliqGold   = Color(hex: "FDCB6E")
    static let fliqInk    = Color(hex: "2D3436")
    static let fliqMuted  = Color.dsSecondary
    static let fliqSky    = Color.dsAccentTint
    static let fliqYellow = Color(hex: "FDCB6E")
}

// MARK: - Background

/// App background — light gray matching fliq.co.in.
struct GradientBackground: View {
    var body: some View {
        Color.dsBackground.ignoresSafeArea()
    }
}

/// Legacy alias — same as GradientBackground.
struct DotGridBackground: View {
    var body: some View {
        GradientBackground()
    }
}

// MARK: - Dot-Matrix Text (kept for hero landing screen)

struct DotMatrixText: View {
    let text: String
    var font: Font = .system(size: 36, weight: .black, design: .monospaced)
    var foreground: Color = .dsAccent
    var dotSpacing: CGFloat = 3.6
    var dotSize: CGFloat = 2.2

    init(_ text: String,
         font: Font = .system(size: 36, weight: .black, design: .monospaced),
         foreground: Color = .dsAccent,
         dotSpacing: CGFloat = 3.6,
         dotSize: CGFloat = 2.2) {
        self.text = text
        self.font = font
        self.foreground = foreground
        self.dotSpacing = dotSpacing
        self.dotSize = dotSize
    }

    var body: some View {
        Text(text)
            .font(font)
            .foregroundStyle(foreground)
            .mask {
                Canvas { context, size in
                    var y: CGFloat = dotSize / 2
                    while y < size.height {
                        var x: CGFloat = dotSize / 2
                        while x < size.width {
                            context.fill(
                                Path(ellipseIn: CGRect(
                                    x: x - dotSize / 2,
                                    y: y - dotSize / 2,
                                    width: dotSize,
                                    height: dotSize
                                )),
                                with: .color(.white)
                            )
                            x += dotSpacing
                        }
                        y += dotSpacing
                    }
                }
            }
    }
}

// MARK: - Button Styles (light theme)

/// Primary CTA — solid accent fill, white text.
struct FliqPrimaryButtonStyle: ButtonStyle {
    var accent: Color = .dsAccent

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(configuration.isPressed ? accent.opacity(0.85) : accent)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Outline/ghost button — accent border and text, transparent fill.
struct NothingGhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(configuration.isPressed ? Color.dsAccentDark : Color.dsAccent)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(configuration.isPressed ? Color.dsAccentTint : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(
                                configuration.isPressed ? Color.dsAccentDark : Color.dsAccent,
                                lineWidth: 1.5
                            )
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Filled button — same as primary.
struct NothingFilledButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(configuration.isPressed ? Color.dsAccentDark : Color.dsAccent)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
