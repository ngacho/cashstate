import SwiftUI

struct HomeView: View {
    let apiClient: APIClient
    @State private var transactions: [Transaction] = []
    @State private var isLoading = false
    @State private var monthlyBudget: Double = 4000 // TODO: Make this user-configurable

    var currentMonthTransactions: [Transaction] {
        let calendar = Calendar.current
        let now = Date()

        return transactions.filter { transaction in
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

            return calendar.isDate(transactionDate, equalTo: now, toGranularity: .month)
        }
    }

    var totalSpent: Double {
        currentMonthTransactions
            .filter { $0.amount < 0 }
            .reduce(0) { $0 + abs($1.amount) }
    }

    var leftToSpend: Double {
        monthlyBudget - totalSpent
    }

    var spendingProgress: Double {
        min(totalSpent / monthlyBudget, 1.0)
    }

    struct CategorySpending: Identifiable {
        let id = UUID()
        let category: String
        let amount: Double
        let color: Color

        var icon: String {
            switch category.lowercased() {
            case let c where c.contains("food") || c.contains("dining") || c.contains("restaurant"):
                return "fork.knife"
            case let c where c.contains("shopping") || c.contains("retail"):
                return "bag"
            case let c where c.contains("transport") || c.contains("travel") || c.contains("gas"):
                return "car.fill"
            case let c where c.contains("entertainment") || c.contains("recreation"):
                return "tv"
            case let c where c.contains("groceries"):
                return "cart"
            default:
                return "tag.fill"
            }
        }
    }

    var topSpendingCategories: [CategorySpending] {
        var categoryTotals: [String: Double] = [:]
        let colors: [Color] = [
            Color(hex: "FF6B6B"),
            Color(hex: "9B59B6"),
            Color(hex: "3498DB"),
            Color(hex: "F39C12"),
            Color(hex: "1ABC9C")
        ]

        for transaction in currentMonthTransactions where transaction.amount < 0 {
            let category = transaction.category?.first ?? "Other"
            categoryTotals[category, default: 0] += abs(transaction.amount)
        }

        return categoryTotals
            .sorted { $0.value > $1.value }
            .prefix(3)
            .enumerated()
            .map { index, item in
                CategorySpending(
                    category: item.key,
                    amount: item.value,
                    color: colors[index % colors.count]
                )
            }
    }

    struct DailySpending {
        let day: Int
        let amount: Double
    }

    var dailySpendingData: [DailySpending] {
        let calendar = Calendar.current
        let now = Date()
        var dailyTotals: [Int: Double] = [:]

        for transaction in currentMonthTransactions where transaction.amount < 0 {
            let components = transaction.date.split(separator: "-")
            guard components.count == 3,
                  let day = Int(components[2]) else {
                continue
            }
            dailyTotals[day, default: 0] += abs(transaction.amount)
        }

        // Fill in days 1-10 (or current day if less than 10)
        let currentDay = calendar.component(.day, from: now)
        let maxDay = min(currentDay, 10)

        return (1...maxDay).map { day in
            DailySpending(day: day, amount: dailyTotals[day] ?? 0)
        }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    // Budget Card
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Left to Spend")
                                    .font(.subheadline)
                                    .foregroundColor(Theme.Colors.textSecondary)
                                Text("$\(String(format: "%.2f", leftToSpend))")
                                    .font(.system(size: 36, weight: .bold))
                                    .foregroundColor(leftToSpend >= 0 ? Theme.Colors.primary : Theme.Colors.expense)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 4) {
                                Text("of $\(String(format: "%.0f", monthlyBudget))")
                                    .font(.subheadline)
                                    .foregroundColor(Theme.Colors.textSecondary)
                                Text("spent $\(String(format: "%.2f", totalSpent))")
                                    .font(.caption)
                                    .foregroundColor(Theme.Colors.textSecondary)
                            }
                        }

                        // Progress bar
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(height: 8)
                                    .cornerRadius(4)

                                Rectangle()
                                    .fill(spendingProgress > 0.9 ? Theme.Colors.expense : Theme.Colors.primary)
                                    .frame(width: geometry.size.width * spendingProgress, height: 8)
                                    .cornerRadius(4)
                            }
                        }
                        .frame(height: 8)
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(16)
                    .shadow(color: .gray.opacity(0.1), radius: 4, x: 0, y: 2)
                    .padding(.horizontal)

                    // Spending Trend Chart
                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        Text("Spending Trend")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(Theme.Colors.textPrimary)
                            .padding(.horizontal)

                        if !dailySpendingData.isEmpty {
                            SpendingTrendChart(data: dailySpendingData)
                                .frame(height: 200)
                                .padding()
                                .background(Color.white)
                                .cornerRadius(16)
                                .shadow(color: .gray.opacity(0.1), radius: 4, x: 0, y: 2)
                                .padding(.horizontal)
                        }
                    }

                    // Top Spending
                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        Text("Top Spending")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(Theme.Colors.textPrimary)
                            .padding(.horizontal)

                        VStack(spacing: 0) {
                            ForEach(topSpendingCategories) { category in
                                TopSpendingRow(category: category)
                                if category.id != topSpendingCategories.last?.id {
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

                    if isLoading {
                        ProgressView()
                            .padding()
                    }
                }
                .padding(.vertical)
            }
            .background(Theme.Colors.background)
            .navigationTitle("Home")
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
            print("Failed to load transactions: \(error)")
        }
    }
}

