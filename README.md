# StrideSlip

StrideSlip is a native SwiftUI iPhone app that turns Apple Health activity into a clean daily receipt: steps, calories, distance, workouts, heart-rate context, goal pacing, and lightweight household competition.

The codebase and bundle identifiers still use the original working name, `StepReceipt`, to preserve the existing Apple Developer, HealthKit, CloudKit, and TestFlight setup:

- App display direction: `StrideSlip`
- Xcode scheme/project: `StepReceipt`
- Bundle ID: `com.tyronsamaroo.stepreceipt`
- Minimum deployment target: iOS 17
- Current development version: `0.1.0`

## Screenshots

| Onboarding | Today |
| --- | --- |
| ![StepReceipt onboarding](Docs/Screenshots/onboarding.png) | ![StepReceipt Today dashboard](Docs/Screenshots/today.png) |

## Why This Exists

Apple Health has the raw data, but it is not always the easiest place to answer everyday questions:

- How many steps did I get today, hour by hour?
- Did I move enough for the day, week, or month?
- What workouts did I actually do most often?
- How hard was that stair stepper or strength session?
- What can I share without exposing private Health data?
- How are Tiffany and I doing against each other in a simple household challenge?

StrideSlip is built around that personal loop. It reads HealthKit, keeps raw samples on the phone, and turns the useful parts into a faster daily dashboard, activity history, receipt cards, and insights.

## Product Tour

### Today

- Colorful hero view for the selected day.
- Steps, goal progress, distance, active calories, flights, and workout minutes.
- Hourly step timetable for seeing when movement happened.
- Weather context from workout metadata when available, displayed in Fahrenheit.
- Today Coach card with goal pacing, weekday context, recent workout context, and household competition hints.
- Tap-through workout preview for the most relevant workout of the day.
- Share button for a day-level activity receipt.

### Activity

- Scrollable day history with daily summaries.
- Workouts list with filters tuned for the workouts used most often:
  - Stair stepper
  - Strength training
  - Outdoor walk
  - Indoor walk
  - Other
- Day drill-in with daily totals and clickable workouts.
- Workout tag support for general training labels such as Push Day, Pull Day, Leg Day, Stair Session, Outdoor Walk, and Indoor Walk.

### Workout Details

- Compact metric grid for duration, distance, active energy, total energy, steps, pace, effort, and weather when present.
- Heart-rate summary with average and max BPM.
- Heart-rate chart and time-in-zone breakdown.
- Workout-specific share cards:
  - Strength training emphasizes duration, active energy, effort, average HR, max HR, and top zone.
  - Stair stepper emphasizes duration, active energy, effort, burn rate, total energy, and HR zones.
  - Outdoor and indoor walks emphasize distance, pace, steps, active energy, HR, weather, and route context where available.
- Outdoor route-map support for HealthKit route data, while keeping route points out of synced aggregate records.

### Insights

- Receipt-style analytics for today, week, and month.
- Best day, best month, daily average, streaks, totals, and goal pacing.
- Weekly and monthly summaries for spotting trends.
- Activity heat map and daily timeline style views for scanning consistency.
- Pure Swift analytics engine with tests around aggregation, averages, projections, filters, sync shape, and date-boundary behavior.

### Compete

- Household competition board for simple Tyron/Tiffany style challenges.
- Invite-code and clipboard join flows.
- Rank, gap, and daily aggregate leaderboard views.
- Local check-ins for offline/manual fallback.
- CloudKit sync intentionally limited to aggregate competition totals.

### Settings

- Display name and goal customization.
- Step goal, weekly workout-minute goal, optional active-calorie goal.
- Distance unit preference.
- Theme controls, with light theme as the default direction.
- Today metric customization.
- Live Activity controls kept in Settings instead of taking over the main screen.
- CloudKit and HealthKit fallback states so the app remains useful with partial permissions or iCloud disabled.

## Apple Frameworks

StrideSlip is intentionally native and Apple-platform first:

