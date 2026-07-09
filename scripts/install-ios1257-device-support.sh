#!/bin/bash
# One-shot install for iPad mini 2 on iOS 12.5.7 (16H81)
set -euo pipefail

XCODE="/Applications/Xcode.app"
DEST="$XCODE/Contents/Developer/Platforms/iPhoneOS.platform/DeviceSupport"
ZIP="$(cd "$(dirname "$0")" && pwd)/12.4.zip"

[[ -d "$XCODE" ]] || { echo "Xcode not found"; exit 1; }
[[ -f "$ZIP" ]] || { echo "Missing $ZIP"; exit 1; }

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
unzip -q "$ZIP" -d "$TMP"
SOURCE="$TMP/12.4 (16G73)"

echo "Installing iOS 12.5.7 device support into Xcode..."
for name in "12.5.7" "12.5.7 (16H81)"; do
  echo "  → $name"
  sudo rm -rf "$DEST/$name"
  sudo cp -R "$SOURCE" "$DEST/$name"
done

echo ""
echo "Installed. Quit Xcode (Cmd+Q), reopen, reconnect iPad, press Run."
