import Combine
import Foundation

@MainActor
final class ActivityRepository: ObservableObject {
    @Published var authorizationState: HealthAuthorizationState = .notDetermined
    @Published var cloudSyncState: CloudSyncState = .unknown
    @Published var selectedDate: Date = Date()
    @Published var todaySummary: DailyActivitySummary?
    @Published var history: [DailyActivitySummary] = []
    @Published var workouts: [WorkoutActivity] = []
    @Published var receipt: InsightReceipt?
    @Published var competitionReceipt: CompetitionReceipt?
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
    @Published var isLoading = false
    @Published var lastError: String?

    let historyLookbackDays = 90

    private let healthKit: any HealthKitProviding
    private let cloudKit: any CloudKitSummarySyncing
    private let engine: InsightEngine
    private let competitionEngine: CompetitionEngine
    private let calendar: Calendar
    private let userDefaults: UserDefaults
    private let authorizationRequestedKey = "stepReceipt.healthAuthorizationRequested.v1"
    private let samplePreviewEnabledKey = "stepReceipt.samplePreviewEnabled.v1"
    private let competitorIDKey = "stepReceipt.currentCompetitorID.v1"
    private let goalsKey = "stepReceipt.goals.v1"
    private let preferencesKey = "stepReceipt.preferences.v1"
    private let localCompetitorsKey = "stepReceipt.localCompetitors.v1"
    private let localCompetitionCheckInsKey = "stepReceipt.localCompetitionCheckIns.v1"
    private let activityCacheKey = "stepReceipt.derivedActivityCache.v1"
    private let currentCompetitorID: UUID
    private var activityDataSource: ActivityDataSource = .none

    init(
        healthKit: any HealthKitProviding = HealthKitClient(),
        cloudKit: any CloudKitSummarySyncing = CloudKitSummarySync(),
        calendar: Calendar = .current,
        userDefaults: UserDefaults = .standard
    ) {
        self.healthKit = healthKit
        self.cloudKit = cloudKit
        self.calendar = calendar
        self.userDefaults = userDefaults
        self.engine = InsightEngine(calendar: calendar)
        self.competitionEngine = CompetitionEngine(calendar: calendar)
        self.goals = Self.loadGoals(key: goalsKey, userDefaults: userDefaults)
        self.preferences = Self.loadPreferences(key: preferencesKey, userDefaults: userDefaults)
        self.localCompetitors = Self.loadLocalCompetitors(key: localCompetitorsKey, userDefaults: userDefaults)
        self.localCompetitionCheckIns = Self.loadLocalCompetitionCheckIns(key: localCompetitionCheckInsKey, userDefaults: userDefaults)
        self.currentCompetitorID = Self.loadCompetitorID(key: competitorIDKey, userDefaults: userDefaults)
    }

    func bootstrap() async {
        resetDefaultsForUITestingIfNeeded()
        cloudSyncState = await cloudKit.status()
        if !healthKit.isAvailable {
            authorizationState = .unavailable
            loadCachedDataOrSample()
            return
        }

        guard hasRequestedHealthAuthorization else {
            if isSamplePreviewEnabled {
                authorizationState = .deniedOrLimited
                loadSampleData()
                return
            }
            authorizationState = .notDetermined
            loadCachedDataOrSample()
            return
        }

        await refresh()
    }

    func requestHealthAccess() async {
        disableSamplePreview()
        markHealthAuthorizationRequested()

        do {
            let state = try await healthKit.requestAuthorization()
            authorizationState = state
            guard state == .authorized else {
                loadCachedDataOrSample()
                return
            }

            await refresh()
        } catch {
            authorizationState = .deniedOrLimited
            lastError = error.localizedDescription
            loadCachedDataOrSample()
        }
    }

