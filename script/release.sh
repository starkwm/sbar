#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SIGNING_IDENTITY="${SIGNING_IDENTITY:--}"
STARKBAR_VERSION="${STARKBAR_VERSION:-0.1.0}"
STARKBAR_BUILD="${STARKBAR_BUILD:-1}"
[[ "$STARKBAR_VERSION" =~ ^[0-9]+(\.[0-9]+){0,3}$ ]] || { echo "Use a numeric release version" >&2; exit 2; }
[[ "$STARKBAR_BUILD" =~ ^[0-9]+$ ]] || { echo "Use a numeric build number" >&2; exit 2; }
export STARKBAR_VERSION STARKBAR_BUILD
BUILD_CONFIGURATION=release bash "$ROOT_DIR/script/build_and_run.sh" --build
APP="$ROOT_DIR/dist/StarkBar.app"
SIGN_OPTIONS=(--force --sign "$SIGNING_IDENTITY" --options runtime)
if [[ "$SIGNING_IDENTITY" != "-" ]]; then SIGN_OPTIONS+=(--timestamp); fi
codesign "${SIGN_OPTIONS[@]}" "$APP/Contents/MacOS/barctl"
codesign "${SIGN_OPTIONS[@]}" "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"
plutil -lint "$APP/Contents/Info.plist"
ARCHIVE="$ROOT_DIR/dist/StarkBar-$STARKBAR_VERSION.zip"
if [[ -n "${NOTARY_PROFILE:-}" ]]; then
  [[ "$SIGNING_IDENTITY" != "-" ]] || { echo "Notarization requires a Developer ID identity" >&2; exit 2; }
  ditto -c -k --keepParent "$APP" "$ARCHIVE"
  xcrun notarytool submit "$ARCHIVE" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$APP"
  xcrun stapler validate "$APP"
fi
ditto -c -k --keepParent "$APP" "$ARCHIVE"
echo "$ARCHIVE"
