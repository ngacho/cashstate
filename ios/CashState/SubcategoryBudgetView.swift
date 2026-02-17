import SwiftUI

struct SubcategoryBudgetView: View {
    @Binding var subcategory: BudgetSubcategory
    let categoryColor: Color
    @Binding var isPresented: Bool
    let apiClient: APIClient

    @State private var budgetAmount: String
    @State private var isSaving: Bool = false
    @State private var errorMessage: String?

    init(subcategory: Binding<BudgetSubcategory>, categoryColor: Color, isPresented: Binding<Bool>, apiClient: APIClient) {
        self._subcategory = subcategory
        self.categoryColor = categoryColor
        self._isPresented = isPresented
        self.apiClient = apiClient

        if let budget = subcategory.wrappedValue.budgetAmount {
            _budgetAmount = State(initialValue: String(format: "%.0f", budget))
        } else {
            _budgetAmount = State(initialValue: "")
        }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    // Subcategory header
                    VStack(spacing: Theme.Spacing.sm) {
                        Text(subcategory.icon)
                            .font(.system(size: 60))
                            .frame(width: 100, height: 100)
                            .background(categoryColor.opacity(0.15))
                            .clipShape(Circle())

                        Text(subcategory.name)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(Theme.Colors.textPrimary)

                        Text("Current spending: $\(String(format: "%.2f", subcategory.spentAmount))")
                            .font(.subheadline)
                            .foregroundColor(Theme.Colors.textSecondary)
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
                            let percentage = min((subcategory.spentAmount / budget) * 100, 100)
                            let isOver = subcategory.spentAmount > budget

                            VStack(spacing: Theme.Spacing.xs) {
                                HStack {
                                    Text("\(Int(percentage))% used")
                                        .font(.subheadline)
                                        .foregroundColor(isOver ? Theme.Colors.expense : Theme.Colors.textSecondary)
                                    Spacer()
                                    Text("$\(String(format: "%.2f", budget - subcategory.spentAmount)) \(isOver ? "over" : "remaining")")
                                        .font(.subheadline)
                                        .foregroundColor(isOver ? Theme.Colors.expense : Theme.Colors.income)
                                }

                                GeometryReader { geometry in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Color.gray.opacity(0.15))
                                            .frame(height: 8)

                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(isOver ? Theme.Colors.expense : categoryColor)
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
                                            .background(categoryColor.opacity(0.1))
                                            .foregroundColor(categoryColor)
                                            .cornerRadius(Theme.CornerRadius.md)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }

                    // Remove budget option
                    if subcategory.budgetAmount != nil {
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
            .navigationTitle("Set Budget")
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
        let spent = subcategory.spentAmount
        let roundedSpent = (spent / 50).rounded(.up) * 50
        return [
            roundedSpent,
            roundedSpent + 50,
            roundedSpent * 1.5,
            roundedSpent * 2,
            (roundedSpent / 10).rounded(.up) * 100
        ].sorted().uniqued()
    }

    private func saveBudget() async {
        isSaving = true
        errorMessage = nil

        // Budget cleared — delete existing allocation if one exists
        if budgetAmount.trimmingCharacters(in: .whitespaces).isEmpty {
            if let budgetId = subcategory.budgetId, let templateId = subcategory.templateId {
                do {
                    try await apiClient.deleteSubcategoryBudget(
                        templateId: templateId,
                        subcategoryBudgetId: budgetId
                    )
                    subcategory.budgetId = nil
                    subcategory.budgetAmount = nil
                    subcategory.templateId = nil
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

        guard let templateId = subcategory.templateId else {
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
            if let budgetId = subcategory.budgetId {
                let updated = try await apiClient.updateSubcategoryBudget(
                    templateId: templateId,
                    subcategoryBudgetId: budgetId,
                    amount: amount
                )
                subcategory.budgetAmount = updated.amount
                subcategory.budgetId = updated.id
            } else {
                let created = try await apiClient.addSubcategoryBudget(
                    templateId: templateId,
                    subcategoryId: subcategory.id,
                    amount: amount
                )
                subcategory.budgetAmount = created.amount
                subcategory.budgetId = created.id
                subcategory.templateId = created.templateId
            }

            isSaving = false
            isPresented = false
        } catch {
            isSaving = false
            errorMessage = "Failed to save: \(error.localizedDescription)"
        }
    }
}

// MARK: - Array Extension for Unique Values

extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

#Preview {
    SubcategoryBudgetView(
        subcategory: .constant(BudgetSubcategory(
            id: "1",
            name: "Movies",
            icon: "🍿",
            budgetAmount: 100.00,
            spentAmount: 45.00,
            transactionCount: 3
        )),
        categoryColor: .blue,
        isPresented: .constant(true),
        apiClient: APIClient()
    )
}
