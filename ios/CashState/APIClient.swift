import Combine
import ConvexMobile
import Foundation

// MARK: - Error Types

enum APIError: LocalizedError {
    case convexError(String)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .convexError(let message):
            return "Error: \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

// Convex paginated result from .paginate()
struct ConvexPage<T: Decodable>: Decodable {
    let page: [T]
    let isDone: Bool
    let continueCursor: String
}

// MARK: - APIClient

/// Networking client that wraps the global ConvexMobile client.
/// JWT auth is handled automatically via Clerk — no userId injection needed.
class APIClient {
    static let shared = APIClient()

    private init() {}

    /// One-shot query: subscribe, take first value, cancel.
    private func query<T: Decodable>(_ name: String, with args: [String: ConvexEncodable?]? = nil) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            var cancellable: AnyCancellable?
            cancellable = convexClient
                .subscribe(to: name, with: args, yielding: T.self)
                .first()
                .sink(
                    receiveCompletion: { completion in
                        switch completion {
                        case .finished:
                            break
                        case .failure(let error):
                            continuation.resume(throwing: error)
                        }
                        cancellable?.cancel()
                    },
                    receiveValue: { value in
                        continuation.resume(returning: value)
                    }
                )
        }
    }

    // MARK: - SimpleFin Methods

    func setupSimplefin(setupToken: String, institutionName: String?) async throws -> SimplefinSetupResponse {
        var args: [String: ConvexEncodable?] = ["setupToken": setupToken]
        if let name = institutionName { args["institutionName"] = name }
        return try await convexClient.action("actions/simplefinSync:setup", with: args)
    }

    func listSimplefinItems() async throws -> [SimplefinItem] {
        return try await query("accounts:listItems")
    }

    func syncSimplefin(itemId: String, startDate: Int? = nil, forceSync: Bool = false) async throws -> SimplefinSyncResponse {
        var args: [String: ConvexEncodable?] = ["itemId": itemId, "forceSync": forceSync]
        if let sd = startDate { args["startDate"] = sd }
        return try await convexClient.action("actions/simplefinSync:sync", with: args)
    }

    func deleteSimplefinItem(itemId: String) async throws {
        try await convexClient.mutation("accounts:disconnect", with: ["itemId": itemId])
    }

    func listSimplefinAccounts(itemId: String) async throws -> [SimplefinAccount] {
        return try await query("accounts:listAccounts", with: ["itemId": itemId])
    }

    func listAllAccounts() async throws -> [SimplefinAccount] {
        return try await query("accounts:listAllAccounts")
    }

    func listSimplefinTransactions(
        dateFrom: Int? = nil,
        dateTo: Int? = nil,
        limit: Int = 50,
        offset: Int = 0,
        accountIds: [String]? = nil
    ) async throws -> TransactionListResponse {
        var args: [String: ConvexEncodable?] = [
            "paginationOpts": ["numItems": limit, "cursor": nil] as [String: ConvexEncodable?],
        ]
        if let dateFrom = dateFrom { args["dateFrom"] = dateFrom }
        if let dateTo = dateTo { args["dateTo"] = dateTo }
        if let accountIds = accountIds, !accountIds.isEmpty {
            args["accountIds"] = accountIds as [ConvexEncodable?]
        }

        let page: ConvexPage<Transaction> = try await query("transactions:list", with: args)
        return TransactionListResponse(
            items: page.page,
            total: page.page.count,
            hasPreviousMonth: offset > 0,
            hasNextMonth: !page.isDone
        )
    }

    // MARK: - Snapshots

    func getSnapshots(
        startDate: Date? = nil,
        endDate: Date? = nil,
        granularity: String = "day"
    ) async throws -> SnapshotsResponse {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        var args: [String: ConvexEncodable?] = ["granularity": granularity]
        if let sd = startDate { args["startDate"] = formatter.string(from: sd) }
        if let ed = endDate { args["endDate"] = formatter.string(from: ed) }
        return try await query("snapshots:list", with: args)
    }

    func calculateSnapshots(startDate: Date? = nil, endDate: Date? = nil) async throws {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        var args: [String: ConvexEncodable?] = [:]
        if let sd = startDate { args["startDate"] = formatter.string(from: sd) }
        if let ed = endDate { args["endDate"] = formatter.string(from: ed) }
        try await convexClient.mutation("snapshots:calculate", with: args)
    }

    func getAccountSnapshots(
        accountId: String,
        startDate: Date? = nil,
        endDate: Date? = nil,
        granularity: String = "day"
    ) async throws -> SnapshotsResponse {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        var args: [String: ConvexEncodable?] = ["accountId": accountId, "granularity": granularity]
        if let sd = startDate { args["startDate"] = formatter.string(from: sd) }
        if let ed = endDate { args["endDate"] = formatter.string(from: ed) }
        return try await query("snapshots:listForAccount", with: args)
    }

    // MARK: - Categories

    func seedDefaultCategories(monthlyBudget: Double, accountIds: [String] = []) async throws -> SeedDefaultsResponse {
        let args: [String: ConvexEncodable?] = [
            "monthlyBudget": monthlyBudget,
            "accountIds": accountIds as [ConvexEncodable?],
        ]
        return try await convexClient.mutation("categories:seedDefaults", with: args)
    }

    func fetchCategories() async throws -> [Category] {
        return try await query("categories:list")
    }

    func fetchCategoriesTree() async throws -> [CategoryWithSubcategories] {
        return try await query("categories:tree")
    }

    func createSubcategory(categoryId: String, name: String, icon: String) async throws -> Subcategory {
        return try await convexClient.mutation(
            "categories:createSubcategory",
            with: ["categoryId": categoryId, "name": name, "icon": icon]
        )
    }

    func updateSubcategory(subcategoryId: String, name: String? = nil, icon: String? = nil) async throws -> Subcategory {
        var args: [String: ConvexEncodable?] = ["id": subcategoryId]
        if let n = name { args["name"] = n }
        if let i = icon { args["icon"] = i }
        return try await convexClient.mutation("categories:updateSubcategory", with: args)
    }

    func updateCategory(categoryId: String, name: String, icon: String, color: String) async throws -> Category {
        return try await convexClient.mutation(
            "categories:update",
            with: ["id": categoryId, "name": name, "icon": icon, "color": color]
        )
    }

    func deleteCategory(categoryId: String) async throws {
        try await convexClient.mutation("categories:deleteCategory", with: ["id": categoryId])
    }

    func categorizeTransaction(
        transactionId: String,
        categoryId: String?,
        subcategoryId: String?,
        createRule: Bool = false
    ) async throws {
        var args: [String: ConvexEncodable?] = [
            "txId": transactionId,
            "createRule": createRule,
        ]
        if let cid = categoryId { args["categoryId"] = cid }
        if let sid = subcategoryId { args["subcategoryId"] = sid }
        try await convexClient.mutation("transactions:categorize", with: args)
    }

    func listCategorizationRules() async throws -> [CategorizationRule] {
        return try await query("categories:listRules")
    }

    func createCategorizationRule(matchField: String, matchValue: String, categoryId: String, subcategoryId: String?) async throws -> CategorizationRule {
        var args: [String: ConvexEncodable?] = [
            "matchField": matchField,
            "matchValue": matchValue,
            "categoryId": categoryId,
        ]
        if let sid = subcategoryId { args["subcategoryId"] = sid }
        return try await convexClient.mutation("categories:createRule", with: args)
    }

    func deleteCategorizationRule(ruleId: String) async throws {
        try await convexClient.mutation("categories:deleteRule", with: ["id": ruleId])
    }

    func createCategory(name: String, icon: String, color: String) async throws -> Category {
        return try await convexClient.mutation(
            "categories:create",
            with: ["name": name, "icon": icon, "color": color]
        )
    }

    // MARK: - Budgets

    func getBudgetSummary(month: String) async throws -> BudgetSummary {
        return try await query("budgets:summary", with: ["month": month])
    }

    func fetchBudgets() async throws -> [BudgetAPI] {
        return try await query("budgets:list")
    }

    func createBudgetLineItem(budgetId: String, categoryId: String, subcategoryId: String?, amount: Double) async throws -> BudgetLineItem {
        var args: [String: ConvexEncodable?] = [
            "budgetId": budgetId,
            "categoryId": categoryId,
            "amount": amount,
        ]
        if let sid = subcategoryId { args["subcategoryId"] = sid }
        return try await convexClient.mutation("budgets:createLineItem", with: args)
    }

    func updateBudgetLineItem(budgetId: String, lineItemId: String, amount: Double) async throws -> BudgetLineItem {
        return try await convexClient.mutation(
            "budgets:updateLineItem",
            with: ["id": lineItemId, "amount": amount]
        )
    }

    func deleteBudgetLineItem(budgetId: String, lineItemId: String) async throws {
        try await convexClient.mutation("budgets:deleteLineItem", with: ["id": lineItemId])
    }

    func fetchBudgetLineItems(budgetId: String) async throws -> [BudgetLineItem] {
        return try await query("budgets:listLineItems", with: ["budgetId": budgetId])
    }

    func createBudget(name: String, isDefault: Bool, emoji: String? = "💰", color: String? = "#00A699") async throws -> BudgetAPI {
        var args: [String: ConvexEncodable?] = ["name": name, "isDefault": isDefault]
        if let e = emoji { args["emoji"] = e }
        if let c = color { args["color"] = c }
        return try await convexClient.mutation("budgets:create", with: args)
    }

    func updateBudget(budgetId: String, name: String? = nil, isDefault: Bool? = nil, emoji: String? = nil, color: String? = nil) async throws -> BudgetAPI {
        var args: [String: ConvexEncodable?] = ["id": budgetId]
        if let n = name { args["name"] = n }
        if let d = isDefault { args["isDefault"] = d }
        if let e = emoji { args["emoji"] = e }
        if let c = color { args["color"] = c }
        return try await convexClient.mutation("budgets:update", with: args)
    }

    func fetchBudgetMonths() async throws -> [BudgetMonth] {
        return try await query("budgets:listMonths")
    }

    func assignBudgetMonth(budgetId: String, month: String) async throws -> BudgetMonth {
        return try await convexClient.mutation(
            "budgets:assignMonth",
            with: ["budgetId": budgetId, "month": month]
        )
    }

    func deleteBudgetMonth(monthId: String) async throws {
        try await convexClient.mutation("budgets:deleteMonth", with: ["id": monthId])
    }

    func deleteBudget(budgetId: String) async throws {
        try await convexClient.mutation("budgets:deleteBudget", with: ["id": budgetId])
    }

    func listBudgetAccounts(budgetId: String) async throws -> [BudgetAccountItem] {
        return try await query("budgets:listAccounts", with: ["budgetId": budgetId])
    }

    func addBudgetAccount(budgetId: String, accountId: String) async throws -> BudgetAccountItem {
        return try await convexClient.mutation(
            "budgets:addAccount",
            with: ["budgetId": budgetId, "accountId": accountId]
        )
    }

    func removeBudgetAccount(budgetId: String, accountId: String) async throws {
        try await convexClient.mutation(
            "budgets:removeAccount",
            with: ["budgetId": budgetId, "accountId": accountId]
        )
    }

    // MARK: - Transaction Categorization

    func batchUpdateTransactions(_ updates: [(transactionId: String, categoryId: String?, subcategoryId: String?)]) async throws -> BatchUpdateResponse {
        let updateList: [ConvexEncodable?] = updates.map { u -> ConvexEncodable? in
            var d: [String: ConvexEncodable?] = ["txId": u.transactionId]
            if let cid = u.categoryId { d["categoryId"] = cid }
            if let sid = u.subcategoryId { d["subcategoryId"] = sid }
            return d
        }
        return try await convexClient.mutation("transactions:batchCategorize", with: ["updates": updateList as [ConvexEncodable?]])
    }

    func categorizeWithAI(transactionIds: [String]? = nil, force: Bool = false) async throws -> AICategorizationResponse {
        var args: [String: ConvexEncodable?] = ["force": force]
        if let ids = transactionIds { args["transactionIds"] = ids as [ConvexEncodable?] }
        return try await convexClient.action("actions/aiCategorize:categorize", with: args)
    }

    // MARK: - Categorization Jobs

    func startCategorizationJob(transactionIds: [String]? = nil, force: Bool = false) async throws -> CategorizationJobStartResponse {
        var args: [String: ConvexEncodable?] = ["force": force]
        if let ids = transactionIds { args["transactionIds"] = ids as [ConvexEncodable?] }
        return try await convexClient.mutation("categorizationJobs:start", with: args)
    }

    func getCategorizationJobStatus(jobId: String) async throws -> CategorizationJob {
        return try await query("categorizationJobs:getStatus", with: ["jobId": jobId])
    }
}

