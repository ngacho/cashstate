import AuthenticationServices
import ClerkKit
import ClerkKitUI
import ConvexMobile
import SwiftUI

// MARK: - Auth Mode

enum AuthMode {
    case createAccount
    case signIn
    case verifyEmail
    case signInVerify
}

// MARK: - Login View (Auth Router)

struct LoginView: View {
    @State private var authMode: AuthMode = .createAccount

    var body: some View {
        ZStack {
            Theme.Colors.background.ignoresSafeArea()

            switch authMode {
            case .createAccount:
                CreateAccountView(
                    authMode: $authMode
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))
            case .signIn:
                SignInView(
                    authMode: $authMode
                )
                .transition(.move(edge: .leading).combined(with: .opacity))
            case .verifyEmail:
                VerifyEmailView(
                    authMode: $authMode
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))
            case .signInVerify:
                SignInVerifyView(
                    authMode: $authMode
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authMode)
        .onAppear {
            Analytics.shared.screen(.login)
        }
    }
}

// MARK: - Create Account View

struct CreateAccountView: View {
    @Binding var authMode: AuthMode
    @State private var authViewIsPresented = false

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showError = false

    @FocusState private var focusedField: CreateAccountField?

    enum CreateAccountField {
        case firstName, lastName, email, password
    }

    private var isFormValid: Bool {
        !firstName.trimmingCharacters(in: .whitespaces).isEmpty
            && !lastName.trimmingCharacters(in: .whitespaces).isEmpty
            && !email.trimmingCharacters(in: .whitespaces).isEmpty
            && !password.isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                Spacer()
                    .frame(height: 40)

                // Header
                VStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.system(size: 64))
                        .foregroundColor(Theme.Colors.primary)

                    Text("Create Account")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Theme.Colors.textPrimary)

                    Text("Start tracking your finances")
                        .font(.subheadline)
                        .foregroundColor(Theme.Colors.textSecondary)
                }

                // Social Sign In Buttons
                VStack(spacing: Theme.Spacing.sm) {
                    SocialSignInButton(provider: .google) {
                        authViewIsPresented = true
                    }

                    SocialSignInButton(provider: .apple) {
                        authViewIsPresented = true
                    }
                }
                .padding(.horizontal, Theme.Spacing.lg)

                // Divider
                HStack {
                    Rectangle()
                        .fill(Theme.Colors.textSecondary.opacity(0.3))
                        .frame(height: 1)
                    Text("or")
                        .font(.subheadline)
                        .foregroundColor(Theme.Colors.textSecondary)
                    Rectangle()
                        .fill(Theme.Colors.textSecondary.opacity(0.3))
                        .frame(height: 1)
                }
                .padding(.horizontal, Theme.Spacing.lg)

                // Form Fields
                VStack(spacing: Theme.Spacing.sm) {
                    HStack(spacing: Theme.Spacing.sm) {
                        AuthTextField(
                            placeholder: "First name",
                            text: $firstName,
                            icon: "person",
                            keyboardType: .default,
                            textContentType: .givenName
                        )
                        .focused($focusedField, equals: .firstName)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .lastName }

                        AuthTextField(
                            placeholder: "Last name",
                            text: $lastName,
                            icon: nil,
                            keyboardType: .default,
                            textContentType: .familyName
                        )
                        .focused($focusedField, equals: .lastName)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .email }
                    }

                    AuthTextField(
                        placeholder: "Email",
                        text: $email,
                        icon: "envelope",
                        keyboardType: .emailAddress,
                        textContentType: .emailAddress
                    )
                    .focused($focusedField, equals: .email)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .password }
                    .textInputAutocapitalization(.never)

                    AuthSecureField(
                        placeholder: "Password",
                        text: $password,
                        icon: "lock"
                    )
                    .focused($focusedField, equals: .password)
                    .submitLabel(.go)
                    .onSubmit { if isFormValid { submit() } }
                }
                .padding(.horizontal, Theme.Spacing.lg)

                // Create Account Button
                Button(action: submit) {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Create Account")
                            .font(.system(size: 17, weight: .semibold))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(isFormValid ? Theme.Colors.primary : Theme.Colors.primary.opacity(0.5))
                .foregroundColor(.white)
                .cornerRadius(Theme.CornerRadius.md)
                .disabled(isLoading || !isFormValid)
                .padding(.horizontal, Theme.Spacing.lg)

                // Switch to Sign In
                Button(action: { authMode = .signIn }) {
                    HStack(spacing: 4) {
                        Text("Already have an account?")
                            .foregroundColor(Theme.Colors.textSecondary)
                        Text("Sign In")
                            .fontWeight(.semibold)
                            .foregroundColor(Theme.Colors.primary)
                    }
                    .font(.subheadline)
                }

                Spacer()
                    .frame(height: 20)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .alert("Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $authViewIsPresented) {
            AuthView()
        }
    }

    private func submit() {
        focusedField = nil
        isLoading = true

        Task {
            do {
                print("🔐 [SignUp] Attempting sign up for: \(email)")
                let signUp = try await Clerk.shared.auth.signUp(
                    emailAddress: email,
                    password: password,
                    firstName: firstName,
                    lastName: lastName
                )
                print("🔐 [SignUp] Sign up created, status: \(signUp.status)")
                try await signUp.sendEmailCode()
                print("🔐 [SignUp] Email code sent")
                Analytics.shared.track(.userRegistered)
                authMode = .verifyEmail
            } catch {
                print("🔐 [SignUp] ERROR: \(error)")
                errorMessage = error.localizedDescription
                showError = true
            }
            isLoading = false
        }
    }
}

