import SwiftUI

struct GoalsView: View {
    let apiClient: APIClient
    @State private var goals: [Goal] = []
    @State private var isLoading = false
    @State private var error: String?
    @State private var hasLoaded = false

    var body: some View {
        NavigationView {
            Group {
                if !hasLoaded {
                    // Haven't gotten a response yet — stay in loading state
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Theme.Colors.background)
                } else if let errorMessage = error, goals.isEmpty {
                    // Got a response but it was an error and we have no cached goals
                    fetchErrorState(message: errorMessage)
                } else if goals.isEmpty {
                    // Successfully loaded — server says there are no goals
                    emptyState
                } else {
                    goalsList
                }
            }
            .navigationTitle("Goals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: CreateGoalView(apiClient: apiClient, onCreated: { newGoal in
                        goals.insert(newGoal, at: 0)
                    })) {
                        Image(systemName: "plus")
                            .foregroundColor(Theme.Colors.primary)
                    }
                }
            }
            .refreshable {
                await loadGoals()
            }
            .task {
                await loadGoals()
            }
            .alert("Error", isPresented: Binding(
                get: { error != nil && !goals.isEmpty },
                set: { if !$0 { error = nil } }
            )) {
                Button("OK") { error = nil }
            } message: {
                Text(error ?? "")
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: "target")
                .font(.system(size: 64))
                .foregroundColor(Theme.Colors.primary.opacity(0.5))

            VStack(spacing: Theme.Spacing.sm) {
                Text("No goals yet")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.Colors.textPrimary)

                Text("Set savings targets or debt payoff goals\nand track progress with your accounts.")
                    .font(.subheadline)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            NavigationLink(destination: CreateGoalView(apiClient: apiClient, onCreated: { newGoal in
                goals.insert(newGoal, at: 0)
            })) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Create your first goal")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(Theme.Spacing.md)
                .background(Theme.Colors.primary)
                .foregroundColor(.white)
                .cornerRadius(Theme.CornerRadius.md)
            }
            .padding(.horizontal, Theme.Spacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Colors.background)
    }

    private var goalsList: some View {
        ScrollView {
            LazyVStack(spacing: Theme.Spacing.sm) {
                ForEach(goals) { goal in
                    NavigationLink(destination: GoalDetailView(apiClient: apiClient, goalId: goal.id)) {
                        GoalCard(goal: goal)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            Task { await deleteGoal(goal) }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .padding(Theme.Spacing.md)
        }
        .background(Theme.Colors.background)
    }

    private var fetchErrorState: some View {
        fetchErrorState(message: error ?? "Unable to load goals")
    }

    private func fetchErrorState(message: String) -> some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 64))
                .foregroundColor(Theme.Colors.expense.opacity(0.6))

            VStack(spacing: Theme.Spacing.sm) {
                Text("Couldn't load goals")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.Colors.textPrimary)

                Text(message)
                    .font(.subheadline)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                Task { await loadGoals() }
            } label: {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Try Again")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(Theme.Spacing.md)
                .background(Theme.Colors.primary)
                .foregroundColor(.white)
                .cornerRadius(Theme.CornerRadius.md)
            }
            .padding(.horizontal, Theme.Spacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Colors.background)
    }

    private func loadGoals() async {
        isLoading = true
        defer {
            isLoading = false
            hasLoaded = true
        }
        do {
            goals = try await apiClient.fetchGoals()
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func deleteGoal(_ goal: Goal) async {
        do {
            try await apiClient.deleteGoal(goalId: goal.id)
            goals.removeAll { $0.id == goal.id }
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// MARK: - Goal Card

struct GoalCard: View {
    let goal: Goal

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            // Header row
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(goal.name)
                        .font(.headline)
                        .foregroundColor(Theme.Colors.textPrimary)
                        .lineLimit(1)
                    if let description = goal.description, !description.isEmpty {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(Theme.Colors.textSecondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                GoalTypeBadge(goalType: goal.goalType)
            }

            // Progress bar
            VStack(alignment: .leading, spacing: 4) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.15))
                            .frame(height: 8)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(progressColor)
                            .frame(width: geo.size.width * CGFloat(min(goal.progressPercent, 100) / 100), height: 8)
                            .animation(.easeInOut(duration: 0.3), value: goal.progressPercent)
                    }
                }
                .frame(height: 8)

                HStack {
                    if goal.goalType == .debtPayment {
                        // Show "Paid off $X of $Y"
                        Text(String(format: "Paid off $%.2f", max(0, goal.currentAmount)))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(Theme.Colors.textPrimary)
                        Text("of \(String(format: "$%.2f", goal.targetAmount))")
                            .font(.subheadline)
                            .foregroundColor(Theme.Colors.textSecondary)
                    } else {
                        Text(String(format: "$%.2f", goal.currentAmount))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(Theme.Colors.textPrimary)
                        Text("of \(String(format: "$%.2f", goal.targetAmount))")
                            .font(.subheadline)
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                    Spacer()
                    Text(String(format: "%.0f%%", goal.progressPercent))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(progressColor)
                }
            }

            // Target date if set
            if let targetDate = goal.targetDate, !targetDate.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                    Text("Target: \(targetDate)")
                        .font(.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                    if goal.isCompleted {
                        Spacer()
                        Text("Completed")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(Theme.Colors.income)
                    }
                }
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.cardBackground)
        .cornerRadius(Theme.CornerRadius.md)
        .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
    }

    private var progressColor: Color {
        if goal.isCompleted { return Theme.Colors.income }
        if goal.progressPercent >= 75 { return Theme.Colors.income }
        if goal.progressPercent >= 40 { return Theme.Colors.primary }
        return Theme.Colors.expense
    }
}

// MARK: - Goal Type Badge

struct GoalTypeBadge: View {
    let goalType: GoalType

    var body: some View {
        Text(goalType.displayName)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(backgroundColor)
            .foregroundColor(foregroundColor)
            .cornerRadius(6)
    }

    private var backgroundColor: Color {
        goalType == .savings ? Theme.Colors.income.opacity(0.15) : Theme.Colors.expense.opacity(0.15)
    }

    private var foregroundColor: Color {
        goalType == .savings ? Theme.Colors.income : Theme.Colors.expense
    }
}
