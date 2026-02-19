import SwiftUI

struct BudgetView: View {
    let apiClient: APIClient
    @State private var categories: [BudgetCategory] = []
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
                            Text("Spending").tag(1)
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
            .navigationDestination(for: AllBudgetsNavValue.self) { _ in
                AllBudgetsView(apiClient: apiClient)
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
                            if let days = daysRemainingText {
                                Text(days)
                                    .font(.caption)
                                    .foregroundColor(Theme.Colors.textSecondary)
                            }

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
                            NavigationLink(value: AllBudgetsNavValue()) {
                                Text("All Budgets")
                                    .font(.subheadline)
                                    .foregroundColor(Theme.Colors.primary)
                            }
                            .buttonStyle(.plain)
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

                        Text("-$\(String(format: "%.2f", totalSpent)) \(spentMonthLabel)")
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

                        // Donut Chart — show all categories with spending, not just budgeted ones
                        InteractiveBudgetDonutView(
                            categories: categories.filter { $0.spentAmount > 0 },
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

            // Add uncategorized row if there's spending without a category
            if let uncategorized = budgetSummary.uncategorizedSpending, uncategorized > 0 {
                result.append(BudgetCategory(
                    id: "uncategorized",
                    name: "Uncategorized",
                    icon: "❔",
                    colorHex: "#9CA3AF",
                    type: .expense,
                    subcategories: [],
                    budgetAmount: nil,
                    spentAmount: uncategorized,
                    budgetId: nil
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

    private var daysRemainingText: String? {
        guard isCurrentMonth else { return nil }
        let calendar = Calendar.current
        let now = Date()
        let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: calendar.date(from: calendar.dateComponents([.year, .month], from: now))!)!
        let remaining = calendar.dateComponents([.day], from: now, to: endOfMonth).day ?? 0
        return remaining > 0 ? "\(remaining) days left" : "Last day"
    }

    private var spentMonthLabel: String {
        if isCurrentMonth {
            return "spent this month"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM"
            return "spent in \(formatter.string(from: selectedMonth))"
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

// MARK: - Navigation value for All Budgets

private struct AllBudgetsNavValue: Hashable {}

// MARK: - Budget List Card (used in AllBudgetsView)

private struct BudgetListCard: View {
    let budget: BudgetAPI
    let lineItems: [BudgetLineItem]
    let allCategories: [CategoryWithSubcategories]

    private let fallbackColors = [
        "#5b8def", "#e8845c", "#d4d46a", "#c17ad4", "#7dd8a0",
        "#6bcbd4", "#ef8f5b", "#a0a0ef", "#efcf5b"
    ]

    var totalBudget: Double {
        lineItems.reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Budget name + badges
            HStack(spacing: 10) {
                Text(budget.emoji ?? "💰")
                    .font(.system(size: 26))
                    .frame(width: 44, height: 44)
                    .background(Color(hex: budget.color ?? "#00A699").opacity(0.15))
                    .cornerRadius(12)

                VStack(alignment: .leading, spacing: 3) {
                    Text(budget.name)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Theme.Colors.textPrimary)
                        .lineLimit(1)
                    if budget.isDefault {
                        Text("DEFAULT")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Theme.Colors.primary)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Theme.Colors.primary.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Theme.Colors.primary.opacity(0.25), lineWidth: 1)
                            )
                            .cornerRadius(4)
                    }
                }

                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13))
                    .foregroundColor(Theme.Colors.textSecondary)
            }
            .padding(.bottom, 14)

            // Total + categories count
            HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("TOTAL BUDGET")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Theme.Colors.textSecondary)
                        .kerning(0.5)
                    Text(formatAmount(totalBudget))
                        .font(.system(size: 30, weight: .bold, design: .monospaced))
                        .foregroundColor(Theme.Colors.textPrimary)
                        .kerning(-1)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("CATEGORIES")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Theme.Colors.textSecondary)
                        .kerning(0.5)
                    Text("\(lineItems.count)")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Theme.Colors.textSecondary)
                }
            }

            if totalBudget > 0 && !lineItems.isEmpty {
                // Colored breakdown bar
                GeometryReader { geometry in
                    HStack(spacing: 3) {
                        ForEach(Array(lineItems.enumerated()), id: \.element.id) { idx, item in
                            let pct = CGFloat(item.amount / totalBudget)
                            let w = max(4, (geometry.size.width - CGFloat(lineItems.count - 1) * 3) * pct)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color(hex: categoryColor(for: item.categoryId, index: idx)))
                                .frame(width: w)
                        }
                    }
                }
                .frame(height: 6)
                .cornerRadius(3)
                .padding(.top, 16)

                // Legend
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(Array(lineItems.enumerated()), id: \.element.id) { idx, item in
                            HStack(spacing: 5) {
                                Circle()
                                    .fill(Color(hex: categoryColor(for: item.categoryId, index: idx)))
                                    .frame(width: 7, height: 7)
                                Text(categoryName(for: item.categoryId))
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(Theme.Colors.textSecondary)
                            }
                        }
                    }
                }
                .padding(.top, 10)
            } else if lineItems.isEmpty {
                Text("No categories set")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.Colors.textSecondary)
                    .padding(.top, 10)
            }
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.07), radius: 8, x: 0, y: 2)
    }

    private func categoryColor(for categoryId: String, index: Int) -> String {
        allCategories.first(where: { $0.id == categoryId })?.color
            ?? fallbackColors[index % fallbackColors.count]
    }

    private func categoryName(for categoryId: String) -> String {
        allCategories.first(where: { $0.id == categoryId })?.name ?? "Category"
    }

    private func formatAmount(_ amount: Double) -> String {
        let fmt = NumberFormatter()
        fmt.numberStyle = .currency
        fmt.currencyCode = "USD"
        fmt.maximumFractionDigits = 0
        fmt.minimumFractionDigits = 0
        return fmt.string(from: NSNumber(value: amount)) ?? "$\(Int(amount))"
    }
}

// MARK: - All Budgets View

struct AllBudgetsView: View {
    let apiClient: APIClient

