import SwiftUI

import Charts

struct HomeView: View {
    let apiClient: APIClient
    @State private var simplefinItems: [SimplefinItem] = []
    @State private var accounts: [SimplefinAccount] = []
    @State private var snapshots: [SnapshotData] = []
    @State private var isLoading = false
    @State private var isSyncing = false
    @State private var isLoadingSnapshots = false
    @State private var showSyncSuccess = false
    @State private var selectedTimeRange: TimeRange = .week
    @State private var selectedDate = Date()

    var totalBalance: Double {
        accounts.compactMap { $0.balance }.reduce(0, +)
    }

    // Group accounts by type (Mint style)
    struct AccountGroup {
        let type: String
        let accounts: [SimplefinAccount]
        let totalBalance: String

        var total: Double {
            accounts.compactMap { $0.balance }.reduce(0, +)
        }
    }

    var accountGroups: [AccountGroup] {
        // Categorize accounts
        var cash: [SimplefinAccount] = []
        var creditCards: [SimplefinAccount] = []
        var investments: [SimplefinAccount] = []
        var other: [SimplefinAccount] = []

        for account in accounts {
            let name = account.name.lowercased()
            if name.contains("credit") || name.contains("card") {
                creditCards.append(account)
            } else if name.contains("investment") || name.contains("brokerage") || name.contains("401k") || name.contains("ira") {
                investments.append(account)
            } else if name.contains("checking") || name.contains("chequing") || name.contains("saving") || name.contains("cash") {
                cash.append(account)
            } else {
                other.append(account)
            }
        }

        var groups: [AccountGroup] = []

        if !cash.isEmpty {
            let total = cash.compactMap { $0.balance }.reduce(0, +)
            groups.append(AccountGroup(
                type: "Cash",
                accounts: cash,
                totalBalance: String(format: "$%.2f", total)
            ))
        }

        if !creditCards.isEmpty {
            let total = creditCards.compactMap { $0.balance }.reduce(0, +)
            groups.append(AccountGroup(
                type: "Credit cards",
                accounts: creditCards,
                totalBalance: String(format: "$%.2f", total)
            ))
        }

        if !investments.isEmpty {
            let total = investments.compactMap { $0.balance }.reduce(0, +)
            groups.append(AccountGroup(
                type: "Investments",
                accounts: investments,
                totalBalance: String(format: "$%.2f", total)
            ))
        }

        if !other.isEmpty {
            let total = other.compactMap { $0.balance }.reduce(0, +)
            groups.append(AccountGroup(
                type: "Other",
                accounts: other,
                totalBalance: String(format: "$%.2f", total)
            ))
        }

        return groups
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.md) {
                    // Mint-style Hero Card
                    VStack(spacing: Theme.Spacing.md) {
                        // Header
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Net Worth")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(Theme.Colors.textOnPrimary.opacity(0.9))
                            }
                            Spacer()
                            // Sync button in header
                            if isSyncing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                                    .frame(width: 36, height: 36)
                                    .background(Color.white.opacity(0.2))
                                    .clipShape(Circle())
                            } else {
                                Button(action: {
                                    Task { await resyncAllAccounts() }
                                }) {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(Theme.Colors.textOnPrimary)
                                        .frame(width: 36, height: 36)
                                        .background(Color.white.opacity(0.2))
                                        .clipShape(Circle())
                                }
                                .disabled(simplefinItems.isEmpty)
                            }
                        }

                        // Balance
                        Text("$\(String(format: "%.2f", totalBalance))")
                            .font(.system(size: 48, weight: .bold))
                            .foregroundColor(Theme.Colors.textOnPrimary)

                        // Account count
                        Text("\(accounts.count) account\(accounts.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundColor(Theme.Colors.textOnPrimary.opacity(0.8))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(Theme.Spacing.lg)
                    .background(
                        LinearGradient(
                            colors: totalBalance < 0
                                ? [Theme.Colors.expense, Theme.Colors.expense.opacity(0.8)]
                                : [Theme.Colors.income, Theme.Colors.income.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(Theme.CornerRadius.xl)
                    .shadow(color: (totalBalance < 0 ? Theme.Colors.expense : Theme.Colors.income).opacity(0.3), radius: 12, x: 0, y: 6)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.top, Theme.Spacing.md)

                    // Net Worth Chart Section
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        HStack {
                            Text("NET WORTH")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(Theme.Colors.textSecondary)
                            Spacer()
                            Picker("Period", selection: $selectedTimeRange) {
                                Text("Week").tag(TimeRange.week)
                                Text("Month").tag(TimeRange.month)
                                Text("Year").tag(TimeRange.year)
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 180)
                        }
                        .padding(.horizontal, Theme.Spacing.md)

                        if isLoadingSnapshots {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .frame(height: 200)
                        } else if snapshots.isEmpty {
                            VStack(spacing: Theme.Spacing.sm) {
                                Image(systemName: "chart.line.uptrend.xyaxis")
                                    .font(.system(size: 40))
                                    .foregroundColor(Theme.Colors.textSecondary.opacity(0.5))
                                Text("No data yet")
                                    .font(.caption)
                                    .foregroundColor(Theme.Colors.textSecondary)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 200)
                            .background(Theme.Colors.cardBackground)
                            .cornerRadius(Theme.CornerRadius.lg)
                            .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
                            .padding(.horizontal, Theme.Spacing.md)
                        } else {
                            NetWorthChart(snapshots: snapshots)
                                .frame(height: 200)
                                .padding(Theme.Spacing.md)
                                .background(Theme.Colors.cardBackground)
                                .cornerRadius(Theme.CornerRadius.lg)
                                .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
                                .padding(.horizontal, Theme.Spacing.md)
                        }
                    }

                    // Accounts Section
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else if accounts.isEmpty {
                        VStack(spacing: Theme.Spacing.md) {
                            Image(systemName: "creditcard.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(Theme.Colors.primary.opacity(0.6))
                            Text("No accounts connected")
                                .font(.headline)
                                .foregroundColor(Theme.Colors.textPrimary)
                            Text("Connect your bank in the Accounts tab to get started")
                                .font(.subheadline)
                                .foregroundColor(Theme.Colors.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, Theme.Spacing.xl)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                    } else {
                        // Grouped Accounts (Mint style)
                        VStack(spacing: Theme.Spacing.md) {
                            ForEach(accountGroups, id: \.type) { group in
                                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                                    // Group header
                                    HStack {
                                        Text(group.type.uppercased())
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundColor(Theme.Colors.textSecondary)
                                        Spacer()
                                        Text(formattedTotal(group.total))
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(group.total < 0 ? Theme.Colors.expense : Theme.Colors.textPrimary)
                                    }
                                    .padding(.horizontal, Theme.Spacing.md)
                                    .padding(.bottom, 4)

                                    // Accounts in group
                                    VStack(spacing: 1) {
                                        ForEach(group.accounts) { account in
                                            NavigationLink(destination: AccountDetailView(
                                                apiClient: apiClient,
                                                account: account
                                            )) {
                                                MintAccountRow(account: account)
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                        }
                                    }
                                    .background(Theme.Colors.cardBackground)
                                    .cornerRadius(Theme.CornerRadius.md)
                                    .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
                                }
                                .padding(.horizontal, Theme.Spacing.md)
                            }
                        }
                    }
                }
                .padding(.vertical, Theme.Spacing.sm)
            }
            .background(Theme.Colors.background)
            .navigationBarHidden(true)
            .refreshable {
                await loadAccounts()
                await loadSnapshots()
            }
            .task {
                await loadAccounts()
                await loadSnapshots()
            }
            .onChange(of: selectedTimeRange) { _, _ in
                Task {
                    await loadSnapshots()
                }
            }
            .alert("Sync Complete", isPresented: $showSyncSuccess) {
                Button("OK") { }
            } message: {
                Text("All accounts have been synced successfully")
            }
        }
    }

    private func formattedTotal(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? "$0.00"
    }

    func loadAccounts() async {
        isLoading = true
        defer { isLoading = false }

        do {
            // Load SimpleFin items first
            simplefinItems = try await apiClient.listSimplefinItems()

            // Load accounts for each item
            var allAccounts: [SimplefinAccount] = []
            for item in simplefinItems {
                let itemAccounts = try await apiClient.listSimplefinAccounts(itemId: item.id)
                allAccounts.append(contentsOf: itemAccounts)
            }
            accounts = allAccounts
        } catch {
            // Silently fail and show empty state - no accounts connected yet
            print("Failed to load accounts: \(error)")
        }
    }

    func loadSnapshots() async {
        isLoadingSnapshots = true
        defer { isLoadingSnapshots = false }

        do {
            let (startDate, endDate, granularity) = calculateDateRange()
            let response = try await apiClient.getSnapshots(
                startDate: startDate,
                endDate: endDate,
                granularity: granularity
            )
            snapshots = response.data
        } catch {
            // Silently fail and show empty state
            print("Failed to load snapshots: \(error)")
        }
    }

    func calculateDateRange() -> (Date, Date, String) {
        let calendar = Calendar.current
        let endDate = calendar.startOfDay(for: selectedDate)

        switch selectedTimeRange {
        case .week:
            // Show 7 days ending at today, daily granularity
            let startDate = calendar.date(byAdding: .day, value: -6, to: endDate)!
            return (startDate, endDate, "day")

        case .month:
            // Show 30 days ending at today, daily granularity
            let startDate = calendar.date(byAdding: .day, value: -29, to: endDate)!
            return (startDate, endDate, "day")

        case .year:
            // Show 12 months ending at today, monthly granularity
            let startDate = calendar.date(byAdding: .month, value: -11, to: endDate)!
            return (startDate, endDate, "month")

        default:
            // Default to month view
            let startDate = calendar.date(byAdding: .day, value: -29, to: endDate)!
            return (startDate, endDate, "day")
        }
    }

    func resyncAllAccounts() async {
        guard !simplefinItems.isEmpty else { return }

        isSyncing = true
        defer { isSyncing = false }

        do {
            // Get start date (Dec 31 of previous year)
            let calendar = Calendar.current
            let currentYear = calendar.component(.year, from: Date())
            let prevYearEnd = calendar.date(from: DateComponents(year: currentYear - 1, month: 12, day: 31))!
            let startTimestamp = Int(prevYearEnd.timeIntervalSince1970)

            // Sync all items with force_sync=true
            for item in simplefinItems {
                print("Syncing item: \(item.id)")
                let response = try await apiClient.syncSimplefin(
                    itemId: item.id,
                    startDate: startTimestamp,
                    forceSync: true
                )
                print("✅ Synced \(response.accountsSynced) accounts, \(response.transactionsAdded) transactions")
            }

            // Reload accounts to show updated balances
            await loadAccounts()

            // Calculate snapshots from the synced transactions
            print("Calculating snapshots...")
            try? await apiClient.calculateSnapshots()

            // Reload snapshots to show the chart
            await loadSnapshots()

            // Show success message
            await MainActor.run {
                showSyncSuccess = true
            }
        } catch {
            // Log error but don't show alert - sync errors are already handled in AccountsView
            print("Failed to sync: \(error)")
        }
    }
}

