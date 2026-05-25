cask "codex-account-switcher" do
  version "0.1.6"
  sha256 "c7f51706f953e459a488068b416cba95a9ed045b022533e6c1c11c763683db1f"

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
