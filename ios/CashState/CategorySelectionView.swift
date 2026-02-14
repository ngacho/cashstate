import SwiftUI

struct CategorySelectionView: View {
    let categories: [BudgetCategory]
    @Binding var includedCategories: Set<String>
    @Binding var excludedCategories: Set<String>
    @Binding var isPresented: Bool

    @State private var showAddCategory = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    // All/None buttons
                    HStack(spacing: Theme.Spacing.sm) {
                        Button {
                            includedCategories = Set(categories.map { $0.id })
                            excludedCategories.removeAll()
                        } label: {
                            Text("All categories")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, Theme.Spacing.sm)
                                .background(Theme.Colors.cardBackground)
                                .foregroundColor(Theme.Colors.textPrimary)
                                .cornerRadius(Theme.CornerRadius.sm)
                        }

                        Button {
                            includedCategories.removeAll()
                            excludedCategories.removeAll()
                        } label: {
                            Text("No categories")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, Theme.Spacing.sm)
                                .background(Theme.Colors.cardBackground)
                                .foregroundColor(Theme.Colors.textPrimary)
                                .cornerRadius(Theme.CornerRadius.sm)
                        }
                    }
                    .padding(.horizontal)

                    // Select Categories Section
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        HStack {
                            Text("Select Categories")
                                .font(.subheadline)
                                .foregroundColor(Theme.Colors.textSecondary)
                            Spacer()
                        }
                        .padding(.horizontal)

                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: Theme.Spacing.md) {
                            ForEach(categories) { category in
                                CategorySelectButton(
                                    category: category,
                                    isIncluded: includedCategories.contains(category.id),
                                    isExcluded: excludedCategories.contains(category.id)
                                ) {
                                    toggleCategorySelection(category.id)
                                }
                            }

                            // Add new category button
                            Button {
                                showAddCategory = true
                            } label: {
                                VStack(spacing: 4) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                                            .fill(Theme.Colors.cardBackground.opacity(0.5))
                                            .frame(width: 60, height: 60)

                                        Image(systemName: "plus")
                                            .font(.title2)
                                            .foregroundColor(Theme.Colors.textSecondary)
                                    }

                                    Text("New")
                                        .font(.caption2)
                                        .foregroundColor(Theme.Colors.textSecondary)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Exclude Categories Section
                    if !excludedCategories.isEmpty {
                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            HStack {
                                Text("Exclude Categories")
                                    .font(.subheadline)
                                    .foregroundColor(Theme.Colors.textSecondary)
                                Spacer()
                                Button("Clear All") {
                                    excludedCategories.removeAll()
                                }
                                .font(.caption)
                                .foregroundColor(Theme.Colors.primary)
                            }
                            .padding(.horizontal)

                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: Theme.Spacing.md) {
                                ForEach(categories.filter { excludedCategories.contains($0.id) }) { category in
                                    CategorySelectButton(
                                        category: category,
                                        isIncluded: false,
                                        isExcluded: true
                                    ) {
                                        toggleCategorySelection(category.id)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }

                    Spacer()
                }
                .padding(.vertical)
            }
            .background(Theme.Colors.background)
            .navigationTitle("Categories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showAddCategory) {
                AddCategoryView(isPresented: $showAddCategory)
            }
        }
    }

    private func toggleCategorySelection(_ categoryId: String) {
        if includedCategories.contains(categoryId) {
            includedCategories.remove(categoryId)
            excludedCategories.insert(categoryId)
        } else if excludedCategories.contains(categoryId) {
            excludedCategories.remove(categoryId)
        } else {
            includedCategories.insert(categoryId)
        }
    }
}

// MARK: - Category Select Button

struct CategorySelectButton: View {
    let category: BudgetCategory
    let isIncluded: Bool
    let isExcluded: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    Text(category.icon)
                        .font(.title2)
                        .frame(width: 60, height: 60)
                        .background(backgroundColor)
                        .cornerRadius(Theme.CornerRadius.md)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                                .stroke(borderColor, lineWidth: 2)
                        )

                    if isIncluded {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.white)
                            .background(Circle().fill(category.color.color))
                            .offset(x: 4, y: -4)
                    } else if isExcluded {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.white)
                            .background(Circle().fill(Color.red))
                            .offset(x: 4, y: -4)
                    }
                }

                Text(category.name)
                    .font(.caption2)
                    .foregroundColor(Theme.Colors.textPrimary)
                    .lineLimit(1)
                    .frame(width: 70)
            }
        }
    }

    private var backgroundColor: Color {
        if isIncluded {
            return category.color.color.opacity(0.2)
        } else if isExcluded {
            return Color.red.opacity(0.1)
        } else {
            return Theme.Colors.cardBackground.opacity(0.5)
        }
    }

    private var borderColor: Color {
        if isIncluded {
            return category.color.color
        } else if isExcluded {
            return Color.red
        } else {
            return Color.clear
        }
    }
}

#Preview {
    CategorySelectionView(
        categories: BudgetCategory.mockCategories,
        includedCategories: .constant(Set(["1", "2"])),
        excludedCategories: .constant(Set(["3"])),
        isPresented: .constant(true)
    )
}
