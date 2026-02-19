import Foundation

// MARK: - Auth Response
// Note: Auth is now handled by Clerk iOS SDK directly.
// This struct is kept for compatibility during transition.

struct AuthResponse: Codable {
    let accessToken: String
    let tokenType: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
    }
}

// MARK: - SimpleFin Transaction (matches Convex simplefinTransactions table)

struct Transaction: Identifiable, Codable, Hashable {
    let id: String                      // Convex _id
    let accountId: String               // Convex simplefinAccounts _id
    let accountName: String             // denormalized account name
    let simplefinTransactionId: String  // external SimpleFin ID (simplefinTxId)
    let amount: Double
    let currency: String
    let date: Int                       // Unix ms (posted date)
    let transactedAt: Int?              // Unix ms (transaction date, optional)
    let description: String?
    let payee: String?
    let pending: Bool
    let categoryId: String?
    let subcategoryId: String?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case accountId
        case accountName
        case simplefinTransactionId = "simplefinTxId"
        case amount
        case currency
        case date
        case transactedAt
        case description
        case payee
        case pending
        case categoryId
        case subcategoryId
    }

    // Compatibility computed properties — views reference these
    var simplefinAccountId: String { accountId }
    var postedDate: Int { date / 1000 }       // convert ms → seconds for Date()
    var transactionDate: Int { (transactedAt ?? date) / 1000 }

    var isExpense: Bool { amount < 0 }

    var displayAmount: String {
        let value = abs(amount)
        return String(format: "$%.2f", value)
    }

    var displayDate: String {
        let d = Date(timeIntervalSince1970: TimeInterval(date) / 1000.0)
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: d)
    }

    var name: String { payee ?? description ?? "" }
    var merchantName: String { description ?? "" }
    var memo: String? { nil } // removed from Convex schema
}

// Transaction list response (adapts Convex paginated format)
struct TransactionListResponse: Codable {
    let items: [Transaction]
    let total: Int
    let hasPreviousMonth: Bool
    let hasNextMonth: Bool

    enum CodingKeys: String, CodingKey {
        case items
        case total
        case hasPreviousMonth = "has_previous_month"
        case hasNextMonth = "has_next_month"
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

// MARK: - SimpleFin Models (matches Convex schema)

struct SimplefinItem: Identifiable, Codable {
    let id: String
    let institutionName: String?
    let status: String
    let lastSyncedAt: Double? // Unix ms from Convex

    var createdAt: String { "" } // not in Convex, kept for compat

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case institutionName
        case status
        case lastSyncedAt
    }
}

struct SimplefinAccount: Identifiable, Codable {
    let id: String
    let simplefinAccountId: String
    let name: String
    let currency: String
    let balance: Double?
    let availableBalance: Double?
    let balanceDate: Double? // Unix ms
    let organizationName: String? // orgName in Convex

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case simplefinAccountId
        case name
        case currency
        case balance
        case availableBalance
        case balanceDate
        case organizationName = "orgName"
    }

    var displayBalance: String {
        guard let balance = balance else { return "N/A" }
        return String(format: "$%.2f", balance)
    }
}

struct BudgetAccountItem: Identifiable, Codable {
    let budgetId: String
    let accountId: String
    let accountName: String
    let balance: Double
    let createdAt: String

    var id: String { accountId }

    enum CodingKeys: String, CodingKey {
        case budgetId
        case accountId
        case accountName
        case balance
        case createdAt
    }
}

struct BudgetAccountListResponse: Codable {
    let items: [BudgetAccountItem]
    let total: Int
}

struct SimplefinSetupRequest: Codable {
    let setupToken: String
    let institutionName: String?
}

struct SimplefinSetupResponse: Codable {
    let itemId: String
    let institutionName: String?
}

struct SimplefinSyncResponse: Codable {
    let success: Bool
    let syncJobId: String
    let accountsSynced: Int
    let transactionsAdded: Int
    let transactionsUpdated: Int
    let errors: [String]
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
}

// MARK: - Goals

enum GoalType: String, Codable, CaseIterable {
    case savings
    case debtPayment = "debt_payment"

    var displayName: String {
        switch self {
        case .savings: return "Savings"
        case .debtPayment: return "Debt Payoff"
        }
    }
}

struct GoalAccountRequest: Codable {
    let simplefinAccountId: String
    let allocationPercentage: Double
}

struct GoalCreate: Codable {
    let name: String
    let description: String?
    let goalType: GoalType
    let targetAmount: Double
    let targetDate: String?
    let accounts: [GoalAccountRequest]
}

struct GoalUpdate: Codable {
    let name: String?
    let description: String?
    let targetAmount: Double?
    let targetDate: String?
    let isCompleted: Bool?
    let accounts: [GoalAccountRequest]?
}

struct GoalAccountResponse: Codable, Identifiable {
    let id: String
    let simplefinAccountId: String
    let accountName: String
    let allocationPercentage: Double
    let currentBalance: Double
    let startingBalance: Double?

    enum CodingKeys: String, CodingKey {
        case id
        case simplefinAccountId
        case accountName
        case allocationPercentage
        case currentBalance
        case startingBalance
    }
}

struct Goal: Codable, Identifiable {
    let id: String
    let name: String
    let description: String?
    let goalType: GoalType
    let targetAmount: Double
    let targetDate: String?
    let isCompleted: Bool
    let currentAmount: Double
    let progressPercent: Double
    let accounts: [GoalAccountResponse]
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case name
        case description
        case goalType
        case targetAmount
        case targetDate
        case isCompleted
        case currentAmount
        case progressPercent
        case accounts
        case createdAt
        case updatedAt
    }
}

struct GoalDetail: Codable {
    let id: String
    let name: String
    let description: String?
    let goalType: GoalType
    let targetAmount: Double
    let targetDate: String?
    let isCompleted: Bool
    let currentAmount: Double
    let progressPercent: Double
    let accounts: [GoalAccountResponse]
    let progressData: [SnapshotData]
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case name
        case description
        case goalType
        case targetAmount
        case targetDate
        case isCompleted
        case currentAmount
        case progressPercent
        case accounts
        case progressData
        case createdAt
        case updatedAt
    }
}

struct GoalListResponse: Codable {
    let items: [Goal]
    let total: Int
}

// MARK: - Categorization Jobs

struct CategorizationJobStartResponse: Codable {
    let jobId: String
}

struct CategorizationJob: Codable, Identifiable {
    let id: String
    let userId: String
    let status: String // "running" | "completed" | "failed"
    let totalTransactions: Int
    let categorizedCount: Int
    let failedCount: Int
    let errorMessage: String?
    let completedAt: Double?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case userId
        case status
        case totalTransactions
        case categorizedCount
        case failedCount
        case errorMessage
        case completedAt
    }
}