// MARK: - Net Worth Chart (Smooth Line)

struct NetWorthChart: View {
    let snapshots: [SnapshotData]

    var minBalance: Double {
        snapshots.map { $0.balance }.min() ?? 0
    }

    var maxBalance: Double {
        snapshots.map { $0.balance }.max() ?? 0
    }

    var currentBalance: Double {
        snapshots.last?.balance ?? 0
    }

    var chartColor: Color {
        // Use red if balance is negative, green if positive
        currentBalance < 0 ? Theme.Colors.expense : Theme.Colors.income
    }

    var chartYDomain: ClosedRange<Double> {
        guard !snapshots.isEmpty else {
            return 0...100 // Default range for empty data
        }

        // If all values are the same, add padding
        if minBalance == maxBalance {
            let value = minBalance
            if value == 0 {
                return -10...10
            } else if value > 0 {
                return 0...(value * 1.2)
            } else {
                return (value * 1.2)...0
            }
        }

        // Calculate padding (5% of range)
        let range = maxBalance - minBalance
        let padding = range * 0.05

        return (minBalance - padding)...(maxBalance + padding)
    }

    var body: some View {
        if snapshots.isEmpty {
            // Empty state
            VStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.largeTitle)
                    .foregroundColor(Theme.Colors.textSecondary.opacity(0.5))
                Text("No snapshot data")
                    .font(.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            // Chart with 1+ points
            Chart(snapshots) { snapshot in
                LineMark(
                    x: .value("Date", snapshot.dateValue),
                    y: .value("Balance", snapshot.balance)
                )
                .foregroundStyle(chartColor)
                .interpolationMethod(.catmullRom) // Smooth curve
                .lineStyle(StrokeStyle(lineWidth: 3))

                // Area fill under the line
                AreaMark(
                    x: .value("Date", snapshot.dateValue),
                    y: .value("Balance", snapshot.balance)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            chartColor.opacity(0.3),
                            chartColor.opacity(0.05)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { value in
                    if let date = value.as(Date.self) {
                        AxisValueLabel {
                            Text(formatAxisDate(date))
                                .font(.caption2)
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(Color.gray.opacity(0.2))
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                    if let balance = value.as(Double.self) {
                        AxisValueLabel {
                            Text(formatCurrency(balance))
                                .font(.caption2)
                                .foregroundColor(balance < 0 ? Theme.Colors.expense : (balance > 0 ? Theme.Colors.income : Theme.Colors.textSecondary))
                        }
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(Color.gray.opacity(0.2))
                    }
                }
            }
            .chartYScale(domain: chartYDomain)
        }
    }

    func formatAxisDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        if snapshots.count > 30 {
            // Monthly view - show month
            formatter.dateFormat = "MMM"
        } else {
            // Daily/weekly view - show day
            formatter.dateFormat = "M/d"
        }
        return formatter.string(from: date)
    }

    func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        formatter.currencySymbol = "$"
        return formatter.string(from: NSNumber(value: value)) ?? "$0"
    }
}

// MARK: - Mint-style Account Row

struct MintAccountRow: View {
    let account: SimplefinAccount

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Bank Icon (rounded square, colored background)
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(iconBackgroundColor)
                    .frame(width: 44, height: 44)
                Image(systemName: accountIcon)
                    .font(.system(size: 18))
                    .foregroundColor(iconColor)
            }

