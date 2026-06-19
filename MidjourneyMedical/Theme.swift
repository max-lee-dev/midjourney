import SwiftUI

/// Centralized design tokens — pure black canvas, gold HUD accents, sharp geometry.
enum Theme {
    static let accent = Color(red: 1.0, green: 0.718, blue: 0.0)           // #FFB800
    static let accentDeep = Color(red: 0.75, green: 0.45, blue: 0.0)

    static let background = Color.black
    static let surface = Color.clear
    static let surfaceElevated = Color.white.opacity(0.03)
    static let stroke = accent.opacity(0.38)

    static let textPrimary = Color(white: 0.92)
    static let textSecondary = Color(white: 0.55)
    static let textTertiary = Color(red: 0.42, green: 0.26, blue: 0.10)

    static let cornerRadius: CGFloat = 0
    static let cornerRadiusSmall: CGFloat = 0

    // Deviation / status scale
    static let normal = Color(red: 0.62, green: 0.82, blue: 0.32)
    static let watch = Color(red: 1.0, green: 0.718, blue: 0.0)
    static let alert = Color(red: 0.85, green: 0.28, blue: 0.22)

    static func color(for status: HealthStatus) -> Color {
        switch status {
        case .normal: return normal
        case .watch: return watch
        case .alert: return alert
        }
    }

    static var screenGradient: LinearGradient {
        LinearGradient(colors: [background, background], startPoint: .top, endPoint: .bottom)
    }

    /// "A shallow pool of golden light." Warm gold welling up from below into black —
    /// the backdrop for the scan ritual (descending into the water).
    static var goldenPoolGradient: RadialGradient {
        RadialGradient(
            colors: [
                accent.opacity(0.28),
                accentDeep.opacity(0.12),
                background
            ],
            center: .init(x: 0.5, y: 0.82),
            startRadius: 0,
            endRadius: 560
        )
    }

    // MARK: - Typography

    static func hudEyebrow(size: CGFloat = 11) -> Font {
        .system(size: size, weight: .bold, design: .default)
    }

    static func hudTitle(size: CGFloat = 28) -> Font {
        .system(size: size, weight: .bold, design: .default)
    }

    static func hudData(size: CGFloat = 34) -> Font {
        .system(size: size, weight: .heavy, design: .monospaced)
    }

    static func hudLabel(size: CGFloat = 11) -> Font {
        .system(size: size, weight: .semibold, design: .default)
    }

    static func hudCaption(size: CGFloat = 9) -> Font {
        .system(size: size, weight: .bold, design: .default)
    }
}

/// Sharp bordered panel used across the app.
struct CardModifier: ViewModifier {
    var padding: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Theme.surfaceElevated, in: Rectangle())
            .overlay(Rectangle().strokeBorder(Theme.stroke, lineWidth: 1))
    }
}

/// Gold HUD countdown panel — thin border, flat progress rail.
struct HUDPanel<Content: View>: View {
    var progress: CGFloat? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            content()
                .padding(14)

            if let progress {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Theme.accent.opacity(0.12))
                        Rectangle()
                            .fill(Theme.accent)
                            .frame(width: geo.size.width * min(max(progress, 0), 1))
                    }
                }
                .frame(height: 3)
            }
        }
        .overlay(Rectangle().strokeBorder(Theme.stroke, lineWidth: 1))
    }
}

extension View {
    func card(padding: CGFloat = 16) -> some View {
        modifier(CardModifier(padding: padding))
    }

    func screenBackground() -> some View {
        background(Theme.screenGradient.ignoresSafeArea())
    }

    func hudEyebrowStyle() -> some View {
        font(Theme.hudEyebrow())
            .tracking(1.6)
            .textCase(.uppercase)
    }

    func hudLabelStyle() -> some View {
        font(Theme.hudLabel())
            .tracking(1.2)
            .textCase(.uppercase)
    }

    func hudCaptionStyle() -> some View {
        font(Theme.hudCaption())
            .tracking(0.8)
            .textCase(.uppercase)
    }
}
