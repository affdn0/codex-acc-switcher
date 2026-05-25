import Foundation

public protocol HTTPTransport: Sendable {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

public struct URLSessionTransport: HTTPTransport {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw OAuthError.invalidResponse }
        return (data, http)
    }
}

public final class OAuthClient {
    private let transport: HTTPTransport
    private let tokenURL = URL(string: "https://auth.openai.com/oauth/token")!
    private let usageURL = URL(string: "https://chatgpt.com/backend-api/wham/usage")!
    private let codexClientID = "app_EMoamEEZ73f0CkXaXp7hrann"

    public init(transport: HTTPTransport = URLSessionTransport()) {
        self.transport = transport
    }

    public func refreshIfNeeded(auth: ActiveAuth, now: Date = Date()) async throws -> ActiveAuth {
        let eightDays: TimeInterval = 8 * 24 * 60 * 60
        if let lastRefresh = auth.lastRefresh, now.timeIntervalSince(lastRefresh) <= eightDays {
            return auth
        }

        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "client_id": codexClientID,
            "grant_type": "refresh_token",
            "refresh_token": auth.tokens.refreshToken,
            "scope": "openid profile email",
        ])

        let (data, response) = try await transport.data(for: request)
        guard (200..<300).contains(response.statusCode) else { throw OAuthError.httpStatus(response.statusCode) }
        let refreshed = try JSONDecoder().decode(TokenRefreshResponse.self, from: data)
        var next = auth
        next.tokens.accessToken = refreshed.accessToken
        next.tokens.refreshToken = refreshed.refreshToken ?? auth.tokens.refreshToken
        next.tokens.idToken = refreshed.idToken ?? auth.tokens.idToken
        next.tokens.accountID = refreshed.accountID ?? auth.tokens.accountID
        next.lastRefresh = now
        return next
    }

    public func fetchUsage(credentials: OAuthCredentials) async throws -> UsageResponse {
        var request = URLRequest(url: usageURL)
        request.httpMethod = "GET"
        request.timeoutInterval = 30
        request.setValue("Bearer \(credentials.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let accountID = credentials.accountID {
            request.setValue(accountID, forHTTPHeaderField: "ChatGPT-Account-Id")
        }
        let (data, response) = try await transport.data(for: request)
        guard (200..<300).contains(response.statusCode) else { throw OAuthError.httpStatus(response.statusCode) }
        return try JSONCoding.decoder.decode(UsageResponse.self, from: data)
    }

}

extension OAuthClient: @unchecked Sendable {}

public enum OAuthError: Error, LocalizedError {
    case invalidResponse
    case httpStatus(Int)

    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "The server returned a non-HTTP response."
        case .httpStatus(let status):
            "OpenAI API returned HTTP \(status)."
        }
    }
}

struct TokenRefreshResponse: Decodable, Sendable {
    var accessToken: String
    var refreshToken: String?
    var idToken: String?
    var accountID: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case idToken = "id_token"
        case accountID = "account_id"
    }
}
