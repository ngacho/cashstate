import SwiftUI

struct MainView: View {
    @Binding var isAuthenticated: Bool
    let apiClient: APIClient

    var body: some View {
        TabView {
            HomeView(apiClient: apiClient)
                .tabItem {
                    Label("Overview", systemImage: "house.fill")
                }

            BudgetView(apiClient: apiClient)
                .tabItem {
                    Label("Budget", systemImage: "chart.pie.fill")
                }

            InsightsView(apiClient: apiClient)
                .tabItem {
                    Label("Insights", systemImage: "chart.pie.fill")
                }

            AccountsView(isAuthenticated: $isAuthenticated, apiClient: apiClient)
                .tabItem {
                    Label("Accounts", systemImage: "person.crop.circle")
                }
        }
        .tint(Theme.Colors.primary)
    }
}

struct TransactionsView: View {
    let apiClient: APIClient
    @State private var transactions: [Transaction] = []
    @State private var isLoading = false

    var body: some View {
        NavigationView {
            Group {
                if isLoading && transactions.isEmpty {
                    VStack {
                        ProgressView()
                            .padding()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.Colors.background)
                } else if transactions.isEmpty {
                    VStack(spacing: Theme.Spacing.md) {
                        Image(systemName: "list.bullet.rectangle")
                            .font(.system(size: 60))
                            .foregroundColor(Theme.Colors.primary.opacity(0.6))
                        Text("No transactions yet")
                            .font(.headline)
                            .foregroundColor(Theme.Colors.textPrimary)
                        Text("Connect your bank in the Accounts tab to sync transactions")
                            .font(.subheadline)
                            .foregroundColor(Theme.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, Theme.Spacing.xl)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.Colors.background)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(transactions) { transaction in
                                MintTransactionRow(transaction: transaction)
                                if transaction.id != transactions.last?.id {
                                    Divider()
                                        .padding(.leading, 60)
                                }
                            }
                        }
                        .background(Theme.Colors.cardBackground)
                        .cornerRadius(Theme.CornerRadius.md)
                        .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
                        .padding(Theme.Spacing.md)
                    }
                    .background(Theme.Colors.background)
                }
            }
            .navigationTitle("Transactions")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable {
                await loadTransactions()
            }
            .task {
                await loadTransactions()
            }
        }
    }

    func loadTransactions() async {
        isLoading = true
        defer { isLoading = false }

        do {
            transactions = try await apiClient.listSimplefinTransactions(limit: 200)
        } catch {
            // Silently fail and show empty state - no data synced yet
            print("Failed to load transactions: \(error)")
        }
    }
}

// MARK: - Mint Transaction Row

struct MintTransactionRow: View {
    let transaction: Transaction

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Icon
            ZStack {
                Circle()
                    .fill(iconBackgroundColor)
                    .frame(width: 44, height: 44)
                Image(systemName: transaction.isExpense ? "arrow.up" : "arrow.down")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(iconColor)
            }

            // Transaction info
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(Theme.Colors.textPrimary)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text(transaction.displayDate)
                        .font(.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                    if transaction.pending {
                        Text("• Pending")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }

            Spacer()

            // Amount
            Text(transaction.isExpense ? "-\(transaction.displayAmount)" : "+\(transaction.displayAmount)")
                .font(.body)
                .fontWeight(.semibold)
                .foregroundColor(transaction.isExpense ? Theme.Colors.expense : Theme.Colors.income)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .background(Theme.Colors.cardBackground)
        .contentShape(Rectangle())
    }

    var iconBackgroundColor: Color {
        transaction.isExpense ? Theme.Colors.expense.opacity(0.15) : Theme.Colors.income.opacity(0.15)
    }

    var iconColor: Color {
        transaction.isExpense ? Theme.Colors.expense : Theme.Colors.income
    }
}

struct InsightsView: View {
    let apiClient: APIClient
    @State private var selectedRange: TimeRange = .month
    @State private var transactions: [Transaction] = []
    @State private var isLoading = false
    @State private var showChart = true // true = donut chart, false = bar graph

    var filteredTransactions: [Transaction] {
        let calendar = Calendar.current
        let now = Date()

        return transactions.filter { transaction in
            // Convert Unix timestamp to Date
            let transactionDate = Date(timeIntervalSince1970: TimeInterval(transaction.postedDate))

            switch selectedRange {
            case .day:
                return calendar.isDateInToday(transactionDate)
            case .week:
                return calendar.isDate(transactionDate, equalTo: now, toGranularity: .weekOfYear)
            case .month:
                return calendar.isDate(transactionDate, equalTo: now, toGranularity: .month)
            case .year:
                return calendar.isDate(transactionDate, equalTo: now, toGranularity: .year)
            case .custom:
                return true // Show all for custom
            }
        }
    }

