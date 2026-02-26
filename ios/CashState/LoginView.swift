import SwiftUI

struct LoginView: View {
    @State private var username = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showError = false
    @State private var isRegistering = false
    @Binding var isAuthenticated: Bool

    let apiClient: APIClient

    var body: some View {
        ZStack {
            Theme.Colors.background.ignoresSafeArea()

            VStack(spacing: Theme.Spacing.lg) {
                Spacer()

                // Logo
                Image(systemName: "dollarsign.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(Theme.Colors.primary)

                Text("CashState")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(Theme.Colors.textPrimary)

                Text("Track your spending")
                    .foregroundColor(Theme.Colors.textSecondary)

                Spacer()

                // Form
                VStack(spacing: Theme.Spacing.md) {
                    TextField("Username", text: $username)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    SecureField("Password", text: $password)
                        .textFieldStyle(.roundedBorder)

                    Button(action: submit) {
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text(isRegistering ? "Create Account" : "Sign In")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Theme.Colors.primary)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .disabled(isLoading || username.isEmpty || password.isEmpty)

                    Button(action: { isRegistering.toggle() }) {
                        Text(isRegistering ? "Already have an account? Sign In" : "New here? Create Account")
                            .font(.subheadline)
                            .foregroundColor(Theme.Colors.primary)
                    }
                }
                .padding(.horizontal, Theme.Spacing.lg)

                Spacer()
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }

    func submit() {
        isLoading = true

        Task {
            do {
                if isRegistering {
                    let response = try await apiClient.register(username: username, password: password)
                    Analytics.shared.identify(userId: response.userId)
                    Analytics.shared.track(.userRegistered)
                } else {
                    let response = try await apiClient.login(username: username, password: password)
                    Analytics.shared.identify(userId: response.userId)
                    Analytics.shared.track(.userLoggedIn)
                }
                isAuthenticated = true
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }

            isLoading = false
        }
    }
}
