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
    var transactionCount: Int
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
                BudgetSubcategory(id: "1-1", name: "Movies", icon: "🍿", budgetAmount: 100.00, spentAmount: 45.00, transactionCount: 3),
                BudgetSubcategory(id: "1-2", name: "Music", icon: "🎵", budgetAmount: 50.00, spentAmount: 9.99, transactionCount: 1),
                BudgetSubcategory(id: "1-3", name: "Activities", icon: "🎳", budgetAmount: 200.00, spentAmount: 120.00, transactionCount: 5)
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
                BudgetSubcategory(id: "2-1", name: "Groceries", icon: "🛒", budgetAmount: 500.00, spentAmount: 450.00, transactionCount: 28),
                BudgetSubcategory(id: "2-2", name: "Dining Out", icon: "🍽️", budgetAmount: 200.00, spentAmount: 230.00, transactionCount: 12),
                BudgetSubcategory(id: "2-3", name: "Coffee", icon: "☕", budgetAmount: 100.00, spentAmount: 85.00, transactionCount: 18)
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
                BudgetSubcategory(id: "3-1", name: "Gas", icon: "⛽", spentAmount: 180.00, transactionCount: 8),
                BudgetSubcategory(id: "3-2", name: "Public Transit", icon: "🚊", spentAmount: 45.00, transactionCount: 22),
                BudgetSubcategory(id: "3-3", name: "Rideshare", icon: "🚕", spentAmount: 60.00, transactionCount: 4)
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
                BudgetSubcategory(id: "4-1", name: "Rent", icon: "🏘️", budgetAmount: 1500.00, spentAmount: 1500.00, transactionCount: 1),
                BudgetSubcategory(id: "4-2", name: "Electricity", icon: "💡", budgetAmount: 150.00, spentAmount: 85.00, transactionCount: 1),
                BudgetSubcategory(id: "4-3", name: "Internet", icon: "📡", spentAmount: 60.00, transactionCount: 1)
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
                BudgetSubcategory(id: "5-1", name: "Healthcare", icon: "💊", spentAmount: 120.00, transactionCount: 2),
                BudgetSubcategory(id: "5-2", name: "Fitness", icon: "🏃", spentAmount: 50.00, transactionCount: 1),
                BudgetSubcategory(id: "5-3", name: "Personal Care", icon: "💇", spentAmount: 75.00, transactionCount: 3)
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
                BudgetSubcategory(id: "6-1", name: "Clothing", icon: "👕", spentAmount: 200.00, transactionCount: 5),
                BudgetSubcategory(id: "6-2", name: "Electronics", icon: "📱", spentAmount: 0.00, transactionCount: 0),
                BudgetSubcategory(id: "6-3", name: "Other", icon: "🎁", spentAmount: 50.00, transactionCount: 2)
            ],
            budgetAmount: 400.00,
            spentAmount: 250.00
        )
    ]
}

// MARK: - Category Transaction

struct CategoryTransaction: Identifiable {
    let id: String
    let categoryId: String
    let subcategoryId: String?
    let merchantName: String
    let amount: Double
    let date: Date
    let description: String
    let pending: Bool
}

