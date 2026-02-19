import Foundation

enum APIError: Error {
    case invalidURL
    case invalidResponse
    case unauthorized
    case serverError(Int, String?)
    case networkError(Error)

    var localizedDescription: String {
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
        }
    }
}

actor APIClient {
    private let session: URLSession
    private var accessToken: String?

    init() {
        self.session = URLSession.shared
    }

    // Custom date decoder that handles ISO8601 with fractional seconds
    private static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let iso8601FormatterNoFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static func customDateDecoder(decoder: Decoder) throws -> Date {
        let container = try decoder.singleValueContainer()
        let dateString = try container.decode(String.self)

        // Try with fractional seconds first
        if let date = Self.iso8601Formatter.date(from: dateString) {
            return date
        }

        // Fallback to without fractional seconds
        if let date = Self.iso8601FormatterNoFractional.date(from: dateString) {
            return date
        }

        throw DecodingError.dataCorruptedError(
            in: container,
            debugDescription: "Date string does not match ISO8601 format: \(dateString)"
        )
    }

    func setAccessToken(_ token: String) {
        self.accessToken = token
        // DEV ONLY: Persist token for auto-login (NOT production-ready!)
        UserDefaults.standard.set(token, forKey: "dev_access_token")
    }

    func loadStoredToken() {
        // DEV ONLY: Load persisted token for auto-login
        if let token = UserDefaults.standard.string(forKey: "dev_access_token") {
            self.accessToken = token
        }
    }

    func hasStoredToken() -> Bool {
        return UserDefaults.standard.string(forKey: "dev_access_token") != nil
    }

    func clearStoredToken() {
        UserDefaults.standard.removeObject(forKey: "dev_access_token")
        self.accessToken = nil
    }

    func request<T: Decodable>(
        endpoint: String,
        method: String = "GET",
        body: Encodable? = nil
    ) async throws -> T {
        guard let url = URL(string: Config.apiBaseURL + endpoint) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body = body {
            request.httpBody = try JSONEncoder().encode(body)
        }

        if Config.debugMode {
            print("→ \(method) \(endpoint)")
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        if Config.debugMode {
            print("← \(httpResponse.statusCode) \(endpoint)")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 {
                throw APIError.unauthorized
            }

            // Try to extract error detail from response
            var errorMessage: String?
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let detail = json["detail"] as? String {
                errorMessage = detail
            }

            throw APIError.serverError(httpResponse.statusCode, errorMessage)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom(Self.customDateDecoder)
        return try decoder.decode(T.self, from: data)
    }

    // MARK: - SimpleFin Methods

    func setupSimplefin(setupToken: String, institutionName: String?) async throws -> SimplefinSetupResponse {
        let body = SimplefinSetupRequest(
            setupToken: setupToken,
            institutionName: institutionName
        )
        return try await request(
            endpoint: "/simplefin/setup",
            method: "POST",
            body: body
        )
    }

    func listSimplefinItems() async throws -> [SimplefinItem] {
        return try await request(endpoint: "/simplefin/items")
    }

    func syncSimplefin(itemId: String, startDate: Int? = nil, forceSync: Bool = false) async throws -> SimplefinSyncResponse {
        var components = URLComponents(string: Config.apiBaseURL + "/simplefin/sync/\(itemId)")
        var queryItems: [URLQueryItem] = []

        if let startDate = startDate {
            queryItems.append(URLQueryItem(name: "start_date", value: String(startDate)))
        }
        if forceSync {
            queryItems.append(URLQueryItem(name: "force_sync", value: "true"))
        }

        if !queryItems.isEmpty {
            components?.queryItems = queryItems
        }

        guard let url = components?.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if Config.debugMode {
            print("→ POST /simplefin/sync/\(itemId)")
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        if Config.debugMode {
            print("← \(httpResponse.statusCode) /simplefin/sync/\(itemId)")
        }

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 {
                throw APIError.unauthorized
            }

            var errorMessage: String?
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let detail = json["detail"] as? String {
                errorMessage = detail
            }

            throw APIError.serverError(httpResponse.statusCode, errorMessage)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom(Self.customDateDecoder)
        return try decoder.decode(SimplefinSyncResponse.self, from: data)
    }

    func deleteSimplefinItem(itemId: String) async throws {
        struct DeleteResponse: Codable {
            let success: Bool
            let message: String
        }
        let _: DeleteResponse = try await request(
            endpoint: "/simplefin/items/\(itemId)",
            method: "DELETE"
        )
    }

    func listSimplefinAccounts(itemId: String) async throws -> [SimplefinAccount] {
        return try await request(endpoint: "/simplefin/accounts/\(itemId)")
    }

    // MARK: - Snapshots

    func getSnapshots(
        startDate: Date? = nil,
        endDate: Date? = nil,
        granularity: String = "day"
    ) async throws -> SnapshotsResponse {
        var components = URLComponents(string: Config.apiBaseURL + "/snapshots")
        var queryItems: [URLQueryItem] = []

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        if let startDate = startDate {
            queryItems.append(URLQueryItem(name: "start_date", value: formatter.string(from: startDate)))
        }
        if let endDate = endDate {
            queryItems.append(URLQueryItem(name: "end_date", value: formatter.string(from: endDate)))
        }
        queryItems.append(URLQueryItem(name: "granularity", value: granularity))

        components?.queryItems = queryItems

        guard let url = components?.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if Config.debugMode {
            print("→ GET /snapshots?granularity=\(granularity)")
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        if Config.debugMode {
            print("← \(httpResponse.statusCode) /snapshots")
        }

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 {
                throw APIError.unauthorized
            }

            var errorMessage: String?
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let detail = json["detail"] as? String {
                errorMessage = detail
            }

            throw APIError.serverError(httpResponse.statusCode, errorMessage)
        }

        let decoder = JSONDecoder()
        return try decoder.decode(SnapshotsResponse.self, from: data)
    }

    func calculateSnapshots(
        startDate: Date? = nil,
        endDate: Date? = nil
    ) async throws {
        var components = URLComponents(string: Config.apiBaseURL + "/snapshots/calculate")
        var queryItems: [URLQueryItem] = []

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        if let startDate = startDate {
            queryItems.append(URLQueryItem(name: "start_date", value: formatter.string(from: startDate)))
        }
        if let endDate = endDate {
            queryItems.append(URLQueryItem(name: "end_date", value: formatter.string(from: endDate)))
        }

        if !queryItems.isEmpty {
            components?.queryItems = queryItems
        }

        guard let url = components?.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw APIError.serverError(httpResponse.statusCode, nil)
        }
    }

    func listSimplefinTransactions(
        dateFrom: Int? = nil,
        dateTo: Int? = nil,
        limit: Int = 50,
        offset: Int = 0
    ) async throws -> TransactionListResponse {
        var components = URLComponents(string: Config.apiBaseURL + "/simplefin/transactions")
        var queryItems: [URLQueryItem] = []

        if let dateFrom = dateFrom {
            queryItems.append(URLQueryItem(name: "date_from", value: String(dateFrom)))
        }
        if let dateTo = dateTo {
            queryItems.append(URLQueryItem(name: "date_to", value: String(dateTo)))
        }
        queryItems.append(URLQueryItem(name: "limit", value: String(limit)))
        queryItems.append(URLQueryItem(name: "offset", value: String(offset)))

        components?.queryItems = queryItems

        guard let url = components?.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if Config.debugMode {
            print("→ GET /simplefin/transactions")
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        if Config.debugMode {
            print("← \(httpResponse.statusCode) /simplefin/transactions")
        }

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 {
                throw APIError.unauthorized
            }

            var errorMessage: String?
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let detail = json["detail"] as? String {
                errorMessage = detail
            }

            throw APIError.serverError(httpResponse.statusCode, errorMessage)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom(Self.customDateDecoder)
        return try decoder.decode(TransactionListResponse.self, from: data)
    }

    // MARK: - Account Snapshots (per-account balance history)

    func getAccountSnapshots(
        accountId: String,
        startDate: Date? = nil,
        endDate: Date? = nil,
        granularity: String = "day"
    ) async throws -> SnapshotsResponse {
        var components = URLComponents(string: Config.apiBaseURL + "/snapshots/account/\(accountId)")
        var queryItems: [URLQueryItem] = []

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        if let startDate = startDate {
            queryItems.append(URLQueryItem(name: "start_date", value: formatter.string(from: startDate)))
        }
        if let endDate = endDate {
            queryItems.append(URLQueryItem(name: "end_date", value: formatter.string(from: endDate)))
        }
        queryItems.append(URLQueryItem(name: "granularity", value: granularity))

        components?.queryItems = queryItems

        guard let url = components?.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if Config.debugMode {
            print("→ GET /snapshots/account/\(accountId)?granularity=\(granularity)")
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        if Config.debugMode {
            print("← \(httpResponse.statusCode) /snapshots/account/\(accountId)")
        }

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 {
                throw APIError.unauthorized
            }

            var errorMessage: String?
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let detail = json["detail"] as? String {
                errorMessage = detail
            }

            throw APIError.serverError(httpResponse.statusCode, errorMessage)
        }

        let decoder = JSONDecoder()
        return try decoder.decode(SnapshotsResponse.self, from: data)
    }

    // MARK: - Categories

    func seedDefaultCategories(monthlyBudget: Double, accountIds: [String] = []) async throws -> SeedDefaultsResponse {
        guard let url = URL(string: Config.apiBaseURL + "/categories/seed-defaults") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let body: [String: Any] = [
            "monthly_budget": monthlyBudget,
            "account_ids": accountIds
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        if Config.debugMode {
            print("→ POST /categories/seed-defaults")
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        if Config.debugMode {
            print("← \(httpResponse.statusCode) /categories/seed-defaults")
        }

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 {
                throw APIError.unauthorized
            }

            var errorMessage: String?
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let detail = json["detail"] as? String {
                errorMessage = detail
            }

            throw APIError.serverError(httpResponse.statusCode, errorMessage)
        }

        // DEBUG: Print raw JSON response
        if let jsonString = String(data: data, encoding: .utf8) {
            print("=== RAW JSON RESPONSE ===")
            print(jsonString)
            print("=========================")
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        do {
            return try decoder.decode(SeedDefaultsResponse.self, from: data)
        } catch {
            print("=== DECODING ERROR ===")
            print("Error: \(error)")
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .keyNotFound(let key, let context):
                    print("Key '\(key.stringValue)' not found:", context.debugDescription)
                    print("Context path:", context.codingPath.map { $0.stringValue }.joined(separator: " -> "))
                case .typeMismatch(let type, let context):
                    print("Type '\(type)' mismatch:", context.debugDescription)
                    print("Context path:", context.codingPath.map { $0.stringValue }.joined(separator: " -> "))
                case .valueNotFound(let type, let context):
                    print("Value '\(type)' not found:", context.debugDescription)
                    print("Context path:", context.codingPath.map { $0.stringValue }.joined(separator: " -> "))
                case .dataCorrupted(let context):
                    print("Data corrupted:", context.debugDescription)
                    print("Context path:", context.codingPath.map { $0.stringValue }.joined(separator: " -> "))
                @unknown default:
                    print("Unknown decoding error:", error)
                }
            }
            print("======================")
            throw error
        }
    }

    func fetchCategories() async throws -> [Category] {
        guard let url = URL(string: Config.apiBaseURL + "/categories") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if Config.debugMode {
            print("→ GET /categories")
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        if Config.debugMode {
            print("← \(httpResponse.statusCode) /categories")
        }

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 {
                throw APIError.unauthorized
            }

            var errorMessage: String?
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let detail = json["detail"] as? String {
                errorMessage = detail
            }

            throw APIError.serverError(httpResponse.statusCode, errorMessage)
        }

        let decoder = JSONDecoder()
        let listResponse = try decoder.decode(CategoryListResponse.self, from: data)
        return listResponse.items
    }

    func fetchCategoriesTree() async throws -> [CategoryWithSubcategories] {
        guard let url = URL(string: Config.apiBaseURL + "/categories/tree") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if Config.debugMode {
            print("→ GET /categories/tree")
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        if Config.debugMode {
            print("← \(httpResponse.statusCode) /categories/tree")
        }

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 {
                throw APIError.unauthorized
            }

            var errorMessage: String?
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let detail = json["detail"] as? String {
                errorMessage = detail
            }

            throw APIError.serverError(httpResponse.statusCode, errorMessage)
        }

        let decoder = JSONDecoder()
        let treeResponse = try decoder.decode(CategoriesTreeResponse.self, from: data)
        return treeResponse.items
    }

    func createSubcategory(categoryId: String, name: String, icon: String) async throws -> Subcategory {
        struct CreateBody: Encodable { let name: String; let icon: String }
        return try await request(
            endpoint: "/categories/\(categoryId)/subcategories",
            method: "POST",
            body: CreateBody(name: name, icon: icon)
        )
    }

    func updateCategory(categoryId: String, name: String, icon: String, color: String) async throws -> Category {
        struct UpdateBody: Encodable { let name: String; let icon: String; let color: String }
        return try await request(
            endpoint: "/categories/\(categoryId)",
            method: "PATCH",
            body: UpdateBody(name: name, icon: icon, color: color)
        )
    }

    func deleteCategory(categoryId: String) async throws {
        struct SuccessResponse: Codable { let success: Bool; let message: String }
        let _: SuccessResponse = try await request(
            endpoint: "/categories/\(categoryId)",
            method: "DELETE"
        )
    }

    func categorizeTransaction(
        transactionId: String,
        categoryId: String?,
        subcategoryId: String?,
        createRule: Bool = false
    ) async throws {
        struct ManualCategorizationBody: Encodable {
            let categoryId: String?
            let subcategoryId: String?
            let createRule: Bool
            enum CodingKeys: String, CodingKey {
                case categoryId = "category_id"
                case subcategoryId = "subcategory_id"
                case createRule = "create_rule"
            }
        }
        struct SuccessResponse: Codable { let success: Bool; let message: String }
        let _: SuccessResponse = try await request(
            endpoint: "/categories/transactions/\(transactionId)/categorize",
            method: "PATCH",
            body: ManualCategorizationBody(categoryId: categoryId, subcategoryId: subcategoryId, createRule: createRule)
        )
    }

    func listCategorizationRules() async throws -> [CategorizationRule] {
        let response: CategorizationRuleListResponse = try await request(endpoint: "/categories/rules")
        return response.items
    }

    func createCategorizationRule(matchField: String, matchValue: String, categoryId: String, subcategoryId: String?) async throws -> CategorizationRule {
        struct CreateBody: Encodable {
            let matchField: String
            let matchValue: String
            let categoryId: String
            let subcategoryId: String?
            enum CodingKeys: String, CodingKey {
                case matchField = "match_field"
                case matchValue = "match_value"
                case categoryId = "category_id"
                case subcategoryId = "subcategory_id"
            }
        }
        return try await request(
            endpoint: "/categories/rules",
            method: "POST",
            body: CreateBody(matchField: matchField, matchValue: matchValue, categoryId: categoryId, subcategoryId: subcategoryId)
        )
    }

    func deleteCategorizationRule(ruleId: String) async throws {
        struct SuccessResponse: Codable { let success: Bool; let message: String }
        let _: SuccessResponse = try await request(
            endpoint: "/categories/rules/\(ruleId)",
            method: "DELETE"
        )
    }

    func createCategory(name: String, icon: String, color: String) async throws -> Category {
        guard let url = URL(string: Config.apiBaseURL + "/categories") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let body = [
            "name": name,
            "icon": icon,
            "color": color,
            "display_order": 0
        ] as [String : Any]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        if Config.debugMode {
            print("→ POST /categories")
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        if Config.debugMode {
            print("← \(httpResponse.statusCode) /categories")
        }

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 {
                throw APIError.unauthorized
            }

            var errorMessage: String?
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let detail = json["detail"] as? String {
                errorMessage = detail
            }

            throw APIError.serverError(httpResponse.statusCode, errorMessage)
        }

        let decoder = JSONDecoder()
        return try decoder.decode(Category.self, from: data)
    }

    // MARK: - Budgets

    func getBudgetSummary(month: String) async throws -> BudgetSummary {
        return try await request(endpoint: "/budgets/summary?month=\(month)")
    }

    func fetchBudgets() async throws -> [BudgetAPI] {
        let response: BudgetAPIListResponse = try await request(endpoint: "/budgets")
        return response.items
    }

    func createBudgetLineItem(budgetId: String, categoryId: String, subcategoryId: String?, amount: Double) async throws -> BudgetLineItem {
        struct CreateBody: Encodable {
            let categoryId: String
            let subcategoryId: String?
            let amount: Double
            enum CodingKeys: String, CodingKey {
                case categoryId = "category_id"
                case subcategoryId = "subcategory_id"
                case amount
            }
        }
        return try await request(
            endpoint: "/budgets/\(budgetId)/line-items",
            method: "POST",
            body: CreateBody(categoryId: categoryId, subcategoryId: subcategoryId, amount: amount)
        )
    }

    func updateBudgetLineItem(budgetId: String, lineItemId: String, amount: Double) async throws -> BudgetLineItem {
        struct UpdateBody: Encodable { let amount: Double }
        return try await request(
            endpoint: "/budgets/\(budgetId)/line-items/\(lineItemId)",
            method: "PATCH",
            body: UpdateBody(amount: amount)
        )
    }

    func deleteBudgetLineItem(budgetId: String, lineItemId: String) async throws {
        struct SuccessResponse: Codable { let success: Bool; let message: String }
        let _: SuccessResponse = try await request(
            endpoint: "/budgets/\(budgetId)/line-items/\(lineItemId)",
            method: "DELETE"
        )
    }

    func createBudget(name: String, isDefault: Bool) async throws -> BudgetAPI {
        struct CreateBody: Encodable {
            let name: String
            let isDefault: Bool
            let accountIds: [String]
            enum CodingKeys: String, CodingKey {
                case name
                case isDefault = "is_default"
                case accountIds = "account_ids"
            }
        }
        return try await request(
            endpoint: "/budgets",
            method: "POST",
            body: CreateBody(name: name, isDefault: isDefault, accountIds: [])
        )
    }

    func updateBudget(budgetId: String, name: String? = nil, isDefault: Bool? = nil) async throws -> BudgetAPI {
        struct UpdateBody: Encodable {
            let name: String?
            let isDefault: Bool?
            enum CodingKeys: String, CodingKey {
                case name
                case isDefault = "is_default"
            }
        }
        return try await request(
            endpoint: "/budgets/\(budgetId)",
            method: "PATCH",
            body: UpdateBody(name: name, isDefault: isDefault)
        )
    }

    func deleteBudget(budgetId: String) async throws {
        struct SuccessResponse: Codable { let success: Bool; let message: String }
        let _: SuccessResponse = try await request(
            endpoint: "/budgets/\(budgetId)",
            method: "DELETE"
        )
    }

    // MARK: - Transaction Categorization

    func batchUpdateTransactions(_ updates: [(transactionId: String, categoryId: String?, subcategoryId: String?)]) async throws -> BatchUpdateResponse {
        guard let url = URL(string: Config.apiBaseURL + "/transactions/batch/categorize") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let updatesArray = updates.map { update in
            [
                "transaction_id": update.transactionId,
                "category_id": update.categoryId as Any,
                "subcategory_id": update.subcategoryId as Any
            ]
        }

        let body = ["updates": updatesArray]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        if Config.debugMode {
            print("→ PATCH /transactions/batch/categorize (\(updates.count) transactions)")
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        if Config.debugMode {
            print("← \(httpResponse.statusCode) /transactions/batch/categorize")
        }

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 {
                throw APIError.unauthorized
            }

            var errorMessage: String?
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let detail = json["detail"] as? String {
                errorMessage = detail
            }

            throw APIError.serverError(httpResponse.statusCode, errorMessage)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(BatchUpdateResponse.self, from: data)
    }

    func categorizeWithAI(transactionIds: [String]? = nil, force: Bool = false) async throws -> AICategorizationResponse {
        guard let url = URL(string: Config.apiBaseURL + "/categories/ai/categorize") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        var body: [String: Any] = ["force": force]
        if let transactionIds = transactionIds {
            body["transaction_ids"] = transactionIds
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        if Config.debugMode {
            print("→ POST /categories/ai/categorize")
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        if Config.debugMode {
            print("← \(httpResponse.statusCode) /categories/ai/categorize")
        }

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 {
                throw APIError.unauthorized
            }

            var errorMessage: String?
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let detail = json["detail"] as? String {
                errorMessage = detail
            }

            throw APIError.serverError(httpResponse.statusCode, errorMessage)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(AICategorizationResponse.self, from: data)
    }
}

// MARK: - Transaction Categorization Response Models

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

// MARK: - Goals API extension (defined at end of file for clarity)
extension APIClient {

    // MARK: Goals

    func fetchGoals() async throws -> [Goal] {
        let response: GoalListResponse = try await request(endpoint: "/goals")
        return response.items
    }

    func createGoal(
        name: String,
        description: String?,
        goalType: GoalType,
        targetAmount: Double,
        targetDate: String?,
        accounts: [GoalAccountRequest]
    ) async throws -> Goal {
        let body = GoalCreate(
            name: name,
            description: description,
            goalType: goalType,
            targetAmount: targetAmount,
            targetDate: targetDate,
            accounts: accounts
        )
        return try await request(endpoint: "/goals", method: "POST", body: body)
    }

    func fetchGoalDetail(
        goalId: String,
        startDate: Date? = nil,
        endDate: Date? = nil,
        granularity: String = "day"
    ) async throws -> GoalDetail {
        var components = URLComponents(string: Config.apiBaseURL + "/goals/\(goalId)")
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "granularity", value: granularity)
        ]
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        if let startDate = startDate {
            queryItems.append(URLQueryItem(name: "start_date", value: formatter.string(from: startDate)))
        }
        if let endDate = endDate {
            queryItems.append(URLQueryItem(name: "end_date", value: formatter.string(from: endDate)))
        }
        components?.queryItems = queryItems

        guard let url = components?.url else { throw APIError.invalidURL }

        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = accessToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard http.statusCode == 200 else {
            if http.statusCode == 401 { throw APIError.unauthorized }
            var msg: String?
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let detail = json["detail"] as? String { msg = detail }
            throw APIError.serverError(http.statusCode, msg)
        }
        let decoder = JSONDecoder()
        return try decoder.decode(GoalDetail.self, from: data)
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
        let body = GoalUpdate(
            name: name,
            description: description,
            targetAmount: targetAmount,
            targetDate: targetDate,
            isCompleted: isCompleted,
            accounts: accounts
        )
        return try await request(endpoint: "/goals/\(goalId)", method: "PUT", body: body)
    }

    func deleteGoal(goalId: String) async throws {
        struct DeleteResponse: Codable { let success: Bool; let message: String }
        let _: DeleteResponse = try await request(endpoint: "/goals/\(goalId)", method: "DELETE")
    }
}
