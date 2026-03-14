import ClerkKit
import SwiftUI

enum AppState: Equatable {
    case loading
    case signedOut
    case checkingUser
    case onboarding
    case signedIn
}

struct ContentView: View {
    private let apiClient = APIClient.shared

    @State private var appState: AppState = .loading

    var body: some View {
        Group {
            switch appState {
            case .loading, .checkingUser:
                ZStack {
                    Theme.Colors.background.ignoresSafeArea()
                    VStack(spacing: Theme.Spacing.md) {
                        Image("cashstate-logo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 80, height: 80)
                        ProgressView()
                        Text(appState == .loading ? "Starting up..." : "Loading your data...")
                            .font(.subheadline)
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                }
            case .signedOut:
                LoginView()
            case .onboarding:
                OnboardingView(apiClient: apiClient) {
                    appState = .signedIn
                }
            case .signedIn:
                MainView(apiClient: apiClient)
            }
        }
        .task {
            await waitForClerkAndRoute()
        }
        .onChange(of: Clerk.shared.isLoaded) { _, loaded in
            if loaded {
                Task { await route() }
            }
        }
        .onChange(of: Clerk.shared.session != nil) { _, _ in
            Task { await route() }
        }
    }

    /// Wait for Clerk to finish loading, then route.
    private func waitForClerkAndRoute() async {
        while !Clerk.shared.isLoaded {
            if Task.isCancelled { return }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        await route()
    }

    /// Decide which screen to show based on current Clerk state.
    private func route() async {
        guard Clerk.shared.isLoaded else {
            appState = .loading
            return
        }

        guard Clerk.shared.session != nil else {
            appState = .signedOut
            return
        }

        appState = .checkingUser
        let exists = await checkUserExists()

        if exists {
            let hasSimplefin = await checkHasSimplefinItems()
            if hasSimplefin {
                appState = .signedIn
            } else {
                appState = .onboarding
            }
        } else {
            print("[ContentView] User not found in DB after retries, signing out")
            try? await Clerk.shared.auth.signOut()
            appState = .signedOut
        }
    }

    /// Check if the user exists in Convex.
    private func checkUserExists() async -> Bool {
        guard let clerkId = await Clerk.shared.user?.id else {
            return false
        }

        let convexSiteURL = Config.convexURL
            .replacingOccurrences(of: ".convex.cloud", with: ".convex.site")

        guard let url = URL(string: "\(convexSiteURL)/user-exists?clerkId=\(clerkId)") else {
            return false
        }

        for attempt in 1...5 {
            if Task.isCancelled { return false }

            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let json = try? JSONDecoder().decode(UserExistsResponse.self, from: data), json.exists {
                    return true
                }
            } catch is CancellationError {
                return false
            } catch let error as NSError where error.code == NSURLErrorCancelled {
                return false
            } catch {
                print("[ContentView] User check attempt \(attempt) failed: \(error)")
            }

            if attempt < 5 {
                try? await Task.sleep(nanoseconds: UInt64(attempt) * 1_000_000_000)
            }
        }

        return false
    }

    /// Check if the user has any SimpleFin connections.
    private func checkHasSimplefinItems() async -> Bool {
        do {
            let items = try await apiClient.listSimplefinItems()
            return !items.isEmpty
        } catch {
            print("[ContentView] Failed to check SimpleFin items: \(error)")
            // On error, skip onboarding to avoid blocking the user
            return true
        }
    }
}

private struct UserExistsResponse: Decodable {
    let exists: Bool
}

#Preview {
    ContentView()
}
