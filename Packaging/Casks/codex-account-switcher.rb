cask "codex-account-switcher" do
  version "0.1.10"
  sha256 "3eba98068079fc7af1bea33f5824bd0f91a9c157c3b64bbf7ad9a7804e81f2e4"

  url "https://github.com/affdn0/codex-acc-switcher/releases/download/v#{version}/Codex-Account-Switcher-#{version}.zip"
  name "Codex Account Switcher"
  desc "Native menu-bar app for switching local Codex Account Snapshots"
  homepage "https://github.com/affdn0/codex-acc-switcher"

  depends_on macos: :sonoma

  app "Codex Account Switcher.app"

  postflight do
    system_command "/usr/bin/xattr",
                   args: ["-dr", "com.apple.quarantine", "#{appdir}/Codex Account Switcher.app"]
  end
end
