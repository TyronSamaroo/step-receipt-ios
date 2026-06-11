#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

TEAM_ID="${DEVELOPMENT_TEAM:-}"
if [ -z "$TEAM_ID" ]; then
  TEAM_ID="$(defaults read com.apple.dt.Xcode IDEProvisioningTeamByIdentifier 2>/dev/null \
    | awk -F'= ' '/teamID/ { gsub(/[; "]/, "", $2); print $2; exit }' || true)"
fi

if [ -z "$TEAM_ID" ]; then
  printf '[FAIL] No DEVELOPMENT_TEAM found. Sign into Xcode or run with DEVELOPMENT_TEAM=<TEAM_ID>.\n' >&2
  exit 1
fi

DEVICES_JSON="$(mktemp /tmp/stepreceipt-devices.XXXXXX.json)"
BUILD_LOG="$(mktemp /tmp/stepreceipt-local-build.XXXXXX.log)"
trap 'rm -f "$DEVICES_JSON" "$BUILD_LOG"' EXIT

xcrun devicectl list devices --json-output "$DEVICES_JSON" >/dev/null
DEVICE_NAME="$(plutil -extract result.devices.0.name raw -o - "$DEVICES_JSON" 2>/dev/null || true)"
DEVICE_IDENTIFIER="$(plutil -extract result.devices.0.identifier raw -o - "$DEVICES_JSON" 2>/dev/null || true)"

if [ -z "$DEVICE_IDENTIFIER" ]; then
  printf '[FAIL] No iPhone is connected or paired.\n' >&2
  printf 'Connect the iPhone, tap Trust on the phone, enable Developer Mode if prompted, then rerun this script.\n' >&2
  exit 1
fi

printf 'Building StepReceipt local iPhone proof\n'
printf 'Team: %s\n' "$TEAM_ID"
printf 'Device: %s (%s)\n' "${DEVICE_NAME:-connected iPhone}" "$DEVICE_IDENTIFIER"

xcodebuild \
  -project StepReceipt.xcodeproj \
  -scheme StepReceipt \
  -configuration Debug \
  -destination "platform=iOS,id=$DEVICE_IDENTIFIER" \
  -allowProvisioningUpdates \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  CODE_SIGN_STYLE=Automatic \
  PRODUCT_BUNDLE_IDENTIFIER=com.tyronsamaroo.stepreceipt.local \
  CODE_SIGN_ENTITLEMENTS=StepReceiptApp/StepReceipt.LocalPersonal.entitlements \
  SWIFT_ACTIVE_COMPILATION_CONDITIONS='$(inherited) DEBUG LOCAL_NO_CLOUDKIT' \
  build | tee "$BUILD_LOG"

APP_PATH="$(awk -F'Touch ' '/Touch .*StepReceipt\\.app/ { print $2 }' "$BUILD_LOG" | tail -n 1)"
if [ -z "$APP_PATH" ]; then
  APP_PATH="$(find "$HOME/Library/Developer/Xcode/DerivedData" -path '*/Build/Products/Debug-iphoneos/StepReceipt.app' -type d -print 2>/dev/null | head -n 1)"
fi

if [ -z "$APP_PATH" ] || [ ! -d "$APP_PATH" ]; then
  printf '[FAIL] Build finished, but StepReceipt.app was not found in DerivedData.\n' >&2
  exit 1
fi

printf 'Installing %s\n' "$APP_PATH"
xcrun devicectl device install app --device "$DEVICE_IDENTIFIER" "$APP_PATH"

printf 'Launching com.tyronsamaroo.stepreceipt.local\n'
xcrun devicectl device process launch --device "$DEVICE_IDENTIFIER" --terminate-existing com.tyronsamaroo.stepreceipt.local || true

printf '[PASS] Local personal-team build installed. This build has HealthKit only; production CloudKit/TestFlight remains unchanged.\n'
