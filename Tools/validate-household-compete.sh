#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

printf 'StrideSlip household compete validation\n\n'

project_value() {
  awk -F': ' -v key="$1" '$1 ~ key { gsub(/"/, "", $2); print $2; exit }' project.yml
}

BUNDLE_ID="$(project_value PRODUCT_BUNDLE_IDENTIFIER)"
failures=0

check() {
  if eval "$2"; then
    printf '[PASS] %s\n' "$1"
  else
    printf '[FAIL] %s\n' "$1"
    failures=$((failures + 1))
  fi
}

check "production bundle id" "[ \"$BUNDLE_ID\" = \"com.tyronsamaroo.stepreceipt\" ]"
check "CloudKit schema doc exists" "[ -f Docs/CloudKitCompetitionSchema.md ]"
check "schema doc mentions HouseholdCompetitionBoard" "grep -q HouseholdCompetitionBoard Docs/CloudKitCompetitionSchema.md"
check "schema doc mentions CompetitionEntry" "grep -q CompetitionEntry Docs/CloudKitCompetitionSchema.md"
check "runbook matches code record types" "grep -q HouseholdCompetitionBoard Docs/TestFlightRunbook.md"
check "stepreceipt URL scheme registered" "grep -q stepreceipt StepReceiptApp/Info.plist"
check "CompeteJoinDeepLink helper exists" "[ -f Sources/StepReceiptCore/CompeteJoinDeepLink.swift ]"
check "CKShare acceptance in app delegate" "grep -q userDidAcceptCloudKitShareWith StepReceiptApp/App/StepReceiptAppDelegate.swift"
check "join confirmation sheet exists" "[ -f StepReceiptApp/Views/Compete/CompeteJoinConfirmationSheet.swift ]"
check "compete diagnostics sheet exists" "[ -f StepReceiptApp/Views/Compete/CompeteDiagnosticsSheet.swift ]"

printf '\nManual two-phone checklist\n'
printf '  1. Both phones use production bundle com.tyronsamaroo.stepreceipt (not .local / LOCAL_NO_CLOUDKIT).\n'
printf '  2. Both phones are signed into iCloud.\n'
printf '  3. Both phones granted Apple Health access.\n'
printf '  4. Deploy CloudKit public schema from Docs/CloudKitCompetitionSchema.md.\n'
printf '  5. Tyron: Compete > Start board > Sync > Invite partner (Messages link).\n'
printf '  6. Tiffany (Path A): tap stepreceipt://compete/join link > confirm join > Sync.\n'
printf '  7. Tyron (Path B alt): Invite via iCloud > Tiffany accepts CKShare > confirm join.\n'
printf '  8. Both leaderboards show 2 members after refresh.\n'
printf '  9. Compete diagnostics (household sheet or needs-attention card) shows Members: 2.\n'
printf ' 10. Settings > Copy Diagnostics shows Household Members: 2.\n'

if [ "$failures" -eq 0 ]; then
  printf '\n[PASS] Automated household compete checks passed.\n'
  exit 0
fi

printf '\n[FAIL] %s automated check(s) failed.\n' "$failures"
exit 1
