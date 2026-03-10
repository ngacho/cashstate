import Foundation

/// App configuration - UPDATE THESE VALUES
enum Config {
    // MARK: - Convex

    /// Your Convex deployment URL
    /// Find it at: https://dashboard.convex.dev → your project → Settings
    /// Example: "https://your-deployment.convex.cloud"
    // TODO: Replace with production Convex deployment URL
    static let convexURL = "https://grandiose-ram-851.convex.cloud"

    // MARK: - PostHog

    static let posthogAPIKey = "phc_Nd1mVhgoAgBogCRgMQ6uU1KjywjKvaWOSX9F4lJVM5y"
    static let posthogHost = "https://us.i.posthog.com"

    // MARK: - Clerk

    /// Your Clerk Publishable Key
    /// Find it at: https://dashboard.clerk.com → Production → API Keys
    // TODO: Replace with production Clerk publishable key (pk_live_...)
    static let clerkPublishableKey = "pk_live_Y2xlcmsuY2FzaHN0YXRlLmFwcCQ"

    // MARK: - App

    static let debugMode = false
    static let requestTimeout: TimeInterval = 30
}
