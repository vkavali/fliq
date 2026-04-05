import SwiftUI

// MARK: - Design System
// Light theme matching fliq.co.in
// Primary: #6C5CE7 · Background: #F8F9FA · Card: #FFFFFF · Text: #2D3436

// MARK: - Color Tokens

extension Color {
    // Page & surface
    static let dsBackground   = Color(hex: "F8F9FA")
    static let dsSurface      = Color.white
    static let dsBorder       = Color(hex: "E5E7EB")
    static let dsBorderLight  = Color(hex: "F3F4F6")

    // Brand / accent
    static let dsAccent       = Color(hex: "6C5CE7")
    static let dsAccentDark   = Color(hex: "5A4BD1")
    static let dsAccentLight  = Color(hex: "A29BFE")
    static let dsAccentTint   = Color(hex: "F0EDFF")

    // Text
    static let dsPrimary      = Color(hex: "2D3436")
    static let dsSecondary    = Color(hex: "636E72")
    static let dsTertiary     = Color(hex: "B2BEC3")

    // Semantic
    static let dsSuccess      = Color(hex: "00B894")
    static let dsWarning      = Color(hex: "FDCB6E")
    static let dsError        = Color(hex: "E17055")
    static let dsSuccessTint  = Color(hex: "E8F8F5")
    static let dsErrorTint    = Color(hex: "FDF0ED")
}

extension Color {
    init(hex: String) {
        var hex = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hex.hasPrefix("#") { hex.removeFirst() }
        var rgb: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&rgb)
        let r = Double((rgb >> 16) & 0xFF) / 255
        let g = Double((rgb >> 8) & 0xFF) / 255
        let b = Double(rgb & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Typography

enum DS {
    enum Typography {
        static let largeTitle  = Font.system(size: 28, weight: .bold, design: .default)
        static let title       = Font.system(size: 22, weight: .bold, design: .default)
        static let title2      = Font.system(size: 18, weight: .semibold, design: .default)
        static let headline    = Font.system(size: 16, weight: .semibold, design: .default)
        static let body        = Font.system(size: 15, weight: .regular, design: .default)
        static let bodyMedium  = Font.system(size: 15, weight: .medium, design: .default)
        static let footnote    = Font.system(size: 13, weight: .regular, design: .default)
        static let caption     = Font.system(size: 12, weight: .medium, design: .default)
        static let micro       = Font.system(size: 11, weight: .semibold, design: .default)
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }

    enum CornerRadius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let card: CGFloat = 16
        static let lg: CGFloat = 20
    }
}

// MARK: - Light App Background

struct LightBackground: View {
    var body: some View {
        Color.dsBackground.ignoresSafeArea()
    }
}

// MARK: - Card

struct FliqCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(DS.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.dsSurface)
            .cornerRadius(DS.CornerRadius.card)
            .shadow(color: Color.dsPrimary.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Section Header

struct FliqSectionHeader: View {
    let title: String
    init(_ title: String) { self.title = title }

    var body: some View {
        Text(title)
            .font(DS.Typography.title2)
            .foregroundStyle(Color.dsPrimary)
    }
}

// MARK: - Text Field

struct FliqTextField: View {
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var axis: Axis = .horizontal

    var body: some View {
        TextField(placeholder, text: $text, axis: axis)
            .keyboardType(keyboardType)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .font(DS.Typography.bodyMedium)
            .foregroundStyle(Color.dsPrimary)
            .lineLimit(axis == .vertical ? 3...6 : 1...1)
            .padding(13)
            .background(Color.dsSurface)
            .cornerRadius(DS.CornerRadius.sm)
            .overlay(
                RoundedRectangle(cornerRadius: DS.CornerRadius.sm)
                    .strokeBorder(Color.dsBorder, lineWidth: 1)
            )
    }
}

// MARK: - Divider

struct FliqDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.dsBorder)
            .frame(height: 1)
    }
}

// MARK: - Row Detail

