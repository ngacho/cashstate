import SwiftUI

struct CreateGoalView: View {
    let apiClient: APIClient
    var onCreated: (Goal) -> Void

    @State private var name = ""
    @State private var description = ""
    @State private var goalType: GoalType = .savings
    @State private var targetAmount = ""
    @State private var targetDate: Date? = nil
    @State private var showDatePicker = false
    @State private var accounts: [SimplefinAccount] = []
    @State private var selectedAllocations: [String: Double] = [:]  // account_id -> %
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var error: String?
    @State private var accountAllocations: [String: Double] = [:]  // existing allocation per account

    @Environment(\.dismiss) private var dismiss

    private var targetAmountDouble: Double? {
        Double(targetAmount.replacingOccurrences(of: ",", with: ""))
    }

    private var eligibleAccounts: [SimplefinAccount] {
        accounts.filter { account in
            let balance = account.balance ?? 0
            if goalType == .savings { return balance >= 0 }
            else { return balance < 0 }
        }
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
        && targetAmountDouble != nil
        && (targetAmountDouble ?? 0) > 0
        && !selectedAllocations.isEmpty
        && selectedAllocations.values.allSatisfy { $0 > 0 }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                // Basic info section
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text("Goal Details")
                        .font(.headline)
                        .foregroundColor(Theme.Colors.textPrimary)

                    VStack(spacing: 0) {
                        TextField("Goal name (e.g. Emergency Fund)", text: $name)
                            .padding(Theme.Spacing.md)
                            .background(Theme.Colors.cardBackground)

                        Divider().padding(.leading, Theme.Spacing.md)

                        TextField("Description (optional)", text: $description)
                            .padding(Theme.Spacing.md)
                            .background(Theme.Colors.cardBackground)
                    }
                    .cornerRadius(Theme.CornerRadius.md)
                    .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
                }

                // Goal type picker
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text("Goal Type")
                        .font(.headline)
                        .foregroundColor(Theme.Colors.textPrimary)

                    Picker("Goal Type", selection: $goalType) {
                        ForEach(GoalType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: goalType) {
                        // Clear selections when type changes (different eligible accounts)
                        selectedAllocations = [:]
                    }

                    Text(goalType == .savings
                         ? "Track savings in positive-balance accounts"
                         : "Track debt reduction in negative-balance accounts")
                        .font(.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                }

                // Target amount
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text(goalType == .debtPayment ? "Amount to Pay Off" : "Target Amount")
                        .font(.headline)
                        .foregroundColor(Theme.Colors.textPrimary)

                    HStack {
                        Text("$")
                            .foregroundColor(Theme.Colors.textSecondary)
                        TextField("0.00", text: $targetAmount)
                            .keyboardType(.decimalPad)
                    }
                    .padding(Theme.Spacing.md)
                    .background(Theme.Colors.cardBackground)
                    .cornerRadius(Theme.CornerRadius.md)
                    .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
                }

                // Target date
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    HStack {
                        Text("Target Date")
                            .font(.headline)
                            .foregroundColor(Theme.Colors.textPrimary)
                        Spacer()
                        if targetDate != nil {
                            Button("Clear") {
                                targetDate = nil
                            }
                            .font(.caption)
                            .foregroundColor(Theme.Colors.primary)
                        }
                    }

