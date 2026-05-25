import CodexAccountSwitcherCore
import SwiftUI

@main
struct CodexAccountSwitcherApp: App {
    @StateObject private var state = AppState()

    var body: some Scene {
        MenuBarExtra("Codex Account Switcher", image: "MenuBarTemplate") {
            MenuContentView()
                .environmentObject(state)
                .onAppear { state.refreshStaleOnOpen() }
        }
        .menuBarExtraStyle(.window)
    }
}

struct MenuContentView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Codex Account Switcher")
                    .font(.headline)
                Spacer()
                Button {
                    state.refreshAll()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Refresh all quotas")
                .disabled(state.isRefreshing)

                Divider()
                    .frame(height: 18)

                Button {
                    state.addFromOAuthLogin()
                } label: {
                    Image(systemName: "person.crop.circle.badge.plus")
                }
                .buttonStyle(.borderless)
                .help("Add Account with OAuth Login")

                Button {
                    state.importCurrentActiveAuth()
                } label: {
                    Image(systemName: "square.and.arrow.down")
                }
                .buttonStyle(.borderless)
                .help("Import Current Active Auth")

                Button {
                    state.relaunchCodex()
                } label: {
                    Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90")
                }
                .buttonStyle(.borderless)
                .help("Relaunch Codex")
            }

            if state.snapshots.isEmpty {
                Text("No Account Snapshots")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 96)
            } else {
                ForEach(state.snapshots) { snapshot in
                    AccountCard(snapshot: snapshot, quota: state.quotas[snapshot.id])
                }
            }

            if let status = state.status {
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

        }
        .padding(14)
        .frame(width: 380)
    }
}

struct AccountCard: View {
    @EnvironmentObject private var state: AppState
    @State private var isConfirmingRemoval = false
    let snapshot: AccountSnapshot
    let quota: QuotaSnapshot?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(snapshot.label)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                    Text(planText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(staleText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Button {
                    state.refreshOne(snapshot)
                } label: {
                    Image(systemName: "arrow.clockwise.circle")
                }
                .buttonStyle(.borderless)
                .help("Refresh quota for \(snapshot.label)")
                Button(role: .destructive) {
                    isConfirmingRemoval = true
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("Remove \(snapshot.label)")
            }

            QuotaBar(label: "5h", window: quota?.session, tint: tint)
            QuotaBar(label: "weekly", window: quota?.weekly, tint: tint)

            HStack {
                Text(resetLine)
                Spacer()
                Text(creditsLine)
            }
            .font(.caption2)
            .foregroundStyle(.secondary)

            if let error = quota?.error {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }

            HStack {
                Spacer()
                Button {
                    state.switchTo(snapshot)
                } label: {
                    Image(systemName: "arrow.right.circle")
                }
                .controlSize(.small)
                .help("Switch Active Auth to \(snapshot.label)")
            }
        }
        .padding(10)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.separator.opacity(0.7), lineWidth: 1)
        }
        .confirmationDialog("Remove \(snapshot.label)?", isPresented: $isConfirmingRemoval) {
            Button("Remove Account", role: .destructive) {
                state.removeSnapshot(snapshot)
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var planText: String {
        quota?.planType ?? "quota not fetched"
    }

    private var staleText: String {
        guard let fetchedAt = quota?.fetchedAt else { return "not synced" }
        return "synced \(fetchedAt.formatted(date: .omitted, time: .shortened))"
    }

    private var resetLine: String {
        [quota?.session, quota?.weekly]
            .compactMap(resetText)
            .first ?? "reset unknown"
    }

    private var creditsLine: String {
        guard let credits = quota?.credits else { return "credits unknown" }
        if credits.unlimited == true { return "credits unlimited" }
        if let remaining = credits.remaining ?? credits.balance {
            return "credits \(format(remaining))"
        }
        return "credits unknown"
    }

    private var tint: Color {
        let maxUsed = max(quota?.session?.usedFraction ?? 0, quota?.weekly?.usedFraction ?? 0)
        if maxUsed >= 0.9 { return .red }
        if maxUsed >= 0.7 { return .orange }
        return .accentColor
    }

    private func resetText(_ window: QuotaWindow?) -> String? {
        guard let window else { return nil }
        if let resetAt = window.resetAt {
            return "\(windowName(window)) resets \(resetAt.formatted(date: .omitted, time: .shortened))"
        }
        if let seconds = window.resetsInSeconds {
            return "\(windowName(window)) resets in \(Int(seconds / 60))m"
        }
        return nil
    }

    private func windowName(_ window: QuotaWindow) -> String {
        window.limitWindowSeconds == 18_000 ? "5h" : "weekly"
    }

    private func format(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1)))
    }
}

struct QuotaBar: View {
    let label: String
    let window: QuotaWindow?
    let tint: Color

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption)
                .frame(width: 44, alignment: .leading)
            ProgressView(value: window?.usedFraction ?? 0)
                .tint(tint)
            Text(percentText)
                .font(.caption)
                .monospacedDigit()
                .frame(width: 72, alignment: .trailing)
        }
    }

    private var percentText: String {
        guard let window else { return "--" }
        if let remaining = window.remainingPercent { return "\(format(remaining))% left" }
        if let used = window.usedPercent { return "\(format(used))% used" }
        if let used = window.used, let limit = window.limit, limit > 0 { return "\(format(used / limit * 100))% used" }
        return "unknown"
    }

    private func format(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1)))
    }
}

private extension QuotaWindow {
    var usedFraction: Double {
        if let usedPercent {
            return min(max(usedPercent / 100, 0), 1)
        }
        if let remainingPercent {
            return min(max((100 - remainingPercent) / 100, 0), 1)
        }
        if let used, let limit, limit > 0 {
            return min(max(used / limit, 0), 1)
        }
        return 0
    }
}