struct FliqDetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(DS.Typography.footnote)
                .foregroundStyle(Color.dsSecondary)
            Spacer()
            Text(value)
                .font(DS.Typography.footnote)
                .fontWeight(.semibold)
                .foregroundStyle(Color.dsPrimary)
                .multilineTextAlignment(.trailing)
        }
    }
}

// MARK: - Amount Display

struct FliqAmountDisplay: View {
    let amount: Int   // in paise
    var label: String = ""

    private var rupees: Int { amount / 100 }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if !label.isEmpty {
                Text(label)
                    .font(DS.Typography.micro)
                    .foregroundStyle(Color.dsSecondary)
            }
            Text("₹\(rupees)")
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(Color.dsPrimary)
        }
    }
}

// MARK: - Tip Status Badge

struct FliqStatusBadge: View {
    let status: String

    private var color: Color {
        switch status.uppercased() {
        case "PAID", "SETTLED", "SUCCESS", "COMPLETED": return .dsSuccess
        case "INITIATED", "PENDING": return .dsWarning
        case "FAILED", "REFUNDED": return .dsError
        default: return .dsSecondary
        }
    }

    private var label: String {
        switch status.uppercased() {
        case "PAID": return "Paid"
        case "SETTLED": return "Settled"
        case "INITIATED": return "Processing"
        case "PENDING": return "Pending"
        case "FAILED": return "Failed"
        case "REFUNDED": return "Refunded"
        case "SUCCESS": return "Success"
        case "COMPLETED": return "Completed"
        default: return status
        }
    }

    var body: some View {
        Text(label)
            .font(DS.Typography.caption)
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .cornerRadius(20)
    }
}

// MARK: - Error Banner

struct FliqErrorBanner: View {
    let message: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(Color.dsError)
            Text(message)
                .font(DS.Typography.footnote)
                .foregroundStyle(Color.dsError)
                .lineLimit(3)
            Spacer()
        }
        .padding(DS.Spacing.md)
        .background(Color.dsErrorTint)
        .cornerRadius(DS.CornerRadius.sm)
    }
}

// MARK: - Success Banner

struct FliqSuccessBanner: View {
    let message: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.dsSuccess)
            Text(message)
                .font(DS.Typography.footnote)
                .foregroundStyle(Color.dsSuccess)
                .lineLimit(3)
            Spacer()
        }
        .padding(DS.Spacing.md)
        .background(Color.dsSuccessTint)
        .cornerRadius(DS.CornerRadius.sm)
    }
}

// MARK: - Primary Button Style

struct DSPrimaryButtonStyle: ButtonStyle {
    var disabled: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DS.Typography.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                RoundedRectangle(cornerRadius: DS.CornerRadius.sm, style: .continuous)
                    .fill(disabled ? Color.dsTertiary : (configuration.isPressed ? Color.dsAccentDark : Color.dsAccent))
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Secondary (Outline) Button Style

struct DSSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DS.Typography.headline)
            .foregroundStyle(configuration.isPressed ? Color.dsAccentDark : Color.dsAccent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                RoundedRectangle(cornerRadius: DS.CornerRadius.sm, style: .continuous)
                    .strokeBorder(configuration.isPressed ? Color.dsAccentDark : Color.dsAccent, lineWidth: 1.5)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Ghost / Text Button Style

struct DSTextButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DS.Typography.footnote)
            .foregroundStyle(configuration.isPressed ? Color.dsAccentDark : Color.dsAccent)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Choice Chip

struct DSChoiceChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(DS.Typography.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundStyle(isSelected ? Color.dsAccent : Color.dsSecondary)
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.sm)
                .background(isSelected ? Color.dsAccentTint : Color.dsBorderLight)
                .cornerRadius(DS.CornerRadius.sm)
                .overlay(
                    RoundedRectangle(cornerRadius: DS.CornerRadius.sm)
                        .strokeBorder(isSelected ? Color.dsAccent.opacity(0.5) : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