    @State private var budgets: [BudgetAPI] = []
    @State private var isLoading = true
    @State private var loadError: String?
    @State private var showCreateBudget = false
    @State private var allCategories: [CategoryWithSubcategories] = []
    @State private var budgetLineItems: [String: [BudgetLineItem]] = [:]

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading...")
            } else if let error = loadError {
                VStack(spacing: Theme.Spacing.md) {
                    Text("Error loading budgets")
                        .font(.headline)
                        .foregroundColor(Theme.Colors.textPrimary)
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
                        .foregroundColor(Theme.Colors.textSecondary)
                    Text("No budgets yet")
                        .font(.headline)
                        .foregroundColor(Theme.Colors.textSecondary)
                    Button("Create Budget") { showCreateBudget = true }
                        .foregroundColor(Theme.Colors.primary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 14) {
                        ForEach(budgets) { budget in
                            NavigationLink(value: budget) {
                                BudgetListCard(
                                    budget: budget,
                                    lineItems: budgetLineItems[budget.id] ?? [],
                                    allCategories: allCategories
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
            }
        }
        .background(Theme.Colors.background.ignoresSafeArea())
        .navigationTitle("All Budgets")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showCreateBudget = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .navigationDestination(for: BudgetAPI.self) { budget in
            BudgetEditView(
                budget: budget,
                apiClient: apiClient,
                onSave: handleBudgetSave,
                onDelete: handleBudgetDelete
            )
        }
        .sheet(isPresented: $showCreateBudget) {
            CreateBudgetSheet(apiClient: apiClient) { newBudget in
                if newBudget.isDefault {
                    for idx in budgets.indices where budgets[idx].isDefault {
                        budgets[idx] = BudgetAPI(
                            id: budgets[idx].id,
                            userId: budgets[idx].userId,
                            name: budgets[idx].name,
                            isDefault: false,
                            emoji: budgets[idx].emoji,
                            color: budgets[idx].color,
                            createdAt: budgets[idx].createdAt,
                            updatedAt: budgets[idx].updatedAt
                        )
                    }
                }
                budgets.append(newBudget)
                showCreateBudget = false
            }
        }
        .task { await loadData() }
    }

    private func handleBudgetSave(_ updated: BudgetAPI) {
        if let idx = budgets.firstIndex(where: { $0.id == updated.id }) {
            budgets[idx] = updated
        }
        if updated.isDefault {
            for idx in budgets.indices where budgets[idx].id != updated.id {
                if budgets[idx].isDefault {
                    budgets[idx] = BudgetAPI(
                        id: budgets[idx].id,
                        userId: budgets[idx].userId,
                        name: budgets[idx].name,
                        isDefault: false,
                        emoji: budgets[idx].emoji,
                        color: budgets[idx].color,
                        createdAt: budgets[idx].createdAt,
                        updatedAt: budgets[idx].updatedAt
                    )
                }
            }
        }
        Task {
            let items = (try? await apiClient.fetchBudgetLineItems(budgetId: updated.id)) ?? []
            budgetLineItems[updated.id] = items.filter { $0.subcategoryId == nil }
        }
    }

    private func handleBudgetDelete(_ deletedId: String) {
        budgets.removeAll { $0.id == deletedId }
        budgetLineItems.removeValue(forKey: deletedId)
    }

    private func loadData() async {
        isLoading = true
        loadError = nil
        do {
            async let budgetsFetch = apiClient.fetchBudgets()
            async let categoriesFetch = apiClient.fetchCategoriesTree()
            let (fetchedBudgets, cats) = try await (budgetsFetch, categoriesFetch)
            budgets = fetchedBudgets
            allCategories = cats
            // Load line items for each budget in parallel
            await withTaskGroup(of: (String, [BudgetLineItem]).self) { group in
                for b in fetchedBudgets {
                    group.addTask {
                        let items = (try? await apiClient.fetchBudgetLineItems(budgetId: b.id)) ?? []
                        return (b.id, items.filter { $0.subcategoryId == nil })
                    }
                }
                for await (budgetId, items) in group {
                    budgetLineItems[budgetId] = items
                }
            }
        } catch {
            loadError = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Subcategory Edit Row (for CategoryEditRow expanded section)

private struct SubcategoryEditRow: View {
    let lineItem: BudgetLineItem?
    let subcategory: Subcategory?
    @Binding var amountText: String
    let onAmountCommit: (Double) -> Void

    @FocusState private var isEditing: Bool

    var body: some View {
        HStack(spacing: 0) {
            Text(subcategory?.icon ?? "•")
                .font(.system(size: 16))
                .frame(width: 28, alignment: .center)
                .padding(.leading, 54)

            Text(subcategory?.name ?? "Subcategory")
                .font(.system(size: 13))
                .foregroundColor(Theme.Colors.textSecondary)
                .lineLimit(1)

            Spacer()

            if isEditing {
                HStack(spacing: 2) {
                    Text("$")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Theme.Colors.primary)
                    TextField("0", text: $amountText)
                        .keyboardType(.numberPad)
                        .focused($isEditing)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundColor(Theme.Colors.textPrimary)
                        .frame(width: 60)
                        .multilineTextAlignment(.trailing)
                        .onSubmit { commitEdit() }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Theme.Colors.primaryLight.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Theme.Colors.primary.opacity(0.4), lineWidth: 1)
                )
                .cornerRadius(8)
                .padding(.trailing, 16)
            } else {
                Button {
                    amountText = String(format: "%.0f", lineItem?.amount ?? 0)
                    isEditing = true
                } label: {
                    Text("$\(String(format: "%.0f", Double(amountText) ?? lineItem?.amount ?? 0))")
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundColor((lineItem?.amount ?? 0) == 0 ? Theme.Colors.textSecondary : Theme.Colors.textPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Theme.Colors.background)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.15), lineWidth: 1)
                        )
                        .cornerRadius(8)
                }
                .padding(.trailing, 16)
            }
        }
        .frame(minHeight: 40)
        .background(Color(red: 0.95, green: 0.96, blue: 0.96))
        .onChange(of: isEditing) { _, editing in
            if !editing { commitEdit() }
        }
    }

    private func commitEdit() {
        let cleaned = amountText.filter { $0.isNumber }
        if let value = Double(cleaned), value >= 0 {
            onAmountCommit(value)
        }
    }
}

