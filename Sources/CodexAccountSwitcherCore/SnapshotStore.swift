import Foundation

public final class SnapshotStore {
    public let files: SecureFileStore
    private let activeAuthURL: URL
    private var indexURL: URL { files.root.appendingPathComponent("snapshots.json") }

    public init(appSupportURL: URL, activeAuthURL: URL) {
        self.files = SecureFileStore(root: appSupportURL)
        self.activeAuthURL = activeAuthURL
    }

    public func loadIndex() throws -> SnapshotIndex {
        try files.preparePrivateDirectories()
        guard FileManager.default.fileExists(atPath: indexURL.path) else { return SnapshotIndex() }
        return try JSONCoding.decoder.decode(SnapshotIndex.self, from: Data(contentsOf: indexURL))
    }

    public func saveIndex(_ index: SnapshotIndex) throws {
        try files.atomicWrite(JSONCoding.encoder.encode(index), to: indexURL)
    }

    public func authURL(for snapshot: AccountSnapshot) -> URL {
        files.snapshotsDirectory.appendingPathComponent(snapshot.authFileName)
    }

    public func saveSnapshot(label: String? = nil, authData: Data) throws -> AccountSnapshot {
        let auth = try JSONCoding.decoder.decode(ActiveAuth.self, from: authData)
        guard !auth.tokens.accessToken.isEmpty, !auth.tokens.refreshToken.isEmpty else {
            throw SnapshotStoreError.missingOAuthCredentials
        }
        var index = try loadIndex()
        let snapshot = AccountSnapshot(label: label ?? suggestedLabel(for: auth))
        try files.atomicWrite(authData, to: authURL(for: snapshot))
        index.snapshots.append(snapshot)
        try saveIndex(index)
        return snapshot
    }

    public func updateSnapshotAuth(_ snapshot: AccountSnapshot, auth: ActiveAuth) throws {
        try files.atomicWrite(JSONCoding.encoder.encode(auth), to: authURL(for: snapshot))
        var index = try loadIndex()
        if let offset = index.snapshots.firstIndex(where: { $0.id == snapshot.id }) {
            index.snapshots[offset].updatedAt = Date()
            try saveIndex(index)
        }
    }

    public func loadAuth(for snapshot: AccountSnapshot) throws -> ActiveAuth {
        try JSONCoding.decoder.decode(ActiveAuth.self, from: Data(contentsOf: authURL(for: snapshot)))
    }

    public func switchActiveAuth(to snapshot: AccountSnapshot) throws {
        let data = try Data(contentsOf: authURL(for: snapshot))
        _ = try JSONCoding.decoder.decode(ActiveAuth.self, from: data)
        try files.atomicWrite(data, to: activeAuthURL)
    }

    public func importActiveAuth(label: String? = nil) throws -> AccountSnapshot {
        try saveSnapshot(label: label, authData: Data(contentsOf: activeAuthURL))
    }

    private func suggestedLabel(for auth: ActiveAuth) -> String {
        if let identifier = auth.snapshotIdentifier {
            return identifier
        }
        return "Codex \(Date().formatted(date: .abbreviated, time: .shortened))"
    }
}

extension SnapshotStore: @unchecked Sendable {}

public enum SnapshotStoreError: Error, LocalizedError {
    case missingOAuthCredentials

    public var errorDescription: String? {
        switch self {
        case .missingOAuthCredentials:
            "Active Auth does not contain Codex OAuth credentials."
        }
    }
}
