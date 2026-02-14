import SwiftUI

struct CategoryTransactionsView: View {
    let category: BudgetCategory
    let subcategory: BudgetSubcategory?
    @Binding var isPresented: Bool

    var transactions: [CategoryTransaction] {
        if let sub = subcategory {
            return CategoryTransaction.transactions(for: category.id, subcategoryId: sub.id)
        } else {
            return CategoryTransaction.transactions(for: category.id)
        }
    }

    var title: String {
        if let sub = subcategory {
            return sub.name
        } else {
            return category.name
        }
    }

    var totalAmount: Double {
        transactions.reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    // Header with icon and stats
                    VStack(spacing: Theme.Spacing.sm) {
                        Text(subcategory?.icon ?? category.icon)
                            .font(.system(size: 50))
                            .frame(width: 80, height: 80)
                            .background(category.color.color.opacity(0.15))
                            .clipShape(Circle())

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
                        }
                        .padding()
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
                                    CategoryTransactionRow(
                                        transaction: transaction,
                                        category: category,
                                        showSubcategoryChip: subcategory == nil,
                                        categoryColor: category.color.color
                                    )
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
        }
    }
}

// MARK: - Category Transaction Row

struct CategoryTransactionRow: View {
    let transaction: CategoryTransaction
    let category: BudgetCategory
    let showSubcategoryChip: Bool
    let categoryColor: Color

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: transaction.date)
    }

    var subcategory: BudgetSubcategory? {
        guard let subId = transaction.subcategoryId else { return nil }
        return category.subcategories.first { $0.id == subId }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: Theme.Spacing.md) {
                // Icon
                ZStack {
                    Circle()
                        .fill(categoryColor.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: "arrow.up")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(categoryColor)
                }

                // Transaction info
                VStack(alignment: .leading, spacing: 4) {
                    Text(transaction.merchantName)
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
                        if !transaction.description.isEmpty && transaction.description != transaction.merchantName {
                            Text("• \(transaction.description)")
                                .font(.caption)
                                .foregroundColor(Theme.Colors.textSecondary)
                                .lineLimit(1)
                        }
                    }
                }

                Spacer()

                // Amount
                Text("-$\(String(format: "%.2f", transaction.amount))")
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
    VStack {
        // Preview with subcategory (no chips)
        CategoryTransactionsView(
            category: BudgetCategory.mockCategories[0],
            subcategory: BudgetCategory.mockCategories[0].subcategories[0],
            isPresented: .constant(true)
        )

        // Preview without subcategory (shows chips)
        CategoryTransactionsView(
            category: BudgetCategory.mockCategories[0],
            subcategory: nil,
            isPresented: .constant(true)
        )
    }
}