// MARK: - Category Edit Row (for BudgetEditView)

private struct CategoryEditRow: View {
    let lineItem: BudgetLineItem
    let category: CategoryWithSubcategories?
    let subcategoryLineItems: [BudgetLineItem]
    let subcategories: [Subcategory]
    let isExpanded: Bool
    @Binding var amountText: String
    @Binding var editingAmounts: [String: String]
    let onToggleExpand: () -> Void
    let onAmountCommit: (Double) -> Void
    let onSubcategoryAmountCommit: (BudgetLineItem, Double) -> Void
    let onSubcategoryCreate: (String, Double) -> Void
    let onRemove: () -> Void

    @FocusState private var isEditing: Bool

    private func formattedAmount(_ text: String, fallback: Double) -> String {
        let val = Double(text) ?? fallback
        let fmt = NumberFormatter()
        fmt.numberStyle = .currency
        fmt.currencyCode = "USD"
        fmt.maximumFractionDigits = 0
        fmt.minimumFractionDigits = 0
        return fmt.string(from: NSNumber(value: val)) ?? "$\(Int(val))"
    }

    // If subcategory budgets are set, sum them; else fall back to category-level amount
    private var headerDisplayAmount: Double {
        if !subcategoryLineItems.isEmpty {
            return subcategories.reduce(0.0) { sum, subcat in
                if let item = subcategoryLineItems.first(where: { $0.subcategoryId == subcat.id }) {
                    let text = editingAmounts[item.id] ?? String(format: "%.0f", item.amount)
                    return sum + (Double(text) ?? item.amount)
                }
                let text = editingAmounts["new_\(subcat.id)"] ?? "0"
                return sum + (Double(text) ?? 0)
            }
        }
        return Double(amountText) ?? lineItem.amount
    }

    var body: some View {
        VStack(spacing: 0) {
            // Category header row — tap to expand/collapse
            Button(action: onToggleExpand) {
                HStack(spacing: 0) {
                    Text(category?.icon ?? "❓")
                        .font(.system(size: 22))
                        .frame(width: 38, alignment: .leading)
                        .padding(.leading, 16)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(category?.name ?? "Unknown")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Theme.Colors.textPrimary)
                            .lineLimit(1)
                        if !subcategories.isEmpty {
                            Text("\(subcategoryLineItems.count) of \(subcategories.count) budgeted")
                                .font(.system(size: 11))
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                    }

                    Spacer()

                    Text(formattedAmount(String(headerDisplayAmount), fallback: lineItem.amount))
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundColor(Theme.Colors.textSecondary)
                        .padding(.trailing, 8)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.Colors.textSecondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .animation(.easeInOut(duration: 0.2), value: isExpanded)
                        .padding(.trailing, 16)
                }
                .frame(minHeight: 52)
                .background(isExpanded ? Color(red: 0.95, green: 0.96, blue: 0.96) : Color.clear)
            }
            .buttonStyle(.plain)

            // Expanded content
            if isExpanded {
                VStack(spacing: 0) {
                    Divider()
                        .background(Color.gray.opacity(0.15))

                    // Category-level amount row (shown when no subcategories, or as "category total")
                    HStack {
                        Text(subcategoryLineItems.isEmpty ? "Category Budget" : "Category Total")
                            .font(.system(size: 14))
                            .foregroundColor(Theme.Colors.textSecondary)
                            .padding(.leading, 54)

                        Spacer()

                        if subcategoryLineItems.isEmpty {
                            // Editable when no subcategory budgets are set yet
                            if isEditing {
                                HStack(spacing: 2) {
                                    Text("$")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(Theme.Colors.primary)
                                    TextField("0", text: $amountText)
                                        .keyboardType(.numberPad)
                                        .focused($isEditing)
                                        .font(.system(size: 15, weight: .semibold, design: .monospaced))
                                        .foregroundColor(Theme.Colors.textPrimary)
                                        .frame(width: 72)
                                        .multilineTextAlignment(.trailing)
                                        .onSubmit { commitEdit() }
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Theme.Colors.primaryLight.opacity(0.15))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Theme.Colors.primary.opacity(0.5), lineWidth: 1)
                                )
                                .cornerRadius(10)
                                .padding(.trailing, 16)
                            } else {
                                Button {
                                    amountText = String(format: "%.0f", lineItem.amount)
                                    isEditing = true
                                } label: {
                                    Text(formattedAmount(amountText, fallback: lineItem.amount))
                                        .font(.system(size: 15, weight: .semibold, design: .monospaced))
                                        .foregroundColor(lineItem.amount == 0 ? Theme.Colors.textSecondary : Theme.Colors.textPrimary)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(Theme.Colors.background)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                        )
                                        .cornerRadius(10)
                                }
                                .padding(.trailing, 16)
                            }
                        } else {
                            // Display-only total when subcategories exist
                            Text(formattedAmount(String(headerDisplayAmount), fallback: lineItem.amount))
                                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                                .foregroundColor(Theme.Colors.textPrimary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color.gray.opacity(0.06))
                                .cornerRadius(10)
                                .padding(.trailing, 16)
                        }
                    }
                    .padding(.vertical, 10)
                    .background(Color(red: 0.95, green: 0.96, blue: 0.96))

                    // Subcategory rows — rendered from category definition, matched to line items
                    if !subcategories.isEmpty {
                        Divider()
                            .padding(.leading, 54)
                            .background(Color.gray.opacity(0.1))

                        ForEach(subcategories) { subcat in
                            let subItem = subcategoryLineItems.first { $0.subcategoryId == subcat.id }
                            SubcategoryEditRow(
                                lineItem: subItem,
                                subcategory: subcat,
                                amountText: Binding(
                                    get: {
                                        if let item = subItem {
                                            return editingAmounts[item.id] ?? String(format: "%.0f", item.amount)
                                        }
                                        return editingAmounts["new_\(subcat.id)"] ?? "0"
                                    },
                                    set: {
                                        if let item = subItem {
                                            editingAmounts[item.id] = $0
                                        } else {
                                            editingAmounts["new_\(subcat.id)"] = $0
                                        }
                                    }
                                ),
                                onAmountCommit: { amount in
                                    if let item = subItem {
                                        onSubcategoryAmountCommit(item, amount)
                                    } else {
                                        onSubcategoryCreate(subcat.id, amount)
                                    }
                                }
                            )

                            if subcat.id != subcategories.last?.id {
                                Divider()
                                    .padding(.leading, 82)
                                    .background(Color.gray.opacity(0.08))
                            }
                        }
                    }

