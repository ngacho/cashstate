import SwiftUI

// MARK: - Categorizable Transaction (extends CategoryTransaction with categorization state)

struct CategorizableTransaction: Identifiable {
    let id: String
    let merchantName: String
    let amount: Double
    let date: Date
    let description: String
    var categoryId: String?
    var subcategoryId: String?

    var isExpense: Bool { amount < 0 }

    var displayAmount: String {
        let value = abs(amount)
        return String(format: "$%.2f", value)
    }

    var displayDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }
}

// MARK: - Uncategorized Transactions Card

struct UncategorizedTransactionsCard: View {
    let uncategorizedCount: Int
    @Binding var showManualCategorization: Bool
    let onAICategorizationTap: () -> Void

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(Theme.Colors.expense)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Categorize Your Transactions")
                        .font(.headline)
                        .foregroundColor(Theme.Colors.textPrimary)

                    Text("\(uncategorizedCount) transaction\(uncategorizedCount == 1 ? "" : "s") need categorization")
                        .font(.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                }

                Spacer()
            }

            HStack(spacing: Theme.Spacing.sm) {
                // Manual categorization button
                Button {
                    showManualCategorization = true
                } label: {
                    HStack {
                        Image(systemName: "hand.tap")
                            .font(.caption)
                        Text("Manual")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(Theme.Colors.primary.opacity(0.1))
                    .foregroundColor(Theme.Colors.primary)
                    .cornerRadius(Theme.CornerRadius.sm)
                }

                // AI categorization button
                Button {
                    onAICategorizationTap()
                } label: {
                    HStack {
                        Image(systemName: "sparkles")
                            .font(.caption)
                        Text("AI Categorize")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(Theme.Colors.primary)
                    .foregroundColor(.white)
                    .cornerRadius(Theme.CornerRadius.sm)
                }
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.expense.opacity(0.05))
        .cornerRadius(Theme.CornerRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                .stroke(Theme.Colors.expense.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - AI Categorization Progress Card (Inline)

struct AICategorizationProgressCard: View {
    let progress: Double
    let totalCount: Int

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(Theme.Colors.primary)
                    .font(.title3)
                    .symbolEffect(.pulse)

                VStack(alignment: .leading, spacing: 4) {
                    Text("AI Categorization in Progress")
                        .font(.headline)
                        .foregroundColor(Theme.Colors.textPrimary)

                    Text("Analyzing \(totalCount) transaction\(totalCount == 1 ? "" : "s")...")
                        .font(.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                }

                Spacer()
            }

            // Progress bar
            VStack(spacing: Theme.Spacing.xs) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.15))
                            .frame(height: 8)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(Theme.Colors.primary)
                            .frame(width: geometry.size.width * progress, height: 8)
                            .animation(.linear(duration: 0.3), value: progress)
                    }
                }
                .frame(height: 8)

                HStack {
                    Text("\(Int(progress * 100))%")
                        .font(.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                    Spacer()
                    if progress >= 1.0 {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(Theme.Colors.income)
                                .font(.caption)
                            Text("Complete")
                                .font(.caption)
                                .foregroundColor(Theme.Colors.income)
                        }
                    }
                }
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.primary.opacity(0.05))
        .cornerRadius(Theme.CornerRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                .stroke(Theme.Colors.primary.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Swipeable Categorization View

struct SwipeableCategorization: View {
    @Binding var isPresented: Bool
    @Binding var transactions: [CategorizableTransaction]
    let categories: [BudgetCategory]
    let apiClient: APIClient
    let allowEditingCategorized: Bool // Allow editing already categorized transactions

    @State private var currentIndex = 0
    @State private var offset: CGSize = .zero
    @State private var selectedCategory: BudgetCategory?
    @State private var selectedSubcategory: BudgetSubcategory?
    @State private var showSubcategories = false
    @State private var categorizedCount = 0
    @State private var pendingUpdates: [(transactionId: String, categoryId: String?, subcategoryId: String?)] = []
    @State private var isSaving = false

    init(isPresented: Binding<Bool>, transactions: Binding<[CategorizableTransaction]>, categories: [BudgetCategory], apiClient: APIClient, allowEditingCategorized: Bool = false) {
        self._isPresented = isPresented
        self._transactions = transactions
        self.categories = categories
        self.apiClient = apiClient
        self.allowEditingCategorized = allowEditingCategorized

        // Count already categorized transactions
        let alreadyCategorized = transactions.wrappedValue.filter { $0.categoryId != nil }.count
        self._categorizedCount = State(initialValue: alreadyCategorized)
    }

    private var currentTransaction: CategorizableTransaction? {
        guard currentIndex < transactions.count else { return nil }
        return transactions[currentIndex]
    }

    private var progress: Double {
        guard !transactions.isEmpty else { return 0 }
        return Double(categorizedCount) / Double(transactions.count)
    }

    private var hasUnsavedChanges: Bool {
        selectedCategory != nil || selectedSubcategory != nil
    }

    var body: some View {
        NavigationView {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()

                VStack(spacing: Theme.Spacing.lg) {
                    // Progress bar
                    VStack(spacing: Theme.Spacing.xs) {
                        HStack {
                            Text("\(categorizedCount) of \(transactions.count) categorized")
                                .font(.caption)
                                .foregroundColor(Theme.Colors.textSecondary)
                            Spacer()
                            Text("\(Int(progress * 100))%")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(Theme.Colors.primary)
                        }

                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.gray.opacity(0.15))
                                    .frame(height: 6)

                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Theme.Colors.primary)
                                    .frame(width: geometry.size.width * progress, height: 6)
                            }
                        }
                        .frame(height: 6)
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.top, Theme.Spacing.md)

                    // Swipe hints (show for first few transactions)
                    if currentIndex < 3 {
                        HStack(spacing: Theme.Spacing.md) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.left")
                                    .font(.caption2)
                                Text("Swipe left to skip")
                                    .font(.caption2)
                            }
                            .foregroundColor(Theme.Colors.textSecondary)

                            Text("•")
                                .font(.caption2)
                                .foregroundColor(Theme.Colors.textSecondary)

                            HStack(spacing: 4) {
                                Text("Swipe right to save")
                                    .font(.caption2)
                                Image(systemName: "arrow.right")
                                    .font(.caption2)
                            }
                            .foregroundColor(Theme.Colors.textSecondary)
                        }
                        .padding(.horizontal, Theme.Spacing.lg)
                        .transition(.opacity)
                    }

                    if let transaction = currentTransaction {
                        // Transaction card stack
                        ZStack {
                            // Next card preview (if exists)
                            if currentIndex + 1 < transactions.count {
                                TransactionCardView(
                                    transaction: transactions[currentIndex + 1],
                                    categories: categories,
                                    selectedCategory: .constant(nil),
                                    selectedSubcategory: .constant(nil),
                                    showSubcategories: .constant(false),
                                    onCategorySelect: { _ in },
                                    onSubcategorySelect: { _ in }
                                )
                                .scaleEffect(0.95)
                                .opacity(0.5)
                                .offset(y: 10)
                            }

                            // Current card
                            TransactionCardView(
                                transaction: transaction,
                                categories: categories,
                                selectedCategory: $selectedCategory,
                                selectedSubcategory: $selectedSubcategory,
                                showSubcategories: $showSubcategories,
                                onCategorySelect: { category in
                                    selectCategory(category)
                                },
                                onSubcategorySelect: { subcategory in
                                    selectedSubcategory = subcategory
                                    // Don't auto-advance - let user confirm
                                }
                            )
                            .offset(offset)
                            .rotationEffect(.degrees(Double(offset.width / 20)))
                            .gesture(
                                DragGesture()
                                    .onChanged { gesture in
                                        offset = gesture.translation
                                    }
                                    .onEnded { _ in
                                        handleSwipe()
                                    }
                            )

                            // Swipe indicators
                            if abs(offset.width) > 50 {
                                VStack {
                                    if offset.width > 0 {
                                        // Swipe right - Save indicator
                                        if selectedCategory != nil {
                                            VStack(spacing: 4) {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .font(.system(size: 50))
                                                    .foregroundColor(Theme.Colors.income)
                                                Text("Save")
                                                    .font(.headline)
                                                    .fontWeight(.bold)
                                                    .foregroundColor(Theme.Colors.income)
                                            }
                                            .padding(Theme.Spacing.md)
                                            .background(Color.white.opacity(0.95))
                                            .cornerRadius(Theme.CornerRadius.md)
                                            .shadow(radius: 8)
                                        } else {
                                            VStack(spacing: 4) {
                                                Image(systemName: "exclamationmark.circle.fill")
                                                    .font(.system(size: 50))
                                                    .foregroundColor(.orange)
                                                Text("Select category first")
                                                    .font(.caption)
                                                    .fontWeight(.bold)
                                                    .foregroundColor(.orange)
                                            }
                                            .padding(Theme.Spacing.md)
                                            .background(Color.white.opacity(0.95))
                                            .cornerRadius(Theme.CornerRadius.md)
                                            .shadow(radius: 8)
                                        }
                                    } else {
                                        // Swipe left - Skip indicator
                                        VStack(spacing: 4) {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.system(size: 50))
                                                .foregroundColor(Theme.Colors.textSecondary)
                                            Text("Skip")
                                                .font(.headline)
                                                .fontWeight(.bold)
                                                .foregroundColor(Theme.Colors.textSecondary)
                                        }
                                        .padding(Theme.Spacing.md)
                                        .background(Color.white.opacity(0.95))
                                        .cornerRadius(Theme.CornerRadius.md)
                                        .shadow(radius: 8)
                                    }
                                }
                                .opacity(min(abs(offset.width) / 100.0, 1.0))
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.lg)

                        // Action buttons (below card)
                        HStack(spacing: Theme.Spacing.sm) {
                            // Skip button (always visible)
                            Button {
                                skipTransaction()
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "xmark")
                                        .font(.caption)
                                    Text("Skip")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }
                                .foregroundColor(Theme.Colors.textSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, Theme.Spacing.md)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(Theme.CornerRadius.md)
                            }

                            // Done button (shows when category is selected)
                            if selectedCategory != nil {
                                Button {
                                    categorizeAndNext()
                                } label: {
                                    HStack(spacing: 4) {
                                        Text("Done")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                        Image(systemName: "checkmark")
                                            .font(.caption)
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, Theme.Spacing.md)
                                    .background(Theme.Colors.primary)
                                    .cornerRadius(Theme.CornerRadius.md)
                                }
                                .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.lg)

                    } else {
                        // All done
                        CompletionView(
                            categorizedCount: categorizedCount,
                            totalCount: transactions.count,
                            onDismiss: {
                                isPresented = false
                            }
                        )
                    }

                    Spacer()
                }
            }
            .navigationTitle("Categorize Transactions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
            .onDisappear {
                // Save any remaining pending updates when view is dismissed
                Task {
                    await savePendingUpdates()
                }
            }
        }
    }

    private func getCategoryForSwipe() -> BudgetCategory? {
        // For now, just return the first category based on swipe direction
        // In a real app, this could be smarter (e.g., most used category for this merchant)
        return categories.first { $0.type == .expense }
    }

    private func handleSwipe() {
        if abs(offset.width) > 100 {
            if offset.width > 0 {
                // Swipe right - categorize with current selection
                if selectedCategory != nil {
                    categorizeAndNext()
                } else {
                    // No category selected, return to center
                    withAnimation(.spring()) {
                        offset = .zero
                    }
                }
            } else {
                // Swipe left - skip
                skipTransaction()
            }
        } else {
            // Weak swipe - return to center
            withAnimation(.spring()) {
                offset = .zero
            }
        }
    }

    private func selectCategory(_ category: BudgetCategory) {
        withAnimation(.spring(response: 0.3)) {
            selectedCategory = category
            selectedSubcategory = nil // Reset subcategory when category changes

            // If category has no subcategories, auto-categorize after a short delay
            if category.subcategories.isEmpty {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    if selectedCategory?.id == category.id { // Make sure user hasn't changed selection
                        // Auto-advance disabled - user must tap Next
                        // categorizeAndNext()
                    }
                }
            } else {
                // Show subcategories
                showSubcategories = true
            }
        }
    }

    private func categorizeAndNext() {
        guard let category = selectedCategory else { return }
        categorizeTransaction(category: category, subcategory: selectedSubcategory)
    }

    private func categorizeTransaction(category: BudgetCategory, subcategory: BudgetSubcategory?) {
        guard currentIndex < transactions.count else { return }

        // Track if this was previously uncategorized
        let wasUncategorized = transactions[currentIndex].categoryId == nil

        let transaction = transactions[currentIndex]
        transactions[currentIndex].categoryId = category.id
        transactions[currentIndex].subcategoryId = subcategory?.id

        // Add to pending updates for batch saving
        pendingUpdates.append((
            transactionId: transaction.id,
            categoryId: category.id,
            subcategoryId: subcategory?.id
        ))

        // Batch save every 10 transactions
        if pendingUpdates.count >= 10 {
            Task {
                await savePendingUpdates()
            }
        }

        withAnimation(.spring()) {
            offset = CGSize(width: 500, height: 0)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            offset = .zero
            currentIndex += 1
            if wasUncategorized {
                categorizedCount += 1
            }
            selectedCategory = nil
            selectedSubcategory = nil
            showSubcategories = false
        }
    }

    private func savePendingUpdates() async {
        guard !pendingUpdates.isEmpty, !isSaving else { return }

        isSaving = true
        let updates = pendingUpdates
        pendingUpdates = []

        do {
            let _ = try await apiClient.batchUpdateTransactions(updates)
            // Success - updates are saved
        } catch {
            // On error, add them back to retry later
            await MainActor.run {
                pendingUpdates.append(contentsOf: updates)
                isSaving = false
            }
        }

        await MainActor.run {
            isSaving = false
        }
    }

    private func skipTransaction() {
        withAnimation(.spring()) {
            offset = CGSize(width: -500, height: 0)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            offset = .zero
            currentIndex += 1
            selectedCategory = nil
            selectedSubcategory = nil
            showSubcategories = false
        }
    }
}

