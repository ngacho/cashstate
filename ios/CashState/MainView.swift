import SwiftUI

struct MainView: View {
    @Binding var isAuthenticated: Bool
    let apiClient: APIClient

    var body: some View {
        TabView {
            HomeView(apiClient: apiClient)
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }

            TransactionsView(apiClient: apiClient)
                .tabItem {
                    Label("Transactions", systemImage: "list.bullet.rectangle")
                }

            BudgetsView(apiClient: apiClient)
                .tabItem {
                    Label("Budgets", systemImage: "chart.pie.fill")
                }

            AccountsView(isAuthenticated: $isAuthenticated)
                .tabItem {
                    Label("Accounts", systemImage: "wallet.pass.fill")
                }
        }
        .tint(Theme.Colors.primary)
    }
}

struct TransactionsView: View {
    let apiClient: APIClient
    @State private var transactions: [Transaction] = []
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showError = false

    var body: some View {
        NavigationView {
            Group {
                if isLoading && transactions.isEmpty {
                    ProgressView("Loading transactions...")
                } else if transactions.isEmpty {
                    VStack(spacing: Theme.Spacing.md) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 60))
                            .foregroundColor(Theme.Colors.textSecondary)
                        Text("No transactions yet")
                            .foregroundColor(Theme.Colors.textSecondary)
                        Text("Connect your bank account to see transactions")
                            .font(.caption)
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                } else {
                    List(transactions) { transaction in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(transaction.name)
                                    .font(.headline)
                                if let merchant = transaction.merchantName {
                                    Text(merchant)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Text(transaction.displayDate)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text(transaction.displayAmount)
                                    .font(.headline)
                                    .foregroundColor(transaction.isExpense ? Theme.Colors.expense : Theme.Colors.income)
                                if transaction.pending {
                                    Text("Pending")
                                        .font(.caption2)
                                        .foregroundColor(.orange)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Transactions")
            .refreshable {
                await loadTransactions()
            }
            .task {
                await loadTransactions()
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    func loadTransactions() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let response: TransactionListResponse = try await apiClient.request(
                endpoint: "/transactions?limit=200",
                method: "GET"
            )
            transactions = response.items
        } catch let error as APIError {
            errorMessage = error.localizedDescription
            showError = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

struct InsightsView: View {
    let apiClient: APIClient
    @State private var selectedRange: TimeRange = .month
    @State private var transactions: [Transaction] = []
    @State private var isLoading = false

    var filteredTransactions: [Transaction] {
        let calendar = Calendar.current
        let now = Date()

        return transactions.filter { transaction in
            // Parse date string (YYYY-MM-DD)
            let components = transaction.date.split(separator: "-")
            guard components.count == 3,
                  let year = Int(components[0]),
                  let month = Int(components[1]),
                  let day = Int(components[2]) else {
                return false
            }

            guard let transactionDate = calendar.date(from: DateComponents(year: year, month: month, day: day)) else {
                return false
            }

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
        var categoryTotals: [String: Double] = [:]

        for transaction in filteredTransactions where transaction.amount < 0 {
            let category = transaction.category?.first ?? "Other"
            categoryTotals[category, default: 0] += abs(transaction.amount)
        }

        return categoryTotals.map { CategorySpending(category: $0.key, amount: $0.value) }
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

        for transaction in filteredTransactions where transaction.amount < 0 {
            dailyTotals[transaction.date, default: 0] += abs(transaction.amount)
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
                    // Time range picker
                    Picker("Period", selection: $selectedRange) {
                        ForEach([TimeRange.day, .week, .month, .year], id: \.self) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    if isLoading {
                        ProgressView()
                    } else if transactions.isEmpty {
                        VStack(spacing: Theme.Spacing.md) {
                            Image(systemName: "chart.pie")
                                .font(.system(size: 60))
                                .foregroundColor(Theme.Colors.textSecondary)
                            Text("No data yet")
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                        .padding(.top, 60)
                    } else {
                        // Summary cards
                        VStack(spacing: Theme.Spacing.md) {
                            SummaryCard(
                                title: "Income",
                                amount: totalIncome,
                                color: Theme.Colors.income,
                                icon: "arrow.down.circle.fill"
                            )
                            SummaryCard(
                                title: "Expenses",
                                amount: totalSpent,
                                color: Theme.Colors.expense,
                                icon: "arrow.up.circle.fill"
                            )
                            SummaryCard(
                                title: "Net",
                                amount: netAmount,
                                color: netAmount >= 0 ? Theme.Colors.income : Theme.Colors.expense,
                                icon: "equal.circle.fill"
                            )
                        }
                        .padding(.horizontal)

                        // Transaction count
                        Text("\(filteredTransactions.count) transactions")
                            .font(.caption)
                            .foregroundColor(Theme.Colors.textSecondary)
                            .padding(.top)

                        // Category breakdown
                        if !categoryBreakdown.isEmpty {
                            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                                Text("Top Categories")
                                    .font(.headline)
                                    .foregroundColor(Theme.Colors.textPrimary)
                                    .padding(.horizontal)

                                ForEach(categoryBreakdown.prefix(5), id: \.category) { item in
                                    CategoryRow(
                                        category: item.category,
                                        amount: item.amount,
                                        percentage: totalSpent > 0 ? (item.amount / totalSpent) : 0
                                    )
                                }
                            }
                            .padding(.top)
                        }

                        // Daily spending chart
                        if !dailySpending.isEmpty {
                            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                                Text("Daily Spending")
                                    .font(.headline)
                                    .foregroundColor(Theme.Colors.textPrimary)
                                    .padding(.horizontal)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(dailySpending.sorted(by: { $0.date < $1.date }), id: \.date) { day in
                                            VStack(spacing: 4) {
                                                Rectangle()
                                                    .fill(Theme.Colors.expense)
                                                    .frame(width: 30, height: max(day.amount / maxDailySpending * 100, 5))
                                                Text("\(day.dayLabel)")
                                                    .font(.caption2)
                                                    .foregroundColor(Theme.Colors.textSecondary)
                                            }
                                        }
                                    }
                                    .padding()
                                }
                                .frame(height: 150)
                                .background(Color.white)
                                .cornerRadius(12)
                                .padding(.horizontal)
                            }
                            .padding(.top)
                        }
                    }

                    Spacer()
                }
                .padding(.top)
            }
            .navigationTitle("Insights")
            .background(Theme.Colors.background)
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
            let response: TransactionListResponse = try await apiClient.request(
                endpoint: "/transactions?limit=200",
                method: "GET"
            )
            transactions = response.items
        } catch {
            // Silent fail for insights - user can refresh
            print("Failed to load transactions: \(error)")
        }
    }
}

struct SummaryCard: View {
    let title: String
    let amount: Double
    let color: Color
    let icon: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
                Text(String(format: "$%.2f", amount))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(Theme.Colors.textPrimary)
            }

            Spacer()
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

struct CategoryRow: View {
    let category: String
    let amount: Double
    let percentage: Double

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(category)
                    .font(.subheadline)
                    .foregroundColor(Theme.Colors.textPrimary)
                Spacer()
                Text(String(format: "$%.2f", amount))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.Colors.textPrimary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 6)
                        .cornerRadius(3)

                    Rectangle()
                        .fill(Theme.Colors.expense)
                        .frame(width: geometry.size.width * percentage, height: 6)
                        .cornerRadius(3)
                }
            }
            .frame(height: 6)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
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

    var body: some View {
        NavigationView {
            List {
                Section("Connected Accounts") {
                    Text("No accounts connected yet")
                        .foregroundColor(Theme.Colors.textSecondary)
                }

                Section("Settings") {
                    Button(role: .destructive) {
                        isAuthenticated = false
                    } label: {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Sign Out")
                        }
                    }
                }
            }
            .navigationTitle("Accounts")
        }
    }
}
