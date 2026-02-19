import Foundation

// MARK: - Category Models (Backend API)

struct Category: Identifiable, Codable, Hashable {
    let id: String
    let userId: String?
    let name: String
    let icon: String
    let color: String
    let isDefault: Bool
    let displayOrder: Int
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id, name, icon, color
        case userId = "user_id"
        case isDefault = "is_default"
        case displayOrder = "display_order"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct Subcategory: Identifiable, Codable, Hashable {
    let id: String
    let categoryId: String
    let userId: String?
    let name: String
    let icon: String
    let isDefault: Bool
    let displayOrder: Int

    enum CodingKeys: String, CodingKey {
        case id, name, icon
        case categoryId = "category_id"
        case userId = "user_id"
        case isDefault = "is_default"
        case displayOrder = "display_order"
    }
}

// MARK: - Categorization Rule

struct CategorizationRule: Identifiable, Codable {
    let id: String
    let userId: String
    let matchField: String
    let matchValue: String
    let categoryId: String
    let subcategoryId: String?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case matchField = "match_field"
        case matchValue = "match_value"
        case categoryId = "category_id"
        case subcategoryId = "subcategory_id"
        case createdAt = "created_at"
    }
}

struct CategorizationRuleListResponse: Codable {
    let items: [CategorizationRule]
    let total: Int
}

struct CategoryWithSubcategories: Identifiable, Codable {
    let id: String
    let name: String
    let icon: String
    let color: String
    let type: String?  // "income" or "expense", defaults to "expense" if nil
    let subcategories: [Subcategory]
}

struct CategoryListResponse: Codable {
    let items: [Category]
    let total: Int
}

struct CategoriesTreeResponse: Codable {
    let items: [CategoryWithSubcategories]
    let total: Int
}

struct SuccessResponse: Codable {
    let message: String
}

struct SeedDefaultsResponse: Codable {
    let categoriesCreated: Int
    let subcategoriesCreated: Int
    let budgetsCreated: Int
    let monthlyBudget: Double
    let budgetPerCategory: Double

    enum CodingKeys: String, CodingKey {
        case categoriesCreated = "categories_created"
        case subcategoriesCreated = "subcategories_created"
        case budgetsCreated = "budgets_created"
        case monthlyBudget = "monthly_budget"
        case budgetPerCategory = "budget_per_category"
    }
}

