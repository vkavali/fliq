import SwiftUI

// MARK: - Brand Colors

extension Color {
    // ── Web app palette — indigo/purple gradient theme ───────────────────────
    static let fliqIndigo   = Color(red: 79 / 255,  green: 70 / 255,  blue: 229 / 255)  // #4F46E5
    static let fliqPurple   = Color(red: 124 / 255, green: 58 / 255,  blue: 237 / 255)  // #7C3AED
    static let fliqTeal     = Color(red: 6 / 255,   green: 182 / 255, blue: 212 / 255)  // #06B6D4
    static let fliqAmber    = Color(red: 245 / 255, green: 158 / 255, blue: 11 / 255)   // #F59E0B
    static let fliqGreen    = Color(red: 16 / 255,  green: 185 / 255, blue: 129 / 255)  // #10B981
    static let fliqLilac    = Color(red: 162 / 255, green: 155 / 255, blue: 254 / 255)
    static let fliqDark     = Color(red: 15 / 255,  green: 12 / 255,  blue: 41 / 255)   // #0F0C29
    static let fliqDarkMid  = Color(red: 48 / 255,  green: 43 / 255,  blue: 99 / 255)   // #302b63

    // ── Aliases for legacy references in provider/business/customer views ────
    // nothingRed → primary indigo accent
    static let nothingRed    = Color(red: 79 / 255, green: 70 / 255, blue: 229 / 255)
    static let nothingBorder = Color.white.opacity(0.18)
    static let nothingMuted  = Color.white.opacity(0.55)
    static let nothingSubtle = Color.white.opacity(0.08)

    // Kept for any remaining legacy call sites
    static let fliqBlue    = Color(red: 79 / 255,  green: 70 / 255,  blue: 229 / 255)
    static let fliqMint    = Color(red: 16 / 255,  green: 185 / 255, blue: 129 / 255)
    static let fliqGold    = Color(red: 245 / 255, green: 158 / 255, blue: 11 / 255)
    static let fliqInk     = Color(red: 15 / 255,  green: 12 / 255,  blue: 41 / 255)
    static let fliqMuted   = Color.white.opacity(0.55)
    static let fliqSky     = Color.white.opacity(0.1)
    static let fliqYellow  = Color(red: 245 / 255, green: 158 / 255, blue: 11 / 255)
}

// MARK: - Background

/// Full-screen indigo → purple gradient with ambient glows — matches web app.
struct GradientBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.fliqIndigo, Color.fliqPurple],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [Color.fliqIndigo.opacity(0.55), .clear],
                center: UnitPoint(x: 0.15, y: 0.5),
                startRadius: 0,
                endRadius: 260
            )
            RadialGradient(
                colors: [Color.fliqTeal.opacity(0.18), .clear],
                center: UnitPoint(x: 0.85, y: 0.28),
                startRadius: 0,
                endRadius: 200
            )
        }
        .ignoresSafeArea()
    }
}

/// Legacy name still used across all view files — now renders the gradient.
struct DotGridBackground: View {
    var body: some View {
        GradientBackground()
    }
}

// MARK: - Dot-Matrix Text

/// Dot-matrix / LED-panel effect — kept for hero accent text.
/// Default foreground is now white to suit the gradient background.
struct DotMatrixText: View {
    let text: String
    var font: Font = .system(size: 36, weight: .black, design: .monospaced)
    var foreground: Color = .white
    var dotSpacing: CGFloat = 3.6
    var dotSize: CGFloat = 2.2

    init(_ text: String,
         font: Font = .system(size: 36, weight: .black, design: .monospaced),
         foreground: Color = .white,
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

// MARK: - Button Styles

/// Primary CTA — indigo → teal gradient fill, white text.
struct FliqPrimaryButtonStyle: ButtonStyle {
    var accent: Color = .fliqIndigo

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [accent, Color.fliqTeal],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .opacity(configuration.isPressed ? 0.75 : 1.0)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Ghost button — semi-transparent white fill + white border.
/// Used for secondary actions on the gradient background.
struct NothingGhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color.white.opacity(configuration.isPressed ? 1.0 : 0.88))
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.18 : 0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(
                                Color.white.opacity(configuration.isPressed ? 0.5 : 0.3),
                                lineWidth: 1
                            )
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Highest-emphasis action — opaque indigo fill, white text.
struct NothingFilledButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.fliqIndigo, Color.fliqTeal],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .opacity(configuration.isPressed ? 0.75 : 1.0)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