// MARK: - Response Models

struct BatchUpdateResponse: Codable {
    let updatedCount: Int
    let failedCount: Int
    let failedIds: [String]
}

struct AICategorizationResponse: Codable {
    let categorizedCount: Int
    let failedCount: Int
    let results: [AICategorizationResult]
}

struct AICategorizationResult: Codable {
    let transactionId: String
    let categoryId: String?
    let subcategoryId: String?
    let confidence: Double
    let reasoning: String?
}

// MARK: - Goals

extension APIClient {

    func fetchGoals() async throws -> [Goal] {
        return try await query("goals:list")
    }

    func createGoal(
        name: String,
        description: String?,
        goalType: GoalType,
        targetAmount: Double,
        targetDate: String?,
        accounts: [GoalAccountRequest]
    ) async throws -> Goal {
        let accountsList: [ConvexEncodable?] = accounts.map { a -> ConvexEncodable? in
            ["accountId": a.simplefinAccountId, "allocationPercentage": a.allocationPercentage] as [String: ConvexEncodable?]
        }
        var args: [String: ConvexEncodable?] = [
            "name": name,
            "goalType": goalType.rawValue,
            "targetAmount": targetAmount,
            "accounts": accountsList as [ConvexEncodable?],
        ]
        if let d = description { args["description"] = d }
        if let td = targetDate { args["targetDate"] = td }
        return try await convexClient.mutation("goals:create", with: args)
    }

