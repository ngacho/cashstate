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

// MARK: - SimpleFin Transaction (matches backend SimplefinTransactionResponse)

struct Transaction: Identifiable, Codable {
    let id: String
    let simplefinAccountId: String
    let simplefinTransactionId: String
    let amount: Double
    let currency: String
    let postedDate: Int          // Unix timestamp
    let transactionDate: Int     // Unix timestamp
    let description: String
    let payee: String?
    let memo: String?
    let pending: Bool
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case simplefinAccountId = "simplefin_account_id"
        case simplefinTransactionId = "simplefin_transaction_id"
        case amount
        case currency
        case postedDate = "posted_date"
        case transactionDate = "transaction_date"
        case description
        case payee
        case memo
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
        // Convert Unix timestamp to readable format
        let date = Date(timeIntervalSince1970: TimeInterval(postedDate))
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    // Use payee as primary name, fall back to description
    var name: String { payee ?? description }

    // Use description as merchant name
    var merchantName: String { description }
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

struct SimplefinAccount: Identifiable, Codable {
    let id: String
    let simplefinAccountId: String
    let name: String
    let currency: String
    let balance: Double?
    let availableBalance: Double?
    let balanceDate: Int?
    let organizationName: String?
    let organizationDomain: String?
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case simplefinAccountId = "simplefin_account_id"
        case name
        case currency
        case balance
        case availableBalance = "available_balance"
        case balanceDate = "balance_date"
        case organizationName = "organization_name"
        case organizationDomain = "organization_domain"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var displayBalance: String {
        guard let balance = balance else { return "N/A" }
        return String(format: "$%.2f", balance)
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
    let accountsSynced: Int
    let transactionsAdded: Int
    let transactionsUpdated: Int
    let errors: [String]

    enum CodingKeys: String, CodingKey {
        case success
        case syncJobId = "sync_job_id"
        case accountsSynced = "accounts_synced"
        case transactionsAdded = "transactions_added"
        case transactionsUpdated = "transactions_updated"
        case errors
    }
}

// MARK: - Snapshots

struct SnapshotData: Codable, Identifiable {
    let date: String
    let balance: Double

    var id: String { date }

    var dateValue: Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter.date(from: date) ?? Date()
    }
}

struct SnapshotsResponse: Codable {
    let startDate: String
    let endDate: String
    let granularity: String
    let data: [SnapshotData]

    enum CodingKeys: String, CodingKey {
        case startDate = "start_date"
        case endDate = "end_date"
        case granularity
        case data
    }
}
