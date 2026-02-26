import SwiftUI

struct BudgetEmptyStateView: View {
    let apiClient: APIClient
    @Binding var isLoading: Bool
    @Binding var error: String?
    var onCategoriesAdded: () -> Void

    @State private var showAddCategory = false
    @State private var showOnboarding = false
    @State private var seedResult: SeedDefaultsResponse?

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Icon
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            // Title
            Text("No Categories Yet")
                .font(.title2)
                .fontWeight(.bold)

            // Description
            Text("Get started by adding categories to track your spending")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            // Action Buttons
            VStack(spacing: 12) {
                // Use Defaults Button
                Button(action: {
                    Analytics.shared.track(.onboardingStarted)
                    showOnboarding = true
                }) {
                    HStack {
                        Image(systemName: "sparkles")
                        Text("Use Default Categories")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(isLoading)

                // Create Custom Button
                Button(action: {
                    Analytics.shared.screen(.addCategory, properties: ["source": "empty_state"])
                    showAddCategory = true
                }) {
                    HStack {
                        Image(systemName: "plus.circle")
                        Text("Create Custom Category")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(12)
                }
                .disabled(isLoading)
            }
            .padding(.horizontal, 32)
            .padding(.top, 8)

            if isLoading {
                ProgressView("Setting up categories...")
                    .padding(.top)
            }

            if let error = error {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding()
            }

            Spacer()
        }
        .sheet(isPresented: $showAddCategory) {
            AddCategoryView(isPresented: $showAddCategory, apiClient: apiClient) { _ in
                onCategoriesAdded()
            }
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingFlow(
                apiClient: apiClient,
                isPresented: $showOnboarding,
                onComplete: { budget, accountIds in
                    seedDefaults(monthlyBudget: budget, accountIds: accountIds)
                }
            )
        }
        .alert("Setup Complete!", isPresented: .constant(seedResult != nil)) {
            Button("OK") {
                seedResult = nil
                onCategoriesAdded()
            }
        } message: {
            if let result = seedResult {
                Text("""
                Created \(result.categoriesCreated) categories and \(result.subcategoriesCreated) subcategories!

                Your $\(String(format: "%.2f", result.monthlyBudget)) monthly budget has been split into $\(String(format: "%.2f", result.budgetPerCategory)) per category.

                You can adjust these budgets anytime.
                """)
            }
        }
    }

    private func seedDefaults(monthlyBudget: Double, accountIds: [String]) {
        isLoading = true
        error = nil

        Task {
            do {
                let result = try await apiClient.seedDefaultCategories(
                    monthlyBudget: monthlyBudget,
                    accountIds: accountIds
                )
                await MainActor.run {
                    isLoading = false
                    seedResult = result
                    Analytics.shared.track(.defaultCategoriesSeeded, properties: [
                        "categories_created": result.categoriesCreated,
                        "subcategories_created": result.subcategoriesCreated,
                        "monthly_budget": monthlyBudget
                    ])
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}

// MARK: - Onboarding Flow

struct OnboardingFlow: View {
    let apiClient: APIClient
    @Binding var isPresented: Bool
    var onComplete: (Double, [String]) -> Void

    @State private var monthlyBudget: String = ""
    @State private var selectedAccountIds: Set<String> = []
    @State private var accounts: [SimplefinAccount] = []
    @State private var isLoadingAccounts = false
    @State private var accountsError: String?

    @FocusState private var isInputFocused: Bool

    var budgetValue: Double? {
        Double(monthlyBudget)
    }

    var canComplete: Bool {
        budgetValue != nil && budgetValue! > 0
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 28) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "dollarsign.circle.fill")
                            .font(.system(size: 52))
                            .foregroundColor(.blue)
                        Text("Set Up Your Budget")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Enter a monthly total and choose which accounts to track.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    .padding(.top, 24)

                    // Budget Input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Monthly Budget")
                            .font(.headline)
                            .padding(.horizontal)

                        HStack {
                            Text("$")
                                .font(.largeTitle)
                                .fontWeight(.medium)
                            TextField("3000", text: $monthlyBudget)
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .keyboardType(.decimalPad)
                                .focused($isInputFocused)
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal)

                        Text("We'll distribute this evenly across categories. Adjust anytime.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                    }

                    // Accounts Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Accounts to Track")
                                .font(.headline)
                            Spacer()
                            if !accounts.isEmpty {
                                Button(selectedAccountIds.count == accounts.count ? "Clear All" : "Select All") {
                                    if selectedAccountIds.count == accounts.count {
                                        selectedAccountIds.removeAll()
                                    } else {
                                        selectedAccountIds = Set(accounts.map { $0.id })
                                    }
                                }
                                .font(.subheadline)
                                .foregroundColor(.blue)
                            }
                        }
                        .padding(.horizontal)

                        if isLoadingAccounts {
                            HStack {
                                Spacer()
                                ProgressView("Loading accounts...")
                                Spacer()
                            }
                            .padding(.vertical, 24)
                        } else if let error = accountsError {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal)
                        } else if accounts.isEmpty {
                            Text("No accounts found. You can still set up your budget.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                        } else {
                            VStack(spacing: 8) {
                                ForEach(accounts) { account in
                                    AccountSelectionRow(
                                        account: account,
                                        isSelected: selectedAccountIds.contains(account.id)
                                    ) {
                                        if selectedAccountIds.contains(account.id) {
                                            selectedAccountIds.remove(account.id)
                                        } else {
                                            selectedAccountIds.insert(account.id)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal)

                            if selectedAccountIds.isEmpty {
                                Text("No accounts selected — all accounts will be tracked")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal)
                            }
                        }
                    }

                    // Complete Button
                    Button(action: {
                        if let budget = budgetValue {
                            Analytics.shared.track(.onboardingCompleted, properties: [
                                "monthly_budget": budget,
                                "accounts_selected": selectedAccountIds.count
                            ])
                            isPresented = false
                            onComplete(budget, Array(selectedAccountIds))
                        }
                    }) {
                        Text("Complete Setup")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(canComplete ? Color.blue : Color.gray.opacity(0.3))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .disabled(!canComplete)
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Monthly Budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
        .onAppear {
            isInputFocused = true
            Analytics.shared.screen(.onboarding)
        }
        .task {
            await loadAccounts()
        }
    }

    private func loadAccounts() async {
        isLoadingAccounts = true
        accountsError = nil

        do {
            let items = try await apiClient.listSimplefinItems()
            var allAccounts: [SimplefinAccount] = []

            for item in items {
                let itemAccounts = try await apiClient.listSimplefinAccounts(itemId: item.id)
                allAccounts.append(contentsOf: itemAccounts)
            }

            await MainActor.run {
                self.accounts = allAccounts
                isLoadingAccounts = false
            }
        } catch {
            await MainActor.run {
                accountsError = error.localizedDescription
                isLoadingAccounts = false
            }
        }
    }
}

// MARK: - Account Selection Row

struct AccountSelectionRow: View {
    let account: SimplefinAccount
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Checkmark
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(isSelected ? .blue : .gray)

                VStack(alignment: .leading, spacing: 4) {
                    Text(account.name)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)

                    HStack(spacing: 8) {
                        if let orgName = account.organizationName {
                            Text(orgName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        if let balance = account.balance {
                            Text("•")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("$\(String(format: "%.2f", balance))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer()
            }
            .padding()
            .background(isSelected ? Color.blue.opacity(0.05) : Color.gray.opacity(0.05))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