extension CategoryTransaction {
    static let mockTransactions: [CategoryTransaction] = [
        // Entertainment - Movies
        CategoryTransaction(id: "t1", categoryId: "1", subcategoryId: "1-1", merchantName: "AMC Theatres", amount: 25.00, date: Date().addingTimeInterval(-86400 * 2), description: "Movie tickets", pending: false),
        CategoryTransaction(id: "t2", categoryId: "1", subcategoryId: "1-1", merchantName: "Regal Cinemas", amount: 15.00, date: Date().addingTimeInterval(-86400 * 5), description: "Matinee showing", pending: false),
        CategoryTransaction(id: "t3", categoryId: "1", subcategoryId: "1-1", merchantName: "Movie Theater", amount: 5.00, date: Date().addingTimeInterval(-86400 * 10), description: "Concessions", pending: false),

        // Entertainment - Music
        CategoryTransaction(id: "t4", categoryId: "1", subcategoryId: "1-2", merchantName: "Spotify", amount: 9.99, date: Date().addingTimeInterval(-86400 * 1), description: "Premium subscription", pending: false),

        // Entertainment - Activities
        CategoryTransaction(id: "t5", categoryId: "1", subcategoryId: "1-3", merchantName: "Bowling Alley", amount: 45.00, date: Date().addingTimeInterval(-86400 * 3), description: "Friday night bowling", pending: false),
        CategoryTransaction(id: "t6", categoryId: "1", subcategoryId: "1-3", merchantName: "Mini Golf", amount: 30.00, date: Date().addingTimeInterval(-86400 * 7), description: "Weekend activity", pending: false),
        CategoryTransaction(id: "t7", categoryId: "1", subcategoryId: "1-3", merchantName: "Escape Room", amount: 45.00, date: Date().addingTimeInterval(-86400 * 14), description: "Group activity", pending: false),

        // Food - Groceries (showing first 5 of 28)
        CategoryTransaction(id: "t8", categoryId: "2", subcategoryId: "2-1", merchantName: "Whole Foods", amount: 85.50, date: Date().addingTimeInterval(-86400 * 1), description: "Weekly groceries", pending: false),
        CategoryTransaction(id: "t9", categoryId: "2", subcategoryId: "2-1", merchantName: "Trader Joe's", amount: 42.30, date: Date().addingTimeInterval(-86400 * 3), description: "Specialty items", pending: false),
        CategoryTransaction(id: "t10", categoryId: "2", subcategoryId: "2-1", merchantName: "Safeway", amount: 123.45, date: Date().addingTimeInterval(-86400 * 5), description: "Bulk shopping", pending: false),
        CategoryTransaction(id: "t11", categoryId: "2", subcategoryId: "2-1", merchantName: "Farmers Market", amount: 28.75, date: Date().addingTimeInterval(-86400 * 6), description: "Fresh produce", pending: false),
        CategoryTransaction(id: "t12", categoryId: "2", subcategoryId: "2-1", merchantName: "Costco", amount: 170.00, date: Date().addingTimeInterval(-86400 * 8), description: "Monthly stock-up", pending: false),

        // Food - Dining Out (showing first 5 of 12)
        CategoryTransaction(id: "t13", categoryId: "2", subcategoryId: "2-2", merchantName: "Thai Restaurant", amount: 45.60, date: Date().addingTimeInterval(-86400 * 1), description: "Dinner", pending: false),
        CategoryTransaction(id: "t14", categoryId: "2", subcategoryId: "2-2", merchantName: "Pizza Place", amount: 32.00, date: Date().addingTimeInterval(-86400 * 2), description: "Takeout", pending: true),
        CategoryTransaction(id: "t15", categoryId: "2", subcategoryId: "2-2", merchantName: "Sushi Bar", amount: 67.50, date: Date().addingTimeInterval(-86400 * 4), description: "Date night", pending: false),
        CategoryTransaction(id: "t16", categoryId: "2", subcategoryId: "2-2", merchantName: "Mexican Grill", amount: 28.90, date: Date().addingTimeInterval(-86400 * 6), description: "Quick lunch", pending: false),
        CategoryTransaction(id: "t17", categoryId: "2", subcategoryId: "2-2", merchantName: "Italian Bistro", amount: 56.00, date: Date().addingTimeInterval(-86400 * 8), description: "Weekend brunch", pending: false),

        // Food - Coffee (showing first 5 of 18)
        CategoryTransaction(id: "t18", categoryId: "2", subcategoryId: "2-3", merchantName: "Starbucks", amount: 6.75, date: Date().addingTimeInterval(-86400 * 1), description: "Morning coffee", pending: false),
        CategoryTransaction(id: "t19", categoryId: "2", subcategoryId: "2-3", merchantName: "Local Cafe", amount: 4.50, date: Date().addingTimeInterval(-86400 * 2), description: "Americano", pending: false),
        CategoryTransaction(id: "t20", categoryId: "2", subcategoryId: "2-3", merchantName: "Starbucks", amount: 8.25, date: Date().addingTimeInterval(-86400 * 3), description: "Latte + pastry", pending: false),
        CategoryTransaction(id: "t21", categoryId: "2", subcategoryId: "2-3", merchantName: "Peet's Coffee", amount: 5.50, date: Date().addingTimeInterval(-86400 * 5), description: "Cold brew", pending: false),
        CategoryTransaction(id: "t22", categoryId: "2", subcategoryId: "2-3", merchantName: "Coffee Shop", amount: 7.00, date: Date().addingTimeInterval(-86400 * 6), description: "Cappuccino", pending: false),
    ]

    static func transactions(for categoryId: String, subcategoryId: String? = nil) -> [CategoryTransaction] {
        mockTransactions.filter { transaction in
            if let subId = subcategoryId {
                return transaction.categoryId == categoryId && transaction.subcategoryId == subId
            } else {
                return transaction.categoryId == categoryId
            }
        }
    }
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