    func previewWithSampleData() {
        enableSamplePreview()
        authorizationState = .deniedOrLimited
        lastError = nil
        loadSampleData()
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let now = Date()
            let selectedDate = normalizedActivityDate(self.selectedDate, now: now)
            self.selectedDate = selectedDate
            let historyEnd = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now.addingTimeInterval(86_400)
            let defaultHistoryStart = calendar.date(byAdding: .day, value: -historyLookbackDays, to: historyEnd) ?? historyEnd.addingTimeInterval(-Double(historyLookbackDays) * 86_400)
            let historyStart = min(defaultHistoryStart, selectedDate)

            async let todayBuckets = healthKit.fetchHourlyBuckets(for: selectedDate)
            async let dailyBuckets = healthKit.fetchDailyBuckets(daysBack: historyLookbackDays, endingAt: now)
            async let fetchedWorkouts = healthKit.fetchWorkouts(startDate: historyStart, endDate: historyEnd)

            let values = try await (todayBuckets: todayBuckets, dailyBuckets: dailyBuckets, workouts: fetchedWorkouts)
            workouts = values.workouts
            history = engine.dailySummaries(
                from: values.dailyBuckets,
                workouts: values.workouts,
                startDate: historyStart,
                endDate: now,
                goals: goals
            )
            todaySummary = engine.aggregateDay(
                containing: selectedDate,
                buckets: values.todayBuckets,
                workouts: values.workouts,
                goals: goals
            )
            receipt = engine.receipt(for: history, goals: goals)
            refreshCompetition()
            activityDataSource = .healthKit
            authorizationState = .authorized
            lastError = nil
            saveDerivedActivityCache(selectedSummary: todaySummary)

            await syncAggregateSummaries(selectedSummary: todaySummary)
        } catch {
            authorizationState = .deniedOrLimited
            lastError = error.localizedDescription
            if history.isEmpty {
                loadCachedDataOrSample()
            }
        }
    }

    func filteredWorkouts(kind: ActivityKind?) -> [WorkoutActivity] {
        engine.filterWorkouts(workouts, kind: kind)
    }

    func filteredDailySummaries(filter: DailySummaryFilter, sort: DailySummarySort) -> [DailyActivitySummary] {
        engine.filterDailySummaries(history, filter: filter, sort: sort)
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

        do {
            let hourlyBuckets = try await healthKit.fetchHourlyBuckets(for: selectedDate)
            todaySummary = engine.aggregateDay(
                containing: selectedDate,
                buckets: hourlyBuckets,
                workouts: workouts,
                goals: goals
            )
            lastError = nil
            if activityDataSource == .healthKit || activityDataSource == .cache {
                saveDerivedActivityCache(selectedSummary: todaySummary)
            }
        } catch {
            lastError = error.localizedDescription
            loadSelectedSummaryFromHistory()
        }
    }

    func updateGoals(steps: Int, workoutMinutes: Int, activeEnergy: Int?) {
        goals = UserGoals(
            stepsPerDay: steps,
            workoutMinutesPerWeek: workoutMinutes,
            activeEnergyKilocaloriesPerDay: activeEnergy
        )
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
    }

    private func loadSelectedSummaryFromHistory() {
        if let summary = history.first(where: { calendar.isDate($0.dateStart, inSameDayAs: selectedDate) }) {
            todaySummary = summary
        } else {
            todaySummary = emptySummary(for: selectedDate)
        }
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

    private func refreshCompetition() {
        let currentUser = CompetitorProfile(
            id: currentCompetitorID,
            displayName: preferences.displayName,
            accentHex: "#1C856F"
        )
        var entries = history.map { summary in
            competitionEngine.entry(from: summary, competitor: currentUser)
        }
        let localEntries = competitionEngine.entries(
            from: localCompetitionCheckIns,
            competitors: localCompetitors
        )
        if localEntries.isEmpty, activityDataSource == .sample {
            entries = competitionEngine.sampleEntries(
                currentUserID: currentCompetitorID,
                currentUserName: preferences.displayName,
                summaries: history
            )
        } else {
            entries.append(contentsOf: localEntries)
        }
        competitionReceipt = competitionEngine.receipt(
            entries: entries,
            currentUserID: currentCompetitorID,
            window: competitionWindow,
            metric: competitionMetric
        )
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

    private func markHealthAuthorizationRequested() {
        userDefaults.set(true, forKey: authorizationRequestedKey)
    }

    private func enableSamplePreview() {
        userDefaults.set(true, forKey: samplePreviewEnabledKey)
    }

    private func disableSamplePreview() {
        userDefaults.set(false, forKey: samplePreviewEnabledKey)
    }

    private func resetDefaultsForUITestingIfNeeded() {
        guard ProcessInfo.processInfo.arguments.contains("-stepReceiptUITestingResetDefaults") else { return }
        [
            authorizationRequestedKey,
            samplePreviewEnabledKey,
            competitorIDKey,
            goalsKey,
            preferencesKey,
            localCompetitorsKey,
            localCompetitionCheckInsKey,
            activityCacheKey
        ].forEach(userDefaults.removeObject)
        goals = UserGoals()
        preferences = UserPreferences()
        localCompetitors = []
        localCompetitionCheckIns = []
        lastError = nil
    }

    private func loadCachedDataOrSample() {
        if !loadCachedActivityData() {
            loadSampleData()
        }
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
                sampleWorkouts.append(
                    WorkoutActivity(
                        sourceIdentifier: "sample-\(dayOffset)",
                        type: dayOffset.isMultiple(of: 2) ? .running : .strengthTraining,
                        startDate: workoutStart,
                        endDate: workoutStart.addingTimeInterval(42 * 60),
                        distanceMeters: dayOffset.isMultiple(of: 2) ? 4_800 : nil,
                        activeEnergyKilocalories: dayOffset.isMultiple(of: 2) ? 420 : 240,
                        sourceName: "Sample"
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
        refreshCompetition()
    }

    private func saveGoals() {
        guard let data = try? JSONEncoder().encode(goals) else { return }
        userDefaults.set(data, forKey: goalsKey)
    }

    func updatePreferences(
        displayName: String? = nil,
        distanceUnit: DistanceUnit? = nil,
        visibleDashboardMetrics: [DashboardMetric]? = nil
    ) {
        preferences = UserPreferences(
            displayName: displayName ?? preferences.displayName,
            distanceUnit: distanceUnit ?? preferences.distanceUnit,
            visibleDashboardMetrics: visibleDashboardMetrics ?? preferences.visibleDashboardMetrics
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

    private static func loadGoals(key: String, userDefaults: UserDefaults) -> UserGoals {
        guard
            let data = userDefaults.data(forKey: key),
            let goals = try? JSONDecoder().decode(UserGoals.self, from: data)
        else {
            return UserGoals()
        }
        return goals
    }

    private static func loadPreferences(key: String, userDefaults: UserDefaults) -> UserPreferences {
        guard
            let data = userDefaults.data(forKey: key),
            let preferences = try? JSONDecoder().decode(UserPreferences.self, from: data)
        else {
            return UserPreferences()
        }
        return preferences
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
}

private enum ActivityDataSource {
    case none
    case healthKit
    case cache
    case sample
}

private struct DerivedActivityCache: Codable {
    let cachedAt: Date
    let selectedDate: Date
    let history: [DailyActivitySummary]
    let workouts: [WorkoutActivity]
    let selectedSummary: DailyActivitySummary?
}