                    // Actions row
                    HStack(spacing: 8) {
                        Button(action: onRemove) {
                            Text("Remove Category")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Theme.Colors.expense)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Theme.Colors.expense.opacity(0.3), lineWidth: 1)
                                )
                                .cornerRadius(8)
                        }
                        Spacer()
                    }
                    .padding(.leading, 54)
                    .padding(.vertical, 10)
                    .padding(.bottom, 6)
                    .background(Color(red: 0.95, green: 0.96, blue: 0.96))
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color(red: 0.95, green: 0.96, blue: 0.96).opacity(isExpanded ? 1 : 0))
        .cornerRadius(14)
        .onChange(of: isEditing) { _, editing in
            if !editing { commitEdit() }
        }
    }

    private func commitEdit() {
        let cleaned = amountText.filter { $0.isNumber }
        if let value = Double(cleaned), value >= 0 {
            onAmountCommit(value)
        }
    }
}

// MARK: - Budget Edit View

private struct BudgetEditView: View {
    let budget: BudgetAPI
    let apiClient: APIClient
    let onSave: (BudgetAPI) -> Void
    let onDelete: (String) -> Void

    @State private var name: String
    @State private var isDefault: Bool
    @State private var emoji: String
    @State private var selectedColor: String
    @State private var isSaving = false
    @State private var isDeleting = false
    @State private var showDeleteConfirmation = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    @State private var lineItems: [BudgetLineItem] = []
    @State private var allCategories: [CategoryWithSubcategories] = []
    @State private var isLoadingLineItems = true
    @State private var showAddLineItem = false
    @State private var expandedCategories: Set<String> = []
    @State private var editingAmounts: [String: String] = [:]

    // Month overrides
    @State private var budgetMonths: [BudgetMonth] = []
    @State private var showMonthPicker = false
    @State private var monthPickerDate = Date()

    // Linked accounts
    @State private var allAccounts: [SimplefinAccount] = []
    @State private var linkedAccountIds: Set<String> = []
    @State private var accountErrorMessage: String?
    @State private var showAddAccount = false
    @State private var isLoadingAccounts = true

    var linkedAccounts: [SimplefinAccount] {
        allAccounts.filter { linkedAccountIds.contains($0.id) }
    }

    var unlinkedAccounts: [SimplefinAccount] {
        allAccounts.filter { !linkedAccountIds.contains($0.id) }
    }

    // Emoji editor
    @State private var showEmojiEditor = false
    @State private var emojiInput: String = ""

    private let fallbackColors = [
        "#5b8def", "#e8845c", "#d4d46a", "#c17ad4", "#7dd8a0",
        "#6bcbd4", "#ef8f5b", "#a0a0ef", "#efcf5b"
    ]

    init(budget: BudgetAPI, apiClient: APIClient, onSave: @escaping (BudgetAPI) -> Void, onDelete: @escaping (String) -> Void) {
        self.budget = budget
        self.apiClient = apiClient
        self.onSave = onSave
        self.onDelete = onDelete
        _name = State(initialValue: budget.name)
        _isDefault = State(initialValue: budget.isDefault)
        _emoji = State(initialValue: budget.emoji ?? "💰")
        _selectedColor = State(initialValue: budget.color ?? "#00A699")
    }

    var categoryLineItems: [BudgetLineItem] {
        lineItems.filter { $0.subcategoryId == nil }
    }

    var totalBudget: Double {
        categoryLineItems.reduce(0) { $0 + $1.amount }
    }

    private func subcategoryLineItemsFor(categoryId: String) -> [BudgetLineItem] {
        lineItems.filter { $0.categoryId == categoryId && $0.subcategoryId != nil }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.Colors.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // Name field
                    TextField("Budget Name", text: $name)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(Theme.Colors.textPrimary)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 6)

