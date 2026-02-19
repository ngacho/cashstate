import SwiftUI
import Charts

// MARK: - Category Comparison Model

struct CategoryComparison: Identifiable {
    let id: String  // categoryId
    let categoryName: String
    let colorHex: String
    let icon: String
    let thisMonth: Double
    let lastMonth: Double

    var delta: Double { thisMonth - lastMonth }  // positive = spent more this month

    var color: Color { Color(hex: colorHex) }
}

// MARK: - Stacked Bar Data

private struct StackedBarItem: Identifiable {
    let id = UUID()
    let monthLabel: String
    let categoryName: String
    let categoryIcon: String
    let amount: Double
    let colorHex: String

    var color: Color { Color(hex: colorHex) }
}

// MARK: - Spending Compare View

struct SpendingCompareView: View {
    let apiClient: APIClient

    @State private var thisMonth: Date
    @State private var lastMonth: Date
    @State private var comparisons: [CategoryComparison] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showThisMonthPicker = false
    @State private var showLastMonthPicker = false

    init(apiClient: APIClient, initialMonth: Date = Date()) {
        self.apiClient = apiClient
        let prior = Calendar.current.date(byAdding: .month, value: -1, to: initialMonth) ?? initialMonth
        _thisMonth = State(initialValue: initialMonth)
        _lastMonth = State(initialValue: prior)
    }

