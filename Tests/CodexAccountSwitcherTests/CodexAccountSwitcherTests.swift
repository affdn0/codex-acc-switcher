import Foundation
import Testing
@testable import CodexAccountSwitcherCore

@Test func parsesActiveAuthOAuthCredentials() throws {
    let auth = try JSONCoding.decoder.decode(ActiveAuth.self, from: sampleAuth(access: "access", refresh: "refresh"))
    #expect(auth.tokens.accessToken == "access")
    #expect(auth.tokens.refreshToken == "refresh")
    #expect(auth.tokens.idToken == "id")
    #expect(auth.tokens.accountID == "acct")
    #expect(auth.lastRefresh != nil)
}

@Test func derivesSnapshotIdentifierFromJwtEmail() throws {
    let auth = try JSONCoding.decoder.decode(ActiveAuth.self, from: sampleAuth(access: "access", refresh: "refresh", email: "you@example.com"))
    #expect(auth.snapshotIdentifier == "you@example.com")
}

@Test func decodesUsageResponseWindowsAndCredits() throws {
    let data = """
    {
      "plan_type": "pro",
      "rate_limit": {
        "primary_window": { "used_percent": 20, "reset_at": 1779703200, "limit_window_seconds": 18000 },
        "secondary_window": { "remaining_percent": "55.5", "resets_in_seconds": 3600 }
      },
      "credits": { "balance": "12", "has_credits": true, "unlimited": false }
    }
    """.data(using: .utf8)!
    let usage = try JSONCoding.decoder.decode(UsageResponse.self, from: data)
    #expect(usage.planType == "pro")
    #expect(usage.rateLimit?.primaryWindow?.usedPercent == 20)
    #expect(usage.rateLimit?.primaryWindow?.resetAt == Date(timeIntervalSince1970: 1_779_703_200))
    #expect(usage.rateLimit?.primaryWindow?.limitWindowSeconds == 18_000)
    #expect(usage.rateLimit?.secondaryWindow?.remainingPercent == 55.5)
    #expect(usage.credits?.balance == 12)
    #expect(usage.credits?.hasCredits == true)
}

