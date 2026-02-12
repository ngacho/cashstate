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

// MARK: - Transaction (SimpleFin only)

struct Transaction: Identifiable, Codable {
    let id: String
    let simplefinItemId: String
    let simplefinTransactionId: String
    let accountId: String
    let accountName: String?
    let amount: Double
    let currency: String?
    let date: String
    let posted: String?
    let description: String
    let payee: String?
    let pending: Bool
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case simplefinItemId = "simplefin_item_id"
        case simplefinTransactionId = "simplefin_transaction_id"
        case accountId = "account_id"
        case accountName = "account_name"
        case amount
        case currency
        case date
        case posted
        case description
        case payee
        case pending
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

    // Use description as the name (SimpleFin doesn't separate these)
    var name: String { description }

    // Use payee as merchant name if available
    var merchantName: String? { payee }
}

// MARK: - Transaction List Response

struct TransactionListResponse: Codable {
    let items: [Transaction]
    let total: Int
    let limit: Int
    let offset: Int

    enum CodingKeys: String, CodingKey {
        case items, total, limit, offset
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

// MARK: - SimpleFin Models

struct SimplefinItem: Identifiable, Codable {
    let id: String
    let institutionName: String?
    let status: String
    let lastSyncedAt: String?
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case institutionName = "institution_name"
        case status
        case lastSyncedAt = "last_synced_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct SimplefinSetupRequest: Codable {
    let setupToken: String
    let institutionName: String?

    enum CodingKeys: String, CodingKey {
        case setupToken = "setup_token"
        case institutionName = "institution_name"
    }
}

struct SimplefinSetupResponse: Codable {
    let itemId: String
    let institutionName: String?

    enum CodingKeys: String, CodingKey {
        case itemId = "item_id"
        case institutionName = "institution_name"
    }
}

struct SimplefinSyncResponse: Codable {
    let success: Bool
    let syncJobId: String
    let transactionsAdded: Int
    let errors: [String]

    enum CodingKeys: String, CodingKey {
        case success
        case syncJobId = "sync_job_id"
        case transactionsAdded = "transactions_added"
        case errors
    }
}