// MARK: - Sign In View

struct SignInView: View {
    @Binding var authMode: AuthMode
    @State private var authViewIsPresented = false

    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showError = false

    @FocusState private var focusedField: SignInField?

    enum SignInField {
        case email, password
    }

    private var isFormValid: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty && !password.isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                Spacer()
                    .frame(height: 60)

                // Header
                VStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.system(size: 64))
                        .foregroundColor(Theme.Colors.primary)

                    Text("Welcome Back")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Theme.Colors.textPrimary)

                    Text("Sign in to your account")
                        .font(.subheadline)
                        .foregroundColor(Theme.Colors.textSecondary)
                }

                // Social Sign In Buttons
                VStack(spacing: Theme.Spacing.sm) {
                    SocialSignInButton(provider: .google) {
                        authViewIsPresented = true
                    }

                    SocialSignInButton(provider: .apple) {
                        authViewIsPresented = true
                    }
                }
                .padding(.horizontal, Theme.Spacing.lg)

                // Divider
                HStack {
                    Rectangle()
                        .fill(Theme.Colors.textSecondary.opacity(0.3))
                        .frame(height: 1)
                    Text("or")
                        .font(.subheadline)
                        .foregroundColor(Theme.Colors.textSecondary)
                    Rectangle()
                        .fill(Theme.Colors.textSecondary.opacity(0.3))
                        .frame(height: 1)
                }
                .padding(.horizontal, Theme.Spacing.lg)

                // Form Fields
                VStack(spacing: Theme.Spacing.sm) {
                    AuthTextField(
                        placeholder: "Email",
                        text: $email,
                        icon: "envelope",
                        keyboardType: .emailAddress,
                        textContentType: .emailAddress
                    )
                    .focused($focusedField, equals: .email)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .password }
                    .textInputAutocapitalization(.never)

                    AuthSecureField(
                        placeholder: "Password",
                        text: $password,
                        icon: "lock"
                    )
                    .focused($focusedField, equals: .password)
                    .submitLabel(.go)
                    .onSubmit { if isFormValid { submit() } }
                }
                .padding(.horizontal, Theme.Spacing.lg)

                // Sign In Button
                Button(action: submit) {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Sign In")
                            .font(.system(size: 17, weight: .semibold))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(isFormValid ? Theme.Colors.primary : Theme.Colors.primary.opacity(0.5))
                .foregroundColor(.white)
                .cornerRadius(Theme.CornerRadius.md)
                .disabled(isLoading || !isFormValid)
                .padding(.horizontal, Theme.Spacing.lg)

                // Switch to Create Account
                Button(action: { authMode = .createAccount }) {
                    HStack(spacing: 4) {
                        Text("Don't have an account?")
                            .foregroundColor(Theme.Colors.textSecondary)
                        Text("Create Account")
                            .fontWeight(.semibold)
                            .foregroundColor(Theme.Colors.primary)
                    }
                    .font(.subheadline)
                }

                Spacer()
                    .frame(height: 20)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .alert("Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $authViewIsPresented) {
            AuthView()
        }
    }

    private func submit() {
        focusedField = nil
        isLoading = true

        Task {
            do {
                var signIn = try await Clerk.shared.auth.signInWithPassword(
                    identifier: email,
                    password: password
                )

                switch signIn.status {
                case .complete:
                    Analytics.shared.track(.userLoggedIn)
                case .needsSecondFactor, .needsClientTrust:
                    signIn = try await signIn.sendMfaEmailCode()
                    authMode = .signInVerify
                default:
                    errorMessage = "Unexpected sign-in status: \(signIn.status)"
                    showError = true
                }
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isLoading = false
        }
    }
}

