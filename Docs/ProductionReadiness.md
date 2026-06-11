# Production Readiness

StepReceipt is usable on simulator with sample preview data and has a real HealthKit/CloudKit integration path. It is not production-complete until device-only gates are verified with the final Apple Developer team.

## Current Evidence

| Area | Status | Evidence |
| --- | --- | --- |
| Native iPhone app shell | Verified locally | Xcode project builds on iPhone 17 simulator |
| Today timeline | Verified with sample preview | UI smoke test reaches Today and confirms hourly steps |
| Activity history and filters | Verified with sample preview | UI smoke test reaches Activity and applies a filter |
| Insights receipt | Verified with unit and UI tests | Core receipt tests plus UI smoke test |
| Workout details and sharing | Implemented | SwiftUI workout detail and share sheet views |
| Goals and customization | Implemented | Settings view persists goals, distance unit, name, and visible metrics |
| Competition | Household-code beta implemented, device validation pending | Aggregate-only leaderboard models, household code sync, local friend check-ins, rank/gap UI, and persistence tests |
| Analytics correctness | Verified locally | Swift Testing suite covers aggregation, averages, streaks, filters, projections, and sync shape |
| Repository resilience | Verified with fakes | Xcode unit tests cover iCloud sync outage, duplicate daily summary merge behavior, and cached derived data fallback |
| HealthKit read path | Implemented, device validation pending | `HealthKitClient` requests read-only authorization and queries metrics/workouts |
| CloudKit private sync | Implemented, account validation pending | `CloudKitSummarySync` writes aggregate daily summaries only; fake tests cover unavailable sync |
| Household competition sync | Implemented with fakes, account validation pending | `CloudKitCompetitionSync` sends aggregate competition board snapshots only; tests cover wife row merge and sync failure fallback |
| Privacy manifest | Implemented locally | `StepReceiptApp/PrivacyInfo.xcprivacy` declares the UserDefaults required-reason API reason |
| TestFlight runbook | Ready for device handoff | `Docs/TestFlightRunbook.md` captures the configured Apple team, iPhone proof, archive, and Family Beta path |
| Device/TestFlight readiness gate | Implemented locally | `Tools/device-testflight-readiness.sh` verifies local toolchain, plist shape, entitlements, signing identity, connected device, and repo state |
| Public GitHub readiness | Ready locally | Clean Git history, README, sample screenshots, CI workflow |

## Gates Before Calling It Production

- Run on a physical iPhone with real Apple Health data.
- Confirm HealthKit prompts for steps, walking/running distance, active energy, flights climbed, and workouts.
- Test partial Health permissions and denied Health access.
- Confirm the configured Apple Developer Team signs successfully on device.
- Confirm `iCloud.com.tyronsamaroo.stepreceipt` exists for that team.
- Keep `DEVELOPMENT_TEAM` aligned between `project.yml`, the generated Xcode project, and the selected Apple Developer team.
- Verify CloudKit behavior when iCloud is available, disabled, offline, and later restored.
- Confirm CloudKit records contain only private aggregate daily summaries and opt-in household competition totals.
- Add real CloudKit account/device coverage after the container is configured.
- Validate household-code competition sync with Tyron and Tiffany Apple IDs before treating wife competition as complete.
- Deploy/verify the CloudKit development schema for public `CompetitionBoard` records before TestFlight acceptance.
- Complete the TestFlight path in `Docs/TestFlightRunbook.md`, including the `Family Beta` external tester group.
- Decide repository license before presenting the public repo as open source.
- Decide when to graduate local/manual competition into real friend sharing.

## Explicit Non-Goals For V1

- Writing HealthKit samples or workouts.
- Uploading raw HealthKit samples, hourly buckets, workout source IDs, or individual workout details.
- CKShare-based private invites before the first household-code beta proves the end-to-end competition loop.
- App Store release before privacy labels, device testing, and signing are complete.