// MARK: - Transaction Card View

struct TransactionCardView: View {
    let transaction: CategorizableTransaction
    let categories: [BudgetCategory]
    @Binding var selectedCategory: BudgetCategory?
    @Binding var selectedSubcategory: BudgetSubcategory?
    @Binding var showSubcategories: Bool
    let onCategorySelect: (BudgetCategory) -> Void
    let onSubcategorySelect: (BudgetSubcategory?) -> Void

    @State private var expandedCategories = false
    @State private var expandedSubcategories = false

    private let maxCategoriesBeforeExpand = 8  // ~2 rows of 4 chips each

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            // Transaction info
            VStack(spacing: Theme.Spacing.md) {
                // Amount
                Text(transaction.displayAmount)
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(transaction.isExpense ? Theme.Colors.expense : Theme.Colors.income)

                // Merchant
                Text(transaction.merchantName)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.Colors.textPrimary)
                    .multilineTextAlignment(.center)

                // Date and description
                VStack(spacing: 4) {
                    Text(transaction.displayDate)
                        .font(.subheadline)
                        .foregroundColor(Theme.Colors.textSecondary)

                    if !transaction.description.isEmpty && transaction.description != transaction.merchantName {
                        Text(transaction.description)
                            .font(.caption)
                            .foregroundColor(Theme.Colors.textSecondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                    }
                }
            }
            .padding(.top, Theme.Spacing.xl)
            .padding(.horizontal, Theme.Spacing.lg)

