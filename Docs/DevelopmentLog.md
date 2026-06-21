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
