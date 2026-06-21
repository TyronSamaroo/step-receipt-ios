# Development Log

A running log of implementation patterns and decisions across StrideSlip / StepReceipt plans. Reference this from future Codex sessions to repeat successful workflows.

## 2026-03-21 — Compete Tab Redesign and Household Competition Fix

### Problem
Household competition backend existed but two-phone sync was never validated. Compete UI buried setup above the leaderboard and sync errors were easy to miss.

### Root causes found
- **CloudKit schema drift:** code writes `HouseholdCompetitionBoard` + `CompetitionEntry`; docs referenced obsolete `CompetitionBoard`.
- **Wrong build path:** `LOCAL_NO_CLOUDKIT` / `com.tyronsamaroo.stepreceipt.local` cannot sync.
- **UX:** 10+ actions in one card; sample competitors looked real.

### Patterns used
1. **Phase router UI** — derive `CompeteBoardPhase` in core (`CompetitionBoardPhaseResolver`), route in `CompetitionView` to welcome vs leaderboard.
2. **Core-first models** — `HouseholdMember`, `CompeteBoardPhase` in `CompetitionModels.swift` with unit tests.
3. **Wizard sheet** — 3 steps (name → code → sync) instead of inline form.
4. **Leaderboard-first** — active board shows competition immediately; household settings in toolbar sheet.
5. **Actionable CloudKit errors** — `CloudKitCompetitionSync.friendlySyncMessage(for:)` maps `CKError` to user copy.
6. **Diagnostics without secrets** — `CompetitionSyncDiagnostics` exposes board state, member count, sync state; no invite codes in clipboard export.
7. **CKShare wiring** — `prepareHouseholdCompetitionShare()` → `UICloudSharingController` via `CloudKitShareSheet` (family invites).
8. **Two-device gate** — `Tools/validate-household-compete.sh` + updated runbook/schema doc.

### Key files
- Core: `Sources/StepReceiptCore/CompetitionModels.swift`
- Sync: `StepReceiptApp/Services/CloudKitCompetitionSync.swift`, `CompetitionSyncDiagnostics.swift`
- Repository: `ActivityRepository.competeBoardPhase`, `householdMembers`, `updateSharedCompetitionWithProfile`
- UI: `StepReceiptApp/Views/Compete/*`, `CompetitionView.swift`
- Docs: `Docs/CloudKitCompetitionSchema.md`

### Ship checklist
- Run `swift test --enable-swift-testing`
- Run `Tools/validate-household-compete.sh`
- Install **production** bundle to both phones
- Manual: same code, both sync, 2 members on leaderboard

## 2026-03-21 — Today, Compare, Insights Filters (PR #10)

### Patterns used
- **Parallel workstreams:** core engine → UI (Insights, Compare, Today) → tests → ship
- **Filter chip reuse:** `FilterChip` from Activity History in Insights trend strip
- **Comparison service in core:** `WorkoutComparisonService` testable without UI
- **Hero preservation:** Today changes only below `todayHero` (58pt steps / 114pt ring)

### Key files
- `InsightEngine.filteredPeriodSummary`, `WorkoutComparisonService`
- `InsightsView` trend filters + `StrengthDetailView`
- `WorkoutCompareView`, `WorkoutRouteMapView`
- `TodayView` coach top-2 + workout preview enrichments

## 2026-06-21 — Heart, Today Warmth, Cardio Split, and Dev Log

### Goal
Richer honest HR metrics, cardio vs stair separation, week-over-week comparison when data supports it, warmer Today screen.

### Patterns used
1. **HR from samples only** — `minHeartRateBPM`, range, dominant zone on `WorkoutActivity`; no resting HR/HRV.
2. **Cardio/stairs split** — `isMovementCardio` default in `cardioInsight`; `CardioSessionScope` chip in cardio detail.
3. **Honest week comparison** — `PeriodComparisonInsight` gates each metric; returns nil when prior week lacks data.
4. **Today de-noise** — welcome band with display name; hide idle Health sync card; remove default at-a-glance digest.
5. **Dev log** — this file for cross-plan Codex reference.

### Key files
- `ActivityModels.swift`, `InsightEngine.swift` (HR + `periodComparison`)
- `InsightsView.swift` (`WeekComparisonCard`, cardio HR row, session scope)
- `TodayView.swift`, `WorkoutDetailView.swift` (`HeartRatePanel` 3-stat grid)
- `ActivityRepository.weekComparison`, `AppViewPreferences.cardioSessionScope`

### Ship
- StepReceiptTests + StepReceiptUITests green
- PR merge + iPhone TT install

## 2026-06-21 — PR #10 Backfill + Cardio Polish Re-apply

### Goal
Re-apply the Heart/Today warm polish set on `codex/heart-today-cardio-polish` after backfilling PR #10 foundations.

### What shipped
- Core: `InsightEngine.cardioInsight` is public + scope-aware (movement default), now emits min/max HR; `periodComparison(current:prior:goals:)` added with prior-week gated metrics; workout compare now includes max HR delta.
- App: week-over-week comparison surfaced via `ActivityRepository.weekComparison(containing:)`; cardio scope preference persisted in `AppViewPreferences`.
- UI: Insights gained week comparison card, cardio min/max + zone mini bar, and cardio detail scope chips; Today reordered with welcome band, week pulse, cleaner health status behavior, and workout HR range pill; workout detail heart-rate panel now shows avg/min/max plus range + dominant zone.
- Tests: core and UI tests updated for movement-cardio default, cardio scopes, period comparison coverage, max-HR compare, welcome band, cardio scope chips, and HR min/max visibility.

