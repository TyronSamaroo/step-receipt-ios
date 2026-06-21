#!/usr/bin/env bash
set -u

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR" || exit 1

failures=0
warnings=0

pass() {
  printf '[PASS] %s\n' "$1"
}

warn() {
  warnings=$((warnings + 1))
  printf '[WARN] %s\n' "$1"
}

fail() {
  failures=$((failures + 1))
  printf '[FAIL] %s\n' "$1"
}

require_command() {
  if command -v "$1" >/dev/null 2>&1; then
    pass "$1 is installed"
  else
    fail "$1 is not installed or not on PATH"
  fi
}

project_value() {
  awk -F': ' -v key="$1" '$1 ~ key { gsub(/"/, "", $2); print $2; exit }' project.yml
}

printf 'StepReceipt device and TestFlight readiness\n'
printf 'Repo: %s\n\n' "$ROOT_DIR"

require_command xcodebuild
require_command xcodegen
require_command swift
require_command plutil
require_command security
require_command xcrun

printf '\nProject settings\n'
bundle_id="$(project_value PRODUCT_BUNDLE_IDENTIFIER)"
marketing_version="$(project_value MARKETING_VERSION)"
build_number="$(project_value CURRENT_PROJECT_VERSION)"
development_team="$(project_value DEVELOPMENT_TEAM)"

if [ "$bundle_id" = "com.tyronsamaroo.stepreceipt" ]; then
  pass "bundle id is $bundle_id"
else
  fail "bundle id is '$bundle_id', expected com.tyronsamaroo.stepreceipt"
fi

if [ "$marketing_version" = "0.1.0" ]; then
  pass "marketing version is $marketing_version"
else
  warn "marketing version is '$marketing_version'"
fi

if [ -n "$build_number" ]; then
  pass "build number is $build_number"
else
  fail "CURRENT_PROJECT_VERSION is blank"
fi

if [ -n "$development_team" ]; then
  pass "DEVELOPMENT_TEAM is set to $development_team"
else
  fail "DEVELOPMENT_TEAM is blank; set the real Apple Developer Team ID before device/TestFlight builds"
fi

printf '\nManifest and entitlements\n'
if plutil -lint StepReceiptApp/Info.plist StepReceiptApp/StepReceipt.entitlements StepReceiptApp/PrivacyInfo.xcprivacy >/dev/null; then
  pass "Info.plist, entitlements, and privacy manifest are valid plists"
else
  fail "plist validation failed"
fi

if grep -q "com.apple.developer.healthkit" StepReceiptApp/StepReceipt.entitlements; then
  pass "HealthKit entitlement is present"
else
  fail "HealthKit entitlement is missing"
fi

if grep -q "iCloud.com.tyronsamaroo.stepreceipt" StepReceiptApp/StepReceipt.entitlements; then
  pass "CloudKit container entitlement is present"
else
  fail "CloudKit container entitlement is missing"
fi

if [ -f Docs/CloudKitCompetitionSchema.md ]; then
  pass "CloudKit competition schema doc is present"
else
  fail "Docs/CloudKitCompetitionSchema.md is missing"
fi

if grep -q "LOCAL_NO_CLOUDKIT" Tools/install-local-personal-iphone.sh; then
  warn "local personal install uses LOCAL_NO_CLOUDKIT; household compete requires production install-production-iphone.sh"
fi

if grep -q "NSPrivacyAccessedAPICategoryUserDefaults" StepReceiptApp/PrivacyInfo.xcprivacy; then
  pass "UserDefaults required-reason API is declared"
else
  fail "PrivacyInfo.xcprivacy is missing the UserDefaults required-reason API"
fi

printf '\nXcode and device state\n'
if xcodebuild -version >/tmp/stepreceipt-xcode-version.txt 2>/dev/null; then
  pass "$(tr '\n' ' ' </tmp/stepreceipt-xcode-version.txt | sed 's/[[:space:]]*$//')"
else
  fail "xcodebuild -version failed"
fi
rm -f /tmp/stepreceipt-xcode-version.txt

identities="$(security find-identity -v -p codesigning 2>/dev/null || true)"
if printf '%s\n' "$identities" | grep -q "0 valid identities found"; then
  fail "no valid code-signing identity is installed"
