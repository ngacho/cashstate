import SwiftUI
import UIKit

/// Mint-inspired design system with light/dark mode support
enum Theme {
    enum Colors {
        // Mint's signature teal/turquoise
        static let primary = Color(hex: "00A699")
        static let primaryLight = Color(hex: "3DBDB0")
        static let primaryDark = Color(hex: "008C82")

        // Background colors - adaptive
        static let background = Color(light: Color(hex: "F0F5F5"), dark: Color(hex: "1C1C1E"))
        static let cardBackground = Color(light: .white, dark: Color(hex: "2C2C2E"))

        // Text colors - adaptive
        static let textPrimary = Color(light: Color(hex: "2C3E50"), dark: Color(hex: "F2F2F7"))
        static let textSecondary = Color(light: Color(hex: "8A94A6"), dark: Color(hex: "8E8E93"))
        static let textOnPrimary = Color.white

        // Transaction colors
        static let income = Color(hex: "10B981")
        static let expense = Color(hex: "EF4444")

        // Category colors
        static let categoryBlue = Color(hex: "60A5FA")
        static let categoryPurple = Color(hex: "A78BFA")
        static let categoryPink = Color(hex: "F472B6")
        static let categoryOrange = Color(hex: "FB923C")
        static let categoryYellow = Color(hex: "FBBF24")

        // Borders / dividers - adaptive
        static let border = Color(light: Color.gray.opacity(0.2), dark: Color.gray.opacity(0.4))
        static let divider = Color(light: Color.gray.opacity(0.15), dark: Color.gray.opacity(0.3))

        // Shadow - adaptive (shadows are subtler in dark mode)
        static let shadowColor = Color(light: Color.black.opacity(0.08), dark: Color.black.opacity(0.3))
    }

    enum Spacing {
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
    }

    enum CornerRadius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
    }

    enum Shadow {
        static func card(color: Color = Colors.shadowColor) -> (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
            (color, 8, 0, 2)
        }

        static func cardHover(color: Color = Colors.shadowColor) -> (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
            (color, 12, 0, 4)
        }
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    /// Creates an adaptive color that switches between light and dark variants
    init(light: Color, dark: Color) {
        self.init(uiColor: UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(dark)
                : UIColor(light)
        })
    }
}
