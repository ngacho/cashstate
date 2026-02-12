import SwiftUI

/// Mint-inspired design system
enum Theme {
    enum Colors {
        // Mint's signature teal/turquoise
        static let primary = Color(hex: "00A699")
        static let primaryLight = Color(hex: "3DBDB0")
        static let primaryDark = Color(hex: "008C82")

        // Background colors
        static let background = Color(hex: "F0F5F5")
        static let cardBackground = Color.white

        // Text colors
        static let textPrimary = Color(hex: "2C3E50")
        static let textSecondary = Color(hex: "8A94A6")
        static let textOnPrimary = Color.white

        // Transaction colors
        static let income = Color(hex: "10B981")
        static let expense = Color(hex: "EF4444")

        // Category colors (for future use)
        static let categoryBlue = Color(hex: "60A5FA")
        static let categoryPurple = Color(hex: "A78BFA")
        static let categoryPink = Color(hex: "F472B6")
        static let categoryOrange = Color(hex: "FB923C")
        static let categoryYellow = Color(hex: "FBBF24")
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
        static func card(color: Color = Color.black.opacity(0.08)) -> (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
            (color, 8, 0, 2)
        }

        static func cardHover(color: Color = Color.black.opacity(0.12)) -> (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
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
}
