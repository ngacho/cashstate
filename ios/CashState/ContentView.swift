import SwiftUI

struct ContentView: View {
    @State private var isAuthenticated = false
    private let apiClient = APIClient.shared

    var body: some View {
        Group {
            if isAuthenticated {
                MainView(isAuthenticated: $isAuthenticated, apiClient: apiClient)
            } else {
                LoginView(isAuthenticated: $isAuthenticated, apiClient: apiClient)
            }
        }
        .task {
            await checkStoredAuth()
        }
    }

    func checkStoredAuth() async {
        let hasSession = await apiClient.loadStoredSession()
        if hasSession {
            isAuthenticated = true
            if let userId = UserDefaults.standard.string(forKey: "dev_user_id") {
                Analytics.shared.identify(userId: userId)
            }
            print("Auto-logged in with stored userId")
        }
    }
}

#Preview {
    ContentView()
}
