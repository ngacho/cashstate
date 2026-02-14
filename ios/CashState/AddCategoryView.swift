import SwiftUI

struct AddCategoryView: View {
    @Binding var isPresented: Bool

    @State private var categoryName: String = ""
    @State private var selectedType: BudgetCategory.CategoryType = .expense
    @State private var selectedIcon: String = "🎨"
    @State private var selectedColor: BudgetCategory.CategoryColor = .blue
    @State private var isMainCategory: Bool = true
    @State private var selectedSubcategories: [String] = []
    @State private var showSubcategoryInfo = false

    // Predefined subcategory suggestions
    let subcategorySuggestions: [String: [SubcategorySuggestion]] = [
        "Drinks": [
            SubcategorySuggestion(name: "Coffee", icon: "☕"),
            SubcategorySuggestion(name: "Bubble Tea", icon: "🧋"),
            SubcategorySuggestion(name: "Soda", icon: "🥤")
        ],
        "Entertainment": [
            SubcategorySuggestion(name: "Movies", icon: "🍿"),
            SubcategorySuggestion(name: "Music", icon: "🎵"),
            SubcategorySuggestion(name: "Activities", icon: "🎳")
        ],
        "Transport": [
            SubcategorySuggestion(name: "Gas", icon: "⛽"),
            SubcategorySuggestion(name: "Public Transit", icon: "🚊"),
            SubcategorySuggestion(name: "Rideshare", icon: "🚕")
        ],
        "Personal & Medical": [
            SubcategorySuggestion(name: "Healthcare", icon: "💊"),
            SubcategorySuggestion(name: "Fitness", icon: "🏃"),
            SubcategorySuggestion(name: "Personal Care", icon: "💇")
        ]
    ]

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
                            Image(systemName: "arrow.down.to.line.compact")
                                .foregroundColor(Theme.Colors.textSecondary)
                            Text("Subcategory")
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

                        // Example subcategories
                        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                            Text("Examples")
                                .font(.headline)
                                .foregroundColor(Theme.Colors.textPrimary)
                                .padding(.horizontal)

                            ForEach(Array(subcategorySuggestions.keys.sorted()), id: \.self) { categoryName in
                                SubcategoryExampleCard(
                                    categoryName: categoryName,
                                    suggestions: subcategorySuggestions[categoryName] ?? []
                                )
                            }
                        }
                        .padding()
                        .background(Theme.Colors.cardBackground.opacity(0.5))
                        .cornerRadius(Theme.CornerRadius.md)
                        .padding(.horizontal)
                    }

                    // Set Name Button
                    Button {
                        saveCategory()
                    } label: {
                        Text("Set Name")
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
        // Save category logic here
        print("Saving category: \(categoryName)")
        isPresented = false
    }
}

// MARK: - Subcategory Suggestion

struct SubcategorySuggestion: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
}

// MARK: - Subcategory Example Card

struct SubcategoryExampleCard: View {
    let categoryName: String
    let suggestions: [SubcategorySuggestion]

    var categoryIcon: String {
        switch categoryName {
        case "Drinks": return "☕"
        case "Entertainment": return "🎭"
        case "Transport": return "🚊"
        case "Personal & Medical": return "❤️"
        default: return "📁"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            // Category header
            HStack(spacing: Theme.Spacing.sm) {
                Text(categoryIcon)
                    .font(.title3)
                Text(categoryName)
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.Colors.textPrimary)
            }
            .padding(.horizontal)

            // Subcategory grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: Theme.Spacing.sm) {
                ForEach(suggestions) { suggestion in
                    VStack(spacing: 4) {
                        Text(suggestion.icon)
                            .font(.title3)
                            .frame(width: 50, height: 50)
                            .background(Theme.Colors.cardBackground)
                            .cornerRadius(Theme.CornerRadius.sm)

                        Text(suggestion.name)
                            .font(.caption2)
                            .foregroundColor(Theme.Colors.textPrimary)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .frame(height: 30)
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, Theme.Spacing.sm)
        .background(Theme.Colors.cardBackground)
        .cornerRadius(Theme.CornerRadius.md)
    }
}

#Preview {
    AddCategoryView(isPresented: .constant(true))
}