@Test func tokenRefreshUpdatesSnapshotWithStrictPermissions() async throws {
    let temp = try temporaryDirectory()
    let active = temp.appendingPathComponent("auth.json")
    let store = SnapshotStore(appSupportURL: temp.appendingPathComponent("support"), activeAuthURL: active)
    let snapshot = try store.saveSnapshot(label: "A", authData: sampleAuth(access: "old", refresh: "refresh", lastRefresh: Date(timeIntervalSince1970: 0)))
    final class RequestBox: @unchecked Sendable {
        var requests: [URLRequest] = []
        func append(_ request: URLRequest) { requests.append(request) }
    }
    let box = RequestBox()
    let client = OAuthClient(transport: MockTransport { request in
        box.append(request)
        if request.url!.absoluteString.contains("/oauth/token") {
            return (Data(#"{"access_token":"new","refresh_token":"next","id_token":"new-id","account_id":"acct"}"#.utf8), http(request.url!, 200))
        }
        return (Data(#"{"plan_type":"pro","rate_limit":{"primary_window":{"used_percent":1},"secondary_window":{"remaining_percent":99}}}"#.utf8), http(request.url!, 200))
    })
    let refresher = QuotaRefresher(snapshotStore: store, client: client)
    _ = await refresher.refresh(snapshot: snapshot)
    let auth = try store.loadAuth(for: snapshot)
    #expect(auth.tokens.accessToken == "new")
    #expect(try store.files.permissions(at: store.authURL(for: snapshot)) == 0o600)
    let refreshRequest = try #require(box.requests.first { $0.url?.absoluteString.contains("/oauth/token") == true })
    #expect(refreshRequest.value(forHTTPHeaderField: "Content-Type") == "application/json")
    let body = try #require(refreshRequest.httpBody)
    let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: String])
    #expect(json["client_id"] == "app_EMoamEEZ73f0CkXaXp7hrann")
    #expect(json["grant_type"] == "refresh_token")
    #expect(json["refresh_token"] == "refresh")
    #expect(json["scope"] == "openid profile email")
    let usageRequest = try #require(box.requests.first { $0.url?.absoluteString.contains("/wham/usage") == true })
    #expect(usageRequest.value(forHTTPHeaderField: "Authorization") == "Bearer new")
    #expect(usageRequest.value(forHTTPHeaderField: "Accept") == "application/json")
    #expect(usageRequest.value(forHTTPHeaderField: "ChatGPT-Account-Id") == "acct")
}

@Test func quotaRefreshForcesTokenRefreshAfterUnauthorizedUsage() async throws {
    let temp = try temporaryDirectory()
    let active = temp.appendingPathComponent("auth.json")
    let store = SnapshotStore(appSupportURL: temp.appendingPathComponent("support"), activeAuthURL: active)
    let snapshot = try store.saveSnapshot(label: "A", authData: sampleAuth(access: "expired", refresh: "refresh", lastRefresh: Date()))
    final class RequestBox: @unchecked Sendable {
        var requests: [URLRequest] = []
        func append(_ request: URLRequest) { requests.append(request) }
    }
    let box = RequestBox()
    let client = OAuthClient(transport: MockTransport { request in
        box.append(request)
        if request.url!.absoluteString.contains("/oauth/token") {
            return (Data(#"{"access_token":"new","refresh_token":"next","id_token":"new-id","account_id":"acct"}"#.utf8), http(request.url!, 200))
        }
        if request.value(forHTTPHeaderField: "Authorization") == "Bearer expired" {
            return (Data(#"{"error":"expired"}"#.utf8), http(request.url!, 401))
        }
        return (Data(#"{"plan_type":"pro","rate_limit":{"primary_window":{"used_percent":3},"secondary_window":{"remaining_percent":97}}}"#.utf8), http(request.url!, 200))
    })
    let refresher = QuotaRefresher(snapshotStore: store, client: client)
    let quota = await refresher.refresh(snapshot: snapshot)
    let auth = try store.loadAuth(for: snapshot)
    #expect(auth.tokens.accessToken == "new")
    #expect(quota.error == nil)
    #expect(box.requests.filter { $0.url?.absoluteString.contains("/wham/usage") == true }.count == 2)
    #expect(box.requests.filter { $0.url?.absoluteString.contains("/oauth/token") == true }.count == 1)
}

@Test func freshCredentialsSkipRefreshAndFetchUsageDirectly() async throws {
    let temp = try temporaryDirectory()
    let active = temp.appendingPathComponent("auth.json")
    let store = SnapshotStore(appSupportURL: temp.appendingPathComponent("support"), activeAuthURL: active)
    let snapshot = try store.saveSnapshot(label: "A", authData: sampleAuth(access: "fresh", refresh: "refresh", lastRefresh: Date()))
    final class RequestBox: @unchecked Sendable {
        var requests: [URLRequest] = []
        func append(_ request: URLRequest) { requests.append(request) }
    }
    let box = RequestBox()
    let client = OAuthClient(transport: MockTransport { request in
        box.append(request)
        return (Data(#"{"plan_type":"pro","rate_limit":{"primary_window":{"used_percent":2},"secondary_window":{"remaining_percent":98}}}"#.utf8), http(request.url!, 200))
    })
    let refresher = QuotaRefresher(snapshotStore: store, client: client)
    _ = await refresher.refresh(snapshot: snapshot)
    #expect(!box.requests.contains { $0.url?.absoluteString.contains("/oauth/token") == true })
    #expect(box.requests.contains { $0.url?.absoluteString.contains("/wham/usage") == true })
}

@Test func snapshotAndCacheFilesUseStrictPermissions() throws {
    let temp = try temporaryDirectory()
    let active = temp.appendingPathComponent("auth.json")
    let store = SnapshotStore(appSupportURL: temp.appendingPathComponent("support"), activeAuthURL: active)
    let snapshot = try store.saveSnapshot(label: "A", authData: sampleAuth(access: "access", refresh: "refresh"))
    let quotaStore = QuotaSnapshotStore(files: store.files)
    try quotaStore.save(QuotaSnapshot(snapshotID: snapshot.id, usage: UsageResponse(planType: "pro", rateLimit: nil, credits: nil)))
    #expect(try store.files.permissions(at: store.authURL(for: snapshot)) == 0o600)
    #expect(try store.files.permissions(at: quotaStore.cacheURL(snapshotID: snapshot.id)) == 0o600)
    #expect(try store.files.permissions(at: store.files.root) == 0o700)
    let cache = try String(contentsOf: quotaStore.cacheURL(snapshotID: snapshot.id), encoding: .utf8)
    #expect(!cache.contains("access"))
    #expect(!cache.contains("refresh"))
    #expect(!cache.contains("Bearer"))
}

@Test func savingSameAccountUpdatesExistingSnapshot() throws {
    let temp = try temporaryDirectory()
    let active = temp.appendingPathComponent("auth.json")
    let store = SnapshotStore(appSupportURL: temp.appendingPathComponent("support"), activeAuthURL: active)
    let first = try store.saveSnapshot(label: "Custom", authData: sampleAuth(access: "old", refresh: "refresh", email: "codex@example.com"))
    let second = try store.saveSnapshot(authData: sampleAuth(access: "new", refresh: "next", email: "CODEX@example.com"))
    let index = try store.loadIndex()
    let auth = try store.loadAuth(for: second)
    #expect(first.id == second.id)
    #expect(index.snapshots.count == 1)
    #expect(index.snapshots[0].label == "Custom")
    #expect(auth.tokens.accessToken == "new")
    #expect(auth.tokens.refreshToken == "next")
}

@Test func duplicateSnapshotsAreRemovedByAccountIdentity() throws {
    let temp = try temporaryDirectory()
    let active = temp.appendingPathComponent("auth.json")
    let store = SnapshotStore(appSupportURL: temp.appendingPathComponent("support"), activeAuthURL: active)
    let old = AccountSnapshot(label: "Old", createdAt: Date(timeIntervalSince1970: 1), updatedAt: Date(timeIntervalSince1970: 1))
    let new = AccountSnapshot(label: "New", createdAt: Date(timeIntervalSince1970: 2), updatedAt: Date(timeIntervalSince1970: 2))
    try store.files.atomicWrite(sampleAuth(access: "old", refresh: "refresh", email: "codex@example.com"), to: store.authURL(for: old))
    try store.files.atomicWrite(sampleAuth(access: "new", refresh: "next", email: "codex@example.com"), to: store.authURL(for: new))
    try store.saveIndex(SnapshotIndex(snapshots: [old, new]))
    try store.removeDuplicateSnapshots()
    let index = try store.loadIndex()
    #expect(index.snapshots.map(\.id) == [new.id])
}

@Test func importedSnapshotUsesJwtEmailAsLabel() throws {
    let temp = try temporaryDirectory()
    let active = temp.appendingPathComponent("auth.json")
    try sampleAuth(access: "access", refresh: "refresh", email: "codex@example.com").write(to: active)
    let store = SnapshotStore(appSupportURL: temp.appendingPathComponent("support"), activeAuthURL: active)
    let snapshot = try store.importActiveAuth()
    #expect(snapshot.label == "codex@example.com")
}

@Test func switchActiveAuthAtomicallyReplacesGlobalAuth() throws {
    let temp = try temporaryDirectory()
    let active = temp.appendingPathComponent("auth.json")
    try Data("old".utf8).write(to: active)
    let store = SnapshotStore(appSupportURL: temp.appendingPathComponent("support"), activeAuthURL: active)
    let snapshot = try store.saveSnapshot(label: "B", authData: sampleAuth(access: "new-active", refresh: "refresh"))
    try store.switchActiveAuth(to: snapshot)
    let auth = try JSONCoding.decoder.decode(ActiveAuth.self, from: Data(contentsOf: active))
    #expect(auth.tokens.accessToken == "new-active")
    #expect(try store.files.permissions(at: active) == 0o600)
}

private func sampleAuth(access: String, refresh: String, lastRefresh: Date? = nil, email: String? = nil) -> Data {
    let lastRefreshValue: String
    if let lastRefresh {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        lastRefreshValue = formatter.string(from: lastRefresh)
    } else {
        lastRefreshValue = "2026-05-01T07:50:05.441616Z"
    }
    let idToken = email.map(makeJWT(email:)) ?? "id"
    return Data("""
    {
      "auth_mode": "chatgpt",
      "OPENAI_API_KEY": null,
      "tokens": {
        "access_token": "\(access)",
        "refresh_token": "\(refresh)",
        "id_token": "\(idToken)",
        "account_id": "acct"
      },
      "last_refresh": "\(lastRefreshValue)"
    }
    """.utf8)
}

private func makeJWT(email: String) -> String {
    let header = #"{"alg":"none"}"#.data(using: .utf8)!.base64URLEncodedString()
    let payload = #"{"email":"\#(email)","name":"Codex User"}"#.data(using: .utf8)!.base64URLEncodedString()
    return "\(header).\(payload)."
}

private extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

private func temporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func http(_ url: URL, _ status: Int) -> HTTPURLResponse {
    HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)!
}

private struct MockTransport: HTTPTransport {
    var handler: @Sendable (URLRequest) throws -> (Data, HTTPURLResponse)

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        try handler(request)
    }
}
