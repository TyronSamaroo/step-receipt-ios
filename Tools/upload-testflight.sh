#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

project_value() {
  awk -F': ' -v key="$1" '$1 ~ key { gsub(/"/, "", $2); print $2; exit }' project.yml
}

TEAM_ID="${DEVELOPMENT_TEAM:-$(project_value DEVELOPMENT_TEAM)}"
MARKETING_VERSION="$(project_value MARKETING_VERSION)"
BUILD_NUMBER="$(project_value CURRENT_PROJECT_VERSION)"
SCHEME="${STEP_RECEIPT_SCHEME:-StepReceipt}"
ARCHIVE_PATH="${STEP_RECEIPT_ARCHIVE_PATH:-$ROOT_DIR/build/StepReceipt.xcarchive}"
EXPORT_PATH="${STEP_RECEIPT_EXPORT_PATH:-$ROOT_DIR/build/export}"
EXPORT_PLIST="$ROOT_DIR/Config/TestFlightExportOptions.plist"

if [ -z "$TEAM_ID" ]; then
  printf '[FAIL] DEVELOPMENT_TEAM missing in project.yml\n' >&2
  exit 1
fi

printf 'StepReceipt TestFlight upload\n'
printf '  Version: %s (%s)\n' "$MARKETING_VERSION" "$BUILD_NUMBER"
printf '  Team:    %s\n' "$TEAM_ID"
printf '  Scheme:  %s\n\n' "$SCHEME"

printf 'Running readiness gate (non-blocking)...\n'
bash Tools/device-testflight-readiness.sh || printf '[WARN] Readiness gate reported issues; continuing archive/upload.\n'

printf '\nRegenerating Xcode project...\n'
xcodegen generate

mkdir -p build

printf '\nArchiving Release build (generic iOS)...\n'
xcodebuild \
  -project StepReceipt.xcodeproj \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE_PATH" \
  -allowProvisioningUpdates \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  CODE_SIGN_STYLE=Automatic \
  clean archive

printf '\nExporting and uploading to App Store Connect...\n'
rm -rf "$EXPORT_PATH"
xcodebuild \
  -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportOptionsPlist "$EXPORT_PLIST" \
  -exportPath "$EXPORT_PATH" \
  -allowProvisioningUpdates

printf '\n[PASS] Upload submitted for %s (%s).\n' "$MARKETING_VERSION" "$BUILD_NUMBER"
cat <<EOF

Next steps in App Store Connect:
  1. Wait for build processing (TestFlight → iOS Builds).
  2. Add export compliance if prompted (already ITSAppUsesNonExemptEncryption=false).
  3. Enable the build for Tiffany (external tester or Family Beta group).
  4. Deploy Production CloudKit schema if not done yet (compete sync on TestFlight).

EOF
