import Foundation

public struct ActiveAuth: Codable, Equatable, Sendable {
    public var authMode: String?
    public var openAIAPIKey: String?
    public var tokens: OAuthCredentials
    public var lastRefresh: Date?

    enum CodingKeys: String, CodingKey {
        case authMode = "auth_mode"
        case openAIAPIKey = "OPENAI_API_KEY"
        case tokens
        case lastRefresh = "last_refresh"
    }
}

public struct OAuthCredentials: Codable, Equatable, Sendable {
    public var accessToken: String
    public var refreshToken: String
    public var idToken: String?
    public var accountID: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case idToken = "id_token"
        case accountID = "account_id"
    }
}

public struct AccountSnapshot: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var label: String
    public var createdAt: Date
    public var updatedAt: Date
    public var authFileName: String

    public init(id: UUID = UUID(), label: String, createdAt: Date = Date(), updatedAt: Date = Date(), authFileName: String? = nil) {
        self.id = id
        self.label = label
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.authFileName = authFileName ?? "\(id.uuidString).auth.json"
    }
}

public struct SnapshotIndex: Codable, Equatable, Sendable {
    public var snapshots: [AccountSnapshot]

    public init(snapshots: [AccountSnapshot] = []) {
        self.snapshots = snapshots
    }
}