// MARK: - Spending Trend Chart

struct SpendingTrendChart: View {
    let data: [HomeView.DailySpending]

    var maxAmount: Double {
        data.map { $0.amount }.max() ?? 1
    }

    var normalizedData: [(x: CGFloat, y: CGFloat)] {
        data.enumerated().map { index, spending in
            let x = CGFloat(index) / CGFloat(max(data.count - 1, 1))
            let y = 1 - (CGFloat(spending.amount) / CGFloat(maxAmount))
            return (x, y)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { geometry in
                ZStack(alignment: .bottomLeading) {
                    // Y-axis labels and grid lines
                    VStack(alignment: .leading) {
                        ForEach([maxAmount, maxAmount * 0.75, maxAmount * 0.5, maxAmount * 0.25, 0], id: \.self) { value in
                            HStack {
                                Text("\(Int(value))")
                                    .font(.caption2)
                                    .foregroundColor(Theme.Colors.textSecondary)
                                    .frame(width: 30, alignment: .trailing)

                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(height: 1)
                            }
                            if value != 0 {
                                Spacer()
                            }
                        }
                    }

                    // Chart line and dots
                    if normalizedData.count > 1 {
                        Path { path in
                            let chartWidth = geometry.size.width - 40
                            let chartHeight = geometry.size.height - 20

                            let firstPoint = CGPoint(
                                x: 40 + normalizedData[0].x * chartWidth,
                                y: normalizedData[0].y * chartHeight
                            )
                            path.move(to: firstPoint)

                            for point in normalizedData.dropFirst() {
                                path.addLine(to: CGPoint(
                                    x: 40 + point.x * chartWidth,
                                    y: point.y * chartHeight
                                ))
                            }
                        }
                        .stroke(Theme.Colors.primary, lineWidth: 3)

                        // Data point circles
                        ForEach(Array(normalizedData.enumerated()), id: \.offset) { index, point in
                            Circle()
                                .fill(Theme.Colors.primary)
                                .frame(width: 8, height: 8)
                                .position(
                                    x: 40 + point.x * (geometry.size.width - 40),
                                    y: point.y * (geometry.size.height - 20)
                                )
                        }
                    }
                }
            }

            // X-axis labels
            HStack {
                Spacer().frame(width: 40)
                ForEach(Array(data.enumerated()), id: \.offset) { index, spending in
                    Text("\(spending.day)")
                        .font(.caption2)
                        .foregroundColor(Theme.Colors.textSecondary)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

// MARK: - Top Spending Row

struct TopSpendingRow: View {
    let category: HomeView.CategorySpending

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Color indicator bar
            Rectangle()
                .fill(category.color)
                .frame(width: 4)

            // Icon
            Image(systemName: category.icon)
                .font(.title3)
                .foregroundColor(category.color)
                .frame(width: 32)

            // Category info
            VStack(alignment: .leading, spacing: 4) {
                Text(category.category)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(Theme.Colors.textPrimary)
                Text("This month")
                    .font(.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
            }

            Spacer()

            // Amount
            Text("$\(String(format: "%.2f", category.amount))")
                .font(.body)
                .fontWeight(.semibold)
                .foregroundColor(Theme.Colors.textPrimary)
        }
        .padding(.vertical, Theme.Spacing.md)
        .padding(.horizontal)
    }
}
