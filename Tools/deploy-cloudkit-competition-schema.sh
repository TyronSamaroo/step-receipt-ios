#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

TEAM_ID="${CLOUDKIT_TEAM_ID:-U63TLL4JY4}"
CONTAINER_ID="${CLOUDKIT_CONTAINER_ID:-iCloud.com.tyronsamaroo.stepreceipt}"
ENVIRONMENT="${CLOUDKIT_SCHEMA_ENV:-development}"
SCHEMA_FILE="${CLOUDKIT_SCHEMA_FILE:-Tools/cloudkit-competition-schema.ckdb}"

printf 'StrideSlip CloudKit competition schema deploy\n'
printf '  Team:        %s\n' "$TEAM_ID"
printf '  Container:   %s\n' "$CONTAINER_ID"
printf '  Environment: %s\n' "$ENVIRONMENT"
printf '  Schema:      %s\n\n' "$SCHEMA_FILE"

if [ ! -f "$SCHEMA_FILE" ]; then
  printf '[FAIL] Missing schema file: %s\n' "$SCHEMA_FILE" >&2
  exit 1
fi

printf '[1/2] Validating schema...\n'
xcrun cktool validate-schema \
  --team-id "$TEAM_ID" \
  --container-id "$CONTAINER_ID" \
  --environment "$ENVIRONMENT" \
  --file "$SCHEMA_FILE"

printf '\n[2/2] Importing schema...\n'
xcrun cktool import-schema \
  --validate \
  --team-id "$TEAM_ID" \
  --container-id "$CONTAINER_ID" \
  --environment "$ENVIRONMENT" \
  --file "$SCHEMA_FILE"

printf '\n[PASS] CloudKit schema imported for %s. CompetitionEntry.groupHash is QUERYABLE in this schema file.\n' "$ENVIRONMENT"
