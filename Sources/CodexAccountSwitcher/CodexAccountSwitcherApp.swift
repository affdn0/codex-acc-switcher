import CodexAccountSwitcherCore
import SwiftUI

@main
struct CodexAccountSwitcherApp: App {
    @StateObject private var state = AppState()

    var body: some Scene {
        MenuBarExtra("Codex", systemImage: "person.2.crop.square.stack") {
            MenuContentView()
                .environmentObject(state)
                .onAppear { state.refreshStaleOnOpen() }
        }
        .menuBarExtraStyle(.menu)
    }
}

struct MenuContentView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        Group {
            if state.snapshots.isEmpty {
                Text("No Account Snapshots")
            } else {
                ForEach(state.snapshots) { snapshot in
                    Button {
                        state.switchTo(snapshot)
                    } label: {
                        VStack(alignment: .leading) {
                            Text(snapshot.label)
                            Text(quotaLine(state.quotas[snapshot.id]))
                        }
                    }
                }
            }

            Divider()

            Button("Add Account with OAuth Login") {
                state.addFromOAuthLogin()
            }
            Button("Import Current Active Auth") {
                state.importCurrentActiveAuth()
            }
            Button(state.isRefreshing ? "Refreshing Quotas..." : "Refresh Quotas") {
                state.refreshAll()
            }
            .disabled(state.isRefreshing)
            Button("Relaunch Codex") {
                state.relaunchCodex()
            }

            if let status = state.status {
                Divider()
                Text(status)
            }

            Divider()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
    }

    private func quotaLine(_ quota: QuotaSnapshot?) -> String {
        guard let quota else { return "Quota not fetched" }
        var parts: [String] = []
        if let plan = quota.planType { parts.append(plan) }
        if let session = quota.session { parts.append("5h \(percentText(session)) \(resetText(session))") }
        if let weekly = quota.weekly { parts.append("weekly \(percentText(weekly)) \(resetText(weekly))") }
        if let credits = quota.credits {
            if credits.unlimited == true {
                parts.append("credits unlimited")
            } else if let remaining = credits.remaining ?? credits.balance {
                parts.append("credits \(format(remaining))")
            }
        }
        parts.append("stale \(quota.fetchedAt.formatted(date: .omitted, time: .shortened))")
        if let error = quota.error { parts.append("error \(error)") }
        return parts.joined(separator: " | ")
    }

    private func percentText(_ window: QuotaWindow) -> String {
        if let remaining = window.remainingPercent { return "\(format(remaining))% left" }
        if let used = window.usedPercent { return "\(format(used))% used" }
        if let used = window.used, let limit = window.limit, limit > 0 { return "\(format(used / limit * 100))% used" }
        return "unknown"
    }

    private func resetText(_ window: QuotaWindow) -> String {
        if let resetAt = window.resetAt { return "resets \(resetAt.formatted(date: .omitted, time: .shortened))" }
        if let seconds = window.resetsInSeconds { return "resets in \(Int(seconds / 60))m" }
        return ""
    }

    private func format(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1)))
    }
}
