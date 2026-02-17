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
                Button(action: { showOnboarding = true }) {
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
                Button(action: { showAddCategory = true }) {
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

    @State private var currentStep = 0
    @State private var monthlyBudget: String = ""
    @State private var selectedAccountIds: Set<String> = []
    @State private var accounts: [SimplefinAccount] = []
    @State private var isLoadingAccounts = false
    @State private var accountsError: String?

    @FocusState private var isInputFocused: Bool

    var budgetValue: Double? {
        Double(monthlyBudget)
    }

    var body: some View {
        NavigationView {
            VStack {
                if currentStep == 0 {
                    budgetInputStep
                } else {
                    accountSelectionStep
                }
            }
            .navigationTitle(currentStep == 0 ? "Monthly Budget" : "Select Accounts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(currentStep == 0 ? "Cancel" : "Back") {
                        if currentStep == 0 {
                            isPresented = false
                        } else {
                            currentStep -= 1
                        }
                    }
                }
            }
        }
        .task {
            await loadAccounts()
        }
    }

    private var budgetInputStep: some View {
        VStack(spacing: 24) {
            Spacer()

            // Icon
            Image(systemName: "dollarsign.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)

            // Title
            Text("Set Your Monthly Budget")
                .font(.title2)
                .fontWeight(.bold)

            // Description
            Text("We'll distribute this evenly across your expense categories. You can adjust individual budgets later.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            // Budget Input
            VStack(spacing: 8) {
                HStack {
                    Text("$")
                        .font(.largeTitle)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    TextField("3000", text: $monthlyBudget)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .keyboardType(.decimalPad)
                        .focused($isInputFocused)
                        .multilineTextAlignment(.leading)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal, 32)

                Text("Typical monthly budgets range from $1,500-$5,000")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Continue Button
            Button(action: {
                currentStep = 1
            }) {
                Text("Continue")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(budgetValue != nil && budgetValue! > 0 ? Color.blue : Color.gray.opacity(0.3))
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .disabled(budgetValue == nil || budgetValue! <= 0)
            .padding(.horizontal, 32)
            .padding(.top, 8)

            Spacer()
        }
        .onAppear {
            isInputFocused = true
        }
    }

    private var accountSelectionStep: some View {
        VStack(spacing: 24) {
            if isLoadingAccounts {
                Spacer()
                ProgressView("Loading accounts...")
                Spacer()
            } else if let error = accountsError {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.orange)
                    Text("Failed to load accounts")
                        .font(.headline)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                Spacer()
            } else if accounts.isEmpty {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "tray")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No accounts found")
                        .font(.headline)
                    Text("Connect your accounts first to track budgets")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                Spacer()
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Select Accounts to Track")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Choose which accounts you want to include in your budget. You can select all or track specific accounts.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.top)

                    // Quick Actions
                    HStack(spacing: 12) {
                        Button(action: {
                            selectedAccountIds = Set(accounts.map { $0.id })
                        }) {
                            Text("Select All")
                                .font(.subheadline)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(8)
                        }

                        Button(action: {
                            selectedAccountIds.removeAll()
                        }) {
                            Text("Clear All")
                                .font(.subheadline)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.gray.opacity(0.1))
                                .foregroundColor(.gray)
                                .cornerRadius(8)
                        }

                        Spacer()
                    }
                    .padding(.horizontal)

                    // Account List
                    ScrollView {
                        VStack(spacing: 12) {
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
                    }

                    // Submit Button
                    VStack(spacing: 8) {
                        if selectedAccountIds.isEmpty {
                            Text("No accounts selected = Track all accounts")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text("\(selectedAccountIds.count) account\(selectedAccountIds.count == 1 ? "" : "s") selected")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Button(action: {
                            if let budget = budgetValue {
                                isPresented = false
                                onComplete(budget, Array(selectedAccountIds))
                            }
                        }) {
                            Text("Complete Setup")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal)
                    }
                    .padding(.bottom)
                }
            }
        }
    }

    private func loadAccounts() async {
        isLoadingAccounts = true
        accountsError = nil

        do {
            let items = try await apiClient.listSimplefinItems()
            var allAccounts: [SimplefinAccount] = []

            // Fetch accounts for each item
            for item in items {
                let itemAccounts = try await apiClient.listSimplefinAccounts(itemId: item.id)
                allAccounts.append(contentsOf: itemAccounts)
            }

            await MainActor.run {
                self.accounts = allAccounts
                // Pre-select all accounts by default
                self.selectedAccountIds = Set(allAccounts.map { $0.id })
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