    var totalSpent: Double {
        filteredTransactions
            .filter { $0.amount < 0 }
            .reduce(0) { $0 + abs($1.amount) }
    }

    var totalIncome: Double {
        filteredTransactions
            .filter { $0.amount > 0 }
            .reduce(0) { $0 + $1.amount }
    }

    var netAmount: Double {
        totalIncome - totalSpent
    }

    struct CategorySpending {
        let category: String
        let amount: Double
    }

    var categoryBreakdown: [CategorySpending] {
        // SimpleFin doesn't provide categories yet
        // Group by payee/merchant for now
        var merchantTotals: [String: Double] = [:]

        for transaction in filteredTransactions where transaction.amount < 0 {
            let merchant = transaction.payee ?? transaction.description
            merchantTotals[merchant, default: 0] += abs(transaction.amount)
        }

        return merchantTotals.map { CategorySpending(category: $0.key, amount: $0.value) }
            .sorted { $0.amount > $1.amount }
    }

    struct DailySpending: Identifiable {
        let id = UUID()
        let date: String
        let amount: Double
        var dayLabel: String {
            String(date.split(separator: "-").last ?? "")
        }
    }

    var dailySpending: [DailySpending] {
        var dailyTotals: [String: Double] = [:]
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        for transaction in filteredTransactions where transaction.amount < 0 {
            let date = Date(timeIntervalSince1970: TimeInterval(transaction.postedDate))
            let dateString = formatter.string(from: date)
            dailyTotals[dateString, default: 0] += abs(transaction.amount)
        }

        return dailyTotals.map { DailySpending(date: $0.key, amount: $0.value) }
    }

    var maxDailySpending: Double {
        dailySpending.map { $0.amount }.max() ?? 1
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {

                    if isLoading {
                        ProgressView()
                            .padding(.top, 60)
                    } else if transactions.isEmpty {
                        VStack(spacing: Theme.Spacing.md) {
                            Image(systemName: "chart.pie.fill")
                                .font(.system(size: 60))
                                .foregroundColor(Theme.Colors.primary.opacity(0.6))
                            Text("No insights yet")
                                .font(.headline)
                                .foregroundColor(Theme.Colors.textPrimary)
                            Text("Transaction data will appear here once you sync your accounts")
                                .font(.subheadline)
                                .foregroundColor(Theme.Colors.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, Theme.Spacing.xl)
                        }
                        .padding(.top, 60)
                    } else {
                        // Chart type toggle
                        HStack {
                            Spacer()
                            Picker("View", selection: $showChart) {
                                Text("Chart").tag(true)
                                Text("Graph").tag(false)
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 180)
                        }
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.top, Theme.Spacing.sm)
                        // Donut Chart or Bar Graph
                        if showChart {
                            // Donut Chart View
                            VStack(spacing: Theme.Spacing.md) {
                                ZStack {
                                    // Donut chart
                                    DonutChart(
                                        categories: categoryBreakdown.prefix(5).map { $0 },
                                        total: totalSpent
                                    )
                                    .frame(height: 240)

                                    // Total in center
                                    VStack(spacing: 4) {
                                        Text("Total spent")
                                            .font(.caption)
                                            .foregroundColor(Theme.Colors.textSecondary)
                                        Text("$\(String(format: "%.2f", totalSpent))")
                                            .font(.system(size: 28, weight: .bold))
                                            .foregroundColor(Theme.Colors.textPrimary)
                                    }
                                }
                                .padding(.horizontal, Theme.Spacing.md)

                                // Legend
                                if !categoryBreakdown.isEmpty {
                                    VStack(spacing: Theme.Spacing.xs) {
                                        ForEach(Array(categoryBreakdown.prefix(5).enumerated()), id: \.element.category) { index, item in
                                            HStack(spacing: Theme.Spacing.sm) {
                                                Circle()
                                                    .fill(categoryColor(for: index))
                                                    .frame(width: 12, height: 12)
                                                Text(item.category)
                                                    .font(.subheadline)
                                                    .foregroundColor(Theme.Colors.textPrimary)
                                                    .lineLimit(1)
                                                Spacer()
                                                Text("\(Int((item.amount / totalSpent) * 100))%")
                                                    .font(.subheadline)
                                                    .fontWeight(.semibold)
                                                    .foregroundColor(Theme.Colors.textSecondary)
                                            }
                                            .padding(.horizontal, Theme.Spacing.md)
                                        }
                                    }
                                    .padding(.vertical, Theme.Spacing.sm)
                                }
                            }
                        } else {
                            // Bar Graph View
                            if !dailySpending.isEmpty {
                                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                                    Text("Daily Activity")
                                        .font(.headline)
                                        .foregroundColor(Theme.Colors.textPrimary)
                                        .padding(.horizontal, Theme.Spacing.md)

                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(alignment: .bottom, spacing: 8) {
                                            ForEach(dailySpending.sorted(by: { $0.date < $1.date }), id: \.date) { day in
                                                VStack(spacing: 4) {
                                                    RoundedRectangle(cornerRadius: 4)
                                                        .fill(Theme.Colors.primary)
                                                        .frame(width: 32, height: max(day.amount / maxDailySpending * 120, 6))
                                                    Text("\(day.dayLabel)")
                                                        .font(.caption2)
                                                        .foregroundColor(Theme.Colors.textSecondary)
                                                }
                                            }
                                        }
                                        .padding()
                                    }
                                    .frame(height: 170)
                                    .background(Theme.Colors.cardBackground)
                                    .cornerRadius(Theme.CornerRadius.md)
                                    .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
                                    .padding(.horizontal, Theme.Spacing.md)
                                }
                            }
                        }

