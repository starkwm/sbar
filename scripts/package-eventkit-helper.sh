#!/bin/sh
set -eu

bin_dir=$1
bundle="$bin_dir/Sbar EventKit.app"
mkdir -p "$bundle/Contents/MacOS"
cp "$bin_dir/sbar-eventkit" "$bundle/Contents/MacOS/sbar-eventkit"
cp Sources/SbarEventKit/Info.plist "$bundle/Contents/Info.plist"
build_id=$(shasum -a 256 "$bin_dir/sbar-eventkit" | cut -d ' ' -f 1)
/usr/libexec/PlistBuddy -c "Add :SbarBuildIdentifier string $build_id" "$bundle/Contents/Info.plist"
# Release distributors can pass a stable signing identity; development builds are ad hoc.
codesign --force --sign "${CODE_SIGN_IDENTITY:--}" "$bundle"
