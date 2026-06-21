import CloudKit
import Combine
import CoreLocation
import Foundation
#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class ActivityRepository: ObservableObject {
    @Published var authorizationState: HealthAuthorizationState = .notDetermined
    @Published var cloudSyncState: CloudSyncState = .unknown
    @Published var selectedDate: Date = Date()
    @Published var dayWeather: DayWeatherSnapshot?
    @Published var dayWeatherDetail: DayWeatherDetail?
    @Published private(set) var isLoadingDayWeather = false
    @Published private(set) var isLoadingWeatherDetail = false
    @Published private(set) var weatherNeedsLocation = false
    @Published private(set) var weatherKitUnavailable = false
    @Published private(set) var weatherKitJWTAuthFailed = false
    @Published var todaySummary: DailyActivitySummary?
    @Published var history: [DailyActivitySummary] = []
    @Published var workouts: [WorkoutActivity] = []
    @Published var receipt: InsightReceipt?
    @Published var competitionReceipt: CompetitionReceipt?
    @Published private(set) var activityNavigationToken = UUID()
    @Published private(set) var competeBoardPhase: CompeteBoardPhase = .setup
    @Published private(set) var householdMembers: [HouseholdMember] = []
    @Published private(set) var isShowingSampleCompetitionBoard = false
    @Published private(set) var competeNavigationToken = UUID()
    @Published private(set) var pendingCompeteJoin: CompeteJoinRequest?
    @Published var competitionMetric: CompetitionMetric = .steps {
        didSet {
            refreshCompetition()
        }
    }
    @Published var competitionWindow: CompetitionWindow = .week {
        didSet {
            refreshCompetition()
        }
    }
    @Published var localCompetitors: [CompetitorProfile] {
        didSet {
            saveLocalCompetitors()
            refreshCompetition()
        }
    }
    @Published var localCompetitionCheckIns: [LocalCompetitionCheckIn] {
        didSet {
            saveLocalCompetitionCheckIns()
            refreshCompetition()
        }
    }
    @Published var sharedCompetitionSettings: SharedCompetitionSettings {
        didSet {
            saveSharedCompetitionSettings()
            refreshCompetition()
        }
    }
    @Published private(set) var workoutTags: [String: String] {
        didSet {
            saveWorkoutTags()
        }
    }
    @Published private(set) var sharedCompetitionEntries: [CompetitionEntry] = [] {
        didSet {
            refreshCompetition()
        }
    }
    @Published var sharedCompetitionSyncState: CompetitionSyncState = .off
    @Published var preferences: UserPreferences {
        didSet {
            savePreferences()
            refreshCompetition()
        }
    }
    @Published var goals: UserGoals {
        didSet {
            saveGoals()
            refreshDerivedState()
        }
    }
    @Published private(set) var liveActivityStatus: DailyStepGoalLiveActivityStatus = .inactive
    @Published private(set) var healthRefreshStatus = HealthRefreshStatus()
    @Published private(set) var healthBackgroundDeliveryState: HealthBackgroundDeliveryState = .notConfigured
    @Published private(set) var isRepairingHealthSync = false
    @Published var isLoading = false
    @Published var lastError: String?

    let historyLookbackDays = 90

    private let healthKit: any HealthKitProviding
    private let cloudKit: any CloudKitSummarySyncing
    private let weatherKit: any WeatherKitProviding
    private let locationProvider: any LocationProviding
    private let competitionSync: any SharedCompetitionSyncing
    private let competitionSubscription: any CompetitionSubscriptionManaging
    private let watchSync: any WatchAggregatePublishing
    private let liveActivityService: any DailyStepGoalLiveActivityServicing
    private let engine: InsightEngine
    private let workoutComparisonService: WorkoutComparisonService
    private let competitionEngine: CompetitionEngine
    private let calendar: Calendar
    private let userDefaults: UserDefaults
    private let authorizationRequestedKey = "stepReceipt.healthAuthorizationRequested.v1"
    private let samplePreviewEnabledKey = "stepReceipt.samplePreviewEnabled.v1"
    private let competitorIDKey = "stepReceipt.currentCompetitorID.v1"
    private let goalsKey = "stepReceipt.goals.v1"
    private let preferencesKey = "stepReceipt.preferences.v1"
    private let preferencesDefaultThemeMigratedKey = "stepReceipt.preferencesDefaultThemeMigrated.v1"
    private let localCompetitorsKey = "stepReceipt.localCompetitors.v1"
    private let localCompetitionCheckInsKey = "stepReceipt.localCompetitionCheckIns.v1"
    private let sharedCompetitionSettingsKey = "stepReceipt.sharedCompetitionSettings.v1"
    private let workoutTagsKey = "stepReceipt.workoutTags.v1"
    private let activityCacheKey = "stepReceipt.derivedActivityCache.v1"
    private let healthBackgroundDeliveryConfiguredAtKey = "stepReceipt.healthBackgroundDeliveryConfiguredAt.v1"
    private let currentCompetitorID: UUID
    private var activityDataSource: ActivityDataSource = .none
    private var hasConfiguredActivityBackgroundDeliveryForSession = false
    private var isRefreshingFromBackgroundDelivery = false

    private var workoutWeatherSources: [String: WeatherDataSource] = [:]
    private var workoutWeatherBackfills: [String: DayWeatherSnapshot] = [:]

    init(
        healthKit: any HealthKitProviding = HealthKitClient(),
        cloudKit: any CloudKitSummarySyncing = CloudKitSummarySync(),
        weatherKit: any WeatherKitProviding = DisabledWeatherKitClient(),
        locationProvider: any LocationProviding = DisabledLocationProvider(),
        competitionSync: any SharedCompetitionSyncing = CloudKitCompetitionSync(),
        competitionSubscription: any CompetitionSubscriptionManaging = DisabledCompetitionSubscriptionService(),
        watchSync: any WatchAggregatePublishing = WatchAggregateSyncService.shared,
        liveActivityService: any DailyStepGoalLiveActivityServicing = DailyStepGoalLiveActivityService(),
        calendar: Calendar = .current,
        userDefaults: UserDefaults = .standard
    ) {
        let activityCalendar = Self.mondayFirstCalendar(calendar)
        self.healthKit = healthKit
        self.cloudKit = cloudKit
        self.weatherKit = weatherKit
        self.locationProvider = locationProvider
        self.competitionSync = competitionSync
        self.competitionSubscription = competitionSubscription
        self.watchSync = watchSync
        self.liveActivityService = liveActivityService
        self.calendar = activityCalendar
        self.userDefaults = userDefaults
        self.engine = InsightEngine(calendar: activityCalendar)
        self.workoutComparisonService = WorkoutComparisonService(calendar: activityCalendar)
        self.competitionEngine = CompetitionEngine(calendar: activityCalendar)
        self.goals = Self.loadGoals(key: goalsKey, userDefaults: userDefaults)
        self.preferences = Self.loadPreferences(
            key: preferencesKey,
            defaultThemeMigratedKey: preferencesDefaultThemeMigratedKey,
            userDefaults: userDefaults
        )
        self.workoutTags = Self.loadWorkoutTags(key: workoutTagsKey, userDefaults: userDefaults)
        self.localCompetitors = Self.loadLocalCompetitors(key: localCompetitorsKey, userDefaults: userDefaults)
        self.localCompetitionCheckIns = Self.loadLocalCompetitionCheckIns(key: localCompetitionCheckInsKey, userDefaults: userDefaults)
        self.sharedCompetitionSettings = Self.loadSharedCompetitionSettings(key: sharedCompetitionSettingsKey, userDefaults: userDefaults)
        self.currentCompetitorID = Self.loadCompetitorID(key: competitorIDKey, userDefaults: userDefaults)
        self.sharedCompetitionSyncState = sharedCompetitionSettings.canSync ? .idle : .off
        self.liveActivityStatus = liveActivityService.status
        self.healthBackgroundDeliveryState = Self.loadHealthBackgroundDeliveryState(
            key: healthBackgroundDeliveryConfiguredAtKey,
            userDefaults: userDefaults
        )
    }

    func bootstrap() async {
        resetDefaultsForUITestingIfNeeded()
        applyUITestingCompeteJoinCodeIfNeeded()
        if isUITestingSampleDataEnabled {
            authorizationState = .authorized
            loadSampleData()
            await syncSharedCompetition()
            return
        }

        cloudSyncState = await cloudKit.status()

        if !healthKit.isAvailable {
            authorizationState = .unavailable
            loadCachedDataOrEmpty()
            await syncSharedCompetition()
            return
        }

        guard hasRequestedHealthAuthorization else {
            if isSamplePreviewEnabled {
                authorizationState = .deniedOrLimited
                loadSampleData()
                await syncSharedCompetition()
                return
            }
            authorizationState = .notDetermined
            loadCachedDataOrEmpty()
            await syncSharedCompetition()
            return
        }

        await refresh()
        await configureActivityBackgroundDeliveryIfPossible()
    }

    func requestHealthAccess() async {
        disableSamplePreview()
        markHealthAuthorizationRequested()

        do {
            let state = try await healthKit.requestAuthorization()
            authorizationState = state
            guard state == .authorized else {
                loadCachedDataOrEmpty()
                return
            }

            await configureActivityBackgroundDeliveryIfPossible()
            await refresh()
        } catch {
            authorizationState = .deniedOrLimited
            lastError = error.localizedDescription
            loadCachedDataOrEmpty()
        }
    }

    func configureHealthObserversOnLaunch() async {
        guard healthKit.isAvailable, hasRequestedHealthAuthorization else {
            return
        }

        await configureActivityBackgroundDeliveryIfPossible()
    }

    func repairHealthSync() async {
        guard !isRepairingHealthSync else { return }

        isRepairingHealthSync = true
        defer { isRepairingHealthSync = false }

        liveActivityStatus = liveActivityService.status

        guard healthKit.isAvailable else {
            authorizationState = .unavailable
            healthBackgroundDeliveryState = .unavailable("Apple Health is unavailable on this iPhone.")
            loadCachedDataOrEmpty()
            return
        }

        if !hasRequestedHealthAuthorization || authorizationState != .authorized {
            await requestHealthAccess()
        }

        guard authorizationState == .authorized else {
            healthBackgroundDeliveryState = .unavailable("Open iPhone Settings and allow StepReceipt to read Apple Health.")
            loadCachedDataOrEmpty()
            return
        }

        let shouldForceBackgroundRepair: Bool
        if case .unavailable = healthBackgroundDeliveryState {
            shouldForceBackgroundRepair = true
        } else {
            shouldForceBackgroundRepair = false
        }

        await configureActivityBackgroundDeliveryIfPossible(force: shouldForceBackgroundRepair)
        await refresh()

        if !calendar.isDateInToday(selectedDate) {
            await refreshCurrentDayForLiveActivity()
        }
    }

    func previewWithSampleData() {
        enableSamplePreview()
        authorizationState = .deniedOrLimited
        lastError = nil
        loadSampleData()
    }

    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        healthRefreshStatus = healthRefreshStatus.refreshing(startedAt: Date())
        defer { isLoading = false }

        let now = Date()
        let selectedDate = normalizedActivityDate(self.selectedDate, now: now)
        self.selectedDate = selectedDate
        let previousHistory = history
        let previousSummary = todaySummary
        let previousWorkouts = workouts
        let historyEnd = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now.addingTimeInterval(86_400)
        let defaultHistoryStart = calendar.date(byAdding: .day, value: -historyLookbackDays, to: historyEnd) ?? historyEnd.addingTimeInterval(-Double(historyLookbackDays) * 86_400)
        let historyStart = min(defaultHistoryStart, selectedDate)

        async let todayFetch = fetchHealthValue(label: "Hourly Apple Health activity") {
            try await healthKit.fetchHourlyBuckets(for: selectedDate)
        }
        async let dailyFetch = fetchHealthValue(label: "Daily Apple Health history") {
            try await healthKit.fetchDailyBuckets(daysBack: historyLookbackDays, endingAt: now)
        }
        async let workoutsFetch = fetchHealthValue(label: "Apple Health workouts") {
            try await healthKit.fetchWorkouts(startDate: historyStart, endDate: historyEnd)
        }

        let fetches = await (today: todayFetch, daily: dailyFetch, workouts: workoutsFetch)
        let fetchErrors = [fetches.today.errorDescription, fetches.daily.errorDescription, fetches.workouts.errorDescription]
            .compactMap { $0 }

        if didReturnNoReadableHealthData(fetches: fetches) {
            let loadedCache = loadCachedActivityData()
            if loadedCache {
                let issue = "Apple Health returned no readable activity. Keeping saved data; check Health permissions if this stays wrong."
                authorizationState = .authorized
                lastError = issue
                healthRefreshStatus = healthRefreshStatus.completed(
                    outcome: .cached,
                    completedAt: Date(),
                    issue: issue
                )
                await updateLiveActivityIfNeeded(with: todaySummary)
                await syncSharedCompetition()
                return
            }
        }

        guard fetches.today.value != nil || fetches.daily.value != nil || !previousHistory.isEmpty || previousSummary != nil else {
            let loadedCache = loadCachedActivityData()
            if !loadedCache {
                loadEmptyActivityState()
            }
            authorizationState = .authorized
            lastError = fetchErrors.isEmpty ? nil : fetchErrors.joined(separator: "\n")
            healthRefreshStatus = healthRefreshStatus.completed(
                outcome: loadedCache ? .cached : .failed,
                completedAt: Date(),
                issue: lastError
            )
            await updateLiveActivityIfNeeded(with: todaySummary)
            await syncSharedCompetition()
            return
        }

        let resolvedWorkouts = fetches.workouts.value ?? previousWorkouts
        var resolvedHistory: [DailyActivitySummary]
        if let dailyBuckets = fetches.daily.value {
            resolvedHistory = engine.dailySummaries(
                from: dailyBuckets,
                workouts: resolvedWorkouts,
                startDate: historyStart,
                endDate: now,
                goals: goals
            )
        } else {
            resolvedHistory = previousHistory.map(rebuildSummaryWithCurrentGoals)
        }

        let resolvedSummary: DailyActivitySummary
        if let todayBuckets = fetches.today.value {
            resolvedSummary = engine.aggregateDay(
                containing: selectedDate,
                buckets: todayBuckets,
                workouts: resolvedWorkouts,
                goals: goals
            )
        } else if
            let previousSummary,
            calendar.isDate(previousSummary.dateStart, inSameDayAs: selectedDate)
        {
            resolvedSummary = rebuildSummaryWithCurrentGoals(previousSummary)
        } else if let historySummary = resolvedHistory.first(where: { calendar.isDate($0.dateStart, inSameDayAs: selectedDate) }) {
            resolvedSummary = historySummary
        } else {
            resolvedSummary = emptySummary(for: selectedDate)
        }

        resolvedHistory = replacingSummary(resolvedSummary, in: resolvedHistory)
        workouts = resolvedWorkouts
        history = resolvedHistory
        todaySummary = resolvedSummary
        receipt = engine.receipt(for: history, goals: goals)
        refreshCompetition()
        activityDataSource = .healthKit
        authorizationState = .authorized
        lastError = fetchErrors.isEmpty ? nil : fetchErrors.joined(separator: "\n")
        healthRefreshStatus = healthRefreshStatus.completed(
            outcome: fetchErrors.isEmpty ? .current : .partial,
            completedAt: Date(),
            successfulAt: Date(),
            issue: lastError
        )
        saveDerivedActivityCache(selectedSummary: todaySummary)
        await updateLiveActivityIfNeeded(with: todaySummary)

        await syncAggregateSummaries(selectedSummary: todaySummary)
        await syncSharedCompetition()
        await fetchDayWeather(for: selectedDate)
        workouts = await backfillOutdoorWorkoutWeather(workouts)
        if let todaySummary {
            self.todaySummary = engine.aggregateDay(
                containing: selectedDate,
                buckets: todaySummary.buckets,
                workouts: workouts,
                goals: goals
            )
            history = replacingSummary(self.todaySummary!, in: history)
        }
    }

    func refreshAfterAppBecameActive() async {
        liveActivityStatus = liveActivityService.status

        guard healthKit.isAvailable, hasRequestedHealthAuthorization else {
            await updateLiveActivityIfNeeded(with: nil)
            return
        }

        await configureActivityBackgroundDeliveryIfPossible()
        await refresh()
        await refreshLiveActivityFromHealthKitIfNeeded()
    }

    func refreshLiveActivityTick() async {
        liveActivityStatus = liveActivityService.status

        guard preferences.dailyStepGoalLiveActivityEnabled || liveActivityService.status.isActive else {
            return
        }

        guard healthKit.isAvailable, hasRequestedHealthAuthorization else {
            await updateLiveActivityIfNeeded(with: nil)
            return
        }

        await refreshLiveActivityFromHealthKitIfNeeded()
    }

    func filteredWorkouts(kind: ActivityKind?) -> [WorkoutActivity] {
        engine.filterWorkouts(workouts, kind: kind)
    }

    func workoutTag(for workout: WorkoutActivity) -> String? {
        workoutTags[workout.sourceIdentifier]
    }

    func updateWorkoutTag(_ tag: String?, for workout: WorkoutActivity) {
        let trimmedTag = tag?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmedTag.isEmpty {
            workoutTags.removeValue(forKey: workout.sourceIdentifier)
        } else {
            workoutTags[workout.sourceIdentifier] = String(trimmedTag.prefix(40))
        }
    }

    func filteredDailySummaries(filter: DailySummaryFilter, sort: DailySummarySort) -> [DailyActivitySummary] {
        engine.filterDailySummaries(history, filter: filter, sort: sort)
    }

    func todayCoachInsights(now: Date = Date()) -> [TodayCoachInsight] {
        engine.todayCoachInsights(
            today: todaySummary,
            history: history,
            competitionReceipt: competitionReceipt,
            now: now
        )
    }

    func periodSummary(scope: ActivityPeriodScope, now: Date = Date()) -> PeriodActivitySummary {
        periodSummary(scope: scope, containing: selectedDate, now: now)
    }

    func periodSummary(scope: ActivityPeriodScope, containing date: Date, now: Date = Date()) -> PeriodActivitySummary {
        engine.periodSummary(
            scope: scope,
            containing: normalizedActivityDate(date, now: now),
            summaries: historyForSelectedPeriod,
            goals: goals,
            now: now,
            heartRateZoneConfiguration: preferences.heartRateZoneConfiguration
        )
    }

    func filteredPeriodSummary(
        scope: ActivityPeriodScope,
        containing date: Date,
        filter: InsightsTrendFilter,
        now: Date = Date()
    ) -> PeriodActivitySummary {
        let base = periodSummary(scope: scope, containing: date, now: now)
        return engine.filteredPeriodSummary(
            base,
            filter: filter,
            goals: goals,
            heartRateZoneConfiguration: preferences.heartRateZoneConfiguration,
            now: now
        )
    }

    func cardioInsight(
        scope: ActivityPeriodScope,
        containing date: Date,
        filter: InsightsTrendFilter,
        sessionScope: CardioSessionScope,
        now: Date = Date()
    ) -> CardioPeriodInsight {
        let period = filteredPeriodSummary(
            scope: scope,
            containing: date,
            filter: filter,
            now: now
        )
        return engine.cardioInsight(
            from: period.summaries,
            scope: sessionScope,
            heartRateZoneConfiguration: preferences.heartRateZoneConfiguration
        )
    }

    func weekComparison(containing date: Date, now: Date = Date()) -> PeriodComparisonInsight? {
        guard let priorAnchor = adjacentInsightPeriodAnchor(
            scope: .week,
            containing: date,
            offset: -1,
            now: now
        ) else {
            return nil
        }

        let current = periodSummary(scope: .week, containing: date, now: now)
        let prior = periodSummary(scope: .week, containing: priorAnchor, now: now)
        return engine.periodComparison(current: current, prior: prior, goals: goals)
    }

    func workoutComparisonPeers(for workout: WorkoutActivity) -> [WorkoutActivity] {
        workoutComparisonService.peerWorkouts(
            for: workout,
            in: workouts,
            tagProvider: { [weak self] candidate in
                self?.workoutTag(for: candidate)
            }
        )
    }

    func workoutLastSession(before workout: WorkoutActivity) -> WorkoutActivity? {
        workoutComparisonService.lastSession(
            before: workout,
            in: workoutComparisonPeers(for: workout)
        )
    }

    func workoutBestSession(excluding workout: WorkoutActivity) -> WorkoutActivity? {
        workoutComparisonService.bestSession(
            in: workoutComparisonPeers(for: workout),
            excluding: workout
        )
    }

    func compareWorkouts(current: WorkoutActivity, baseline: WorkoutActivity) -> WorkoutSessionComparison {
        workoutComparisonService.compare(current: current, baseline: baseline)
    }

    func adjacentInsightPeriodAnchor(scope: ActivityPeriodScope, containing date: Date, offset: Int, now: Date = Date()) -> Date? {
        let range = selectableDateRange(now: now)
        return engine.adjacentPeriodAnchor(
            scope: scope,
            containing: normalizedActivityDate(date, now: now),
            offset: offset,
            lowerBound: range.lowerBound,
            upperBound: range.upperBound
        )
    }

    private var historyForSelectedPeriod: [DailyActivitySummary] {
        guard let todaySummary else { return history }
        let selectedDayKey = ActivityFormatting.dayKey(for: todaySummary.dateStart, calendar: calendar)
        var summariesByDay = Dictionary(
            uniqueKeysWithValues: history.map {
                (ActivityFormatting.dayKey(for: $0.dateStart, calendar: calendar), $0)
            }
        )
        summariesByDay[selectedDayKey] = todaySummary
        return summariesByDay.values.sorted { $0.dateStart < $1.dateStart }
    }

    func selectableDateRange(now: Date = Date()) -> ClosedRange<Date> {
        let end = calendar.startOfDay(for: now)
        let start = calendar.date(byAdding: .day, value: -historyLookbackDays, to: end) ?? end
        return start...end
    }

    func selectDate(_ date: Date) async {
        selectedDate = normalizedActivityDate(date)
        guard healthKit.isAvailable, hasRequestedHealthAuthorization else {
            loadSelectedSummaryFromHistory()
            return
        }

        let hourlyFetch = await fetchHealthValue(label: "Selected day Apple Health activity") {
            try await healthKit.fetchHourlyBuckets(for: selectedDate)
        }

        if let hourlyBuckets = hourlyFetch.value {
            todaySummary = engine.aggregateDay(
                containing: selectedDate,
                buckets: hourlyBuckets,
                workouts: workouts,
                goals: goals
            )
            lastError = nil
            healthRefreshStatus = healthRefreshStatus.completed(
                outcome: .current,
                completedAt: Date(),
                successfulAt: Date(),
                issue: nil
            )
            if activityDataSource == .healthKit || activityDataSource == .cache {
                if let todaySummary {
                    history = replacingSummary(todaySummary, in: history)
                    receipt = engine.receipt(for: history, goals: goals)
                    refreshCompetition()
                }
                saveDerivedActivityCache(selectedSummary: todaySummary)
            }
            await updateLiveActivityIfNeeded(with: todaySummary)
        } else {
            lastError = hourlyFetch.errorDescription
            healthRefreshStatus = healthRefreshStatus.completed(
                outcome: .partial,
                completedAt: Date(),
                issue: lastError
            )
            loadSelectedSummaryFromHistory()
        }

        await fetchDayWeather(for: selectedDate)
    }

    func weatherSource(for workout: WorkoutActivity) -> WeatherDataSource? {
        if workoutWeatherSources[workout.sourceIdentifier] == .weatherKit {
            return .weatherKit
        }
        if workout.weatherTemperatureCelsius != nil || workout.weatherHumidityPercent != nil {
            return .healthKitWorkout
        }
        return nil
    }

    func weatherBackfill(for workout: WorkoutActivity) -> DayWeatherSnapshot? {
        workoutWeatherBackfills[workout.sourceIdentifier]
    }

    func loadWeatherDetail(for date: Date) async {
        if let detail = dayWeatherDetail, calendar.isDate(detail.date, inSameDayAs: date) {
            return
        }

        isLoadingWeatherDetail = true
        defer { isLoadingWeatherDetail = false }

        do {
            await locationProvider.requestWhenInUseAuthorization()
            let status = await locationProvider.authorizationStatus()
            weatherNeedsLocation = status == .denied || status == .restricted
            guard !weatherNeedsLocation else {
                throw LocationProviderError.denied
            }

            let location = try await locationProvider.currentLocation()
            let detail = try await weatherKit.fetchWeatherDetail(for: date, at: location, calendar: calendar)
            dayWeatherDetail = detail
            dayWeather = detail.snapshot
            weatherNeedsLocation = false
        } catch {
            let status = await locationProvider.authorizationStatus()
            weatherNeedsLocation = status == .denied || status == .restricted
            if dayWeatherDetail == nil, let fallback = fallbackDayWeather(for: date) {
                dayWeatherDetail = DayWeatherDetail(date: calendar.startOfDay(for: date), snapshot: fallback, hourly: [])
                dayWeather = fallback
            }
        }
    }

    func ensureDayWeather() async {
        let status = await locationProvider.authorizationStatus()
        weatherNeedsLocation = status == .denied || status == .restricted

        if dayWeather?.source == .weatherKit, !weatherNeedsLocation {
            return
        }

        await fetchDayWeather(for: selectedDate)
    }

    private func fetchDayWeather(for date: Date) async {
        isLoadingDayWeather = true
        defer { isLoadingDayWeather = false }

        do {
            await locationProvider.requestWhenInUseAuthorization()
            let status = await locationProvider.authorizationStatus()
            weatherNeedsLocation = status == .denied || status == .restricted

            guard !weatherNeedsLocation else {
                throw LocationProviderError.denied
            }

            let location = try await locationProvider.currentLocation()
            let snapshot = try await weatherKit.fetchDayWeather(for: date, at: location, calendar: calendar)
            dayWeather = snapshot
            dayWeatherDetail = DayWeatherDetail(
                date: calendar.startOfDay(for: date),
                snapshot: snapshot,
                hourly: dayWeatherDetail?.hourly ?? []
            )
            weatherNeedsLocation = false
            weatherKitUnavailable = false
            weatherKitJWTAuthFailed = false
        } catch let error as LocationProviderError where error == .denied || error == .restricted {
            weatherNeedsLocation = true
            weatherKitUnavailable = false
            weatherKitJWTAuthFailed = false
            dayWeather = fallbackDayWeather(for: date)
        } catch {
            let status = await locationProvider.authorizationStatus()
            weatherNeedsLocation = status == .denied || status == .restricted
            if weatherNeedsLocation {
                weatherKitUnavailable = false
                weatherKitJWTAuthFailed = false
                dayWeather = fallbackDayWeather(for: date)
            } else {
                weatherKitUnavailable = true
                weatherKitJWTAuthFailed = Self.isWeatherKitJWTAuthError(error)
                if dayWeather?.source != .weatherKit {
                    dayWeather = fallbackDayWeather(for: date)
                }
            }
        }
    }

    private static func isWeatherKitJWTAuthError(_ error: Error) -> Bool {
        let description = String(describing: error)
        if description.contains("WDSJWTAuthenticatorServiceListener") {
            return true
        }
        let nsError = error as NSError
        return nsError.domain.contains("WDSJWTAuthenticatorServiceListener")
    }

    private func fallbackDayWeather(for date: Date) -> DayWeatherSnapshot? {
        guard let summary = todaySummary, calendar.isDate(summary.dateStart, inSameDayAs: date) else {
            return nil
        }

        guard let workout = summary.workouts.first(where: {
            $0.weatherTemperatureCelsius != nil || $0.weatherHumidityPercent != nil
        }) else {
            return nil
        }

        let temperatureCelsius = workout.weatherTemperatureCelsius ?? 0
        let humidityPercent = workout.weatherHumidityPercent ?? 0
        let estimatedFeelsLike = DayWeatherSnapshot.estimatedApparentTemperatureCelsius(
            temperatureCelsius: temperatureCelsius,
            humidityPercent: humidityPercent
        )

        return DayWeatherSnapshot(
            temperatureCelsius: temperatureCelsius,
            humidityPercent: humidityPercent,
            apparentTemperatureCelsius: estimatedFeelsLike,
            conditionSymbolName: nil,
            source: .healthKitWorkout
        )
    }

    private func backfillOutdoorWorkoutWeather(_ workouts: [WorkoutActivity]) async -> [WorkoutActivity] {
        var enriched = workouts
        var backfills: [String: DayWeatherSnapshot] = [:]
        var sources: [String: WeatherDataSource] = workoutWeatherSources

        for (index, workout) in workouts.enumerated() {
            guard workout.weatherTemperatureCelsius == nil,
                  workout.weatherHumidityPercent == nil,
                  workout.environment != .indoor,
                  workout.hasRoute,
                  let firstPoint = workout.routePoints.first
            else {
                if workout.weatherTemperatureCelsius != nil || workout.weatherHumidityPercent != nil {
                    sources[workout.sourceIdentifier] = .healthKitWorkout
                }
                continue
            }

            let location = CLLocation(latitude: firstPoint.latitude, longitude: firstPoint.longitude)
            do {
                let snapshot = try await weatherKit.fetchWorkoutWeather(at: location, around: workout.startDate)
                enriched[index] = workout.withWeatherBackfill(from: snapshot)
                backfills[workout.sourceIdentifier] = snapshot
                sources[workout.sourceIdentifier] = .weatherKit
            } catch {
                continue
            }
        }

        workoutWeatherBackfills = backfills
        workoutWeatherSources = sources
        return enriched
    }

    func updateGoals(steps: Int, workoutMinutes: Int, activeEnergy: Int?) {
        goals = UserGoals(
            stepsPerDay: steps,
            workoutMinutesPerWeek: workoutMinutes,
            activeEnergyKilocaloriesPerDay: activeEnergy
        )
    }

    func startDailyStepGoalLiveActivity() async {
        guard let summary = liveActivitySummary else {
            liveActivityStatus = .unavailable("Open or refresh today's view before starting the Live Activity.")
            return
        }

        liveActivityStatus = await liveActivityService.start(summary: summary)
    }

    func updateDailyStepGoalLiveActivity() async {
        guard let summary = liveActivitySummary else {
            liveActivityStatus = .unavailable("Live Activity updates only use today's step summary.")
            return
        }

        liveActivityStatus = await liveActivityService.update(summary: summary)
    }

    func endDailyStepGoalLiveActivity() async {
        liveActivityStatus = await liveActivityService.end(summary: liveActivitySummary)
    }

    func setDailyStepGoalLiveActivityEnabled(_ isEnabled: Bool) async {
        updatePreferences(dailyStepGoalLiveActivityEnabled: isEnabled)

        if isEnabled {
            await configureActivityBackgroundDeliveryIfPossible()
            if liveActivitySummary == nil {
                await refreshCurrentDayForLiveActivity()
            }
            await startDailyStepGoalLiveActivity()
        } else {
            await endDailyStepGoalLiveActivity()
        }
    }

    private func refreshDerivedState() {
        history = history.map { summary in
            engine.aggregateDay(
                containing: summary.dateStart,
                buckets: summary.buckets,
                workouts: summary.workouts,
                goals: goals
            )
        }
        receipt = engine.receipt(for: history, goals: goals)
        refreshCompetition()
        if let todaySummary {
            self.todaySummary = engine.aggregateDay(
                containing: todaySummary.dateStart,
                buckets: todaySummary.buckets,
                workouts: todaySummary.workouts,
                goals: goals
            )
        }
        if activityDataSource == .healthKit || activityDataSource == .cache {
            saveDerivedActivityCache(selectedSummary: todaySummary)
        }
        Task { await updateLiveActivityIfNeeded(with: todaySummary) }
    }

    private func loadSelectedSummaryFromHistory() {
        if let summary = history.first(where: { calendar.isDate($0.dateStart, inSameDayAs: selectedDate) }) {
            todaySummary = summary
        } else {
            todaySummary = emptySummary(for: selectedDate)
        }
    }

    private func replacingSummary(
        _ summary: DailyActivitySummary,
        in summaries: [DailyActivitySummary]
    ) -> [DailyActivitySummary] {
        let summaryKey = ActivityFormatting.dayKey(for: summary.dateStart, calendar: calendar)
        var summariesByDay = Dictionary(
            uniqueKeysWithValues: summaries.map {
                (ActivityFormatting.dayKey(for: $0.dateStart, calendar: calendar), $0)
            }
        )
        summariesByDay[summaryKey] = summary
        return summariesByDay.values.sorted { $0.dateStart < $1.dateStart }
    }

    private func emptySummary(for date: Date) -> DailyActivitySummary {
        DailyActivitySummary(
            dateStart: calendar.startOfDay(for: date),
            steps: 0,
            distanceMeters: 0,
            activeEnergyKilocalories: 0,
            flightsClimbed: 0,
            workoutMinutes: 0,
            buckets: [],
            workouts: [],
            goals: goals
        )
    }

    private func normalizedActivityDate(_ date: Date, now: Date = Date()) -> Date {
        let range = selectableDateRange(now: now)
        return min(max(calendar.startOfDay(for: date), range.lowerBound), range.upperBound)
    }

    private static func mondayFirstCalendar(_ calendar: Calendar) -> Calendar {
        var calendar = calendar
        calendar.firstWeekday = 2
        return calendar
    }

    private var liveActivitySummary: DailyActivitySummary? {
        if let todaySummary, calendar.isDateInToday(todaySummary.dateStart) {
            return todaySummary
        }

        let todayStart = calendar.startOfDay(for: Date())
        return history.first { calendar.isDate($0.dateStart, inSameDayAs: todayStart) }
    }

    private func updateLiveActivityIfNeeded(with summary: DailyActivitySummary?) async {
        let effectiveSummary: DailyActivitySummary?
        if let summary, calendar.isDateInToday(summary.dateStart) {
            effectiveSummary = summary
        } else {
            effectiveSummary = liveActivitySummary
        }

        guard let effectiveSummary else {
            liveActivityStatus = liveActivityService.status
            return
        }

        if preferences.dailyStepGoalLiveActivityEnabled {
            if liveActivityService.status.isActive {
                liveActivityStatus = await liveActivityService.update(summary: effectiveSummary)
            } else {
                liveActivityStatus = await liveActivityService.start(summary: effectiveSummary)
            }
        } else {
            liveActivityStatus = await liveActivityService.updateIfActive(summary: effectiveSummary)
        }
    }

    private func refreshLiveActivityFromHealthKitIfNeeded() async {
        guard preferences.dailyStepGoalLiveActivityEnabled || liveActivityService.status.isActive else {
            liveActivityStatus = liveActivityService.status
            return
        }

        await refreshCurrentDayForLiveActivity()
    }

    private func configureActivityBackgroundDeliveryIfPossible(force: Bool = false) async {
        guard healthKit.isAvailable, hasRequestedHealthAuthorization else {
            healthBackgroundDeliveryState = .unavailable("Apple Health is not ready for background updates.")
            return
        }

        guard force || !hasConfiguredActivityBackgroundDeliveryForSession else {
            return
        }

        healthBackgroundDeliveryState = .configuring

        do {
            try await healthKit.startActivityBackgroundDelivery { [weak self] in
                await self?.refreshCurrentDayFromHealthBackgroundDelivery()
            }
            hasConfiguredActivityBackgroundDeliveryForSession = true
            let configuredAt = Date()
            userDefaults.set(configuredAt, forKey: healthBackgroundDeliveryConfiguredAtKey)
            healthBackgroundDeliveryState = .configured(configuredAt)
        } catch {
            hasConfiguredActivityBackgroundDeliveryForSession = false
            let message = "Lock Screen auto-update setup failed: \(error.localizedDescription)"
            healthBackgroundDeliveryState = .unavailable(message)
            lastError = message
        }
    }

    private func refreshCurrentDayFromHealthBackgroundDelivery() async {
        guard !isRefreshingFromBackgroundDelivery else { return }
        isRefreshingFromBackgroundDelivery = true
        defer { isRefreshingFromBackgroundDelivery = false }

        await refreshCurrentDayForLiveActivity()
    }

    private func refreshCurrentDayForLiveActivity() async {
        guard healthKit.isAvailable, hasRequestedHealthAuthorization else { return }

        let now = Date()
        let todayStart = calendar.startOfDay(for: now)
        let todayEnd = calendar.date(byAdding: .day, value: 1, to: todayStart) ?? todayStart.addingTimeInterval(86_400)

        async let todayFetch = fetchHealthValue(label: "Current day Apple Health activity") {
            try await healthKit.fetchHourlyBuckets(for: todayStart)
        }
        async let workoutsFetch = fetchHealthValue(label: "Current day Apple Health workouts") {
            try await healthKit.fetchWorkouts(startDate: todayStart, endDate: todayEnd)
        }

        let fetches = await (today: todayFetch, workouts: workoutsFetch)
        let fetchErrors = [fetches.today.errorDescription, fetches.workouts.errorDescription]
            .compactMap { $0 }

        guard fetches.today.value != nil || fetches.workouts.value != nil else {
            let issue = fetchErrors.joined(separator: "\n")
            lastError = issue.isEmpty ? lastError : issue
            healthRefreshStatus = healthRefreshStatus.completed(
                outcome: .failed,
                completedAt: Date(),
                issue: issue.isEmpty ? healthRefreshStatus.issue : issue
            )
            liveActivityStatus = liveActivityService.status
            return
        }

        let todayBuckets = fetches.today.value ?? liveActivitySummary?.buckets ?? []
        let todayWorkouts = fetches.workouts.value ?? currentDayWorkouts(start: todayStart, end: todayEnd)
        workouts = replacingWorkouts(start: todayStart, end: todayEnd, with: todayWorkouts)

        let updatedSummary = engine.aggregateDay(
            containing: todayStart,
            buckets: todayBuckets,
            workouts: workouts,
            goals: goals
        )

        upsertHistorySummary(updatedSummary)
        if calendar.isDate(selectedDate, inSameDayAs: todayStart) {
            todaySummary = updatedSummary
        }
        receipt = engine.receipt(for: historyForSelectedPeriod, goals: goals)
        refreshCompetition()
        activityDataSource = .healthKit
        authorizationState = .authorized
        lastError = fetchErrors.isEmpty ? nil : fetchErrors.joined(separator: "\n")
        healthRefreshStatus = healthRefreshStatus.completed(
            outcome: fetchErrors.isEmpty ? .current : .partial,
            completedAt: Date(),
            successfulAt: Date(),
            issue: lastError
        )
        saveDerivedActivityCache(selectedSummary: todaySummary)
        await updateLiveActivityIfNeeded(with: updatedSummary)
    }

    private func upsertHistorySummary(_ summary: DailyActivitySummary) {
        let summaryKey = ActivityFormatting.dayKey(for: summary.dateStart, calendar: calendar)
        var summariesByDay = Dictionary(
            uniqueKeysWithValues: history.map {
                (ActivityFormatting.dayKey(for: $0.dateStart, calendar: calendar), $0)
            }
        )
        summariesByDay[summaryKey] = summary
        history = summariesByDay.values.sorted { $0.dateStart < $1.dateStart }
    }

    private func currentDayWorkouts(start: Date, end: Date) -> [WorkoutActivity] {
        workouts.filter { workout in
            workout.startDate < end && workout.endDate > start
        }
    }

    private func replacingWorkouts(start: Date, end: Date, with todayWorkouts: [WorkoutActivity]) -> [WorkoutActivity] {
        let otherWorkouts = workouts.filter { workout in
            workout.endDate <= start || workout.startDate >= end
        }
        return (otherWorkouts + todayWorkouts)
            .sorted { $0.startDate > $1.startDate }
    }

    private func didReturnNoReadableHealthData(
        fetches: (
            today: HealthFetchResult<[HealthMetricBucket]>,
            daily: HealthFetchResult<[HealthMetricBucket]>,
            workouts: HealthFetchResult<[WorkoutActivity]>
        )
    ) -> Bool {
        guard
            let todayBuckets = fetches.today.value,
            let dailyBuckets = fetches.daily.value,
            let workouts = fetches.workouts.value
        else {
            return false
        }

        return todayBuckets.allSatisfy(\.hasNoActivity)
            && dailyBuckets.allSatisfy(\.hasNoActivity)
            && workouts.isEmpty
    }

    private func syncAggregateSummaries(selectedSummary: DailyActivitySummary?) async {
        var summariesByDay: [String: DailyActivitySummary] = [:]
        for summary in history {
            let dayKey = ActivityFormatting.dayKey(for: summary.dateStart, calendar: calendar)
            summariesByDay[dayKey] = summary
        }
        if let selectedSummary {
            let selectedKey = ActivityFormatting.dayKey(for: selectedSummary.dateStart, calendar: calendar)
            summariesByDay[selectedKey] = selectedSummary
        }

        let records = summariesByDay.values
            .sorted { $0.dateStart < $1.dateStart }
            .map { engine.syncedRecord(from: $0) }

        do {
            try await cloudKit.sync(records: records)
            cloudSyncState = .available
        } catch {
            cloudSyncState = .unavailable(error.localizedDescription)
        }
    }

    func setCompetition(metric: CompetitionMetric? = nil, window: CompetitionWindow? = nil) {
        if let metric {
            competitionMetric = metric
        }
        if let window {
            competitionWindow = window
        }
        refreshCompetition()
    }

    @discardableResult
    func addLocalCompetitionCheckIn(
        displayName: String,
        date: Date,
        steps: Int,
        distanceMeters: Double,
        activeEnergyKilocalories: Double,
        workoutMinutes: Double
    ) -> CompetitorProfile {
        let competitor = upsertLocalCompetitor(displayName: displayName)
        let checkIn = LocalCompetitionCheckIn(
            competitorID: competitor.id,
            dayKey: ActivityFormatting.dayKey(for: date, calendar: calendar),
            steps: steps,
            distanceMeters: distanceMeters,
            activeEnergyKilocalories: activeEnergyKilocalories,
            workoutMinutes: workoutMinutes
        )
        localCompetitionCheckIns.removeAll {
            $0.competitorID == competitor.id && $0.dayKey == checkIn.dayKey
        }
        localCompetitionCheckIns.append(checkIn)
        localCompetitionCheckIns.sort {
            if $0.dayKey == $1.dayKey {
                return competitorName(for: $0.competitorID).localizedCaseInsensitiveCompare(competitorName(for: $1.competitorID)) == .orderedAscending
            }
            return $0.dayKey > $1.dayKey
        }
        return competitor
    }

    func removeLocalCompetitionCheckIn(_ checkIn: LocalCompetitionCheckIn) {
        localCompetitionCheckIns.removeAll { $0.id == checkIn.id }
    }

    func removeLocalCompetitor(_ competitor: CompetitorProfile) {
        localCompetitors.removeAll { $0.id == competitor.id }
        localCompetitionCheckIns.removeAll { $0.competitorID == competitor.id }
    }

    func updateSharedCompetition(isEnabled: Bool, inviteCode: String) async {
        let settings = SharedCompetitionSettings(isEnabled: isEnabled, inviteCode: inviteCode)
        sharedCompetitionSettings = settings
        if settings.canSync {
            await configureCompetitionPushIfNeeded()
            await syncSharedCompetition()
        } else {
            sharedCompetitionEntries = []
            sharedCompetitionSyncState = .off
            refreshCompetitionBoardState()
            await removeCompetitionSubscriptionIfNeeded()
            publishWatchSnapshot()
        }
    }

    func updateSharedCompetitionWithProfile(
        isEnabled: Bool,
        inviteCode: String,
        displayName: String? = nil
    ) async {
        if let displayName {
            updatePreferences(displayName: displayName)
        }
        await updateSharedCompetition(isEnabled: isEnabled, inviteCode: inviteCode)
    }

    func openActivityTab() {
        activityNavigationToken = UUID()
    }

    func openCompeteTab() {
        competeNavigationToken = UUID()
    }

    func handleCompeteJoinDeepLink(code: String) {
        let normalized = SharedCompetitionSettings.normalizedInviteCode(code)
        guard !normalized.isEmpty else { return }

        pendingCompeteJoin = CompeteJoinRequest(
            inviteCode: normalized,
            source: .deepLink
        )
        openCompeteTab()
    }

    func handleCloudKitShareAcceptance(metadata: CKShare.Metadata) async {
        let container = CKContainer(identifier: metadata.containerIdentifier)
        do {
            _ = try await container.accept(metadata)
            let boardRecord = try await container.sharedCloudDatabase.record(for: metadata.rootRecordID)

            guard let inviteCode = CloudKitCompetitionSync.inviteCode(from: boardRecord) else {
                lastError = "Could not read household code from iCloud invite."
                return
            }

            pendingCompeteJoin = CompeteJoinRequest(
                inviteCode: inviteCode,
                source: .cloudKitShare,
                ownerDisplayName: CloudKitCompetitionSync.ownerDisplayName(from: boardRecord)
            )
            openCompeteTab()
        } catch {
            lastError = CloudKitCompetitionSync.friendlySyncMessage(for: error)
        }
    }

    func confirmPendingCompeteJoin(displayName: String) async {
        guard let pending = pendingCompeteJoin else { return }
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        await updateSharedCompetitionWithProfile(
            isEnabled: true,
            inviteCode: pending.inviteCode,
            displayName: trimmedName.isEmpty ? nil : trimmedName
        )
        pendingCompeteJoin = nil
        await syncSharedCompetition()
    }

    func dismissPendingCompeteJoin() {
        pendingCompeteJoin = nil
    }

    func handleCompetitionCloudKitNotification() async {
        guard sharedCompetitionSettings.canSync else { return }
        await syncSharedCompetition()
    }

    var isCloudKitCompetitionAvailable: Bool {
        competitionSync is CloudKitCompetitionSync
    }

    var competitionSyncDiagnostics: CompetitionSyncDiagnostics {
        let inviteCode = sharedCompetitionSettings.inviteCode
        let groupHash = inviteCode.isEmpty ? nil : CloudKitCompetitionSync.groupHash(for: inviteCode)
        let syncedAt: Date? = if case .synced(let date) = sharedCompetitionSyncState { date } else { nil }
        let unavailableReason: String? = if case .unavailable(let reason) = sharedCompetitionSyncState { reason } else { nil }
        let syncDetail = unavailableReason ?? CompetitionSyncPresentation.statusDetail(
            state: sharedCompetitionSyncState,
            canSync: sharedCompetitionSettings.canSync,
            canPublishEntries: canPublishSharedCompetitionEntries
        )

        return CompetitionSyncDiagnostics(
            boardEnabled: sharedCompetitionSettings.canSync,
            inviteCodeHint: inviteCode.isEmpty ? nil : String(inviteCode.suffix(4)),
            memberCount: householdMembers.count,
            remoteEntryCount: sharedCompetitionEntries.count,
            lastSyncState: CompetitionSyncPresentation.statusTitle(for: sharedCompetitionSyncState),
            lastSyncDetail: syncDetail,
            lastSyncedAt: syncedAt,
            boardRecordHashSuffix: groupHash.map { String($0.suffix(8)) },
            cloudKitCompetitionAvailable: isCloudKitCompetitionAvailable,
            schemaLikelyMissing: CompetitionSyncDiagnostics.schemaLikelyMissing(from: syncDetail)
        )
    }

    func enrichedCompetitionSyncDiagnostics() async -> CompetitionSyncDiagnostics {
        let base = competitionSyncDiagnostics
        guard isCloudKitCompetitionAvailable else { return base }

        let inviteCode = sharedCompetitionSettings.inviteCode
        let groupHash = inviteCode.isEmpty ? nil : CloudKitCompetitionSync.groupHash(for: inviteCode)
        let container = CKContainer(identifier: "iCloud.com.tyronsamaroo.stepreceipt")

        let accountStatus: String
        do {
            let status = try await container.accountStatus()
            accountStatus = CompetitionSyncPresentation.iCloudAccountStatusLabel(status)
        } catch {
            accountStatus = "check failed"
        }

        #if canImport(UIKit)
        let pushState = UIApplication.shared.isRegisteredForRemoteNotifications ? "registered" : "not registered"
        #else
        let pushState = "unknown"
        #endif

        let subscriptionRegistered: Bool?
        if let groupHash {
            let expectedHash = competitionSubscription.registeredGroupHash()
            subscriptionRegistered = expectedHash == groupHash
        } else {
            subscriptionRegistered = nil
        }

        return CompetitionSyncDiagnostics(
            boardEnabled: base.boardEnabled,
            inviteCodeHint: base.inviteCodeHint,
            memberCount: base.memberCount,
            remoteEntryCount: base.remoteEntryCount,
            lastSyncState: base.lastSyncState,
            lastSyncDetail: base.lastSyncDetail,
            lastSyncedAt: base.lastSyncedAt,
            boardRecordHashSuffix: base.boardRecordHashSuffix,
            cloudKitCompetitionAvailable: base.cloudKitCompetitionAvailable,
            iCloudAccountStatus: accountStatus,
            pushRegistrationState: pushState,
            subscriptionRegistered: subscriptionRegistered,
            schemaLikelyMissing: base.schemaLikelyMissing
        )
    }

    func checkICloudAvailableForCompete() async -> Bool {
        guard isCloudKitCompetitionAvailable else { return false }
        let container = CKContainer(identifier: "iCloud.com.tyronsamaroo.stepreceipt")
        do {
            let status = try await container.accountStatus()
            return status == .available
        } catch {
            return false
        }
    }

    func syncSharedCompetition() async {
        guard sharedCompetitionSettings.canSync else {
            sharedCompetitionEntries = []
            sharedCompetitionSyncState = .off
            return
        }

        let localEntries = entriesForSharedCompetitionSync()
        sharedCompetitionSyncState = .syncing
        do {
            let remoteEntries = try await competitionSync.sync(
                entries: localEntries,
                inviteCode: sharedCompetitionSettings.inviteCode
            )
            sharedCompetitionEntries = deduplicatedCompetitionEntries(remoteEntries)
            if localEntries.isEmpty && sharedCompetitionEntries.isEmpty {
                sharedCompetitionSyncState = .unavailable("Connect Apple Health before syncing your row to the household board.")
            } else {
                sharedCompetitionSyncState = .synced(Date())
                await registerCompetitionSubscriptionIfNeeded()
            }
        } catch {
            sharedCompetitionSyncState = .unavailable(CloudKitCompetitionSync.friendlySyncMessage(for: error))
            refreshCompetition()
        }
        publishWatchSnapshot()
    }

    private func configureCompetitionPushIfNeeded() async {
        guard sharedCompetitionSettings.canSync else { return }
        #if canImport(UIKit)
        await CompetitionPushRegistration.registerIfNeeded(boardEnabled: true)
        #endif
    }

    private func registerCompetitionSubscriptionIfNeeded() async {
        guard sharedCompetitionSettings.canSync else { return }
        let groupHash = CloudKitCompetitionSync.groupHash(for: sharedCompetitionSettings.inviteCode)
        do {
            try await competitionSubscription.register(for: groupHash)
            await configureCompetitionPushIfNeeded()
        } catch {
            // Subscription failures should not block leaderboard display.
        }
    }

    private func removeCompetitionSubscriptionIfNeeded() async {
        do {
            try await competitionSubscription.unregisterCurrent()
        } catch {
            // Best-effort cleanup when leaving a board.
        }
    }

    private func publishWatchSnapshot() {
        let todaySteps: Int
        if let todaySummary, calendar.isDateInToday(todaySummary.dateStart) {
            todaySteps = todaySummary.steps
        } else if let liveActivitySummary {
            todaySteps = liveActivitySummary.steps
        } else {
            todaySteps = 0
        }

        let snapshot = WatchAggregateSnapshot(
            steps: todaySteps,
            stepGoal: goals.stepsPerDay,
            updatedAt: Date(),
            competeRank: sharedCompetitionSettings.canSync ? competitionReceipt?.currentUserRank : nil,
            competeHeadline: sharedCompetitionSettings.canSync ? competitionReceipt?.headline : nil,
            householdBoardActive: sharedCompetitionSettings.canSync
        )
        watchSync.publish(snapshot)
    }

    func generatedSharedCompetitionInviteCode() -> String {
        let random = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        return SharedCompetitionSettings.normalizedInviteCode("SR\(random.prefix(8))")
    }

    func prepareHouseholdCompetitionShare() async throws -> HouseholdCompetitionShare {
        guard let cloudCompetitionSync = competitionSync as? CloudKitCompetitionSync else {
            throw CloudSyncError.unavailable("iCloud household sharing requires the production CloudKit build.")
        }

        let settings = sharedCompetitionSettings
        guard settings.canSync else {
            throw CloudSyncError.unavailable("Sync a household board before opening the iCloud invite.")
        }

        return try await cloudCompetitionSync.prepareHouseholdShare(
            inviteCode: settings.inviteCode,
            displayName: preferences.displayName
        )
    }

    var canPublishSharedCompetitionEntries: Bool {
        !entriesForSharedCompetitionSync().isEmpty
    }

    private func refreshCompetition() {
        var entries: [CompetitionEntry] = []
        var entriesByID: [String: CompetitionEntry] = [:]
        merge(sharedCompetitionEntries, into: &entriesByID)
        merge(currentUserCompetitionEntries(from: history), into: &entriesByID)
        let localEntries = competitionEngine.entries(
            from: localCompetitionCheckIns,
            competitors: localCompetitors
        )
        if localEntries.isEmpty, sharedCompetitionEntries.isEmpty, activityDataSource == .sample {
            entries = competitionEngine.sampleEntries(
                currentUserID: currentCompetitorID,
                currentUserName: preferences.displayName,
                summaries: history
            )
        } else {
            merge(localEntries, into: &entriesByID)
            entries = Array(entriesByID.values)
        }
        competitionReceipt = competitionEngine.receipt(
            entries: entries,
            currentUserID: currentCompetitorID,
            window: competitionWindow,
            metric: competitionMetric
        )
        refreshCompetitionBoardState()
    }

    private func refreshCompetitionBoardState() {
        let boardEntries = householdCompetitionEntries()
        householdMembers = CompetitionBoardPhaseResolver.householdMembers(
            from: boardEntries,
            currentUserID: currentCompetitorID
        )

        let localEntries = competitionEngine.entries(
            from: localCompetitionCheckIns,
            competitors: localCompetitors
        )
        isShowingSampleCompetitionBoard =
            localEntries.isEmpty &&
            sharedCompetitionEntries.isEmpty &&
            activityDataSource == .sample

        let syncNeedsAttention: Bool = {
            if case .unavailable = sharedCompetitionSyncState { return true }
            return false
        }()

        competeBoardPhase = CompetitionBoardPhaseResolver.boardPhase(
            settings: sharedCompetitionSettings,
            syncNeedsAttention: syncNeedsAttention,
            canPublishEntries: canPublishSharedCompetitionEntries,
            householdMemberCount: householdMembers.count,
            isShowingSampleBoard: isShowingSampleCompetitionBoard
        )
        publishWatchSnapshot()
    }

    private func householdCompetitionEntries() -> [CompetitionEntry] {
        var entriesByID: [String: CompetitionEntry] = [:]
        merge(sharedCompetitionEntries, into: &entriesByID)
        merge(currentUserCompetitionEntries(from: history), into: &entriesByID)
        return Array(entriesByID.values)
    }

    private func entriesForSharedCompetitionSync() -> [CompetitionEntry] {
        guard activityDataSource == .healthKit || activityDataSource == .cache else {
            return []
        }
        return currentUserCompetitionEntries(from: history)
    }

    private func currentUserCompetitionEntries(from summaries: [DailyActivitySummary]) -> [CompetitionEntry] {
        let currentUser = CompetitorProfile(
            id: currentCompetitorID,
            displayName: preferences.displayName,
            accentHex: "#1C856F"
        )
        return summaries.map { summary in
            competitionEngine.entry(from: summary, competitor: currentUser)
        }
    }

    private func deduplicatedCompetitionEntries(_ entries: [CompetitionEntry]) -> [CompetitionEntry] {
        var entriesByID: [String: CompetitionEntry] = [:]
        merge(entries, into: &entriesByID)
        return Array(entriesByID.values)
            .sorted {
                if $0.dayKey == $1.dayKey {
                    return $0.competitor.displayName.localizedCaseInsensitiveCompare($1.competitor.displayName) == .orderedAscending
                }
                return $0.dayKey > $1.dayKey
            }
    }

    private func merge(_ entries: [CompetitionEntry], into entriesByID: inout [String: CompetitionEntry]) {
        for entry in entries {
            if let existing = entriesByID[entry.id], existing.updatedAt > entry.updatedAt {
                continue
            }
            entriesByID[entry.id] = entry
        }
    }

    private func upsertLocalCompetitor(displayName: String) -> CompetitorProfile {
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let safeName = trimmedName.isEmpty ? "Friend" : trimmedName
        if let existing = localCompetitors.first(where: { $0.displayName.caseInsensitiveCompare(safeName) == .orderedSame }) {
            return existing
        }
        let accents = ["#3364C3", "#E86332", "#7A5CCF", "#B7791F", "#2F855A"]
        let competitor = CompetitorProfile(
            displayName: safeName,
            accentHex: accents[localCompetitors.count % accents.count]
        )
        localCompetitors.append(competitor)
        return competitor
    }

    private func competitorName(for id: UUID) -> String {
        localCompetitors.first { $0.id == id }?.displayName ?? ""
    }

    private var hasRequestedHealthAuthorization: Bool {
        userDefaults.bool(forKey: authorizationRequestedKey)
    }

    private var isSamplePreviewEnabled: Bool {
        userDefaults.bool(forKey: samplePreviewEnabledKey)
    }

    private var isUITestingSampleDataEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains("-stepReceiptUITestingUseSampleData")
    }

    private func markHealthAuthorizationRequested() {
        userDefaults.set(true, forKey: authorizationRequestedKey)
    }

    private func enableSamplePreview() {
        userDefaults.set(true, forKey: samplePreviewEnabledKey)
    }

    private func disableSamplePreview() {
        userDefaults.set(false, forKey: samplePreviewEnabledKey)
    }

    private func applyUITestingCompeteJoinCodeIfNeeded() {
        let arguments = ProcessInfo.processInfo.arguments
        guard let flagIndex = arguments.firstIndex(of: "-CompeteJoinCode"),
              arguments.indices.contains(arguments.index(after: flagIndex))
        else { return }

        let code = arguments[arguments.index(after: flagIndex)]
        handleCompeteJoinDeepLink(code: code)
    }

    private func resetDefaultsForUITestingIfNeeded() {
        guard ProcessInfo.processInfo.arguments.contains("-stepReceiptUITestingResetDefaults") else { return }
        [
            authorizationRequestedKey,
            samplePreviewEnabledKey,
            competitorIDKey,
            goalsKey,
            preferencesKey,
            preferencesDefaultThemeMigratedKey,
            localCompetitorsKey,
            localCompetitionCheckInsKey,
            sharedCompetitionSettingsKey,
            workoutTagsKey,
            activityCacheKey,
            healthBackgroundDeliveryConfiguredAtKey
        ].forEach(userDefaults.removeObject)
        AppViewPreferenceKey.all.forEach(userDefaults.removeObject)
        goals = UserGoals()
        preferences = UserPreferences()
        workoutTags = [:]
        localCompetitors = []
        localCompetitionCheckIns = []
        sharedCompetitionSettings = SharedCompetitionSettings()
        sharedCompetitionEntries = []
        sharedCompetitionSyncState = .off
        healthBackgroundDeliveryState = .notConfigured
        hasConfiguredActivityBackgroundDeliveryForSession = false
        isRepairingHealthSync = false
        lastError = nil
    }

    private func loadCachedDataOrEmpty() {
        if !loadCachedActivityData() {
            loadEmptyActivityState()
        }
    }

    private func loadEmptyActivityState() {
        selectedDate = normalizedActivityDate(selectedDate)
        workouts = []
        history = []
        todaySummary = emptySummary(for: selectedDate)
        receipt = engine.receipt(for: history, goals: goals)
        activityDataSource = .none
        refreshCompetition()
        Task { await updateLiveActivityIfNeeded(with: todaySummary) }
    }

    @discardableResult
    private func loadCachedActivityData() -> Bool {
        guard
            let data = userDefaults.data(forKey: activityCacheKey),
            let cache = try? JSONDecoder().decode(DerivedActivityCache.self, from: data),
            !cache.history.isEmpty || cache.selectedSummary != nil || !cache.workouts.isEmpty
        else {
            return false
        }

        workouts = cache.workouts
        history = cache.history.map(rebuildSummaryWithCurrentGoals)
        selectedDate = normalizedActivityDate(cache.selectedDate)
        if
            let selectedSummary = cache.selectedSummary.map(rebuildSummaryWithCurrentGoals),
            calendar.isDate(selectedSummary.dateStart, inSameDayAs: selectedDate)
        {
            todaySummary = selectedSummary
        } else {
            loadSelectedSummaryFromHistory()
        }
        receipt = engine.receipt(for: history, goals: goals)
        refreshCompetition()
        activityDataSource = .cache
        healthRefreshStatus = healthRefreshStatus.completed(
            outcome: .cached,
            completedAt: Date(),
            issue: healthRefreshStatus.issue
        )
        Task { await updateLiveActivityIfNeeded(with: todaySummary) }
        return true
    }

    private func saveDerivedActivityCache(selectedSummary: DailyActivitySummary?) {
        guard activityDataSource == .healthKit || activityDataSource == .cache else { return }
        let cache = DerivedActivityCache(
            cachedAt: Date(),
            selectedDate: selectedDate,
            history: history,
            workouts: workouts,
            selectedSummary: selectedSummary
        )
        guard let data = try? JSONEncoder().encode(cache) else { return }
        userDefaults.set(data, forKey: activityCacheKey)
    }

    private func rebuildSummaryWithCurrentGoals(_ summary: DailyActivitySummary) -> DailyActivitySummary {
        engine.aggregateDay(
            containing: summary.dateStart,
            buckets: summary.buckets,
            workouts: summary.workouts,
            goals: goals
        )
    }

    private func loadSampleData() {
        let now = Date()
        let start = calendar.date(byAdding: .day, value: -29, to: now) ?? now
        var allBuckets: [HealthMetricBucket] = []
        var sampleWorkouts: [WorkoutActivity] = []

        for dayOffset in 0..<30 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: calendar.startOfDay(for: start)) else { continue }
            for hour in stride(from: 7, through: 20, by: 2) {
                guard let bucketStart = calendar.date(byAdding: .hour, value: hour, to: day) else { continue }
                let base = 450 + (dayOffset % 5) * 160 + hour * 22
                allBuckets.append(
                    HealthMetricBucket(
                        startDate: bucketStart,
                        endDate: bucketStart.addingTimeInterval(3_600),
                        steps: base,
                        distanceMeters: Double(base) * 0.74,
                        activeEnergyKilocalories: Double(base) * 0.038,
                        flightsClimbed: hour.isMultiple(of: 4) ? 2 : 0
                    )
                )
            }

            if dayOffset.isMultiple(of: 3) {
                let workoutStart = calendar.date(byAdding: .hour, value: 18, to: day) ?? day
                let sampleKind = dayOffset % 4
                let sampleWorkout: (ActivityKind, String, Double?, Double, Int?, WorkoutEnvironment?) = switch sampleKind {
                case 0:
                    (.walking, "Outdoor Walk", 3_200, 185, 4_300, .outdoor)
                case 1:
                    (.strengthTraining, "Traditional Strength Training", nil, 265, nil, .indoor)
                case 2:
                    (.stairClimbing, "Stair Stepper", nil, 310, 2_100, .indoor)
                default:
                    (.running, "Running", 4_800, 420, 5_800, .outdoor)
                }
                let workoutEnd = workoutStart.addingTimeInterval((sampleKind == 1 ? 72 : 42) * 60)
                sampleWorkouts.append(
                    WorkoutActivity(
                        sourceIdentifier: "sample-\(dayOffset)",
                        type: sampleWorkout.0,
                        title: sampleWorkout.1,
                        startDate: workoutStart,
                        endDate: workoutEnd,
                        distanceMeters: sampleWorkout.2,
                        activeEnergyKilocalories: sampleWorkout.3,
                        totalEnergyKilocalories: sampleWorkout.3 + 95,
                        steps: sampleWorkout.4,
                        sourceName: "Sample",
                        environment: sampleWorkout.5,
                        weatherTemperatureCelsius: sampleWorkout.5 == .outdoor ? 21 : nil,
                        weatherHumidityPercent: sampleWorkout.5 == .outdoor ? 62 : nil,
                        heartRateSamples: sampleHeartRateSamples(
                            startDate: workoutStart,
                            endDate: workoutEnd,
                            kind: sampleWorkout.0
                        )
                    )
                )
            }
        }

        workouts = sampleWorkouts
        history = engine.dailySummaries(
            from: allBuckets,
            workouts: sampleWorkouts,
            startDate: start,
            endDate: now,
            goals: goals
        )
        todaySummary = engine.aggregateDay(
            containing: now,
            buckets: allBuckets,
            workouts: sampleWorkouts,
            goals: goals
        )
        receipt = engine.receipt(for: history, goals: goals)
        activityDataSource = .sample
        dayWeather = sampleDayWeatherSnapshot()
        refreshCompetition()
        Task { await updateLiveActivityIfNeeded(with: todaySummary) }
    }

    private func sampleDayWeatherSnapshot() -> DayWeatherSnapshot {
        DayWeatherSnapshot(
            temperatureCelsius: 25.5,
            humidityPercent: 47,
            apparentTemperatureCelsius: 26.5,
            conditionSymbolName: "cloud.sun.fill",
            conditionDescription: "Partly Cloudy",
            windSpeedMetersPerSecond: 3.6,
            windDirectionDegrees: 45,
            uvIndex: 5,
            dewPointCelsius: 13.5,
            visibilityMeters: 16_000,
            precipitationChancePercent: 15,
            highTemperatureCelsius: 28,
            lowTemperatureCelsius: 18,
            cloudCoverPercent: 42,
            isDaylight: true,
            source: .weatherKit
        )
    }

    private func sampleHeartRateSamples(
        startDate: Date,
        endDate: Date,
        kind: ActivityKind
    ) -> [WorkoutHeartRateSample] {
        let duration = endDate.timeIntervalSince(startDate)
        guard duration > 0 else { return [] }

        let count = max(24, min(180, Int(duration / 20)))
        let profile: (base: Double, ramp: Double, wave: Double) = switch kind {
        case .walking:
            (92, 22, 7)
        case .running:
            (122, 42, 11)
        case .stairClimbing:
            (108, 36, 10)
        case .strengthTraining:
            (86, 24, 9)
        default:
            (92, 24, 8)
        }

        return (0..<count).map { index in
            let progress = count == 1 ? 0 : Double(index) / Double(count - 1)
            let seconds = duration * progress
            let rollingWave = sin(progress * .pi * 5) * profile.wave
            let shortWave = sin(progress * .pi * 31) * (profile.wave * 0.38)
            let latePush = progress > 0.72 ? (progress - 0.72) * 18 : 0
            let recoveryDip = kind == .strengthTraining && progress < 0.25 ? -8 * (0.25 - progress) : 0
            let bpm = profile.base + (profile.ramp * progress) + rollingWave + shortWave + latePush + recoveryDip

            return WorkoutHeartRateSample(
                timestamp: startDate.addingTimeInterval(seconds),
                beatsPerMinute: bpm
            )
        }
    }

    private func saveGoals() {
        guard let data = try? JSONEncoder().encode(goals) else { return }
        userDefaults.set(data, forKey: goalsKey)
    }

    func updatePreferences(
        displayName: String? = nil,
        distanceUnit: DistanceUnit? = nil,
        visibleDashboardMetrics: [DashboardMetric]? = nil,
        appTheme: AppTheme? = nil,
        dailyStepGoalLiveActivityEnabled: Bool? = nil,
        heartRateZoneConfiguration: HeartRateZoneConfiguration? = nil
    ) {
        preferences = UserPreferences(
            displayName: displayName ?? preferences.displayName,
            distanceUnit: distanceUnit ?? preferences.distanceUnit,
            visibleDashboardMetrics: visibleDashboardMetrics ?? preferences.visibleDashboardMetrics,
            appTheme: appTheme ?? preferences.appTheme,
            dailyStepGoalLiveActivityEnabled: dailyStepGoalLiveActivityEnabled ?? preferences.dailyStepGoalLiveActivityEnabled,
            heartRateZoneConfiguration: heartRateZoneConfiguration ?? preferences.heartRateZoneConfiguration
        )
    }

    private func savePreferences() {
        guard let data = try? JSONEncoder().encode(preferences) else { return }
        userDefaults.set(data, forKey: preferencesKey)
    }

    private func saveLocalCompetitors() {
        guard let data = try? JSONEncoder().encode(localCompetitors) else { return }
        userDefaults.set(data, forKey: localCompetitorsKey)
    }

    private func saveLocalCompetitionCheckIns() {
        guard let data = try? JSONEncoder().encode(localCompetitionCheckIns) else { return }
        userDefaults.set(data, forKey: localCompetitionCheckInsKey)
    }

    private func saveSharedCompetitionSettings() {
        guard let data = try? JSONEncoder().encode(sharedCompetitionSettings) else { return }
        userDefaults.set(data, forKey: sharedCompetitionSettingsKey)
    }

    private func saveWorkoutTags() {
        guard let data = try? JSONEncoder().encode(workoutTags) else { return }
        userDefaults.set(data, forKey: workoutTagsKey)
    }

    private static func loadGoals(key: String, userDefaults: UserDefaults) -> UserGoals {
        guard
            let data = userDefaults.data(forKey: key),
            let goals = try? JSONDecoder().decode(UserGoals.self, from: data)
        else {
            return UserGoals()
        }
        return goals
    }

    private static func loadPreferences(
        key: String,
        defaultThemeMigratedKey: String,
        userDefaults: UserDefaults
    ) -> UserPreferences {
        guard
            let data = userDefaults.data(forKey: key),
            let preferences = try? JSONDecoder().decode(UserPreferences.self, from: data)
        else {
            userDefaults.set(true, forKey: defaultThemeMigratedKey)
            return UserPreferences()
        }

        guard !userDefaults.bool(forKey: defaultThemeMigratedKey) else {
            return preferences
        }

        userDefaults.set(true, forKey: defaultThemeMigratedKey)

        guard preferences.appTheme == .system else {
            return preferences
        }

        let migratedPreferences = UserPreferences(
            displayName: preferences.displayName,
            distanceUnit: preferences.distanceUnit,
            visibleDashboardMetrics: preferences.visibleDashboardMetrics,
            appTheme: .light,
            dailyStepGoalLiveActivityEnabled: preferences.dailyStepGoalLiveActivityEnabled,
            heartRateZoneConfiguration: preferences.heartRateZoneConfiguration
        )

        if let data = try? JSONEncoder().encode(migratedPreferences) {
            userDefaults.set(data, forKey: key)
        }

        return migratedPreferences
    }

    private static func loadLocalCompetitors(key: String, userDefaults: UserDefaults) -> [CompetitorProfile] {
        guard
            let data = userDefaults.data(forKey: key),
            let competitors = try? JSONDecoder().decode([CompetitorProfile].self, from: data)
        else {
            return []
        }
        return competitors
    }

    private static func loadLocalCompetitionCheckIns(key: String, userDefaults: UserDefaults) -> [LocalCompetitionCheckIn] {
        guard
            let data = userDefaults.data(forKey: key),
            let checkIns = try? JSONDecoder().decode([LocalCompetitionCheckIn].self, from: data)
        else {
            return []
        }
        return checkIns
    }

    private static func loadSharedCompetitionSettings(key: String, userDefaults: UserDefaults) -> SharedCompetitionSettings {
        guard
            let data = userDefaults.data(forKey: key),
            let settings = try? JSONDecoder().decode(SharedCompetitionSettings.self, from: data)
        else {
            return SharedCompetitionSettings()
        }
        return settings
    }

    private static func loadWorkoutTags(key: String, userDefaults: UserDefaults) -> [String: String] {
        guard
            let data = userDefaults.data(forKey: key),
            let tags = try? JSONDecoder().decode([String: String].self, from: data)
        else {
            return [:]
        }
        return tags
    }

    private static func loadCompetitorID(key: String, userDefaults: UserDefaults) -> UUID {
        if
            let stored = userDefaults.string(forKey: key),
            let id = UUID(uuidString: stored)
        {
            return id
        }
        let id = UUID()
        userDefaults.set(id.uuidString, forKey: key)
        return id
    }

    private static func loadHealthBackgroundDeliveryState(
        key: String,
        userDefaults: UserDefaults
    ) -> HealthBackgroundDeliveryState {
        guard let configuredAt = userDefaults.object(forKey: key) as? Date else {
            return .notConfigured
        }

        return .configured(configuredAt)
    }
}