            // Account Info
            VStack(alignment: .leading, spacing: 4) {
                Text(account.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(Theme.Colors.textPrimary)
                if let org = account.organizationName {
                    HStack(spacing: 4) {
                        Text(org)
                            .font(.caption)
                            .foregroundColor(Theme.Colors.textSecondary)
                        if account.balanceDate != nil {
                            Text("• Just now")
                                .font(.caption)
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                    }
                }
            }

            Spacer()

            // Balance
            Text(account.displayBalance)
                .font(.body)
                .fontWeight(.semibold)
                .foregroundColor(balanceColor)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .contentShape(Rectangle())
    }

    var accountIcon: String {
        let name = account.name.lowercased()
        if name.contains("credit") || name.contains("card") {
            return "creditcard.fill"
        } else if name.contains("checking") || name.contains("chequing") {
            return "banknote.fill"
        } else if name.contains("saving") {
            return "dollarsign.circle.fill"
        } else if name.contains("investment") || name.contains("brokerage") {
            return "chart.line.uptrend.xyaxis.circle.fill"
        } else {
            return "building.columns.circle.fill"
        }
    }

    var iconBackgroundColor: Color {
        let name = account.name.lowercased()
        if name.contains("credit") || name.contains("card") {
            return Color(hex: "FEE2E2")
        } else if name.contains("checking") || name.contains("chequing") {
            return Color(hex: "DCFCE7")
        } else if name.contains("saving") {
            return Color(hex: "DBEAFE")
        } else if name.contains("investment") {
            return Color(hex: "F3E8FF")
        } else {
            return Theme.Colors.primary.opacity(0.1)
        }
    }

    var iconColor: Color {
        let name = account.name.lowercased()
        if name.contains("credit") || name.contains("card") {
            return Color(hex: "DC2626")
        } else if name.contains("checking") || name.contains("chequing") {
            return Color(hex: "16A34A")
        } else if name.contains("saving") {
            return Color(hex: "2563EB")
        } else if name.contains("investment") {
            return Color(hex: "9333EA")
        } else {
            return Theme.Colors.primary
        }
    }

    var balanceColor: Color {
        guard let balance = account.balance else { return Theme.Colors.textPrimary }
        // Transactions are already signed correctly: negative = bad, positive = good
        return balance < 0 ? Theme.Colors.expense : Theme.Colors.textPrimary
    }
}

// MARK: - Account Detail View

struct AccountDetailView: View {
    let apiClient: APIClient
    let account: SimplefinAccount

