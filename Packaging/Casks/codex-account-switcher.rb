cask "codex-account-switcher" do
  version "0.1.3"
  sha256 "bcc8eb483bc495de4a0264b3aacff29d27fbdb1cc2ff0acf8865b5a29d239a3c"

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
