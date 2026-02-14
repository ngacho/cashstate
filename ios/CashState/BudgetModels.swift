import Foundation
import SwiftUI

// MARK: - Budget Category

struct BudgetCategory: Identifiable, Codable {
    let id: String
    let name: String
    let icon: String
    let color: CategoryColor
    let type: CategoryType
    var subcategories: [BudgetSubcategory]
    var budgetAmount: Double?
    var spentAmount: Double

    enum CategoryType: String, Codable, CaseIterable {
        case expense = "Expense"
        case income = "Income"
    }

    enum CategoryColor: String, Codable, CaseIterable {
        case blue, purple, pink, orange, yellow, green, teal, red

        var color: Color {
            switch self {
            case .blue: return Color.blue
            case .purple: return Color.purple
            case .pink: return Color.pink
            case .orange: return Color.orange
            case .yellow: return Color.yellow
            case .green: return Color.green
            case .teal: return Color.teal
            case .red: return Color.red
            }
        }
    }

    var percentageUsed: Double {
        guard let budget = budgetAmount, budget > 0 else { return 0 }
        return min((spentAmount / budget) * 100, 100)
    }

    var isOverBudget: Bool {
        guard let budget = budgetAmount else { return false }
        return spentAmount > budget
    }
}

// MARK: - Budget Subcategory

struct BudgetSubcategory: Identifiable, Codable {
    let id: String
    let name: String
    let icon: String
    var budgetAmount: Double?
    var spentAmount: Double
}

// MARK: - Budget

struct Budget: Identifiable, Codable {
    let id: String
    var name: String
    var amount: Double
    var type: BudgetType
    var period: BudgetPeriod
    var startDate: Date
    var color: BudgetCategory.CategoryColor
    var includedCategories: [String] // Category IDs
    var excludedCategories: [String] // Category IDs
    var transactionFilters: [TransactionFilter]
    var accountFilters: [AccountFilter]

    enum BudgetType: String, Codable, CaseIterable {
        case expense = "Expense budget"
        case savings = "Savings budget"
    }

    enum BudgetPeriod: String, Codable, CaseIterable {
        case month = "1 month"
        case threeMonths = "3 months"
        case sixMonths = "6 months"
        case year = "1 year"

        var months: Int {
            switch self {
            case .month: return 1
            case .threeMonths: return 3
            case .sixMonths: return 6
            case .year: return 12
            }
        }
    }

    enum TransactionFilter: String, Codable, CaseIterable {
        case `default` = "Default"
        case income = "Income"
        case expense = "Expense"
        case lentAndBorrow = "Lent and borrow"
    }

    enum AccountFilter: String, Codable, CaseIterable {
        case allAccounts = "All Accounts"
        case bank = "Bank"
        case creditCard = "Credit Card"
        case cash = "Cash"
    }

    var currentPeriodEnd: Date {
        Calendar.current.date(byAdding: .month, value: period.months, to: startDate) ?? startDate
    }

    var daysRemaining: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: currentPeriodEnd).day ?? 0
    }
}

// MARK: - Mock Data