    @State private var transactions: [Transaction] = []
    @State private var isLoading = false
    @State private var isLoadingCategories = true
    @State private var selectedTab: TransactionTab = .all
    @State private var selectedTransaction: Transaction?
    @State private var showTransactionDetail = false
    @State private var allCategories: [BudgetCategory] = []
    @State private var selectedTimeRange: TimeRange = .month
    @State private var selectedDate = Date()
    @State private var customStartDate = Date()
    @State private var customEndDate = Date()
    @State private var showDatePicker = false
    @State private var selectedChartType: ChartType = .balance

    enum ChartType: String, CaseIterable {
        case balance = "Balance Trend"
        case transactions = "Spending vs Credit"

        var displayName: String {
            switch self {
            case .balance: return "Balance"
            case .transactions: return "Spending"
            }
        }
    }

    enum TransactionTab: String, CaseIterable {
        case all = "All"
        case spent = "Spent"
        case credit = "Credit"

        var icon: String {
            switch self {
            case .all: return "list.bullet"
            case .spent: return "arrow.up.circle.fill"
            case .credit: return "arrow.down.circle.fill"
            }
        }
    }

    // Smart granularity: determine how to visualize custom ranges
    var effectiveTimeRange: TimeRange {
        guard selectedTimeRange == .custom else {
            return selectedTimeRange
        }

        let calendar = Calendar.current
        let daysDiff = calendar.dateComponents([.day], from: customStartDate, to: customEndDate).day ?? 0

        if daysDiff <= 7 {
            return .week  // Show daily like week view
        } else if daysDiff <= 30 {
            return .month  // Show daily like month view
        } else if daysDiff <= 365 {
            return .year  // Show monthly like year view
        } else {
            return .year  // Show annually (treat as year for now)
        }
    }

    var filteredTransactions: [Transaction] {
        let calendar = Calendar.current

        // Filter by time range
        let timeFiltered = transactions.filter { transaction in
            let transactionDate = Date(timeIntervalSince1970: TimeInterval(transaction.postedDate))

            switch selectedTimeRange {
            case .day:
                // Same day as selectedDate
                return calendar.isDate(transactionDate, inSameDayAs: selectedDate)

            case .week:
                // 7 days ending at selectedDate (past week)
                guard let weekStart = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: selectedDate)) else {
                    return false
                }
                return transactionDate >= calendar.startOfDay(for: weekStart) &&
                       transactionDate <= calendar.startOfDay(for: selectedDate).addingTimeInterval(86399)

            case .month:
                // Same month and year as selectedDate
                return calendar.isDate(transactionDate, equalTo: selectedDate, toGranularity: .month)

            case .year:
                // Same year as selectedDate
                return calendar.isDate(transactionDate, equalTo: selectedDate, toGranularity: .year)

            case .custom:
                // Between customStartDate and customEndDate
                let startOfDay = calendar.startOfDay(for: customStartDate)
                let endOfDay = calendar.startOfDay(for: customEndDate).addingTimeInterval(86399)
                return transactionDate >= startOfDay && transactionDate <= endOfDay
            }
        }

