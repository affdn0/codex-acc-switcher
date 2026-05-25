#!/bin/sh
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="${CONFIGURATION:-release}"
APP="$ROOT/.build/Codex Account Switcher.app"
CONTENTS="$APP/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

cd "$ROOT"
swift build -c "$CONFIG" --product CodexAccountSwitcher

rm -rf "$APP"
mkdir -p "$MACOS" "$RESOURCES"
cp ".build/$CONFIG/CodexAccountSwitcher" "$MACOS/Codex Account Switcher"
cp "$ROOT/Packaging/Info.plist" "$CONTENTS/Info.plist"
cp "$ROOT/Packaging/AppIcon.icns" "$RESOURCES/AppIcon.icns"
chmod 755 "$MACOS/Codex Account Switcher"
codesign --force --deep --sign - "$APP"

echo "$APP"