// MARK: - Sign In Verify View (Client Trust / MFA)

struct SignInVerifyView: View {
    @Binding var authMode: AuthMode

    @State private var code = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showError = false

    @FocusState private var isCodeFocused: Bool

    private var isCodeValid: Bool {
        code.trimmingCharacters(in: .whitespaces).count == 6
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                Spacer()
                    .frame(height: 60)

                VStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 64))
                        .foregroundColor(Theme.Colors.primary)

                    Text("Verify Your Identity")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Theme.Colors.textPrimary)

                    Text("A verification code has been sent to your email")
                        .font(.subheadline)
                        .foregroundColor(Theme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }

                AuthTextField(
                    placeholder: "Verification code",
                    text: $code,
                    icon: "number",
                    keyboardType: .numberPad,
                    textContentType: .oneTimeCode
                )
                .focused($isCodeFocused)
                .padding(.horizontal, Theme.Spacing.lg)

                Button(action: verify) {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Verify")
                            .font(.system(size: 17, weight: .semibold))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(isCodeValid ? Theme.Colors.primary : Theme.Colors.primary.opacity(0.5))
                .foregroundColor(.white)
                .cornerRadius(Theme.CornerRadius.md)
                .disabled(isLoading || !isCodeValid)
                .padding(.horizontal, Theme.Spacing.lg)

                Button(action: { authMode = .signIn }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back to Sign In")
                    }
                    .font(.subheadline)
                    .foregroundColor(Theme.Colors.textSecondary)
                }

                Spacer()
                    .frame(height: 20)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .alert("Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            isCodeFocused = true
        }
    }

    private func verify() {
        isCodeFocused = false
        isLoading = true

        Task {
            do {
                guard var signIn = Clerk.shared.auth.currentSignIn else {
                    errorMessage = "Sign-in session expired. Please try again."
                    showError = true
                    isLoading = false
                    return
                }

                signIn = try await signIn.verifyMfaCode(code, type: .emailCode)

                if signIn.status == .complete {
                    Analytics.shared.track(.userLoggedIn)
                } else {
                    errorMessage = "Unexpected status: \(signIn.status)"
                    showError = true
                }
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isLoading = false
        }
    }
}

// MARK: - Verify Email View

struct VerifyEmailView: View {
    @Binding var authMode: AuthMode

    @State private var code = ""
    @State private var isLoading = false
    @State private var isResending = false
    @State private var errorMessage = ""
    @State private var showError = false

    @FocusState private var isCodeFocused: Bool

    private var isCodeValid: Bool {
        code.trimmingCharacters(in: .whitespaces).count == 6
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                Spacer()
                    .frame(height: 60)

                // Header
                VStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: "envelope.badge")
                        .font(.system(size: 64))
                        .foregroundColor(Theme.Colors.primary)

