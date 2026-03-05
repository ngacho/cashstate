import ClerkKit
import SwiftUI

struct ContentView: View {
    private let apiClient = APIClient.shared

    var body: some View {
        ZStack {
            if Clerk.shared.session != nil {
                MainView(apiClient: apiClient)
            } else {
                LoginView()
            }
        }
    }
}

#Preview {
    ContentView()
}