                    // Badge row
                    HStack(spacing: 8) {
                        if isDefault {
                            Text("DEFAULT")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Theme.Colors.primary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Theme.Colors.primary.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Theme.Colors.primary.opacity(0.25), lineWidth: 1)
                                )
                                .cornerRadius(6)
                        }
                        Toggle("", isOn: $isDefault)
                            .labelsHidden()
                            .tint(Theme.Colors.primary)
                            .scaleEffect(0.85)
                        Text(isDefault ? "Default budget" : "Not default")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.Colors.textSecondary)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)

                    // Linked Accounts Section
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("LINKED ACCOUNTS")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(Theme.Colors.textSecondary)
                                .kerning(1.0)
                            Spacer()
                            Button {
                                showAddAccount = true
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 11, weight: .semibold))
                                    Text("Add Account")
                                        .font(.system(size: 12, weight: .semibold))
                                }
                                .foregroundColor(unlinkedAccounts.isEmpty ? Theme.Colors.textSecondary : Theme.Colors.primary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Theme.Colors.background)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                )
                                .cornerRadius(8)
                            }
                            .disabled(unlinkedAccounts.isEmpty)
                        }

                        if isLoadingAccounts {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Loading accounts...")
                                    .font(.system(size: 12))
                                    .foregroundColor(Theme.Colors.textSecondary)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.gray.opacity(0.06))
                            .cornerRadius(10)
                        } else if linkedAccounts.isEmpty {
                            Text(allAccounts.isEmpty
                                 ? "No bank accounts connected. Add one from the Overview tab."
                                 : "No accounts linked. Tap \"Add Account\" to link accounts to this budget.")
                                .font(.system(size: 12))
                                .foregroundColor(Theme.Colors.textSecondary)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.gray.opacity(0.06))
                                .cornerRadius(10)
                        } else {
                            VStack(spacing: 0) {
                                ForEach(Array(linkedAccounts.enumerated()), id: \.element.id) { idx, account in
                                    HStack(spacing: 12) {
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(account.name)
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(Theme.Colors.textPrimary)
                                            if let org = account.organizationName {
                                                Text(org)
                                                    .font(.system(size: 12))
                                                    .foregroundColor(Theme.Colors.textSecondary)
                                            }
                                        }
                                        Spacer()
                                        if let balance = account.balance {
                                            Text(String(format: "$%.2f", balance))
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundColor(balance < 0 ? Theme.Colors.expense : Theme.Colors.textPrimary)
                                        }
                                        Button {
                                            Task { await toggleAccount(account) }
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.system(size: 20))
                                                .foregroundColor(Color.gray.opacity(0.4))
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)

                                    if idx < linkedAccounts.count - 1 {
                                        Divider().padding(.leading, 16)
                                    }
                                }
                            }
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                        }

                        if let error = accountErrorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(Theme.Colors.expense)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)

                    // Budget Total Card
                    budgetTotalCard
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)

                    // Categories section header
                    HStack {
                        Text("CATEGORIES & AMOUNTS")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Theme.Colors.textSecondary)
                            .kerning(1.0)
                        Spacer()
                        Button {
                            showAddLineItem = true
                        } label: {
                            Text("+ Add / Remove")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Theme.Colors.primary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Theme.Colors.background)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                )
                                .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)

                    // Category rows
                    if isLoadingLineItems {
                        ProgressView()
                            .padding(.top, 40)
                    } else if categoryLineItems.isEmpty {
                        VStack(spacing: 12) {
                            Text("No categories yet")
                                .foregroundColor(Theme.Colors.textSecondary)
                                .font(.system(size: 14))
                            Button {
                                showAddLineItem = true
                            } label: {
                                Text("Add Categories")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Theme.Colors.primary)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                                    .background(Color(red: 0.96, green: 0.97, blue: 0.97))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.gray.opacity(0.25), lineWidth: 1)
                                    )
                                    .cornerRadius(12)
                            }
                        }
                        .padding(.top, 40)
                    } else {
                        VStack(spacing: 4) {
                            ForEach(Array(categoryLineItems.enumerated()), id: \.element.id) { idx, item in
                                CategoryEditRow(
                                    lineItem: item,
                                    category: allCategories.first { $0.id == item.categoryId },
                                    subcategoryLineItems: subcategoryLineItemsFor(categoryId: item.categoryId),
                                    subcategories: allCategories.first { $0.id == item.categoryId }?.subcategories ?? [],
                                    isExpanded: expandedCategories.contains(item.id),
                                    amountText: Binding(
                                        get: { editingAmounts[item.id] ?? String(format: "%.0f", item.amount) },
                                        set: { editingAmounts[item.id] = $0 }
                                    ),
                                    editingAmounts: $editingAmounts,
                                    onToggleExpand: {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            if expandedCategories.contains(item.id) {
                                                expandedCategories.remove(item.id)
                                            } else {
                                                expandedCategories.insert(item.id)
                                            }
                                        }
                                    },
                                    onAmountCommit: { newAmount in
                                        Task { await updateAmount(lineItem: item, newAmount: newAmount) }
                                    },
                                    onSubcategoryAmountCommit: { subItem, amount in
                                        Task { await updateAmount(lineItem: subItem, newAmount: amount) }
                                    },
                                    onSubcategoryCreate: { subcategoryId, amount in
                                        Task { await createSubcategoryLineItem(categoryId: item.categoryId, subcategoryId: subcategoryId, amount: amount) }
                                    },
                                    onRemove: {
                                        Task { await removeLineItem(item) }
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 6)
                    }

                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.horizontal, 20)
                            .padding(.top, 12)
                    }

                    // Month Overrides Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("MONTH OVERRIDES")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(Theme.Colors.textSecondary)
                                .kerning(1.0)
                            Spacer()
                            Button {
                                monthPickerDate = Date()
                                showMonthPicker = true
                            } label: {
                                Text("+ Add Month")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(Theme.Colors.primary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Theme.Colors.background)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                    )
                                    .cornerRadius(8)
                            }
                        }

                        // Info notification
                        if isDefault {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(Theme.Colors.primary)
                                    .font(.system(size: 13))
                                    .padding(.top, 1)
                                Text("This is your default budget and applies to all months automatically. Set a month override on another budget to use it for a specific month instead.")
                                    .font(.system(size: 12))
                                    .foregroundColor(Theme.Colors.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(12)
                            .background(Theme.Colors.primary.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Theme.Colors.primary.opacity(0.15), lineWidth: 1)
                            )
                            .cornerRadius(10)
                        } else if budgetMonths.isEmpty {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "calendar.badge.exclamationmark")
                                    .foregroundColor(.orange)
                                    .font(.system(size: 13))
                                    .padding(.top, 1)
                                Text("No month overrides set. The default budget applies to all months unless you add an override here.")
                                    .font(.system(size: 12))
                                    .foregroundColor(Theme.Colors.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(12)
                            .background(Color.orange.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.orange.opacity(0.15), lineWidth: 1)
                            )
                            .cornerRadius(10)
                        }

                        // Month pills
                        if !budgetMonths.isEmpty {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110))], spacing: 8) {
                                ForEach(budgetMonths) { month in
                                    HStack(spacing: 6) {
                                        Text(formatMonthString(month.month))
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(Theme.Colors.textPrimary)
                                        Spacer()
                                        Button {
                                            Task { await removeMonth(month) }
                                        } label: {
                                            Image(systemName: "xmark")
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundColor(Theme.Colors.expense)
                                        }
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color.white)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                    )
                                    .cornerRadius(8)
                                    .shadow(color: .black.opacity(0.04), radius: 2)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 28)

                    // Delete button
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        HStack(spacing: 8) {
                            if isDeleting {
                                ProgressView().tint(Theme.Colors.expense)
                            } else {
                                Image(systemName: "trash")
                                Text("Delete Budget")
                            }
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Theme.Colors.expense)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Theme.Colors.expense.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Theme.Colors.expense.opacity(0.3), lineWidth: 1)
                        )
                        .cornerRadius(12)
                    }
                    .disabled(isDeleting || isSaving)
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 100)
                }
                .padding(.top, 8)
            }

            // Floating tip gradient
            VStack(spacing: 0) {
                LinearGradient(
                    gradient: Gradient(colors: [.clear, Theme.Colors.background]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 36)
                Text("Tap amounts to edit  ·  Expand categories for details")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Theme.Colors.textSecondary)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity)
                    .background(Theme.Colors.background)
            }
        }
        .navigationTitle(name.isEmpty ? "Edit Budget" : name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if isSaving {
                    ProgressView()
                } else {
                    Button("Save") { Task { await save() } }
                        .fontWeight(.semibold)
                        .foregroundColor(Theme.Colors.primary)
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
        .task { await loadLineItemsAndCategories() }
        .sheet(isPresented: $showAddLineItem, onDismiss: {
            Task { await loadLineItemsAndCategories() }
        }) {
            ManageBudgetCategoriesView(
                budgetId: budget.id,
                apiClient: apiClient,
                existingLineItems: lineItems,
                allCategories: allCategories
            )
        }
        .sheet(isPresented: $showAddAccount) {
            NavigationStack {
                Group {
                    if unlinkedAccounts.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 48))
                                .foregroundColor(Theme.Colors.primary)
                            Text("All accounts are already linked to this budget")
                                .font(.subheadline)
                                .foregroundColor(Theme.Colors.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List(unlinkedAccounts) { account in
                            Button {
                                Task {
                                    await toggleAccount(account)
                                    if unlinkedAccounts.isEmpty { showAddAccount = false }
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(account.name)
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundColor(Theme.Colors.textPrimary)
                                        if let org = account.organizationName {
                                            Text(org)
                                                .font(.system(size: 13))
                                                .foregroundColor(Theme.Colors.textSecondary)
                                        }
                                    }
                                    Spacer()
                                    if let balance = account.balance {
                                        Text(String(format: "$%.2f", balance))
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(balance < 0 ? Theme.Colors.expense : Theme.Colors.textPrimary)
                                    }
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(Theme.Colors.primary)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                        .listStyle(.insetGrouped)
                    }
                }
                .navigationTitle("Add Account")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { showAddAccount = false }
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showMonthPicker) {
            NavigationStack {
                VStack(spacing: 0) {
                    DatePicker(
                        "Select Month",
                        selection: $monthPickerDate,
                        in: ...Date(),
                        displayedComponents: [.date]
                    )
                    .datePickerStyle(.graphical)
                    .padding()
                }
                .navigationTitle("Choose Month Override")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") { showMonthPicker = false }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Add Override") {
                            showMonthPicker = false
                            Task { await addMonth(monthPickerDate) }
                        }
                        .fontWeight(.semibold)
                        .foregroundColor(Theme.Colors.primary)
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showEmojiEditor) {
            NavigationStack {
                VStack(spacing: 24) {
                    Text(emojiInput.isEmpty ? emoji : emojiInput)
                        .font(.system(size: 72))
                        .padding(.top, 32)

                    TextField("Type or paste an emoji", text: $emojiInput)
                        .font(.system(size: 28))
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal, 40)

                    Text("Tap the text field and use the emoji keyboard (🌐) to pick one")
                        .font(.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)

                    Spacer()
                }
                .navigationTitle("Choose Emoji")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") { showEmojiEditor = false }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            let first = emojiInput.unicodeScalars.first
                            if let scalar = first, scalar.properties.isEmoji {
                                emoji = String(emojiInput.prefix(2))
                            } else if !emojiInput.isEmpty {
                                emoji = String(emojiInput.prefix(2))
                            }
                            showEmojiEditor = false
                        }
                        .fontWeight(.semibold)
                        .foregroundColor(Theme.Colors.primary)
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }

    // MARK: - Budget Total Card

    @ViewBuilder
    private var budgetTotalCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("TOTAL BUDGET")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Theme.Colors.textSecondary)
                        .kerning(0.5)
                    Text(formatAmount(totalBudget))
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                        .foregroundColor(Theme.Colors.textPrimary)
                        .kerning(-1)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("CATEGORIES")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Theme.Colors.textSecondary)
                        .kerning(0.5)
                    Text("\(categoryLineItems.count)")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Theme.Colors.textSecondary)
                }
            }

            if totalBudget > 0 && !categoryLineItems.isEmpty {
                GeometryReader { geometry in
                    HStack(spacing: 3) {
                        ForEach(Array(categoryLineItems.enumerated()), id: \.element.id) { idx, item in
                            let pct = CGFloat(item.amount / totalBudget)
                            let w = max(4, (geometry.size.width - CGFloat(categoryLineItems.count - 1) * 3) * pct)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color(hex: categoryColorFor(id: item.categoryId, index: idx)))
                                .frame(width: w)
                        }
                    }
                }
                .frame(height: 6)
                .cornerRadius(3)
                .padding(.top, 18)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(Array(categoryLineItems.enumerated()), id: \.element.id) { idx, item in
                            HStack(spacing: 5) {
                                Circle()
                                    .fill(Color(hex: categoryColorFor(id: item.categoryId, index: idx)))
                                    .frame(width: 7, height: 7)
                                Text(allCategories.first { $0.id == item.categoryId }?.name ?? "Category")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(Theme.Colors.textSecondary)
                            }
                        }
                    }
                }
                .padding(.top, 12)
            }
        }
        .padding(22)
        .background(Color.white)
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.07), radius: 8, x: 0, y: 2)
        .animation(.easeInOut(duration: 0.3), value: totalBudget)
    }

    private func categoryColorFor(id: String, index: Int) -> String {
        allCategories.first(where: { $0.id == id })?.color
            ?? fallbackColors[index % fallbackColors.count]
    }

    private func formatAmount(_ amount: Double) -> String {
        let fmt = NumberFormatter()
        fmt.numberStyle = .currency
        fmt.currencyCode = "USD"
        fmt.maximumFractionDigits = 0
        fmt.minimumFractionDigits = 0
        return fmt.string(from: NSNumber(value: amount)) ?? "$\(Int(amount))"
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
                isDefault: isDefault != budget.isDefault ? isDefault : nil,
                emoji: emoji != (budget.emoji ?? "💰") ? emoji : nil,
                color: selectedColor != (budget.color ?? "#00A699") ? selectedColor : nil
            )
            onSave(updated)
            dismiss()
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
            dismiss()
        } catch {
            errorMessage = "Failed to delete: \(error.localizedDescription)"
            isDeleting = false
        }
    }

    private func loadLineItemsAndCategories() async {
        isLoadingLineItems = true
        do {
            async let lineItemsFetch = apiClient.fetchBudgetLineItems(budgetId: budget.id)
            async let categoriesFetch = apiClient.fetchCategoriesTree()
            async let monthsFetch = apiClient.fetchBudgetMonths()
            async let linkedFetch = apiClient.listBudgetAccounts(budgetId: budget.id)
            let (items, cats, months, linked) = try await (lineItemsFetch, categoriesFetch, monthsFetch, linkedFetch)
            lineItems = items
            allCategories = cats
            budgetMonths = months.filter { $0.budgetId == budget.id }
            linkedAccountIds = Set(linked.map { $0.accountId })
        } catch {
            // silently fail — categories section stays empty
        }
        isLoadingLineItems = false

        // Load all available accounts separately (non-critical)
        do {
            allAccounts = try await loadAllAccounts()
        } catch {
            // silently fail if no accounts connected
        }
        isLoadingAccounts = false
    }

    private func loadAllAccounts() async throws -> [SimplefinAccount] {
        let items = try await apiClient.listSimplefinItems()
        var accounts: [SimplefinAccount] = []
        for item in items {
            let accs = try await apiClient.listSimplefinAccounts(itemId: item.id)
            accounts.append(contentsOf: accs)
        }
        return accounts
    }

    private func formatMonthString(_ monthStr: String) -> String {
        let parts = monthStr.split(separator: "-")
        guard parts.count == 2,
              let year = Int(parts[0]),
              let month = Int(parts[1]) else { return monthStr }
        let dateComponents = DateComponents(year: year, month: month)
        guard let date = Calendar.current.date(from: dateComponents) else { return monthStr }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter.string(from: date)
    }

    private func addMonth(_ date: Date) async {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        let monthStr = String(format: "%04d-%02d", year, month)
        do {
            let newMonth = try await apiClient.assignBudgetMonth(budgetId: budget.id, month: monthStr)
            budgetMonths.append(newMonth)
        } catch {
            errorMessage = "Failed to add month override: \(error.localizedDescription)"
        }
    }

    private func removeMonth(_ month: BudgetMonth) async {
        do {
            try await apiClient.deleteBudgetMonth(monthId: month.id)
            budgetMonths.removeAll { $0.id == month.id }
        } catch {
            errorMessage = "Failed to remove month override"
        }
    }

    private func toggleAccount(_ account: SimplefinAccount) async {
        let isLinked = linkedAccountIds.contains(account.id)
        accountErrorMessage = nil

        if isLinked {
            linkedAccountIds.remove(account.id)
            do {
                try await apiClient.removeBudgetAccount(budgetId: budget.id, accountId: account.id)
            } catch {
                linkedAccountIds.insert(account.id)
                accountErrorMessage = "Failed to remove account"
            }
        } else {
            linkedAccountIds.insert(account.id)
            do {
                _ = try await apiClient.addBudgetAccount(budgetId: budget.id, accountId: account.id)
            } catch {
                linkedAccountIds.remove(account.id)
                let desc = error.localizedDescription
                accountErrorMessage = desc.contains("already linked") ? "This account is already linked to another budget" : "Failed to add account"
            }
        }
    }

    private func updateAmount(lineItem: BudgetLineItem, newAmount: Double) async {
        guard newAmount >= 0, newAmount != lineItem.amount else {
            editingAmounts.removeValue(forKey: lineItem.id)
            return
        }
        do {
            let updated = try await apiClient.updateBudgetLineItem(
                budgetId: budget.id,
                lineItemId: lineItem.id,
                amount: newAmount
            )
            if let idx = lineItems.firstIndex(where: { $0.id == lineItem.id }) {
                lineItems[idx] = updated
            }
            editingAmounts.removeValue(forKey: lineItem.id)
        } catch {
            errorMessage = "Failed to update amount"
        }
    }

    private func createSubcategoryLineItem(categoryId: String, subcategoryId: String, amount: Double) async {
        guard amount > 0 else { return }
        do {
            let newItem = try await apiClient.createBudgetLineItem(
                budgetId: budget.id,
                categoryId: categoryId,
                subcategoryId: subcategoryId,
                amount: amount
            )
            lineItems.append(newItem)
            editingAmounts.removeValue(forKey: "new_\(subcategoryId)")
        } catch {
            errorMessage = "Failed to set subcategory budget"
        }
    }

    private func removeLineItem(_ item: BudgetLineItem) async {
        do {
            try await apiClient.deleteBudgetLineItem(budgetId: budget.id, lineItemId: item.id)
            lineItems.removeAll { $0.id == item.id }
            expandedCategories.remove(item.id)
            editingAmounts.removeValue(forKey: item.id)
        } catch {
            // silently fail — user can try again
        }
    }
}