                    Text("Check Your Email")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Theme.Colors.textPrimary)

                    Text("Enter the 6-digit code we sent you")
                        .font(.subheadline)
                        .foregroundColor(Theme.Colors.textSecondary)
                }

                // Code Field
                AuthTextField(
                    placeholder: "Verification code",
                    text: $code,
                    icon: "number",
                    keyboardType: .numberPad,
                    textContentType: .oneTimeCode
                )
                .focused($isCodeFocused)
                .padding(.horizontal, Theme.Spacing.lg)

                // Verify Button
                Button(action: verify) {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Verify Email")
                            .font(.system(size: 17, weight: .semibold))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(isCodeValid ? Theme.Colors.primary : Theme.Colors.primary.opacity(0.5))
                .foregroundColor(.white)
                .cornerRadius(Theme.CornerRadius.md)
                .disabled(isLoading || !isCodeValid)
                .padding(.horizontal, Theme.Spacing.lg)

                // Resend Code
                Button(action: resendCode) {
                    if isResending {
                        ProgressView()
                            .tint(Theme.Colors.primary)
                    } else {
                        Text("Resend code")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(Theme.Colors.primary)
                    }
                }
                .disabled(isResending)

                // Back to Create Account
                Button(action: { authMode = .createAccount }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(.subheadline)
                    .foregroundColor(Theme.Colors.textSecondary)
                }

                Spacer()
                    .frame(height: 20)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .alert("Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            isCodeFocused = true
        }
    }

    private func verify() {
        isCodeFocused = false
        isLoading = true

        Task {
            do {
                guard let signUp = Clerk.shared.client?.signUp else {
                    print("🔐 [Verify] No signUp on client")
                    throw ClerkError.signUpNotFound
                }
                print("🔐 [Verify] Verifying email code...")
                try await signUp.verifyEmailCode(code)
                print("🔐 [Verify] Verification complete!")
                print("🔐 [Verify] Session: \(String(describing: Clerk.shared.session))")
                print("🔐 [Verify] User: \(String(describing: Clerk.shared.user))")
            } catch {
                print("🔐 [Verify] ERROR: \(error)")
                errorMessage = error.localizedDescription
                showError = true
            }
            isLoading = false
        }
    }

    private func resendCode() {
        isResending = true

        Task {
            do {
                guard let signUp = Clerk.shared.client?.signUp else {
                    throw ClerkError.signUpNotFound
                }
                try await signUp.sendEmailCode()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isResending = false
        }
    }
}

enum ClerkError: LocalizedError {
    case signUpNotFound

    var errorDescription: String? {
        switch self {
        case .signUpNotFound:
            return "Sign-up session expired. Please try again."
        }
    }
}

// MARK: - Reusable Auth Components

struct AuthTextField: View {
    let placeholder: String
    @Binding var text: String
    let icon: String?
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType?

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            if let icon {
                Image(systemName: icon)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .frame(width: 20)
            }

            TextField(placeholder, text: $text)
                .keyboardType(keyboardType)
                .textContentType(textContentType)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, Theme.Spacing.md)
        .frame(height: 50)
        .background(Theme.Colors.cardBackground)
        .cornerRadius(Theme.CornerRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                .stroke(Theme.Colors.border, lineWidth: 1)
        )
    }
}

struct AuthSecureField: View {
    let placeholder: String
    @Binding var text: String
    let icon: String
    @State private var isRevealed = false

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: icon)
                .foregroundColor(Theme.Colors.textSecondary)
                .frame(width: 20)

            if isRevealed {
                TextField(placeholder, text: $text)
                    .textContentType(.password)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            } else {
                SecureField(placeholder, text: $text)
                    .textContentType(.password)
            }

            Button(action: { isRevealed.toggle() }) {
                Image(systemName: isRevealed ? "eye.slash" : "eye")
                    .foregroundColor(Theme.Colors.textSecondary)
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .frame(height: 50)
        .background(Theme.Colors.cardBackground)
        .cornerRadius(Theme.CornerRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                .stroke(Theme.Colors.border, lineWidth: 1)
        )
    }
}

// MARK: - Social Sign In

enum SocialProvider {
    case google
    case apple

    var label: String {
        switch self {
        case .google: return "Continue with Google"
        case .apple: return "Continue with Apple"
        }
    }

    var systemIcon: String? {
        switch self {
        case .google: return nil
        case .apple: return "apple.logo"
        }
    }

    var assetIcon: String? {
        switch self {
        case .google: return "google-logo"
        case .apple: return nil
        }
    }

    var backgroundColor: Color {
        switch self {
        case .google: return Theme.Colors.cardBackground
        case .apple: return Color(light: .black, dark: .white)
        }
    }

    var foregroundColor: Color {
        switch self {
        case .google: return Theme.Colors.textPrimary
        case .apple: return Color(light: .white, dark: .black)
        }
    }
}

struct SocialSignInButton: View {
    let provider: SocialProvider
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.sm) {
                if let assetIcon = provider.assetIcon {
                    Image(assetIcon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                } else if let systemIcon = provider.systemIcon {
                    Image(systemName: systemIcon)
                        .font(.system(size: 18))
                        .frame(width: 20, height: 20)
                }

                Text(provider.label)
                    .font(.system(size: 16, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .foregroundColor(provider.foregroundColor)
            .background(provider.backgroundColor)
            .cornerRadius(Theme.CornerRadius.md)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                    .stroke(Theme.Colors.border, lineWidth: 1)
            )
        }
    }
}