    private func monthLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter.string(from: date)
    }

    private func monthString(for date: Date) -> String {
        let calendar = Calendar.current
        let comps = calendar.dateComponents([.year, .month], from: date)
        let year = comps.year ?? 2026
        let month = comps.month ?? 1
        return "\(year)-\(String(format: "%02d", month))"
    }

    private var thisMonthLabel: String { monthLabel(for: thisMonth) }
    private var lastMonthLabel: String { monthLabel(for: lastMonth) }

    private var thisMonthTotal: Double { comparisons.reduce(0) { $0 + $1.thisMonth } }
    private var lastMonthTotal: Double { comparisons.reduce(0) { $0 + $1.lastMonth } }
    private var totalDelta: Double { thisMonthTotal - lastMonthTotal }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                // Month selectors
                HStack(spacing: Theme.Spacing.sm) {
                    Button { showThisMonthPicker = true } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar").font(.caption)
                            Text(thisMonthLabel).font(.subheadline).fontWeight(.semibold)
                        }
                        .padding(.horizontal, Theme.Spacing.sm)
                        .padding(.vertical, Theme.Spacing.xs)
                        .background(Theme.Colors.primary.opacity(0.12))
                        .foregroundColor(Theme.Colors.primary)
                        .cornerRadius(Theme.CornerRadius.sm)
                    }

                    Image(systemName: "arrow.left.arrow.right")
                        .font(.caption)
                        .foregroundColor(Theme.Colors.textSecondary)

                    Button { showLastMonthPicker = true } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar").font(.caption)
                            Text(lastMonthLabel).font(.subheadline).fontWeight(.semibold)
                        }
                        .padding(.horizontal, Theme.Spacing.sm)
                        .padding(.vertical, Theme.Spacing.xs)
                        .background(Theme.Colors.cardBackground)
                        .foregroundColor(Theme.Colors.textSecondary)
                        .cornerRadius(Theme.CornerRadius.sm)
                    }

                    Spacer()
                }
                .padding(.horizontal, Theme.Spacing.md)

                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if let error = errorMessage {
                    VStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.title2)
                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(Theme.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                        Button("Retry") { Task { await loadData() } }
                            .font(.subheadline)
                            .foregroundColor(Theme.Colors.primary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                } else if comparisons.isEmpty {
                    VStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: "chart.bar.xaxis")
                            .font(.largeTitle)
                            .foregroundColor(Theme.Colors.textSecondary.opacity(0.5))
                        Text("No spending data to compare")
                            .font(.subheadline)
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 200)
                } else {
                    // Month totals summary
                    monthTotalsCard

                    // Stacked bar chart
                    stackedChart

                    // Category legend
                    categoryLegend

                    // Per-category detail table
                    summaryList
                }
            }
            .padding(.vertical, Theme.Spacing.sm)
        }
        .background(Theme.Colors.background)
        .task { await loadData() }
        .onChange(of: thisMonth) { _, _ in Task { await loadData() } }
        .onChange(of: lastMonth) { _, _ in Task { await loadData() } }
        .sheet(isPresented: $showThisMonthPicker) {
            MonthPickerSheet(selectedMonth: $thisMonth, isPresented: $showThisMonthPicker)
        }
        .sheet(isPresented: $showLastMonthPicker) {
            MonthPickerSheet(selectedMonth: $lastMonth, isPresented: $showLastMonthPicker)
        }
    }

    // MARK: - Month Totals Card

    private var monthTotalsCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(thisMonthLabel)
                    .font(.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
                Text("$\(String(format: "%.0f", thisMonthTotal))")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(Theme.Colors.textPrimary)
            }

            Spacer()

            // Delta indicator
            VStack(spacing: 2) {
                if abs(totalDelta) < 1 {
                    Image(systemName: "equal")
                        .foregroundColor(Theme.Colors.textSecondary)
                } else if totalDelta > 0 {
                    Image(systemName: "arrow.up")
                        .foregroundColor(Theme.Colors.expense)
                    Text("$\(String(format: "%.0f", totalDelta)) more")
                        .font(.caption2)
                        .foregroundColor(Theme.Colors.expense)
                } else {
                    Image(systemName: "arrow.down")
                        .foregroundColor(Theme.Colors.income)
                    Text("$\(String(format: "%.0f", -totalDelta)) less")
                        .font(.caption2)
                        .foregroundColor(Theme.Colors.income)
                }
            }
            .font(.title3)

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(lastMonthLabel)
                    .font(.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
                Text("$\(String(format: "%.0f", lastMonthTotal))")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(Theme.Colors.textSecondary)
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.cardBackground)
        .cornerRadius(Theme.CornerRadius.md)
        .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
        .padding(.horizontal, Theme.Spacing.md)
    }

    // MARK: - Stacked Bar Chart

    private var stackedChart: some View {
        let sorted = comparisons.sorted { max($0.thisMonth, $0.lastMonth) > max($1.thisMonth, $1.lastMonth) }

        var bars: [StackedBarItem] = []
        for comp in sorted {
            if comp.thisMonth > 0 {
                bars.append(StackedBarItem(
                    monthLabel: thisMonthLabel,
                    categoryName: comp.categoryName,
                    categoryIcon: comp.icon,
                    amount: comp.thisMonth,
                    colorHex: comp.colorHex
                ))
            }
            if comp.lastMonth > 0 {
                bars.append(StackedBarItem(
                    monthLabel: lastMonthLabel,
                    categoryName: comp.categoryName,
                    categoryIcon: comp.icon,
                    amount: comp.lastMonth,
                    colorHex: comp.colorHex
                ))
            }
        }

        return Chart(bars) { bar in
            BarMark(
                x: .value("Month", bar.monthLabel),
                y: .value("Spending", bar.amount)
            )
            .foregroundStyle(bar.color)
            .cornerRadius(2)
        }
        .chartXAxis {
            AxisMarks(values: [thisMonthLabel, lastMonthLabel]) { value in
                AxisValueLabel {
                    if let label = value.as(String.self) {
                        Text(label)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(label == thisMonthLabel
                                ? Theme.Colors.primary
                                : Theme.Colors.textSecondary)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel {
                    if let amount = value.as(Double.self) {
                        Text("$\(Int(amount))")
                            .font(.caption2)
                    }
                }
            }
        }
        .frame(height: 260)
        .padding(.horizontal, Theme.Spacing.md)
    }

    // MARK: - Category Legend

    private var categoryLegend: some View {
        let sorted = comparisons.sorted { max($0.thisMonth, $0.lastMonth) > max($1.thisMonth, $1.lastMonth) }
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.xs) {
                ForEach(sorted) { comp in
                    HStack(spacing: 4) {
                        Text(comp.icon)
                            .font(.caption2)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(comp.color)
                            .frame(width: 10, height: 10)
                        Text(comp.categoryName)
                            .font(.caption2)
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Theme.Colors.cardBackground)
                    .cornerRadius(Theme.CornerRadius.sm)
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
        }
    }

    // MARK: - Summary List

    private var summaryList: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Category")
                    .font(.caption).fontWeight(.semibold)
                    .foregroundColor(Theme.Colors.textSecondary)
                Spacer()
                Text(thisMonthLabel)
                    .font(.caption).fontWeight(.semibold)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .frame(width: 60, alignment: .trailing)
                Text(lastMonthLabel)
                    .font(.caption).fontWeight(.semibold)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .frame(width: 60, alignment: .trailing)
                Text("Change")
                    .font(.caption).fontWeight(.semibold)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .frame(width: 70, alignment: .trailing)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            .background(Theme.Colors.cardBackground.opacity(0.5))

            ForEach(comparisons.sorted { max($0.thisMonth, $0.lastMonth) > max($1.thisMonth, $1.lastMonth) }) { comp in
                ComparisonRow(
                    comparison: comp,
                    thisMonthLabel: thisMonthLabel,
                    lastMonthLabel: lastMonthLabel
                )
                Divider().padding(.leading, Theme.Spacing.md)
            }
        }
        .background(Theme.Colors.cardBackground)
        .cornerRadius(Theme.CornerRadius.md)
        .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.bottom, Theme.Spacing.lg)
    }

    // MARK: - Load Data

    private func loadData() async {
        isLoading = true
        errorMessage = nil

        do {
            async let thisSummaryFetch = apiClient.getBudgetSummary(month: monthString(for: thisMonth))
            async let lastSummaryFetch = apiClient.getBudgetSummary(month: monthString(for: lastMonth))
            async let categoriesFetch = apiClient.fetchCategoriesTree()

            let (thisSummary, lastSummary, categoriesTree) = try await (
                thisSummaryFetch, lastSummaryFetch, categoriesFetch
            )

            func aggregateSpending(from summary: BudgetSummary) -> [String: Double] {
                var spending: [String: Double] = [:]
                for item in summary.lineItems where item.subcategoryId == nil {
                    spending[item.categoryId, default: 0] += abs(item.spent)
                }
                for item in summary.lineItems where item.subcategoryId != nil {
                    if spending[item.categoryId] == nil {
                        spending[item.categoryId, default: 0] += abs(item.spent)
                    }
                }
                for item in summary.unbudgetedCategories {
                    if spending[item.categoryId] == nil {
                        spending[item.categoryId] = abs(item.spent)
                    }
                }
                return spending
            }

            let thisSpend = aggregateSpending(from: thisSummary)
            let lastSpend = aggregateSpending(from: lastSummary)
            let allCategoryIds = Set(thisSpend.keys).union(Set(lastSpend.keys))

            var result: [CategoryComparison] = []
            for cat in categoriesTree where allCategoryIds.contains(cat.id) {
                let thisAmt = thisSpend[cat.id] ?? 0
                let lastAmt = lastSpend[cat.id] ?? 0
                guard thisAmt > 0 || lastAmt > 0 else { continue }
                if let catType = cat.type, catType == "income" { continue }
                result.append(CategoryComparison(
                    id: cat.id,
                    categoryName: cat.name,
                    colorHex: cat.color,
                    icon: cat.icon,
                    thisMonth: thisAmt,
                    lastMonth: lastAmt
                ))
            }

            comparisons = result
        } catch {
            errorMessage = "Failed to load comparison: \(error.localizedDescription)"
        }

        isLoading = false
    }
}

