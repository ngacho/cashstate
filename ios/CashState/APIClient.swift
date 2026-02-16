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

        guard httpResponse.statusCode == 200 else {
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
        decoder.dateDecodingStrategy = .iso8601
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
        decoder.dateDecodingStrategy = .iso8601
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
    ) async throws -> [Transaction] {
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
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([Transaction].self, from: data)
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

    func seedDefaultCategories(monthlyBudget: Double) async throws -> SeedDefaultsResponse {
        guard let url = URL(string: Config.apiBaseURL + "/categories/seed-defaults") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let body = ["monthly_budget": monthlyBudget]
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

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(SeedDefaultsResponse.self, from: data)
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

    func fetchBudgets(categoryId: String? = nil) async throws -> [BudgetItem] {
        var urlString = Config.apiBaseURL + "/budgets"
        if let categoryId = categoryId {
            urlString += "?category_id=\(categoryId)"
        }

        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if Config.debugMode {
            print("→ GET /budgets")
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        if Config.debugMode {
            print("← \(httpResponse.statusCode) /budgets")
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
        let listResponse = try decoder.decode(BudgetListResponse.self, from: data)
        return listResponse.items
    }

    func createBudget(categoryId: String, amount: Double, period: String = "monthly") async throws -> BudgetItem {
        guard let url = URL(string: Config.apiBaseURL + "/budgets") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let body = [
            "category_id": categoryId,
            "amount": amount,
            "period": period
        ] as [String : Any]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        if Config.debugMode {
            print("→ POST /budgets")
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        if Config.debugMode {
            print("← \(httpResponse.statusCode) /budgets")
        }

        guard httpResponse.statusCode == 201 else {
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
        return try decoder.decode(BudgetItem.self, from: data)
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
