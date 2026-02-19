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

    // AI categorization (inline, no modal)
    @State private var isAICategorizationRunning = false
    @State private var aiCategorizationProgress: Double = 0
    @State private var aiCategorizationError: String?

    // Quick add category
    @State private var showAddCategory = false

    // Loading state
    @State private var isLoading = true
    @State private var loadError: String?
    @State private var loadTask: Task<Void, Never>?

    // Tab selection (Budget vs Compare)
    @State private var budgetTab = 0

    // Filter toggle
    @State private var showIncomeInBudget = false

    // Month selection for viewing historical data
    @State private var selectedMonth: Date = Date()
    @State private var hasPreviousData: Bool = false
    @State private var hasNextData: Bool = false

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

    var isNextMonthAvailable: Bool {
        let calendar = Calendar.current
        guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: selectedMonth) else {
            return false
        }
        return nextMonth <= Date()
    }

    var isCurrentMonth: Bool {
        let calendar = Calendar.current
        return calendar.isDate(selectedMonth, equalTo: Date(), toGranularity: .month)
    }

    var isPreviousMonthAvailable: Bool {
        // API tells us if there's any previous data
        return hasPreviousData
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
                        reloadData()
                    }
                } else {
                    // Show main budget UI with Budget/Compare segmented control
                    VStack(spacing: 0) {
                        Picker("", selection: $budgetTab) {
                            Text("Budget").tag(0)
                            Text("Compare").tag(1)
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.vertical, Theme.Spacing.sm)

                        if budgetTab == 0 {
                            budgetContentView
                        } else {
                            SpendingCompareView(apiClient: apiClient, initialMonth: selectedMonth)
                        }
                    }
                }
            }
            .navigationTitle("Budget")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: CategoryTransactionsDestination.self) { destination in
                CategoryTransactionsNavigableView(
                    category: destination.category,
                    subcategory: destination.subcategory,
                    apiClient: apiClient,
                    selectedMonth: selectedMonth
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
                AllBudgetsView(isPresented: $showAllBudgets, apiClient: apiClient)
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
                    reloadData()
                }
            }
            .sheet(isPresented: $showAddCategory) {
                AddCategoryView(isPresented: $showAddCategory, apiClient: apiClient) { newCategory in
                    categories.append(newCategory)
                }
            }
        }
        .task {
            reloadData()
        }
        .onChange(of: selectedMonth) { oldValue, newValue in
            // Reload data when the selected month changes (skip initial load)
            if oldValue != newValue {
                isLoading = true  // Show loading state immediately
                reloadData()
            }
        }
    }

    private var budgetContentView: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                // Budget Header with date navigation
                HStack {
                        Button {
                            // Previous month
                            let calendar = Calendar.current
                            if let newMonth = calendar.date(byAdding: .month, value: -1, to: selectedMonth) {
                                selectedMonth = newMonth
                            }
                        } label: {
                            Image(systemName: "chevron.left")
                                .foregroundColor(isPreviousMonthAvailable ? Theme.Colors.textPrimary : Theme.Colors.textSecondary.opacity(0.3))
                        }
                        .disabled(!isPreviousMonthAvailable)

                        Spacer()

                        VStack(spacing: 2) {
                            Text(currentMonthYear)
                                .font(.headline)
                                .foregroundColor(Theme.Colors.textPrimary)
                            Text("\(daysRemainingText)")
                                .font(.caption)
                                .foregroundColor(Theme.Colors.textSecondary)

                            // Show indicator when at earliest available month
                            if !isPreviousMonthAvailable {
                                Text("No earlier data")
                                    .font(.caption2)
                                    .foregroundColor(Theme.Colors.textSecondary.opacity(0.7))
                                    .italic()
                            }
                        }

                        Spacer()

                        Button {
                            // Next month (only if not in future)
                            let calendar = Calendar.current
                            if let newMonth = calendar.date(byAdding: .month, value: 1, to: selectedMonth),
                               newMonth <= Date() {
                                selectedMonth = newMonth
                            }
                        } label: {
                            Image(systemName: "chevron.right")
                                .foregroundColor(isNextMonthAvailable ? Theme.Colors.textPrimary : Theme.Colors.textSecondary.opacity(0.3))
                        }
                        .disabled(!isNextMonthAvailable)
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.top, Theme.Spacing.sm)

                    // Uncategorized Transactions Card or AI Progress
                    if !uncategorizedTransactions.isEmpty {
                        if isAICategorizationRunning {
                            AICategorizationProgressCard(
                                progress: aiCategorizationProgress,
                                totalCount: uncategorizedTransactions.count
                            )
                            .padding(.horizontal, Theme.Spacing.md)
                        } else {
                            UncategorizedTransactionsCard(
                                uncategorizedCount: uncategorizedTransactions.count,
                                showManualCategorization: $showManualCategorization,
                                onAICategorizationTap: {
                                    Task { await startAICategorization() }
                                }
                            )
                            .padding(.horizontal, Theme.Spacing.md)

                            // Show error if AI categorization failed
                            if let error = aiCategorizationError {
                                HStack(spacing: Theme.Spacing.sm) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                    Text(error)
                                        .font(.caption)
                                        .foregroundColor(Theme.Colors.textSecondary)
                                    Spacer()
                                    Button("Retry") {
                                        aiCategorizationError = nil
                                        Task { await startAICategorization() }
                                    }
                                    .font(.caption)
                                    .foregroundColor(Theme.Colors.primary)
                                }
                                .padding(Theme.Spacing.sm)
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(Theme.CornerRadius.sm)
                                .padding(.horizontal, Theme.Spacing.md)
                            }
                        }
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
                                    reloadData()
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
                                ExpandableCategoryCard(
                                    category: $category,
                                    apiClient: apiClient,
                                    onDeleteCategoryBudget: category.lineItemId != nil ? {
                                        let c = category
                                        await deleteCategoryBudget(category: c)
                                    } : nil,
                                    onDeleteCategory: {
                                        let c = category
                                        await deleteCategory(category: c)
                                    }
                                )
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

    private func reloadData() {
        loadTask?.cancel()
        loadTask = Task { await loadData() }
    }

    private func loadData() async {
        isLoading = true
        loadError = nil

        // Clear old data to prevent showing stale information
        categories = []
        uncategorizedTransactions = []

        do {
            let calendar = Calendar.current
            let components = calendar.dateComponents([.year, .month], from: selectedMonth)
            guard let year = components.year, let month = components.month else {
                throw NSError(domain: "BudgetView", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid date"])
            }
            let monthString = "\(year)-\(String(format: "%02d", month))"

            // Fetch budget summary and categories tree in parallel
            async let summaryFetch = apiClient.getBudgetSummary(month: monthString)
            async let categoriesTreeFetch = apiClient.fetchCategoriesTree()

            let (budgetSummary, categoriesTree) = try await (summaryFetch, categoriesTreeFetch)

            // Build category lookup
            var categoryLookup: [String: CategoryWithSubcategories] = [:]
            for cat in categoriesTree {
                categoryLookup[cat.id] = cat
            }

            // Build subcategory-level line item lookup (by subcategory ID)
            var subcategoryLineItemMap: [String: BudgetSummaryLineItem] = [:]
            for lineItem in budgetSummary.lineItems where lineItem.subcategoryId != nil {
                subcategoryLineItemMap[lineItem.subcategoryId!] = lineItem
            }

            // Helper to build subcategories for a category
            func buildSubcategories(for cat: CategoryWithSubcategories) -> [BudgetSubcategory] {
                cat.subcategories.map { sub in
                    let subLineItem = subcategoryLineItemMap[sub.id]
                    // Use line item spending if budgeted, else fall back to raw subcategory spending
                    let spent = subLineItem?.spent ?? budgetSummary.subcategorySpending?[sub.id] ?? 0
                    return BudgetSubcategory(
                        id: sub.id,
                        name: sub.name,
                        icon: sub.icon,
                        budgetAmount: subLineItem?.amount,
                        spentAmount: spent,
                        transactionCount: 0,
                        lineItemId: subLineItem?.id,
                        budgetId: subLineItem != nil ? budgetSummary.budgetId : nil
                    )
                }
            }

            // Build BudgetCategory list from budgeted line items (category-level)
            var result: [BudgetCategory] = budgetSummary.lineItems
                .filter { $0.subcategoryId == nil }
                .compactMap { lineItem in
                    guard let cat = categoryLookup[lineItem.categoryId] else { return nil }
                    return BudgetCategory(
                        id: cat.id,
                        name: cat.name,
                        icon: cat.icon,
                        colorHex: cat.color,
                        type: .expense,
                        subcategories: buildSubcategories(for: cat),
                        budgetAmount: lineItem.amount,
                        spentAmount: lineItem.spent,
                        lineItemId: lineItem.id,
                        budgetId: budgetSummary.budgetId
                    )
                }

            // Add unbudgeted categories that have spending
            let budgetedCategoryIds = Set(result.map { $0.id })
            for unbudgeted in budgetSummary.unbudgetedCategories where unbudgeted.spent > 0 {
                guard !budgetedCategoryIds.contains(unbudgeted.categoryId),
                      let cat = categoryLookup[unbudgeted.categoryId] else { continue }
                result.append(BudgetCategory(
                    id: cat.id,
                    name: cat.name,
                    icon: cat.icon,
                    colorHex: cat.color,
                    type: .expense,
                    subcategories: buildSubcategories(for: cat),
                    budgetAmount: nil,
                    spentAmount: unbudgeted.spent,
                    budgetId: budgetSummary.budgetId
                ))
            }

            self.categories = result

            // Load transactions for uncategorized list and month navigation flags
            let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedMonth))!
            let startTimestamp = Int(startOfMonth.timeIntervalSince1970)
            let startOfNextMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth)!
            let endTimestamp = Int(startOfNextMonth.timeIntervalSince1970)

            let txResponse = try await apiClient.listSimplefinTransactions(
                dateFrom: startTimestamp,
                dateTo: endTimestamp,
                limit: 1000,
                offset: 0
            )

            hasPreviousData = txResponse.hasPreviousMonth
            hasNextData = txResponse.hasNextMonth

            self.uncategorizedTransactions = txResponse.items
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
        return formatter.string(from: selectedMonth)
    }

    private var daysRemainingText: String {
        let calendar = Calendar.current

        // If viewing current month, show days remaining
        if isCurrentMonth {
            let now = Date()
            let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: calendar.date(from: calendar.dateComponents([.year, .month], from: now))!)!
            let remaining = calendar.dateComponents([.day], from: now, to: endOfMonth).day ?? 0
            return remaining > 0 ? "\(remaining) days left" : "Period ended"
        } else {
            // For historical months, show "Past period" or similar
            return "Past period"
        }
    }

    private func startAICategorization() async {
        guard !isAICategorizationRunning else { return }

        isAICategorizationRunning = true
        aiCategorizationProgress = 0
        aiCategorizationError = nil

        // Animate progress while waiting for API
        let progressTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
            if !isAICategorizationRunning || aiCategorizationProgress >= 0.95 {
                timer.invalidate()
            } else {
                aiCategorizationProgress += 0.02
            }
        }

        do {
            // Call backend AI categorization
            let transactionIds = uncategorizedTransactions.map { $0.id }
            let response = try await apiClient.categorizeWithAI(transactionIds: transactionIds, force: false)

            // Build batch updates
            let updates = response.results.compactMap { result -> (transactionId: String, categoryId: String?, subcategoryId: String?)? in
                guard result.categoryId != nil else { return nil }
                return (transactionId: result.transactionId,
                       categoryId: result.categoryId,
                       subcategoryId: result.subcategoryId)
            }

            // Save to backend (already done by categorizeWithAI, but batch update ensures consistency)
            if !updates.isEmpty {
                _ = try await apiClient.batchUpdateTransactions(updates)
            }

            // Complete progress
            aiCategorizationProgress = 1.0

            // Wait a moment to show completion
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

            // Reload data to refresh the view
            await loadData()

            // Reset state
            isAICategorizationRunning = false
            aiCategorizationProgress = 0

        } catch {
            progressTimer.invalidate()
            aiCategorizationError = "Failed to categorize: \(error.localizedDescription)"
            isAICategorizationRunning = false
            aiCategorizationProgress = 0
        }
    }

    func deleteCategoryBudget(category: BudgetCategory) async {
        guard let lineItemId = category.lineItemId,
              let budgetId = category.budgetId else { return }
        do {
            try await apiClient.deleteBudgetLineItem(budgetId: budgetId, lineItemId: lineItemId)
            if let idx = categories.firstIndex(where: { $0.id == category.id }) {
                categories[idx].lineItemId = nil
                categories[idx].budgetAmount = nil
                categories[idx].budgetId = nil
            }
        } catch {
            // Budget delete failed silently — user can retry via context menu
        }
    }

    func deleteCategory(category: BudgetCategory) async {
        if category.lineItemId != nil {
            await deleteCategoryBudget(category: category)
        }
        do {
            try await apiClient.deleteCategory(categoryId: category.id)
            categories.removeAll { $0.id == category.id }
        } catch {
            // Deletion failed silently
        }
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

// MARK: - All Budgets View

struct AllBudgetsView: View {
    @Binding var isPresented: Bool
    let apiClient: APIClient

    @State private var budgets: [BudgetAPI] = []
    @State private var isLoading = true
    @State private var loadError: String?
    @State private var editingBudget: BudgetAPI?
    @State private var showCreateBudget = false

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading...")
                } else if let error = loadError {
                    VStack(spacing: Theme.Spacing.md) {
                        Text("Error loading budgets")
                            .font(.headline)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(Theme.Colors.textSecondary)
                        Button("Retry") { Task { await loadData() } }
                            .foregroundColor(Theme.Colors.primary)
                    }
                } else if budgets.isEmpty {
                    VStack(spacing: Theme.Spacing.md) {
                        Image(systemName: "list.bullet.rectangle")
                            .font(.largeTitle)
                            .foregroundColor(Theme.Colors.textSecondary.opacity(0.5))
                        Text("No budgets yet")
                            .font(.headline)
                            .foregroundColor(Theme.Colors.textSecondary)
                        Button("Create Budget") { showCreateBudget = true }
                            .foregroundColor(Theme.Colors.primary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        Section {
                            ForEach(budgets) { budget in
                                Button {
                                    editingBudget = budget
                                } label: {
                                    HStack(spacing: Theme.Spacing.sm) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            HStack(spacing: 6) {
                                                Text(budget.name)
                                                    .font(.body)
                                                    .foregroundColor(Theme.Colors.textPrimary)
                                                if budget.isDefault {
                                                    Text("DEFAULT")
                                                        .font(.caption2).fontWeight(.bold)
                                                        .foregroundColor(.white)
                                                        .padding(.horizontal, 6).padding(.vertical, 2)
                                                        .background(Theme.Colors.primary)
                                                        .cornerRadius(4)
                                                }
                                            }
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundColor(Theme.Colors.textSecondary)
                                    }
                                }
                            }
                        } header: {
                            Text("Budgets")
                        } footer: {
                            Text("Tap a budget to rename, set as default, or delete it.")
                                .font(.caption)
                        }
                    }
                }
            }
            .navigationTitle("All Budgets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { isPresented = false }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showCreateBudget = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(item: $editingBudget) { budget in
                BudgetEditSheet(
                    budget: budget,
                    apiClient: apiClient,
                    onSave: { updated in
                        if let idx = budgets.firstIndex(where: { $0.id == updated.id }) {
                            budgets[idx] = updated
                        }
                        // If this is now default, clear default from others
                        if updated.isDefault {
                            for idx in budgets.indices where budgets[idx].id != updated.id {
                                if budgets[idx].isDefault {
                                    budgets[idx] = BudgetAPI(
                                        id: budgets[idx].id,
                                        userId: budgets[idx].userId,
                                        name: budgets[idx].name,
                                        isDefault: false,
                                        createdAt: budgets[idx].createdAt,
                                        updatedAt: budgets[idx].updatedAt
                                    )
                                }
                            }
                        }
                        editingBudget = nil
                    },
                    onDelete: { deletedId in
                        budgets.removeAll { $0.id == deletedId }
                        editingBudget = nil
                    }
                )
            }
            .sheet(isPresented: $showCreateBudget) {
                CreateBudgetSheet(apiClient: apiClient) { newBudget in
                    // If new budget is default, clear others
                    if newBudget.isDefault {
                        for idx in budgets.indices {
                            if budgets[idx].isDefault {
                                budgets[idx] = BudgetAPI(
                                    id: budgets[idx].id,
                                    userId: budgets[idx].userId,
                                    name: budgets[idx].name,
                                    isDefault: false,
                                    createdAt: budgets[idx].createdAt,
                                    updatedAt: budgets[idx].updatedAt
                                )
                            }
                        }
                    }
                    budgets.append(newBudget)
                    showCreateBudget = false
                }
            }
        }
        .task { await loadData() }
    }

    private func loadData() async {
        isLoading = true
        loadError = nil
        do {
            budgets = try await apiClient.fetchBudgets()
        } catch {
            loadError = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Budget Edit Sheet

private struct BudgetEditSheet: View {
    let budget: BudgetAPI
    let apiClient: APIClient
    let onSave: (BudgetAPI) -> Void
    let onDelete: (String) -> Void

    @State private var name: String
    @State private var isDefault: Bool
    @State private var isSaving = false
    @State private var isDeleting = false
    @State private var showDeleteConfirmation = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    init(budget: BudgetAPI, apiClient: APIClient, onSave: @escaping (BudgetAPI) -> Void, onDelete: @escaping (String) -> Void) {
        self.budget = budget
        self.apiClient = apiClient
        self.onSave = onSave
        self.onDelete = onDelete
        _name = State(initialValue: budget.name)
        _isDefault = State(initialValue: budget.isDefault)
    }

    var body: some View {
        NavigationView {
            Form {
                Section("Budget Details") {
                    HStack {
                        Text("Name")
                        Spacer()
                        TextField("Budget name", text: $name)
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                    Toggle("Set as Default", isOn: $isDefault)
                        .tint(Theme.Colors.primary)
                }

                if isDefault && budget.isDefault {
                    Section {
                        HStack(spacing: Theme.Spacing.sm) {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.blue)
                            Text("This is your default budget, applied to months without a specific override.")
                                .font(.caption)
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                    }
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }

                Section {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        HStack {
                            Spacer()
                            if isDeleting {
                                ProgressView()
                            } else {
                                Label("Delete Budget", systemImage: "trash")
                            }
                            Spacer()
                        }
                    }
                    .disabled(isDeleting || isSaving)
                }
            }
            .navigationTitle("Edit Budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Save") { Task { await save() } }
                            .fontWeight(.semibold)
                            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                    }
                }
            }
            .confirmationDialog(
                "Delete \"\(budget.name)\"?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete Budget", role: .destructive) { Task { await delete() } }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will delete the budget and all its line items. Transactions are not affected.")
            }
        }
    }

    private func save() async {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        isSaving = true
        errorMessage = nil
        do {
            let updated = try await apiClient.updateBudget(
                budgetId: budget.id,
                name: trimmed != budget.name ? trimmed : nil,
                isDefault: isDefault != budget.isDefault ? isDefault : nil
            )
            onSave(updated)
        } catch {
            errorMessage = "Failed to save: \(error.localizedDescription)"
        }
        isSaving = false
    }

    private func delete() async {
        isDeleting = true
        errorMessage = nil
        do {
            try await apiClient.deleteBudget(budgetId: budget.id)
            onDelete(budget.id)
        } catch {
            errorMessage = "Failed to delete: \(error.localizedDescription)"
            isDeleting = false
        }
    }
}

