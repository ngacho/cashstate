import Foundation

// MARK: - Error Types

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case serverError(Int, String?)
    case networkError(Error)
    case convexError(String)
    case notLoggedIn

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid server response"
        case .unauthorized:
            return "Unauthorized - please login again"
        case .serverError(let code, let message):
            return message ?? "Server error (\(code))"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .convexError(let message):
            return "Error: \(message)"
        case .notLoggedIn:
            return "Not logged in"
        }
    }
}

// MARK: - Convex HTTP API response wrappers

private struct ConvexResponse<T: Decodable>: Decodable {
    let status: String
    let value: T?
    let errorMessage: String?
}

private struct ConvexVoidResponse: Decodable {
    let status: String
    let errorMessage: String?
}

// Convex paginated result from .paginate()
struct ConvexPage<T: Decodable>: Decodable {
    let page: [T]
    let isDone: Bool
    let continueCursor: String
}

// MARK: - Dev Auth Models

struct DevAuthResponse: Decodable {
    let userId: String
    let username: String
}

// MARK: - APIClient Actor

/// Networking actor that calls the Convex HTTP API.
/// Uses naive dev auth: stores userId and injects it into every call.
actor APIClient {
    private let session: URLSession
    private var userId: String?

    static let shared = APIClient()

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = Config.requestTimeout
        self.session = URLSession(configuration: config)
    }

    // MARK: - Dev Auth

    func register(username: String, password: String) async throws -> DevAuthResponse {
        let result: DevAuthResponse = try await convexMutation(
            function: "devAuth:register",
            args: ["username": username, "password": password],
            skipUserId: true
        )
        self.userId = result.userId
        UserDefaults.standard.set(result.userId, forKey: "dev_user_id")
        UserDefaults.standard.set(result.username, forKey: "dev_username")
        return result
    }

    func login(username: String, password: String) async throws -> DevAuthResponse {
        let result: DevAuthResponse = try await convexMutation(
            function: "devAuth:login",
            args: ["username": username, "password": password],
            skipUserId: true
        )
        self.userId = result.userId
        UserDefaults.standard.set(result.userId, forKey: "dev_user_id")
        UserDefaults.standard.set(result.username, forKey: "dev_username")
        return result
    }

    func me() async throws -> DevAuthResponse {
        guard let uid = currentUserId() else { throw APIError.notLoggedIn }
        return try await convexQuery(
            function: "devAuth:me",
            args: ["userId": uid],
            skipUserId: true
        )
    }

    func loadStoredSession() -> Bool {
        if let storedId = UserDefaults.standard.string(forKey: "dev_user_id") {
            self.userId = storedId
            return true
        }
        return false
    }

    func isLoggedIn() -> Bool {
        return currentUserId() != nil
    }

    func logout() {
        self.userId = nil
        UserDefaults.standard.removeObject(forKey: "dev_user_id")
        UserDefaults.standard.removeObject(forKey: "dev_username")
    }

    func currentUserId() -> String? {
        if let uid = userId { return uid }
        if let stored = UserDefaults.standard.string(forKey: "dev_user_id") {
            self.userId = stored
            return stored
        }
        return nil
    }

    // MARK: - Convex Base Methods

    private func convexQuery<T: Decodable>(function: String, args: [String: Any] = [:], skipUserId: Bool = false) async throws -> T {
        return try await convexCall(endpoint: "/api/query", function: function, args: args, skipUserId: skipUserId)
    }

    private func convexMutation<T: Decodable>(function: String, args: [String: Any] = [:], skipUserId: Bool = false) async throws -> T {
        return try await convexCall(endpoint: "/api/mutation", function: function, args: args, skipUserId: skipUserId)
    }

    private func convexAction<T: Decodable>(function: String, args: [String: Any] = [:], skipUserId: Bool = false) async throws -> T {
        return try await convexCall(endpoint: "/api/action", function: function, args: args, skipUserId: skipUserId)
    }

    private func convexCall<T: Decodable>(endpoint: String, function: String, args: [String: Any], skipUserId: Bool = false) async throws -> T {
        guard let url = URL(string: Config.convexURL + endpoint) else {
            throw APIError.invalidURL
        }

        // Auto-inject userId into args unless skipped (for auth endpoints)
        var finalArgs = args
        if !skipUserId {
            guard let uid = currentUserId() else {
                throw APIError.notLoggedIn
            }
            if finalArgs["userId"] == nil {
                finalArgs["userId"] = uid
            }
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "path": function,
            "args": finalArgs,
            "format": "json",
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        if Config.debugMode {
            print("→ CONVEX \(function)")
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        if Config.debugMode {
            print("← \(httpResponse.statusCode) \(function)")
        }

        if httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        }

        // Parse Convex envelope
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            let status = json["status"] as? String ?? ""
            if status == "error" {
                let msg = json["errorMessage"] as? String ?? "Unknown error"
                throw APIError.convexError(msg)
            }
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.serverError(httpResponse.statusCode, nil)
        }

        // Decode the "value" field from the Convex envelope
        let decoder = JSONDecoder()
        if let valueData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let value = valueData["value"] {
            let valueJSON = try JSONSerialization.data(withJSONObject: value)
            return try decoder.decode(T.self, from: valueJSON)
        }

        return try decoder.decode(T.self, from: data)
    }

    // MARK: - SimpleFin Methods

    func setupSimplefin(setupToken: String, institutionName: String?) async throws -> SimplefinSetupResponse {
        var args: [String: Any] = ["setupToken": setupToken]
        if let name = institutionName { args["institutionName"] = name }
        return try await convexAction(function: "actions/simplefinSync:setup", args: args)
    }

    func listSimplefinItems() async throws -> [SimplefinItem] {
        return try await convexQuery(function: "accounts:listItems")
    }

    func syncSimplefin(itemId: String, startDate: Int? = nil, forceSync: Bool = false) async throws -> SimplefinSyncResponse {
        var args: [String: Any] = ["itemId": itemId, "forceSync": forceSync]
        if let sd = startDate { args["startDate"] = sd }
        return try await convexAction(function: "actions/simplefinSync:sync", args: args)
    }

    func deleteSimplefinItem(itemId: String) async throws {
        struct VoidResult: Decodable { let success: Bool }
        let _: VoidResult = try await convexMutation(function: "accounts:disconnect", args: ["itemId": itemId])
    }

    func listSimplefinAccounts(itemId: String) async throws -> [SimplefinAccount] {
        return try await convexQuery(function: "accounts:listAccounts", args: ["itemId": itemId])
    }

    func listAllAccounts() async throws -> [SimplefinAccount] {
        return try await convexQuery(function: "accounts:listAllAccounts")
    }

    func listSimplefinTransactions(
        dateFrom: Int? = nil,
        dateTo: Int? = nil,
        limit: Int = 50,
        offset: Int = 0,
        accountIds: [String]? = nil
    ) async throws -> TransactionListResponse {
        var args: [String: Any] = [
            "paginationOpts": ["numItems": limit, "cursor": NSNull()],
        ]
        if let dateFrom = dateFrom { args["dateFrom"] = dateFrom }
        if let dateTo = dateTo { args["dateTo"] = dateTo }
        if let accountIds = accountIds, !accountIds.isEmpty { args["accountIds"] = accountIds }

        let page: ConvexPage<Transaction> = try await convexQuery(function: "transactions:list", args: args)
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
        var args: [String: Any] = ["granularity": granularity]
        if let sd = startDate { args["startDate"] = formatter.string(from: sd) }
        if let ed = endDate { args["endDate"] = formatter.string(from: ed) }
        return try await convexQuery(function: "snapshots:list", args: args)
    }

    func calculateSnapshots(startDate: Date? = nil, endDate: Date? = nil) async throws {
        struct VoidResult: Decodable { let success: Bool }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        var args: [String: Any] = [:]
        if let sd = startDate { args["startDate"] = formatter.string(from: sd) }
        if let ed = endDate { args["endDate"] = formatter.string(from: ed) }
        let _: VoidResult = try await convexMutation(function: "snapshots:calculate", args: args)
    }

    func getAccountSnapshots(
        accountId: String,
        startDate: Date? = nil,
        endDate: Date? = nil,
        granularity: String = "day"
    ) async throws -> SnapshotsResponse {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        var args: [String: Any] = ["accountId": accountId, "granularity": granularity]
        if let sd = startDate { args["startDate"] = formatter.string(from: sd) }
        if let ed = endDate { args["endDate"] = formatter.string(from: ed) }
        return try await convexQuery(function: "snapshots:listForAccount", args: args)
    }

    // MARK: - Categories

    func seedDefaultCategories(monthlyBudget: Double, accountIds: [String] = []) async throws -> SeedDefaultsResponse {
        let args: [String: Any] = [
            "monthlyBudget": monthlyBudget,
            "accountIds": accountIds,
        ]
        return try await convexMutation(function: "categories:seedDefaults", args: args)
    }

    func fetchCategories() async throws -> [Category] {
        return try await convexQuery(function: "categories:list")
    }

    func fetchCategoriesTree() async throws -> [CategoryWithSubcategories] {
        return try await convexQuery(function: "categories:tree")
    }

    func createSubcategory(categoryId: String, name: String, icon: String) async throws -> Subcategory {
        return try await convexMutation(
            function: "categories:createSubcategory",
            args: ["categoryId": categoryId, "name": name, "icon": icon]
        )
    }

    func updateCategory(categoryId: String, name: String, icon: String, color: String) async throws -> Category {
        return try await convexMutation(
            function: "categories:update",
            args: ["id": categoryId, "name": name, "icon": icon, "color": color]
        )
    }

    func deleteCategory(categoryId: String) async throws {
        struct VoidResult: Decodable { let success: Bool }
        let _: VoidResult = try await convexMutation(function: "categories:deleteCategory", args: ["id": categoryId])
    }

    func categorizeTransaction(
        transactionId: String,
        categoryId: String?,
        subcategoryId: String?,
        createRule: Bool = false
    ) async throws {
        struct VoidResult: Decodable { let success: Bool }
        var args: [String: Any] = [
            "txId": transactionId,
            "createRule": createRule,
        ]
        if let cid = categoryId { args["categoryId"] = cid }
        if let sid = subcategoryId { args["subcategoryId"] = sid }
        let _: VoidResult = try await convexMutation(function: "transactions:categorize", args: args)
    }

    func listCategorizationRules() async throws -> [CategorizationRule] {
        return try await convexQuery(function: "categories:listRules")
    }

    func createCategorizationRule(matchField: String, matchValue: String, categoryId: String, subcategoryId: String?) async throws -> CategorizationRule {
        var args: [String: Any] = [
            "matchField": matchField,
            "matchValue": matchValue,
            "categoryId": categoryId,
        ]
        if let sid = subcategoryId { args["subcategoryId"] = sid }
        return try await convexMutation(function: "categories:createRule", args: args)
    }

    func deleteCategorizationRule(ruleId: String) async throws {
        struct VoidResult: Decodable { let success: Bool }
        let _: VoidResult = try await convexMutation(function: "categories:deleteRule", args: ["id": ruleId])
    }

    func createCategory(name: String, icon: String, color: String) async throws -> Category {
        return try await convexMutation(
            function: "categories:create",
            args: ["name": name, "icon": icon, "color": color]
        )
    }

    // MARK: - Budgets

    func getBudgetSummary(month: String) async throws -> BudgetSummary {
        return try await convexQuery(function: "budgets:summary", args: ["month": month])
    }

    func fetchBudgets() async throws -> [BudgetAPI] {
        return try await convexQuery(function: "budgets:list")
    }

    func createBudgetLineItem(budgetId: String, categoryId: String, subcategoryId: String?, amount: Double) async throws -> BudgetLineItem {
        var args: [String: Any] = [
            "budgetId": budgetId,
            "categoryId": categoryId,
            "amount": amount,
        ]
        if let sid = subcategoryId { args["subcategoryId"] = sid }
        return try await convexMutation(function: "budgets:createLineItem", args: args)
    }

    func updateBudgetLineItem(budgetId: String, lineItemId: String, amount: Double) async throws -> BudgetLineItem {
        return try await convexMutation(
            function: "budgets:updateLineItem",
            args: ["id": lineItemId, "amount": amount]
        )
    }

    func deleteBudgetLineItem(budgetId: String, lineItemId: String) async throws {
        struct VoidResult: Decodable { let success: Bool }
        let _: VoidResult = try await convexMutation(function: "budgets:deleteLineItem", args: ["id": lineItemId])
    }

    func fetchBudgetLineItems(budgetId: String) async throws -> [BudgetLineItem] {
        return try await convexQuery(function: "budgets:listLineItems", args: ["budgetId": budgetId])
    }

    func createBudget(name: String, isDefault: Bool, emoji: String? = "💰", color: String? = "#00A699") async throws -> BudgetAPI {
        var args: [String: Any] = ["name": name, "isDefault": isDefault]
        if let e = emoji { args["emoji"] = e }
        if let c = color { args["color"] = c }
        return try await convexMutation(function: "budgets:create", args: args)
    }

    func updateBudget(budgetId: String, name: String? = nil, isDefault: Bool? = nil, emoji: String? = nil, color: String? = nil) async throws -> BudgetAPI {
        var args: [String: Any] = ["id": budgetId]
        if let n = name { args["name"] = n }
        if let d = isDefault { args["isDefault"] = d }
        if let e = emoji { args["emoji"] = e }
        if let c = color { args["color"] = c }
        return try await convexMutation(function: "budgets:update", args: args)
    }

    func fetchBudgetMonths() async throws -> [BudgetMonth] {
        return try await convexQuery(function: "budgets:listMonths")
    }

    func assignBudgetMonth(budgetId: String, month: String) async throws -> BudgetMonth {
        return try await convexMutation(
            function: "budgets:assignMonth",
            args: ["budgetId": budgetId, "month": month]
        )
    }

    func deleteBudgetMonth(monthId: String) async throws {
        struct VoidResult: Decodable { let success: Bool }
        let _: VoidResult = try await convexMutation(function: "budgets:deleteMonth", args: ["id": monthId])
    }

    func deleteBudget(budgetId: String) async throws {
        struct VoidResult: Decodable { let success: Bool }
        let _: VoidResult = try await convexMutation(function: "budgets:deleteBudget", args: ["id": budgetId])
    }

    func listBudgetAccounts(budgetId: String) async throws -> [BudgetAccountItem] {
        return try await convexQuery(function: "budgets:listAccounts", args: ["budgetId": budgetId])
    }

    func addBudgetAccount(budgetId: String, accountId: String) async throws -> BudgetAccountItem {
        return try await convexMutation(
            function: "budgets:addAccount",
            args: ["budgetId": budgetId, "accountId": accountId]
        )
    }

    func removeBudgetAccount(budgetId: String, accountId: String) async throws {
        struct VoidResult: Decodable { let success: Bool }
        let _: VoidResult = try await convexMutation(
            function: "budgets:removeAccount",
            args: ["budgetId": budgetId, "accountId": accountId]
        )
    }

    // MARK: - Transaction Categorization

    func batchUpdateTransactions(_ updates: [(transactionId: String, categoryId: String?, subcategoryId: String?)]) async throws -> BatchUpdateResponse {
        let updateList = updates.map { u -> [String: Any] in
            var d: [String: Any] = ["txId": u.transactionId]
            if let cid = u.categoryId { d["categoryId"] = cid }
            if let sid = u.subcategoryId { d["subcategoryId"] = sid }
            return d
        }
        return try await convexMutation(function: "transactions:batchCategorize", args: ["updates": updateList])
    }

    func categorizeWithAI(transactionIds: [String]? = nil, force: Bool = false) async throws -> AICategorizationResponse {
        var args: [String: Any] = ["force": force]
        if let ids = transactionIds { args["transactionIds"] = ids }
        return try await convexAction(function: "actions/aiCategorize:categorize", args: args)
    }

    // MARK: - Categorization Jobs

    func startCategorizationJob(transactionIds: [String]? = nil, force: Bool = false) async throws -> CategorizationJobStartResponse {
        var args: [String: Any] = ["force": force]
        if let ids = transactionIds { args["transactionIds"] = ids }
        return try await convexMutation(function: "categorizationJobs:start", args: args)
    }

    func getCategorizationJobStatus(jobId: String) async throws -> CategorizationJob {
        return try await convexQuery(function: "categorizationJobs:getStatus", args: ["jobId": jobId])
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
        return try await convexQuery(function: "goals:list")
    }

    func createGoal(
        name: String,
        description: String?,
        goalType: GoalType,
        targetAmount: Double,
        targetDate: String?,
        accounts: [GoalAccountRequest]
    ) async throws -> Goal {
        var args: [String: Any] = [
            "name": name,
            "goalType": goalType.rawValue,
            "targetAmount": targetAmount,
            "accounts": accounts.map { ["accountId": $0.simplefinAccountId, "allocationPercentage": $0.allocationPercentage] },
        ]
        if let d = description { args["description"] = d }
        if let td = targetDate { args["targetDate"] = td }
        return try await convexMutation(function: "goals:create", args: args)
    }

    func fetchGoalDetail(
        goalId: String,
        startDate: Date? = nil,
        endDate: Date? = nil,
        granularity: String = "day"
    ) async throws -> GoalDetail {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        var args: [String: Any] = ["id": goalId, "granularity": granularity]
        if let sd = startDate { args["startDate"] = formatter.string(from: sd) }
        if let ed = endDate { args["endDate"] = formatter.string(from: ed) }
        return try await convexQuery(function: "goals:get", args: args)
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
        var args: [String: Any] = ["id": goalId]
        if let n = name { args["name"] = n }
        if let d = description { args["description"] = d }
        if let ta = targetAmount { args["targetAmount"] = ta }
        if let td = targetDate { args["targetDate"] = td }
        if let ic = isCompleted { args["isCompleted"] = ic }
        if let accs = accounts {
            args["accounts"] = accs.map { ["accountId": $0.simplefinAccountId, "allocationPercentage": $0.allocationPercentage] }
        }
        return try await convexMutation(function: "goals:update", args: args)
    }

    func deleteGoal(goalId: String) async throws {
        struct VoidResult: Decodable { let success: Bool }
        let _: VoidResult = try await convexMutation(function: "goals:deleteGoal", args: ["id": goalId])
    }
}