                    Button {
                        showDatePicker.toggle()
                    } label: {
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundColor(Theme.Colors.primary)
                            Text(targetDate.map { dateFormatter.string(from: $0) } ?? "Optional — select a target date")
                                .foregroundColor(targetDate == nil ? Theme.Colors.textSecondary : Theme.Colors.textPrimary)
                            Spacer()
                        }
                        .padding(Theme.Spacing.md)
                        .background(Theme.Colors.cardBackground)
                        .cornerRadius(Theme.CornerRadius.md)
                        .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
                    }

                    if showDatePicker {
                        DatePicker(
                            "Target Date",
                            selection: Binding(
                                get: { targetDate ?? Date() },
                                set: { targetDate = $0 }
                            ),
                            in: Date()...,
                            displayedComponents: .date
                        )
                        .datePickerStyle(.graphical)
                        .background(Theme.Colors.cardBackground)
                        .cornerRadius(Theme.CornerRadius.md)
                    }
                }

                // Account selection
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text("Linked Accounts")
                        .font(.headline)
                        .foregroundColor(Theme.Colors.textPrimary)

                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else if eligibleAccounts.isEmpty {
                        Text("No \(goalType == .savings ? "positive" : "negative")-balance accounts available. Add accounts in the Accounts tab first.")
                            .font(.subheadline)
                            .foregroundColor(Theme.Colors.textSecondary)
                            .padding()
                            .background(Theme.Colors.cardBackground)
                            .cornerRadius(Theme.CornerRadius.md)
                    } else if goalType == .debtPayment {
                        // Debt: just pick which account(s) to track — no allocation slider
                        Text("Select which debt account(s) to track. Progress measures how much you've paid off since creating this goal.")
                            .font(.caption)
                            .foregroundColor(Theme.Colors.textSecondary)
                            .padding(.bottom, 2)
                        ForEach(eligibleAccounts) { account in
                            DebtAccountRow(
                                account: account,
                                isSelected: (selectedAllocations[account.id] ?? 0) > 0,
                                onToggle: {
                                    if (selectedAllocations[account.id] ?? 0) > 0 {
                                        selectedAllocations[account.id] = nil
                                    } else {
                                        selectedAllocations[account.id] = 100
                                    }
                                }
                            )
                        }
                    } else {
                        ForEach(eligibleAccounts) { account in
                            AccountAllocationRow(
                                account: account,
                                allocation: Binding(
                                    get: { selectedAllocations[account.id] },
                                    set: { selectedAllocations[account.id] = $0 }
                                ),
                                existingAllocation: accountAllocations[account.id] ?? 0
                            )
                        }
                    }
                }

                if let error = error {
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(Theme.Colors.expense)
                        .padding(Theme.Spacing.sm)
                        .background(Theme.Colors.expense.opacity(0.1))
                        .cornerRadius(Theme.CornerRadius.sm)
                }

                // Create button
                Button {
                    Task { await createGoal() }
                } label: {
                    Group {
                        if isSaving {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Create Goal")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(Theme.Spacing.md)
                    .background(isValid ? Theme.Colors.primary : Color.gray.opacity(0.4))
                    .foregroundColor(.white)
                    .cornerRadius(Theme.CornerRadius.md)
                }
                .disabled(!isValid || isSaving)

                Spacer(minLength: Theme.Spacing.xl)
            }
            .padding(Theme.Spacing.md)
        }
        .background(Theme.Colors.background)
        .navigationTitle("New Goal")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadAccounts()
        }
        .onAppear {
            Analytics.shared.screen(.createGoal)
        }
    }

    private func loadAccounts() async {
        isLoading = true
        defer { isLoading = false }
        do {
            // Get all user accounts via the simplefin items endpoint
            let items = try await apiClient.listSimplefinItems()
            var allAccounts: [SimplefinAccount] = []
            for item in items {
                let accs = try await apiClient.listSimplefinAccounts(itemId: item.id)
                allAccounts.append(contentsOf: accs)
            }
            accounts = allAccounts
        } catch {
            self.error = "Failed to load accounts: \(error.localizedDescription)"
        }
    }

    private func createGoal() async {
        guard let amount = targetAmountDouble else { return }
        isSaving = true
        defer { isSaving = false }
        error = nil

        let accountRequests = selectedAllocations.compactMap { (accountId, pct) -> GoalAccountRequest? in
            guard pct > 0 else { return nil }
            return GoalAccountRequest(simplefinAccountId: accountId, allocationPercentage: pct)
        }

        do {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let dateStr = targetDate.map { formatter.string(from: $0) }

            let goal = try await apiClient.createGoal(
                name: name.trimmingCharacters(in: .whitespaces),
                description: description.isEmpty ? nil : description,
                goalType: goalType,
                targetAmount: amount,
                targetDate: dateStr,
                accounts: accountRequests
            )
            Analytics.shared.track(.goalCreated, properties: ["goal_type": goalType.rawValue])
            onCreated(goal)
            dismiss()
        } catch let err as APIError {
            error = err.localizedDescription
        } catch {
            self.error = error.localizedDescription
        }
    }

    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f
    }
}

// MARK: - Debt Account Row (no allocation slider)

struct DebtAccountRow: View {
    let account: SimplefinAccount
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? Theme.Colors.primary : Color.gray.opacity(0.5))
                VStack(alignment: .leading, spacing: 2) {
                    Text(account.name)
                        .font(.body)
                        .foregroundColor(Theme.Colors.textPrimary)
                    Text(account.displayBalance)
                        .font(.caption)
                        .foregroundColor(Theme.Colors.expense)
                }
                Spacer()
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.cardBackground)
        .cornerRadius(Theme.CornerRadius.md)
        .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 1)
    }
}

// MARK: - Account Allocation Row

struct AccountAllocationRow: View {
    let account: SimplefinAccount
    @Binding var allocation: Double?
    let existingAllocation: Double  // sum of other goals' allocation for this account

    private var isSelected: Bool { allocation != nil && (allocation ?? 0) > 0 }
    private var available: Double { 100 - existingAllocation }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack {
                // Checkbox toggle
                Button {
                    if isSelected {
                        allocation = nil
                    } else {
                        allocation = min(100, available)
                    }
                } label: {
                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(isSelected ? Theme.Colors.primary : Color.gray.opacity(0.5))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(account.name)
                                .font(.body)
                                .foregroundColor(Theme.Colors.textPrimary)
                            Text(account.displayBalance)
                                .font(.caption)
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                    }
                }
                Spacer()

                if existingAllocation > 0 {
                    Text("\(Int(existingAllocation))% used")
                        .font(.caption)
                        .foregroundColor(existingAllocation >= 90 ? Theme.Colors.expense : Theme.Colors.textSecondary)
                }
            }

            if isSelected {
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("Allocation: \(Int(allocation ?? 0))%")
                            .font(.caption)
                            .foregroundColor(Theme.Colors.textSecondary)
                        Spacer()
                        Text("Available: \(Int(available))%")
                            .font(.caption)
                            .foregroundColor(available <= 20 ? Theme.Colors.expense : Theme.Colors.income)
                    }
                    Slider(
                        value: Binding(
                            get: { allocation ?? 0 },
                            set: { allocation = $0 }
                        ),
                        in: 1...max(1, available),
                        step: 1
                    )
                    .tint(Theme.Colors.primary)
                }
                .padding(.leading, 28)
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.cardBackground)
        .cornerRadius(Theme.CornerRadius.md)
        .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 1)
        .opacity(available <= 0 && !isSelected ? 0.5 : 1)
    }
}