| Framework | Use |
| --- | --- |
| SwiftUI | Main app UI, navigation, settings, cards, and share surfaces |
| HealthKit | Read-only source of truth for steps, walking/running distance, active energy, flights, workouts, heart rate, and routes |
| Swift Charts | Step timelines and workout/insight visuals |
| ActivityKit | Daily step-goal Live Activity |
| WidgetKit | Live Activity widget extension |
| CloudKit | Private aggregate summary sync and opt-in household competition board |
| MapKit | Outdoor route-map presentation for workouts with route data |
| XCTest / Swift Testing | Core analytics, repository behavior, and UI smoke coverage |

## Privacy Model

This repository is safe to keep public because it contains source code, sample screenshots, docs, and project configuration. It does not contain Tyron's, Tiffany's, or any user's Apple Health data.

StrideSlip's runtime privacy model:

- Reads Apple Health only after the user grants HealthKit permission.
- Does not write workouts or Health samples in v1.
- Keeps raw HealthKit samples on the iPhone.
- Keeps individual workout details, hourly buckets, source names, and source identifiers out of CloudKit sync records.
- Keeps route points local to workout display and excludes them from aggregate sync records.
- Syncs private CloudKit daily summaries as aggregate totals only.
- Syncs household competition rows as aggregate totals only.
- Treats household invite codes like shared secrets for the beta competition board.
- Remains usable when HealthKit, individual Health permissions, iCloud, or CloudKit are unavailable.

See [Docs/PrivacyPolicy.md](Docs/PrivacyPolicy.md) for the app-facing privacy policy draft.

## Architecture

The app is split into a small core analytics package and SwiftUI app surfaces.

```text
HealthKit
  -> HealthKitClient
  -> ActivityRepository
  -> StepReceiptCore / InsightEngine
  -> SwiftUI views, receipts, widgets, and share cards

CloudKit
  -> CloudKitSummarySync
  -> CloudKitCompetitionSync
  -> aggregate-only records
```

Key pieces:

| Area | Files |
| --- | --- |
| App shell | `StepReceiptApp/App` |
| Theme and symbols | `StepReceiptApp/Design` |
| HealthKit, repository, CloudKit, Live Activity services | `StepReceiptApp/Services` |
| Today, Activity, Compete, Insights, Settings, workout details, share cards | `StepReceiptApp/Views` |
| Pure models and analytics | `Sources/StepReceiptCore` |
| Live Activity shared attributes | `StepReceiptLiveActivityShared` |
| Live Activity widget | `StepReceiptLiveActivityWidget` |
| Tests | `Tests` |
| Device/TestFlight scripts | `Tools` |
| Release docs | `Docs` |

Core types include:

- `HealthMetricBucket`
- `WorkoutActivity`
- `DailyActivitySummary`
- `InsightReceipt`
- `PeriodActivitySummary`
- `TodayCoachInsight`
- `UserGoals`
- `SyncedSummaryRecord`
- `CompetitionReceipt`
- `WorkoutTemplate`

## Data Shape

Private summary sync stores aggregate daily totals:

| Field | Meaning |
| --- | --- |
| `dayKey` | Calendar day identifier |
| `dateStart` | Start of summarized day |
| `steps` | Daily step total |
| `distanceMeters` | Daily walking/running distance total |
| `activeEnergyKilocalories` | Daily active-energy total |
| `flightsClimbed` | Daily flights total |
| `workoutMinutes` | Total workout duration touching the day |
| `workoutCount` | Count of workouts touching the day |
| `stepGoal` | Step goal used for the summary |
| `updatedAt` | App sync timestamp |

Excluded from sync:

- Raw HealthKit samples
- Hourly buckets
- Individual workout details
- Workout source IDs and source names
- Heart-rate sample streams
- Route points

## Requirements

- macOS with Xcode 26 or newer
- iOS 17+ simulator or physical iPhone
- XcodeGen
- Apple Developer team for HealthKit, CloudKit, physical-device signing, and TestFlight
- Physical iPhone for real HealthKit validation

Install XcodeGen:

```bash
brew install xcodegen
```

## Local Setup

