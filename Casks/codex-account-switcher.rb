cask "codex-account-switcher" do
  version "0.1.0"
  sha256 "f537b002161dd6ca56f9203d06bc38a7a48dcc3a9abf8eadfcd43eda7632bbad"

  url "https://github.com/affdn0/codex-acc-switcher/releases/download/v#{version}/Codex-Account-Switcher-#{version}.zip"
  name "Codex Account Switcher"
  desc "Native menu-bar app for switching local Codex Account Snapshots"
  homepage "https://github.com/affdn0/codex-acc-switcher"

  app "Codex Account Switcher.app"
end