            // Category and Subcategory Selection (inside card)
            VStack(spacing: Theme.Spacing.md) {
                // Category chips (wrapping layout, max 2 rows)
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Select Category")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(Theme.Colors.textSecondary)
                        .padding(.horizontal, Theme.Spacing.sm)

                    let expenseCategories = categories.filter { $0.type == .expense }
                    let displayedCategories = expandedCategories ? expenseCategories : Array(expenseCategories.prefix(maxCategoriesBeforeExpand))
                    let hasMore = expenseCategories.count > maxCategoriesBeforeExpand

                    WrappingHStack(horizontalSpacing: Theme.Spacing.sm, verticalSpacing: Theme.Spacing.sm) {
                        ForEach(displayedCategories) { category in
                            CategoryChip(
                                category: category,
                                isSelected: selectedCategory?.id == category.id,
                                action: {
                                    onCategorySelect(category)
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
                    .padding(.horizontal, Theme.Spacing.sm)
                }

                // Subcategory chips (shown when category is selected)
                if let selectedCat = selectedCategory, !selectedCat.subcategories.isEmpty {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text("Select Subcategory (Optional)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(Theme.Colors.textSecondary)
                            .padding(.horizontal, Theme.Spacing.sm)

                        let allSubcategories = selectedCat.subcategories
                        let displayedSubcategories = expandedSubcategories ? allSubcategories : Array(allSubcategories.prefix(maxCategoriesBeforeExpand))
                        let hasMoreSubs = allSubcategories.count > maxCategoriesBeforeExpand

                        WrappingHStack(horizontalSpacing: Theme.Spacing.sm, verticalSpacing: Theme.Spacing.sm) {
                            // "None" option for optional subcategory
                            SubcategoryChip(
                                subcategory: nil,
                                categoryColor: selectedCat.color,
                                isSelected: selectedSubcategory == nil && showSubcategories,
                                action: {
                                    onSubcategorySelect(nil)
                                }
                            )

                            ForEach(displayedSubcategories) { subcategory in
                                SubcategoryChip(
                                    subcategory: subcategory,
                                    categoryColor: selectedCat.color,
                                    isSelected: selectedSubcategory?.id == subcategory.id,
                                    action: {
                                        onSubcategorySelect(subcategory)
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
                        .padding(.horizontal, Theme.Spacing.sm)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.bottom, Theme.Spacing.md)
        }
        .frame(maxWidth: .infinity)
        .background(Theme.Colors.cardBackground)
        .cornerRadius(Theme.CornerRadius.lg)
        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
}

// MARK: - Wrapping HStack (content-sized, no fixed widths)

struct WrappingHStack: Layout {
    var horizontalSpacing: CGFloat = 8
    var verticalSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlexboxLayout(
            containerWidth: proposal.width ?? 0,
            horizontalSpacing: horizontalSpacing,
            verticalSpacing: verticalSpacing
        )

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            _ = result.add(width: size.width, height: size.height)
        }

        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlexboxLayout(
            containerWidth: bounds.width,
            horizontalSpacing: horizontalSpacing,
            verticalSpacing: verticalSpacing
        )

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let position = result.add(width: size.width, height: size.height)
            subview.place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: ProposedViewSize(size)
            )
        }
    }

    class FlexboxLayout {
        let containerWidth: CGFloat
        let horizontalSpacing: CGFloat
        let verticalSpacing: CGFloat

        private var currentX: CGFloat = 0
        private var currentY: CGFloat = 0
        private var lineHeight: CGFloat = 0
        private var totalHeight: CGFloat = 0

        var size: CGSize {
            CGSize(width: containerWidth, height: totalHeight)
        }

        init(containerWidth: CGFloat, horizontalSpacing: CGFloat, verticalSpacing: CGFloat) {
            self.containerWidth = containerWidth
            self.horizontalSpacing = horizontalSpacing
            self.verticalSpacing = verticalSpacing
        }

        func add(width: CGFloat, height: CGFloat) -> CGPoint {
            if currentX + width > containerWidth && currentX > 0 {
                // Move to next line
                currentX = 0
                currentY += lineHeight + verticalSpacing
                lineHeight = 0
            }

            let position = CGPoint(x: currentX, y: currentY)

            currentX += width + horizontalSpacing
            lineHeight = max(lineHeight, height)
            totalHeight = max(totalHeight, currentY + lineHeight)

            return position
        }
    }
}

// MARK: - Swipe Indicator

enum SwipeDirection {
    case left, right
}

struct SwipeIndicator: View {
    let direction: SwipeDirection
    let category: BudgetCategory?

    var body: some View {
        VStack {
            if let category = category {
                Text(category.icon)
                    .font(.system(size: 60))
                Text(category.name)
                    .font(.headline)
                    .foregroundColor(category.color)
            }
        }
        .padding(Theme.Spacing.md)
        .background(Color.white.opacity(0.9))
        .cornerRadius(Theme.CornerRadius.md)
        .shadow(radius: 5)
    }
}

// MARK: - Category Chip

struct CategoryChip: View {
    let category: BudgetCategory
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(category.icon)
                    .font(.body)
                Text(category.name)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            .background(isSelected ? category.color.opacity(0.2) : Color.gray.opacity(0.1))
            .foregroundColor(isSelected ? category.color : Theme.Colors.textSecondary)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? category.color : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Subcategory Chip

struct SubcategoryChip: View {
    let subcategory: BudgetSubcategory?
    let categoryColor: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let subcategory = subcategory {
                    Text(subcategory.icon)
                        .font(.body)
                    Text(subcategory.name)
                        .font(.subheadline)
                        .fontWeight(isSelected ? .semibold : .regular)
                } else {
                    // "None" option
                    Text("None")
                        .font(.subheadline)
                        .fontWeight(isSelected ? .semibold : .regular)
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            .background(isSelected ? categoryColor.opacity(0.2) : Color.gray.opacity(0.1))
            .foregroundColor(isSelected ? categoryColor : Theme.Colors.textSecondary)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? categoryColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Subcategory Picker

struct SubcategoryPickerView: View {
    let category: BudgetCategory
    @Binding var isPresented: Bool
    let onSelect: (BudgetSubcategory?) -> Void

    var body: some View {
        NavigationView {
            List {
                // No subcategory option
                Button {
                    onSelect(nil)
                    isPresented = false
                } label: {
                    HStack {
                        Text(category.icon)
                            .font(.title2)
                        Text("No subcategory")
                            .foregroundColor(Theme.Colors.textPrimary)
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }

                // Subcategories
                ForEach(category.subcategories) { subcategory in
                    Button {
                        onSelect(subcategory)
                        isPresented = false
                    } label: {
                        HStack {
                            Text(subcategory.icon)
                                .font(.title2)
                            Text(subcategory.name)
                                .foregroundColor(Theme.Colors.textPrimary)
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Select Subcategory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

// MARK: - Completion View

struct CompletionView: View {
    let categorizedCount: Int
    let totalCount: Int
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(Theme.Colors.income)

            VStack(spacing: Theme.Spacing.sm) {
                Text("All Done!")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(Theme.Colors.textPrimary)

                Text("Categorized \(categorizedCount) of \(totalCount) transactions")
                    .font(.subheadline)
                    .foregroundColor(Theme.Colors.textSecondary)
            }

            Button {
                onDismiss()
            } label: {
                Text("Finish")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.md)
                    .background(Theme.Colors.primary)
                    .cornerRadius(Theme.CornerRadius.md)
            }
            .padding(.horizontal, Theme.Spacing.xl)

            Spacer()
        }
    }
}

// MARK: - AI Categorization View

struct AICategorization: View {
    @Binding var isPresented: Bool
    @Binding var transactions: [CategorizableTransaction]
    let categories: [BudgetCategory]
    let apiClient: APIClient

    @State private var isProcessing = false
    @State private var progress: Double = 0
    @State private var categorizedTransactions: [(transaction: CategorizableTransaction, category: BudgetCategory, subcategory: BudgetSubcategory?)] = []
    @State private var showReview = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()

                if isProcessing {
                    ProcessingView(progress: $progress)
                } else if showReview {
                    ReviewView(
                        categorizedTransactions: $categorizedTransactions,
                        categories: categories,
                        onApprove: {
                            applyCategorizationsAndDismiss()
                        }
                    )
                } else {
                    StartView(
                        transactionCount: transactions.count,
                        onStart: {
                            startAICategorization()
                        }
                    )
                }
            }
            .navigationTitle("AI Categorization")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !isProcessing {
                        Button("Cancel") {
                            isPresented = false
                        }
                    }
                }
            }
        }
    }

    private func startAICategorization() {
        isProcessing = true
        errorMessage = nil

        Task {
            do {
                // Call backend AI categorization
                let transactionIds = transactions.map { $0.id }
                let response = try await apiClient.categorizeWithAI(transactionIds: transactionIds, force: false)

                // Create category lookup map
                var categoryMap: [String: BudgetCategory] = [:]
                for category in categories {
                    categoryMap[category.id] = category
                }

                // Map results to UI model
                var results: [(transaction: CategorizableTransaction, category: BudgetCategory, subcategory: BudgetSubcategory?)] = []

                for result in response.results {
                    guard let transaction = transactions.first(where: { $0.id == result.transactionId }),
                          let categoryId = result.categoryId,
                          let category = categoryMap[categoryId] else {
                        continue
                    }

                    var subcategory: BudgetSubcategory?
                    if let subcategoryId = result.subcategoryId {
                        subcategory = category.subcategories.first { $0.id == subcategoryId }
                    }

                    results.append((transaction, category, subcategory))
                }

                await MainActor.run {
                    categorizedTransactions = results
                    progress = 1.0
                    isProcessing = false
                    showReview = true
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isProcessing = false
                }
            }
        }

        // Animate progress while waiting for API
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
            if !isProcessing || progress >= 0.95 {
                timer.invalidate()
            } else {
                progress += 0.02
            }
        }
    }

    private func applyCategorizationsAndDismiss() {
        isProcessing = true

        Task {
            // Build batch updates
            let updates = categorizedTransactions.map { item in
                (transactionId: item.transaction.id,
                 categoryId: item.category.id,
                 subcategoryId: item.subcategory?.id)
            }

            do {
                // Save to backend
                let _ = try await apiClient.batchUpdateTransactions(updates)

                // Update local state
                await MainActor.run {
                    for (index, item) in categorizedTransactions.enumerated() {
                        if index < transactions.count {
                            transactions[index].categoryId = item.category.id
                            transactions[index].subcategoryId = item.subcategory?.id
                        }
                    }
                    isPresented = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isProcessing = false
                }
            }
        }
    }
}

// MARK: - AI Processing View

struct ProcessingView: View {
    @Binding var progress: Double

    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer()

            Image(systemName: "sparkles")
                .font(.system(size: 60))
                .foregroundColor(Theme.Colors.primary)
                .symbolEffect(.pulse)

            VStack(spacing: Theme.Spacing.sm) {
                Text("Analyzing Transactions...")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.Colors.textPrimary)

                Text("Using AI to categorize your spending")
                    .font(.subheadline)
                    .foregroundColor(Theme.Colors.textSecondary)
            }

            // Progress bar
            VStack(spacing: Theme.Spacing.xs) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.15))
                            .frame(height: 8)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(Theme.Colors.primary)
                            .frame(width: geometry.size.width * progress, height: 8)
                    }
                }
                .frame(height: 8)

                Text("\(Int(progress * 100))%")
                    .font(.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
            }
            .padding(.horizontal, Theme.Spacing.xl * 2)

            Spacer()
        }
        .padding(Theme.Spacing.xl)
    }
}

