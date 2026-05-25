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

@Test func decodesUsageResponseWindowsAndCredits() throws {
    let data = """
    {
      "plan_type": "pro",
      "rate_limit": {
        "primary_window": { "used_percent": 20, "reset_at": "2026-05-25T10:00:00Z" },
        "secondary_window": { "remaining_percent": "55.5", "resets_in_seconds": 3600 }
      },
      "credits": { "remaining": 12, "used": 3, "granted": 15 }
    }
    """.data(using: .utf8)!
    let usage = try JSONCoding.decoder.decode(UsageResponse.self, from: data)
    #expect(usage.planType == "pro")
    #expect(usage.rateLimit?.primaryWindow?.usedPercent == 20)
    #expect(usage.rateLimit?.secondaryWindow?.remainingPercent == 55.5)
    #expect(usage.credits?.remaining == 12)
}

@Test func tokenRefreshUpdatesSnapshotWithStrictPermissions() async throws {
    let temp = try temporaryDirectory()
    let active = temp.appendingPathComponent("auth.json")
    let store = SnapshotStore(appSupportURL: temp.appendingPathComponent("support"), activeAuthURL: active)
    let snapshot = try store.saveSnapshot(label: "A", authData: sampleAuth(access: "old", refresh: "refresh"))
    let client = OAuthClient(transport: MockTransport { request in
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

private func sampleAuth(access: String, refresh: String) -> Data {
    Data("""
    {
      "auth_mode": "chatgpt",
      "OPENAI_API_KEY": null,
      "tokens": {
        "access_token": "\(access)",
        "refresh_token": "\(refresh)",
        "id_token": "id",
        "account_id": "acct"
      },
      "last_refresh": "2026-05-25T07:50:05.441616Z"
    }
    """.utf8)
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
