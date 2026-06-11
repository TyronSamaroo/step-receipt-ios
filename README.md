# StepReceipt

StepReceipt is a native SwiftUI iPhone app for daily movement, workout history, shareable activity receipts, and simple Apple Health insights.

Raw HealthKit samples stay on the device. CloudKit sync is limited to aggregate summaries, goals, preference-shaped app data, and opt-in household competition totals.

![StepReceipt onboarding](Docs/Screenshots/onboarding.png)

![StepReceipt today dashboard](Docs/Screenshots/today.png)

## Features

- Today dashboard with hourly steps, distance, active calories, flights, workouts, and goal progress.
- Date controls for reviewing previous days within the recent activity window.
- Activity history with scrollable daily summaries, day filters, sorting, and workout type filtering.
- Workout detail pages with duration, distance, burn, source, and share actions.
- Insight receipt with totals, best day, best month, daily average, streaks, and goal pacing.
- Share-card flow for workout and receipt snapshots.
- Competition tab with household-code sync, local friend check-ins, aggregate-only leaderboards, rank, and gap insight.
- Settings for display name, miles/kilometers, visible Today metrics, step goal, workout goal, and optional calorie goal.
- Sample preview mode for simulator runs, denied Health access, and public demo screenshots.

## Architecture

- `HealthKitClient` requests Health read authorization and queries steps, walking/running distance, active energy, flights climbed, and workouts.
- `HKStatisticsCollectionQuery` powers hourly and daily metric buckets.
- `ActivityRepository` normalizes HealthKit reads into app state, on-device derived summaries, receipts, household competition entries, local competition check-ins, and sample preview data.
- `InsightEngine` is pure Swift logic for daily aggregation, averages, best day/month, streaks, goal pacing, filters, and sync-record shaping.
- `CloudKitSummarySync` writes only daily aggregate records to the user's private CloudKit database.
- `CloudKitCompetitionSync` publishes and fetches an opt-in household competition board keyed by a hashed invite code.
- `StepReceiptCore` is shared by the app and tests so analytics can be validated without launching iOS.

See [Production Readiness](Docs/ProductionReadiness.md) for the current proof matrix and [TestFlight Runbook](Docs/TestFlightRunbook.md) for the iPhone, App Store Connect, and wife-install path.

## Privacy

This repo can be public without exposing personal activity data. It contains source code, generated sample screenshots, and a CloudKit container identifier, but it does not contain real HealthKit samples.

- Reads from HealthKit only after user consent.
- Does not write workouts or health samples in v1.
- Does not upload raw workouts, hourly buckets, or HealthKit samples.
- Syncs only `SyncedSummaryRecord`-style aggregate daily totals to the user's private CloudKit database.
- Shares only aggregate daily competition entries when a household code is enabled.
- Stores local friend competition check-ins as manually entered aggregate totals only.
- Includes a privacy manifest for required-reason API review.
- Keeps the app useful when HealthKit, iCloud, or individual metric permissions are unavailable.
- Caches the last derived dashboard data on device so a HealthKit refresh failure does not erase the real activity view.
- Treat household competition codes like invites; anyone using the same code can see aggregate leaderboard totals for that board.

## Requirements

- Xcode 26 or newer with iOS 17+ support.
- XcodeGen.
- iOS 17 minimum deployment target.
- Physical iPhone for real HealthKit validation.
- Apple Developer team for device signing, HealthKit capability, and CloudKit container setup.

Install XcodeGen with Homebrew if needed:

```bash
brew install xcodegen
```

## Run Locally

```bash
git clone <your-repo-url>
cd step-receipt-ios
xcodegen generate
open StepReceipt.xcodeproj
```

`StepReceipt.xcodeproj` is committed for convenience and can be regenerated from `project.yml`. If XcodeGen changes the project file, review the generated diff before committing it.

In Xcode, confirm the configured `U63TLL4JY4` Development Team, HealthKit capability, and iCloud/CloudKit capability, then run on a physical iPhone for real Apple Health data.

The simulator path is useful for UI work. Use **Preview Sample Data** on the onboarding screen to exercise the app without HealthKit data.

For the physical-device and wife TestFlight flow, follow [Docs/TestFlightRunbook.md](Docs/TestFlightRunbook.md).

### Temporary Personal-Team iPhone Proof

If the paid Apple Developer Program team becomes unavailable in Xcode, a free Xcode personal team can still run a local HealthKit-only proof on Tyron's connected iPhone:

