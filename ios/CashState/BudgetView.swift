import SwiftUI

struct BudgetView: View {
    let apiClient: APIClient
    @State private var categories: [BudgetCategory] = []
    @State private var showAllBudgets = false
    @State private var showEditBudget = false
    @State private var selectedCategory: BudgetCategory?
    @State private var navigationPath = NavigationPath()

    // Categorization state
    @State private var uncategorizedTransactions: [CategorizableTransaction] = []
    @State private var showManualCategorization = false
    @State private var showAICategorization = false

    // Quick add category
    @State private var showAddCategory = false

    // Loading state
    @State private var isLoading = true
    @State private var loadError: String?

    // Filter toggle
    @State private var showIncomeInBudget = false

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
        NavigationStack(path: $navigationPath) {
            Group {
                if isLoading {
                    ProgressView("Loading...")
                } else if categories.isEmpty {
                    // Show empty state for new users
                    BudgetEmptyStateView(
                        apiClient: apiClient,
                        isLoading: $isLoading,
                        error: $loadError
                    ) {
                        Task { await loadData() }
                    }
                } else {
                    // Show main budget UI
                    budgetContentView
                }
            }
            .navigationTitle("Budget")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: CategoryTransactionsDestination.self) { destination in
                CategoryTransactionsNavigableView(
                    category: destination.category,
                    subcategory: destination.subcategory,
                    apiClient: apiClient
                )
            }
            .toolbar {
                if !categories.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showEditBudget = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(Theme.Colors.primary)
                        }
                    }
                }
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
            .sheet(isPresented: $showManualCategorization) {
                SwipeableCategorization(
                    isPresented: $showManualCategorization,
                    transactions: $uncategorizedTransactions,
                    categories: categories,
                    apiClient: apiClient
                )
            }
            .onChange(of: showManualCategorization) { oldValue, newValue in
                // Reload data when categorization sheet is dismissed
                if oldValue == true && newValue == false {
                    Task { await loadData() }
                }
            }
            .sheet(isPresented: $showAICategorization) {
                AICategorization(
                    isPresented: $showAICategorization,
                    transactions: $uncategorizedTransactions,
                    categories: categories,
                    apiClient: apiClient
                )
            }
            .onChange(of: showAICategorization) { oldValue, newValue in
                // Reload data when AI categorization sheet is dismissed
                if oldValue == true && newValue == false {
                    Task { await loadData() }
                }
            }
            .sheet(isPresented: $showAddCategory) {
                AddCategoryView(isPresented: $showAddCategory) { newCategory in
                    categories.append(newCategory)
                }
            }
        }
        .task {
            await loadData()
        }
    }

    private var budgetContentView: some View {
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

                    // Uncategorized Transactions Card
                    if !uncategorizedTransactions.isEmpty {
                        UncategorizedTransactionsCard(
                            uncategorizedCount: uncategorizedTransactions.count,
                            showManualCategorization: $showManualCategorization,
                            showAICategorization: $showAICategorization
                        )
                        .padding(.horizontal, Theme.Spacing.md)
                    }

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
                            // Toggle for including income
                            Menu {
                                Button(action: {
                                    showIncomeInBudget.toggle()
                                    Task { await loadData() }
                                }) {
                                    Label(
                                        showIncomeInBudget ? "Hide Income" : "Show Income",
                                        systemImage: showIncomeInBudget ? "eye.slash" : "eye"
                                    )
                                }
                                Button {
                                    showEditBudget = true
                                } label: {
                                    Label("Edit Budget", systemImage: "pencil")
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .font(.title3)
                                    .foregroundColor(Theme.Colors.primary)
                            }
                        }

                        // Income indicator (when enabled)
                        if showIncomeInBudget {
                            HStack(spacing: 8) {
                                Image(systemName: "info.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                Text("Income included in totals")
                                    .font(.caption)
                                    .foregroundColor(Theme.Colors.textSecondary)
                            }
                            .padding(.horizontal, Theme.Spacing.sm)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(Theme.CornerRadius.sm)
                        }

                        // Donut Chart
                        InteractiveBudgetDonutView(
                            categories: categories.filter { $0.budgetAmount != nil },
                            totalSpent: totalSpent,
                            totalBudget: totalBudget
                        )
                        .padding(.vertical, Theme.Spacing.sm)

                        // Category list with expandable subcategories
                        VStack(spacing: Theme.Spacing.sm) {
                            ForEach($categories) { $category in
                                ExpandableCategoryCard(category: $category, apiClient: apiClient)
                            }

                            // Add Category button
                            Button {
                                showAddCategory = true
                            } label: {
                                HStack(spacing: Theme.Spacing.sm) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.title3)
                                        .foregroundColor(Theme.Colors.primary)

                                    Text("Add Category")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(Theme.Colors.textPrimary)

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(Theme.Colors.textSecondary)
                                }
                                .padding(.vertical, Theme.Spacing.md)
                                .padding(.horizontal, Theme.Spacing.sm)
                                .background(Theme.Colors.background)
                                .cornerRadius(Theme.CornerRadius.sm)
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
        }

    private func loadData() async {
        isLoading = true
        loadError = nil

        do {
            // Fetch categories tree
            let categoriesTree = try await apiClient.fetchCategoriesTree()

            // Fetch budgets
            let budgets = try await apiClient.fetchBudgets()

            // Fetch transactions for the current month to calculate spending
            let calendar = Calendar.current
            let now = Date()
            let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
            let startTimestamp = Int(startOfMonth.timeIntervalSince1970)

            let transactions = try await apiClient.listSimplefinTransactions(
                dateFrom: startTimestamp,
                dateTo: nil,
                limit: 1000,
                offset: 0
            )

            // Build category spending map
            // IMPORTANT: Only count expenses (negative amounts) in budget tracking
            // Income/credits (positive amounts) are excluded unless toggle is enabled
            var categorySpending: [String: Double] = [:]
            var subcategorySpending: [String: Double] = [:]
            var subcategoryTransactionCount: [String: Int] = [:]

            for transaction in transactions {
                // Skip income/credits unless toggle is enabled
                let isExpense = transaction.amount < 0
                if !isExpense && !showIncomeInBudget {
                    continue
                }

                let amount = abs(transaction.amount)

                if let categoryId = transaction.categoryId {
                    categorySpending[categoryId, default: 0] += amount

                    if let subcategoryId = transaction.subcategoryId {
                        subcategorySpending[subcategoryId, default: 0] += amount
                        subcategoryTransactionCount[subcategoryId, default: 0] += 1
                    }
                }
            }

            // Build budget map
            var budgetMap: [String: Double] = [:]
            for budget in budgets {
                budgetMap[budget.categoryId] = budget.amount
            }

            // Convert to BudgetCategory (filter out non-expense categories)
            self.categories = categoriesTree
                .filter { cat in
                    // Only include expense categories in budget view
                    // Income and Transfers should not appear in expense budgeting
                    let categoryType = cat.type ?? "expense"  // Default to expense if not set
                    return categoryType == "expense"
                }
                .map { cat in
                let subcategories = cat.subcategories.map { sub in
                    BudgetSubcategory(
                        id: sub.id,
                        name: sub.name,
                        icon: sub.icon,
                        budgetAmount: nil, // Subcategories don't have budgets yet
                        spentAmount: subcategorySpending[sub.id] ?? 0,
                        transactionCount: subcategoryTransactionCount[sub.id] ?? 0
                    )
                }

                return BudgetCategory(
                    id: cat.id,
                    name: cat.name,
                    icon: cat.icon,
                    colorHex: cat.color,  // Use hex color directly from database
                    type: .expense, // Default to expense for now
                    subcategories: subcategories,
                    budgetAmount: budgetMap[cat.id],
                    spentAmount: categorySpending[cat.id] ?? 0
                )
            }

            // Load uncategorized transactions (transactions without category_id)
            // Only show uncategorized EXPENSES by default (income/credits excluded unless toggle is on)
            self.uncategorizedTransactions = transactions
                .filter { tx in
                    let hasNoCategory = tx.categoryId == nil
                    let isExpense = tx.amount < 0
                    return hasNoCategory && (isExpense || showIncomeInBudget)
                }
                .map { tx in
                    CategorizableTransaction(
                        id: tx.id,
                        merchantName: tx.payee ?? tx.description,
                        amount: tx.amount,
                        date: Date(timeIntervalSince1970: TimeInterval(tx.postedDate)),
                        description: tx.description,
                        categoryId: nil,
                        subcategoryId: nil
                    )
                }

            isLoading = false
        } catch {
            loadError = error.localizedDescription
            isLoading = false
        }
    }

    private var currentMonthYear: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: Date())
    }

    private var daysRemainingText: String {
        let calendar = Calendar.current
        let now = Date()
        let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: calendar.date(from: calendar.dateComponents([.year, .month], from: now))!)!
        let remaining = calendar.dateComponents([.day], from: now, to: endOfMonth).day ?? 0
        return remaining > 0 ? "\(remaining) days left" : "Period ended"
    }
}

