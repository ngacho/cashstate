import SwiftUI

struct AddCategoryView: View {
    @Binding var isPresented: Bool
    var onSave: ((BudgetCategory) -> Void)?

    @State private var categoryName: String = ""
    @State private var selectedType: BudgetCategory.CategoryType = .expense
    @State private var selectedIcon: String = "🎨"
    @State private var selectedColor: BudgetCategory.CategoryColor = .blue
    @State private var isMainCategory: Bool = true
    @State private var subcategories: [SubcategoryItem] = []
    @State private var showAddSubcategory = false
    @State private var showSubcategoryInfo = false


    let availableIcons = [
        "🍿", "🍔", "🚗", "🏠", "❤️", "🛍️", "✈️", "🎮",
        "📱", "💼", "🎓", "⚽", "🎵", "🎨", "🍕", "☕",
        "🎁", "💰", "🏋️", "🎬", "📚", "🌳", "🍜", "🎤"
    ]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    // Category Type Toggle
                    HStack(spacing: 0) {
                        ForEach(BudgetCategory.CategoryType.allCases, id: \.self) { type in
                            Button {
                                selectedType = type
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: type == .expense ? "arrow.down" : "arrow.up")
                                        .font(.caption)
                                    Text(type.rawValue)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, Theme.Spacing.sm)
                                .background(selectedType == type ? Theme.Colors.primary : Theme.Colors.cardBackground.opacity(0.5))
                                .foregroundColor(selectedType == type ? .white : Theme.Colors.textSecondary)
                            }
                        }
                    }
                    .background(Theme.Colors.cardBackground)
                    .cornerRadius(Theme.CornerRadius.md)
                    .padding(.horizontal)

                    // Icon Preview and Name
                    HStack(spacing: Theme.Spacing.md) {
                        // Icon preview
                        Text(selectedIcon)
                            .font(.system(size: 48))
                            .frame(width: 100, height: 100)
                            .background(selectedColor.color.opacity(0.2))
                            .cornerRadius(Theme.CornerRadius.lg)

                        // Name input
                        TextField("Name", text: $categoryName)
                            .font(.title3)
                            .fontWeight(.medium)
                            .foregroundColor(Theme.Colors.textPrimary)
                            .padding()
                            .background(Theme.Colors.cardBackground.opacity(0.5))
                            .cornerRadius(Theme.CornerRadius.md)
                    }
                    .padding(.horizontal)

                    // Color Selection
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Theme.Spacing.md) {
                            ForEach(BudgetCategory.CategoryColor.allCases, id: \.self) { color in
                                Button {
                                    selectedColor = color
                                } label: {
                                    Circle()
                                        .fill(color.color)
                                        .frame(width: 50, height: 50)
                                        .overlay(
                                            Circle()
                                                .stroke(selectedColor == color ? Color.white : Color.clear, lineWidth: 3)
                                                .padding(3)
                                        )
                                        .overlay(
                                            Circle()
                                                .stroke(selectedColor == color ? color.color : Color.clear, lineWidth: 2)
                                        )
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Icon Selection
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text("Select Icon")
                            .font(.subheadline)
                            .foregroundColor(Theme.Colors.textSecondary)
                            .padding(.horizontal)

                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: Theme.Spacing.sm) {
                            ForEach(availableIcons, id: \.self) { icon in
                                Button {
                                    selectedIcon = icon
                                } label: {
                                    Text(icon)
                                        .font(.title2)
                                        .frame(width: 50, height: 50)
                                        .background(
                                            selectedIcon == icon
                                            ? selectedColor.color.opacity(0.2)
                                            : Theme.Colors.cardBackground.opacity(0.5)
                                        )
                                        .cornerRadius(Theme.CornerRadius.sm)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                                                .stroke(
                                                    selectedIcon == icon ? selectedColor.color : Color.clear,
                                                    lineWidth: 2
                                                )
                                        )
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Main Category Button
                    Button {
                        isMainCategory = true
                    } label: {
                        HStack {
                            Image(systemName: "square.grid.2x2")
                                .foregroundColor(isMainCategory ? .white : Theme.Colors.textPrimary)
                            Text("Main Category")
                                .fontWeight(.medium)
                                .foregroundColor(isMainCategory ? .white : Theme.Colors.textPrimary)
                            Spacer()
                        }
                        .padding()
                        .background(isMainCategory ? selectedColor.color : Theme.Colors.cardBackground)
                        .cornerRadius(Theme.CornerRadius.md)
                    }
                    .padding(.horizontal)

                    // Subcategory Section
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        HStack {
                            Text("Subcategories (Optional)")
                                .font(.headline)
                                .foregroundColor(Theme.Colors.textPrimary)
                            Button {
                                showSubcategoryInfo = true
                            } label: {
                                Image(systemName: "info.circle")
                                    .foregroundColor(Theme.Colors.textSecondary)
                            }
                            Spacer()
                        }
                        .padding(.horizontal)

                        // Current subcategories
                        if !subcategories.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: Theme.Spacing.sm) {
                                    ForEach(subcategories) { subcategory in
                                        HStack(spacing: 4) {
                                            Text(subcategory.icon)
                                                .font(.caption)
                                            Text(subcategory.name)
                                                .font(.caption)
                                                .fontWeight(.medium)
                                        }
                                        .padding(.horizontal, Theme.Spacing.sm)
                                        .padding(.vertical, 6)
                                        .background(selectedColor.color.opacity(0.15))
                                        .cornerRadius(Theme.CornerRadius.sm)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }

                        // Add subcategory button
                        Button {
                            showAddSubcategory = true
                        } label: {
                            HStack(spacing: Theme.Spacing.sm) {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(selectedColor.color)
                                Text("Add Subcategory")
                                    .fontWeight(.medium)
                                    .foregroundColor(Theme.Colors.textPrimary)
                                Spacer()
                            }
                            .padding()
                            .background(Theme.Colors.cardBackground)
                            .cornerRadius(Theme.CornerRadius.md)
                        }
                        .padding(.horizontal)

                        // Single example
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            Text("Example: Entertainment → Movies, Music, Activities")
                                .font(.caption)
                                .foregroundColor(Theme.Colors.textSecondary)
                                .padding(.horizontal)
                        }
                    }
                    .sheet(isPresented: $showAddSubcategory) {
                        AddSubcategoryToNewCategoryView(
                            categoryColor: selectedColor,
                            isPresented: $showAddSubcategory
                        ) { newSubcategory in
                            subcategories.append(newSubcategory)
                        }
                    }

                    // Add Category Button
                    Button {
                        saveCategory()
                    } label: {
                        Text("Add Category")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(categoryName.isEmpty ? Color.gray.opacity(0.3) : selectedColor.color)
                            .foregroundColor(.white)
                            .cornerRadius(Theme.CornerRadius.md)
                    }
                    .disabled(categoryName.isEmpty)
                    .padding(.horizontal)
                    .padding(.top, Theme.Spacing.md)

                    Spacer(minLength: Theme.Spacing.xl)
                }
                .padding(.vertical)
            }
            .background(Theme.Colors.background)
            .navigationTitle("Add Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
            .alert("Subcategories", isPresented: $showSubcategoryInfo) {
                Button("OK") { }
            } message: {
                Text("Create subcategories to further organize your transactions the way you want it")
            }
        }
    }

    private func saveCategory() {
        guard !categoryName.isEmpty else { return }

        let budgetSubcategories = subcategories.map { item in
            BudgetSubcategory(
                id: UUID().uuidString,
                name: item.name,
                icon: item.icon,
                budgetAmount: nil,
                spentAmount: 0.0,
                transactionCount: 0
            )
        }

        let newCategory = BudgetCategory(
            id: UUID().uuidString,
            name: categoryName,
            icon: selectedIcon,
            color: selectedColor,
            type: selectedType,
            subcategories: budgetSubcategories,
            budgetAmount: nil,
            spentAmount: 0.0
        )

        onSave?(newCategory)
        isPresented = false
    }
}

