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
    @State private var selectedTimeRange: TimeRange = .month
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
        NavigationView {
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
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
                            } else {
                                Button(action: {
                                    Task { await resyncAllAccounts() }
                                }) {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(Theme.Colors.textOnPrimary)
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
                            colors: [Theme.Colors.primary, Theme.Colors.primaryDark],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(Theme.CornerRadius.xl)
                    .shadow(color: Theme.Colors.primary.opacity(0.3), radius: 12, x: 0, y: 6)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.top, Theme.Spacing.sm)

                    // Net Worth Chart Section
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        HStack {
                            Text("Net Worth")
                                .font(.headline)
                                .foregroundColor(Theme.Colors.textPrimary)
                            Spacer()
                            // Time range menu
                            Menu {
                                Picker("Period", selection: $selectedTimeRange) {
                                    Text("Week").tag(TimeRange.week)
                                    Text("Month").tag(TimeRange.month)
                                    Text("Year").tag(TimeRange.year)
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Text(selectedTimeRange.rawValue)
                                        .font(.subheadline)
                                        .foregroundColor(Theme.Colors.textPrimary)
                                    Image(systemName: "chevron.down")
                                        .font(.caption)
                                        .foregroundColor(Theme.Colors.textSecondary)
                                }
                            }
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
                            .cornerRadius(Theme.CornerRadius.md)
                            .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
                            .padding(.horizontal, Theme.Spacing.md)
                        } else {
                            NetWorthChart(snapshots: snapshots)
                                .frame(height: 200)
                                .padding(Theme.Spacing.md)
                                .background(Theme.Colors.cardBackground)
                                .cornerRadius(Theme.CornerRadius.md)
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
                        VStack(spacing: Theme.Spacing.lg) {
                            ForEach(accountGroups, id: \.type) { group in
                                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                                    // Group header
                                    HStack {
                                        Text(group.type)
                                            .font(.headline)
                                            .foregroundColor(Theme.Colors.textPrimary)
                                        Spacer()
                                        Text(group.totalBalance)
                                            .font(.headline)
                                            .foregroundColor(Theme.Colors.textPrimary)
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
            .navigationTitle("Overview")
            .navigationBarTitleDisplayMode(.inline)
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

    var body: some View {
        Chart(snapshots) { snapshot in
            LineMark(
                x: .value("Date", snapshot.dateValue),
                y: .value("Balance", snapshot.balance)
            )
            .foregroundStyle(Theme.Colors.primary)
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
                        Theme.Colors.primary.opacity(0.3),
                        Theme.Colors.primary.opacity(0.05)
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
        .chartYScale(domain: (minBalance * 0.95)...(maxBalance * 1.05))
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
            // Bank Icon (circular, colored background)
            ZStack {
                Circle()
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
        .background(Theme.Colors.cardBackground)
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
        return balance < 0 ? Theme.Colors.expense : Theme.Colors.textPrimary
    }
}

// MARK: - Account Detail View

struct AccountDetailView: View {
    let apiClient: APIClient
    let account: SimplefinAccount

    @State private var transactions: [Transaction] = []
    @State private var isLoading = false
    @State private var selectedTab: TransactionTab = .all
    @State private var selectedTimeRange: TimeRange = .month
    @State private var selectedDate = Date()
    @State private var customStartDate = Date()
    @State private var customEndDate = Date()
    @State private var showDatePicker = false

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
            VStack(spacing: Theme.Spacing.lg) {
                // Account Summary Card
                VStack(spacing: Theme.Spacing.sm) {
                    Text(account.name)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(Theme.Colors.textPrimary)
                    if let org = account.organizationName {
                        Text(org)
                            .font(.caption)
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                    Text(account.displayBalance)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(Theme.Colors.primary)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.white)
                .cornerRadius(16)
                .shadow(color: .gray.opacity(0.1), radius: 4, x: 0, y: 2)
                .padding(.horizontal)

                // Time Range Picker
                Picker("Period", selection: $selectedTimeRange) {
                    Text("Day").tag(TimeRange.day)
                    Text("Week").tag(TimeRange.week)
                    Text("Month").tag(TimeRange.month)
                    Text("Year").tag(TimeRange.year)
                    Text("Custom").tag(TimeRange.custom)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                // Date Range Selector
                Button(action: { showDatePicker = true }) {
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundColor(Theme.Colors.primary)
                        Text(dateRangeText)
                            .font(.subheadline)
                            .foregroundColor(Theme.Colors.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(color: .gray.opacity(0.1), radius: 4, x: 0, y: 2)
                }
                .padding(.horizontal)

                // Summary Stats
                HStack(spacing: Theme.Spacing.md) {
                    StatCard(
                        title: "Spent",
                        amount: totalSpent,
                        color: Theme.Colors.expense,
                        icon: "arrow.up.circle.fill"
                    )
                    StatCard(
                        title: "Credit",
                        amount: totalCredit,
                        color: Theme.Colors.income,
                        icon: "arrow.down.circle.fill"
                    )
                    StatCard(
                        title: "Net",
                        amount: abs(netAmount),
                        color: netAmount >= 0 ? Theme.Colors.income : Theme.Colors.expense,
                        icon: "equal.circle.fill"
                    )
                }
                .padding(.horizontal)

                // Balance Trend Chart
                if !filteredTransactions.isEmpty {
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text("Balance Trend")
                            .font(.headline)
                            .foregroundColor(Theme.Colors.textPrimary)
                            .padding(.horizontal)

                        AccountBalanceChart(
                            transactions: filteredTransactions,
                            currentBalance: account.balance ?? 0,
                            timeRange: selectedTimeRange
                        )
                            .frame(height: 200)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(16)
                            .shadow(color: .gray.opacity(0.1), radius: 4, x: 0, y: 2)
                            .padding(.horizontal)
                    }
                }

                // Transaction Tabs
                Picker("Type", selection: $selectedTab) {
                    ForEach(TransactionTab.allCases, id: \.self) { tab in
                        Label(tab.rawValue, systemImage: tab.icon).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                // Transactions List
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    HStack {
                        Text("\(filteredTransactions.count) transaction\(filteredTransactions.count == 1 ? "" : "s")")
                            .font(.headline)
                            .foregroundColor(Theme.Colors.textPrimary)
                        Spacer()
                    }
                    .padding(.horizontal)

                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else if filteredTransactions.isEmpty {
                        VStack(spacing: Theme.Spacing.sm) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 40))
                                .foregroundColor(Theme.Colors.textSecondary)
                            Text("No transactions")
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(filteredTransactions) { transaction in
                                TransactionRow(transaction: transaction)
                                if transaction.id != filteredTransactions.last?.id {
                                    Divider()
                                        .padding(.leading, 60)
                                }
                            }
                        }
                        .background(Color.white)
                        .cornerRadius(16)
                        .shadow(color: .gray.opacity(0.1), radius: 4, x: 0, y: 2)
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
        .background(Theme.Colors.background)
        .navigationTitle("Account Details")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await loadTransactions()
        }
        .task {
            await loadTransactions()
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

    func loadTransactions() async {
        isLoading = true
        defer { isLoading = false }

        do {
            // Load all transactions and filter by account
            let allTransactions = try await apiClient.listSimplefinTransactions(limit: 500)
            transactions = allTransactions.filter { $0.simplefinAccountId == account.id }
        } catch {
            print("Failed to load transactions: \(error)")
        }
    }
}

// MARK: - Stat Card (Mint style)

struct StatCard: View {
    let title: String
    let amount: Double
    let color: Color
    let icon: String

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
                Spacer()
            }
            Text("$\(String(format: "%.2f", amount))")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(Theme.Colors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity)
        .background(Theme.Colors.cardBackground)
        .cornerRadius(Theme.CornerRadius.md)
        .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
    }
}

// MARK: - Transaction Row

struct TransactionRow: View {
    let transaction: Transaction

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Icon
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.1))
                    .frame(width: 40, height: 40)
                Image(systemName: iconName)
                    .foregroundColor(iconColor)
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(Theme.Colors.textPrimary)
                Text(transaction.displayDate)
                    .font(.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
            }

            Spacer()

            // Amount
            Text(transaction.displayAmount)
                .font(.headline)
                .foregroundColor(transaction.isExpense ? Theme.Colors.expense : Theme.Colors.income)
        }
        .padding()
    }

    var iconName: String {
        transaction.isExpense ? "arrow.up.circle.fill" : "arrow.down.circle.fill"
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
            let startDate = calendar.startOfDay(for: Date(timeIntervalSince1970: TimeInterval(firstDate)))
            dailyBalances[startDate] = runningBalance
        }

        // Calculate balance after each transaction
        for transaction in sortedTransactions {
            let transactionDate = Date(timeIntervalSince1970: TimeInterval(transaction.postedDate))
            let dayStart = calendar.startOfDay(for: transactionDate)

            runningBalance += transaction.amount
            dailyBalances[dayStart] = runningBalance
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

    var body: some View {
        if balancePoints.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 40))
                    .foregroundColor(Theme.Colors.textSecondary)
                Text("No balance data")
                    .font(.subheadline)
                    .foregroundColor(Theme.Colors.textSecondary)
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
            .chartYScale(domain: (minBalance * 0.95)...(maxBalance * 1.05))
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

// MARK: - Date Range Picker View

struct DateRangePickerView: View {
    @Environment(\.dismiss) private var dismiss
    let timeRange: TimeRange
    @Binding var selectedDate: Date
    @Binding var customStartDate: Date
    @Binding var customEndDate: Date

    var body: some View {
        NavigationView {
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
