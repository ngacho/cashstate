import SwiftUI

struct EditBudgetView: View {
    @Binding var budget: Budget
    @Binding var categories: [BudgetCategory]
    @Binding var isPresented: Bool
    let apiClient: APIClient

    @State private var budgetName: String
    @State private var budgetAmount: String
    @State private var selectedType: Budget.BudgetType
    @State private var selectedPeriod: Budget.BudgetPeriod
    @State private var selectedColor: ColorPalette
    @State private var selectedTransactionFilters: Set<Budget.TransactionFilter>
    @State private var selectedAccountFilters: Set<Budget.AccountFilter>
    @State private var includedCategories: Set<String>
    @State private var excludedCategories: Set<String>
    @State private var showCategorySelection = false
    @State private var expandedCategories: Set<String> = []
    @State private var subcategoryAmounts: [String: String] = [:]

    init(budget: Binding<Budget>, categories: Binding<[BudgetCategory]>, isPresented: Binding<Bool>, apiClient: APIClient) {
        self._budget = budget
        self._categories = categories
        self._isPresented = isPresented
        self.apiClient = apiClient

        let budgetValue = budget.wrappedValue
        _budgetName = State(initialValue: budgetValue.name)
        _budgetAmount = State(initialValue: String(format: "%.0f", budgetValue.amount))
        _selectedType = State(initialValue: budgetValue.type)
        _selectedPeriod = State(initialValue: budgetValue.period)
        _selectedColor = State(initialValue: ColorPalette(rawValue: budgetValue.colorHex) ?? .blue)
        _selectedTransactionFilters = State(initialValue: Set(budgetValue.transactionFilters))
        _selectedAccountFilters = State(initialValue: Set(budgetValue.accountFilters))
        _includedCategories = State(initialValue: Set(budgetValue.includedCategories))
        _excludedCategories = State(initialValue: Set(budgetValue.excludedCategories))

        // Initialize subcategory amounts from existing budget data
        var amounts: [String: String] = [:]
        for category in categories.wrappedValue {
            for sub in category.subcategories {
                if let amount = sub.budgetAmount {
                    amounts[sub.id] = String(format: "%.0f", amount)
                }
            }
        }
        _subcategoryAmounts = State(initialValue: amounts)
        // Start all included categories expanded
        _expandedCategories = State(initialValue: Set(budgetValue.includedCategories))
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    // Budget Type Toggle
                    HStack(spacing: 0) {
                        ForEach(Budget.BudgetType.allCases, id: \.self) { type in
                            Button {
                                selectedType = type
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: type == .expense ? "arrow.down" : "arrow.up")
                                        .font(.caption)
                                    Text(type.rawValue)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, Theme.Spacing.sm)
                                .background(selectedType == type ? Theme.Colors.primary : Theme.Colors.cardBackground.opacity(0.5))
                                .foregroundColor(selectedType == type ? .white : Theme.Colors.textSecondary)
                            }
                        }
                    }
                    .background(Theme.Colors.cardBackground)
                    .cornerRadius(Theme.CornerRadius.md)
                    .padding(.horizontal)

                    // Budget Name
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text(budgetName.isEmpty ? "Budget Name" : budgetName)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(Theme.Colors.textPrimary)
                            .padding(.horizontal)

                        TextField("Enter budget name", text: $budgetName)
                            .textFieldStyle(.plain)
                            .padding()
                            .background(Theme.Colors.cardBackground)
                            .cornerRadius(Theme.CornerRadius.md)
                            .padding(.horizontal)
                    }

                    // Budget Amount and Period
                    VStack(spacing: Theme.Spacing.sm) {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("$")
                                .font(.title)
                                .foregroundColor(Theme.Colors.textPrimary)
                            TextField("0", text: $budgetAmount)
                                .font(.system(size: 36, weight: .bold))
                                .keyboardType(.decimalPad)
                                .foregroundColor(Theme.Colors.textPrimary)
                                .frame(maxWidth: 200)
                            Text("/")
                                .font(.title)
                                .foregroundColor(Theme.Colors.textSecondary)

                            Menu {
                                Picker("Period", selection: $selectedPeriod) {
                                    ForEach(Budget.BudgetPeriod.allCases, id: \.self) { period in
                                        Text(period.rawValue).tag(period)
                                    }
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Text(selectedPeriod.rawValue)
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                    Image(systemName: "chevron.down")
                                        .font(.caption)
                                }
                                .foregroundColor(Theme.Colors.primary)
                            }
                        }
                        .padding(.horizontal)

                        Text("beginning \(formattedStartDate)")
                            .font(.subheadline)
                            .foregroundColor(Theme.Colors.textSecondary)
                            .padding(.horizontal)
                    }

                    // Select Color
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text("Select Color")
                            .font(.subheadline)
                            .foregroundColor(Theme.Colors.textSecondary)
                            .padding(.horizontal)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: Theme.Spacing.md) {
                                ForEach(ColorPalette.allCases) { color in
                                    Button {
                                        selectedColor = color
                                    } label: {
                                        Circle()
                                            .fill(color.color)
                                            .frame(width: 50, height: 50)
                                            .overlay(
                                                Circle()
                                                    .stroke(selectedColor == color ? Color.white : Color.clear, lineWidth: 3)
                                                    .padding(3)
                                            )
                                            .overlay(
                                                Circle()
                                                    .stroke(selectedColor == color ? color.color : Color.clear, lineWidth: 2)
                                            )
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }

                    // Transactions to Include
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        HStack(spacing: 4) {
                            Image(systemName: "info.circle")
                                .font(.caption)
                            Text("Transactions to Include")
                                .font(.subheadline)
                        }
                        .foregroundColor(Theme.Colors.textSecondary)
                        .padding(.horizontal)

                        FlowLayout(spacing: Theme.Spacing.xs) {
                            ForEach(Budget.TransactionFilter.allCases, id: \.self) { filter in
                                FilterChip(
                                    title: filter.rawValue,
                                    isSelected: selectedTransactionFilters.contains(filter),
                                    action: {
                                        if selectedTransactionFilters.contains(filter) {
                                            selectedTransactionFilters.remove(filter)
                                        } else {
                                            selectedTransactionFilters.insert(filter)
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Select Accounts
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text("Select Accounts")
                            .font(.subheadline)
                            .foregroundColor(Theme.Colors.textSecondary)
                            .padding(.horizontal)

                        FlowLayout(spacing: Theme.Spacing.xs) {
                            ForEach(Budget.AccountFilter.allCases, id: \.self) { filter in
                                FilterChip(
                                    title: filter.rawValue,
                                    isSelected: selectedAccountFilters.contains(filter),
                                    action: {
                                        if selectedAccountFilters.contains(filter) {
                                            selectedAccountFilters.remove(filter)
                                        } else {
                                            selectedAccountFilters.insert(filter)
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Categories & Amounts Tree View
                    categoriesAmountsSection

                    // Save Button
                    Button {
                        saveBudget()
                    } label: {
                        Text("Save Changes")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Theme.Colors.primary)
                            .foregroundColor(.white)
                            .cornerRadius(Theme.CornerRadius.md)
                    }
                    .padding(.horizontal)
                    .padding(.top, Theme.Spacing.md)

                    Spacer(minLength: Theme.Spacing.xl)
                }
                .padding(.vertical)
            }
            .background(Theme.Colors.background)
            .navigationTitle("Edit Budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        // Delete budget
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(Theme.Colors.expense)
                    }
                }
            }
            .sheet(isPresented: $showCategorySelection) {
                CategorySelectionView(
                    categories: $categories,
                    includedCategories: $includedCategories,
                    excludedCategories: $excludedCategories,
                    isPresented: $showCategorySelection,
                    apiClient: apiClient
                )
            }
        }
    }

    // MARK: - Categories & Amounts Tree View

    private var categoriesAmountsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Text("CATEGORIES & AMOUNTS")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.Colors.textSecondary)
                Spacer()
                Button {
                    showCategorySelection = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.caption)
                        Text("Add / Remove")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                            .stroke(Theme.Colors.primary, lineWidth: 1)
                    )
                    .foregroundColor(Theme.Colors.primary)
                }
            }
            .padding(.horizontal)

            let includedCats = categories.filter { includedCategories.contains($0.id) }

            if includedCats.isEmpty {
                Text("No categories added. Tap + Add / Remove to get started.")
                    .font(.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Theme.Colors.cardBackground)
                    .cornerRadius(Theme.CornerRadius.md)
                    .padding(.horizontal)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(includedCats.enumerated()), id: \.element.id) { idx, category in
                        let isExpanded = expandedCategories.contains(category.id)
                        let total = categoryTotal(for: category)

                        VStack(spacing: 0) {
                            // Category header row
                            Button {
                                if expandedCategories.contains(category.id) {
                                    expandedCategories.remove(category.id)
                                } else {
                                    expandedCategories.insert(category.id)
                                }
                            } label: {
                                HStack(spacing: Theme.Spacing.sm) {
                                    Text(category.icon)
                                        .font(.title2)
                                    Text(category.name)
                                        .font(.headline)
                                        .fontWeight(.bold)
                                        .foregroundColor(Theme.Colors.textPrimary)
                                    Spacer()
                                    if total > 0 {
                                        Text("$\(Int(total))")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(Theme.Colors.textSecondary)
                                    }
                                    Image(systemName: isExpanded ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                                        .font(.caption2)
                                        .foregroundColor(Theme.Colors.textSecondary)
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 14)
                            }

                            if isExpanded {
                                ForEach(category.subcategories) { subcategory in
                                    Divider()
                                        .padding(.leading, 24)
                                    SubcategoryAmountRow(
                                        name: subcategory.name,
                                        amount: Binding(
                                            get: {
                                                subcategoryAmounts[subcategory.id]
                                                    ?? subcategory.budgetAmount.map { String(format: "%.0f", $0) }
                                                    ?? ""
                                            },
                                            set: { subcategoryAmounts[subcategory.id] = $0 }
                                        )
                                    )
                                }

                                Divider()
                                    .padding(.leading, 24)

                                // Bottom action buttons
                                HStack(spacing: Theme.Spacing.sm) {
                                    Button {
                                        // TODO: subcategory management
                                    } label: {
                                        Text("+/- Subcategories")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(Theme.Colors.textSecondary.opacity(0.5), lineWidth: 1)
                                            )
                                            .foregroundColor(Theme.Colors.textSecondary)
                                    }
                                    Button {
                                        includedCategories.remove(category.id)
                                    } label: {
                                        Text("Remove Category")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(Theme.Colors.expense.opacity(0.8), lineWidth: 1)
                                            )
                                            .foregroundColor(Theme.Colors.expense)
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal)
                                .padding(.vertical, Theme.Spacing.sm)
                            }
                        }

                        if idx < includedCats.count - 1 {
                            Divider()
                        }
                    }
                }
                .background(Theme.Colors.cardBackground)
                .cornerRadius(Theme.CornerRadius.md)
                .padding(.horizontal)
            }
        }
    }

    private func categoryTotal(for category: BudgetCategory) -> Double {
        category.subcategories.reduce(0.0) { sum, sub in
            let amtStr = subcategoryAmounts[sub.id]
                ?? sub.budgetAmount.map { String(format: "%.0f", $0) }
                ?? ""
            return sum + (Double(amtStr) ?? 0)
        }
    }

    private var formattedStartDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d"
        return formatter.string(from: budget.startDate)
    }

    private func saveBudget() {
        guard let amount = Double(budgetAmount) else { return }

        budget.name = budgetName
        budget.amount = amount
        budget.type = selectedType
        budget.period = selectedPeriod
        budget.colorHex = selectedColor.rawValue
        budget.transactionFilters = Array(selectedTransactionFilters)
        budget.accountFilters = Array(selectedAccountFilters)
        budget.includedCategories = Array(includedCategories)
        budget.excludedCategories = Array(excludedCategories)

        // Persist subcategory amounts back to categories binding
        var updatedCategories = categories
        for i in updatedCategories.indices {
            for j in updatedCategories[i].subcategories.indices {
                let subId = updatedCategories[i].subcategories[j].id
                if let amountStr = subcategoryAmounts[subId] {
                    updatedCategories[i].subcategories[j].budgetAmount = Double(amountStr)
                }
            }
        }
        categories = updatedCategories

        isPresented = false
    }
}

