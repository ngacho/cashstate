import SwiftUI

struct BudgetView: View {
    let apiClient: APIClient
    @State private var categories: [BudgetCategory] = BudgetCategory.mockCategories
    @State private var currentBudget: Budget = Budget.mockBudgets[0]
    @State private var showAllBudgets = false
    @State private var showEditBudget = false
    @State private var selectedCategory: BudgetCategory?

    var totalBudget: Double {
        categories.compactMap { $0.budgetAmount }.reduce(0, +)
    }

    var totalSpent: Double {
        categories.reduce(0) { $0 + $1.spentAmount }
    }

    var budgetRemaining: Double {
        totalBudget - totalSpent
    }

    var spentPercentage: Double {
        guard totalBudget > 0 else { return 0 }
        return min((totalSpent / totalBudget) * 100, 100)
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    // Budget Header with date navigation
                    HStack {
                        Button {
                            // Previous month
                        } label: {
                            Image(systemName: "chevron.left")
                                .foregroundColor(Theme.Colors.textPrimary)
                        }

                        Spacer()

                        VStack(spacing: 2) {
                            Text(currentMonthYear)
                                .font(.headline)
                                .foregroundColor(Theme.Colors.textPrimary)
                            Text("\(daysRemainingText)")
                                .font(.caption)
                                .foregroundColor(Theme.Colors.textSecondary)
                        }

                        Spacer()

                        Button {
                            // Next month
                        } label: {
                            Image(systemName: "chevron.right")
                                .foregroundColor(Theme.Colors.textPrimary)
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.top, Theme.Spacing.sm)

                    // Budget Overview Card
                    VStack(spacing: Theme.Spacing.md) {
                        HStack {
                            Text("Budget")
                                .font(.headline)
                                .foregroundColor(Theme.Colors.textPrimary)
                            Spacer()
                            Button {
                                showAllBudgets = true
                            } label: {
                                Text("All Budgets")
                                    .font(.subheadline)
                                    .foregroundColor(Theme.Colors.primary)
                            }
                        }

                        // Amount and status
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("$\(String(format: "%.2f", budgetRemaining))")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(budgetRemaining >= 0 ? Theme.Colors.income : Theme.Colors.expense)
                            Text("left")
                                .font(.headline)
                                .foregroundColor(Theme.Colors.textSecondary)
                        }

                        Text("-$\(String(format: "%.2f", totalSpent)) spent this month")
                            .font(.subheadline)
                            .foregroundColor(Theme.Colors.textSecondary)

                        // Progress bar
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.gray.opacity(0.15))
                                    .frame(height: 8)

                                RoundedRectangle(cornerRadius: 4)
                                    .fill(spentPercentage > 90 ? Theme.Colors.expense : Theme.Colors.primary)
                                    .frame(width: geometry.size.width * (spentPercentage / 100), height: 8)
                            }
                        }
                        .frame(height: 8)
                    }
                    .padding(Theme.Spacing.md)
                    .background(Theme.Colors.cardBackground)
                    .cornerRadius(Theme.CornerRadius.md)
                    .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
                    .padding(.horizontal, Theme.Spacing.md)

                    // Categories Section with Donut Chart
                    VStack(spacing: Theme.Spacing.md) {
                        HStack {
                            Text("Categories")
                                .font(.headline)
                                .foregroundColor(Theme.Colors.textPrimary)
                            Spacer()
                            Button {
                                showEditBudget = true
                            } label: {
                                Text("Edit Budget")
                                    .font(.subheadline)
                                    .foregroundColor(Theme.Colors.primary)
                            }
                        }

                        // Donut Chart
                        ZStack {
                            BudgetDonutChart(
                                categories: categories.filter { $0.budgetAmount != nil },
                                total: totalSpent
                            )
                            .frame(height: 220)

                            // Total in center
                            VStack(spacing: 4) {
                                Text("Expense")
                                    .font(.caption)
                                    .foregroundColor(Theme.Colors.textSecondary)
                                Text("$\(String(format: "%.2f", totalSpent))")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(Theme.Colors.textPrimary)
                            }
                        }
                        .padding(.vertical, Theme.Spacing.sm)

                        // Category list with expandable subcategories
                        VStack(spacing: Theme.Spacing.sm) {
                            ForEach($categories) { $category in
                                ExpandableCategoryCard(category: $category)
                            }
                        }
                    }
                    .padding(Theme.Spacing.md)
                    .background(Theme.Colors.cardBackground)
                    .cornerRadius(Theme.CornerRadius.md)
                    .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
                    .padding(.horizontal, Theme.Spacing.md)

                    Spacer(minLength: Theme.Spacing.lg)
                }
            }
            .background(Theme.Colors.background)
            .navigationTitle("Budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showEditBudget = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(Theme.Colors.primary)
                    }
                }
            }
            .sheet(isPresented: $showEditBudget) {
                EditBudgetView(
                    budget: $currentBudget,
                    categories: $categories,
                    isPresented: $showEditBudget
                )
            }
            .sheet(isPresented: $showAllBudgets) {
                AllBudgetsView(isPresented: $showAllBudgets)
            }
            .sheet(item: $selectedCategory) { category in
                CategoryDetailView(category: category, isPresented: .init(
                    get: { selectedCategory != nil },
                    set: { if !$0 { selectedCategory = nil } }
                ))
            }
        }
    }

    private var currentMonthYear: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: Date())
    }

    private var daysRemainingText: String {
        let remaining = currentBudget.daysRemaining
        return remaining > 0 ? "\(remaining) days left" : "Period ended"
    }
}

