import Foundation

// MARK: - Auth Response (matches backend TokenResponse)

struct AuthResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let tokenType: String
    let expiresIn: Int
    let userId: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case userId = "user_id"
    }
}

// MARK: - Transaction

struct Transaction: Identifiable, Codable {
    let id: String
    let plaidItemId: String
    let plaidTransactionId: String
    let accountId: String
    let amount: Double
    let isoCurrencyCode: String?
    let date: String
    let name: String
    let merchantName: String?
    let category: [String]?
    let pending: Bool
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case plaidItemId = "plaid_item_id"
        case plaidTransactionId = "plaid_transaction_id"
        case accountId = "account_id"
        case amount
        case isoCurrencyCode = "iso_currency_code"
        case date, name
        case merchantName = "merchant_name"
        case category, pending
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var isExpense: Bool { amount < 0 }
    var displayAmount: String {
        let value = abs(amount)
        return String(format: "$%.2f", value)
    }
    var displayDate: String {
        // Convert YYYY-MM-DD to readable format
        let components = date.split(separator: "-")
        guard components.count == 3,
              let month = Int(components[1]),
              let day = Int(components[2]) else {
            return date
        }
        let monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                          "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        return "\(monthNames[month - 1]) \(day)"
    }
}

// MARK: - Transaction List Response

struct TransactionListResponse: Codable {
    let items: [Transaction]
    let total: Int
    let limit: Int
    let offset: Int
    let hasMore: Bool

    enum CodingKeys: String, CodingKey {
        case items, total, limit, offset
        case hasMore = "has_more"
    }
}

// MARK: - Time Range

enum TimeRange: String, CaseIterable {
    case day = "Day"
    case week = "Week"
    case month = "Month"
    case year = "Year"
    case custom = "Custom"
}

// MARK: - Spending Insight

struct SpendingInsight {
    let timeRange: TimeRange
    let totalSpent: Decimal
    let totalIncome: Decimal
    let transactionCount: Int

    var netAmount: Decimal {
        totalIncome - abs(totalSpent)
    }
}
