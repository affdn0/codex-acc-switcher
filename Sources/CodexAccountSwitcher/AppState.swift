import CodexAccountSwitcherCore
import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var snapshots: [AccountSnapshot] = []
    @Published var quotas: [UUID: QuotaSnapshot] = [:]
    @Published var status: String?
    @Published var isRefreshing = false

    private let store: SnapshotStore
    private let refresher: QuotaRefresher
    private let loginRunner = CodexLoginRunner()

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Codex Account Switcher", isDirectory: true)
        let active = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex", isDirectory: true)
            .appendingPathComponent("auth.json")
        store = SnapshotStore(appSupportURL: support, activeAuthURL: active)
        refresher = QuotaRefresher(snapshotStore: store)
        reload()
    }

    func reload() {
        do {
            snapshots = try store.loadIndex().snapshots.sorted { $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending }
            Task { await loadCachedQuotas() }
        } catch {
            status = Redaction.redact(error.localizedDescription)
        }
    }

    func addFromOAuthLogin() {
        status = "Starting codex login..."
        Task {
            do {
                try loginRunner.runLogin()
                let label = "Codex \(Date().formatted(date: .abbreviated, time: .shortened))"
                let snapshot = try store.importActiveAuth(label: label)
                await MainActor.run {
                    status = "Saved \(snapshot.label)."
                    reload()
                }
                await refresh(snapshot: snapshot)
            } catch {
                await MainActor.run { status = Redaction.redact(error.localizedDescription) }
            }
        }
    }

    func importCurrentActiveAuth() {
        do {
            let label = "Imported \(Date().formatted(date: .abbreviated, time: .shortened))"
            let snapshot = try store.importActiveAuth(label: label)
            status = "Saved \(snapshot.label)."
            reload()
            Task { await refresh(snapshot: snapshot) }
        } catch {
            status = Redaction.redact(error.localizedDescription)
        }
    }

    func switchTo(_ snapshot: AccountSnapshot) {
        do {
            try store.switchActiveAuth(to: snapshot)
            status = "Switched Active Auth to \(snapshot.label). Relaunch Codex when ready."
            Task { await refresh(snapshot: snapshot) }
        } catch {
            status = Redaction.redact(error.localizedDescription)
        }
    }

    func relaunchCodex() {
        let script = """
        tell application "Codex" to quit
        delay 1
        tell application "Codex" to activate
        """
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        do {
            try process.run()
            status = "Relaunch Codex requested."
        } catch {
            status = "Could not relaunch Codex: \(Redaction.redact(error.localizedDescription))"
        }
    }

    func refreshAll() {
        Task {
            isRefreshing = true
            for snapshot in snapshots {
                await refresh(snapshot: snapshot)
            }
            isRefreshing = false
        }
    }

    func refreshStaleOnOpen() {
        let staleAfter: TimeInterval = 15 * 60
        for snapshot in snapshots where Date().timeIntervalSince(quotas[snapshot.id]?.fetchedAt ?? .distantPast) > staleAfter {
            Task { await refresh(snapshot: snapshot) }
        }
    }

    private func refresh(snapshot: AccountSnapshot) async {
        let quota = await refresher.refresh(snapshot: snapshot)
        await MainActor.run { quotas[snapshot.id] = quota }
    }

    private func loadCachedQuotas() async {
        var cached: [UUID: QuotaSnapshot] = [:]
        for snapshot in snapshots {
            cached[snapshot.id] = await refresher.cachedQuota(for: snapshot)
        }
        await MainActor.run { quotas = cached }
    }
}
