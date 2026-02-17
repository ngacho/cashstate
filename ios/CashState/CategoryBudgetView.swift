import SwiftUI

struct CategoryBudgetView: View {
    @Binding var category: BudgetCategory
    @Binding var isPresented: Bool
    let apiClient: APIClient

    @State private var budgetAmount: String
    @State private var isSaving: Bool = false
    @State private var errorMessage: String?

    init(category: Binding<BudgetCategory>, isPresented: Binding<Bool>, apiClient: APIClient) {
        self._category = category
        self._isPresented = isPresented
        self.apiClient = apiClient

        if let budget = category.wrappedValue.budgetAmount {
            _budgetAmount = State(initialValue: String(format: "%.0f", budget))
        } else {
            _budgetAmount = State(initialValue: "")
        }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    // Category header
                    VStack(spacing: Theme.Spacing.sm) {
                        Text(category.icon)
                            .font(.system(size: 60))
                            .frame(width: 100, height: 100)
                            .background(category.color.opacity(0.15))
                            .clipShape(Circle())

                        Text(category.name)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(Theme.Colors.textPrimary)

                        Text("Current spending: $\(String(format: "%.2f", category.spentAmount))")
                            .font(.subheadline)
                            .foregroundColor(Theme.Colors.textSecondary)

                        if !category.subcategories.isEmpty {
                            Text("\(category.subcategories.count) subcategories")
                                .font(.caption)
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                    }
                    .padding(.top, Theme.Spacing.md)

                    // Budget input
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text("Monthly Budget")
                            .font(.headline)
                            .foregroundColor(Theme.Colors.textPrimary)

                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("$")
                                .font(.title)
                                .foregroundColor(Theme.Colors.textPrimary)
                            TextField("0", text: $budgetAmount)
                                .font(.system(size: 36, weight: .bold))
                                .keyboardType(.decimalPad)
                                .foregroundColor(Theme.Colors.textPrimary)
                                .frame(maxWidth: 200)
                            Text("/ month")
                                .font(.title3)
                                .foregroundColor(Theme.Colors.textSecondary)
                        }

                        if let budget = Double(budgetAmount), budget > 0 {
                            let percentage = min((category.spentAmount / budget) * 100, 100)
                            let isOver = category.spentAmount > budget

                            VStack(spacing: Theme.Spacing.xs) {
                                HStack {
                                    Text("\(Int(percentage))% used")
                                        .font(.subheadline)
                                        .foregroundColor(isOver ? Theme.Colors.expense : Theme.Colors.textSecondary)
                                    Spacer()
                                    Text("$\(String(format: "%.2f", budget - category.spentAmount)) \(isOver ? "over" : "remaining")")
                                        .font(.subheadline)
                                        .foregroundColor(isOver ? Theme.Colors.expense : Theme.Colors.income)
                                }

                                GeometryReader { geometry in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Color.gray.opacity(0.15))
                                            .frame(height: 8)

                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(isOver ? Theme.Colors.expense : category.color)
                                            .frame(width: geometry.size.width * min(percentage / 100, 1.0), height: 8)
                                    }
                                }
                                .frame(height: 8)
                            }
                            .padding(.top, Theme.Spacing.sm)
                        }
                    }
                    .padding(.horizontal)

                    // Quick budget suggestions
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text("Suggestions")
                            .font(.headline)
                            .foregroundColor(Theme.Colors.textPrimary)
                            .padding(.horizontal)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: Theme.Spacing.sm) {
                                ForEach(budgetSuggestions, id: \.self) { amount in
                                    Button {
                                        budgetAmount = String(format: "%.0f", amount)
                                    } label: {
                                        Text("$\(Int(amount))")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .padding(.horizontal, Theme.Spacing.md)
                                            .padding(.vertical, Theme.Spacing.sm)
                                            .background(category.color.opacity(0.1))
                                            .foregroundColor(category.color)
                                            .cornerRadius(Theme.CornerRadius.md)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }

                    // Subcategory budgets info
                    if !category.subcategories.isEmpty {
                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            HStack {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(Theme.Colors.primary)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Tip: Set Subcategory Budgets")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(Theme.Colors.textPrimary)
                                    Text("You can also set budgets for individual subcategories within this category.")
                                        .font(.caption)
                                        .foregroundColor(Theme.Colors.textSecondary)
                                }
                            }
                            .padding()
                            .background(Theme.Colors.primary.opacity(0.1))
                            .cornerRadius(Theme.CornerRadius.md)
                        }
                        .padding(.horizontal)
                    }

                    // Remove budget option
                    if category.budgetAmount != nil {
                        Button {
                            budgetAmount = ""
                        } label: {
                            HStack {
                                Image(systemName: "xmark.circle.fill")
                                Text("Remove Budget")
                            }
                            .font(.subheadline)
                            .foregroundColor(Theme.Colors.expense)
                            .padding(.vertical, Theme.Spacing.sm)
                        }
                        if budgetAmount.isEmpty {
                            Text("Tap Save to confirm removal")
                                .font(.caption)
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                    }

                    // Error message
                    if let error = errorMessage {
                        HStack(spacing: Theme.Spacing.sm) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(Theme.CornerRadius.md)
                        .padding(.horizontal)
                    }

                    Spacer()
                }
            }
            .background(Theme.Colors.background)
            .navigationTitle("Set Category Budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Save") {
                            Task {
                                await saveBudget()
                            }
                        }
                        .fontWeight(.semibold)
                        .disabled(isSaving)
                    }
                }
            }
        }
    }

    private var budgetSuggestions: [Double] {
        // Smart suggestions based on current spending
        let spent = category.spentAmount
        let roundedSpent = (spent / 100).rounded(.up) * 100

        // Also consider sum of subcategory budgets
        let subcategoryBudgetSum = category.subcategories.compactMap { $0.budgetAmount }.reduce(0, +)

        var suggestions = Set<Double>()
        suggestions.insert(roundedSpent)
        suggestions.insert(roundedSpent + 100)
        suggestions.insert(roundedSpent * 1.5)
        suggestions.insert(roundedSpent * 2)

        if subcategoryBudgetSum > 0 {
            suggestions.insert(subcategoryBudgetSum)
            suggestions.insert((subcategoryBudgetSum / 100).rounded(.up) * 100)
        }

        return suggestions.sorted()
    }

    private func saveBudget() async {
        isSaving = true
        errorMessage = nil

        // Budget cleared — delete existing allocation if one exists
        if budgetAmount.trimmingCharacters(in: .whitespaces).isEmpty {
            if let budgetId = category.budgetId, let templateId = category.templateId {
                do {
                    try await apiClient.deleteCategoryBudget(
                        templateId: templateId,
                        categoryBudgetId: budgetId
                    )
                    category.budgetId = nil
                    category.budgetAmount = nil
                    category.templateId = nil
                } catch {
                    errorMessage = "Failed to remove budget: \(error.localizedDescription)"
                    isSaving = false
                    return
                }
            }
            isSaving = false
            isPresented = false
            return
        }

        guard let templateId = category.templateId else {
            errorMessage = "Missing template ID. Please try again."
            isSaving = false
            return
        }

        guard let amount = Double(budgetAmount), amount > 0 else {
            errorMessage = "Please enter a valid budget amount"
            isSaving = false
            return
        }

        do {
            if let budgetId = category.budgetId {
                let updated = try await apiClient.updateCategoryBudget(
                    templateId: templateId,
                    categoryBudgetId: budgetId,
                    amount: amount
                )
                category.budgetAmount = updated.amount
                category.budgetId = updated.id
            } else {
                let created = try await apiClient.addCategoryBudget(
                    templateId: templateId,
                    categoryId: category.id,
                    amount: amount
                )
                category.budgetAmount = created.amount
                category.budgetId = created.id
                category.templateId = created.templateId
            }

            isSaving = false
            isPresented = false
        } catch {
            isSaving = false
            errorMessage = "Failed to save: \(error.localizedDescription)"
        }
    }
}

#Preview {
    CategoryBudgetView(
        category: .constant(BudgetCategory.mockCategories[0]),
        isPresented: .constant(true),
        apiClient: APIClient()
    )
}
