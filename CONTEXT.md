# Codex Account Switcher

This context describes a personal macOS menu-bar utility for switching between the user's own Codex Pro accounts by changing the active Codex authentication state.

## Language

**Active Auth**:
The one Codex authentication state currently installed at `~/.codex/auth.json`.
_Avoid_: current profile, global profile

**Account Snapshot**:
A saved copy of one Codex account's `auth.json` content that can replace **Active Auth**.
_Avoid_: profile, credential blob

**Snapshot Label**:
A user-facing name for an **Account Snapshot**.
_Avoid_: slot, account letter

**Snapshot Store**:
The local private directory containing saved **Account Snapshots** and metadata.
_Avoid_: keychain vault, cloud store

**Global Auth Switching**:
Switching accounts by replacing **Active Auth** rather than launching isolated Codex instances.
_Avoid_: isolated profile switching, per-app sandbox switching

**Relaunch Codex**:
An explicit user action that restarts Codex so it can read the new **Active Auth**.
_Avoid_: automatic restart, forced quit

**OAuth Login**:
A sign-in flow started by the app through the official `codex login` command so the resulting auth file can become an **Account Snapshot**.
_Avoid_: custom PKCE implementation, pasted token setup

**Menu-Bar App**:
The native SwiftUI macOS app that exposes account switching from the system menu bar.
_Avoid_: dashboard app, web UI, dock app

**Homebrew Cask**:
The Homebrew tap artifact used to install the packaged **Menu-Bar App**.
_Avoid_: formula, npm package

**Sample Cask**:
A checked-in example Homebrew cask file showing how the packaged app will be installed later.
_Avoid_: release automation, tap publishing

**Quota Snapshot**:
A cached per-account view of Codex usage limits fetched for an **Account Snapshot**.
_Avoid_: global quota, live-only quota

**Session Quota**:
The short Codex rate-limit window from the usage API, usually shown as the 5-hour window.
_Avoid_: daily quota

**Weekly Quota**:
The longer Codex rate-limit window from the usage API, usually shown as the weekly window.
_Avoid_: monthly quota

**Quota Refresh**:
Reading an **Account Snapshot**'s OAuth tokens, refreshing them if needed, and fetching its latest usage without changing **Active Auth**.
_Avoid_: switch-to-check, dashboard scraping

## Relationships

- **Global Auth Switching** changes exactly one **Active Auth**.
- An **Account Snapshot** can become **Active Auth**.
- The app may keep any number of **Account Snapshots**, but Codex sees only one **Active Auth** at a time.
- Every **Account Snapshot** has one **Snapshot Label** for menu display.
- The **Snapshot Store** keeps sensitive snapshot files as local plaintext with strict user-only permissions.
- An **Account Snapshot** may have one latest **Quota Snapshot** for menu display.
- **Quota Refresh** may update refreshed OAuth tokens inside an **Account Snapshot**, but it does not switch **Active Auth** by itself.
- **Quota Refresh** stores only derived quota state in the quota cache and never stores bearer tokens outside the **Snapshot Store**.
- **Session Quota** and **Weekly Quota** are shown per **Account Snapshot**, so a stale or failed refresh on one account does not affect the others.
- **Global Auth Switching** may happen while Codex is running; **Relaunch Codex** is offered separately.
- **OAuth Login** delegates sign-in to `codex login`, then creates or refreshes an **Account Snapshot** from the resulting **Active Auth**.
- The **Menu-Bar App** is the primary user interface for **Global Auth Switching**.
- The **Homebrew Cask** installs the **Menu-Bar App**; the MVP does not ship a separate CLI formula.
- The MVP includes a local buildable app bundle and a **Sample Cask**, not automated release or tap publishing.

## Example Dialogue

> **Dev:** "When I click account B in the menu bar, do we launch a separate Codex instance?"
> **Domain expert:** "No, this app uses **Global Auth Switching**: account B's **Account Snapshot** replaces **Active Auth** at `~/.codex/auth.json`."

## Flagged Ambiguities

- "account" means the user's own Codex Pro identity saved as an **Account Snapshot**, not a shared pool or team account.
- "profile" was avoided because reference repos use it to mean both saved `auth.json` files and isolated `CODEX_HOME` directories; this project uses **Account Snapshot** for saved auth and **Active Auth** for the live file.
- "slot" was avoided because the app supports any number of **Account Snapshots**, not fixed A/B accounts.
- "secure storage" is resolved for MVP as local plaintext files with `0600` snapshot permissions, not Keychain-backed secret storage.
- "switching" does not imply quitting or restarting Codex; restart behavior is covered by **Relaunch Codex**.
- "add account" includes **OAuth Login**, not only importing the current `~/.codex/auth.json`.
- "OAuth" means invoking the official Codex login command for MVP, not reimplementing OpenAI's PKCE/local-callback flow.
- "UI" means a native SwiftUI **Menu-Bar App**, not Tauri, Electron, or a browser dashboard.
- "brew support" means a **Homebrew Cask** for the app bundle, not a formula for a command-line tool.
- "brew tap" work is limited to a **Sample Cask** in the MVP; signing, notarization, GitHub Releases, and SHA automation are deferred.
- "usage quota" means Codex remote usage windows and credits fetched from OpenAI/ChatGPT APIs, not local token-count scanning.
- "show quota per account" means fetching from each saved **Account Snapshot** independently; it must not require making that snapshot **Active Auth** first.
- "quota refresh" for MVP uses OAuth API calls from saved `auth.json` tokens, not browser cookie import, WebKit dashboard scraping, or CLI RPC fallback.
