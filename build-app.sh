#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release
BIN="$(swift build -c release --show-bin-path)/WindowLayout"

APP="Mac Window Layout.app"
rm -rf WindowLayout.app "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/WindowLayout"
cp Info.plist "$APP/Contents/Info.plist"
# Regenerate with: swift make-icon.swift icon.png, then sips + iconutil into AppIcon.icns.
cp AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
# A stable identity keeps the Accessibility grant across rebuilds (ad-hoc "-" changes every build).
codesign --force -s "${SIGN_ID:-Apple Development}" "$APP"
echo "Built $(pwd)/$APP"
