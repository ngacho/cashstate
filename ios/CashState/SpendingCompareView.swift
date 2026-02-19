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

// MARK: - Chart Bar Data

private struct ComparisonBar: Identifiable {
    let id = UUID()
    let categoryIcon: String
    let amount: Double
    let monthLabel: String
    let colorHex: String
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
                    // Bar chart (top 8 categories by max spending)
                    comparisonChart

                    // Legend
                    HStack(spacing: Theme.Spacing.md) {
                        HStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Theme.Colors.primary)
                                .frame(width: 14, height: 8)
                            Text(thisMonthLabel)
                                .font(.caption)
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                        HStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Theme.Colors.primary.opacity(0.35))
                                .frame(width: 14, height: 8)
                            Text(lastMonthLabel)
                                .font(.caption)
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, Theme.Spacing.md)

                    // Summary table
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

    // MARK: - Bar Chart

    private var comparisonChart: some View {
        let top = comparisons
            .sorted { max($0.thisMonth, $0.lastMonth) > max($1.thisMonth, $1.lastMonth) }
            .prefix(8)

        var bars: [ComparisonBar] = []
        for comp in top {
            bars.append(ComparisonBar(
                categoryIcon: comp.icon,
                amount: comp.thisMonth,
                monthLabel: thisMonthLabel,
                colorHex: comp.colorHex
            ))
            bars.append(ComparisonBar(
                categoryIcon: comp.icon,
                amount: comp.lastMonth,
                monthLabel: lastMonthLabel,
                colorHex: comp.colorHex
            ))
        }

        return Chart(bars) { bar in
            BarMark(
                x: .value("Category", bar.categoryIcon),
                y: .value("Amount", bar.amount)
            )
            .foregroundStyle(by: .value("Month", bar.monthLabel))
            .position(by: .value("Month", bar.monthLabel))
        }
        .chartForegroundStyleScale([
            thisMonthLabel: Theme.Colors.primary,
            lastMonthLabel: Theme.Colors.primary.opacity(0.35)
        ])
        .chartXAxis {
            AxisMarks(values: .automatic) {
                AxisValueLabel().font(.body)
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
        .frame(height: 220)
        .padding(.horizontal, Theme.Spacing.md)
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
            // Fetch both summaries + categories in parallel
            async let thisSummaryFetch = apiClient.getBudgetSummary(month: monthString(for: thisMonth))
            async let lastSummaryFetch = apiClient.getBudgetSummary(month: monthString(for: lastMonth))
            async let categoriesFetch = apiClient.fetchCategoriesTree()

            let (thisSummary, lastSummary, categoriesTree) = try await (
                thisSummaryFetch, lastSummaryFetch, categoriesFetch
            )

            // Aggregate spending per category from both summaries
            func aggregateSpending(from summary: BudgetSummary) -> [String: Double] {
                var spending: [String: Double] = [:]
                // Category-level line items
                for item in summary.lineItems where item.subcategoryId == nil {
                    spending[item.categoryId, default: 0] += abs(item.spent)
                }
                // Subcategory-level items (for categories without category-level items)
                for item in summary.lineItems where item.subcategoryId != nil {
                    if spending[item.categoryId] == nil {
                        spending[item.categoryId, default: 0] += abs(item.spent)
                    }
                }
                // Unbudgeted categories
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

            // Build comparisons from category metadata
            var result: [CategoryComparison] = []
            for cat in categoriesTree where allCategoryIds.contains(cat.id) {
                let thisAmt = thisSpend[cat.id] ?? 0
                let lastAmt = lastSpend[cat.id] ?? 0
                guard thisAmt > 0 || lastAmt > 0 else { continue }
                // Skip income categories
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