// MARK: - AI Start View

struct StartView: View {
    let transactionCount: Int
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer()

            Image(systemName: "sparkles")
                .font(.system(size: 80))
                .foregroundColor(Theme.Colors.primary)

            VStack(spacing: Theme.Spacing.md) {
                Text("AI-Powered Categorization")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(Theme.Colors.textPrimary)
                    .multilineTextAlignment(.center)

                Text("Let AI automatically categorize \(transactionCount) transaction\(transactionCount == 1 ? "" : "s") based on merchant names and spending patterns.")
                    .font(.subheadline)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Spacing.xl)
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                FeatureRow(icon: "checkmark.circle", text: "Smart merchant recognition")
                FeatureRow(icon: "checkmark.circle", text: "Learning from your patterns")
                FeatureRow(icon: "checkmark.circle", text: "Review before applying")
            }
            .padding(.horizontal, Theme.Spacing.xl)

            Button {
                onStart()
            } label: {
                Text("Start AI Categorization")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.md)
                    .background(Theme.Colors.primary)
                    .cornerRadius(Theme.CornerRadius.md)
            }
            .padding(.horizontal, Theme.Spacing.xl)

            Spacer()
        }
        .padding(Theme.Spacing.lg)
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: icon)
                .foregroundColor(Theme.Colors.income)
                .font(.body)
            Text(text)
                .font(.subheadline)
                .foregroundColor(Theme.Colors.textPrimary)
        }
    }
}

