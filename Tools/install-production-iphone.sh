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
TARGET_DEVICE_ID="${STEP_RECEIPT_DEVICE_ID:-}"
TARGET_DEVICE_NAME="${STEP_RECEIPT_DEVICE_NAME:-}"
DEVICE_NAME=""
DEVICE_UDID=""
DEVICE_IDENTIFIER=""
DEVELOPER_MODE=""
DDI_SERVICES=""
FALLBACK_NAME=""
FALLBACK_UDID=""
FALLBACK_IDENTIFIER=""
FALLBACK_DEVELOPER_MODE=""
FALLBACK_DDI_SERVICES=""

for index in $(seq 0 20); do
  DEVICE_TYPE="$(plutil -extract "result.devices.$index.hardwareProperties.deviceType" raw -o - "$DEVICES_JSON" 2>/dev/null || true)"
  if [ "$DEVICE_TYPE" = "iPhone" ]; then
    CANDIDATE_NAME="$(plutil -extract "result.devices.$index.deviceProperties.name" raw -o - "$DEVICES_JSON" 2>/dev/null || true)"
    CANDIDATE_UDID="$(plutil -extract "result.devices.$index.hardwareProperties.udid" raw -o - "$DEVICES_JSON" 2>/dev/null || true)"
    CANDIDATE_IDENTIFIER="$(plutil -extract "result.devices.$index.identifier" raw -o - "$DEVICES_JSON" 2>/dev/null || true)"
    CANDIDATE_DEVELOPER_MODE="$(plutil -extract "result.devices.$index.deviceProperties.developerModeStatus" raw -o - "$DEVICES_JSON" 2>/dev/null || true)"
    CANDIDATE_DDI_SERVICES="$(plutil -extract "result.devices.$index.deviceProperties.ddiServicesAvailable" raw -o - "$DEVICES_JSON" 2>/dev/null || true)"

    if [ -z "$FALLBACK_UDID" ]; then
      FALLBACK_NAME="$CANDIDATE_NAME"
      FALLBACK_UDID="$CANDIDATE_UDID"
      FALLBACK_IDENTIFIER="$CANDIDATE_IDENTIFIER"
      FALLBACK_DEVELOPER_MODE="$CANDIDATE_DEVELOPER_MODE"
      FALLBACK_DDI_SERVICES="$CANDIDATE_DDI_SERVICES"
    fi

    if [ -n "$TARGET_DEVICE_ID" ]; then
      if [ "$CANDIDATE_UDID" != "$TARGET_DEVICE_ID" ] && [ "$CANDIDATE_IDENTIFIER" != "$TARGET_DEVICE_ID" ]; then
        continue
      fi
    elif [ -n "$TARGET_DEVICE_NAME" ]; then
      if [[ "$CANDIDATE_NAME" != *"$TARGET_DEVICE_NAME"* ]]; then
        continue
      fi
    elif [ "$CANDIDATE_DEVELOPER_MODE" != "enabled" ] || [ "$CANDIDATE_DDI_SERVICES" != "true" ]; then
      continue
    fi

    DEVICE_NAME="$CANDIDATE_NAME"
    DEVICE_UDID="$CANDIDATE_UDID"
    DEVICE_IDENTIFIER="$CANDIDATE_IDENTIFIER"
    DEVELOPER_MODE="$CANDIDATE_DEVELOPER_MODE"
    DDI_SERVICES="$CANDIDATE_DDI_SERVICES"
    break
  fi
done

if [ -z "$DEVICE_UDID" ] && [ -z "$TARGET_DEVICE_ID" ] && [ -z "$TARGET_DEVICE_NAME" ]; then
  DEVICE_NAME="$FALLBACK_NAME"
  DEVICE_UDID="$FALLBACK_UDID"
  DEVICE_IDENTIFIER="$FALLBACK_IDENTIFIER"
  DEVELOPER_MODE="$FALLBACK_DEVELOPER_MODE"
  DDI_SERVICES="$FALLBACK_DDI_SERVICES"
fi

if [ -z "$DEVICE_UDID" ]; then
  if [ -n "$TARGET_DEVICE_ID" ] || [ -n "$TARGET_DEVICE_NAME" ]; then
    printf '[FAIL] No matching iPhone found for target id "%s" or name "%s".\n' "$TARGET_DEVICE_ID" "$TARGET_DEVICE_NAME" >&2
  else
    printf '[FAIL] No iPhone is connected or paired.\n' >&2
  fi
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
printf 'Device: %s (%s, %s)\n' "${DEVICE_NAME:-connected iPhone}" "$DEVICE_UDID" "$DEVICE_IDENTIFIER"

xcodebuild \
  -project StepReceipt.xcodeproj \
  -scheme StepReceipt \
  -configuration Debug \
  -destination "platform=iOS,id=$DEVICE_UDID" \
  -allowProvisioningUpdates \
  -allowProvisioningDeviceRegistration \
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
