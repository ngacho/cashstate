import SwiftUI

struct BudgetEmptyStateView: View {
    let apiClient: APIClient
    @Binding var isLoading: Bool
    @Binding var error: String?
    var onCategoriesAdded: () -> Void

    @State private var showAddCategory = false
    @State private var monthlyBudget: String = ""
    @State private var showBudgetInput = false
    @State private var seedResult: SeedDefaultsResponse?

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Icon
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            // Title
            Text("No Categories Yet")
                .font(.title2)
                .fontWeight(.bold)

            // Description
            Text("Get started by adding categories to track your spending")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            // Action Buttons
            VStack(spacing: 12) {
                // Use Defaults Button
                Button(action: { showBudgetInput = true }) {
                    HStack {
                        Image(systemName: "sparkles")
                        Text("Use Default Categories")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(isLoading)

                // Create Custom Button
                Button(action: { showAddCategory = true }) {
                    HStack {
                        Image(systemName: "plus.circle")
                        Text("Create Custom Category")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(12)
                }
                .disabled(isLoading)
            }
            .padding(.horizontal, 32)
            .padding(.top, 8)

            if isLoading {
                ProgressView("Setting up categories...")
                    .padding(.top)
            }

            if let error = error {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding()
            }

            Spacer()
        }
        .sheet(isPresented: $showAddCategory) {
            AddCategoryView(isPresented: $showAddCategory) { _ in
                onCategoriesAdded()
            }
        }
        .sheet(isPresented: $showBudgetInput) {
            BudgetInputSheet(
                monthlyBudget: $monthlyBudget,
                isPresented: $showBudgetInput,
                onSubmit: { budget in
                    seedDefaults(monthlyBudget: budget)
                }
            )
        }
        .alert("Setup Complete!", isPresented: .constant(seedResult != nil)) {
            Button("OK") {
                seedResult = nil
                onCategoriesAdded()
            }
        } message: {
            if let result = seedResult {
                Text("""
                Created \(result.categoriesCreated) categories and \(result.subcategoriesCreated) subcategories!

                Your $\(String(format: "%.2f", result.monthlyBudget)) monthly budget has been split into $\(String(format: "%.2f", result.budgetPerCategory)) per category.

                You can adjust these budgets anytime.
                """)
            }
        }
    }

    private func seedDefaults(monthlyBudget: Double) {
        isLoading = true
        error = nil

        Task {
            do {
                let result = try await apiClient.seedDefaultCategories(monthlyBudget: monthlyBudget)
                await MainActor.run {
                    isLoading = false
                    seedResult = result
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}

// MARK: - Budget Input Sheet

struct BudgetInputSheet: View {
    @Binding var monthlyBudget: String
    @Binding var isPresented: Bool
    var onSubmit: (Double) -> Void

    @FocusState private var isInputFocused: Bool

    var budgetValue: Double? {
        Double(monthlyBudget)
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Spacer()

                // Icon
                Image(systemName: "dollarsign.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)

                // Title
                Text("Set Your Monthly Budget")
                    .font(.title2)
                    .fontWeight(.bold)

                // Description
                Text("We'll distribute this evenly across your expense categories. You can adjust individual budgets later.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                // Budget Input
                VStack(spacing: 8) {
                    HStack {
                        Text("$")
                            .font(.largeTitle)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        TextField("3000", text: $monthlyBudget)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .keyboardType(.decimalPad)
                            .focused($isInputFocused)
                            .multilineTextAlignment(.leading)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal, 32)

                    Text("Typical monthly budgets range from $1,500-$5,000")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Submit Button
                Button(action: {
                    if let budget = budgetValue, budget > 0 {
                        isPresented = false
                        onSubmit(budget)
                    }
                }) {
                    Text("Continue")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(budgetValue != nil && budgetValue! > 0 ? Color.blue : Color.gray.opacity(0.3))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .disabled(budgetValue == nil || budgetValue! <= 0)
                .padding(.horizontal, 32)
                .padding(.top, 8)

                Spacer()
            }
            .navigationTitle("Monthly Budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
            .onAppear {
                isInputFocused = true
            }
        }
    }
}