        // Filter by transaction type
        switch selectedTab {
        case .all:
            return timeFiltered
        case .spent:
            return timeFiltered.filter { $0.amount < 0 }
        case .credit:
            return timeFiltered.filter { $0.amount > 0 }
        }
    }

    var totalSpent: Double {
        filteredTransactions.filter { $0.amount < 0 }.reduce(0) { $0 + abs($1.amount) }
    }

    var totalCredit: Double {
        filteredTransactions.filter { $0.amount > 0 }.reduce(0) { $0 + $1.amount }
    }

    var netAmount: Double {
        filteredTransactions.reduce(0) { $0 + $1.amount }
    }

    // Spending breakdown by merchant
    struct MerchantSpending: Identifiable {
        let id = UUID()
        let merchant: String
        let amount: Double
    }

    var merchantBreakdown: [MerchantSpending] {
        var merchantTotals: [String: Double] = [:]

        for transaction in filteredTransactions where transaction.amount < 0 {
            let merchant = transaction.payee ?? transaction.description ?? ""
            merchantTotals[merchant, default: 0] += abs(transaction.amount)
        }

        return merchantTotals.map { MerchantSpending(merchant: $0.key, amount: $0.value) }
            .sorted { $0.amount > $1.amount }
    }

    var dateRangeText: String {
        let formatter = DateFormatter()

        switch selectedTimeRange {
        case .day:
            formatter.dateStyle = .medium
            return formatter.string(from: selectedDate)

        case .week:
            formatter.dateFormat = "MMM d"
            let calendar = Calendar.current
            guard let weekStart = calendar.date(byAdding: .day, value: -6, to: selectedDate) else {
                return formatter.string(from: selectedDate)
            }
            return "\(formatter.string(from: weekStart)) - \(formatter.string(from: selectedDate))"

        case .month:
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: selectedDate)

        case .year:
            formatter.dateFormat = "yyyy"
            return formatter.string(from: selectedDate)

        case .custom:
            formatter.dateStyle = .short
            return "\(formatter.string(from: customStartDate)) - \(formatter.string(from: customEndDate))"
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.md) {

                // Account Summary Card
                VStack(spacing: 6) {
                    Text(account.name)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(Theme.Colors.textPrimary)
                    if let org = account.organizationName {
                        Text(org)
                            .font(.subheadline)
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                    Text(account.displayBalance)
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor((account.balance ?? 0) < 0 ? Theme.Colors.expense : Theme.Colors.primary)
                        .padding(.top, 4)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.lg)
                .padding(.horizontal, Theme.Spacing.md)
                .background(Theme.Colors.cardBackground)
                .cornerRadius(Theme.CornerRadius.xl)
                .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
                .padding(.horizontal, Theme.Spacing.md)

                // Time Range Picker
                Picker("Period", selection: $selectedTimeRange) {
                    Text("Week").tag(TimeRange.week)
                    Text("Month").tag(TimeRange.month)
                    Text("Year").tag(TimeRange.year)
                    Text("Custom").tag(TimeRange.custom)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, Theme.Spacing.md)

                // Date Range Selector
                Button(action: { showDatePicker = true }) {
                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: "calendar")
                            .font(.system(size: 15))
                            .foregroundColor(Theme.Colors.primary)
                        Text(dateRangeText)
                            .font(.subheadline)
                            .foregroundColor(Theme.Colors.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(Theme.Colors.cardBackground)
                    .cornerRadius(Theme.CornerRadius.md)
                    .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
                }
                .padding(.horizontal, Theme.Spacing.md)

                // Chart Card: toggle + chart together
                VStack(spacing: 0) {
                    // Chart type toggle inside the card
                    Picker("Chart Type", selection: $selectedChartType) {
                        ForEach(ChartType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.top, Theme.Spacing.md)
                    .padding(.bottom, Theme.Spacing.sm)

                    // Chart
                    Group {
                        switch selectedChartType {
                        case .balance:
                            AccountBalanceChart(
                                transactions: filteredTransactions,
                                currentBalance: account.balance ?? 0,
                                timeRange: effectiveTimeRange
                            )
                        case .transactions:
                            SpendingCreditChart(
                                transactions: filteredTransactions,
                                timeRange: effectiveTimeRange
                            )
                        }
                    }
                    .frame(height: 180)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.bottom, Theme.Spacing.md)
                }
                .background(Theme.Colors.cardBackground)
                .cornerRadius(Theme.CornerRadius.xl)
                .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
                .padding(.horizontal, Theme.Spacing.md)

                // Spending Breakdown Section
                if !filteredTransactions.isEmpty && totalSpent > 0 {
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        // Section header
                        Text("SPENDING BREAKDOWN")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(Theme.Colors.textSecondary)
                            .padding(.horizontal, Theme.Spacing.md)

                        // Donut + Merchant list in one card
                        VStack(spacing: 0) {
                            // Donut Chart with centered total
                            ZStack {
                                DonutChart(
                                    categories: merchantBreakdown.prefix(5).map {
                                        InsightsView.CategorySpending(category: $0.merchant, amount: $0.amount)
                                    },
                                    total: totalSpent
                                )
                                .frame(height: 200)
                                VStack(spacing: 2) {
                                    Text("Total spent")
                                        .font(.caption)
                                        .foregroundColor(Theme.Colors.textSecondary)
                                    Text("$\(String(format: "%.0f", totalSpent))")
                                        .font(.system(size: 22, weight: .bold))
                                        .foregroundColor(Theme.Colors.textPrimary)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, Theme.Spacing.md)

                            // Merchant Legend
                            if !merchantBreakdown.isEmpty {
                                VStack(spacing: 0) {
                                    ForEach(Array(merchantBreakdown.prefix(5).enumerated()), id: \.element.id) { index, item in
                                        HStack(spacing: Theme.Spacing.sm) {
                                            Circle()
                                                .fill(categoryColor(for: index))
                                                .frame(width: 10, height: 10)
                                            Text(item.merchant)
                                                .font(.subheadline)
                                                .foregroundColor(Theme.Colors.textPrimary)
                                                .lineLimit(1)
                                            Spacer()
                                            Text("\(Int((item.amount / totalSpent) * 100))%")
                                                .font(.subheadline)
                                                .foregroundColor(Theme.Colors.textSecondary)
                                                .frame(width: 36, alignment: .trailing)
                                            Text("$\(String(format: "%.2f", item.amount))")
                                                .font(.subheadline)
                                                .fontWeight(.semibold)
                                                .foregroundColor(Theme.Colors.textPrimary)
                                                .frame(width: 72, alignment: .trailing)
                                        }
                                        .padding(.horizontal, Theme.Spacing.md)
                                        .padding(.vertical, 10)

                                        if index < min(merchantBreakdown.count, 5) - 1 {
                                            Divider().padding(.leading, Theme.Spacing.md)
                                        }
                                    }
                                }
                                .padding(.bottom, Theme.Spacing.sm)
                            }
                        }
                        .background(Theme.Colors.cardBackground)
                        .cornerRadius(Theme.CornerRadius.xl)
                        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
                        .padding(.horizontal, Theme.Spacing.md)
                    }
                }

                // Stats Row (Spent / Credit / Net) — unified card
                HStack(spacing: 0) {
                    // Spent
                    VStack(alignment: .center, spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(Theme.Colors.expense)
                            Text("Spent")
                                .font(.caption)
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                        Text("$\(String(format: "%.0f", totalSpent))")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(Theme.Colors.expense)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                    .frame(maxWidth: .infinity)

                    Divider()
                        .frame(height: 40)

                    // Credit
                    VStack(alignment: .center, spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(Theme.Colors.income)
                            Text("Credit")
                                .font(.caption)
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                        Text("$\(String(format: "%.0f", totalCredit))")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(Theme.Colors.income)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                    .frame(maxWidth: .infinity)

                    Divider()
                        .frame(height: 40)

                    // Net
                    VStack(alignment: .center, spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "equal.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(netAmount >= 0 ? Theme.Colors.income : Theme.Colors.expense)
                            Text("Net")
                                .font(.caption)
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                        Text("$\(String(format: "%.0f", abs(netAmount)))")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(netAmount >= 0 ? Theme.Colors.income : Theme.Colors.expense)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.vertical, 14)
                .background(Theme.Colors.cardBackground)
                .cornerRadius(Theme.CornerRadius.md)
                .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
                .padding(.horizontal, Theme.Spacing.md)

                // Transaction Filter Tabs + List
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    // Tabs
                    Picker("Type", selection: $selectedTab) {
                        ForEach(TransactionTab.allCases, id: \.self) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)

                    // Transaction count
                    Text("\(filteredTransactions.count) TRANSACTION\(filteredTransactions.count == 1 ? "" : "S")")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(Theme.Colors.textSecondary)

                    // Transaction list
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else if filteredTransactions.isEmpty {
                        VStack(spacing: Theme.Spacing.sm) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 36))
                                .foregroundColor(Theme.Colors.textSecondary.opacity(0.5))
                            Text("No transactions")
                                .font(.subheadline)
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(filteredTransactions) { transaction in
                                TransactionRow(transaction: transaction)
                                    .onTapGesture {
                                        selectedTransaction = transaction
                                        showTransactionDetail = true
                                    }
                                if transaction.id != filteredTransactions.last?.id {
                                    Divider()
                                        .padding(.leading, 60)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)
            }
            .padding(.vertical, Theme.Spacing.md)
        }
        .background(Theme.Colors.background)
        .navigationTitle("Account Details")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await loadTransactions()
        }
        .task {
            await loadTransactions()
            await loadCategories()
        }
        .sheet(isPresented: $showTransactionDetail) {
            if let transaction = selectedTransaction {
                TransactionDetailView(
                    transaction: transaction,
                    categories: allCategories,
                    apiClient: apiClient,
                    isPresented: $showTransactionDetail,
                    onCategoryUpdated: .constant({ _, _ in
                        Task {
                            await loadTransactions()
                        }
                    })
                )
            }
        }
        .sheet(isPresented: $showDatePicker) {
            DateRangePickerView(
                timeRange: selectedTimeRange,
                selectedDate: $selectedDate,
                customStartDate: $customStartDate,
                customEndDate: $customEndDate
            )
        }
    }

    func loadCategories() async {
        isLoadingCategories = true
        defer { isLoadingCategories = false }

        do {
            // Fetch the category tree (includes all categories and subcategories)
            let treeResponse = try await apiClient.fetchCategoriesTree()

            // Convert to BudgetCategory model
            allCategories = treeResponse.map { item in
                BudgetCategory(
                    id: item.id,
                    name: item.name,
                    icon: item.icon,
                    colorHex: item.color,  // Use hex color directly from database
                    type: (item.type == "income") ? .income : .expense,
                    subcategories: item.subcategories.map { sub in
                        BudgetSubcategory(
                            id: sub.id,
                            name: sub.name,
                            icon: sub.icon,
                            budgetAmount: nil,
                            spentAmount: 0,
                            transactionCount: 0
                        )
                    },
                    budgetAmount: nil,
                    spentAmount: 0
                )
            }
        } catch {
            // Silently fail - we can still show transactions without category options
            print("Failed to load categories: \(error)")
        }
    }

    func loadTransactions() async {
        isLoading = true
        defer { isLoading = false }

        do {
            // Load all transactions and filter by account
            let response = try await apiClient.listSimplefinTransactions(limit: 500)
            transactions = response.items.filter { $0.simplefinAccountId == account.id }
        } catch {
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

// MARK: - Transaction Row

struct TransactionRow: View {
    let transaction: Transaction

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Icon with circle background (matches MintTransactionRow)
            ZStack {
                Circle()
                    .fill(iconBackgroundColor)
                    .frame(width: 44, height: 44)
                Image(systemName: transaction.isExpense ? "arrow.up" : "arrow.down")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(iconColor)
            }

            // Info
            VStack(alignment: .leading, spacing: 3) {
                Text(transaction.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(Theme.Colors.textPrimary)
                    .lineLimit(1)
                Text(transaction.displayDate)
                    .font(.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
            }

            Spacer()

            // Amount
            Text(transaction.displayAmount)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(transaction.isExpense ? Theme.Colors.expense : Theme.Colors.income)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .contentShape(Rectangle())
    }

    var iconBackgroundColor: Color {
        transaction.isExpense ? Theme.Colors.expense.opacity(0.15) : Theme.Colors.income.opacity(0.15)
    }

    var iconColor: Color {
        transaction.isExpense ? Theme.Colors.expense : Theme.Colors.income
    }
}

// MARK: - Transaction Chart

struct TransactionChart: View {
    let transactions: [Transaction]
    let timeRange: TimeRange

    var dailyData: [(date: Date, amount: Double)] {
        let calendar = Calendar.current
        var dailyTotals: [Date: Double] = [:]

        for transaction in transactions where transaction.amount < 0 {
            let date = Date(timeIntervalSince1970: TimeInterval(transaction.postedDate))
            let startOfDay = calendar.startOfDay(for: date)
            dailyTotals[startOfDay, default: 0] += abs(transaction.amount)
        }

        return dailyTotals.map { ($0.key, $0.value) }.sorted { $0.date < $1.date }
    }

    var maxAmount: Double {
        dailyData.map { $0.amount }.max() ?? 1
    }

    var body: some View {
        GeometryReader { geometry in
            if dailyData.isEmpty {
                Text("No data")
                    .foregroundColor(Theme.Colors.textSecondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HStack(alignment: .bottom, spacing: 4) {
                    ForEach(Array(dailyData.enumerated()), id: \.offset) { index, data in
                        VStack {
                            Spacer()
                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    LinearGradient(
                                        colors: [Theme.Colors.primary, Theme.Colors.primary.opacity(0.6)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(
                                    width: max((geometry.size.width / CGFloat(dailyData.count)) - 8, 8),
                                    height: max((data.amount / maxAmount) * (geometry.size.height - 30), 4)
                                )
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

// MARK: - Account Balance Chart

struct AccountBalanceChart: View {
    let transactions: [Transaction]
    let currentBalance: Double
    let timeRange: TimeRange

    struct BalancePoint: Identifiable {
        let id = UUID()
        let date: Date
        let balance: Double
    }

    var balancePoints: [BalancePoint] {
        let calendar = Calendar.current

        // Sort transactions by date (oldest first)
        let sortedTransactions = transactions.sorted {
            $0.postedDate < $1.postedDate
        }

        guard !sortedTransactions.isEmpty else { return [] }

        // Calculate starting balance by working backwards from current balance
        let totalChange = sortedTransactions.reduce(0.0) { $0 + $1.amount }
        var runningBalance = currentBalance - totalChange

        // Create data points for each transaction date
        var points: [BalancePoint] = []
        var dailyBalances: [Date: Double] = [:]

        // Add starting point
        if let firstDate = sortedTransactions.first?.postedDate {
            let transactionDate = Date(timeIntervalSince1970: TimeInterval(firstDate))
            let startDate: Date

            if timeRange == .year {
                // For year view, group by month
                startDate = calendar.date(from: calendar.dateComponents([.year, .month], from: transactionDate)) ?? calendar.startOfDay(for: transactionDate)
            } else {
                // For other views, group by day
                startDate = calendar.startOfDay(for: transactionDate)
            }

            dailyBalances[startDate] = runningBalance
        }

        // Calculate balance after each transaction
        for transaction in sortedTransactions {
            let transactionDate = Date(timeIntervalSince1970: TimeInterval(transaction.postedDate))
            let key: Date

            // Group by day or month depending on time range
            if timeRange == .year {
                // For year view, group by month
                key = calendar.date(from: calendar.dateComponents([.year, .month], from: transactionDate)) ?? calendar.startOfDay(for: transactionDate)
            } else {
                // For other views, group by day
                key = calendar.startOfDay(for: transactionDate)
            }

            runningBalance += transaction.amount
            // Keep the latest balance for each period (day or month)
            dailyBalances[key] = runningBalance
        }

        // Convert to sorted points
        points = dailyBalances.map { BalancePoint(date: $0.key, balance: $0.value) }
            .sorted { $0.date < $1.date }

        // Add current balance as final point
        if let lastTransaction = sortedTransactions.last {
            let lastDate = Date(timeIntervalSince1970: TimeInterval(lastTransaction.postedDate))
            let today = Date()

            // Only add "today" point if it's different from last transaction date
            if !calendar.isDate(lastDate, inSameDayAs: today) {
                points.append(BalancePoint(date: today, balance: currentBalance))
            }
        }

        return points
    }

    var minBalance: Double {
        balancePoints.map { $0.balance }.min() ?? 0
    }

    var maxBalance: Double {
        balancePoints.map { $0.balance }.max() ?? 0
    }

    var chartColor: Color {
        // Use red if balance is negative, teal if positive
        currentBalance < 0 ? Theme.Colors.expense : Theme.Colors.primary
    }

    var chartYDomain: ClosedRange<Double> {
        guard !balancePoints.isEmpty else {
            return 0...100 // Default range for empty data
        }

        let min = minBalance
        let max = maxBalance

        // If all values are the same, add padding
        if min == max {
            let value = min
            if value == 0 {
                return -10...10
            } else if value > 0 {
                return 0...(value * 1.2)
            } else {
                return (value * 1.2)...0
            }
        }

        // Calculate padding based on the range
        let range = max - min
        let padding = range * 0.1

        // Extend the domain in both directions
        let lowerBound = min < 0 ? min - padding : min * 0.95
        let upperBound = max > 0 ? max + padding : max * 1.05

        // Ensure we include zero if balances cross it
        if min < 0 && max > 0 {
            return lowerBound...upperBound
        }

        return lowerBound...upperBound
    }

    var body: some View {
        if balancePoints.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 48))
                    .foregroundColor(Theme.Colors.textSecondary.opacity(0.5))
                Text("Not enough data yet")
                    .font(.headline)
                    .foregroundColor(Theme.Colors.textPrimary)
                Text("Complete more transactions to see your balance trend")
                    .font(.subheadline)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Chart(balancePoints) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Balance", point.balance)
                )
                .foregroundStyle(chartColor)
                .interpolationMethod(.catmullRom) // Smooth curve like NetWorthChart
                .lineStyle(StrokeStyle(lineWidth: 3))

                // Area fill under the line
                AreaMark(
                    x: .value("Date", point.date),
                    y: .value("Balance", point.balance)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            chartColor.opacity(0.3),
                            chartColor.opacity(0.05)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { value in
                    if let date = value.as(Date.self) {
                        AxisValueLabel {
                            Text(formatAxisDate(date))
                                .font(.caption2)
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(Color.gray.opacity(0.2))
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                    if let balance = value.as(Double.self) {
                        AxisValueLabel {
                            Text(formatCurrency(balance))
                                .font(.caption2)
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(Color.gray.opacity(0.2))
                    }
                }
            }
            .chartYScale(domain: chartYDomain)
        }
    }

    func formatAxisDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        if balancePoints.count > 30 {
            formatter.dateFormat = "MMM"
        } else {
            formatter.dateFormat = "M/d"
        }
        return formatter.string(from: date)
    }

    func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "$0"
    }
}

// MARK: - Spending vs Credit Chart

struct SpendingCreditChart: View {
    let transactions: [Transaction]
    let timeRange: TimeRange

    struct BarData: Identifiable {
        let id = UUID()
        let date: Date
        let dateLabel: String
        let type: String
        let amount: Double
    }

    var barData: [BarData] {
        let calendar = Calendar.current
        var dailyTotals: [Date: (spent: Double, credit: Double)] = [:]

        for transaction in transactions {
            let date = Date(timeIntervalSince1970: TimeInterval(transaction.postedDate))
            let key: Date

            // Group by day or month depending on time range
            if timeRange == .year {
                // For year view, group by month
                key = calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? calendar.startOfDay(for: date)
            } else {
                // For other views, group by day
                key = calendar.startOfDay(for: date)
            }

            if transaction.amount < 0 {
                dailyTotals[key, default: (0, 0)].spent += abs(transaction.amount)
            } else {
                dailyTotals[key, default: (0, 0)].credit += transaction.amount
            }
        }

        // Flatten to create individual bars
        var result: [BarData] = []
        for (date, totals) in dailyTotals {
            let label = formatAxisDate(date)
            result.append(BarData(date: date, dateLabel: label, type: "Spent", amount: totals.spent))
            result.append(BarData(date: date, dateLabel: label, type: "Credit", amount: totals.credit))
        }

        return result.sorted { $0.date < $1.date }
    }

    var maxValue: Double {
        barData.map { $0.amount }.max() ?? 1
    }

    var uniqueLabels: [String] {
        // Get unique date labels in chronological order
        let sortedData = barData.sorted { $0.date < $1.date }
        var seen = Set<String>()
        var labels: [String] = []
        for bar in sortedData {
            if !seen.contains(bar.dateLabel) {
                seen.insert(bar.dateLabel)
                labels.append(bar.dateLabel)
            }
        }
        return labels
    }

    var barWidth: MarkDimension {
        let count = uniqueLabels.count
        switch count {
        case 0...2:
            return .ratio(0.7)  // Wide bars for very little data
        case 3...5:
            return .ratio(0.6)  // Medium-wide bars
        case 6...8:
            return .ratio(0.5)  // Medium bars
        default:
            return .ratio(0.4)  // Narrow bars for lots of data
        }
    }

    var body: some View {
        if barData.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 48))
                    .foregroundColor(Theme.Colors.textSecondary.opacity(0.5))
                Text("No transaction data")
                    .font(.headline)
                    .foregroundColor(Theme.Colors.textPrimary)
                Text("Complete transactions to see spending trends")
                    .font(.subheadline)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Chart {
                ForEach(barData.filter { $0.type == "Spent" }) { bar in
                    BarMark(
                        x: .value("Date", bar.dateLabel),
                        y: .value("Amount", bar.amount),
                        width: barWidth
                    )
                    .foregroundStyle(Theme.Colors.expense)
                    .position(by: .value("Type", "Spent"))
                }
                ForEach(barData.filter { $0.type == "Credit" }) { bar in
                    BarMark(
                        x: .value("Date", bar.dateLabel),
                        y: .value("Amount", bar.amount),
                        width: barWidth
                    )
                    .foregroundStyle(Theme.Colors.income)
                    .position(by: .value("Type", "Credit"))
                }
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let label = value.as(String.self) {
                            Text(label)
                                .font(.caption2)
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                    }
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.gray.opacity(0.2))
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                    if let amount = value.as(Double.self) {
                        AxisValueLabel {
                            Text(formatCurrency(amount))
                                .font(.caption2)
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(Color.gray.opacity(0.2))
                    }
                }
            }
            .chartLegend(position: .top, alignment: .trailing) {
                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Theme.Colors.expense)
                            .frame(width: 8, height: 8)
                        Text("Spent")
                            .font(.caption)
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Theme.Colors.income)
                            .frame(width: 8, height: 8)
                        Text("Credit")
                            .font(.caption)
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                }
            }
        }
    }

    func formatAxisDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        if timeRange == .year {
            formatter.dateFormat = "MMM"
        } else {
            formatter.dateFormat = "M/d"
        }
        return formatter.string(from: date)
    }

    func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "$0"
    }
}

// MARK: - Date Range Picker View

struct DateRangePickerView: View {
    @Environment(\.dismiss) private var dismiss
    let timeRange: TimeRange
    @Binding var selectedDate: Date
    @Binding var customStartDate: Date
    @Binding var customEndDate: Date

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    switch timeRange {
                    case .day:
                        DatePicker(
                            "Select Day",
                            selection: $selectedDate,
                            displayedComponents: .date
                        )
                        .datePickerStyle(.graphical)

                    case .week:
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Select Week End")
                                .font(.subheadline)
                                .foregroundColor(Theme.Colors.textSecondary)
                            DatePicker(
                                "Week Ending",
                                selection: $selectedDate,
                                displayedComponents: .date
                            )
                            .datePickerStyle(.graphical)
                            Text("Shows 7 days ending on selected date")
                                .font(.caption)
                                .foregroundColor(Theme.Colors.textSecondary)
                        }

                    case .month:
                        DatePicker(
                            "Select Month",
                            selection: $selectedDate,
                            displayedComponents: [.date]
                        )
                        .datePickerStyle(.graphical)

                    case .year:
                        DatePicker(
                            "Select Year",
                            selection: $selectedDate,
                            displayedComponents: [.date]
                        )
                        .datePickerStyle(.graphical)

                    case .custom:
                        VStack(alignment: .leading, spacing: 16) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Start Date")
                                    .font(.subheadline)
                                    .foregroundColor(Theme.Colors.textSecondary)
                                DatePicker(
                                    "From",
                                    selection: $customStartDate,
                                    displayedComponents: .date
                                )
                                .datePickerStyle(.compact)
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("End Date")
                                    .font(.subheadline)
                                    .foregroundColor(Theme.Colors.textSecondary)
                                DatePicker(
                                    "To",
                                    selection: $customEndDate,
                                    in: customStartDate...,
                                    displayedComponents: .date
                                )
                                .datePickerStyle(.compact)
                            }
                        }
                    }
                } header: {
                    Text(headerText)
                }

                Section {
                    Button("Apply") {
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundColor(Theme.Colors.primary)
                }
            }
            .navigationTitle("Select Date Range")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    var headerText: String {
        switch timeRange {
        case .day:
            return "Pick a specific day to view transactions"
        case .week:
            return "Pick the last day of a 7-day period"
        case .month:
            return "Pick a month to view transactions"
        case .year:
            return "Pick a year to view transactions"
        case .custom:
            return "Pick a custom date range"
        }
    }
}
