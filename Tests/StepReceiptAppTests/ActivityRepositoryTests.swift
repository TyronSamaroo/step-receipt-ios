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

    func requestAuthorization() async throws -> HealthAuthorizationState {
        authorizationState
    }

    func fetchHourlyBuckets(for date: Date) async throws -> [HealthMetricBucket] {
        hourlyBuckets
    }

    func fetchDailyBuckets(daysBack: Int, endingAt endDate: Date) async throws -> [HealthMetricBucket] {
        dailyBuckets
    }

    func fetchWorkouts(startDate: Date, endDate: Date) async throws -> [WorkoutActivity] {
        workouts
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