// MARK: - AI Review View

struct ReviewView: View {
    @Binding var categorizedTransactions: [(transaction: CategorizableTransaction, category: BudgetCategory, subcategory: BudgetSubcategory?)]
    let categories: [BudgetCategory]
    let onApprove: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: Theme.Spacing.sm) {
                Text("Review & Approve")
                    .font(.headline)
                    .foregroundColor(Theme.Colors.textPrimary)

                Text("Review AI suggestions and make changes if needed")
                    .font(.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
            }
            .padding(Theme.Spacing.md)
            .background(Theme.Colors.cardBackground)

            // List of categorized transactions
            ScrollView {
                LazyVStack(spacing: Theme.Spacing.sm) {
                    ForEach(categorizedTransactions.indices, id: \.self) { index in
                        ReviewTransactionRow(
                            transaction: categorizedTransactions[index].transaction,
                            category: categorizedTransactions[index].category,
                            subcategory: categorizedTransactions[index].subcategory
                        )
                    }
                }
                .padding(Theme.Spacing.md)
            }

            // Approve button
            VStack(spacing: Theme.Spacing.sm) {
                Button {
                    onApprove()
                } label: {
                    Text("Apply Categorizations")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.md)
                        .background(Theme.Colors.primary)
                        .cornerRadius(Theme.CornerRadius.md)
                }
                .padding(.horizontal, Theme.Spacing.md)

                Text("You can always change categories later")
                    .font(.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
            }
            .padding(.vertical, Theme.Spacing.md)
            .background(Theme.Colors.cardBackground)
        }
    }
}

