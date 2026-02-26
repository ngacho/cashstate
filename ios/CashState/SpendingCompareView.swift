import SwiftUI
import Charts

// MARK: - Category Comparison Model

struct CategoryComparison: Identifiable {
    let id: String  // categoryId
    let categoryName: String
    let colorHex: String
    let icon: String
    let thisMonth: Double   // amount for whichever date thisMonth points to
    let lastMonth: Double   // amount for whichever date lastMonth points to

    var color: Color { Color(hex: colorHex) }
}

// MARK: - Stacked Bar Data

private struct StackedBarItem: Identifiable {
    let id = UUID()
    let monthLabel: String
    let categoryName: String
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

    // MARK: - Computed helpers

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

    // Always show the earlier date on the left, later date on the right
    private var olderIsThis: Bool { thisMonth <= lastMonth }
    private var leftDate: Date  { olderIsThis ? thisMonth : lastMonth }
    private var rightDate: Date { olderIsThis ? lastMonth : thisMonth }
    private var leftLabel: String  { monthLabel(for: leftDate) }
    private var rightLabel: String { monthLabel(for: rightDate) }

    private func leftAmount(for comp: CategoryComparison) -> Double {
        olderIsThis ? comp.thisMonth : comp.lastMonth
    }
    private func rightAmount(for comp: CategoryComparison) -> Double {
        olderIsThis ? comp.lastMonth : comp.thisMonth
    }

