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
    }
}

#Preview {
    ContentView()
}
