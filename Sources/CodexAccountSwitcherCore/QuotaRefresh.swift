import Foundation

public final class QuotaSnapshotStore {
    private let files: SecureFileStore

    public init(files: SecureFileStore) {
        self.files = files
    }

    public func cacheURL(snapshotID: UUID) -> URL {
        files.quotaDirectory.appendingPathComponent("\(snapshotID.uuidString).quota.json")
    }

    public func load(snapshotID: UUID) -> QuotaSnapshot? {
        let url = cacheURL(snapshotID: snapshotID)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONCoding.decoder.decode(QuotaSnapshot.self, from: data)
    }

    public func save(_ snapshot: QuotaSnapshot) throws {
        try files.atomicWrite(JSONCoding.encoder.encode(snapshot), to: cacheURL(snapshotID: snapshot.snapshotID))
    }

    public func remove(snapshotID: UUID) throws {
        let url = cacheURL(snapshotID: snapshotID)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }
}

public actor QuotaRefresher {
    private let snapshotStore: SnapshotStore
    private let quotaStore: QuotaSnapshotStore
    private let client: OAuthClient

    public init(snapshotStore: SnapshotStore, client: OAuthClient = OAuthClient()) {
        self.snapshotStore = snapshotStore
        self.quotaStore = QuotaSnapshotStore(files: snapshotStore.files)
        self.client = client
    }

    public func cachedQuota(for snapshot: AccountSnapshot) -> QuotaSnapshot? {
        quotaStore.load(snapshotID: snapshot.id)
    }

    @discardableResult
    public func refresh(snapshot: AccountSnapshot) async -> QuotaSnapshot {
        do {
            let original = try snapshotStore.loadAuth(for: snapshot)
            var refreshed = try await client.refreshIfNeeded(auth: original)
            try updateSnapshotIfNeeded(snapshot, original: original, refreshed: refreshed)
            let usage: UsageResponse
            do {
                usage = try await client.fetchUsage(credentials: refreshed.tokens)
            } catch OAuthError.httpStatus(401) {
                let stale = refreshed
                refreshed = try await client.refresh(auth: refreshed)
                try updateSnapshotIfNeeded(snapshot, original: stale, refreshed: refreshed)
                usage = try await client.fetchUsage(credentials: refreshed.tokens)
            }
            let quota = QuotaSnapshot(snapshotID: snapshot.id, usage: usage)
            try quotaStore.save(quota)
            return quota
        } catch {
            let message = Redaction.redact(error.localizedDescription)
            if var lastGood = quotaStore.load(snapshotID: snapshot.id) {
                lastGood.error = message
                try? quotaStore.save(lastGood)
                return lastGood
            }
            let failed = QuotaSnapshot(snapshotID: snapshot.id, usage: UsageResponse(planType: nil, rateLimit: nil, credits: nil), error: message)
            try? quotaStore.save(failed)
            return failed
        }
    }

    private func updateSnapshotIfNeeded(_ snapshot: AccountSnapshot, original: ActiveAuth, refreshed: ActiveAuth) throws {
        if refreshed != original {
            try snapshotStore.updateSnapshotAuth(snapshot, auth: refreshed)
        }
    }
}

public enum Redaction {
    public static func redact(_ value: String) -> String {
        value
            .replacingOccurrences(of: #"Bearer\s+[A-Za-z0-9._~-]+"#, with: "Bearer [redacted]", options: .regularExpression)
            .replacingOccurrences(of: #"rt_[A-Za-z0-9._~-]+"#, with: "[redacted-refresh-token]", options: .regularExpression)
            .replacingOccurrences(of: #"eyJ[A-Za-z0-9._~-]+"#, with: "[redacted-jwt]", options: .regularExpression)
    }
}