// MARK: - Subcategory Item

struct SubcategoryItem: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
}

// MARK: - Add Subcategory to New Category View

struct AddSubcategoryToNewCategoryView: View {
    let categoryColor: BudgetCategory.CategoryColor
    @Binding var isPresented: Bool
    var onSave: ((SubcategoryItem) -> Void)?

    @State private var subcategoryName: String = ""
    @State private var selectedIcon: String = "📁"

    let availableIcons = [
        "☕", "🧋", "🥤", "🍿", "🎵", "🎳", "⛽", "🚊", "🚕",
        "💊", "🏃", "💇", "🍔", "🍕", "🍜", "🎮", "📱", "✈️"
    ]

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            // Header
            HStack {
                Text("Add Subcategory")
                    .font(.headline)
                    .foregroundColor(Theme.Colors.textPrimary)
                Spacer()
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Theme.Colors.textSecondary)
                        .font(.title3)
                }
            }
            .padding()

            // Name and emoji
            HStack(spacing: Theme.Spacing.sm) {
                Text(selectedIcon)
                    .font(.system(size: 32))
                    .frame(width: 60, height: 60)
                    .background(categoryColor.color.opacity(0.15))
                    .cornerRadius(Theme.CornerRadius.sm)

                TextField("Name", text: $subcategoryName)
                    .font(.body)
                    .padding()
                    .background(Theme.Colors.cardBackground)
                    .cornerRadius(Theme.CornerRadius.sm)
            }
            .padding(.horizontal)

            // Emoji selector
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.sm) {
                    ForEach(availableIcons, id: \.self) { icon in
                        Button {
                            selectedIcon = icon
                        } label: {
                            Text(icon)
                                .font(.title2)
                                .frame(width: 44, height: 44)
                                .background(
                                    selectedIcon == icon
                                    ? categoryColor.color.opacity(0.2)
                                    : Theme.Colors.cardBackground
                                )
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(
                                            selectedIcon == icon ? categoryColor.color : Color.clear,
                                            lineWidth: 2
                                        )
                                )
                        }
                    }
                }
                .padding(.horizontal)
            }

            // Add button
            Button {
                saveSubcategory()
            } label: {
                Text("Add")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(subcategoryName.isEmpty ? Color.gray.opacity(0.3) : categoryColor.color)
                    .foregroundColor(.white)
                    .cornerRadius(Theme.CornerRadius.md)
            }
            .disabled(subcategoryName.isEmpty)
            .padding(.horizontal)
            .padding(.bottom)
        }
        .background(Theme.Colors.background)
        .presentationDetents([.height(280)])
    }

    private func saveSubcategory() {
        guard !subcategoryName.isEmpty else { return }

        let newSubcategory = SubcategoryItem(
            name: subcategoryName,
            icon: selectedIcon
        )

        onSave?(newSubcategory)
        isPresented = false
    }
}

#Preview {
    AddCategoryView(isPresented: .constant(true))
}
