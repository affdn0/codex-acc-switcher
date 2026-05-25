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
        if let offset = matchingSnapshotOffset(in: index, auth: auth) {
            var snapshot = index.snapshots[offset]
            if let label {
                snapshot.label = label
            } else if isGeneratedLabel(snapshot.label) {
                snapshot.label = suggestedLabel(for: auth)
            }
            snapshot.updatedAt = Date()
            try files.atomicWrite(authData, to: authURL(for: snapshot))
            index.snapshots[offset] = snapshot
            try saveIndex(index)
            return snapshot
        }
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
            if auth.snapshotIdentifier != nil, isGeneratedLabel(index.snapshots[offset].label) {
                index.snapshots[offset].label = suggestedLabel(for: auth)
            }
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

    public func removeDuplicateSnapshots() throws {
        var index = try loadIndex()
        var seen: [(snapshot: AccountSnapshot, auth: ActiveAuth)] = []
        var keptIDs = Set<UUID>()

        for snapshot in index.snapshots.sorted(by: { $0.updatedAt > $1.updatedAt }) {
            guard let auth = try? loadAuth(for: snapshot) else {
                keptIDs.insert(snapshot.id)
                continue
            }
            if seen.contains(where: { auth.belongsToSameAccount(as: $0.auth) }) {
                continue
            }
            seen.append((snapshot, auth))
            keptIDs.insert(snapshot.id)
        }

        let deduplicated = index.snapshots.filter { keptIDs.contains($0.id) }
        guard deduplicated.count != index.snapshots.count else { return }
        index.snapshots = deduplicated
        try saveIndex(index)
    }

    private func suggestedLabel(for auth: ActiveAuth) -> String {
        if let identifier = auth.snapshotIdentifier {
            return identifier
        }
        return "Codex \(Date().formatted(date: .abbreviated, time: .shortened))"
    }

    private func isGeneratedLabel(_ label: String) -> Bool {
        label.hasPrefix("Codex ") || label.hasPrefix("Imported ")
    }

    private func matchingSnapshotOffset(in index: SnapshotIndex, auth: ActiveAuth) -> Int? {
        index.snapshots.firstIndex { snapshot in
            guard let existing = try? loadAuth(for: snapshot) else { return false }
            return auth.belongsToSameAccount(as: existing)
        }
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