struct ReviewTransactionRow: View {
    let transaction: CategorizableTransaction
    let category: BudgetCategory
    let subcategory: BudgetSubcategory?

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.merchantName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(Theme.Colors.textPrimary)

                Text(transaction.displayAmount)
                    .font(.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
            }

            Spacer()

            HStack(spacing: 4) {
                Text(category.icon)
                    .font(.body)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(category.name)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(category.color)

                    if let subcategory = subcategory {
                        Text(subcategory.name)
                            .font(.caption2)
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                }
            }
        }
        .padding(Theme.Spacing.sm)
        .background(Theme.Colors.cardBackground)
        .cornerRadius(Theme.CornerRadius.sm)
    }
}

// MARK: - Mock Data

extension CategorizableTransaction {
    static let mockUncategorized: [CategorizableTransaction] = [
        CategorizableTransaction(id: "u1", merchantName: "Starbucks", amount: -5.50, date: Date().addingTimeInterval(-86400), description: "Morning coffee"),
        CategorizableTransaction(id: "u2", merchantName: "Whole Foods", amount: -85.30, date: Date().addingTimeInterval(-86400 * 2), description: "Weekly groceries"),
        CategorizableTransaction(id: "u3", merchantName: "Shell Gas Station", amount: -45.00, date: Date().addingTimeInterval(-86400 * 3), description: "Fuel"),
        CategorizableTransaction(id: "u4", merchantName: "AMC Theatres", amount: -28.50, date: Date().addingTimeInterval(-86400 * 4), description: "Movie tickets"),
        CategorizableTransaction(id: "u5", merchantName: "Target", amount: -156.78, date: Date().addingTimeInterval(-86400 * 5), description: "Shopping"),
    ]
}

// MARK: - Previews

#Preview("Uncategorized Card") {
    @Previewable @State var showManual = false

    return VStack {
        UncategorizedTransactionsCard(
            uncategorizedCount: 15,
            showManualCategorization: $showManual,
            onAICategorizationTap: {
                print("AI categorization tapped")
            }
        )
        .padding()

        AICategorizationProgressCard(
            progress: 0.65,
            totalCount: 15
        )
        .padding()

        Spacer()
    }
    .background(Theme.Colors.background)
}

#Preview("Swipeable Categorization") {
    @Previewable @State var isPresented = true
    @Previewable @State var transactions = CategorizableTransaction.mockUncategorized

    return SwipeableCategorization(
        isPresented: $isPresented,
        transactions: $transactions,
        categories: BudgetCategory.mockCategories,
        apiClient: APIClient()
    )
}

#Preview("AI Categorization") {
    @Previewable @State var isPresented = true
    @Previewable @State var transactions = CategorizableTransaction.mockUncategorized

    return AICategorization(
        isPresented: $isPresented,
        transactions: $transactions,
        categories: BudgetCategory.mockCategories,
        apiClient: APIClient()
    )
}
