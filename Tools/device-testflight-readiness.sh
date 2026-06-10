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
elif printf '%s\n' "$identities" | grep -q "valid identities found"; then
  pass "at least one code-signing identity is installed"
else
  warn "could not determine code-signing identity state"
fi

devices="$(xcrun devicectl list devices 2>/dev/null || true)"
if printf '%s\n' "$devices" | grep -q "No devices found"; then
  fail "no iPhone is connected or paired"
elif [ -n "$devices" ]; then
  pass "devicectl sees at least one device"
else
  warn "could not determine connected device state"
fi

printf '\nRepository state\n'
if [ -z "$(git status --porcelain --untracked-files=normal)" ]; then
  pass "working tree has no uncommitted changes"
else
  warn "working tree has uncommitted changes"
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
