import Foundation

// MARK: - Category Models (Convex categories table)
// Convex returns camelCase JSON — CodingKeys updated from snake_case

struct Category: Identifiable, Codable, Hashable {
    let id: String
    let userId: String?
    let name: String
    let icon: String
    let color: String
    let isDefault: Bool
    let displayOrder: Int

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case userId
        case name
        case icon
        case color
        case isDefault
        case displayOrder
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
        case id = "_id"
        case categoryId
        case userId
        case name
        case icon
        case isDefault
        case displayOrder
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

    var createdAt: String { "" } // not returned from Convex, kept for compat

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case userId
        case matchField
        case matchValue
        case categoryId
        case subcategoryId
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
    let type: String?
    let subcategories: [Subcategory]

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case name
        case icon
        case color
        case type
        case subcategories
    }
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
}
