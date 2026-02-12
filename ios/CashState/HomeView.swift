import SwiftUI

struct HomeView: View {
    let apiClient: APIClient
    @State private var simplefinItems: [SimplefinItem] = []
    @State private var accounts: [SimplefinAccount] = []
    @State private var isLoading = false
    @State private var isSyncing = false
    @State private var errorMessage: String?
    @State private var showSyncSuccess = false

    var totalBalance: Double {
        accounts.compactMap { $0.balance }.reduce(0, +)
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    // Total Balance Card
                    VStack(spacing: Theme.Spacing.sm) {
                        Text("Total Balance")
                            .font(.subheadline)
                            .foregroundColor(Theme.Colors.textSecondary)
                        Text("$\(String(format: "%.2f", totalBalance))")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(Theme.Colors.textPrimary)
                        Text("\(accounts.count) account\(accounts.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.lg)
                    .background(
                        LinearGradient(
                            colors: [Theme.Colors.primary, Theme.Colors.primary.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .foregroundColor(.white)
                    .cornerRadius(20)
                    .shadow(color: Theme.Colors.primary.opacity(0.3), radius: 10, x: 0, y: 5)
                    .padding(.horizontal)

                    // Accounts Section
                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        Text("Your Accounts")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(Theme.Colors.textPrimary)
                            .padding(.horizontal)

                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding()
                        } else if accounts.isEmpty {
                            VStack(spacing: Theme.Spacing.md) {
                                Image(systemName: "creditcard")
                                    .font(.system(size: 60))
                                    .foregroundColor(Theme.Colors.textSecondary)
                                Text("No accounts connected")
                                    .font(.headline)
                                    .foregroundColor(Theme.Colors.textSecondary)
                                Text("Connect your bank in the Accounts tab")
                                    .font(.caption)
                                    .foregroundColor(Theme.Colors.textSecondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                        } else {
                            VStack(spacing: Theme.Spacing.sm) {
                                ForEach(accounts) { account in
                                    NavigationLink(destination: AccountDetailView(
                                        apiClient: apiClient,
                                        account: account
                                    )) {
                                        AccountCard(account: account)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
            .background(Theme.Colors.background)
            .navigationTitle("Home")
            .refreshable {
                await loadAccounts()
            }
            .task {
                await loadAccounts()
            }
            .overlay(alignment: .bottomTrailing) {
                // Floating Resync Button
                Button(action: {
                    Task {
                        await resyncAllAccounts()
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Theme.Colors.primary, Theme.Colors.primary.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 60, height: 60)
                            .shadow(color: Theme.Colors.primary.opacity(0.4), radius: 8, x: 0, y: 4)

                        if isSyncing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.title2)
                                .foregroundColor(.white)
                        }
                    }
                }
                .disabled(isSyncing || simplefinItems.isEmpty)
                .opacity(simplefinItems.isEmpty ? 0.5 : 1.0)
                .padding()
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
            errorMessage = error.localizedDescription
            print("Failed to load accounts: \(error)")
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
        } catch let error as APIError {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
            print("Failed to sync: \(error)")
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
            print("Failed to sync: \(error)")
        }
    }
}

// MARK: - Account Card

struct AccountCard: View {
    let account: SimplefinAccount

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Account Icon
            ZStack {
                Circle()
                    .fill(Theme.Colors.primary.opacity(0.1))
                    .frame(width: 50, height: 50)
                Image(systemName: accountIcon)
                    .font(.title3)
                    .foregroundColor(Theme.Colors.primary)
            }

            // Account Info
            VStack(alignment: .leading, spacing: 4) {
                Text(account.name)
                    .font(.headline)
                    .foregroundColor(Theme.Colors.textPrimary)
                if let org = account.organizationName {
                    Text(org)
                        .font(.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                }
            }

            Spacer()

            // Balance
            VStack(alignment: .trailing, spacing: 4) {
                Text(account.displayBalance)
                    .font(.headline)
                    .foregroundColor(balanceColor)
                Text(account.currency)
                    .font(.caption2)
                    .foregroundColor(Theme.Colors.textSecondary)
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(Theme.Colors.textSecondary)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.1), radius: 4, x: 0, y: 2)
    }

    var accountIcon: String {
        let name = account.name.lowercased()
        if name.contains("credit") {
            return "creditcard.fill"
        } else if name.contains("checking") || name.contains("chequing") {
            return "dollarsign.circle.fill"
        } else if name.contains("saving") {
            return "banknote.fill"
        } else {
            return "building.columns.fill"
        }
    }

    var balanceColor: Color {
        guard let balance = account.balance else { return Theme.Colors.textPrimary }
        return balance < 0 ? Theme.Colors.expense : Theme.Colors.income
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
                // 7 days starting from selectedDate
                guard let weekEnd = calendar.date(byAdding: .day, value: 6, to: calendar.startOfDay(for: selectedDate)) else {
                    return false
                }
                return transactionDate >= calendar.startOfDay(for: selectedDate) &&
                       transactionDate <= calendar.startOfDay(for: weekEnd).addingTimeInterval(86399)

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
            guard let weekEnd = calendar.date(byAdding: .day, value: 6, to: selectedDate) else {
                return formatter.string(from: selectedDate)
            }
            return "\(formatter.string(from: selectedDate)) - \(formatter.string(from: weekEnd))"

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

                // Spending Chart
                if !filteredTransactions.isEmpty {
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text("Activity")
                            .font(.headline)
                            .foregroundColor(Theme.Colors.textPrimary)
                            .padding(.horizontal)

                        TransactionChart(transactions: filteredTransactions, timeRange: selectedTimeRange)
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

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let amount: Double
    let color: Color
    let icon: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            Text(title)
                .font(.caption)
                .foregroundColor(Theme.Colors.textSecondary)
            Text("$\(String(format: "%.2f", amount))")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(Theme.Colors.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.1), radius: 4, x: 0, y: 2)
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
                            Text("Select Week Start")
                                .font(.subheadline)
                                .foregroundColor(Theme.Colors.textSecondary)
                            DatePicker(
                                "Week Starting",
                                selection: $selectedDate,
                                displayedComponents: .date
                            )
                            .datePickerStyle(.graphical)
                            Text("Shows 7 days from selected date")
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
            return "Pick the first day of a 7-day period"
        case .month:
            return "Pick a month to view transactions"
        case .year:
            return "Pick a year to view transactions"
        case .custom:
            return "Pick a custom date range"
        }
    }
}
