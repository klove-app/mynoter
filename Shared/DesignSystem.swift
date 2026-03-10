import SwiftUI

// MARK: - Spacing

enum DS {
    enum Spacing {
        static let xs:  CGFloat = 4
        static let sm:  CGFloat = 8
        static let md:  CGFloat = 12
        static let lg:  CGFloat = 16
        static let xl:  CGFloat = 24
        static let xxl: CGFloat = 32
    }

    enum Radius {
        static let small:  CGFloat = 6
        static let medium: CGFloat = 10
        static let large:  CGFloat = 14
        static let xl:     CGFloat = 20
    }
}

// MARK: - Colors

extension Color {
    enum ds {
        static let surfacePrimary   = Color("dsSurfacePrimary",   bundle: nil)
        static let surfaceSecondary = Color("dsSurfaceSecondary", bundle: nil)

        static var accentSubtle: Color { Color.accentColor.opacity(0.08) }
        static var accentMedium: Color { Color.accentColor.opacity(0.15) }
        static var accentWash:   Color { Color.accentColor.opacity(0.03) }

        static var rowHover: Color { Color.primary.opacity(0.04) }
        static var rowSelected: Color { Color.accentColor.opacity(0.10) }

        static var separator: Color {
            #if os(macOS)
            Color(nsColor: .separatorColor)
            #else
            Color(uiColor: .separator)
            #endif
        }

        static var elevatedBackground: Color {
            #if os(macOS)
            Color(nsColor: .controlBackgroundColor)
            #else
            Color(uiColor: .secondarySystemBackground)
            #endif
        }
    }
}

// MARK: - Shadows

struct DSShadow: ViewModifier {
    enum Level { case subtle, medium, elevated }
    let level: Level

    func body(content: Content) -> some View {
        switch level {
        case .subtle:
            content.shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        case .medium:
            content.shadow(color: .black.opacity(0.07), radius: 8, x: 0, y: 3)
        case .elevated:
            content.shadow(color: .black.opacity(0.10), radius: 16, x: 0, y: 6)
        }
    }
}

extension View {
    func dsShadow(_ level: DSShadow.Level = .subtle) -> some View {
        modifier(DSShadow(level: level))
    }
}

// MARK: - Typography

extension Font {
    enum ds {
        static let titleLarge  = Font.system(size: 26, weight: .bold, design: .default)
        static let titleMedium = Font.system(size: 20, weight: .semibold, design: .default)
        static let titleSmall  = Font.system(size: 17, weight: .semibold, design: .default)

        static let bodyLarge = Font.system(size: 16, weight: .regular, design: .default)
        static let body      = Font.system(size: 15, weight: .regular, design: .default)
        static let bodySmall = Font.system(size: 13, weight: .regular, design: .default)

        static let caption     = Font.system(size: 12, weight: .regular, design: .default)
        static let captionMono = Font.system(size: 11, weight: .regular, design: .monospaced)
    }
}

// MARK: - Button Styles

struct DSToolbarButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.90 : 1.0)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(.spring(duration: 0.2), value: configuration.isPressed)
    }
}

struct DSPressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(duration: 0.25, bounce: 0.3), value: configuration.isPressed)
    }
}

// MARK: - Transitions

extension AnyTransition {
    static var dsSlideIn: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .opacity
        )
    }

    static var dsFade: AnyTransition {
        .opacity.animation(.easeInOut(duration: 0.2))
    }

    static var dsScale: AnyTransition {
        .scale(scale: 0.95).combined(with: .opacity)
    }
}

// MARK: - View Extensions

extension View {
    func dsCardStyle(isSelected: Bool = false, cornerRadius: CGFloat = DS.Radius.medium) -> some View {
        self
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(isSelected ? Color.ds.rowSelected : Color.clear)
            )
    }

    @ViewBuilder
    func dsAccentBar(visible: Bool, edge: Edge = .leading) -> some View {
        self.overlay(alignment: edge == .leading ? .leading : .trailing) {
            if visible {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.accentColor)
                    .frame(width: 3)
                    .padding(.vertical, 4)
                    .transition(.opacity.combined(with: .scale(scale: 0.8, anchor: edge == .leading ? .leading : .trailing)))
            }
        }
    }
}