elif printf '%s\n' "$identities" | grep -q "Apple Development:"; then
  pass "Apple Development code-signing identity is installed"
  if printf '%s\n' "$identities" | grep -q "Apple Distribution:"; then
    pass "Apple Distribution code-signing identity is installed"
  else
    warn "no Apple Distribution identity is installed yet; Xcode may create one during archive/upload"
  fi
elif printf '%s\n' "$identities" | grep -q "valid identities found"; then
  warn "code-signing identities exist, but no Apple Development identity was found"
else
  warn "could not determine code-signing identity state"
fi

devices_json="$(mktemp /tmp/stepreceipt-devices.XXXXXX)"
iphone_name=""
iphone_udid=""
iphone_developer_mode=""
iphone_ddi_services=""
if xcrun devicectl list devices --json-output "$devices_json" >/dev/null 2>&1; then
  for index in $(seq 0 20); do
    device_type="$(plutil -extract "result.devices.$index.hardwareProperties.deviceType" raw -o - "$devices_json" 2>/dev/null || true)"
    if [ "$device_type" = "iPhone" ]; then
      iphone_name="$(plutil -extract "result.devices.$index.deviceProperties.name" raw -o - "$devices_json" 2>/dev/null || true)"
      iphone_udid="$(plutil -extract "result.devices.$index.hardwareProperties.udid" raw -o - "$devices_json" 2>/dev/null || true)"
      iphone_developer_mode="$(plutil -extract "result.devices.$index.deviceProperties.developerModeStatus" raw -o - "$devices_json" 2>/dev/null || true)"
      iphone_ddi_services="$(plutil -extract "result.devices.$index.deviceProperties.ddiServicesAvailable" raw -o - "$devices_json" 2>/dev/null || true)"
      break
    fi
  done
fi
rm -f "$devices_json"

if [ -z "$iphone_udid" ]; then
  fail "no iPhone is connected or paired"
elif [ "$iphone_developer_mode" != "enabled" ] || [ "$iphone_ddi_services" != "true" ]; then
  fail "${iphone_name:-iPhone} is connected but Developer Mode/DDI is not ready"
elif [ -n "$iphone_udid" ]; then
  pass "devicectl sees ${iphone_name:-an iPhone} as development-ready"
else
  warn "could not determine connected device state"
fi

printf '\nRepository state\n'
if [ -z "$(git status --porcelain --untracked-files=normal)" ]; then
  pass "working tree has no uncommitted changes"
else
  warn "working tree has uncommitted changes"
fi

if command -v swift >/dev/null 2>&1; then
  printf '\nSwift package tests\n'
  if swift test --enable-swift-testing >/tmp/stepreceipt-swift-test.log 2>&1; then
    pass "swift test --enable-swift-testing"
  else
    fail "swift test --enable-swift-testing (see /tmp/stepreceipt-swift-test.log)"
  fi
fi

if git remote -v | grep -q .; then
  pass "a Git remote is configured"
else
  warn "no Git remote is configured; GitHub push remains separate from phone delivery"
fi

printf '\nLocal validation commands before archive\n'
printf '  swift run StepReceiptCoreCheck\n'
printf '  swift test --enable-swift-testing\n'
printf "  xcodebuild -project StepReceipt.xcodeproj -scheme StepReceipt -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' test\n"
printf "  xcodebuild -project StepReceipt.xcodeproj -scheme StepReceipt -configuration Debug -destination 'platform=iOS,id=<DEVICE_UDID>' -allowProvisioningUpdates -allowProvisioningDeviceRegistration build\n"
printf "  xcodebuild -project StepReceipt.xcodeproj -scheme StepReceipt -configuration Release -destination 'generic/platform=iOS' build CODE_SIGNING_ALLOWED=NO\n"

printf '\nSummary\n'
if [ "$failures" -eq 0 ]; then
  printf '[PASS] Device/TestFlight repo readiness checks passed'
  if [ "$warnings" -gt 0 ]; then
    printf ' with %s warning(s)' "$warnings"
  fi
  printf '.\n'
  exit 0
fi

printf '[FAIL] %s blocking check(s), %s warning(s).\n' "$failures" "$warnings"
exit 1
