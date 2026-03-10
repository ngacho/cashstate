import ClerkKit
import SwiftUI

struct ContentView: View {
    private let apiClient = APIClient.shared

    @State private var isCheckingUser = true
    @State private var userExists = false

    var body: some View {
        Group {
            if Clerk.shared.session != nil {
                if isCheckingUser {
                    ZStack {
                        Theme.Colors.background.ignoresSafeArea()
                        VStack(spacing: Theme.Spacing.md) {
                            ProgressView()
                            Text("Loading...")
                                .font(.subheadline)
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                    }
                    .task {
                        await checkUserExists()
                    }
                } else if userExists {
                    MainView(apiClient: apiClient)
                } else {
                    LoginView()
                }
            } else {
                LoginView()
            }
        }
        .onChange(of: Clerk.shared.session != nil) { _, hasSession in
            if hasSession {
                isCheckingUser = true
                userExists = false
                Task { await checkUserExists() }
            } else {
                isCheckingUser = true
                userExists = false
            }
        }
    }

    private func checkUserExists() async {
        guard let clerkId = await Clerk.shared.user?.id else {
            isCheckingUser = false
            userExists = false
            return
        }

        let convexSiteURL = Config.convexURL
            .replacingOccurrences(of: ".convex.cloud", with: ".convex.site")

        guard let url = URL(string: "\(convexSiteURL)/user-exists?clerkId=\(clerkId)") else {
            isCheckingUser = false
            userExists = false
            return
        }

        // Retry a few times since the webhook may not have fired yet
        for attempt in 1...5 {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let json = try? JSONDecoder().decode(UserExistsResponse.self, from: data), json.exists {
                    isCheckingUser = false
                    userExists = true
                    return
                }
            } catch {
                print("[ContentView] User check attempt \(attempt) failed: \(error)")
            }

            if attempt < 5 {
                try? await Task.sleep(nanoseconds: UInt64(attempt) * 1_000_000_000)
            }
        }

        // User not found after retries — sign out
        print("[ContentView] User not found in DB after retries, signing out")
        try? await Clerk.shared.session?.revoke()
        isCheckingUser = false
        userExists = false
    }
}

private struct UserExistsResponse: Decodable {
    let exists: Bool
}

#Preview {
    ContentView()
}
