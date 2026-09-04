#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="StarkBar"
BUNDLE_ID="com.starkwm.StarkBar"
MIN_SYSTEM_VERSION="14.0"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="$ROOT_DIR/dist/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_BINARY="$APP_CONTENTS/MacOS/$APP_NAME"

if [[ "$MODE" != "--build" && "$MODE" != "build" ]]; then
  pkill -x "$APP_NAME" >/dev/null 2>&1 || true
fi
swift build
BUILD_DIRECTORY="$(swift build --show-bin-path)"
BUILD_BINARY="$BUILD_DIRECTORY/$APP_NAME"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_CONTENTS/MacOS"
cp "$BUILD_BINARY" "$APP_BINARY"
cp "$BUILD_DIRECTORY/barctl" "$APP_CONTENTS/MacOS/barctl"
# SwiftPM's generated Bundle.module accessor resolves this relative to the app root.
cp -R "$BUILD_DIRECTORY/StarkBar_StarkBar.bundle" "$APP_BUNDLE/"
chmod +x "$APP_BINARY"
cat >"$APP_CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>$APP_NAME</string>
<key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
<key>CFBundleName</key><string>$APP_NAME</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>LSMinimumSystemVersion</key><string>$MIN_SYSTEM_VERSION</string>
<key>LSUIElement</key><true/>
<key>NSPrincipalClass</key><string>NSApplication</string>
</dict></plist>
PLIST

open_app() { /usr/bin/open -n "$APP_BUNDLE"; }
case "$MODE" in
  --build|build) ;;
  run) open_app ;;
  --debug|debug) lldb -- "$APP_BINARY" ;;
  --logs|logs) open_app; /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\"" ;;
  --telemetry|telemetry) open_app; /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\"" ;;
  --verify|verify) open_app; sleep 1; pgrep -x "$APP_NAME" >/dev/null ;;
  *) echo "usage: $0 [--build|run|--debug|--logs|--telemetry|--verify]" >&2; exit 2 ;;
esac
