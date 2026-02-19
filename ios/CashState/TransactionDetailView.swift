import SwiftUI

// MARK: - Navigable version (for NavigationLink)
struct TransactionDetailNavigableView: View {
    let transaction: Transaction
    let categories: [BudgetCategory]
    let apiClient: APIClient
    var onCategoryUpdated: ((String?, String?) -> Void)?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        TransactionDetailContentView(
            transaction: transaction,
            categories: categories,
            apiClient: apiClient,
            onCategoryUpdated: onCategoryUpdated,
            onDismiss: { dismiss() }
        )
    }
}

// MARK: - Modal version (for sheets - legacy support)
struct TransactionDetailView: View {
    let transaction: Transaction
    let categories: [BudgetCategory]
    let apiClient: APIClient
    @Binding var isPresented: Bool
    @Binding var onCategoryUpdated: ((String?, String?) -> Void)?

    var body: some View {
        NavigationStack {
            TransactionDetailContentView(
                transaction: transaction,
                categories: categories,
                apiClient: apiClient,
                onCategoryUpdated: onCategoryUpdated,
                onDismiss: { isPresented = false }
            )
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

// MARK: - Content View (shared logic)
private struct TransactionDetailContentView: View {
    let transaction: Transaction
    let categories: [BudgetCategory]
    let apiClient: APIClient
    var onCategoryUpdated: ((String?, String?) -> Void)?
    var onDismiss: () -> Void

    @State private var selectedCategory: BudgetCategory?
    @State private var selectedSubcategory: BudgetSubcategory?
    @State private var isSaving = false
    @State private var saveError: String?
    @State private var showSuccessAnimation = false
    @State private var isLoadingCategories = false
    @State private var loadedCategories: [BudgetCategory] = []
    @State private var categoryLoadError: String?

    init(
        transaction: Transaction,
        categories: [BudgetCategory],
        apiClient: APIClient,
        onCategoryUpdated: ((String?, String?) -> Void)?,
        onDismiss: @escaping () -> Void
    ) {
        self.transaction = transaction
        self.categories = categories
        self.apiClient = apiClient
        self.onCategoryUpdated = onCategoryUpdated
        self.onDismiss = onDismiss

        // Initialize loadedCategories with passed categories
        self._loadedCategories = State(initialValue: categories)

        // Initialize selected category and subcategory based on transaction
        if let categoryId = transaction.categoryId,
           let category = categories.first(where: { $0.id == categoryId }) {
            self._selectedCategory = State(initialValue: category)

            if let subcategoryId = transaction.subcategoryId,
               let subcategory = category.subcategories.first(where: { $0.id == subcategoryId }) {
                self._selectedSubcategory = State(initialValue: subcategory)
            }
        }
    }

    var effectiveCategories: [BudgetCategory] {
        loadedCategories.isEmpty ? categories : loadedCategories
    }

    var merchantName: String {
        transaction.payee ?? transaction.description ?? "Unknown"
    }

    var formattedDate: String {
        let date = Date(timeIntervalSince1970: TimeInterval(transaction.postedDate))
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d, yyyy"
        return formatter.string(from: date)
    }

    var formattedAmount: String {
        let value = abs(transaction.amount)
        return String(format: "$%.2f", value)
    }

    var hasChanges: Bool {
        let currentCategoryId = selectedCategory?.id
        let currentSubcategoryId = selectedSubcategory?.id

        return currentCategoryId != transaction.categoryId ||
               currentSubcategoryId != transaction.subcategoryId
    }

    var body: some View {
        ZStack {
            Theme.Colors.background.ignoresSafeArea()

            ScrollView {
                    VStack(spacing: Theme.Spacing.lg) {
                        // Transaction Details Card (always show this)
                        VStack(spacing: Theme.Spacing.md) {
                            // Amount
                            Text(formattedAmount)
                                .font(.system(size: 48, weight: .bold))
                                .foregroundColor(transaction.isExpense ? Theme.Colors.expense : Theme.Colors.income)

                            // Merchant Name
                            Text(merchantName)
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(Theme.Colors.textPrimary)
                                .multilineTextAlignment(.center)

                            // Date
                            Text(formattedDate)
                                .font(.subheadline)
                                .foregroundColor(Theme.Colors.textSecondary)

                            // Description/Memo
                            if let desc = transaction.description, !desc.isEmpty, desc != merchantName {
                                Text(desc)
                                    .font(.caption)
                                    .foregroundColor(Theme.Colors.textSecondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.top, 4)
                            }

                            if let memo = transaction.memo, !memo.isEmpty {
                                Text(memo)
                                    .font(.caption)
                                    .foregroundColor(Theme.Colors.textSecondary)
                                    .multilineTextAlignment(.center)
                            }

                            // Pending status
                            if transaction.pending {
                                HStack(spacing: 4) {
                                    Image(systemName: "clock")
                                        .font(.caption)
                                    Text("Pending")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                                .foregroundColor(.orange)
                                .padding(.horizontal, Theme.Spacing.sm)
                                .padding(.vertical, 6)
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(Theme.CornerRadius.sm)
                            }
                        }
                        .padding(Theme.Spacing.lg)
                        .background(Theme.Colors.cardBackground)
                        .cornerRadius(Theme.CornerRadius.lg)
                        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 4)
                        .padding(.horizontal, Theme.Spacing.lg)
                        .padding(.top, Theme.Spacing.md)

                        // Category Selection (with loading state)
                        if isLoadingCategories {
                            VStack(spacing: Theme.Spacing.md) {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: Theme.Colors.primary))
                                Text("Loading categories...")
                                    .font(.subheadline)
                                    .foregroundColor(Theme.Colors.textSecondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(Theme.Spacing.xl)
                            .background(Theme.Colors.cardBackground)
                            .cornerRadius(Theme.CornerRadius.lg)
                            .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 4)
                            .padding(.horizontal, Theme.Spacing.lg)
                        } else if let error = categoryLoadError {
                            VStack(spacing: Theme.Spacing.sm) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(.orange)
                                Text("Failed to load categories")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(Theme.Colors.textPrimary)
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(Theme.Colors.textSecondary)
                                    .multilineTextAlignment(.center)
                                Button {
                                    Task { await loadCategoriesIfNeeded() }
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "arrow.clockwise")
                                        Text("Retry")
                                    }
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(Theme.Colors.primary)
                                    .padding(.horizontal, Theme.Spacing.md)
                                    .padding(.vertical, Theme.Spacing.sm)
                                    .background(Theme.Colors.primary.opacity(0.1))
                                    .cornerRadius(Theme.CornerRadius.sm)
                                }
                                .padding(.top, 4)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(Theme.Spacing.lg)
                            .background(Theme.Colors.cardBackground)
                            .cornerRadius(Theme.CornerRadius.lg)
                            .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 4)
                            .padding(.horizontal, Theme.Spacing.lg)
                        } else if effectiveCategories.isEmpty {
                            VStack(spacing: Theme.Spacing.sm) {
                                Image(systemName: "folder.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(Theme.Colors.textSecondary.opacity(0.5))
                                Text("No categories available")
                                    .font(.subheadline)
                                    .foregroundColor(Theme.Colors.textSecondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(Theme.Spacing.xl)
                            .background(Theme.Colors.cardBackground)
                            .cornerRadius(Theme.CornerRadius.lg)
                            .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 4)
                            .padding(.horizontal, Theme.Spacing.lg)
                        } else {
                            CategorySelectionCard(
                                categories: effectiveCategories,
                                selectedCategory: $selectedCategory,
                                selectedSubcategory: $selectedSubcategory
                            )
                            .padding(.horizontal, Theme.Spacing.lg)
                        }

                        // Save Button (only show if changes were made)
                        if hasChanges && !isSaving {
                            Button {
                                Task {
                                    await saveChanges()
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.headline)
                                    Text("Save Changes")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, Theme.Spacing.md)
                                .background(Theme.Colors.primary)
                                .cornerRadius(Theme.CornerRadius.md)
                            }
                            .padding(.horizontal, Theme.Spacing.lg)
                        }

                        // Saving indicator
                        if isSaving {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: Theme.Colors.primary))
                                Text("Saving...")
                                    .font(.subheadline)
                                    .foregroundColor(Theme.Colors.textSecondary)
                            }
                            .padding()
                        }

                        // Error message
                        if let error = saveError {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(Theme.CornerRadius.sm)
                            .padding(.horizontal, Theme.Spacing.lg)
                        }

                        Spacer(minLength: Theme.Spacing.xl)
                    }
            }

            // Success Animation Overlay
            if showSuccessAnimation {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()

                        VStack(spacing: Theme.Spacing.md) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(Theme.Colors.income)

                            Text("Updated!")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(Theme.Colors.textPrimary)
                        }
                        .padding(Theme.Spacing.xl)
                        .background(Theme.Colors.cardBackground)
                        .cornerRadius(Theme.CornerRadius.lg)
                        .shadow(radius: 20)
                    }
                    .transition(.opacity)
                }
        }
        .navigationTitle("Transaction Details")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadCategoriesIfNeeded()
        }
    }

    private func loadCategoriesIfNeeded() async {
        // If categories were already passed in, don't load
        guard categories.isEmpty else {
            return
        }

        isLoadingCategories = true
        categoryLoadError = nil

        do {
            // Fetch the category tree (includes all categories and subcategories)
            let treeResponse = try await apiClient.fetchCategoriesTree()

            // Convert to BudgetCategory model
            let fetchedCategories = treeResponse.map { item in
                BudgetCategory(
                    id: item.id,
                    name: item.name,
                    icon: item.icon,
                    colorHex: item.color,  // Use hex color directly from database
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

            await MainActor.run {
                loadedCategories = fetchedCategories
                isLoadingCategories = false

                // Initialize selected category if transaction has one
                if let categoryId = transaction.categoryId,
                   let category = fetchedCategories.first(where: { $0.id == categoryId }) {
                    selectedCategory = category

                    if let subcategoryId = transaction.subcategoryId,
                       let subcategory = category.subcategories.first(where: { $0.id == subcategoryId }) {
                        selectedSubcategory = subcategory
                    }
                }
            }
        } catch {
            await MainActor.run {
                isLoadingCategories = false
                categoryLoadError = error.localizedDescription
            }
        }
    }

    private func saveChanges() async {
        isSaving = true
        saveError = nil

        do {
            let updates = [(
                transactionId: transaction.id,
                categoryId: selectedCategory?.id,
                subcategoryId: selectedSubcategory?.id
            )]

            let _ = try await apiClient.batchUpdateTransactions(updates)

            // Success! Show animation and notify parent
            await MainActor.run {
                isSaving = false
                showSuccessAnimation = true

                // Call the update callback
                onCategoryUpdated?(selectedCategory?.id, selectedSubcategory?.id)

                // Dismiss after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    showSuccessAnimation = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        onDismiss()
                    }
                }
            }
        } catch {
            await MainActor.run {
                isSaving = false
                saveError = error.localizedDescription
            }
        }
    }
}

