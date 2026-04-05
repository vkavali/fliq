import SwiftUI

// MARK: - Color Hex Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 200, 200, 200)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Brand Colors

extension Color {
    // ── Core brand palette ─────────────────────────────────────────────────
    static let fliqIndigo     = Color(hex: "4F46E5")   // progress bars, accents
    static let fliqPurple     = Color(hex: "7C3AED")   // primary CTA
    static let fliqPurpleDark = Color(hex: "6D28D9")   // CTA gradient end
    static let fliqTeal       = Color(hex: "06B6D4")   // avatar circles, trust badges
    static let fliqAmber      = Color(hex: "F59E0B")   // rating / gold
    static let fliqGreen      = Color(hex: "10B981")   // success / trust
    static let fliqLilac      = Color(hex: "A29BFE")   // business accent

    // ── Light theme surfaces & text ────────────────────────────────────────
    static let fliqPageBg     = Color(hex: "F8F9FA")   // page background
    static let fliqCardBg     = Color(hex: "FFFFFF")   // card background
    static let fliqBorderLight = Color(hex: "E5E7EB")  // subtle card border
    static let fliqBorderMid  = Color(hex: "D1D5DB")   // form field border
    static let fliqTextPrimary = Color(hex: "1F2937")  // primary text
    static let fliqTextSecond  = Color(hex: "6B7280")  // secondary / muted text
    static let fliqTextMuted   = Color(hex: "9CA3AF")  // placeholder / disabled

    // ── Light theme fill levels ────────────────────────────────────────────
    static let fliqFill1      = Color(hex: "F3F4F6")   // subtle fills
    static let fliqFill2      = Color(hex: "E9ECEF")   // stronger fills
    static let fliqMintBg     = Color(hex: "F0FDFA")   // dream card tint

    // ── Legacy aliases (kept for call-site compat) ─────────────────────────
    static let nothingBorder  = Color(hex: "E5E7EB")
    static let nothingMuted   = Color(hex: "6B7280")
    static let nothingSubtle  = Color(hex: "F3F4F6")

    static let fliqBlue   = Color(hex: "4F46E5")
    static let fliqMint   = Color(hex: "10B981")
    static let fliqGold   = Color(hex: "F59E0B")
    static let fliqInk    = Color(hex: "1F2937")
    static let fliqMuted  = Color(hex: "6B7280")
    static let fliqSky    = Color(hex: "F0F9FF")
    static let fliqYellow = Color(hex: "F59E0B")
    static let fliqDark   = Color(hex: "1F2937")
    static let fliqDarkMid = Color(hex: "374151")
}

// MARK: - Background

/// Clean white / near-white page background — matches the phone mockup on fliq.co.in.
struct GradientBackground: View {
    var body: some View {
        Color(hex: "F8F9FA")
            .ignoresSafeArea()
    }
}

/// Legacy alias — renders the same light background.
struct DotGridBackground: View {
    var body: some View {
        GradientBackground()
    }
}

// MARK: - Dot-Matrix Text

/// Dot-matrix / LED-panel effect — hero accent text.
/// Default foreground is now dark to suit the light page background.
struct DotMatrixText: View {
    let text: String
    var font: Font = .system(size: 36, weight: .black, design: .monospaced)
    var foreground: Color = Color(hex: "1F2937")
    var dotSpacing: CGFloat = 3.6
    var dotSize: CGFloat = 2.2

    init(_ text: String,
         font: Font = .system(size: 36, weight: .black, design: .monospaced),
         foreground: Color = Color(hex: "1F2937"),
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

/// Primary CTA — solid accent fill, white text. Default accent is purple.
struct FliqPrimaryButtonStyle: ButtonStyle {
    var accent: Color = .fliqPurple

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(accent)
                    .opacity(configuration.isPressed ? 0.80 : 1.0)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Ghost / secondary button — white background, gray border, dark text.
struct NothingGhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(configuration.isPressed ? Color(hex: "1F2937") : Color(hex: "374151"))
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(configuration.isPressed ? Color(hex: "F3F4F6") : Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Color(hex: "D1D5DB"), lineWidth: 1)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Filled high-emphasis button — purple gradient fill, white text.
struct NothingFilledButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.fliqPurple, Color.fliqPurpleDark],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .opacity(configuration.isPressed ? 0.80 : 1.0)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