```bash
Tools/install-local-personal-iphone.sh
```

This script uses bundle id `com.tyronsamaroo.stepreceipt.local`, `StepReceiptApp/StepReceipt.LocalPersonal.entitlements`, and the `LOCAL_NO_CLOUDKIT` build flag. It does not modify the production CloudKit/TestFlight entitlement file. Household CloudKit sync and wife TestFlight delivery still require the paid Apple Developer Program team.

## Fork Setup

Before shipping a fork or using a different Apple Developer account:

- Change the bundle identifier from `com.tyronsamaroo.stepreceipt`.
- Change the CloudKit container from `iCloud.com.tyronsamaroo.stepreceipt`.
- Set `DEVELOPMENT_TEAM` in Xcode or `project.yml`.
- Create/enable matching HealthKit and CloudKit capabilities for the selected team.

## Validation

These checks are the current local validation path:

```bash
Tools/device-testflight-readiness.sh
xcodegen generate
swift run StepReceiptCoreCheck
swift test --enable-swift-testing
xcodebuild -project StepReceipt.xcodeproj -scheme StepReceipt -destination 'platform=iOS Simulator,name=<installed iPhone simulator>' build
xcodebuild -project StepReceipt.xcodeproj -scheme StepReceipt -destination 'platform=iOS Simulator,name=<installed iPhone simulator>' build-for-testing
xcodebuild -project StepReceipt.xcodeproj -scheme StepReceipt -destination 'platform=iOS Simulator,name=<installed iPhone simulator>' test
```

The latest local validation used `platform=iOS Simulator,name=iPhone 17,OS=26.5`.

Real HealthKit and CloudKit behavior still need physical-device validation with the configured Apple Developer team.

`Tools/device-testflight-readiness.sh` intentionally fails until a valid signing identity exists and an iPhone is connected or paired. On this Mac, the current remaining blocker is the connected or paired iPhone.

GitHub Actions runs the same core, repository, typecheck, plist, asset, app build, test-bundle build, and Xcode unit-test checks on `macos-26` with Xcode 26.5. The simulator UI smoke test is available as a manual workflow dispatch option because UI automation can be slower and noisier in hosted CI.

## CloudKit Data Shape

Private summary sync stores only aggregate daily summaries:

| Field | Meaning |
| --- | --- |
| `dayKey` | Calendar day identifier |
| `dateStart` | Start of the summarized day |
| `steps` | Daily step total |
| `distanceMeters` | Daily walking/running distance total |
| `activeEnergyKilocalories` | Daily active energy total |
| `flightsClimbed` | Daily flights total |
| `workoutMinutes` | Daily workout duration total |
| `workoutCount` | Count of workouts touching the day |
| `stepGoal` | Step goal used for that summary |
| `updatedAt` | App sync timestamp |

Raw samples, hourly buckets, workout source IDs, and individual workout details are intentionally excluded.

Household competition sync uses the same aggregate privacy boundary: competitor profile, day key, steps, distance, active burn, workout minutes, and update time. It excludes buckets, workouts, source identifiers, workout details, and raw samples.

Local competition check-ins stay on device and remain available as an offline fallback.

CloudKit competition records use one public `CompetitionBoard` record per hashed household invite code. The board stores a compact aggregate JSON snapshot so both phones can fetch the same board by record ID without a CloudKit query index. The code is an invite secret for the household board, not a replacement for future CKShare-based private invites.

## Production Checklist

- Keep `DEVELOPMENT_TEAM` set to the selected Apple Developer team before device/App Store builds.
- Confirm the CloudKit container `iCloud.com.tyronsamaroo.stepreceipt` exists for the selected Apple Developer team.
- Confirm `StepReceiptApp/PrivacyInfo.xcprivacy` is included in the app target before archiving.
- Run on a physical iPhone to verify HealthKit permission prompts, partial Health permissions, and real step/workout reads.
- Verify iCloud disabled/offline behavior on device.
- Verify household-code competition sync on two Apple IDs before wife TestFlight acceptance.
- Prepare App Store privacy labels around HealthKit reads, private aggregate CloudKit sync, and opt-in aggregate competition totals.

## Roadmap

- Device-tested HealthKit onboarding and partial-permission handling.
- CKShare-based private friend invites and shared challenge zones.
- Widgets and lock-screen summaries.
- Exportable weekly and monthly receipt cards.
