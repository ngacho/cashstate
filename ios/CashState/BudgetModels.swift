import Foundation
import SwiftUI

// MARK: - Budget API Models (Convex budgets table)
// Convex returns camelCase JSON — CodingKeys updated from snake_case

struct BudgetAPI: Identifiable, Codable {
    let id: String
    let userId: String
    let name: String
    let isDefault: Bool
    let emoji: String?
    let color: String?
    let accountIds: [String]

    var createdAt: String { "" } // not returned, kept for compat

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case userId
        case name
        case isDefault
        case emoji
        case color
        case accountIds
    }
}

struct BudgetMonth: Identifiable, Codable {
    let id: String
    let budgetId: String
    let userId: String
    let month: String // "YYYY-MM"

    var createdAt: String { "" }

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case budgetId
        case userId
        case month
    }
}

struct BudgetMonthAPIListResponse: Codable {
    let items: [BudgetMonth]
    let total: Int
}

struct BudgetAPIListResponse: Codable {
    let items: [BudgetAPI]
    let total: Int
}

extension BudgetAPI: Hashable {
    static func == (lhs: BudgetAPI, rhs: BudgetAPI) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct BudgetLineItem: Identifiable, Codable {
    let id: String
    let budgetId: String
    let categoryId: String
    let subcategoryId: String?
    let amount: Double

    var createdAt: String { "" }
    var updatedAt: String { "" }

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case budgetId
        case categoryId
        case subcategoryId
        case amount
    }
}

extension BudgetLineItem: Hashable {
    static func == (lhs: BudgetLineItem, rhs: BudgetLineItem) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct BudgetLineItemListResponse: Codable {
    let items: [BudgetLineItem]
    let total: Int
}

struct BudgetSummaryLineItem: Identifiable, Codable {
    let id: String
    let budgetId: String
    let categoryId: String
    let subcategoryId: String?
    let amount: Double
    let spent: Double
    let remaining: Double
}

struct UnbudgetedCategory: Codable {
    let categoryId: String
    let spent: Double
}

struct BudgetSummary: Codable {
    let budgetId: String?
    let budgetName: String?
    let month: String
    let totalBudgeted: Double
    let totalSpent: Double
    let lineItems: [BudgetSummaryLineItem]
    let unbudgetedCategories: [UnbudgetedCategory]
    let subcategorySpending: [String: Double]?
    let uncategorizedSpending: Double?
    let accountIds: [String]?
    let hasPreviousMonth: Bool?
    let hasNextMonth: Bool?
}

// MARK: - Budget Category (local UI model, not from API)

struct BudgetCategory: Identifiable, Codable, Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: BudgetCategory, rhs: BudgetCategory) -> Bool {
        lhs.id == rhs.id
    }
    let id: String
    var name: String
    var icon: String
    var colorHex: String
    let type: CategoryType
    var subcategories: [BudgetSubcategory]
    var budgetAmount: Double?
    var spentAmount: Double

    var lineItemId: String?
    var budgetId: String?

    enum CategoryType: String, Codable, CaseIterable {
        case expense = "Expense"
        case income = "Income"
    }

    var color: Color {
        Color(hex: colorHex)
    }

    var percentageUsed: Double {
        guard let budget = budgetAmount, budget > 0 else { return 0 }
        return min((spentAmount / budget) * 100, 100)
    }

    var isOverBudget: Bool {
        guard let budget = budgetAmount else { return false }
        return spentAmount > budget
    }

    enum CodingKeys: String, CodingKey {
        case id, name, icon, type, subcategories, budgetAmount, spentAmount
        case colorHex = "color"
    }
}

// MARK: - Color Palette

enum ColorPalette: String, CaseIterable, Identifiable {
    case blue = "#3B82F6"
    case purple = "#8B5CF6"
    case pink = "#EC4899"
    case red = "#EF4444"
    case orange = "#F59E0B"
    case yellow = "#FBBF24"
    case green = "#10B981"
    case teal = "#06B6D4"
    case indigo = "#6366F1"
    case cyan = "#14B8A6"

    var id: String { rawValue }

    var color: Color {
        Color(hex: rawValue)
    }

    var name: String {
        switch self {
        case .blue: return "Blue"
        case .purple: return "Purple"
        case .pink: return "Pink"
        case .red: return "Red"
        case .orange: return "Orange"
        case .yellow: return "Yellow"
        case .green: return "Green"
        case .teal: return "Teal"
        case .indigo: return "Indigo"
        case .cyan: return "Cyan"
        }
    }
}

// MARK: - Budget Subcategory

struct BudgetSubcategory: Identifiable, Codable, Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: BudgetSubcategory, rhs: BudgetSubcategory) -> Bool {
        lhs.id == rhs.id
    }
    let id: String
    let name: String
    let icon: String
    var budgetAmount: Double?
    var spentAmount: Double
    var transactionCount: Int

    var lineItemId: String?
    var budgetId: String?
}

// MARK: - Budget (local UI model)

struct Budget: Identifiable, Codable {
    let id: String
    var name: String
    var amount: Double
    var type: BudgetType
    var period: BudgetPeriod
    var startDate: Date
    var colorHex: String
    var includedCategories: [String]
    var excludedCategories: [String]
    var transactionFilters: [TransactionFilter]
    var accountFilters: [AccountFilter]

    var color: Color {
        Color(hex: colorHex)
    }

    enum CodingKeys: String, CodingKey {
        case id, name, amount, type, period, startDate
        case colorHex = "color"
        case includedCategories, excludedCategories, transactionFilters, accountFilters
    }

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
            colorHex: "#3B82F6",
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
            colorHex: "#F59E0B",
            type: .expense,
            subcategories: [
                BudgetSubcategory(id: "2-1", name: "Groceries", icon: "🛒", budgetAmount: 500.00, spentAmount: 450.00, transactionCount: 28),
                BudgetSubcategory(id: "2-2", name: "Dining Out", icon: "🍽️", budgetAmount: 200.00, spentAmount: 230.00, transactionCount: 12),
                BudgetSubcategory(id: "2-3", name: "Coffee", icon: "☕", budgetAmount: 100.00, spentAmount: 85.00, transactionCount: 18)
            ],
            budgetAmount: 800.00,
            spentAmount: 765.00
        ),
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
    static func transactions(for categoryId: String, subcategoryId: String? = nil) -> [CategoryTransaction] {
        return []
    }
}

extension Budget {
    static let mockBudgets: [Budget] = []
}
