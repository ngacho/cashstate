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
}