// MARK: - Category Selection Card

struct CategorySelectionCard: View {
    let categories: [BudgetCategory]
    @Binding var selectedCategory: BudgetCategory?
    @Binding var selectedSubcategory: BudgetSubcategory?

    @State private var expandedCategories = false
    @State private var expandedSubcategories = false

    private let maxCategoriesBeforeExpand = 8

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            // Categories Section
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack {
                    Text("Category")
                        .font(.headline)
                        .foregroundColor(Theme.Colors.textPrimary)

                    Spacer()

                    if let selected = selectedCategory {
                        HStack(spacing: 4) {
                            Text(selected.icon)
                                .font(.caption)
                            Text(selected.name)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(selected.color)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(selected.color.opacity(0.1))
                        .cornerRadius(6)
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)

                let expenseCategories = categories.filter { $0.type == .expense }
                let displayedCategories = expandedCategories ? expenseCategories : Array(expenseCategories.prefix(maxCategoriesBeforeExpand))
                let hasMore = expenseCategories.count > maxCategoriesBeforeExpand

                WrappingHStack(horizontalSpacing: Theme.Spacing.sm, verticalSpacing: Theme.Spacing.sm) {
                    ForEach(displayedCategories) { category in
                        CategoryChip(
                            category: category,
                            isSelected: selectedCategory?.id == category.id,
                            action: {
                                withAnimation(.spring(response: 0.3)) {
                                    selectedCategory = category
                                    // Reset subcategory when changing category
                                    if selectedSubcategory?.id != nil {
                                        selectedSubcategory = nil
                                    }
                                }
                            }
                        )
                    }

                    // Show More / Show Less button
                    if hasMore {
                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                expandedCategories.toggle()
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: expandedCategories ? "chevron.up" : "chevron.down")
                                    .font(.caption2)
                                Text(expandedCategories ? "Less" : "More")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .padding(.horizontal, Theme.Spacing.sm)
                            .padding(.vertical, 6)
                            .background(Color.gray.opacity(0.1))
                            .foregroundColor(Theme.Colors.textSecondary)
                            .cornerRadius(20)
                        }
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)
            }

