#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
if [ ! -f Vendor/Engine/iphoneos/lib/libqalculate.a ] || [ ! -f Vendor/Engine/iphonesimulator/lib/libqalculate.a ]; then
  Scripts/build-engine.sh
fi
xcodegen generate
xcodebuild -project Qalculate.xcodeproj -scheme Qalculate -destination 'generic/platform=iOS Simulator' -derivedDataPath .build/DerivedData CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Qalculate.xcodeproj -scheme Qalculate -destination 'generic/platform=iOS' -derivedDataPath .build/DeviceData CODE_SIGNING_ALLOWED=NO build