## 2026-06-21 — Today Layout Refinement (Mockup-Driven)

### Problem
Today felt cluttered: redundant welcome card, week pulse too low, duplicate metric surfaces, and hourly chart/timetable split.

### Changes
1. **Weather strip** — top `metricCard()` with temp/feels-like and humidity columns (`today-weather-strip`).
2. **Hero polish** — accent date line, `X left to Y` goal copy, 4 pills (Distance · Active Burn · Avg HR · Workout), ProgressRing stroke 12pt with existing green→blue→orange gradient.
3. **Week Pulse** — compact chips directly under hero (Steps + Goal days).
4. **Day Flow** — merged hourly chart + timetable (`today-day-flow`).
5. **Workouts** — list with See all → Activity tab via `openActivityTab()`.
6. **Today at a Glance** — restored bottom 4-column grid with most-active window from `TodayQuickDigestBuilder`.

### Removed from Today scroll
- `welcomeBand`, `primaryWorkoutCard` (when list shown), `metricGrid`, standalone hourly/timetable cards.

### Key files
- `StepReceiptApp/Views/TodayView.swift`
- `Sources/StepReceiptCore/TodayQuickDigest.swift`
- `StepReceiptApp/Services/ActivityRepository.swift` (`openActivityTab`)
- `Tests/StepReceiptUITests/StepReceiptUITests.swift`

## 2026-06-21 — Today Hero Steps Layout Fix

### Problem
PR #12 put `"3,463 steps"` at 58pt beside the 114pt ring in an `HStack`, causing truncation (`3,463 st...`) and a right-aligned ring.

### Fix
Stack hero steps block vertically: full-width step headline, goal subtitle, then centered `ProgressRing` on its own row. UI test asserts step label ends with `steps` and has no ellipsis.

### Key files
- `StepReceiptApp/Views/TodayView.swift`
- `Tests/StepReceiptUITests/StepReceiptUITests.swift`

## 2026-06-21 — CloudKit Subscriptions, App Intents, and Watch Companion

### Goal
Live-ish household compete updates, Shortcuts discoverability, and a read-only Apple Watch glance without uploading raw HealthKit to CloudKit.

### Patterns used
1. **CKQuerySubscription on `CompetitionEntry`** — register when household board sync succeeds; silent push via `shouldSendContentAvailable`; remove on leave board.
2. **App delegate push bridge** — `StepReceiptAppDelegate` handles CloudKit remote notifications and calls `ActivityRepository.handleCompetitionCloudKitNotification()` without clearing cached entries on sync failure.
3. **Push only when board active** — `CompetitionPushRegistration.registerIfNeeded` calls `registerForRemoteNotifications()` after board enable/sync; `UIBackgroundModes` includes `remote-notification`.
4. **App Intents + Shortcuts** — `OpenCompeteIntent`, `SyncHouseholdBoardIntent`, `GetTodayStepsIntent` with `StepReceiptShortcuts` provider; repository bridge via `StepReceiptAppIntentsSupport`.
5. **Watch aggregate snapshot** — `WatchAggregateSnapshot` in shared folder; iPhone publishes via `WatchConnectivity.updateApplicationContext`; Watch shows steps, goal ring, compete rank/headline only.
6. **Privacy preserved** — no raw HealthKit samples on Watch CloudKit path; aggregates only.

### Key files
- Subscriptions: `CloudKitCompetitionSubscriptionService.swift`, `StepReceiptAppDelegate.swift`
- Intents: `StepReceiptApp/Intents/*`
- Watch: `StepReceiptWatchShared/WatchAggregateSnapshot.swift`, `WatchAggregateSyncService.swift`, `StepReceiptWatchExtension/*`
- Repository wiring: `ActivityRepository.syncSharedCompetition`, `publishWatchSnapshot`, `handleCompetitionCloudKitNotification`
- Tests: `CompetitionSubscriptionTests.swift`, `WatchAggregateSnapshotTests.swift`

### Manual setup
- Enable Push Notifications capability / `aps-environment` on the production App ID before TestFlight silent push works end-to-end.
- Pair Apple Watch with iPhone; open iPhone app once so WatchConnectivity context is seeded.
- CloudKit Dashboard must already have `CompetitionEntry.groupHash` queryable for subscriptions.

### Ship
- `xcodegen generate`
- `swift test --enable-swift-testing`
- `xcodebuild -project StepReceipt.xcodeproj -scheme StepReceipt -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' test`


## 2026-06-21 — Today Hero Balance + Coach Embed

### Problem
Stacked hero had left-aligned steps with a centered ring (visual imbalance). Week Pulse under hero competed with the briefing; Coach was too low in scroll.

### Fix
1. Center steps + goal subtitle + ring as one cluster; date controls stay above.
2. Embed top-2 Coach insights in hero footer (`today-hero-coach`); remove standalone Coach card.
3. Reorder: Weather → Hero → Day Flow → Workouts → Week Pulse → Glance.

### Key files
- `StepReceiptApp/Views/TodayView.swift`
- `Tests/StepReceiptUITests/StepReceiptUITests.swift`
