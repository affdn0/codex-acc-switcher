cask "codex-account-switcher" do
  version "0.1.4"
  sha256 "14e7ad33ac5e254759138593e3c21ed26a208cc6e0cb9ab9e24e3dcc67effd58"

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