// MARK: - Manage Budget Categories View

private struct ManageBudgetCategoriesView: View {
    let budgetId: String
    let apiClient: APIClient

    @Environment(\.dismiss) private var dismiss
    @State private var categories: [CategoryWithSubcategories] = []
    @State private var lineItems: [BudgetLineItem] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedForAdd: CategoryWithSubcategories?
    @State private var showAddCategory = false
    @State private var addAmountText = ""
    @State private var isAddingSaving = false

    init(budgetId: String, apiClient: APIClient, existingLineItems: [BudgetLineItem], allCategories: [CategoryWithSubcategories]) {
        self.budgetId = budgetId
        self.apiClient = apiClient
        _lineItems = State(initialValue: existingLineItems)
        _categories = State(initialValue: allCategories)
    }

    private func categoryLineItem(for cat: CategoryWithSubcategories) -> BudgetLineItem? {
        lineItems.first { $0.categoryId == cat.id && $0.subcategoryId == nil }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    // Create new category button
                    Button {
                        showAddCategory = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(Theme.Colors.primary)
                            Text("Create New Category")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(Theme.Colors.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12))
                                .foregroundColor(Theme.Colors.primary.opacity(0.6))
                        }
                        .padding(16)
                        .background(Theme.Colors.primary.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Theme.Colors.primary.opacity(0.2), lineWidth: 1)
                        )
                        .cornerRadius(14)
                    }
                    .padding(.horizontal, 16)

                    if isLoading {
                        ProgressView()
                            .padding(.top, 40)
                    } else {
                        ForEach(categories) { cat in
                            let lineItem = categoryLineItem(for: cat)
                            CategoryManageRow(
                                category: cat,
                                lineItem: lineItem,
                                onAdd: {
                                    selectedForAdd = cat
                                    addAmountText = ""
                                },
                                onRemove: {
                                    Task { await removeCategory(cat) }
                                }
                            )
                            .padding(.horizontal, 16)
                        }
                    }

                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.horizontal, 16)
                    }
                }
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
            .background(Theme.Colors.background)
            .navigationTitle("Manage Categories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundColor(Theme.Colors.primary)
                }
            }
            .sheet(item: $selectedForAdd) { cat in
                NavigationStack {
                    VStack(spacing: 24) {
                        VStack(spacing: 10) {
                            Text(cat.icon)
                                .font(.system(size: 52))
                                .frame(width: 90, height: 90)
                                .background(Color(hex: cat.color).opacity(0.15))
                                .cornerRadius(20)
                            Text(cat.name)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(Theme.Colors.textPrimary)
                        }
                        .padding(.top, 20)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Monthly Budget Amount")
                                .font(.headline)
                                .foregroundColor(Theme.Colors.textPrimary)
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text("$")
                                    .font(.title)
                                    .foregroundColor(Theme.Colors.textPrimary)
                                TextField("0", text: $addAmountText)
                                    .font(.system(size: 36, weight: .bold))
                                    .keyboardType(.decimalPad)
                                    .foregroundColor(Theme.Colors.textPrimary)
                            }
                        }
                        .padding(.horizontal, 32)

                        Spacer()
                    }
                    .navigationTitle("Set Budget Amount")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Cancel") { selectedForAdd = nil }
                        }
                        ToolbarItem(placement: .navigationBarTrailing) {
                            if isAddingSaving {
                                ProgressView()
                            } else {
                                Button("Add") {
                                    guard let amount = Double(addAmountText), amount > 0 else { return }
                                    Task { await addCategory(cat, amount: amount) }
                                }
                                .fontWeight(.semibold)
                                .foregroundColor(Theme.Colors.primary)
                                .disabled(Double(addAmountText) == nil || addAmountText.isEmpty)
                            }
                        }
                    }
                }
                .presentationDetents([.medium])
            }
            .sheet(isPresented: $showAddCategory) {
                AddCategoryView(isPresented: $showAddCategory, apiClient: apiClient) { _ in
                    // Reload categories after creating one
                    Task { await reloadCategories() }
                }
            }
        }
        .task {
            isLoading = false
        }
    }

    private func addCategory(_ cat: CategoryWithSubcategories, amount: Double) async {
        isAddingSaving = true
        do {
            let newItem = try await apiClient.createBudgetLineItem(
                budgetId: budgetId,
                categoryId: cat.id,
                subcategoryId: nil,
                amount: amount
            )
            lineItems.append(newItem)
            selectedForAdd = nil
        } catch {
            errorMessage = "Failed to add category: \(error.localizedDescription)"
        }
        isAddingSaving = false
    }

    private func removeCategory(_ cat: CategoryWithSubcategories) async {
        guard let lineItem = lineItems.first(where: { $0.categoryId == cat.id && $0.subcategoryId == nil }) else { return }
        do {
            try await apiClient.deleteBudgetLineItem(budgetId: budgetId, lineItemId: lineItem.id)
            lineItems.removeAll { $0.id == lineItem.id }
        } catch {
            errorMessage = "Failed to remove category: \(error.localizedDescription)"
        }
    }

    private func reloadCategories() async {
        if let cats = try? await apiClient.fetchCategoriesTree() {
            categories = cats
        }
    }
}

