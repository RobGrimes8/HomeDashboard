#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/HomeDashboard/Config/Signing.xcconfig"

if [[ -f "$DEST" ]]; then
  echo "Signing.xcconfig already exists:"
  cat "$DEST"
  exit 0
fi

echo "Paste your Apple Development Team ID (from Xcode → Signing & Capabilities):"
read -r TEAM_ID

if [[ -z "$TEAM_ID" || "$TEAM_ID" == "YOUR_TEAM_ID_HERE" ]]; then
  echo "No team ID provided."
  exit 1
fi

cat > "$DEST" <<EOF
DEVELOPMENT_TEAM = $TEAM_ID
EOF

echo "Created HomeDashboard/Config/Signing.xcconfig"
echo "Git will ignore this file — your team survives future pulls."