            // Subcategories Section (shown when category is selected)
            if let selectedCat = selectedCategory, !selectedCat.subcategories.isEmpty {
                Divider()
                    .padding(.horizontal, Theme.Spacing.md)

                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    HStack {
                        Text("Subcategory (Optional)")
                            .font(.headline)
                            .foregroundColor(Theme.Colors.textPrimary)

                        Spacer()

                        if let selected = selectedSubcategory {
                            HStack(spacing: 4) {
                                Text(selected.icon)
                                    .font(.caption)
                                Text(selected.name)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(selectedCat.color)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(selectedCat.color.opacity(0.1))
                            .cornerRadius(6)
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.md)

                    let allSubcategories = selectedCat.subcategories
                    let displayedSubcategories = expandedSubcategories ? allSubcategories : Array(allSubcategories.prefix(maxCategoriesBeforeExpand))
                    let hasMoreSubs = allSubcategories.count > maxCategoriesBeforeExpand

                    WrappingHStack(horizontalSpacing: Theme.Spacing.sm, verticalSpacing: Theme.Spacing.sm) {
                        // "None" option
                        SubcategoryChip(
                            subcategory: nil,
                            categoryColor: selectedCat.color,
                            isSelected: selectedSubcategory == nil,
                            action: {
                                withAnimation(.spring(response: 0.3)) {
                                    selectedSubcategory = nil
                                }
                            }
                        )

                        ForEach(displayedSubcategories) { subcategory in
                            SubcategoryChip(
                                subcategory: subcategory,
                                categoryColor: selectedCat.color,
                                isSelected: selectedSubcategory?.id == subcategory.id,
                                action: {
                                    withAnimation(.spring(response: 0.3)) {
                                        selectedSubcategory = subcategory
                                    }
                                }
                            )
                        }

                        // Show More / Show Less button for subcategories
                        if hasMoreSubs {
                            Button {
                                withAnimation(.spring(response: 0.3)) {
                                    expandedSubcategories.toggle()
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: expandedSubcategories ? "chevron.up" : "chevron.down")
                                        .font(.caption2)
                                    Text(expandedSubcategories ? "Less" : "More")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                                .padding(.horizontal, Theme.Spacing.sm)
                                .padding(.vertical, 6)
                                .background(Color.gray.opacity(0.1))
                                .foregroundColor(Theme.Colors.textSecondary)
                                .cornerRadius(20)
                            }
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, Theme.Spacing.md)
        .background(Theme.Colors.cardBackground)
        .cornerRadius(Theme.CornerRadius.lg)
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var isPresented = true
    @Previewable @State var onUpdate: ((String?, String?) -> Void)? = nil

    let mockTransaction = Transaction(
        id: "1",
        accountId: "acc1",
        accountName: "Checking",
        simplefinTransactionId: "txn1",
        amount: -45.50,
        currency: "USD",
        date: Int(Date().timeIntervalSince1970 * 1000),
        transactedAt: nil,
        description: "Whole Foods Market",
        payee: "Whole Foods",
        pending: false,
        categoryId: nil,
        subcategoryId: nil
    )

    TransactionDetailView(
        transaction: mockTransaction,
        categories: BudgetCategory.mockCategories,
        apiClient: APIClient.shared,
        isPresented: $isPresented,
        onCategoryUpdated: $onUpdate
    )
}