// MARK: - Category Manage Row

private struct CategoryManageRow: View {
    let category: CategoryWithSubcategories
    let lineItem: BudgetLineItem?
    let onAdd: () -> Void
    let onRemove: () -> Void

    var isInBudget: Bool { lineItem != nil }

    var body: some View {
        HStack(spacing: 14) {
            Text(category.icon)
                .font(.system(size: 24))
                .frame(width: 46, height: 46)
                .background(Color(hex: category.color).opacity(0.15))
                .cornerRadius(12)

            VStack(alignment: .leading, spacing: 3) {
                Text(category.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Theme.Colors.textPrimary)
                    .lineLimit(1)
                if let lineItem = lineItem {
                    Text("$\(String(format: "%.0f", lineItem.amount)) / month")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.Colors.primary)
                } else {
                    Text("Not in budget")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.Colors.textSecondary)
                }
            }

            Spacer()

            if isInBudget {
                Button(action: onRemove) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 26))
                        .foregroundColor(Theme.Colors.primary)
                }
            } else {
                Button(action: onAdd) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 26))
                        .foregroundColor(Theme.Colors.textSecondary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.white)
        .cornerRadius(14)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 1)
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
                        } else if category.id != "uncategorized" {
                            Text("Set Budget")
                                .font(.caption)
                                .foregroundColor(category.color)
                        }

                        // Edit budget button (not shown for uncategorized)
                        if category.id != "uncategorized" {
                            Button {
                                showEditCategoryBudget = true
                            } label: {
                                Image(systemName: "pencil.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(category.color.opacity(0.7))
                            }
                            .buttonStyle(.plain)
                        }
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