// MARK: - Create Budget Sheet

private struct CreateBudgetSheet: View {
    let apiClient: APIClient
    let onCreate: (BudgetAPI) -> Void

    @State private var name = ""
    @State private var isDefault = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section("Budget Details") {
                    HStack {
                        Text("Name")
                        Spacer()
                        TextField("e.g. Monthly Budget", text: $name)
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                    Toggle("Set as Default", isOn: $isDefault)
                        .tint(Theme.Colors.primary)
                }

                Section {
                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)
                        Text("The default budget is applied to all months unless you set a specific budget for a month.")
                            .font(.caption)
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("New Budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Create") { Task { await create() } }
                            .fontWeight(.semibold)
                            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                    }
                }
            }
        }
    }

    private func create() async {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        isSaving = true
        errorMessage = nil
        do {
            let created = try await apiClient.createBudget(name: trimmed, isDefault: isDefault)
            onCreate(created)
        } catch {
            errorMessage = "Failed to create: \(error.localizedDescription)"
            isSaving = false
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
    var onDeleteCategoryBudget: (() async -> Void)? = nil
    var onDeleteCategory: (() async -> Void)? = nil
    @State private var isExpanded: Bool = false
    @State private var showEditCategoryBudget: Bool = false
    @State private var showEditCategory: Bool = false
    @State private var showAddSubcategory: Bool = false
    @State private var showDeleteCategoryConfirmation: Bool = false

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
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(.vertical, Theme.Spacing.xs)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .contextMenu {
                Button {
                    showEditCategory = true
                } label: {
                    Label("Edit Category", systemImage: "square.and.pencil")
                }
                Divider()
                Button {
                    showEditCategoryBudget = true
                } label: {
                    Label("Edit Category Budget", systemImage: "pencil")
                }
                if let onDelete = onDeleteCategoryBudget {
                    Button(role: .destructive) {
                        Task { await onDelete() }
                    } label: {
                        Label("Remove Category Budget", systemImage: "minus.circle")
                    }
                }
                Divider()
                if onDeleteCategory != nil {
                    Button(role: .destructive) {
                        showDeleteCategoryConfirmation = true
                    } label: {
                        Label("Delete Category", systemImage: "trash")
                    }
                }
            }

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
                            apiClient: apiClient,
                            onDeleteSubcategoryBudget: subcategory.lineItemId != nil ? {
                                let sub = subcategory
                                await deleteSubcategoryBudget(subcategory: sub)
                            } : nil
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
                isPresented: $showEditCategoryBudget,
                apiClient: apiClient
            )
        }
        .sheet(isPresented: $showEditCategory) {
            EditCategoryView(
                category: $category,
                isPresented: $showEditCategory,
                apiClient: apiClient
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
        .confirmationDialog(
            "Delete \"\(category.name)\"?",
            isPresented: $showDeleteCategoryConfirmation,
            titleVisibility: .visible
        ) {
            if category.lineItemId != nil {
                Button("Remove Budget & Delete Category", role: .destructive) {
                    Task { await onDeleteCategory?() }
                }
            } else {
                Button("Delete Category", role: .destructive) {
                    Task { await onDeleteCategory?() }
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            if category.lineItemId != nil {
                Text("This will remove the $\(String(format: "%.0f", category.budgetAmount ?? 0)) budget allocation and delete the category. Transactions will become uncategorized.")
            } else {
                Text("This category will be deleted. Transactions will become uncategorized.")
            }
        }
    }

    private func deleteSubcategoryBudget(subcategory: BudgetSubcategory) async {
        guard let lineItemId = subcategory.lineItemId,
              let budgetId = subcategory.budgetId else { return }
        do {
            try await apiClient.deleteBudgetLineItem(budgetId: budgetId, lineItemId: lineItemId)
            if let idx = category.subcategories.firstIndex(where: { $0.id == subcategory.id }) {
                category.subcategories[idx].lineItemId = nil
                category.subcategories[idx].budgetAmount = nil
                category.subcategories[idx].budgetId = nil
            }
        } catch {
            // Delete failed silently — user can retry via context menu
        }
    }
}

// MARK: - Subcategory Row

struct SubcategoryRow: View {
    let category: BudgetCategory
    @Binding var subcategory: BudgetSubcategory
    let categoryColor: Color
    let apiClient: APIClient
    var onDeleteSubcategoryBudget: (() async -> Void)? = nil
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
        .contextMenu {
            Button {
                showEditBudget = true
            } label: {
                Label("Edit Subcategory Budget", systemImage: "pencil")
            }
            if let onDelete = onDeleteSubcategoryBudget {
                Button(role: .destructive) {
                    Task { await onDelete() }
                } label: {
                    Label("Remove Subcategory Budget", systemImage: "trash")
                }
            }
        }
        .sheet(isPresented: $showEditBudget) {
            SubcategoryBudgetView(
                subcategory: $subcategory,
                categoryId: category.id,
                categoryColor: categoryColor,
                isPresented: $showEditBudget,
                apiClient: apiClient
            )
        }
    }
}

#Preview {
    BudgetView(apiClient: APIClient())
}
