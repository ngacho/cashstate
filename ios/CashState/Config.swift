import Foundation

/// App configuration - UPDATE THESE VALUES
enum Config {
    // MARK: - Convex

    /// Your Convex deployment URL
    /// Find it at: https://dashboard.convex.dev → your project → Settings
    /// Example: "https://your-deployment.convex.cloud"
    static let convexURL = "https://flexible-bison-651.convex.cloud"

    // MARK: - PostHog

    static let posthogAPIKey = "phc_Nd1mVhgoAgBogCRgMQ6uU1KjywjKvaWOSX9F4lJVM5y"
    static let posthogHost = "https://us.i.posthog.com"

    // MARK: - App

    static let debugMode = true
    static let requestTimeout: TimeInterval = 30
}