                        // Summary cards (always show)
                        HStack(spacing: Theme.Spacing.sm) {
                            SummaryCard(
                                title: "Income",
                                amount: totalIncome,
                                color: Theme.Colors.income,
                                icon: "arrow.down.circle.fill"
                            )
                            SummaryCard(
                                title: "Spent",
                                amount: totalSpent,
                                color: Theme.Colors.expense,
                                icon: "arrow.up.circle.fill"
                            )
                        }
                        .padding(.horizontal, Theme.Spacing.md)

                        // Net amount card
                        HStack(spacing: Theme.Spacing.md) {
                            ZStack {
                                Circle()
                                    .fill((netAmount >= 0 ? Theme.Colors.income : Theme.Colors.expense).opacity(0.15))
                                    .frame(width: 48, height: 48)
                                Image(systemName: "equal.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(netAmount >= 0 ? Theme.Colors.income : Theme.Colors.expense)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Net")
                                    .font(.subheadline)
                                    .foregroundColor(Theme.Colors.textSecondary)
                                Text(String(format: "$%.2f", abs(netAmount)))
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(Theme.Colors.textPrimary)
                            }

                            Spacer()

                            Text("\(filteredTransactions.count) transactions")
                                .font(.caption)
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                        .padding(Theme.Spacing.md)
                        .background(Theme.Colors.cardBackground)
                        .cornerRadius(Theme.CornerRadius.md)
                        .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
                        .padding(.horizontal, Theme.Spacing.md)

                        // Transactions preview
                        if !filteredTransactions.isEmpty {
                            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                                HStack {
                                    Text("Transactions")
                                        .font(.headline)
                                        .foregroundColor(Theme.Colors.textPrimary)
                                    Spacer()
                                    Text("\(filteredTransactions.count) total")
                                        .font(.caption)
                                        .foregroundColor(Theme.Colors.textSecondary)
                                }
                                .padding(.horizontal, Theme.Spacing.md)
                            }
                        }
                    }

                    Spacer(minLength: Theme.Spacing.lg)
                }
            }
            .navigationTitle("Analytics")
            .navigationBarTitleDisplayMode(.inline)
            .background(Theme.Colors.background)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Picker("Period", selection: $selectedRange) {
                            ForEach([TimeRange.day, .week, .month, .year], id: \.self) { range in
                                Text(range.rawValue).tag(range)
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(selectedRange.rawValue)
                                .font(.subheadline)
                                .foregroundColor(Theme.Colors.textPrimary)
                            Image(systemName: "chevron.down")
                                .font(.caption)
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                    }
                }
            }
            .refreshable {
                await loadTransactions()
            }
            .task {
                await loadTransactions()
            }
        }
    }

    func loadTransactions() async {
        isLoading = true
        defer { isLoading = false }

        do {
            transactions = try await apiClient.listSimplefinTransactions(limit: 200)
        } catch {
            // Silent fail for insights - user can refresh
            print("Failed to load transactions: \(error)")
        }
    }

    func categoryColor(for index: Int) -> Color {
        let colors = [
            Theme.Colors.categoryBlue,
            Theme.Colors.categoryPurple,
            Theme.Colors.categoryPink,
            Theme.Colors.categoryOrange,
            Theme.Colors.categoryYellow
        ]
        return colors[index % colors.count]
    }
}