// MARK: - Budget Category Row

struct BudgetCategoryRow: View {
    let category: BudgetCategory

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Icon
            Text(category.icon)
                .font(.title2)
                .frame(width: 44, height: 44)
                .background(category.color.color.opacity(0.15))
                .clipShape(Circle())

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(category.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(Theme.Colors.textPrimary)

                if let budget = category.budgetAmount {
                    HStack(spacing: 4) {
                        Text("$\(String(format: "%.0f", category.spentAmount))")
                            .font(.caption)
                            .foregroundColor(category.isOverBudget ? Theme.Colors.expense : Theme.Colors.textSecondary)
                        Text("of $\(String(format: "%.0f", budget))")
                            .font(.caption)
                            .foregroundColor(Theme.Colors.textSecondary)
                    }

                    // Progress bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.gray.opacity(0.15))
                                .frame(height: 4)

                            RoundedRectangle(cornerRadius: 2)
                                .fill(category.isOverBudget ? Theme.Colors.expense : category.color.color)
                                .frame(width: geometry.size.width * min(category.percentageUsed / 100, 1.0), height: 4)
                        }
                    }
                    .frame(height: 4)
                } else {
                    Text("$\(String(format: "%.2f", category.spentAmount)) spent")
                        .font(.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                }
            }

            Spacer()

            // Percentage or amount
            if let budget = category.budgetAmount {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(category.percentageUsed))%")
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(category.isOverBudget ? Theme.Colors.expense : Theme.Colors.textPrimary)
                    if category.isOverBudget {
                        Text("Over")
                            .font(.caption2)
                            .foregroundColor(Theme.Colors.expense)
                    }
                }
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(Theme.Colors.textSecondary)
        }
        .padding(.vertical, Theme.Spacing.xs)
    }
}

// MARK: - Budget Donut Chart

struct BudgetDonutChart: View {
    let categories: [BudgetCategory]
    let total: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(Array(categories.enumerated()), id: \.element.id) { index, category in
                    BudgetDonutSlice(
                        startAngle: startAngle(for: index),
                        endAngle: endAngle(for: index),
                        color: category.color.color
                    )
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.width)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    func startAngle(for index: Int) -> Angle {
        let previousTotal = categories.prefix(index).reduce(0.0) { $0 + $1.spentAmount }
        return Angle(degrees: (previousTotal / total) * 360 - 90)
    }

    func endAngle(for index: Int) -> Angle {
        let currentTotal = categories.prefix(index + 1).reduce(0.0) { $0 + $1.spentAmount }
        return Angle(degrees: (currentTotal / total) * 360 - 90)
    }
}

struct BudgetDonutSlice: View {
    let startAngle: Angle
    let endAngle: Angle
    let color: Color

    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
                let radius = min(geometry.size.width, geometry.size.height) / 2
                let innerRadius = radius * 0.65 // Donut hole

                path.addArc(
                    center: center,
                    radius: radius,
                    startAngle: startAngle,
                    endAngle: endAngle,
                    clockwise: false
                )

                let endRad = endAngle.radians
                path.addLine(to: CGPoint(
                    x: center.x + innerRadius * CGFloat(cos(endRad)),
                    y: center.y + innerRadius * CGFloat(sin(endRad))
                ))

                path.addArc(
                    center: center,
                    radius: innerRadius,
                    startAngle: endAngle,
                    endAngle: startAngle,
                    clockwise: true
                )

