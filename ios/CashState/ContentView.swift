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
        .onAppear {
            print("🔐 [ContentView] session: \(String(describing: Clerk.shared.session))")
            print("🔐 [ContentView] user: \(String(describing: Clerk.shared.user))")
            print("🔐 [ContentView] client: \(String(describing: Clerk.shared.client))")
        }
    }
}

#Preview {
    ContentView()
}
