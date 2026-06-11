#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

project_value() {
  awk -F': ' -v key="$1" '$1 ~ key { gsub(/"/, "", $2); print $2; exit }' project.yml
}

TEAM_ID="${DEVELOPMENT_TEAM:-$(project_value DEVELOPMENT_TEAM)}"
BUNDLE_ID="$(project_value PRODUCT_BUNDLE_IDENTIFIER)"

if [ -z "$TEAM_ID" ]; then
  printf '[FAIL] No DEVELOPMENT_TEAM found. Set project.yml or run with DEVELOPMENT_TEAM=<TEAM_ID>.\n' >&2
  exit 1
fi

if [ "$BUNDLE_ID" != "com.tyronsamaroo.stepreceipt" ]; then
  printf '[FAIL] Unexpected bundle id: %s\n' "$BUNDLE_ID" >&2
  exit 1
fi

DEVICES_JSON="$(mktemp /tmp/stepreceipt-devices.XXXXXX)"
BUILD_LOG="$(mktemp /tmp/stepreceipt-production-build.XXXXXX)"
trap 'rm -f "$DEVICES_JSON" "$BUILD_LOG"' EXIT

xcrun devicectl list devices --json-output "$DEVICES_JSON" >/dev/null
DEVICE_NAME="$(plutil -extract result.devices.0.name raw -o - "$DEVICES_JSON" 2>/dev/null || true)"
DEVICE_UDID="$(plutil -extract result.devices.0.hardwareProperties.udid raw -o - "$DEVICES_JSON" 2>/dev/null || true)"
DEVELOPER_MODE="$(plutil -extract result.devices.0.deviceProperties.developerModeStatus raw -o - "$DEVICES_JSON" 2>/dev/null || true)"
DDI_SERVICES="$(plutil -extract result.devices.0.deviceProperties.ddiServicesAvailable raw -o - "$DEVICES_JSON" 2>/dev/null || true)"

if [ -z "$DEVICE_UDID" ]; then
  printf '[FAIL] No iPhone is connected or paired.\n' >&2
  printf 'Connect the iPhone, tap Trust on the phone, enable Developer Mode if prompted, then rerun this script.\n' >&2
  exit 1
fi

if [ "$DEVELOPER_MODE" != "enabled" ] || [ "$DDI_SERVICES" != "true" ]; then
  printf '[FAIL] iPhone is connected but not development-ready.\n' >&2
  printf 'Developer Mode: %s; DDI services available: %s\n' "${DEVELOPER_MODE:-unknown}" "${DDI_SERVICES:-unknown}" >&2
  printf 'On the iPhone, enable Settings > Privacy & Security > Developer Mode, restart, unlock, and rerun this script.\n' >&2
  exit 1
fi

printf 'Building StepReceipt production iPhone proof\n'
printf 'Team: %s\n' "$TEAM_ID"
printf 'Bundle: %s\n' "$BUNDLE_ID"
printf 'Device: %s (%s)\n' "${DEVICE_NAME:-connected iPhone}" "$DEVICE_UDID"

xcodebuild \
  -project StepReceipt.xcodeproj \
  -scheme StepReceipt \
  -configuration Debug \
  -destination "platform=iOS,id=$DEVICE_UDID" \
  -allowProvisioningUpdates \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  CODE_SIGN_STYLE=Automatic \
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
xcrun devicectl device install app --device "$DEVICE_UDID" "$APP_PATH"

printf 'Launching %s\n' "$BUNDLE_ID"
xcrun devicectl device process launch --device "$DEVICE_UDID" --terminate-existing "$BUNDLE_ID" || true

printf '[PASS] Production bundle installed on the iPhone. Continue with HealthKit and CloudKit acceptance checks.\n'
