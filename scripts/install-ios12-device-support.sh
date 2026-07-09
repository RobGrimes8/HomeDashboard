#!/bin/bash
# Installs iOS 12 DeviceSupport files into Xcode so an iPad mini 2 (iOS 12.x) can be used for development.
# Requires admin password because Xcode lives in /Applications.

set -euo pipefail

XCODE="/Applications/Xcode.app"
DEVICE_SUPPORT="$XCODE/Contents/Developer/Platforms/iPhoneOS.platform/DeviceSupport"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ZIP="$SCRIPT_DIR/12.4.zip"

if [[ ! -d "$XCODE" ]]; then
  echo "Error: Xcode not found at $XCODE"
  exit 1
fi

if [[ ! -f "$ZIP" ]]; then
  echo "Error: Missing $ZIP"
  echo "Download from: https://github.com/filsv/iOSDeviceSupport/raw/master/12.4%20(16G73).zip"
  exit 1
fi

echo "This will copy iOS 12.4 DeviceSupport into Xcode and add aliases for iOS 12.5.x."
echo "Target: $DEVICE_SUPPORT"
echo ""
read -r -p "Continue? [y/N] " reply
if [[ ! "$reply" =~ ^[Yy]$ ]]; then
  echo "Cancelled."
  exit 0
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

unzip -q "$ZIP" -d "$TMP"
SOURCE="$TMP/12.4 (16G73)"

if [[ ! -f "$SOURCE/DeveloperDiskImage.dmg" ]]; then
  echo "Error: Invalid zip contents"
  exit 1
fi

# iPad mini 2 is on iOS 12.5.7 (16H81). Xcode looks for an exact folder name match.
ALIASES=(
  "12.5.7"
  "12.5.7 (16H81)"
  "12.4 (16G73)"
)

for name in "${ALIASES[@]}"; do
  dest="$DEVICE_SUPPORT/$name"
  echo "Installing $name ..."
  sudo rm -rf "$dest"
  sudo cp -R "$SOURCE" "$dest"
done

echo ""
echo "Done. Quit Xcode completely (Cmd+Q), reopen it, reconnect your iPad, and try Run again."
echo ""
echo "If it still fails, check your iPad's exact iOS version:"
echo "  Settings → General → About → iOS Version"
echo "Then tell Xcode support to add a folder named exactly that version in:"
echo "  $DEVICE_SUPPORT"