// MARK: - Budget Category Row

struct BudgetCategoryRow: View {
    let category: BudgetCategory

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Icon with colored border
            Text(category.icon)
                .font(.title2)
                .frame(width: 44, height: 44)
                .overlay(
                    Circle()
                        .strokeBorder(category.color, lineWidth: 2)
                )

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
                                .fill(category.isOverBudget ? Theme.Colors.expense : category.color)
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
            if category.budgetAmount != nil {
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

// MARK: - Interactive Budget Donut View

struct InteractiveBudgetDonutView: View {
    let categories: [BudgetCategory]
    let totalSpent: Double
    let totalBudget: Double

    @State private var selectedCategoryIndex: Int?
    @State private var showBudgetRing = false

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            ZStack {
                BudgetDonutChart(
                    categories: categories,
                    total: totalSpent,
                    selectedIndex: selectedCategoryIndex,
                    showBudgetRing: showBudgetRing,
                    onTap: { index in
                        withAnimation(.spring(response: 0.3)) {
                            if selectedCategoryIndex == index {
                                selectedCategoryIndex = nil
                            } else {
                                selectedCategoryIndex = index
                            }
                        }
                    }
                )
                .frame(height: 280)  // Bigger donut

                // Center content - changes based on selection
                VStack(spacing: 4) {
                    if let selectedIndex = selectedCategoryIndex,
                       selectedIndex < categories.count {
                        let category = categories[selectedIndex]
                        Text(category.icon)
                            .font(.system(size: 32))
                        Text(category.name)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(Theme.Colors.textSecondary)

                        // Show budget info if budget ring is visible
                        if showBudgetRing, let budget = category.budgetAmount {
                            Text("$\(String(format: "%.2f", category.spentAmount))")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(category.color)
                            Text("of $\(String(format: "%.0f", budget)) budget")
                                .font(.caption2)
                                .foregroundColor(Theme.Colors.textSecondary)

                            let percentage = (category.spentAmount / budget) * 100
                            Text("\(Int(percentage))% used")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(percentage > 100 ? Theme.Colors.expense :
                                               percentage > 90 ? .orange : Theme.Colors.income)
                        } else {
                            // Just spending info
                            Text("$\(String(format: "%.2f", category.spentAmount))")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(category.color)
                            Text("\(Int((category.spentAmount / totalSpent) * 100))% of spending")
                                .font(.caption2)
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                    } else {
                        Text("Spending")
                            .font(.caption)
                            .foregroundColor(Theme.Colors.textSecondary)
                        Text("$\(String(format: "%.2f", totalSpent))")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(Theme.Colors.textPrimary)
                        Text("of $\(String(format: "%.0f", totalBudget))")
                            .font(.caption2)
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                }
                .multilineTextAlignment(.center)
            }

            // Controls and legend
            HStack(spacing: Theme.Spacing.lg) {
                // Toggle for budget ring
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        showBudgetRing.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: showBudgetRing ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(showBudgetRing ? Theme.Colors.primary : Theme.Colors.textSecondary)
                        Text("Show Budget")
                            .font(.caption2)
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                }

                Spacer()

                // Tap instruction
                if selectedCategoryIndex == nil {
                    Text("Tap segments for details")
                        .font(.caption2)
                        .foregroundColor(Theme.Colors.textSecondary.opacity(0.7))
                        .italic()
                } else {
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            selectedCategoryIndex = nil
                        }
                    } label: {
                        Text("Clear selection")
                            .font(.caption2)
                            .foregroundColor(Theme.Colors.primary)
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.sm)
        }
    }
}

// MARK: - Budget Donut Chart

struct BudgetDonutChart: View {
    let categories: [BudgetCategory]
    let total: Double
    var selectedIndex: Int?
    var showBudgetRing: Bool
    var onTap: ((Int) -> Void)?