extension BudgetCategory {
    static let mockCategories: [BudgetCategory] = [
        BudgetCategory(
            id: "1",
            name: "Entertainment",
            icon: "🍿",
            color: .blue,
            type: .expense,
            subcategories: [
                BudgetSubcategory(id: "1-1", name: "Movies", icon: "🍿", budgetAmount: 100.00, spentAmount: 45.00),
                BudgetSubcategory(id: "1-2", name: "Music", icon: "🎵", budgetAmount: 50.00, spentAmount: 9.99),
                BudgetSubcategory(id: "1-3", name: "Activities", icon: "🎳", budgetAmount: 200.00, spentAmount: 120.00)
            ],
            budgetAmount: 500.00,
            spentAmount: 174.99
        ),
        BudgetCategory(
            id: "2",
            name: "Food",
            icon: "🍔",
            color: .orange,
            type: .expense,
            subcategories: [
                BudgetSubcategory(id: "2-1", name: "Groceries", icon: "🛒", budgetAmount: 500.00, spentAmount: 450.00),
                BudgetSubcategory(id: "2-2", name: "Dining Out", icon: "🍽️", budgetAmount: 200.00, spentAmount: 230.00),
                BudgetSubcategory(id: "2-3", name: "Coffee", icon: "☕", budgetAmount: 100.00, spentAmount: 85.00)
            ],
            budgetAmount: 800.00,
            spentAmount: 765.00
        ),
        BudgetCategory(
            id: "3",
            name: "Transport",
            icon: "🚗",
            color: .teal,
            type: .expense,
            subcategories: [
                BudgetSubcategory(id: "3-1", name: "Gas", icon: "⛽", spentAmount: 180.00),
                BudgetSubcategory(id: "3-2", name: "Public Transit", icon: "🚊", spentAmount: 45.00),
                BudgetSubcategory(id: "3-3", name: "Rideshare", icon: "🚕", spentAmount: 60.00)
            ],
            budgetAmount: 400.00,
            spentAmount: 285.00
        ),
        BudgetCategory(
            id: "4",
            name: "Home & Utilities",
            icon: "🏠",
            color: .purple,
            type: .expense,
            subcategories: [
                BudgetSubcategory(id: "4-1", name: "Rent", icon: "🏘️", budgetAmount: 1500.00, spentAmount: 1500.00),
                BudgetSubcategory(id: "4-2", name: "Electricity", icon: "💡", budgetAmount: 150.00, spentAmount: 85.00),
                BudgetSubcategory(id: "4-3", name: "Internet", icon: "📡", spentAmount: 60.00)
            ],
            budgetAmount: 1800.00,
            spentAmount: 1645.00
        ),
        BudgetCategory(
            id: "5",
            name: "Personal & Medical",
            icon: "❤️",
            color: .pink,
            type: .expense,
            subcategories: [
                BudgetSubcategory(id: "5-1", name: "Healthcare", icon: "💊", spentAmount: 120.00),
                BudgetSubcategory(id: "5-2", name: "Fitness", icon: "🏃", spentAmount: 50.00),
                BudgetSubcategory(id: "5-3", name: "Personal Care", icon: "💇", spentAmount: 75.00)
            ],
            budgetAmount: 300.00,
            spentAmount: 245.00
        ),
        BudgetCategory(
            id: "6",
            name: "Shopping",
            icon: "🛍️",
            color: .yellow,
            type: .expense,
            subcategories: [
                BudgetSubcategory(id: "6-1", name: "Clothing", icon: "👕", spentAmount: 200.00),
                BudgetSubcategory(id: "6-2", name: "Electronics", icon: "📱", spentAmount: 0.00),
                BudgetSubcategory(id: "6-3", name: "Other", icon: "🎁", spentAmount: 50.00)
            ],
            budgetAmount: 400.00,
            spentAmount: 250.00
        )
    ]
}

extension Budget {
    static let mockBudgets: [Budget] = [
        Budget(
            id: "1",
            name: "Monthly Budget",
            amount: 4200.00,
            type: .expense,
            period: .month,
            startDate: Calendar.current.date(from: DateComponents(year: 2025, month: 2, day: 1))!,
            color: .blue,
            includedCategories: ["1", "2", "3", "4", "5", "6"],
            excludedCategories: [],
            transactionFilters: [.default, .expense],
            accountFilters: [.allAccounts]
        ),
        Budget(
            id: "2",
            name: "Savings Goal",
            amount: 1000.00,
            type: .savings,
            period: .month,
            startDate: Calendar.current.date(from: DateComponents(year: 2025, month: 2, day: 1))!,
            color: .green,
            includedCategories: [],
            excludedCategories: [],
            transactionFilters: [.income],
            accountFilters: [.bank]
        )
    ]
}
