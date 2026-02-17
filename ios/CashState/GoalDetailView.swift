import SwiftUI
import Charts

struct GoalDetailView: View {
    let apiClient: APIClient
    let goalId: String

    @State private var detail: GoalDetail?
    @State private var isLoading = false
    @State private var error: String?
    @State private var selectedGranularity = "month"
    @State private var selectedRange = "1M"
    @Environment(\.dismiss) private var dismiss

    private let ranges = ["1M", "3M", "6M", "1Y"]
    private let granularityMap = ["1M": "day", "3M": "week", "6M": "week", "1Y": "month"]

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                if isLoading && detail == nil {
                    ProgressView()
                        .padding(.top, 60)
                } else if let detail = detail {
                    // Header card
                    headerCard(detail: detail)

                    // Progress chart — always show if there's data
                    chartCard(detail: detail)

                    // Accounts section
                    accountsSection(detail: detail)
                } else if let error = error {
                    Text(error)
                        .foregroundColor(Theme.Colors.expense)
                        .padding()
                }
            }
            .padding(Theme.Spacing.md)
        }
        .background(Theme.Colors.background)
        .navigationTitle(detail?.name ?? "Goal")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if let detail = detail {
                    NavigationLink(destination: EditGoalView(
                        apiClient: apiClient,
                        goal: goalToGoal(detail),
                        onUpdated: { _ in Task { await loadDetail() } }
                    )) {
                        Text("Edit")
                            .foregroundColor(Theme.Colors.primary)
                    }
                }
            }
        }
        .task {
            await loadDetail()
        }
    }

    private func headerCard(detail: GoalDetail) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: Theme.Spacing.sm) {
                        GoalTypeBadge(goalType: detail.goalType)
                        if detail.isCompleted {
                            Text("Completed")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(Theme.Colors.income)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Theme.Colors.income.opacity(0.15))
                                .cornerRadius(6)
                        }
                    }
                    if let desc = detail.description, !desc.isEmpty {
                        Text(desc)
                            .font(.subheadline)
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                }
                Spacer()
                if let targetDate = detail.targetDate, !targetDate.isEmpty {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Target date")
                            .font(.caption)
                            .foregroundColor(Theme.Colors.textSecondary)
                        Text(targetDate)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(Theme.Colors.textPrimary)
                    }
                }
            }

            // Amounts
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(detail.goalType == .debtPayment ? "Balance" : "Current")
                        .font(.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                    Text(formatBalance(detail.goalType == .debtPayment
                        ? debtCurrentBalance(detail)
                        : detail.currentAmount))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(Theme.Colors.textPrimary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(detail.goalType == .debtPayment ? "Goal balance" : "Target")
                        .font(.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                    Text(formatBalance(detail.goalType == .debtPayment
                        ? debtTargetBalance(detail)
                        : detail.targetAmount))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(Theme.Colors.textPrimary)
                }
            }

            // Progress bar
            VStack(spacing: 4) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.gray.opacity(0.15))
                            .frame(height: 12)
                        RoundedRectangle(cornerRadius: 6)
                            .fill(progressColor(for: detail.progressPercent, isCompleted: detail.isCompleted))
                            .frame(width: geo.size.width * CGFloat(min(detail.progressPercent, 100) / 100), height: 12)
                    }
                }
                .frame(height: 12)
                HStack {
                    Spacer()
                    Text(String(format: "%.1f%% of goal", detail.progressPercent))
                        .font(.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                }
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.cardBackground)
        .cornerRadius(Theme.CornerRadius.md)
        .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
    }

    private func chartCard(detail: GoalDetail) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Text("Progress over time")
                    .font(.headline)
                    .foregroundColor(Theme.Colors.textPrimary)
                Spacer()
                HStack(spacing: 4) {
                    ForEach(ranges, id: \.self) { range in
                        Button(range) {
                            selectedRange = range
                            selectedGranularity = granularityMap[range] ?? "day"
                            Task { await loadDetail() }
                        }
                        .font(.caption)
                        .fontWeight(selectedRange == range ? .bold : .regular)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(selectedRange == range ? Theme.Colors.primary.opacity(0.15) : Color.clear)
                        .foregroundColor(selectedRange == range ? Theme.Colors.primary : Theme.Colors.textSecondary)
                        .cornerRadius(6)
                    }
                }
            }

            if #available(iOS 16.0, *) {
                let points = extrapolatedBalancePoints(for: detail)
                let goalBalance = detail.goalType == .debtPayment
                    ? debtTargetBalance(detail)
                    : detail.targetAmount
                // Green if current balance has crossed the goal balance, red for debt in progress
                let currentBalance = points.last?.balance ?? 0
                let lineColor: Color = currentBalance >= goalBalance
                    ? Theme.Colors.income
                    : (detail.goalType == .debtPayment ? Theme.Colors.expense : Theme.Colors.income)

                Chart {
                    ForEach(points) { point in
                        AreaMark(
                            x: .value("Date", point.date),
                            y: .value("Balance", point.balance)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [lineColor.opacity(0.25), lineColor.opacity(0.03)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Balance", point.balance)
                        )
                        .foregroundStyle(lineColor)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                    }

                    RuleMark(y: .value("Goal balance", goalBalance))
                        .foregroundStyle(Theme.Colors.income.opacity(0.6))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [6, 3]))
                        .annotation(position: .top, alignment: .trailing) {
                            Text("Goal \(formatBalance(goalBalance))")
                                .font(.caption2)
                                .foregroundColor(Theme.Colors.income)
                        }
                }
                .frame(height: 180)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(formatBalance(v))
                                    .font(.caption2)
                            }
                        }
                    }
                }
            } else {
                Text("Charts require iOS 16+")
                    .font(.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .frame(height: 180)
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.cardBackground)
        .cornerRadius(Theme.CornerRadius.md)
        .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
    }

    // MARK: - Chart helpers

    struct BalancePoint: Identifiable {
        let id: String
        let date: Date
        let balance: Double
    }

    /// Fills the full date range with real snapshot data where available,
    /// carrying the last known balance forward for missing periods.
    /// Falls back to the raw current account balance when no history exists.
    private func extrapolatedBalancePoints(for detail: GoalDetail) -> [BalancePoint] {
        let (startDate, _) = dateRange(for: selectedRange)
        let today = Date()
        let calendar = Calendar.current
        let granularity = granularityMap[selectedRange] ?? "day"
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        // Real snapshot lookup by date string
        var dataByDate: [String: Double] = [:]
        for snapshot in detail.progressData {
            dataByDate[snapshot.date] = snapshot.balance
        }
        let sortedKeys = dataByDate.keys.sorted()

        // Current raw account balance used as fallback
        let rawCurrent = detail.accounts.reduce(0.0) { $0 + $1.currentBalance }

        // Generate date ticks
        var ticks: [Date] = []
        var cursor = calendar.startOfDay(for: startDate)
        let endDay = calendar.startOfDay(for: today)
        while cursor <= endDay {
            ticks.append(cursor)
            switch granularity {
            case "week":  cursor = calendar.date(byAdding: .weekOfYear, value: 1, to: cursor) ?? cursor
            case "month": cursor = calendar.date(byAdding: .month, value: 1, to: cursor) ?? cursor
            default:      cursor = calendar.date(byAdding: .day, value: 1, to: cursor) ?? cursor
            }
        }
        if ticks.last.map({ !calendar.isDateInToday($0) }) ?? true { ticks.append(endDay) }

        return ticks.map { date in
            let dateStr = formatter.string(from: date)
            if calendar.isDateInToday(date) || date >= today {
                return BalancePoint(id: dateStr, date: date, balance: rawCurrent)
            }
            if let val = dataByDate[dateStr] {
                return BalancePoint(id: dateStr, date: date, balance: val)
            }
            let lastKey = sortedKeys.last { $0 <= dateStr }
            let balance = lastKey.flatMap { dataByDate[$0] } ?? rawCurrent
            return BalancePoint(id: dateStr, date: date, balance: balance)
        }
    }

    private func accountsSection(detail: GoalDetail) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Linked Accounts")
                .font(.headline)
                .foregroundColor(Theme.Colors.textPrimary)

            ForEach(detail.accounts) { account in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(account.accountName)
                            .font(.body)
                            .foregroundColor(Theme.Colors.textPrimary)
                        if detail.goalType == .debtPayment, let starting = account.startingBalance {
                            Text(String(format: "Started at $%.2f", abs(starting)))
                                .font(.caption)
                                .foregroundColor(Theme.Colors.textSecondary)
                        } else {
                            Text(String(format: "%.0f%% allocated", account.allocationPercentage))
                                .font(.caption)
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(String(format: "$%.2f", abs(account.currentBalance)))
                            .font(.body)
                            .fontWeight(.semibold)
                            .foregroundColor(Theme.Colors.textPrimary)
                        if detail.goalType == .debtPayment, let starting = account.startingBalance {
                            let paidOff = abs(starting) - abs(account.currentBalance)
                            Text(String(format: "$%.2f paid off", max(0, paidOff)))
                                .font(.caption)
                                .foregroundColor(Theme.Colors.income)
                        } else {
                            Text(String(format: "$%.2f attributed", abs(account.currentBalance) * account.allocationPercentage / 100))
                                .font(.caption)
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                    }
                }
                .padding(Theme.Spacing.sm)
                .background(Theme.Colors.background.opacity(0.5))
                .cornerRadius(Theme.CornerRadius.sm)
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.cardBackground)
        .cornerRadius(Theme.CornerRadius.md)
        .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
    }

    private func loadDetail() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let (startDate, _) = dateRange(for: selectedRange)
            detail = try await apiClient.fetchGoalDetail(
                goalId: goalId,
                startDate: startDate,
                granularity: granularityMap[selectedRange] ?? "day"
            )
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func dateRange(for range: String) -> (Date, Date) {
        let end = Date()
        let calendar = Calendar.current
        let start: Date
        switch range {
        case "3M": start = calendar.date(byAdding: .month, value: -3, to: end) ?? end
        case "6M": start = calendar.date(byAdding: .month, value: -6, to: end) ?? end
        case "1Y": start = calendar.date(byAdding: .year, value: -1, to: end) ?? end
        default:   start = calendar.date(byAdding: .month, value: -1, to: end) ?? end
        }
        return (start, end)
    }

    /// Raw current balance summed across accounts (negative for debt, e.g. -22432.09).
    private func debtCurrentBalance(_ detail: GoalDetail) -> Double {
        detail.accounts.reduce(0) { $0 + $1.currentBalance }
    }

    /// The goal balance to reach: startingTotal + targetAmount
    /// e.g. starting -22432, pay off 6000 → goal balance = -16432 (still negative debt).
    private func debtTargetBalance(_ detail: GoalDetail) -> Double {
        let startingTotal = detail.accounts.reduce(0.0) {
            $0 + ($1.startingBalance ?? $1.currentBalance)
        }
        return startingTotal + detail.targetAmount
    }

    /// Formats a balance correctly regardless of sign: -$22,432.09 or $5,000.00
    private func formatBalance(_ value: Double) -> String {
        value < 0
            ? String(format: "-$%.2f", abs(value))
            : String(format: "$%.2f", value)
    }

    private func progressColor(for pct: Double, isCompleted: Bool) -> Color {
        if isCompleted { return Theme.Colors.income }
        if pct >= 75 { return Theme.Colors.income }
        if pct >= 40 { return Theme.Colors.primary }
        return Theme.Colors.expense
    }

    // Convert GoalDetail back to Goal for edit screen
    private func goalToGoal(_ d: GoalDetail) -> Goal {
        Goal(
            id: d.id,
            name: d.name,
            description: d.description,
            goalType: d.goalType,
            targetAmount: d.targetAmount,
            targetDate: d.targetDate,
            isCompleted: d.isCompleted,
            currentAmount: d.currentAmount,
            progressPercent: d.progressPercent,
            accounts: d.accounts,
            createdAt: d.createdAt,
            updatedAt: d.updatedAt
        )
    }
}
