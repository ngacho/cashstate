import SwiftUI

struct ContentView: View {
    @State private var isAuthenticated = false
    private let apiClient = APIClient()

    var body: some View {
        Group {
            if isAuthenticated {
                MainView(isAuthenticated: $isAuthenticated, apiClient: apiClient)
            } else {
                LoginView(isAuthenticated: $isAuthenticated, apiClient: apiClient)
            }
        }
        .task {
            // DEV ONLY: Auto-login if we have a stored token
            await checkStoredAuth()
        }
    }

    func checkStoredAuth() async {
        if await apiClient.hasStoredToken() {
            await apiClient.loadStoredToken()
            isAuthenticated = true
            print("✅ DEV: Auto-logged in with stored token")
        }
    }
}

#Preview {
    ContentView()
}
