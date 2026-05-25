import CodexAccountSwitcherCore
import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var snapshots: [AccountSnapshot] = []
    @Published var quotas: [UUID: QuotaSnapshot] = [:]
    @Published var status: String?
    @Published var isRefreshing = false

    private var statusClearTask: Task<Void, Never>?
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
            try store.removeDuplicateSnapshots()
            snapshots = try store.loadIndex().snapshots.sorted { $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending }
            Task { await loadCachedQuotas() }
        } catch {
            showStatus(Redaction.redact(error.localizedDescription))
        }
    }

    func addFromOAuthLogin() {
        showStatus("Starting codex login...")
        Task {
            let previous = try? store.importActiveAuth()
            do {
                try loginRunner.runLogin()
                let snapshot = try store.importActiveAuth()
                if let previous, previous.id != snapshot.id {
                    try store.switchActiveAuth(to: previous)
                }
                await MainActor.run {
                    showStatus("Saved \(snapshot.label).")
                    reload()
                }
                await refresh(snapshot: snapshot)
            } catch {
                if let previous {
                    try? store.switchActiveAuth(to: previous)
                }
                await MainActor.run { showStatus(Redaction.redact(error.localizedDescription)) }
            }
        }
    }

    func importCurrentActiveAuth() {
        do {
            let snapshot = try store.importActiveAuth()
            showStatus("Saved \(snapshot.label).")
            reload()
            Task { await refresh(snapshot: snapshot) }
        } catch {
            showStatus(Redaction.redact(error.localizedDescription))
        }
    }

    func switchTo(_ snapshot: AccountSnapshot) {
        do {
            try store.switchActiveAuth(to: snapshot)
            showStatus("Switched Active Auth to \(snapshot.label). Relaunch Codex when ready.")
            Task { await refresh(snapshot: snapshot) }
        } catch {
            showStatus(Redaction.redact(error.localizedDescription))
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
            showStatus("Relaunch Codex requested.")
        } catch {
            showStatus("Could not relaunch Codex: \(Redaction.redact(error.localizedDescription))")
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

    func refreshOne(_ snapshot: AccountSnapshot) {
        Task { await refresh(snapshot: snapshot) }
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

    private func showStatus(_ message: String, clearAfter seconds: UInt64 = 4) {
        status = message
        statusClearTask?.cancel()
        statusClearTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: seconds * 1_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard self?.status == message else { return }
                self?.status = nil
            }
        }
    }
}
