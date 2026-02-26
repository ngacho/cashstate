import SwiftUI

struct EditGoalView: View {
    let apiClient: APIClient
    let goal: Goal
    var onUpdated: (Goal) -> Void

    @State private var name: String
    @State private var description: String
    @State private var targetAmount: String
    @State private var targetDate: Date?
    @State private var isCompleted: Bool
    @State private var accounts: [SimplefinAccount] = []
    @State private var selectedAllocations: [String: Double] = [:]
    @State private var showDatePicker = false
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var error: String?

    @Environment(\.dismiss) private var dismiss

    init(apiClient: APIClient, goal: Goal, onUpdated: @escaping (Goal) -> Void) {
        self.apiClient = apiClient
        self.goal = goal
        self.onUpdated = onUpdated
        _name = State(initialValue: goal.name)
        _description = State(initialValue: goal.description ?? "")
        _targetAmount = State(initialValue: String(format: "%.2f", goal.targetAmount))
        _isCompleted = State(initialValue: goal.isCompleted)

        // Pre-fill allocations from existing goal accounts
        var allocations: [String: Double] = [:]
        for acc in goal.accounts {
            allocations[acc.simplefinAccountId] = acc.allocationPercentage
        }
        _selectedAllocations = State(initialValue: allocations)

        // Parse target date
        if let dateStr = goal.targetDate, !dateStr.isEmpty {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            _targetDate = State(initialValue: formatter.date(from: dateStr))
        } else {
            _targetDate = State(initialValue: nil)
        }
    }

    private var targetAmountDouble: Double? {
        Double(targetAmount.replacingOccurrences(of: ",", with: ""))
    }

    private var eligibleAccounts: [SimplefinAccount] {
        accounts.filter { account in
            let balance = account.balance ?? 0
            if goal.goalType == .savings { return balance >= 0 }
            else { return balance < 0 }
        }
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
        && targetAmountDouble != nil
        && (targetAmountDouble ?? 0) > 0
        && !selectedAllocations.filter({ $0.value > 0 }).isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                // Basic info
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text("Goal Details")
                        .font(.headline)
                        .foregroundColor(Theme.Colors.textPrimary)

                    VStack(spacing: 0) {
                        TextField("Goal name", text: $name)
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

                // Goal type (read-only)
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Goal Type")
                        .font(.headline)
                        .foregroundColor(Theme.Colors.textPrimary)
                    HStack {
                        GoalTypeBadge(goalType: goal.goalType)
                        Text("(cannot be changed)")
                            .font(.caption)
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                }

                // Target amount
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text(goal.goalType == .debtPayment ? "Amount to Pay Off" : "Target Amount")
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
                            Button("Clear") { targetDate = nil }
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

                // Mark completed toggle
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Toggle(isOn: $isCompleted) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Mark as Completed")
                                .font(.body)
                                .foregroundColor(Theme.Colors.textPrimary)
                            Text("Goal will show as achieved")
                                .font(.caption)
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                    }
                    .padding(Theme.Spacing.md)
                    .background(Theme.Colors.cardBackground)
                    .cornerRadius(Theme.CornerRadius.md)
                    .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
                    .tint(Theme.Colors.income)
                }

                // Account allocations
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text("Linked Accounts")
                        .font(.headline)
                        .foregroundColor(Theme.Colors.textPrimary)

                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else if goal.goalType == .debtPayment {
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
                                existingAllocation: 0  // On edit, we replace all, so no existing cap
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

                // Save button
                Button {
                    Task { await saveChanges() }
                } label: {
                    Group {
                        if isSaving {
                            ProgressView().tint(.white)
                        } else {
                            Text("Save Changes").fontWeight(.semibold)
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
        .navigationTitle("Edit Goal")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadAccounts()
        }
        .onAppear {
            Analytics.shared.screen(.editGoal)
        }
    }

    private func loadAccounts() async {
        isLoading = true
        defer { isLoading = false }
        do {
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

    private func saveChanges() async {
        isSaving = true
        defer { isSaving = false }
        error = nil

        let accountRequests: [GoalAccountRequest] = selectedAllocations.compactMap { (accountId, pct) in
            guard pct > 0 else { return nil }
            return GoalAccountRequest(simplefinAccountId: accountId, allocationPercentage: pct)
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateStr = targetDate.map { formatter.string(from: $0) }

        do {
            let updated = try await apiClient.updateGoal(
                goalId: goal.id,
                name: name.trimmingCharacters(in: .whitespaces),
                description: description.isEmpty ? nil : description,
                targetAmount: targetAmountDouble,
                targetDate: dateStr,
                isCompleted: isCompleted,
                accounts: accountRequests.isEmpty ? nil : accountRequests
            )
            Analytics.shared.track(.goalEdited, properties: ["goal_type": goal.goalType.rawValue])
            onUpdated(updated)
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
