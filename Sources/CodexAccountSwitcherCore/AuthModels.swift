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

    public var snapshotIdentifier: String? {
        if let email = tokens.claimString("email") {
            return email
        }
        if let name = tokens.claimString("name") {
            return name
        }
        if let accountID = tokens.accountID, !accountID.isEmpty {
            return accountID
        }
        return nil
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

    func claimString(_ key: String) -> String? {
        for token in [idToken, accessToken].compactMap(\.self) {
            if let value = Self.jwtClaimString(key, token: token) {
                return value
            }
        }
        return nil
    }

    private static func jwtClaimString(_ key: String, token: String) -> String? {
        let parts = token.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        var payload = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let padding = payload.count % 4
        if padding > 0 {
            payload += String(repeating: "=", count: 4 - padding)
        }
        guard
            let data = Data(base64Encoded: payload),
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let value = object[key] as? String,
            !value.isEmpty
        else {
            return nil
        }
        return value
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
