import SwiftUI

struct OnboardingView: View {
    @State private var currentPage = 0
    @State private var showSimplefinWebView = false
    let onComplete: () -> Void

    private let pageCount = 3

    var body: some View {
        ZStack {
            Theme.Colors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $currentPage) {
                    welcomePage.tag(0)
                    whySimplefinPage.tag(1)
                    getStartedPage.tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: currentPage)

                // Page indicator + navigation
                VStack(spacing: Theme.Spacing.lg) {
                    // Page dots
                    HStack(spacing: 8) {
                        ForEach(0..<pageCount, id: \.self) { index in
                            Circle()
                                .fill(index == currentPage ? Theme.Colors.primary : Theme.Colors.textSecondary.opacity(0.3))
                                .frame(width: 8, height: 8)
                        }
                    }

                    if currentPage < pageCount - 1 {
                        Button {
                            currentPage += 1
                        } label: {
                            Text("Next")
                                .font(.system(size: 17, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Theme.Colors.primary)
                                .foregroundColor(.white)
                                .cornerRadius(Theme.CornerRadius.md)
                        }
                        .padding(.horizontal, Theme.Spacing.lg)

                        Button {
                            onComplete()
                        } label: {
                            Text("Skip")
                                .font(.subheadline)
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                    }
                }
                .padding(.bottom, 50)
            }
        }
    }

    // MARK: - Page 1: Welcome

    private var welcomePage: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer()

            Image("cashstate-logo")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)

            VStack(spacing: Theme.Spacing.sm) {
                Text("Welcome to CashState")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(Theme.Colors.textPrimary)
                    .multilineTextAlignment(.center)

                Text("All your bank accounts, transactions, and budgets in one place. Finally, a clear picture of your money.")
                    .font(.body)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.horizontal, Theme.Spacing.xl)

            // Feature highlights
            VStack(spacing: Theme.Spacing.md) {
                featureRow(icon: "building.columns", text: "Aggregate all your bank accounts")
                featureRow(icon: "chart.pie", text: "Auto-categorize your spending")
                featureRow(icon: "target", text: "Set goals and track your progress")
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.top, Theme.Spacing.md)

            Spacer()
            Spacer()
        }
    }

    // MARK: - Page 2: Why SimpleFin

    private var whySimplefinPage: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Theme.Colors.primary.opacity(0.1))
                    .frame(width: 100, height: 100)
                Image(systemName: "lock.shield")
                    .font(.system(size: 48))
                    .foregroundColor(Theme.Colors.primary)
            }

            VStack(spacing: Theme.Spacing.sm) {
                Text("Secure Bank Connection")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(Theme.Colors.textPrimary)
                    .multilineTextAlignment(.center)

                Text("CashState uses SimpleFin to securely connect to your banks. SimpleFin is a trusted, privacy-first service that gives you control of your financial data.")
                    .font(.body)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.horizontal, Theme.Spacing.xl)

            VStack(spacing: Theme.Spacing.md) {
                benefitRow(
                    icon: "eye.slash",
                    title: "Read-only access",
                    subtitle: "SimpleFin can only view your data — no one can move your money"
                )
                benefitRow(
                    icon: "dollarsign.circle",
                    title: "Just $1.50/month",
                    subtitle: "Connect up to 25 accounts for less than a cup of coffee"
                )
                benefitRow(
                    icon: "lock.rotation",
                    title: "No passwords shared",
                    subtitle: "Your bank credentials stay with your bank, never with us"
                )
                benefitRow(
                    icon: "checkmark.shield",
                    title: "You're in control",
                    subtitle: "Revoke access anytime — your data, your rules"
                )
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.top, Theme.Spacing.sm)

            Spacer()
            Spacer()
        }
    }

    // MARK: - Page 3: Get Started

    private var getStartedPage: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Theme.Colors.income.opacity(0.1))
                    .frame(width: 100, height: 100)
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 48))
                    .foregroundColor(Theme.Colors.income)
            }

            VStack(spacing: Theme.Spacing.sm) {
                Text("Ready to get started?")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(Theme.Colors.textPrimary)
                    .multilineTextAlignment(.center)

                Text("Get your SimpleFin access key, then connect your banks in CashState. It only takes a couple of minutes.")
                    .font(.body)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.horizontal, Theme.Spacing.xl)

            VStack(spacing: Theme.Spacing.sm) {
                stepRow(number: "1", text: "Sign up at SimpleFin ($1.50/mo)")
                stepRow(number: "2", text: "Connect your banks through SimpleFin")
                stepRow(number: "3", text: "Paste your access key in CashState")
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.top, Theme.Spacing.sm)

            Spacer()

            // CTAs
            VStack(spacing: Theme.Spacing.sm) {
                Button {
                    showSimplefinWebView = true
                } label: {
                    HStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Get a SimpleFin Key")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Theme.Colors.primary)
                    .foregroundColor(.white)
                    .cornerRadius(Theme.CornerRadius.md)
                }

                Button {
                    onComplete()
                } label: {
                    Text("I already have a key")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Theme.Colors.cardBackground)
                        .foregroundColor(Theme.Colors.textPrimary)
                        .cornerRadius(Theme.CornerRadius.md)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                                .stroke(Theme.Colors.border, lineWidth: 1)
                        )
                }

                Button {
                    onComplete()
                } label: {
                    Text("I'll do this later")
                        .font(.subheadline)
                        .foregroundColor(Theme.Colors.textSecondary)
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.bottom, 50)
            .sheet(isPresented: $showSimplefinWebView) {
                SimplefinBridgeWebView()
            }
        }
    }

    // MARK: - Components

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(Theme.Colors.primary)
                .frame(width: 32)
            Text(text)
                .font(.body)
                .foregroundColor(Theme.Colors.textPrimary)
            Spacer()
        }
    }

    private func benefitRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            ZStack {
                Circle()
                    .fill(Theme.Colors.primary.opacity(0.1))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(Theme.Colors.primary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Theme.Colors.textPrimary)
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(Theme.Colors.textSecondary)
                    .lineSpacing(2)
            }
            Spacer()
        }
    }

    private func stepRow(number: String, text: String) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            ZStack {
                Circle()
                    .fill(Theme.Colors.primary)
                    .frame(width: 28, height: 28)
                Text(number)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            }
            Text(text)
                .font(.body)
                .foregroundColor(Theme.Colors.textPrimary)
            Spacer()
        }
    }
}
