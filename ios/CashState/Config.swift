import Foundation

enum Config {
    // MARK: - Convex

    #if DEBUG
    static let convexURL = "https://flexible-bison-651.convex.cloud"
    #else
    static let convexURL = "https://grandiose-ram-851.convex.cloud"
    #endif

    // MARK: - PostHog

    static let posthogAPIKey = "phc_Nd1mVhgoAgBogCRgMQ6uU1KjywjKvaWOSX9F4lJVM5y"
    static let posthogHost = "https://us.i.posthog.com"

    // MARK: - Clerk

    #if DEBUG
    static let clerkPublishableKey = "pk_test_Zmx5aW5nLXJhY2Nvb24tNzIuY2xlcmsuYWNjb3VudHMuZGV2JA"
    #else
    static let clerkPublishableKey = "pk_live_Y2xlcmsuY2FzaHN0YXRlLmFwcCQ"
    #endif

    // MARK: - Web

    static let webBaseURL = "https://cashstate.app"
    static let feedbackURL = "\(webBaseURL)/feedback?source=ios"

    // MARK: - App

    #if DEBUG
    static let debugMode = true
    #else
    static let debugMode = false
    #endif
    static let requestTimeout: TimeInterval = 30
}
