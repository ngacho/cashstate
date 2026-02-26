import Foundation
import PostHog
import UIKit

// MARK: - App Delegate for PostHog

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_: UIApplication, didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        Analytics.shared.configure()
        return true
    }
}

// MARK: - Typed Events

enum AnalyticsEvent: String {
    // Auth
    case userRegistered = "user_registered"
    case userLoggedIn = "user_logged_in"
    case userLoggedOut = "user_logged_out"

    // Navigation
    case screenViewed = "screen_viewed"
    case tabSwitched = "tab_switched"

    // Banks
    case simplefinSetupStarted = "simplefin_setup_started"
    case simplefinConnected = "simplefin_connected"
    case accountsSynced = "accounts_synced"

    // Budget
    case budgetMonthNavigated = "budget_month_navigated"
    case spendingCompareViewed = "spending_compare_viewed"
    case categoryDrillDown = "category_drill_down"
    case aiCategorizationStarted = "ai_categorization_started"
    case aiCategorizationCompleted = "ai_categorization_completed"
    case transactionCategorized = "transaction_categorized"

    // Goals
    case goalCreated = "goal_created"
    case goalEdited = "goal_edited"
    case goalDeleted = "goal_deleted"
    case goalDetailViewed = "goal_detail_viewed"

    // Home
    case accountDetailViewed = "account_detail_viewed"
    case timeRangeChanged = "time_range_changed"
}

// MARK: - Typed Screens

enum AnalyticsScreen: String {
    case home = "Home"
    case budget = "Budget"
    case goals = "Goals"
    case accounts = "Accounts"
    case goalDetail = "Goal Detail"
    case createGoal = "Create Goal"
    case editGoal = "Edit Goal"
    case accountDetail = "Account Detail"
    case transactionDetail = "Transaction Detail"
    case categoryTransactions = "Category Transactions"
    case simplefinSetup = "SimpleFin Setup"
    case login = "Login"
    case spendingCompare = "Spending Compare"
}

// MARK: - Analytics Singleton

final class Analytics {
    static let shared = Analytics()
    private init() {}

    func configure() {
        let config = PostHogConfig(
            apiKey: Config.posthogAPIKey,
            host: Config.posthogHost
        )
        config.captureScreenViews = false
        config.captureApplicationLifecycleEvents = true
        config.sessionReplay = true
        config.sessionReplayConfig.maskAllTextInputs = true
        config.sessionReplayConfig.maskAllImages = true
        config.sessionReplayConfig.screenshotMode = true
        PostHogSDK.shared.setup(config)
    }

    func track(_ event: AnalyticsEvent, properties: [String: Any]? = nil) {
        PostHogSDK.shared.capture(event.rawValue, properties: properties)
    }

    func screen(_ screen: AnalyticsScreen, properties: [String: Any]? = nil) {
        PostHogSDK.shared.screen(screen.rawValue, properties: properties)
    }

    func identify(userId: String) {
        PostHogSDK.shared.identify(userId)
    }

    func reset() {
        PostHogSDK.shared.reset()
    }
}
