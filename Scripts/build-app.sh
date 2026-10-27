#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
xcodegen generate
xcodebuild -project ClockworkCalc.xcodeproj -scheme ClockworkCalc -destination 'generic/platform=iOS Simulator' -derivedDataPath .build/DerivedData CODE_SIGNING_ALLOWED=NO clean build
xcodebuild -project ClockworkCalc.xcodeproj -scheme ClockworkCalc -destination 'generic/platform=iOS' -derivedDataPath .build/DeviceData CODE_SIGNING_ALLOWED=NO clean build
python3 Scripts/audit-distribution.py .build/DeviceData/Build/Products/Debug-iphoneos/ClockworkCalc.app