    func fetchGoalDetail(
        goalId: String,
        startDate: Date? = nil,
        endDate: Date? = nil,
        granularity: String = "day"
    ) async throws -> GoalDetail {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        var args: [String: ConvexEncodable?] = ["id": goalId, "granularity": granularity]
        if let sd = startDate { args["startDate"] = formatter.string(from: sd) }
        if let ed = endDate { args["endDate"] = formatter.string(from: ed) }
        return try await query("goals:get", with: args)
    }

    func updateGoal(
        goalId: String,
        name: String? = nil,
        description: String? = nil,
        targetAmount: Double? = nil,
        targetDate: String? = nil,
        isCompleted: Bool? = nil,
        accounts: [GoalAccountRequest]? = nil
    ) async throws -> Goal {
        var args: [String: ConvexEncodable?] = ["id": goalId]
        if let n = name { args["name"] = n }
        if let d = description { args["description"] = d }
        if let ta = targetAmount { args["targetAmount"] = ta }
        if let td = targetDate { args["targetDate"] = td }
        if let ic = isCompleted { args["isCompleted"] = ic }
        if let accs = accounts {
            let accountsList: [ConvexEncodable?] = accs.map { a -> ConvexEncodable? in
                ["accountId": a.simplefinAccountId, "allocationPercentage": a.allocationPercentage] as [String: ConvexEncodable?]
            }
            args["accounts"] = accountsList as [ConvexEncodable?]
        }
        return try await convexClient.mutation("goals:update", with: args)
    }

    func deleteGoal(goalId: String) async throws {
        try await convexClient.mutation("goals:deleteGoal", with: ["id": goalId])
    }
}
