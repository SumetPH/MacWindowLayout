#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release
BIN="$(swift build -c release --show-bin-path)/WindowLayout"

rm -rf WindowLayout.app
mkdir -p WindowLayout.app/Contents/MacOS
cp "$BIN" WindowLayout.app/Contents/MacOS/WindowLayout
cp Info.plist WindowLayout.app/Contents/Info.plist
# A stable identity keeps the Accessibility grant across rebuilds (ad-hoc "-" changes every build).
codesign --force -s "${SIGN_ID:-Apple Development}" WindowLayout.app
echo "Built $(pwd)/WindowLayout.app"