private enum ActivityDataSource {
    case none
    case healthKit
    case cache
    case sample
}

enum HealthRefreshOutcome: Equatable, Sendable {
    case idle
    case refreshing
    case current
    case partial
    case cached
    case failed
}

struct HealthRefreshStatus: Equatable, Sendable {
    var outcome: HealthRefreshOutcome = .idle
    var startedAt: Date?
    var lastCompletedAt: Date?
    var lastSuccessfulAt: Date?
    var issue: String?

    func refreshing(startedAt: Date) -> HealthRefreshStatus {
        HealthRefreshStatus(
            outcome: .refreshing,
            startedAt: startedAt,
            lastCompletedAt: lastCompletedAt,
            lastSuccessfulAt: lastSuccessfulAt,
            issue: issue
        )
    }

    func completed(
        outcome: HealthRefreshOutcome,
        completedAt: Date,
        successfulAt: Date? = nil,
        issue: String? = nil
    ) -> HealthRefreshStatus {
        HealthRefreshStatus(
            outcome: outcome,
            startedAt: nil,
            lastCompletedAt: completedAt,
            lastSuccessfulAt: successfulAt ?? lastSuccessfulAt,
            issue: issue
        )
    }
}

enum HealthBackgroundDeliveryState: Equatable, Sendable {
    case notConfigured
    case configuring
    case configured(Date)
    case unavailable(String)
}

private struct HealthFetchResult<Value: Sendable>: Sendable {
    let value: Value?
    let errorDescription: String?
}

private func fetchHealthValue<Value: Sendable>(
    label: String,
    retryDelayNanoseconds: UInt64 = 250_000_000,
    operation: @Sendable () async throws -> Value
) async -> HealthFetchResult<Value> {
    do {
        return HealthFetchResult(value: try await operation(), errorDescription: nil)
    } catch {
        try? await Task.sleep(nanoseconds: retryDelayNanoseconds)
        do {
            return HealthFetchResult(value: try await operation(), errorDescription: nil)
        } catch {
            return HealthFetchResult(value: nil, errorDescription: "\(label): \(error.localizedDescription)")
        }
    }
}

private struct DerivedActivityCache: Codable {
    let cachedAt: Date
    let selectedDate: Date
    let history: [DailyActivitySummary]
    let workouts: [WorkoutActivity]
    let selectedSummary: DailyActivitySummary?
}

private extension HealthMetricBucket {
    var hasNoActivity: Bool {
        steps == 0
            && distanceMeters == 0
            && activeEnergyKilocalories == 0
            && flightsClimbed == 0
    }
}
