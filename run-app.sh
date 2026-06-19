#!/bin/bash
# One-click run MidjourneyMedical in the iOS Simulator (no Xcode UI needed).
set -euo pipefail

PROJECT="/Users/maxlee/Developer/midjourney/MidjourneyMedical.xcodeproj"
SCHEME="MidjourneyMedical"
BUNDLE_ID="com.midjourney.medical.demo"
# iPhone 16 · iOS 18.4 — change id if needed: xcrun simctl list devices available
SIMULATOR_ID="8BEDEEBC-93B3-4EA0-85A5-01385B740F88"

echo "→ Building..."
DERIVED_DATA="/Users/maxlee/Developer/midjourney/.derivedData"
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Debug \
  -destination "platform=iOS Simulator,id=$SIMULATOR_ID" \
  -derivedDataPath "$DERIVED_DATA" \
  SKIP_LOADING=1 \
  build 2>&1 | tail -3

APP_PATH="$DERIVED_DATA/Build/Products/Debug-iphonesimulator/MidjourneyMedical.app"
if [[ ! -d "$APP_PATH" ]]; then
  echo "Build failed — app not found."
  exit 1
fi

echo "→ Opening Simulator..."
xcrun simctl boot "$SIMULATOR_ID" 2>/dev/null || true
open -a Simulator

echo "→ Installing & launching..."
xcrun simctl install "$SIMULATOR_ID" "$APP_PATH"
xcrun simctl launch "$SIMULATOR_ID" "$BUNDLE_ID"

echo "Done — MidjourneyMedical is running in the Simulator."