// MARK: - Subcategory Amount Row

struct SubcategoryAmountRow: View {
    let name: String
    @Binding var amount: String

    var body: some View {
        HStack {
            Text(name)
                .font(.subheadline)
                .foregroundColor(Theme.Colors.textSecondary)
            Spacer()
            HStack(spacing: 2) {
                Text("$")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                TextField("0", text: $amount)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(minWidth: 40, maxWidth: 80)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Theme.Colors.textPrimary)
            .cornerRadius(8)
        }
        .padding(.horizontal)
        .padding(.leading, 8)
        .padding(.vertical, 10)
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption2)
                }
                Text(title)
                    .font(.subheadline)
            }
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, Theme.Spacing.xs)
            .background(isSelected ? Theme.Colors.primary : Theme.Colors.cardBackground)
            .foregroundColor(isSelected ? .white : Theme.Colors.textPrimary)
            .cornerRadius(Theme.CornerRadius.sm)
        }
    }
}

// MARK: - Category Icon Button

struct CategoryIconButton: View {
    let category: BudgetCategory
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(category.icon)
                    .font(.title2)
                    .frame(width: 60, height: 60)
                    .background(
                        isSelected
                        ? category.color.opacity(0.2)
                        : Color.gray.opacity(0.1)
                    )
                    .cornerRadius(Theme.CornerRadius.md)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                            .stroke(
                                isSelected ? category.color : Color.clear,
                                lineWidth: 2
                            )
                    )

                Text(category.name)
                    .font(.caption2)
                    .foregroundColor(Theme.Colors.textPrimary)
                    .lineLimit(1)
                    .frame(width: 60)
            }
        }
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.frames[index].minX, y: bounds.minY + result.frames[index].minY), proposal: .unspecified)
        }
    }

    struct FlowResult {
        var frames: [CGRect] = []
        var size: CGSize = .zero

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }

                frames.append(CGRect(x: x, y: y, width: size.width, height: size.height))
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing
            }

            self.size = CGSize(width: maxWidth, height: y + lineHeight)
        }
    }
}

#Preview {
    EditBudgetView(
        budget: .constant(Budget.mockBudgets[0]),
        categories: .constant(BudgetCategory.mockCategories),
        isPresented: .constant(true),
        apiClient: APIClient()
    )
}