// MARK: - Comparison Row

private struct ComparisonRow: View {
    let comparison: CategoryComparison
    let thisMonthLabel: String
    let lastMonthLabel: String

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Text(comparison.icon)
                .font(.body)
                .frame(width: 28)

            Text(comparison.categoryName)
                .font(.subheadline)
                .foregroundColor(Theme.Colors.textPrimary)
                .lineLimit(1)

            Spacer()

            Text("$\(String(format: "%.0f", comparison.thisMonth))")
                .font(.subheadline)
                .foregroundColor(Theme.Colors.textPrimary)
                .frame(width: 60, alignment: .trailing)

            Text("$\(String(format: "%.0f", comparison.lastMonth))")
                .font(.subheadline)
                .foregroundColor(Theme.Colors.textSecondary)
                .frame(width: 60, alignment: .trailing)

            Group {
                if abs(comparison.delta) < 1 {
                    Text("—")
                        .foregroundColor(Theme.Colors.textSecondary)
                } else if comparison.delta > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.up").font(.caption2)
                        Text("$\(String(format: "%.0f", comparison.delta))")
                    }
                    .foregroundColor(Theme.Colors.expense)
                } else {
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.down").font(.caption2)
                        Text("$\(String(format: "%.0f", -comparison.delta))")
                    }
                    .foregroundColor(Theme.Colors.income)
                }
            }
            .font(.subheadline)
            .frame(width: 70, alignment: .trailing)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
    }
}

// MARK: - Month Picker Sheet

struct MonthPickerSheet: View {
    @Binding var selectedMonth: Date
    @Binding var isPresented: Bool
    @State private var tempMonth: Date

    init(selectedMonth: Binding<Date>, isPresented: Binding<Bool>) {
        self._selectedMonth = selectedMonth
        self._isPresented = isPresented
        _tempMonth = State(initialValue: selectedMonth.wrappedValue)
    }

    var body: some View {
        NavigationView {
            DatePicker(
                "Select Month",
                selection: $tempMonth,
                in: ...Date(),
                displayedComponents: [.date]
            )
            .datePickerStyle(.graphical)
            .padding()
            .navigationTitle("Select Month")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        selectedMonth = tempMonth
                        isPresented = false
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

#Preview {
    SpendingCompareView(apiClient: APIClient())
}
