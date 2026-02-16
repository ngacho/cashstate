import SwiftUI

struct CategoryTransactionsView: View {
    let category: BudgetCategory
    let subcategory: BudgetSubcategory?
    let apiClient: APIClient
    @Binding var isPresented: Bool

    @State private var transactions: [Transaction] = []
    @State private var isLoading = true
    @State private var isLoadingCategories = true
    @State private var errorMessage: String?
    @State private var selectedTransaction: Transaction?
    @State private var showTransactionDetail = false
    @State private var allCategories: [BudgetCategory] = []

    var title: String {
        if let sub = subcategory {
            return sub.name
        } else {
            return category.name
        }
    }

    var totalAmount: Double {
        transactions.reduce(0) { $0 + abs($1.amount) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                if isLoading || isLoadingCategories {
                    VStack(spacing: 12) {
                        ProgressView()
                        if isLoading {
                            Text("Loading transactions...")
                                .font(.subheadline)
                                .foregroundColor(Theme.Colors.textSecondary)
                        } else {
                            Text("Loading categories...")
                                .font(.subheadline)
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                    }
                } else if let error = errorMessage {
                    VStack(spacing: Theme.Spacing.md) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 50))
                            .foregroundColor(.red)
                        Text("Error loading transactions")
                            .font(.headline)
                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(Theme.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    contentView
                }
            }
            .navigationTitle("Transactions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                    .fontWeight(.semibold)
                }
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
                        onCategoryUpdated: .constant({ newCategoryId, newSubcategoryId in
                            // Reload transactions to reflect changes
                            Task {
                                await loadTransactions()
                            }
                        })
                    )
                }
            }
        }
    }

    private var contentView: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                // Header with icon and stats
                VStack(spacing: Theme.Spacing.sm) {
                        Text(subcategory?.icon ?? category.icon)
                            .font(.system(size: 50))
                            .frame(width: 80, height: 80)
                            .overlay(
                                Circle()
                                    .strokeBorder(category.color.color, lineWidth: 3)
                            )

                        Text(title)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(Theme.Colors.textPrimary)

                        HStack(spacing: Theme.Spacing.md) {
                            VStack(spacing: 4) {
                                Text("\(transactions.count)")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundColor(Theme.Colors.textPrimary)
                                Text("Transactions")
                                    .font(.caption)
                                    .foregroundColor(Theme.Colors.textSecondary)
                            }
                            .frame(maxWidth: .infinity)

                            Divider()
                                .frame(height: 40)

                            VStack(spacing: 4) {
                                Text("$\(String(format: "%.2f", totalAmount))")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundColor(Theme.Colors.textPrimary)
                                Text("Total Spent")
                                    .font(.caption)
                                    .foregroundColor(Theme.Colors.textSecondary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Theme.Colors.cardBackground)
                        .cornerRadius(Theme.CornerRadius.md)
                        .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
                    }
                    .padding(.horizontal)
                    .padding(.top, Theme.Spacing.sm)

                    // Transactions list
                    if transactions.isEmpty {
                        VStack(spacing: Theme.Spacing.md) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 50))
                                .foregroundColor(Theme.Colors.textSecondary.opacity(0.5))
                            Text("No transactions yet")
                                .font(.headline)
                                .foregroundColor(Theme.Colors.textPrimary)
                            Text("Transactions will appear here once categorized")
                                .font(.subheadline)
                                .foregroundColor(Theme.Colors.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, Theme.Spacing.xl)
                    } else {
                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            Text("Recent Transactions")
                                .font(.headline)
                                .foregroundColor(Theme.Colors.textPrimary)
                                .padding(.horizontal)

                            LazyVStack(spacing: 0) {
                                ForEach(transactions) { transaction in
                                    TransactionRowView(
                                        transaction: transaction,
                                        category: category,
                                        showSubcategoryChip: subcategory == nil,
                                        categoryColor: category.color.color
                                    )
                                    .onTapGesture {
                                        selectedTransaction = transaction
                                        showTransactionDetail = true
                                    }
                                    if transaction.id != transactions.last?.id {
                                        Divider()
                                            .padding(.leading, 60)
                                    }
                                }
                            }
                            .background(Theme.Colors.cardBackground)
                            .cornerRadius(Theme.CornerRadius.md)
                            .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
                            .padding(.horizontal)
                        }
                    }

                    Spacer(minLength: Theme.Spacing.lg)
                }
            }
            .background(Theme.Colors.background)
        }

    private func loadCategories() async {
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
                    color: BudgetCategory.CategoryColor(rawValue: item.color) ?? .blue,
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

    private func loadTransactions() async {
        isLoading = true
        errorMessage = nil

        do {
            // Fetch all transactions for the current month
            let calendar = Calendar.current
            let now = Date()
            let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
            let startTimestamp = Int(startOfMonth.timeIntervalSince1970)

            let allTransactions = try await apiClient.listSimplefinTransactions(
                dateFrom: startTimestamp,
                dateTo: nil,
                limit: 1000,
                offset: 0
            )

            // Filter transactions by category and subcategory
            if let sub = subcategory {
                // Filter by subcategory
                transactions = allTransactions.filter {
                    $0.categoryId == category.id && $0.subcategoryId == sub.id
                }
            } else {
                // Filter by category only (all subcategories)
                transactions = allTransactions.filter {
                    $0.categoryId == category.id
                }
            }

            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}

// MARK: - Transaction Row View

struct TransactionRowView: View {
    let transaction: Transaction
    let category: BudgetCategory
    let showSubcategoryChip: Bool
    let categoryColor: Color

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: Date(timeIntervalSince1970: TimeInterval(transaction.postedDate)))
    }

    var subcategory: BudgetSubcategory? {
        guard let subId = transaction.subcategoryId else { return nil }
        return category.subcategories.first { $0.id == subId }
    }

    var merchantName: String {
        transaction.payee ?? transaction.description
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: Theme.Spacing.md) {
                // Icon
                Image(systemName: "arrow.up")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(categoryColor)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Circle()
                            .strokeBorder(categoryColor, lineWidth: 2)
                    )

                // Transaction info
                VStack(alignment: .leading, spacing: 4) {
                    Text(merchantName)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(Theme.Colors.textPrimary)
                        .lineLimit(1)
                    HStack(spacing: 4) {
                        Text(formattedDate)
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
                Text("-$\(String(format: "%.2f", abs(transaction.amount)))")
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.Colors.expense)
            }

            // Subcategory chip (only shown when viewing all category transactions)
            if showSubcategoryChip, let sub = subcategory {
                HStack(spacing: 4) {
                    Text(sub.icon)
                        .font(.caption2)
                    Text(sub.name)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundColor(categoryColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(categoryColor.opacity(0.1))
                .cornerRadius(6)
                .padding(.leading, 56) // Align with transaction info
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .background(Theme.Colors.cardBackground)
        .contentShape(Rectangle())
    }
}

#Preview {
    CategoryTransactionsView(
        category: BudgetCategory.mockCategories[0],
        subcategory: nil,
        apiClient: APIClient(),
        isPresented: .constant(true)
    )
}