    private var leftTotal: Double  { comparisons.reduce(0) { $0 + leftAmount(for: $1) } }
    private var rightTotal: Double { comparisons.reduce(0) { $0 + rightAmount(for: $1) } }
    private var totalDelta: Double { rightTotal - leftTotal }  // positive = spending more now

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                // Month selectors — labels always show which date is selected, order doesn't matter
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
                    monthTotalsCard
                    stackedChart
                    categoryLegend
                    summaryList
                }
            }
            .padding(.vertical, Theme.Spacing.sm)
        }
        .background(Theme.Colors.background)
        .task { await loadData() }
        .onChange(of: thisMonth) { _, newValue in
            Analytics.shared.track(.spendingCompareMonthChanged, properties: ["month": monthLabel(for: newValue), "picker": "this_month"])
            Task { await loadData() }
        }
        .onChange(of: lastMonth) { _, newValue in
            Analytics.shared.track(.spendingCompareMonthChanged, properties: ["month": monthLabel(for: newValue), "picker": "compare_month"])
            Task { await loadData() }
        }
        .sheet(isPresented: $showThisMonthPicker) {
            MonthYearPickerSheet(selectedMonth: $thisMonth, isPresented: $showThisMonthPicker)
        }
        .sheet(isPresented: $showLastMonthPicker) {
            MonthYearPickerSheet(selectedMonth: $lastMonth, isPresented: $showLastMonthPicker)
        }
    }

    // MARK: - Month Totals Card

    private var monthTotalsCard: some View {
        HStack {
            // Left = older month
            VStack(alignment: .leading, spacing: 4) {
                Text(leftLabel)
                    .font(.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
                Text("$\(String(format: "%.0f", leftTotal))")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(Theme.Colors.textSecondary)
            }

            Spacer()

            // Delta indicator (older → newer)
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

            // Right = newer month
            VStack(alignment: .trailing, spacing: 4) {
                Text(rightLabel)
                    .font(.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
                Text("$\(String(format: "%.0f", rightTotal))")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(Theme.Colors.primary)
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
        let sorted = comparisons.sorted {
            max(leftAmount(for: $0), rightAmount(for: $0)) > max(leftAmount(for: $1), rightAmount(for: $1))
        }

        // Build bars: older (left) month first so Swift Charts renders it on the left
        var bars: [StackedBarItem] = []
        for comp in sorted {
            let left  = leftAmount(for: comp)
            let right = rightAmount(for: comp)
            if left > 0 {
                bars.append(StackedBarItem(
                    monthLabel: leftLabel,
                    categoryName: comp.categoryName,
                    amount: left,
                    colorHex: comp.colorHex
                ))
            }
            if right > 0 {
                bars.append(StackedBarItem(
                    monthLabel: rightLabel,
                    categoryName: comp.categoryName,
                    amount: right,
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
            AxisMarks(values: [leftLabel, rightLabel]) { value in
                AxisValueLabel {
                    if let label = value.as(String.self) {
                        Text(label)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(label == rightLabel
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
        let sorted = comparisons.sorted {
            max(leftAmount(for: $0), rightAmount(for: $0)) > max(leftAmount(for: $1), rightAmount(for: $1))
        }
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.xs) {
                ForEach(sorted) { comp in
                    HStack(spacing: 4) {
                        Text(comp.icon).font(.caption2)
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
            // Header — left label (older) first, right label (newer) second
            HStack {
                Text("Category")
                    .font(.caption).fontWeight(.semibold)
                    .foregroundColor(Theme.Colors.textSecondary)
                Spacer()
                Text(leftLabel)
                    .font(.caption).fontWeight(.semibold)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .frame(width: 60, alignment: .trailing)
                Text(rightLabel)
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

            ForEach(comparisons.sorted {
                max(leftAmount(for: $0), rightAmount(for: $0)) > max(leftAmount(for: $1), rightAmount(for: $1))
            }) { comp in
                ComparisonRow(
                    comparison: comp,
                    leftLabel: leftLabel,
                    rightLabel: rightLabel,
                    leftAmount: leftAmount(for: comp),
                    rightAmount: rightAmount(for: comp)
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
                if let uncategorized = summary.uncategorizedSpending, uncategorized > 0 {
                    spending["uncategorized"] = uncategorized
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

            let thisUncategorized = thisSpend["uncategorized"] ?? 0
            let lastUncategorized = lastSpend["uncategorized"] ?? 0
            if thisUncategorized > 0 || lastUncategorized > 0 {
                result.append(CategoryComparison(
                    id: "uncategorized",
                    categoryName: "Uncategorized",
                    colorHex: "#9CA3AF",
                    icon: "❔",
                    thisMonth: thisUncategorized,
                    lastMonth: lastUncategorized
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
    let leftLabel: String
    let rightLabel: String
    let leftAmount: Double   // older month
    let rightAmount: Double  // newer month

    private var delta: Double { rightAmount - leftAmount }  // positive = spending more in newer month

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

            Text("$\(String(format: "%.0f", leftAmount))")
                .font(.subheadline)
                .foregroundColor(Theme.Colors.textSecondary)
                .frame(width: 60, alignment: .trailing)

            Text("$\(String(format: "%.0f", rightAmount))")
                .font(.subheadline)
                .foregroundColor(Theme.Colors.textPrimary)
                .frame(width: 60, alignment: .trailing)

            Group {
                if abs(delta) < 1 {
                    Text("—")
                        .foregroundColor(Theme.Colors.textSecondary)
                } else if delta > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.up").font(.caption2)
                        Text("$\(String(format: "%.0f", delta))")
                    }
                    .foregroundColor(Theme.Colors.expense)
                } else {
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.down").font(.caption2)
                        Text("$\(String(format: "%.0f", -delta))")
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

// MARK: - Month Year Picker Sheet

struct MonthYearPickerSheet: View {
    @Binding var selectedMonth: Date
    @Binding var isPresented: Bool

    @State private var pickerYear: Int
    @State private var pickerMonthIndex: Int  // 1–12

    private static let monthNames = [
        "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December"
    ]

    private var currentYear: Int {
        Calendar.current.component(.year, from: Date())
    }
    private var currentMonthIndex: Int {
        Calendar.current.component(.month, from: Date())
    }
    private var availableYears: [Int] {
        Array(2020...currentYear)
    }
    private var availableMonths: [Int] {
        pickerYear == currentYear ? Array(1...currentMonthIndex) : Array(1...12)
    }

    init(selectedMonth: Binding<Date>, isPresented: Binding<Bool>) {
        self._selectedMonth = selectedMonth
        self._isPresented = isPresented
        let calendar = Calendar.current
        let comps = calendar.dateComponents([.year, .month], from: selectedMonth.wrappedValue)
        _pickerYear = State(initialValue: comps.year ?? Calendar.current.component(.year, from: Date()))
        _pickerMonthIndex = State(initialValue: comps.month ?? Calendar.current.component(.month, from: Date()))
    }

    var body: some View {
        NavigationView {
            HStack(spacing: 0) {
                // Month wheel
                Picker("Month", selection: $pickerMonthIndex) {
                    ForEach(availableMonths, id: \.self) { m in
                        Text(Self.monthNames[m - 1]).tag(m)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)
                .clipped()

                // Year wheel
                Picker("Year", selection: $pickerYear) {
                    ForEach(availableYears, id: \.self) { y in
                        Text(String(y)).tag(y)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)
                .clipped()
            }
            .padding(.horizontal, Theme.Spacing.md)
            .onChange(of: pickerYear) { _, newYear in
                // If we switched to the current year and the selected month is in the future, clamp it
                if newYear == currentYear && pickerMonthIndex > currentMonthIndex {
                    pickerMonthIndex = currentMonthIndex
                }
            }
            .navigationTitle("Select Month")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        if let date = Calendar.current.date(
                            from: DateComponents(year: pickerYear, month: pickerMonthIndex, day: 1)
                        ) {
                            selectedMonth = date
                        }
                        isPresented = false
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.height(300)])
    }
}

#Preview {
    SpendingCompareView(apiClient: APIClient())
}
