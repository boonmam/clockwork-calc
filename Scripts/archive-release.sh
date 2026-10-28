#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
# Use a clean source export or checkout; ignored legacy files must not enter the app.
xcodegen generate
ARCHIVE="$ROOT/.build/Release/ClockworkCalc.xcarchive"
SIGNING=(CODE_SIGNING_ALLOWED=NO)
if [[ -n "${TEAM_ID:-}" ]]; then SIGNING=("DEVELOPMENT_TEAM=$TEAM_ID" CODE_SIGN_STYLE=Automatic); fi
xcodebuild -project "Clockwork Calc.xcodeproj" -scheme ClockworkCalc -configuration Release \
  -destination 'generic/platform=iOS' -archivePath "$ARCHIVE" \
  -derivedDataPath "$ROOT/.build/Release/DerivedData" "${SIGNING[@]}" archive
python3 Scripts/audit-distribution.py "$ARCHIVE/Products/Applications/ClockworkCalc.app"
echo "Archive: $ARCHIVE"
if [[ -z "${TEAM_ID:-}" ]]; then echo "UNSIGNED: this archive cannot be uploaded. Rebuild with a configured Apple Developer team."; fi