// MARK: - Donut Chart

struct DonutChart: View {
    let categories: [InsightsView.CategorySpending]
    let total: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(Array(categories.enumerated()), id: \.element.category) { index, category in
                    DonutSlice(
                        startAngle: startAngle(for: index),
                        endAngle: endAngle(for: index),
                        color: colorForIndex(index)
                    )
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.width)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    func startAngle(for index: Int) -> Angle {
        let previousTotal = categories.prefix(index).reduce(0.0) { $0 + $1.amount }
        return Angle(degrees: (previousTotal / total) * 360 - 90)
    }

    func endAngle(for index: Int) -> Angle {
        let currentTotal = categories.prefix(index + 1).reduce(0.0) { $0 + $1.amount }
        return Angle(degrees: (currentTotal / total) * 360 - 90)
    }

    func colorForIndex(_ index: Int) -> Color {
        let colors = [
            Theme.Colors.categoryBlue,
            Theme.Colors.categoryPurple,
            Theme.Colors.categoryPink,
            Theme.Colors.categoryOrange,
            Theme.Colors.categoryYellow
        ]
        return colors[index % colors.count]
    }
}

struct DonutSlice: View {
    let startAngle: Angle
    let endAngle: Angle
    let color: Color

    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
                let radius = min(geometry.size.width, geometry.size.height) / 2
                let innerRadius = radius * 0.6 // Donut hole

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

struct SummaryCard: View {
    let title: String
    let amount: Double
    let color: Color
    let icon: String

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Icon circle
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 48, height: 48)
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(Theme.Colors.textSecondary)
                Text(String(format: "$%.2f", amount))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(Theme.Colors.textPrimary)
            }

            Spacer()
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.cardBackground)
        .cornerRadius(Theme.CornerRadius.md)
        .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
    }
}

struct CategoryRow: View {
    let category: String
    let amount: Double
    let percentage: Double

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(category)
                        .font(.body)
                        .foregroundColor(Theme.Colors.textPrimary)
                        .lineLimit(1)
                    Spacer()
                    Text(String(format: "$%.2f", amount))
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(Theme.Colors.textPrimary)
                }

                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.gray.opacity(0.15))
                            .frame(height: 6)

                        RoundedRectangle(cornerRadius: 3)
                            .fill(Theme.Colors.primary)
                            .frame(width: geometry.size.width * percentage, height: 6)
                    }
                }
                .frame(height: 6)
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
    }
}

struct BudgetsView: View {
    let apiClient: APIClient

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    Text("Budget Management")
                        .font(.title2)
                        .foregroundColor(Theme.Colors.textSecondary)
                        .padding()

                    Text("Coming soon: Set category budgets and track spending goals")
                        .font(.body)
                        .foregroundColor(Theme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle("Budgets")
            .background(Theme.Colors.background)
        }
    }
}