```bash
git clone https://github.com/TyronSamaroo/step-receipt-ios.git
cd step-receipt-ios
xcodegen generate
open StepReceipt.xcodeproj
```

The generated Xcode project is committed for convenience, but `project.yml` is the source of truth. If XcodeGen changes the project file, review the generated diff before committing it.

For simulator UI work, use the app's sample preview path. The simulator cannot provide real Apple Health data.

## Run On iPhone

1. Open `StepReceipt.xcodeproj`.
2. Confirm signing uses the configured Apple Developer team.
3. Confirm these capabilities are present:
   - HealthKit
   - iCloud with CloudKit
   - Live Activities / widget extension support
4. Connect or pair an iPhone.
5. Trust the Mac and enable Developer Mode when iOS asks.
6. Run the `StepReceipt` scheme on the physical device.
7. Grant Health permissions for steps, distance, active energy, flights, workouts, and heart rate if available.

Scripted production-device install:

```bash
Tools/install-production-iphone.sh
```

Temporary personal-team local proof, without CloudKit:

```bash
Tools/install-local-personal-iphone.sh
```

The personal-team path uses `com.tyronsamaroo.stepreceipt.local` and `LOCAL_NO_CLOUDKIT`. It is useful for local HealthKit proof only; it is not the TestFlight path.

## Validation

Core local checks:

```bash
xcodegen generate
swift run StepReceiptCoreCheck
swift test --enable-swift-testing
```

Simulator build/test checks:

```bash
xcodebuild \
  -project StepReceipt.xcodeproj \
  -scheme StepReceipt \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' \
  build

xcodebuild \
  -project StepReceipt.xcodeproj \
  -scheme StepReceipt \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' \
  test
```

Device/TestFlight readiness gate:

```bash
Tools/device-testflight-readiness.sh
```

GitHub Actions runs core checks, repository typecheck, plist/asset validation, app build, test-bundle build, and Xcode unit tests on macOS with Xcode 26.5. The UI smoke test is available as a manual workflow dispatch option.

## TestFlight And Release Notes

The TestFlight path is documented, but this app is still a beta and should be treated as personal/family testing software until the device, CloudKit, and privacy gates are fully revalidated.

Useful release docs:

- [Production Readiness](Docs/ProductionReadiness.md)
- [TestFlight Runbook](Docs/TestFlightRunbook.md)
- [App Store Connect Submission Notes](Docs/AppStoreConnectSubmission.md)
- [Privacy Policy](Docs/PrivacyPolicy.md)

Forking or shipping under another Apple Developer account requires changing:

- Bundle identifier
- CloudKit container
- Development team
- HealthKit and iCloud capabilities
- App Store Connect app record

## Current Status

Implemented:

- Native SwiftUI iPhone app shell
- HealthKit read path
- Today dashboard and hero experience
- Activity history and workout filters
- Workout drill-ins, tags, heart-rate charts, HR zones, route support, and share cards
- Insights receipts for today/week/month
- Today Coach personalization
- Settings, theme controls, goals, units, visible metrics, and Live Activity controls
- Household competition beta with aggregate-only CloudKit sync
- TestFlight and device-install runbooks
- CI workflow and local validation suite

Still beta / follow-up:

- Real HealthKit acceptance should be repeated on every release build.
- CloudKit household competition needs continued two-device validation.
- TestFlight external beta flow depends on Apple beta review state.
- CKShare-style private invites are a future improvement over household-code boards.
- A license has not been selected yet, so treat the repository as source-visible rather than open-source reusable.

## Roadmap

- Better weekly and monthly receipt cards.
- Richer trend filters by day, week, month, workout type, and goal status.
- More personalized Today Coach insights.
- Cleaner route maps and workout comparisons.
- CKShare-based household/friend invitations.
- Lock Screen widgets beyond the current Live Activity.
- Optional export packages for coach check-ins or social sharing.

## License

No license has been selected yet.

Until a license is added, the code is public for review and portfolio visibility but is not granted for reuse, redistribution, or derivative work.
