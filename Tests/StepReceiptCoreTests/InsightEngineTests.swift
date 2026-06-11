import Foundation
import Testing
#if canImport(StepReceiptCore)
@testable import StepReceiptCore
#endif

struct InsightEngineTests {
    private let calendar: Calendar
    private let engine: InsightEngine

    init() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        self.calendar = calendar
        self.engine = InsightEngine(calendar: calendar)
    }

    @Test
    func testAggregateDaySumsBucketsAndOverlappingWorkouts() throws {
        let day = try date("2026-06-10T00:00:00Z")
        let buckets = [
            bucket("2026-06-10T08:00:00Z", steps: 1_200, distance: 900, energy: 35, flights: 1),
            bucket("2026-06-10T12:00:00Z", steps: 2_300, distance: 1_700, energy: 90, flights: 4),
            bucket("2026-06-11T08:00:00Z", steps: 9_999, distance: 9_999, energy: 9_999, flights: 9)
        ]
        let workout = WorkoutActivity(
            sourceIdentifier: "w1",
            type: .running,
            startDate: try date("2026-06-10T18:00:00Z"),
            endDate: try date("2026-06-10T18:45:00Z"),
            distanceMeters: 5_000,
            activeEnergyKilocalories: 410
        )

        let summary = engine.aggregateDay(
            containing: day,
            buckets: buckets,
            workouts: [workout],
            goals: UserGoals()
        )

        #expect(summary.steps == 3_500)
        #expect(summary.distanceMeters == 2_600)
        #expect(summary.activeEnergyKilocalories == 125)
        #expect(summary.flightsClimbed == 5)
        #expect(summary.workoutMinutes == 45)
        #expect(summary.workouts.first?.type == .running)
    }

    @Test
    func testAggregateDayProratesWorkoutsThatCrossMidnight() throws {
        let workout = WorkoutActivity(
            sourceIdentifier: "overnight",
            type: .walking,
            startDate: try date("2026-06-10T23:30:00Z"),
            endDate: try date("2026-06-11T00:30:00Z")
        )

        let firstDay = engine.aggregateDay(
            containing: try date("2026-06-10T12:00:00Z"),
            buckets: [],
            workouts: [workout],
            goals: UserGoals()
        )
        let secondDay = engine.aggregateDay(
            containing: try date("2026-06-11T12:00:00Z"),
            buckets: [],
            workouts: [workout],
            goals: UserGoals()
        )

        #expect(firstDay.workoutMinutes == 30)
        #expect(secondDay.workoutMinutes == 30)
        #expect(firstDay.workouts.count == 1)
        #expect(secondDay.workouts.count == 1)
    }

    @Test
    func testReceiptFindsBestDayAverageBestMonthAndStreak() throws {
        let goals = UserGoals(stepsPerDay: 10_000)
        let summaries = [
            summary("2026-05-30T00:00:00Z", steps: 8_000, goals: goals),
            summary("2026-05-31T00:00:00Z", steps: 12_000, goals: goals),
            summary("2026-06-01T00:00:00Z", steps: 15_000, goals: goals),
            summary("2026-06-02T00:00:00Z", steps: 10_500, goals: goals)
        ]

        let receipt = engine.receipt(
            for: summaries,
            goals: goals,
            now: try date("2026-06-02T18:00:00Z")
        )

        #expect(receipt.totalSteps == 45_500)
        #expect(receipt.dailyAverageSteps == 11_375)
        #expect(receipt.bestDay?.steps == 15_000)
        #expect(receipt.bestMonth?.steps == 25_500)
        #expect(receipt.currentStepGoalStreakDays == 3)
        #expect(receipt.stepGoalCompletionRate == 0.75)
    }

    @Test
    func testTodayProjectionUsesElapsedDay() throws {
        let goals = UserGoals(stepsPerDay: 10_000)
        let summary = summary("2026-06-10T00:00:00Z", steps: 5_000, goals: goals)

        let receipt = engine.receipt(
            for: [summary],
            goals: goals,
            now: try date("2026-06-10T12:00:00Z")
        )

        #expect(receipt.projectedStepsToday == 10_000)
        #expect(receipt.onTrackMessage == "On pace to hit your step goal today.")
    }

    @Test
    func testFilterWorkoutsByTypeAndDateRange() throws {
        let workouts = [
            workout("2026-06-08T10:00:00Z", type: .walking),
            workout("2026-06-09T10:00:00Z", type: .running),
            workout("2026-06-10T10:00:00Z", type: .running)
        ]

        let filtered = engine.filterWorkouts(
            workouts,
            kind: .running,
            startDate: try date("2026-06-09T00:00:00Z"),
            endDate: try date("2026-06-09T23:59:59Z")
        )

        #expect(filtered.count == 1)
        #expect(filtered.first?.type == .running)
        let first = try #require(filtered.first)
        #expect(calendar.isDate(first.startDate, inSameDayAs: try date("2026-06-09T12:00:00Z")))
    }

    @Test
    func testFilterDailySummariesByGoalWorkoutAndSort() throws {
        let goals = UserGoals(stepsPerDay: 10_000)
        let lowDay = DailyActivitySummary(
            dateStart: try date("2026-06-08T00:00:00Z"),
            steps: 3_000,
            distanceMeters: 2_000,
            activeEnergyKilocalories: 120,
            flightsClimbed: 1,
            workoutMinutes: 0,
            buckets: [],
            workouts: [],
            goals: goals
        )
        let runWorkout = workout("2026-06-09T18:00:00Z", type: .running)
        let workoutDay = DailyActivitySummary(
            dateStart: try date("2026-06-09T00:00:00Z"),
            steps: 9_000,
            distanceMeters: 6_000,
            activeEnergyKilocalories: 360,
            flightsClimbed: 4,
            workoutMinutes: 45,
            buckets: [],
            workouts: [runWorkout],
            goals: goals
        )
        let goalDay = DailyActivitySummary(
            dateStart: try date("2026-06-10T00:00:00Z"),
            steps: 12_000,
            distanceMeters: 8_000,
            activeEnergyKilocalories: 480,
            flightsClimbed: 6,
            workoutMinutes: 0,
            buckets: [],
            workouts: [],
            goals: goals
        )
        let summaries = [lowDay, workoutDay, goalDay]

        let goalHits = engine.filterDailySummaries(summaries, filter: .goalHit, sort: .newest)
        let workoutDays = engine.filterDailySummaries(summaries, filter: .workoutDays, sort: .newest)
        let lightDays = engine.filterDailySummaries(summaries, filter: .lightDays, sort: .newest)
        let sortedBySteps = engine.filterDailySummaries(summaries, filter: .all, sort: .steps)

        #expect(goalHits.map(\.steps) == [12_000])
        #expect(workoutDays.map(\.steps) == [9_000])
        #expect(lightDays.map(\.steps) == [3_000])
        #expect(sortedBySteps.map(\.steps) == [12_000, 9_000, 3_000])
    }

    @Test
    func testDailySummariesRespectCalendarBoundaries() throws {
        let buckets = [
            bucket("2026-06-09T23:30:00Z", steps: 900),
            bucket("2026-06-10T00:15:00Z", steps: 1_100)
        ]

        let summaries = engine.dailySummaries(
            from: buckets,
            workouts: [],
            startDate: try date("2026-06-09T00:00:00Z"),
            endDate: try date("2026-06-10T00:00:00Z"),
            goals: UserGoals()
        )

        #expect(summaries.map(\.steps) == [900, 1_100])
    }

    @Test
    func testSyncedRecordContainsOnlyAggregates() throws {
        let goals = UserGoals(stepsPerDay: 12_000)
        let summary = DailyActivitySummary(
            dateStart: try date("2026-06-10T00:00:00Z"),
            steps: 12_345,
            distanceMeters: 8_100,
            activeEnergyKilocalories: 560,
            flightsClimbed: 7,
            workoutMinutes: 52,
            buckets: [bucket("2026-06-10T08:00:00Z", steps: 500)],
            workouts: [workout("2026-06-10T10:00:00Z", type: .running)],
            goals: goals
        )

        let record = engine.syncedRecord(
            from: summary,
            updatedAt: try date("2026-06-10T20:00:00Z")
        )

        #expect(record.dayKey == "2026-06-10")
        #expect(record.steps == 12_345)
        #expect(record.workoutCount == 1)
        #expect(record.stepGoal == 12_000)
    }

    @Test
    func testPreferencesNormalizeAndDistanceFormattingSupportsUnits() {
        let preferences = UserPreferences(
            displayName: "   ",
            distanceUnit: .kilometers,
            visibleDashboardMetrics: []
        )

        #expect(preferences.displayName == "You")
        #expect(preferences.distanceUnit == .kilometers)
        #expect(preferences.visibleDashboardMetrics == DashboardMetric.allCases)
        #expect(ActivityFormatting.formattedDistance(from: 1_609.344, unit: .miles) == "1.00 mi")
        #expect(ActivityFormatting.formattedDistance(from: 1_000, unit: .kilometers) == "1.00 km")
    }

    @Test
    func testSharedCompetitionSettingsNormalizeInviteCodes() {
        let enabled = SharedCompetitionSettings(isEnabled: true, inviteCode: " sr-wife-2026!!! ")

        #expect(enabled.isEnabled)
        #expect(enabled.canSync)
        #expect(enabled.inviteCode == "SRWIFE2026")

        let empty = SharedCompetitionSettings(isEnabled: true, inviteCode: "   ")
        #expect(!empty.isEnabled)
        #expect(!empty.canSync)
    }

    @Test
    func testSharedCompetitionSettingsFindInviteCodeCandidates() {
        let inviteMessage = """
        StepReceipt household code: SRWIFE2026
        Open StepReceipt > Compete, paste this code, set your board name, then tap Sync.
        """

        #expect(SharedCompetitionSettings.normalizedInviteCodeCandidates(from: inviteMessage).first == "SRWIFE2026")
        #expect(SharedCompetitionSettings.normalizedInviteCodeCandidates(from: "household code family beta").first == "FAMILYBETA")
        #expect(SharedCompetitionSettings.normalizedInviteCodeCandidates(from: "code is sr-wife-2026").first == "SRWIFE2026")
        #expect(SharedCompetitionSettings.normalizedInviteCodeCandidates(from: "SR-WIFE-2026").first == "SRWIFE2026")
        #expect(SharedCompetitionSettings.normalizedInviteCodeCandidates(from: "SRWIFE2026").first == "SRWIFE2026")
    }

    @Test
    func testCompetitionRanksWithinWindowAndComputesGap() throws {
        let competitionEngine = CompetitionEngine(calendar: calendar)
        let currentUser = try CompetitorProfile(
            id: #require(UUID(uuidString: "00000000-0000-0000-0000-000000000001")),
            displayName: "You",
            initials: "Y"
        )
        let friend = try CompetitorProfile(
            id: #require(UUID(uuidString: "00000000-0000-0000-0000-000000000002")),
            displayName: "Maya",
            initials: "M"
        )
        let entries = [
            CompetitionEntry(
                competitor: currentUser,
                dayKey: "2026-06-10",
                steps: 8_000,
                distanceMeters: 6_000,
                activeEnergyKilocalories: 320,
                workoutMinutes: 35,
                updatedAt: try date("2026-06-10T12:00:00Z")
            ),
            CompetitionEntry(
                competitor: friend,
                dayKey: "2026-06-10",
                steps: 9_250,
                distanceMeters: 7_000,
                activeEnergyKilocalories: 360,
                workoutMinutes: 22,
                updatedAt: try date("2026-06-10T12:00:00Z")
            ),
            CompetitionEntry(
                competitor: friend,
                dayKey: "2026-05-10",
                steps: 99_000,
                distanceMeters: 70_000,
                activeEnergyKilocalories: 4_000,
                workoutMinutes: 500,
                updatedAt: try date("2026-05-10T12:00:00Z")
            )
        ]

        let receipt = competitionEngine.receipt(
            entries: entries,
            currentUserID: currentUser.id,
            window: .today,
            metric: .steps,
            now: try date("2026-06-10T18:00:00Z")
        )

        #expect(receipt.rows.count == 2)
        #expect(receipt.rows.first?.competitor.id == friend.id)
        #expect(receipt.currentUserRank == 2)
        #expect(receipt.gapToNextRank == 1_250)
    }

    @Test
    func testCompetitionTieBreakWindowsMissingUserAndSerialization() throws {
        let competitionEngine = CompetitionEngine(calendar: calendar)
        let currentUser = try CompetitorProfile(
            id: #require(UUID(uuidString: "00000000-0000-0000-0000-000000000001")),
            displayName: "You",
            initials: "Y"
        )
        let alex = try CompetitorProfile(
            id: #require(UUID(uuidString: "00000000-0000-0000-0000-000000000003")),
            displayName: "Alex",
            initials: "A"
        )
        let friend = try CompetitorProfile(
            id: #require(UUID(uuidString: "00000000-0000-0000-0000-000000000004")),
            displayName: "Maya",
            initials: "M"
        )
        let now = try date("2026-06-10T18:00:00Z")
        let tieReceipt = competitionEngine.receipt(
            entries: [
                CompetitionEntry(
                    competitor: currentUser,
                    dayKey: "2026-06-10",
                    steps: 5_000,
                    distanceMeters: 3_000,
                    activeEnergyKilocalories: 200,
                    workoutMinutes: 10,
                    updatedAt: now
                ),
                CompetitionEntry(
                    competitor: alex,
                    dayKey: "2026-06-10",
                    steps: 5_000,
                    distanceMeters: 3_000,
                    activeEnergyKilocalories: 200,
                    workoutMinutes: 10,
                    updatedAt: now
                )
            ],
            currentUserID: currentUser.id,
            window: .today,
            metric: .steps,
            now: now
        )
        #expect(tieReceipt.rows.map(\.competitor.displayName) == ["Alex", "You"])

        let entries = [
            CompetitionEntry(
                competitor: currentUser,
                dayKey: "2026-06-10",
                steps: 8_000,
                distanceMeters: 6_000,
                activeEnergyKilocalories: 320,
                workoutMinutes: 35,
                updatedAt: now
            ),
            CompetitionEntry(
                competitor: friend,
                dayKey: "2026-06-10",
                steps: 9_250,
                distanceMeters: 7_000,
                activeEnergyKilocalories: 360,
                workoutMinutes: 22,
                updatedAt: now
            ),
            CompetitionEntry(
                competitor: friend,
                dayKey: "2026-05-10",
                steps: 99_000,
                distanceMeters: 70_000,
                activeEnergyKilocalories: 4_000,
                workoutMinutes: 500,
                updatedAt: try date("2026-05-10T12:00:00Z")
            )
        ]

        let weekReceipt = competitionEngine.receipt(entries: entries, currentUserID: currentUser.id, window: .week, metric: .steps, now: now)
        let monthReceipt = competitionEngine.receipt(entries: entries, currentUserID: currentUser.id, window: .month, metric: .steps, now: now)
        #expect(weekReceipt.rows.first?.score == 9_250)
        #expect(monthReceipt.rows.first?.score == 9_250)

        let missingUserReceipt = competitionEngine.receipt(entries: [entries[1]], currentUserID: currentUser.id, window: .today, metric: .steps, now: now)
        #expect(missingUserReceipt.currentUserRank == nil)
        #expect(missingUserReceipt.headline == "Connect summaries to start a friendly board.")

        let encoded = try JSONEncoder().encode(entries[0])
        let text = String(data: encoded, encoding: .utf8) ?? ""
        #expect(text.contains("steps"))
        #expect(!text.contains("sourceIdentifier"))
        #expect(!text.contains("sourceName"))
    }

    @Test
    func testLocalCompetitionCheckInsBecomeAggregateEntries() throws {
        let competitionEngine = CompetitionEngine(calendar: calendar)
        let currentUser = try CompetitorProfile(
            id: #require(UUID(uuidString: "00000000-0000-0000-0000-000000000001")),
            displayName: "You"
        )
        let friend = try CompetitorProfile(
            id: #require(UUID(uuidString: "00000000-0000-0000-0000-000000000005")),
            displayName: "Taylor Brooks"
        )
        let renamedFriend = CompetitorProfile(
            id: friend.id,
            displayName: "Taylor B"
        )
        let unknownID = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000099"))
        let now = try date("2026-06-10T18:00:00Z")
        let localEntries = competitionEngine.entries(
            from: [
                LocalCompetitionCheckIn(
                    competitorID: friend.id,
                    dayKey: "2026-06-10",
                    steps: 9_400,
                    distanceMeters: 7_100,
                    activeEnergyKilocalories: 410,
                    workoutMinutes: 45,
                    updatedAt: now
                ),
                LocalCompetitionCheckIn(
                    competitorID: unknownID,
                    dayKey: "2026-06-10",
                    steps: 50_000,
                    updatedAt: now
                )
            ],
            competitors: [friend, renamedFriend]
        )
        let entries = [
            CompetitionEntry(
                competitor: currentUser,
                dayKey: "2026-06-10",
                steps: 8_100,
                distanceMeters: 6_000,
                activeEnergyKilocalories: 300,
                workoutMinutes: 25,
                updatedAt: now
            )
        ] + localEntries

        let receipt = competitionEngine.receipt(
            entries: entries,
            currentUserID: currentUser.id,
            window: .today,
            metric: .steps,
            now: now
        )

        #expect(friend.initials == "TB")
        #expect(localEntries.count == 1)
        #expect(receipt.rows.map(\.competitor.displayName) == ["Taylor B", "You"])
        #expect(receipt.gapToNextRank == 1_300)

        let encoded = try JSONEncoder().encode(entries[1])
        let text = String(data: encoded, encoding: .utf8) ?? ""
        #expect(text.contains("steps"))
        #expect(!text.contains("sourceIdentifier"))
        #expect(!text.contains("workouts"))
    }

    @Test
    func testEmptyReceiptIsStable() throws {
        let now = try date("2026-06-10T09:00:00Z")
        let receipt = engine.receipt(for: [], goals: UserGoals(), now: now)

        #expect(receipt.totalSteps == 0)
        #expect(receipt.bestDay == nil)
        #expect(receipt.bestMonth == nil)
        #expect(receipt.currentStepGoalStreakDays == 0)
    }

    private func bucket(
        _ isoStart: String,
        steps: Int = 0,
        distance: Double = 0,
        energy: Double = 0,
        flights: Int = 0
    ) -> HealthMetricBucket {
        let start = try! date(isoStart)
        return HealthMetricBucket(
            startDate: start,
            endDate: start.addingTimeInterval(3_600),
            steps: steps,
            distanceMeters: distance,
            activeEnergyKilocalories: energy,
            flightsClimbed: flights
        )
    }

    private func workout(_ isoStart: String, type: ActivityKind) -> WorkoutActivity {
        let start = try! date(isoStart)
        return WorkoutActivity(
            sourceIdentifier: isoStart,
            type: type,
            startDate: start,
            endDate: start.addingTimeInterval(45 * 60),
            distanceMeters: type == .running ? 5_000 : nil,
            activeEnergyKilocalories: type == .running ? 420 : 160
        )
    }

    private func summary(_ isoDayStart: String, steps: Int, goals: UserGoals) -> DailyActivitySummary {
        let start = try! date(isoDayStart)
        return DailyActivitySummary(
            dateStart: start,
            steps: steps,
            distanceMeters: Double(steps) * 0.75,
            activeEnergyKilocalories: Double(steps) * 0.04,
            flightsClimbed: steps / 2_000,
            workoutMinutes: steps >= goals.stepsPerDay ? 35 : 0,
            buckets: [],
            workouts: [],
            goals: goals
        )
    }

    private func date(_ iso: String) throws -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        guard let date = formatter.date(from: iso) else {
            throw TestDateError.invalidISODate(iso)
        }
        return date
    }

    private enum TestDateError: Error {
        case invalidISODate(String)
    }
}
