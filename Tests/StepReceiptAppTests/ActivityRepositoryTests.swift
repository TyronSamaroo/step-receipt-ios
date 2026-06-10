import Foundation
import Testing

@MainActor
struct ActivityRepositoryTests {
    private let calendar: Calendar

    init() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        self.calendar = calendar
    }

    @Test
    func testRefreshKeepsHealthDataWhenCloudKitSyncIsUnavailable() async throws {
        let day = calendar.startOfDay(for: Date())
        let health = FakeHealthKitProvider(
            hourlyBuckets: [
                bucket(day, hour: 8, steps: 1_500, distance: 1_100, energy: 62),
                bucket(day, hour: 12, steps: 2_100, distance: 1_550, energy: 84)
            ],
            dailyBuckets: [
                bucket(day, hour: 0, steps: 3_600, distance: 2_650, energy: 146)
            ],
            workouts: [
                WorkoutActivity(
                    sourceIdentifier: "local-workout",
                    type: .walking,
                    startDate: calendar.date(byAdding: .hour, value: 18, to: day) ?? day,
                    endDate: calendar.date(byAdding: .minute, value: 45, to: calendar.date(byAdding: .hour, value: 18, to: day) ?? day) ?? day,
                    distanceMeters: 3_000,
                    activeEnergyKilocalories: 210,
                    sourceName: "Unit Test"
                )
            ]
        )
        let cloud = FakeCloudKitSummarySync(
            state: .available,
            syncError: CloudSyncError.unavailable("Offline test")
        )
        let suiteName = defaultsSuiteName()
        let defaults = isolatedDefaults(suiteName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let repository = ActivityRepository(
            healthKit: health,
            cloudKit: cloud,
            calendar: calendar,
            userDefaults: defaults
        )

        await repository.requestHealthAccess()

        #expect(repository.authorizationState == .authorized)
        #expect(repository.todaySummary?.steps == 3_600)
        #expect(repository.todaySummary?.workoutMinutes == 45)
        #expect(repository.receipt?.totalSteps ?? 0 >= 3_600)
        #expect(repository.cloudSyncState == .unavailable("Offline test"))

        let records = await cloud.syncedRecords()
        #expect(!records.isEmpty)
        #expect(records.allSatisfy { $0.dayKey.count == 10 })
    }

    @Test
    func testRefreshDeduplicatesSelectedDayBeforeCloudSync() async throws {
        let day = calendar.startOfDay(for: Date())
        let previousDay = try #require(calendar.date(byAdding: .day, value: -1, to: day))
        let health = FakeHealthKitProvider(
            hourlyBuckets: [
                bucket(day, hour: 9, steps: 4_200, distance: 3_200, energy: 175)
            ],
            dailyBuckets: [
                bucket(previousDay, hour: 0, steps: 2_400, distance: 1_700, energy: 90),
                bucket(day, hour: 0, steps: 4_200, distance: 3_200, energy: 175)
            ],
            workouts: []
        )
        let cloud = FakeCloudKitSummarySync(state: .available)
        let suiteName = defaultsSuiteName()
        let defaults = isolatedDefaults(suiteName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let repository = ActivityRepository(
            healthKit: health,
            cloudKit: cloud,
            calendar: calendar,
            userDefaults: defaults
        )

        await repository.requestHealthAccess()

        let records = await cloud.syncedRecords()
        let dayKeys = records.map(\.dayKey)
        #expect(Set(dayKeys).count == dayKeys.count)
        #expect(dayKeys.contains(ActivityFormatting.dayKey(for: day, calendar: calendar)))
        #expect(dayKeys.contains(ActivityFormatting.dayKey(for: previousDay, calendar: calendar)))
    }

    @Test
    func testBootstrapUsesCachedHealthDataWhenRefreshFails() async throws {
        let day = calendar.startOfDay(for: Date())
        let suiteName = defaultsSuiteName()
        let defaults = isolatedDefaults(suiteName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let workout = WorkoutActivity(
            sourceIdentifier: "cached-workout",
            type: .running,
            startDate: calendar.date(byAdding: .hour, value: 7, to: day) ?? day,
            endDate: calendar.date(byAdding: .minute, value: 38, to: calendar.date(byAdding: .hour, value: 7, to: day) ?? day) ?? day,
            distanceMeters: 4_600,
            activeEnergyKilocalories: 355,
            sourceName: "Unit Test"
        )
        let initialRepository = ActivityRepository(
            healthKit: FakeHealthKitProvider(
                hourlyBuckets: [
                    bucket(day, hour: 7, steps: 2_400, distance: 1_850, energy: 96),
                    bucket(day, hour: 13, steps: 2_800, distance: 2_050, energy: 113)
                ],
                dailyBuckets: [
                    bucket(day, hour: 0, steps: 5_200, distance: 3_900, energy: 209)
                ],
                workouts: [workout]
            ),
            cloudKit: FakeCloudKitSummarySync(state: .available),
            calendar: calendar,
            userDefaults: defaults
        )

        await initialRepository.requestHealthAccess()

        let cachedRepository = ActivityRepository(
            healthKit: FakeHealthKitProvider(
                hourlyBuckets: [],
                dailyBuckets: [],
                workouts: [],
                fetchError: .fetchFailed
            ),
            cloudKit: FakeCloudKitSummarySync(state: .available),
            calendar: calendar,
            userDefaults: defaults
        )

        await cachedRepository.bootstrap()

        #expect(cachedRepository.authorizationState == .deniedOrLimited)
        #expect(cachedRepository.todaySummary?.steps == 5_200)
        #expect(cachedRepository.todaySummary?.buckets.count == 2)
        #expect(cachedRepository.workouts.first?.sourceIdentifier == "cached-workout")
        #expect(cachedRepository.receipt?.totalSteps ?? 0 >= 5_200)
    }

    @Test
    func testDeniedHealthAccessUsesCachedDataBeforeSamplePreview() async throws {
        let day = calendar.startOfDay(for: Date())
        let suiteName = defaultsSuiteName()
        let defaults = isolatedDefaults(suiteName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let initialRepository = ActivityRepository(
            healthKit: FakeHealthKitProvider(
                hourlyBuckets: [
                    bucket(day, hour: 10, steps: 1_800, distance: 1_240, energy: 73)
                ],
                dailyBuckets: [
                    bucket(day, hour: 0, steps: 1_800, distance: 1_240, energy: 73)
                ],
                workouts: []
            ),
            cloudKit: FakeCloudKitSummarySync(state: .available),
            calendar: calendar,
            userDefaults: defaults
        )

        await initialRepository.requestHealthAccess()

        let deniedRepository = ActivityRepository(
            healthKit: FakeHealthKitProvider(
                authorizationState: .deniedOrLimited,
                hourlyBuckets: [],
                dailyBuckets: [],
                workouts: []
            ),
            cloudKit: FakeCloudKitSummarySync(state: .available),
            calendar: calendar,
            userDefaults: defaults
        )

        await deniedRepository.requestHealthAccess()

        #expect(deniedRepository.authorizationState == .deniedOrLimited)
        #expect(deniedRepository.todaySummary?.steps == 1_800)
        #expect(deniedRepository.todaySummary?.buckets.count == 1)
        #expect(deniedRepository.receipt?.bestDay?.steps == 1_800)
    }

    @Test
    func testLocalCompetitionCheckInsPersistAndAffectLeaderboard() async throws {
        let day = calendar.startOfDay(for: Date())
        let suiteName = defaultsSuiteName()
        let defaults = isolatedDefaults(suiteName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let health = FakeHealthKitProvider(
            hourlyBuckets: [
                bucket(day, hour: 8, steps: 3_900, distance: 2_900, energy: 150),
                bucket(day, hour: 18, steps: 4_100, distance: 3_100, energy: 165)
            ],
            dailyBuckets: [
                bucket(day, hour: 0, steps: 8_000, distance: 6_000, energy: 315)
            ],
            workouts: []
        )
        let repository = ActivityRepository(
            healthKit: health,
            cloudKit: FakeCloudKitSummarySync(state: .available),
            calendar: calendar,
            userDefaults: defaults
        )

        await repository.requestHealthAccess()
        repository.addLocalCompetitionCheckIn(
            displayName: "Taylor Brooks",
            date: day,
            steps: 9_250,
            distanceMeters: 6_850,
            activeEnergyKilocalories: 360,
            workoutMinutes: 30
        )

        #expect(repository.localCompetitors.first?.initials == "TB")
        #expect(repository.localCompetitionCheckIns.count == 1)
        #expect(repository.competitionReceipt?.rows.first?.competitor.displayName == "Taylor Brooks")
        #expect(repository.competitionReceipt?.currentUserRank == 2)

        let restoredRepository = ActivityRepository(
            healthKit: health,
            cloudKit: FakeCloudKitSummarySync(state: .available),
            calendar: calendar,
            userDefaults: defaults
        )

        await restoredRepository.bootstrap()

        #expect(restoredRepository.localCompetitors.map(\.displayName) == ["Taylor Brooks"])
        #expect(restoredRepository.localCompetitionCheckIns.first?.steps == 9_250)
        #expect(restoredRepository.competitionReceipt?.rows.first?.competitor.displayName == "Taylor Brooks")
        #expect(restoredRepository.competitionReceipt?.currentUserRank == 2)
    }

    @Test
    func testSampleCompetitionRowsAreReplacedByLocalCheckIns() async throws {
        let day = calendar.startOfDay(for: Date())
        let suiteName = defaultsSuiteName()
        let defaults = isolatedDefaults(suiteName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let repository = ActivityRepository(
            healthKit: FakeHealthKitProvider(hourlyBuckets: [], dailyBuckets: [], workouts: []),
            cloudKit: FakeCloudKitSummarySync(state: .available),
            calendar: calendar,
            userDefaults: defaults
        )

        repository.previewWithSampleData()

        let sampleNames = repository.competitionReceipt?.rows.map(\.competitor.displayName) ?? []
        #expect(sampleNames.contains("Maya"))

        repository.addLocalCompetitionCheckIn(
            displayName: "Taylor Brooks",
            date: day,
            steps: 20_000,
            distanceMeters: 14_000,
            activeEnergyKilocalories: 800,
            workoutMinutes: 90
        )

        let localNames = repository.competitionReceipt?.rows.map(\.competitor.displayName) ?? []
        #expect(localNames.contains("Taylor Brooks"))
        #expect(!localNames.contains("Maya"))
        #expect(repository.localCompetitionCheckIns.count == 1)

        repository.addLocalCompetitionCheckIn(
            displayName: "Taylor Brooks",
            date: day,
            steps: 21_000,
            distanceMeters: 14_800,
            activeEnergyKilocalories: 840,
            workoutMinutes: 95
        )

        #expect(repository.localCompetitionCheckIns.count == 1)
        #expect(repository.localCompetitionCheckIns.first?.steps == 21_000)
    }

    private func defaultsSuiteName() -> String {
        "StepReceiptTests.\(UUID().uuidString)"
    }

    private func isolatedDefaults(suiteName: String) -> UserDefaults {
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private func bucket(
        _ day: Date,
        hour: Int,
        steps: Int,
        distance: Double,
        energy: Double,
        flights: Int = 0
    ) -> HealthMetricBucket {
        let start = calendar.date(byAdding: .hour, value: hour, to: day) ?? day
        return HealthMetricBucket(
            startDate: start,
            endDate: start.addingTimeInterval(3_600),
            steps: steps,
            distanceMeters: distance,
            activeEnergyKilocalories: energy,
            flightsClimbed: flights
        )
    }
}

private struct FakeHealthKitProvider: HealthKitProviding {
    var isAvailable = true
    var authorizationState: HealthAuthorizationState = .authorized
    var hourlyBuckets: [HealthMetricBucket]
    var dailyBuckets: [HealthMetricBucket]
    var workouts: [WorkoutActivity]
    var fetchError: HealthFixtureError? = nil

    func requestAuthorization() async throws -> HealthAuthorizationState {
        authorizationState
    }

    func fetchHourlyBuckets(for date: Date) async throws -> [HealthMetricBucket] {
        if let fetchError { throw fetchError }
        return hourlyBuckets
    }

    func fetchDailyBuckets(daysBack: Int, endingAt endDate: Date) async throws -> [HealthMetricBucket] {
        if let fetchError { throw fetchError }
        return dailyBuckets
    }

    func fetchWorkouts(startDate: Date, endDate: Date) async throws -> [WorkoutActivity] {
        if let fetchError { throw fetchError }
        return workouts
    }
}

private enum HealthFixtureError: LocalizedError, Sendable {
    case fetchFailed

    var errorDescription: String? {
        switch self {
        case .fetchFailed: "Health fixture fetch failed."
        }
    }
}

private actor FakeCloudKitSummarySync: CloudKitSummarySyncing {
    private let state: CloudSyncState
    private let syncError: Error?
    private var batches: [[SyncedSummaryRecord]] = []

    init(state: CloudSyncState, syncError: Error? = nil) {
        self.state = state
        self.syncError = syncError
    }

    func status() async -> CloudSyncState {
        state
    }

    func sync(records: [SyncedSummaryRecord]) async throws {
        batches.append(records)
        if let syncError {
            throw syncError
        }
    }

    func syncedRecords() -> [SyncedSummaryRecord] {
        batches.flatMap { $0 }
    }
}
