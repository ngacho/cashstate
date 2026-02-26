import SwiftUI

struct AddSubcategoryView: View {
    let parentCategory: BudgetCategory
    @Binding var isPresented: Bool
    var onSave: ((BudgetSubcategory) -> Void)?

    @State private var subcategoryName: String = ""
    @State private var selectedIcon: String = "📁"
    @State private var budgetAmount: String = ""
    @State private var hasBudget: Bool = false

    let availableIcons = [
        // Food related
        "🍔", "🍕", "🍜", "🍱", "🍣", "🍝", "🍗", "🥗",
        "☕", "🥤", "🧋", "🍺", "🍷", "🥂", "🍰", "🍪",
        // Shopping
        "🛒", "🛍️", "👕", "👗", "👟", "💄", "📱", "💻",
        // Transport
        "⛽", "🚗", "🚌", "🚊", "🚕", "✈️", "🚲", "🛴",
        // Home
        "🏘️", "💡", "📡", "🔌", "🚿", "🛋️", "🛏️", "🧹",
        // Entertainment
        "🍿", "🎬", "🎮", "🎵", "🎸", "🎨", "🎭", "📚",
        // Health
        "💊", "🏥", "💉", "🏃", "⛹️", "🧘", "💇", "💅",
        // Finance
        "💰", "💳", "💸", "📈", "📊", "🏦", "💼", "📝",
        // General
        "📁", "⭐", "❤️", "🎯", "✅", "📌", "🔔", "⚡"
    ]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    // Parent category indicator
                    HStack(spacing: Theme.Spacing.sm) {
                        Text(parentCategory.icon)
                            .font(.title2)
                            .frame(width: 50, height: 50)
                            .background(parentCategory.color.opacity(0.15))
                            .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Adding to")
                                .font(.caption)
                                .foregroundColor(Theme.Colors.textSecondary)
                            Text(parentCategory.name)
                                .font(.headline)
                                .foregroundColor(Theme.Colors.textPrimary)
                        }

                        Spacer()
                    }
                    .padding()
                    .background(Theme.Colors.cardBackground)
                    .cornerRadius(Theme.CornerRadius.md)
                    .padding(.horizontal)

                    // Icon preview and name
                    HStack(spacing: Theme.Spacing.md) {
                        // Icon preview
                        Text(selectedIcon)
                            .font(.system(size: 48))
                            .frame(width: 100, height: 100)
                            .background(parentCategory.color.opacity(0.2))
                            .cornerRadius(Theme.CornerRadius.lg)

                        // Name input
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            Text("Subcategory Name")
                                .font(.caption)
                                .foregroundColor(Theme.Colors.textSecondary)

                            TextField("e.g., Coffee", text: $subcategoryName)
                                .font(.title3)
                                .fontWeight(.medium)
                                .foregroundColor(Theme.Colors.textPrimary)
                                .padding()
                                .background(Theme.Colors.cardBackground)
                                .cornerRadius(Theme.CornerRadius.md)
                        }
                    }
                    .padding(.horizontal)

                    // Budget toggle and input
                    VStack(spacing: Theme.Spacing.sm) {
                        Toggle(isOn: $hasBudget) {
                            HStack {
                                Image(systemName: "dollarsign.circle")
                                    .foregroundColor(parentCategory.color)
                                Text("Set Budget")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                        }
                        .tint(parentCategory.color)

                        if hasBudget {
                            HStack {
                                Text("$")
                                    .font(.title3)
                                    .foregroundColor(Theme.Colors.textSecondary)
                                TextField("0.00", text: $budgetAmount)
                                    .font(.title3)
                                    .fontWeight(.medium)
                                    .keyboardType(.decimalPad)
                                    .foregroundColor(Theme.Colors.textPrimary)
                                Text("/ month")
                                    .font(.subheadline)
                                    .foregroundColor(Theme.Colors.textSecondary)
                            }
                            .padding()
                            .background(Theme.Colors.cardBackground)
                            .cornerRadius(Theme.CornerRadius.md)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .padding()
                    .background(Theme.Colors.cardBackground.opacity(0.5))
                    .cornerRadius(Theme.CornerRadius.md)
                    .padding(.horizontal)

                    // Icon selection
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
                                    withAnimation(.spring(response: 0.3)) {
                                        selectedIcon = icon
                                    }
                                } label: {
                                    Text(icon)
                                        .font(.title2)
                                        .frame(width: 50, height: 50)
                                        .background(
                                            selectedIcon == icon
                                            ? parentCategory.color.opacity(0.2)
                                            : Theme.Colors.cardBackground.opacity(0.5)
                                        )
                                        .cornerRadius(Theme.CornerRadius.sm)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                                                .stroke(
                                                    selectedIcon == icon ? parentCategory.color : Color.clear,
                                                    lineWidth: 2
                                                )
                                        )
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Save button
                    Button {
                        saveSubcategory()
                    } label: {
                        HStack {
                            Image(systemName: "checkmark")
                                .font(.subheadline)
                            Text("Add Subcategory")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.md)
                        .background(
                            subcategoryName.isEmpty
                            ? Color.gray.opacity(0.3)
                            : parentCategory.color
                        )
                        .cornerRadius(Theme.CornerRadius.md)
                    }
                    .disabled(subcategoryName.isEmpty)
                    .padding(.horizontal)
                    .padding(.top, Theme.Spacing.md)

                    Spacer(minLength: Theme.Spacing.xl)
                }
                .padding(.vertical)
            }
            .background(Theme.Colors.background)
            .navigationTitle("New Subcategory")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                Analytics.shared.screen(.addSubcategory)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
    }

    private func saveSubcategory() {
        guard !subcategoryName.isEmpty else { return }

        let budget = hasBudget && !budgetAmount.isEmpty ? Double(budgetAmount) : nil

        let newSubcategory = BudgetSubcategory(
            id: UUID().uuidString,
            name: subcategoryName,
            icon: selectedIcon,
            budgetAmount: budget,
            spentAmount: 0.0,
            transactionCount: 0
        )

        Analytics.shared.track(.subcategoryCreated, properties: [
            "subcategory_name": subcategoryName,
            "parent_category": parentCategory.name
        ])
        onSave?(newSubcategory)
        isPresented = false
    }
}

#Preview {
    AddSubcategoryView(
        parentCategory: BudgetCategory.mockCategories[1], // Food
        isPresented: .constant(true)
    ) { newSub in
        print("New subcategory: \(newSub.name)")
    }
}