    var totalBudget: Double {
        categories.compactMap { $0.budgetAmount }.reduce(0, +)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Outer ring - Spending (wider)
                ForEach(Array(categories.enumerated()), id: \.element.id) { index, category in
                    BudgetDonutSlice(
                        startAngle: spendingStartAngle(for: index),
                        endAngle: spendingEndAngle(for: index),
                        color: category.color,
                        innerRadiusRatio: 0.50,  // Bigger donut hole
                        outerRadiusRatio: 1.0,
                        isSelected: selectedIndex == index,
                        isAnySelected: selectedIndex != nil
                    )
                    .onTapGesture {
                        onTap?(index)
                    }
                }

                // Outer ring - Budget allocation (narrow wrapper) - toggleable
                if showBudgetRing && totalBudget > 0 {
                    ForEach(Array(categories.enumerated()), id: \.element.id) { index, category in
                        if category.budgetAmount != nil {
                            BudgetDonutSlice(
                                startAngle: budgetStartAngle(for: index),
                                endAngle: budgetEndAngle(for: index),
                                color: category.color.opacity(0.4),
                                innerRadiusRatio: 1.02,  // Just outside spending ring
                                outerRadiusRatio: 1.08,  // Super narrow ring
                                isSelected: selectedIndex == index,  // Highlight if category is selected
                                isAnySelected: selectedIndex != nil
                            )
                        }
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.width)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    // Spending angles (outer ring)
    func spendingStartAngle(for index: Int) -> Angle {
        let previousTotal = categories.prefix(index).reduce(0.0) { $0 + $1.spentAmount }
        return Angle(degrees: (previousTotal / total) * 360 - 90)
    }

    func spendingEndAngle(for index: Int) -> Angle {
        let currentTotal = categories.prefix(index + 1).reduce(0.0) { $0 + $1.spentAmount }
        return Angle(degrees: (currentTotal / total) * 360 - 90)
    }

    // Budget allocation angles (inner ring)
    func budgetStartAngle(for index: Int) -> Angle {
        let previousTotal = categories.prefix(index).compactMap { $0.budgetAmount }.reduce(0.0, +)
        return Angle(degrees: (previousTotal / totalBudget) * 360 - 90)
    }

    func budgetEndAngle(for index: Int) -> Angle {
        let currentTotal = categories.prefix(index + 1).compactMap { $0.budgetAmount }.reduce(0.0, +)
        return Angle(degrees: (currentTotal / totalBudget) * 360 - 90)
    }
}

struct BudgetDonutSlice: View {
    let startAngle: Angle
    let endAngle: Angle
    let color: Color
    let innerRadiusRatio: CGFloat
    let outerRadiusRatio: CGFloat
    let isSelected: Bool
    let isAnySelected: Bool

    // Calculate effective color based on selection state
    var effectiveColor: Color {
        if isSelected {
            return color  // Full brightness when selected
        } else if isAnySelected {
            return color.opacity(0.3)  // Dimmed when another is selected
        } else {
            return color  // Normal when nothing selected
        }
    }

    // Scale factor for selected slice
    var scaleFactor: CGFloat {
        isSelected ? 1.05 : 1.0
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Main slice
                Path { path in
                    let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    let maxRadius = min(geometry.size.width, geometry.size.height) / 2
                    let outerRadius = maxRadius * outerRadiusRatio * scaleFactor
                    let innerRadius = maxRadius * innerRadiusRatio

                    path.addArc(
                        center: center,
                        radius: outerRadius,
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
                .fill(effectiveColor)

                // Glow effect when selected
                if isSelected {
                    Path { path in
                        let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
                        let maxRadius = min(geometry.size.width, geometry.size.height) / 2
                        let outerRadius = maxRadius * outerRadiusRatio * scaleFactor
                        let innerRadius = maxRadius * innerRadiusRatio

                        path.addArc(
                            center: center,
                            radius: outerRadius,
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
                    .stroke(color, lineWidth: 3)
                    .shadow(color: color.opacity(0.5), radius: 8, x: 0, y: 0)
                }
            }
        }
    }
}

// MARK: - All Budgets View (Stub)

struct AllBudgetsView: View {
    @Binding var isPresented: Bool

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "chart.bar.doc.horizontal")
                    .font(.system(size: 60))
                    .foregroundColor(.secondary)
                Text("Budget history coming soon")
                    .font(.headline)
                Text("You'll be able to view and compare past budgets here")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
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
                            .overlay(
                                Circle()
                                    .strokeBorder(category.color, lineWidth: 3)
                            )

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
                                        .overlay(
                                            Circle()
                                                .strokeBorder(category.color, lineWidth: 1.5)
                                        )

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

// Helper for navigation
struct CategoryTransactionsDestination: Hashable {
    let category: BudgetCategory
    let subcategory: BudgetSubcategory?

    func hash(into hasher: inout Hasher) {
        hasher.combine(category.id)
        hasher.combine(subcategory?.id)
    }

    static func == (lhs: CategoryTransactionsDestination, rhs: CategoryTransactionsDestination) -> Bool {
        lhs.category.id == rhs.category.id && lhs.subcategory?.id == rhs.subcategory?.id
    }
}

struct ExpandableCategoryCard: View {
    @Binding var category: BudgetCategory
    let apiClient: APIClient
    @State private var isExpanded: Bool = false
    @State private var showEditCategoryBudget: Bool = false
    @State private var showAddSubcategory: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Main category row
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: Theme.Spacing.md) {
                    // Icon with colored border
                    Text(category.icon)
                        .font(.title2)
                        .frame(width: 44, height: 44)
                        .overlay(
                            Circle()
                                .strokeBorder(category.color, lineWidth: 2)
                        )

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
                        if category.budgetAmount != nil {
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
                                .foregroundColor(category.color)
                        }

                        // Edit budget button
                        Button {
                            showEditCategoryBudget = true
                        } label: {
                            Image(systemName: "pencil.circle.fill")
                                .font(.title3)
                                .foregroundColor(category.color.opacity(0.7))
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
            if category.budgetAmount != nil {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.gray.opacity(0.15))
                            .frame(height: 4)

                        RoundedRectangle(cornerRadius: 2)
                            .fill(category.isOverBudget ? Theme.Colors.expense : category.color)
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
                            category: category,
                            subcategory: $subcategory,
                            categoryColor: category.color,
                            apiClient: apiClient
                        )
                    }

                    // Add subcategory button
                    Button {
                        showAddSubcategory = true
                    } label: {
                        HStack(spacing: Theme.Spacing.xs) {
                            Image(systemName: "plus.circle.fill")
                                .font(.caption)
                            Text("Add Subcategory")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(category.color)
                        .padding(.vertical, Theme.Spacing.xs)
                    }

                    // View all transactions button
                    NavigationLink(value: CategoryTransactionsDestination(category: category, subcategory: nil)) {
                        HStack(spacing: Theme.Spacing.xs) {
                            Image(systemName: "list.bullet.rectangle")
                                .font(.caption)
                            Text("View All Transactions")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(Theme.Colors.primary)
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
        .sheet(isPresented: $showAddSubcategory) {
            AddSubcategoryView(
                parentCategory: category,
                isPresented: $showAddSubcategory
            ) { newSubcategory in
                category.subcategories.append(newSubcategory)
            }
        }
    }
}

// MARK: - Subcategory Row

struct SubcategoryRow: View {
    let category: BudgetCategory
    @Binding var subcategory: BudgetSubcategory
    let categoryColor: Color
    let apiClient: APIClient
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
            HStack(spacing: Theme.Spacing.sm) {
                NavigationLink(value: CategoryTransactionsDestination(category: category, subcategory: subcategory)) {
                    HStack(spacing: Theme.Spacing.sm) {
                    // Icon with parent category colored border
                    Text(subcategory.icon)
                        .font(.body)
                        .frame(width: 32, height: 32)
                        .overlay(
                            Circle()
                                .strokeBorder(categoryColor, lineWidth: 1.5)
                        )

                    // Info
                    VStack(alignment: .leading, spacing: 2) {
                        Text(subcategory.name)
                            .font(.subheadline)
                            .foregroundColor(Theme.Colors.textPrimary)

                        HStack(spacing: 4) {
                            if let budget = subcategory.budgetAmount {
                                Text("$\(String(format: "%.0f", subcategory.spentAmount)) of $\(String(format: "%.0f", budget))")
                                    .font(.caption2)
                                    .foregroundColor(isOverBudget ? Theme.Colors.expense : Theme.Colors.textSecondary)
                            } else {
                                Text("$\(String(format: "%.2f", subcategory.spentAmount)) spent")
                                    .font(.caption2)
                                    .foregroundColor(Theme.Colors.textSecondary)
                            }

                            Text("•")
                                .font(.caption2)
                                .foregroundColor(Theme.Colors.textSecondary)

                            Text("\(subcategory.transactionCount) transaction\(subcategory.transactionCount == 1 ? "" : "s")")
                                .font(.caption2)
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                    }

                    }
                }
                .buttonStyle(.plain)

                Spacer()

                // Budget edit button
                Button {
                    showEditBudget = true
                } label: {
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
                }
                .buttonStyle(.plain)

                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundColor(Theme.Colors.textSecondary)
            }
            .padding(.horizontal, Theme.Spacing.xs)
            .padding(.vertical, 4)

            // Progress bar for subcategory
            if subcategory.budgetAmount != nil {
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
