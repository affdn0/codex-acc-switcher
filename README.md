# Codex Account Switcher

Native macOS SwiftUI menu-bar app for switching between your own Codex Pro accounts by replacing the global Active Auth file at `~/.codex/auth.json`.

## Local Build

```sh
swift test
Scripts/build-app.sh
open ".build/Codex Account Switcher.app"
```

The build script creates a local `.app` bundle at `.build/Codex Account Switcher.app`. It does not sign, notarize, release, or publish anything.
It does apply an ad-hoc local code signature so macOS recognizes the hand-built app bundle structure.

## Account Snapshots

Use **Add Account with OAuth Login** from the menu. The app shells out to:

```sh
codex login
```

After the official login flow finishes, the resulting `~/.codex/auth.json` is saved as an Account Snapshot. You can also use **Import Current Active Auth** to snapshot the Active Auth that already exists.

Snapshots are plaintext JSON files in:

```text
~/Library/Application Support/Codex Account Switcher/Account Snapshots
```

The Snapshot Store directories are kept private with `0700` permissions, and snapshot files are written with `0600` permissions.

## Switching And Relaunching

Choosing an Account Snapshot atomically replaces:

```text
~/.codex/auth.json
```

Switching does not quit Codex. This lets you switch while Codex is running, then explicitly choose **Relaunch Codex** when you want Codex to reread Active Auth.

## Quota Privacy

Quota Refresh reads OAuth credentials from each saved Account Snapshot, refreshes stale credentials with `https://auth.openai.com/oauth/token`, then fetches usage from `https://chatgpt.com/backend-api/wham/usage`.

Quota caches are stored per Account Snapshot in:

```text
~/Library/Application Support/Codex Account Switcher/Quota Snapshots
```

The cache stores only derived quota state such as plan, session and weekly window percentages, reset timing, credits, fetch timestamp, and redacted errors. It never stores bearer tokens.

Use **Refresh Quotas** for a manual refresh. The app also refreshes after login/save/switch and when the menu opens if cached quota is stale. Network failures preserve the last-good quota where possible.

## Sample Homebrew Cask

Install from this repository as a Homebrew tap:

```sh
brew tap affdn0/codex-acc-switcher https://github.com/affdn0/codex-acc-switcher
brew install --cask codex-account-switcher
open "/Applications/Codex Account Switcher.app"
```

`Casks/codex-account-switcher.rb` is the tap cask Homebrew uses. `Packaging/Casks/codex-account-switcher.rb` is a copy kept with the packaging files for reference. This repo does not include a formula, release automation, signing, or notarization automation.
Because the app is intentionally not notarized, the personal cask removes the quarantine attribute after install for local testing.
