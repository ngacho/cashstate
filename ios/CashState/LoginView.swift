import SwiftUI

struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showError = false
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
                    TextField("Email", text: $email)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)

                    SecureField("Password", text: $password)
                        .textFieldStyle(.roundedBorder)

                    Button(action: login) {
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Sign In")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Theme.Colors.primary)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .disabled(isLoading)
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

    func login() {
        isLoading = true

        Task {
            do {
                struct LoginRequest: Encodable {
                    let email: String
                    let password: String
                }

                let response: AuthResponse = try await apiClient.request(
                    endpoint: "/auth/login",
                    method: "POST",
                    body: LoginRequest(email: email, password: password)
                )

                await apiClient.setAccessToken(response.accessToken)
                isAuthenticated = true
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }

            isLoading = false
        }
    }
}
