import SwiftUI

enum Theme {
    enum Palette {
        static let primary = Color(red: 0x1F / 255, green: 0x2D / 255, blue: 0x7A / 255)
        static let background = Color(red: 0xF7 / 255, green: 0xF8 / 255, blue: 0xFB / 255)
        static let cardSurface = Color.white
        static let heroAccent = Color(red: 0xE8 / 255, green: 0xED / 255, blue: 0xFB / 255)
        static let success = Color(red: 0x5D / 255, green: 0xB0 / 255, blue: 0x75 / 255)
        static let attention = Color(red: 0xF5 / 255, green: 0xC8 / 255, blue: 0x42 / 255)
        static let negative = Color(red: 0xE2 / 255, green: 0x7B / 255, blue: 0x7B / 255)
        static let pastelYellow = Color(red: 0xFC / 255, green: 0xE8 / 255, blue: 0xB2 / 255)
        static let pastelPink = Color(red: 0xF8 / 255, green: 0xC8 / 255, blue: 0xD6 / 255)
        static let pastelPeach = Color(red: 0xFB / 255, green: 0xD3 / 255, blue: 0xB5 / 255)
        static let pastelSky = Color(red: 0xC8 / 255, green: 0xDD / 255, blue: 0xF6 / 255)
        static let textPrimary = Color(.label)
        static let textSecondary = Color(.secondaryLabel)
        static let divider = Color(red: 0xE5 / 255, green: 0xE7 / 255, blue: 0xEB / 255)
    }

    enum Radius {
        static let card: CGFloat = 16
        static let button: CGFloat = 12
    }

    enum Font {
        static let hero: SwiftUI.Font = .system(size: 30, weight: .bold, design: .default)
        static let heroLabel: SwiftUI.Font = .system(size: 14, weight: .medium)
        static let sectionTitle: SwiftUI.Font = .system(size: 20, weight: .semibold)
        static let body: SwiftUI.Font = .system(size: 16, weight: .regular)
        static let bodyEmphasis: SwiftUI.Font = .system(size: 16, weight: .semibold)
        static let caption: SwiftUI.Font = .system(size: 13, weight: .medium)
    }

    static let cardShadow = ShadowStyle(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)

    struct ShadowStyle {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }
}

extension View {
    func cardStyle(padding: CGFloat = 20, background: Color = Theme.Palette.cardSurface) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
            .shadow(
                color: Theme.cardShadow.color,
                radius: Theme.cardShadow.radius,
                x: Theme.cardShadow.x,
                y: Theme.cardShadow.y
            )
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var fullWidth: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Font.bodyEmphasis)
            .foregroundStyle(Color.white)
            .padding(.vertical, 14)
            .padding(.horizontal, 24)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .background(
                Theme.Palette.primary.opacity(configuration.isPressed ? 0.85 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous))
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Font.bodyEmphasis)
            .foregroundStyle(Theme.Palette.textPrimary)
            .padding(.vertical, 12)
            .padding(.horizontal, 20)
            .background(Color.white)
            .overlay(
                Capsule().stroke(Theme.Palette.divider, lineWidth: 1)
            )
            .clipShape(Capsule())
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

extension MedCategory {
    var pastelColor: Color {
        switch self {
        case .adhd: return Theme.Palette.pastelPeach
        case .depression: return Theme.Palette.pastelYellow
        case .anxiety: return Theme.Palette.heroAccent
        case .sleep: return Theme.Palette.pastelSky
        case .birthControl, .hormonal: return Theme.Palette.pastelPink
        case .thyroid: return Theme.Palette.pastelYellow
        case .glp1: return Theme.Palette.pastelPeach
        case .other: return Theme.Palette.divider
        }
    }

    var iconSystemName: String {
        switch self {
        case .adhd: return "bolt.fill"
        case .depression: return "sun.max.fill"
        case .anxiety: return "wind"
        case .sleep: return "moon.fill"
        case .birthControl: return "pill.fill"
        case .hormonal: return "leaf.fill"
        case .thyroid: return "flame.fill"
        case .glp1: return "drop.fill"
        case .other: return "capsule.fill"
        }
    }
}
