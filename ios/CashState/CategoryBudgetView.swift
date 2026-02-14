import SwiftUI

struct CategoryBudgetView: View {
    @Binding var category: BudgetCategory
    @Binding var isPresented: Bool

    @State private var budgetAmount: String

    init(category: Binding<BudgetCategory>, isPresented: Binding<Bool>) {
        self._category = category
        self._isPresented = isPresented

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
                            .background(category.color.color.opacity(0.15))
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
                                            .fill(isOver ? Theme.Colors.expense : category.color.color)
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
                                            .background(category.color.color.opacity(0.1))
                                            .foregroundColor(category.color.color)
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
                    Button("Save") {
                        saveBudget()
                    }
                    .fontWeight(.semibold)
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

    private func saveBudget() {
        if let amount = Double(budgetAmount), amount > 0 {
            category.budgetAmount = amount
        } else {
            category.budgetAmount = nil
        }
        isPresented = false
    }
}

#Preview {
    CategoryBudgetView(
        category: .constant(BudgetCategory.mockCategories[0]),
        isPresented: .constant(true)
    )
}
