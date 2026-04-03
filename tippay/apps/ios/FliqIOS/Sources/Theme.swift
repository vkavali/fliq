import SwiftUI

extension Color {
    static let fliqBlue = Color(red: 34 / 255, green: 103 / 255, blue: 242 / 255)
    static let fliqMint = Color(red: 21 / 255, green: 149 / 255, blue: 112 / 255)
    static let fliqGold = Color(red: 240 / 255, green: 138 / 255, blue: 36 / 255)
    static let fliqInk = Color(red: 16 / 255, green: 24 / 255, blue: 40 / 255)
    static let fliqMuted = Color(red: 76 / 255, green: 87 / 255, blue: 108 / 255)
    static let fliqSky = Color(red: 245 / 255, green: 248 / 255, blue: 255 / 255)
}

struct FliqPrimaryButtonStyle: ButtonStyle {
    let accent: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(accent.opacity(configuration.isPressed ? 0.82 : 1.0))
            )
            .scaleEffect(configuration.isPressed ? 0.99 : 1.0)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}