struct AccountsView: View {
    @Binding var isAuthenticated: Bool
    let apiClient: APIClient
    @State private var simplefinItems: [SimplefinItem] = []
    @State private var showSimplefinSetup = false
    @State private var isLoading = false
    @State private var isSyncing = false
    @State private var syncErrorMessage: String?
    @State private var showSyncError = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    // Connection Section
                    VStack(spacing: Theme.Spacing.md) {
                        if simplefinItems.isEmpty {
                            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                                HStack {
                                    ZStack {
                                        Circle()
                                            .fill(Theme.Colors.primary.opacity(0.15))
                                            .frame(width: 48, height: 48)
                                        Image(systemName: "building.columns.fill")
                                            .font(.title3)
                                            .foregroundColor(Theme.Colors.primary)
                                    }

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Connect Your Banks")
                                            .font(.headline)
                                            .foregroundColor(Theme.Colors.textPrimary)
                                        Text("Sync all your accounts and transactions")
                                            .font(.caption)
                                            .foregroundColor(Theme.Colors.textSecondary)
                                    }
                                    Spacer()
                                }
                                .padding(Theme.Spacing.md)

                                Button {
                                    showSimplefinSetup = true
                                } label: {
                                    HStack {
                                        Image(systemName: "link.circle.fill")
                                            .font(.body)
                                        Text("Connect SimpleFin")
                                            .fontWeight(.semibold)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(Theme.Spacing.md)
                                    .background(Theme.Colors.primary)
                                    .foregroundColor(.white)
                                    .cornerRadius(Theme.CornerRadius.md)
                                }
                                .padding(.horizontal, Theme.Spacing.md)
                                .padding(.bottom, Theme.Spacing.sm)
                            }
                            .background(Theme.Colors.cardBackground)
                            .cornerRadius(Theme.CornerRadius.md)
                            .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
                        } else {
                            // Connected status
                            HStack(spacing: Theme.Spacing.md) {
                                ZStack {
                                    Circle()
                                        .fill(Theme.Colors.income.opacity(0.15))
                                        .frame(width: 48, height: 48)
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.title3)
                                        .foregroundColor(Theme.Colors.income)
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("SimpleFin Connected")
                                        .font(.body)
                                        .fontWeight(.semibold)
                                        .foregroundColor(Theme.Colors.textPrimary)
                                    if let item = simplefinItems.first, let lastSynced = item.lastSyncedAt {
                                        Text("Last synced: \(formatDate(lastSynced))")
                                            .font(.caption)
                                            .foregroundColor(Theme.Colors.textSecondary)
                                    }
                                }

                                Spacer()

                                if isSyncing {
                                    ProgressView()
                                } else {
                                    Button {
                                        if let item = simplefinItems.first {
                                            Task {
                                                await syncItem(item.id)
                                            }
                                        }
                                    } label: {
                                        Image(systemName: "arrow.clockwise")
                                            .font(.body)
                                            .foregroundColor(Theme.Colors.primary)
                                            .padding(Theme.Spacing.sm)
                                            .background(Theme.Colors.primary.opacity(0.1))
                                            .clipShape(Circle())
                                    }
                                }
                            }
                            .padding(Theme.Spacing.md)
                            .background(Theme.Colors.cardBackground)
                            .cornerRadius(Theme.CornerRadius.md)
                            .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.top, Theme.Spacing.sm)

                    // Settings Section
                    VStack(spacing: 0) {
                        Button {
                            Task {
                                await apiClient.clearStoredToken()
                                isAuthenticated = false
                            }
                        } label: {
                            HStack {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .foregroundColor(Theme.Colors.expense)
                                Text("Sign Out")
                                    .foregroundColor(Theme.Colors.expense)
                                Spacer()
                            }
                            .padding(Theme.Spacing.md)
                            .background(Theme.Colors.cardBackground)
                            .contentShape(Rectangle())
                        }
                    }
                    .cornerRadius(Theme.CornerRadius.md)
                    .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
                    .padding(.horizontal, Theme.Spacing.md)

                    Spacer()
                }
                .padding(.vertical, Theme.Spacing.sm)
            }
            .background(Theme.Colors.background)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable {
                await loadSimplefinItems()
            }
            .task {
                await loadSimplefinItems()
            }
            .sheet(isPresented: $showSimplefinSetup) {
                SimplefinSetupView(apiClient: apiClient) { itemId in
                    Task {
                        await loadSimplefinItems()
                        // Auto-sync after setup with force_sync=true (new account)
                        await syncItem(itemId, forceSync: true)
                    }
                }
            }
            .alert("Sync Error", isPresented: $showSyncError) {
                Button("OK") { }
            } message: {
                Text(syncErrorMessage ?? "Failed to sync transactions")
            }
        }
    }

    private func loadSimplefinItems() async {
        isLoading = true
        defer { isLoading = false }

        do {
            simplefinItems = try await apiClient.listSimplefinItems()
        } catch {
            print("Failed to load SimpleFin items: \(error)")
        }
    }

    private func syncItem(_ itemId: String, forceSync: Bool = false) async {
        isSyncing = true
        defer { isSyncing = false }

        do {
            // Get Dec 31 of previous year (beginning of current year transactions)
            let calendar = Calendar.current
            let currentYear = calendar.component(.year, from: Date())
            let prevYearEnd = calendar.date(from: DateComponents(year: currentYear - 1, month: 12, day: 31))!
            let startTimestamp = Int(prevYearEnd.timeIntervalSince1970)

            let response = try await apiClient.syncSimplefin(
                itemId: itemId,
                startDate: startTimestamp,
                forceSync: forceSync
            )
            print("✅ Synced \(response.accountsSynced) accounts, \(response.transactionsAdded) transactions")

            // Reload items to update last synced time
            await loadSimplefinItems()
        } catch let error as APIError {
            await MainActor.run {
                syncErrorMessage = error.localizedDescription
                showSyncError = true
            }
            print("Failed to sync: \(error)")
        } catch {
            await MainActor.run {
                syncErrorMessage = error.localizedDescription
                showSyncError = true
            }
            print("Failed to sync: \(error)")
        }
    }

    private func formatDate(_ dateString: String) -> String {
        // Simple date formatting - could be improved
        let components = dateString.split(separator: "T")
        return String(components.first ?? "")
    }
}
