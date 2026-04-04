import SwiftUI

// MARK: - Colours

extension Color {
    // ── Nothing Phone palette ──────────────────────────────────────────────
    static let nothingRed    = Color(red: 217 / 255, green: 45 / 255,  blue: 32 / 255)  // #D92D20
    static let nothingBorder = Color.white.opacity(0.14)
    static let nothingMuted  = Color.white.opacity(0.45)
    static let nothingSubtle = Color.white.opacity(0.05)

    // ── Legacy palette (kept for compatibility with provider/business views) ──
    static let fliqBlue   = Color(red: 34 / 255,  green: 103 / 255, blue: 242 / 255)
    static let fliqMint   = Color(red: 21 / 255,  green: 149 / 255, blue: 112 / 255)
    static let fliqGold   = Color(red: 240 / 255, green: 138 / 255, blue: 36 / 255)
    static let fliqInk    = Color(red: 16 / 255,  green: 24 / 255,  blue: 40 / 255)
    static let fliqMuted  = Color(red: 76 / 255,  green: 87 / 255,  blue: 108 / 255)
    static let fliqSky    = Color(red: 245 / 255, green: 248 / 255, blue: 255 / 255)

    // ── Extended brand ─────────────────────────────────────────────────────
    static let fliqIndigo  = Color(red: 79 / 255,  green: 70 / 255,  blue: 229 / 255)
    static let fliqPurple  = Color(red: 108 / 255, green: 92 / 255,  blue: 231 / 255)
    static let fliqLilac   = Color(red: 162 / 255, green: 155 / 255, blue: 254 / 255)
    static let fliqTeal    = Color(red: 6 / 255,   green: 182 / 255, blue: 212 / 255)
    static let fliqAmber   = Color(red: 245 / 255, green: 158 / 255, blue: 11 / 255)
    static let fliqGreen   = Color(red: 0 / 255,   green: 184 / 255, blue: 148 / 255)
    static let fliqYellow  = Color(red: 253 / 255, green: 203 / 255, blue: 110 / 255)
    static let fliqDark    = Color(red: 26 / 255,  green: 17 / 255,  blue: 69 / 255)
    static let fliqDarkMid = Color(red: 45 / 255,  green: 27 / 255,  blue: 105 / 255)
}

// MARK: - Background

/// Full-screen black background with a subtle ambient dot grid.
struct DotGridBackground: View {
    var body: some View {
        ZStack {
            Color.black
            Canvas { context, size in
                let spacing: CGFloat = 22
                let dotSize: CGFloat = 1.4
                var y: CGFloat = 0
                while y < size.height + spacing {
                    var x: CGFloat = 0
                    while x < size.width + spacing {
                        context.fill(
                            Path(ellipseIn: CGRect(x: x, y: y, width: dotSize, height: dotSize)),
                            with: .color(.white.opacity(0.055))
                        )
                        x += spacing
                    }
                    y += spacing
                }
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Dot-Matrix Text

/// Renders text with a dot-matrix / LED-panel effect.
///
/// The approach: draw the text normally, then apply a Canvas mask made of
/// a uniform grid of opaque circles. Where a circle overlaps a text pixel,
/// the pixel shows through; everywhere else is clipped. The result is the
/// signature Nothing Phone dot-glyph aesthetic.
struct DotMatrixText: View {
    let text: String
    var font: Font = .system(size: 36, weight: .black, design: .monospaced)
    var foreground: Color = .white
    /// Centre-to-centre spacing between dots (lower = denser)
    var dotSpacing: CGFloat = 3.6
    /// Diameter of each dot
    var dotSize: CGFloat = 2.2

    // Allows call-site sugar: DotMatrixText("FLIQ", font: ..., ...)
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

/// Primary CTA — thin accent border, matching text, near-zero fill.
/// Defaults to Nothing red; pass any Color for per-role tinting.
struct FliqPrimaryButtonStyle: ButtonStyle {
    var accent: Color = .nothingRed

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(accent)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(accent.opacity(configuration.isPressed ? 0.10 : 0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .strokeBorder(accent.opacity(configuration.isPressed ? 1.0 : 0.5), lineWidth: 1)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Ghost button — thin white border, white text. For secondary actions on dark bg.
struct NothingGhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color.white.opacity(configuration.isPressed ? 1.0 : 0.65))
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.07 : 0.02))
                    .overlay(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .strokeBorder(Color.white.opacity(configuration.isPressed ? 0.45 : 0.18), lineWidth: 1)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Solid white fill, black text — highest-contrast action (e.g. final tip CTA).
struct NothingFilledButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.black)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.88 : 1.0))
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
