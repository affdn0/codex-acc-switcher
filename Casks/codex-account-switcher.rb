cask "codex-account-switcher" do
  version "0.1.9"
  sha256 "85f327e08ec039aaf27f12aa8922cd1d1f9a5531acc04b49a9d906c7c0770e41"

  url "https://github.com/affdn0/codex-acc-switcher/releases/download/v#{version}/Codex-Account-Switcher-#{version}.zip"
  name "Codex Account Switcher"
  desc "Native menu-bar app for switching local Codex Account Snapshots"
  homepage "https://github.com/affdn0/codex-acc-switcher"

  app "Codex Account Switcher.app"

  postflight do
    system_command "/usr/bin/xattr",
                   args: ["-dr", "com.apple.quarantine", "#{appdir}/Codex Account Switcher.app"]
  end
end
