import SwiftUI

enum Theme {

    /// Semantic design tokens per BRAND_UX_SPEC.md §2 (v1.0).
    ///
    /// Tokens are named by ROLE, not by color. Every raw hex in the app lives
    /// in this file; views never define colors. Each token carries its light
    /// and dark value — the interface is light by default (the dark navy
    /// field belongs to marketing), and dark mode is the separately defined
    /// theme from the spec, not an inversion.
    enum Palette {

        // MARK: Surfaces
        static let surface        = dyn(0xF8F9FA, 0x0F1A3E)   // screen background
        static let surfaceRaised  = dyn(0xFFFFFF, 0x17234B)   // cards, sheets, rows
        static let surfaceSunken  = dyn(0xF1F3F7, 0x0B1330)   // unselected fills, inset wells

        // MARK: Text
        static let textPrimary    = dyn(0x0F1A3E, 0xF8F9FA)   // 16.1:1 both themes
        static let textSecondary  = dyn(0x5A6478, 0x98A2B8)   // 5.65:1 / 6.62:1
        static let textTertiary   = dyn(0x626D82, 0x7A86A0)   // 4.94:1 / 4.64:1 — sparingly
        static let textDisabled   = dyn(0x98A2B8, 0x5A6478)   // placeholder/disabled only

        // MARK: Accent & actions
        // Cool on light (Iris Deep), warm on dark (Signal Orange) — spec §1.3.
        static let accent          = dyn(0x2F5FB8, 0xFE9F5E)  // links, selection, interactive
        static let onAccent        = dyn(0xFFFFFF, 0x0F1A3E)
        static let actionPrimary   = dyn(0x0F1A3E, 0xFE9F5E)  // primary button fill
        static let onActionPrimary = dyn(0xF8F9FA, 0x0F1A3E)

        // MARK: Separation
        static let separator = dyn(0xE4E7EC, 0x25315C)        // decorative hairlines only

        // MARK: Data / charts (spec §6)
        static let data1       = dyn(0x548CE8, 0x548CE8)      // primary series, solid
        static let data2       = dyn(0x5588DC, 0x82ADFB)      // comparison series, DASHED
        static let dataMarker  = dyn(0x0F1A3E, 0xF8F9FA)      // dose-change rules, axis emphasis
        static let dataCurrent = dyn(0xFE9F5E, 0xFE9F5E)      // current point ONLY; needs
                                                              // a dataMarker ring on light

        // MARK: System states (the only green and red in the app)
        static let success = dyn(0x0F7B4F, 0x4ADE9B)
        static let error   = dyn(0xA32E2E, 0xFF8A8A)

        // MARK: Brand tints
        // The identity allows exactly two tint fills (PDF §01): Peach and
        // Lavender. Always Deep Navy type on top. Dark values are the same
        // hues taken down to sit on Navy Rise (decision noted in the brand
        // report — the spec does not define dark-mode tints).
        static let peachTint    = dyn(0xFDE8DA, 0x3E2C1D)
        static let lavenderTint = dyn(0xDCE4FB, 0x232C55)
        /// Informational callout card fill — flat Lavender, never a gradient
        /// (spec §9).
        static let callout = lavenderTint

        // MARK: -
        private static func dyn(_ light: UInt32, _ dark: UInt32) -> Color {
            Color(UIColor { trait in
                trait.userInterfaceStyle == .dark ? UIColor(rgb: dark) : UIColor(rgb: light)
            })
        }
    }

    enum Radius {
        static let card: CGFloat = 20      // spec §4: 20–28pt
        static let button: CGFloat = 12
    }

    enum Font {
        // Platform system face only (spec §3 — Poppins is marketing, never
        // the product). Semantic text styles so Dynamic Type works.
        static let hero: SwiftUI.Font         = .system(.largeTitle,   weight: .bold)
        static let heroLabel: SwiftUI.Font    = .system(.subheadline,  weight: .semibold)
        static let sectionTitle: SwiftUI.Font = .system(.title3,       weight: .semibold)
        static let body: SwiftUI.Font         = .system(.callout,      weight: .regular)
        static let bodyEmphasis: SwiftUI.Font = .system(.callout,      weight: .semibold)
        static let caption: SwiftUI.Font      = .system(.footnote,     weight: .medium)
    }

    static let cardShadow = ShadowStyle(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)

    struct ShadowStyle {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }
}

private extension UIColor {
    convenience init(rgb: UInt32) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}

extension View {
    func cardStyle(padding: CGFloat = 20, background: Color = Theme.Palette.surfaceRaised) -> some View {
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

extension Text {
    /// Tabular figures for every score, dose, date, percentage and streak
    /// (spec §3): values must not shift horizontally as digits change.
    func numeric() -> Text { monospacedDigit() }
}

struct PrimaryButtonStyle: ButtonStyle {
    var fullWidth: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Font.bodyEmphasis)
            .foregroundStyle(Theme.Palette.onActionPrimary)
            .padding(.vertical, 14)
            .padding(.horizontal, 24)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .background(
                Theme.Palette.actionPrimary.opacity(configuration.isPressed ? 0.85 : 1)
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
            .background(Theme.Palette.surfaceRaised)
            .overlay(
                Capsule().stroke(Theme.Palette.separator, lineWidth: 1)
            )
            .clipShape(Capsule())
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

extension UserMedication {
    /// Per-medication fill for schedule rows and timeline pills. The brand
    /// allows exactly two tints, so meds alternate between them.
    var scheduleColor: Color {
        let hash = id.uuidString.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
        return hash % 2 == 0 ? Theme.Palette.peachTint : Theme.Palette.lavenderTint
    }
}

extension MedCategory {
    /// Category icon-badge fill: warm tint for energy/body categories, cool
    /// for mind/rest, neutral for uncategorized. Deep Navy glyphs on top.
    var pastelColor: Color {
        switch self {
        case .adhd, .glp1, .pain, .thyroid:
            return Theme.Palette.peachTint
        case .depression, .anxiety, .sleep, .migraine, .moodStabilizer,
             .birthControl, .hormonal:
            return Theme.Palette.lavenderTint
        case .other:
            return Theme.Palette.surfaceSunken
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
        case .moodStabilizer: return "equal.circle.fill"
        case .pain: return "bandage.fill"
        case .migraine: return "brain.head.profile"
        case .other: return "capsule.fill"
        }
    }
}
