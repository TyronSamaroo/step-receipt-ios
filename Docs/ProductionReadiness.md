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
| Competition | V1 scaffold | Aggregate-only leaderboard models, engine, and tab |
| Analytics correctness | Verified locally | Swift Testing suite covers aggregation, averages, streaks, filters, projections, and sync shape |
| Repository resilience | Verified with fakes | Xcode unit tests cover iCloud sync outage and duplicate daily summary merge behavior |
| HealthKit read path | Implemented, device validation pending | `HealthKitClient` requests read-only authorization and queries metrics/workouts |
| CloudKit private sync | Implemented, account validation pending | `CloudKitSummarySync` writes aggregate daily summaries only; fake tests cover unavailable sync |
| Public GitHub readiness | Ready locally | Clean Git history, README, sample screenshots, CI workflow |

## Gates Before Calling It Production

- Run on a physical iPhone with real Apple Health data.
- Confirm HealthKit prompts for steps, walking/running distance, active energy, flights climbed, and workouts.
- Test partial Health permissions and denied Health access.
- Set a real Apple Developer Team and confirm signing works on device.
- Confirm `iCloud.com.tyronsamaroo.stepreceipt` exists for that team.
- Verify CloudKit behavior when iCloud is available, disabled, offline, and later restored.
- Confirm CloudKit records contain only aggregate daily summaries.
- Add real CloudKit account/device coverage after the container is configured.
- Decide repository license before presenting the public repo as open source.
- Decide whether v1 competition remains local/sample-based or moves to real friend sharing.

## Explicit Non-Goals For V1

- Writing HealthKit samples or workouts.
- Uploading raw HealthKit samples, hourly buckets, workout source IDs, or individual workout details.
- Real shared leaderboards before CloudKit sharing and privacy rules are designed.
- App Store release before privacy labels, device testing, and signing are complete.
