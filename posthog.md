Integrate PostHog with iOS
Read the docs
1. Install the SDK
required

Add PostHog to your Podfile:

pod "PostHog", "~> 3.0"

Or install via Swift Package Manager:

dependencies: [
  .package(url: "https://github.com/PostHog/posthog-ios.git", from: "3.0.0")
]

SDK version

Session replay requires PostHog iOS SDK version 3.6.0 or higher. We recommend always using the latest version.
2. Enable session recordings in project settings
required

Go to your PostHog Project Settings and enable Record user sessions. Session recordings will not work without this setting enabled.
3. Configure PostHog with session replay
required

Add sessionReplay = true to your PostHog configuration. Here are all the available options:


```
import Foundation
import PostHog
import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_: UIApplication, didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        let POSTHOG_TOKEN = "phc_Nd1mVhgoAgBogCRgMQ6uU1KjywjKvaWOSX9F4lJVM5y"
        let POSTHOG_HOST = "https://us.i.posthog.com"

        let config = PostHogConfig(apiKey: POSTHOG_TOKEN, host: POSTHOG_HOST)

        // Enable session recording. Requires enabling in your project settings as well.
        // Default is false.
        config.sessionReplay = true

        // Whether text and text input fields are masked. Default is true.
        // Password inputs are always masked regardless
        config.sessionReplayConfig.maskAllTextInputs = true

        // Whether images are masked. Default is true.
        config.sessionReplayConfig.maskAllImages = true

        // Whether logs are captured in recordings. Default is false.
        //
        // Support for remote configuration 
        // in the [session replay settings](https://app.posthog.com/settings/project-replay#replay-log-capture)
        // requires SDK version 3.41.1 or higher.
        config.sessionReplayConfig.captureLogs = false

        // Whether network requests are captured in recordings. Default is true
        // Only metric-like data like speed, size, and response code are captured.
        // No data is captured from the request or response body.
        //
        // Support for remote configuration 
        // in the [session replay settings](https://app.posthog.com/settings/project-replay#replay-network)
        // requires SDK version 3.41.1 or higher.
        config.sessionReplayConfig.captureNetworkTelemetry = true

        // Whether replays are created using high quality screenshots. Default is false.
        // Required for SwiftUI.
        // If disabled, replays are created using wireframes instead.
        // The screenshot may contain sensitive information, so use with caution
        config.sessionReplayConfig.screenshotMode = true

        PostHogSDK.shared.setup(config)

        return true
    }
}

```