                path.closeSubpath()
            }
            .fill(color)
        }
    }
}

// MARK: - All Budgets View (Stub)

struct AllBudgetsView: View {
    @Binding var isPresented: Bool
    @State private var budgets: [Budget] = Budget.mockBudgets

    var body: some View {
        NavigationView {
            List {
                ForEach(budgets) { budget in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(budget.name)
                            .font(.headline)
                        Text("$\(String(format: "%.2f", budget.amount)) / \(budget.period.rawValue)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("All Budgets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

// MARK: - Category Detail View (Stub)

struct CategoryDetailView: View {
    let category: BudgetCategory
    @Binding var isPresented: Bool

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    // Category header
                    HStack {
                        Text(category.icon)
                            .font(.system(size: 60))
                            .frame(width: 80, height: 80)
                            .background(category.color.color.opacity(0.15))
                            .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 4) {
                            Text(category.name)
                                .font(.title2)
                                .fontWeight(.bold)
                            if let budget = category.budgetAmount {
                                Text("$\(String(format: "%.2f", category.spentAmount)) of $\(String(format: "%.2f", budget))")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()
                    }
                    .padding()

                    // Subcategories
                    if !category.subcategories.isEmpty {
                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            Text("Subcategories")
                                .font(.headline)
                                .padding(.horizontal)

                            ForEach(category.subcategories) { subcategory in
                                HStack {
                                    Text(subcategory.icon)
                                        .font(.title3)
                                        .frame(width: 36, height: 36)
                                        .background(category.color.color.opacity(0.15))
                                        .clipShape(Circle())

                                    Text(subcategory.name)
                                        .font(.body)

                                    Spacer()

                                    Text("$\(String(format: "%.2f", subcategory.spentAmount))")
                                        .font(.body)
                                        .fontWeight(.semibold)
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                                .background(Theme.Colors.cardBackground)
                            }
                        }
                        .padding(.horizontal)
                    }

                    Spacer()
                }
            }
            .background(Theme.Colors.background)
            .navigationTitle("Category Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

// MARK: - Expandable Category Card

struct ExpandableCategoryCard: View {
    @Binding var category: BudgetCategory
    @State private var isExpanded: Bool = false
    @State private var showEditCategoryBudget: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Main category row
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: Theme.Spacing.md) {
                    // Icon
                    Text(category.icon)
                        .font(.title2)
                        .frame(width: 44, height: 44)
                        .background(category.color.color.opacity(0.15))
                        .clipShape(Circle())

                    // Info
                    VStack(alignment: .leading, spacing: 4) {
                        Text(category.name)
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(Theme.Colors.textPrimary)

                        if let budget = category.budgetAmount {
                            HStack(spacing: 4) {
                                Text("$\(String(format: "%.0f", category.spentAmount))")
                                    .font(.caption)
                                    .foregroundColor(category.isOverBudget ? Theme.Colors.expense : Theme.Colors.textSecondary)
                                Text("of $\(String(format: "%.0f", budget))")
                                    .font(.caption)
                                    .foregroundColor(Theme.Colors.textSecondary)
                            }
                        } else {
                            Text("$\(String(format: "%.2f", category.spentAmount)) spent")
                                .font(.caption)
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                    }

                    Spacer()

                    // Percentage or amount with edit button
                    HStack(spacing: Theme.Spacing.xs) {
                        if let budget = category.budgetAmount {
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(Int(category.percentageUsed))%")
                                    .font(.body)
                                    .fontWeight(.semibold)
                                    .foregroundColor(category.isOverBudget ? Theme.Colors.expense : Theme.Colors.textPrimary)
                                if category.isOverBudget {
                                    Text("Over")
                                        .font(.caption2)
                                        .foregroundColor(Theme.Colors.expense)
                                }
                            }
                        } else {
                            Text("Set Budget")
                                .font(.caption)
                                .foregroundColor(category.color.color)
                        }

                        // Edit budget button
                        Button {
                            showEditCategoryBudget = true
                        } label: {
                            Image(systemName: "pencil.circle.fill")
                                .font(.title3)
                                .foregroundColor(category.color.color.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                    }

                    // Expand indicator
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(.vertical, Theme.Spacing.xs)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Progress bar
            if let budget = category.budgetAmount {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.gray.opacity(0.15))
                            .frame(height: 4)

                        RoundedRectangle(cornerRadius: 2)
                            .fill(category.isOverBudget ? Theme.Colors.expense : category.color.color)
                            .frame(width: geometry.size.width * min(category.percentageUsed / 100, 1.0), height: 4)
                    }
                }
                .frame(height: 4)
                .padding(.top, 4)
            }

            // Expandable subcategories section
            if isExpanded && !category.subcategories.isEmpty {
                VStack(spacing: Theme.Spacing.xs) {
                    Divider()
                        .padding(.vertical, Theme.Spacing.xs)

                    // Subcategories header
                    HStack {
                        Text("Subcategories")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(Theme.Colors.textSecondary)
                            .textCase(.uppercase)
                        Spacer()
                        Text("\(category.subcategories.count)")
                            .font(.caption2)
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                    .padding(.horizontal, Theme.Spacing.xs)

                    // Subcategory list
                    ForEach($category.subcategories) { $subcategory in
                        SubcategoryRow(
                            subcategory: $subcategory,
                            categoryColor: category.color.color
                        )
                    }

                    // Add subcategory button
                    Button {
                        // Add new subcategory
                    } label: {
                        HStack(spacing: Theme.Spacing.xs) {
                            Image(systemName: "plus.circle.fill")
                                .font(.caption)
                            Text("Add Subcategory")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(category.color.color)
                        .padding(.vertical, Theme.Spacing.xs)
                    }
                }
                .padding(.top, Theme.Spacing.sm)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .sheet(isPresented: $showEditCategoryBudget) {
            CategoryBudgetView(
                category: $category,
                isPresented: $showEditCategoryBudget
            )
        }
    }
}

// MARK: - Subcategory Row

struct SubcategoryRow: View {
    @Binding var subcategory: BudgetSubcategory
    let categoryColor: Color
    @State private var showEditBudget = false

    var percentageUsed: Double {
        guard let budget = subcategory.budgetAmount, budget > 0 else { return 0 }
        return min((subcategory.spentAmount / budget) * 100, 100)
    }

    var isOverBudget: Bool {
        guard let budget = subcategory.budgetAmount else { return false }
        return subcategory.spentAmount > budget
    }

    var body: some View {
        VStack(spacing: 4) {
            Button {
                showEditBudget = true
            } label: {
                HStack(spacing: Theme.Spacing.sm) {
                    // Icon
                    Text(subcategory.icon)
                        .font(.body)
                        .frame(width: 32, height: 32)
                        .background(categoryColor.opacity(0.1))
                        .clipShape(Circle())

                    // Info
                    VStack(alignment: .leading, spacing: 2) {
                        Text(subcategory.name)
                            .font(.subheadline)
                            .foregroundColor(Theme.Colors.textPrimary)

                        if let budget = subcategory.budgetAmount {
                            Text("$\(String(format: "%.0f", subcategory.spentAmount)) of $\(String(format: "%.0f", budget))")
                                .font(.caption2)
                                .foregroundColor(isOverBudget ? Theme.Colors.expense : Theme.Colors.textSecondary)
                        } else {
                            Text("$\(String(format: "%.2f", subcategory.spentAmount)) spent")
                                .font(.caption2)
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                    }

                    Spacer()

                    // Budget indicator
                    if subcategory.budgetAmount != nil {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(Int(percentageUsed))%")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(isOverBudget ? Theme.Colors.expense : Theme.Colors.textPrimary)
                            if isOverBudget {
                                Text("Over")
                                    .font(.caption2)
                                    .foregroundColor(Theme.Colors.expense)
                            }
                        }
                    } else {
                        Text("Set Budget")
                            .font(.caption)
                            .foregroundColor(categoryColor)
                    }

                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundColor(Theme.Colors.textSecondary)
                }
                .padding(.horizontal, Theme.Spacing.xs)
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)

            // Progress bar for subcategory
            if let budget = subcategory.budgetAmount {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.gray.opacity(0.1))
                            .frame(height: 3)

                        RoundedRectangle(cornerRadius: 2)
                            .fill(isOverBudget ? Theme.Colors.expense : categoryColor)
                            .frame(width: geometry.size.width * min(percentageUsed / 100, 1.0), height: 3)
                    }
                }
                .frame(height: 3)
                .padding(.horizontal, Theme.Spacing.xs)
            }
        }
        .background(Theme.Colors.background.opacity(0.5))
        .cornerRadius(Theme.CornerRadius.sm)
        .sheet(isPresented: $showEditBudget) {
            SubcategoryBudgetView(
                subcategory: $subcategory,
                categoryColor: categoryColor,
                isPresented: $showEditBudget
            )
        }
    }
}

#Preview {
    BudgetView(apiClient: APIClient())
}
