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
        calendar.firstWeekday = 2
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
    func testPeriodSummaryBuildsWeekAndMonthReceipts() throws {
        let goals = UserGoals(stepsPerDay: 10_000)
        let summaries = [
            summary("2026-06-01T00:00:00Z", steps: 6_000, goals: goals),
            summary("2026-06-07T00:00:00Z", steps: 11_000, goals: goals),
            summary("2026-06-08T00:00:00Z", steps: 9_000, goals: goals),
            summary("2026-06-09T00:00:00Z", steps: 14_000, goals: goals),
            summary("2026-06-10T00:00:00Z", steps: 4_000, goals: goals),
            summary("2026-07-01T00:00:00Z", steps: 20_000, goals: goals)
        ]

        let week = engine.periodSummary(
            scope: .week,
            containing: try date("2026-06-10T12:00:00Z"),
            summaries: summaries,
            goals: goals,
            now: try date("2026-06-10T18:00:00Z")
        )
        let month = engine.periodSummary(
            scope: .month,
            containing: try date("2026-06-10T12:00:00Z"),
            summaries: summaries,
            goals: goals,
            now: try date("2026-06-10T18:00:00Z")
        )
        let expectedWeekStart = try date("2026-06-08T00:00:00Z")
        let expectedWeekEnd = try date("2026-06-15T00:00:00Z")

        #expect(week.periodStart == expectedWeekStart)
        #expect(week.periodEnd == expectedWeekEnd)
        #expect(week.summaries.map(\.steps) == [9_000, 14_000, 4_000])
        #expect(week.receipt.totalSteps == 27_000)
        #expect(week.goalHitDays == 1)
        #expect(week.bestDay?.steps == 14_000)
        #expect(week.headline.contains("average steps/day"))

        #expect(month.summaries.count == 5)
        #expect(month.receipt.totalSteps == 44_000)
        #expect(month.activeDays == 5)
        #expect(month.bestDay?.steps == 14_000)
        #expect(month.receipt.bestMonth?.steps == 44_000)
    }

    @Test
    func testPeriodNavigationAnchorsClampToHistoryRange() throws {
        let lowerBound = try date("2026-06-01T00:00:00Z")
        let upperBound = try date("2026-06-30T00:00:00Z")

        let currentWeekStart = engine.adjacentPeriodAnchor(
            scope: .week,
            containing: try date("2026-06-10T12:00:00Z"),
            offset: 0,
            lowerBound: lowerBound,
            upperBound: upperBound
        )
        let previousWeekStart = engine.adjacentPeriodAnchor(
            scope: .week,
            containing: try date("2026-06-10T12:00:00Z"),
            offset: -1,
            lowerBound: lowerBound,
            upperBound: upperBound
        )
        let firstWeekPrevious = engine.adjacentPeriodAnchor(
            scope: .week,
            containing: try date("2026-06-02T12:00:00Z"),
            offset: -1,
            lowerBound: lowerBound,
            upperBound: upperBound
        )
        let nextMonth = engine.adjacentPeriodAnchor(
            scope: .month,
            containing: try date("2026-06-10T12:00:00Z"),
            offset: 1,
            lowerBound: lowerBound,
            upperBound: upperBound
        )
        let expectedCurrentWeekStart = try date("2026-06-08T00:00:00Z")
        let expectedPreviousWeekStart = try date("2026-06-01T00:00:00Z")

        #expect(currentWeekStart == expectedCurrentWeekStart)
        #expect(previousWeekStart == expectedPreviousWeekStart)
        #expect(firstWeekPrevious == nil)
        #expect(nextMonth == nil)
    }

    @Test
    func testCardioInsightIncludesMovementWorkoutsAndExcludesStrength() throws {
        let goals = UserGoals(stepsPerDay: 10_000)
        let runStart = try date("2026-06-08T18:00:00Z")
        let run = WorkoutActivity(
            sourceIdentifier: "run",
            type: .running,
            title: "Outdoor Run",
            startDate: runStart,
            endDate: runStart.addingTimeInterval(45 * 60),
            distanceMeters: 5_000,
            activeEnergyKilocalories: 420,
            heartRateSamples: [
                WorkoutHeartRateSample(timestamp: runStart.addingTimeInterval(60), beatsPerMinute: 100),
                WorkoutHeartRateSample(timestamp: runStart.addingTimeInterval(120), beatsPerMinute: 140)
            ]
        )
        let stairStart = try date("2026-06-09T18:00:00Z")
        let stairs = WorkoutActivity(
            sourceIdentifier: "stairs",
            type: .stairClimbing,
            title: "Stair Stepper",
            startDate: stairStart,
            endDate: stairStart.addingTimeInterval(30 * 60),
            activeEnergyKilocalories: 310,
            heartRateSamples: [
                WorkoutHeartRateSample(timestamp: stairStart.addingTimeInterval(60), beatsPerMinute: 120)
            ]
        )
        let strength = WorkoutActivity(
            sourceIdentifier: "strength",
            type: .strengthTraining,
            title: "Traditional Strength Training",
            startDate: runStart.addingTimeInterval(2 * 60 * 60),
            endDate: runStart.addingTimeInterval(3 * 60 * 60),
            activeEnergyKilocalories: 500
        )
        let yoga = WorkoutActivity(
            sourceIdentifier: "yoga",
            type: .yoga,
            startDate: stairStart.addingTimeInterval(2 * 60 * 60),
            endDate: stairStart.addingTimeInterval(3 * 60 * 60),
            activeEnergyKilocalories: 150
        )
        let summaries = [
            summary("2026-06-08T00:00:00Z", steps: 9_000, goals: goals, workouts: [run, strength]),
            summary("2026-06-09T00:00:00Z", steps: 8_000, goals: goals, workouts: [stairs, yoga])
        ]

        let period = engine.periodSummary(
            scope: .week,
            containing: try date("2026-06-10T12:00:00Z"),
            summaries: summaries,
            goals: goals
        )

        #expect(period.cardioInsight.sessionCount == 2)
        #expect(period.cardioInsight.totalMinutes == 75)
        #expect(period.cardioInsight.totalDistanceMeters == 5_000)
        #expect(period.cardioInsight.totalActiveEnergyKilocalories == 730)
        #expect(period.cardioInsight.averageHeartRateBPM == 120)
        #expect(period.cardioInsight.bestWorkout?.sourceIdentifier == "run")
        #expect(period.cardioInsight.zoneSummaries.first { $0.level == 1 }?.durationSeconds == 60)
        #expect(period.cardioInsight.zoneSummaries.first { $0.level == 2 }?.durationSeconds == 1_740)
        #expect(period.cardioInsight.zoneSummaries.first { $0.level == 3 }?.durationSeconds == 2_580)
        #expect(period.cardioInsight.totalZoneSeconds == 4_380)
    }

    @Test
    func testEmptyCardioInsightIsStable() throws {
        let goals = UserGoals(stepsPerDay: 10_000)
        let period = engine.periodSummary(
            scope: .week,
            containing: try date("2026-06-10T12:00:00Z"),
            summaries: [
                summary("2026-06-08T00:00:00Z", steps: 9_000, goals: goals),
                summary("2026-06-09T00:00:00Z", steps: 8_000, goals: goals)
            ],
            goals: goals
        )

        #expect(period.cardioInsight == .empty)
        #expect(!period.cardioInsight.hasCardio)
    }

    @Test
    func testHeartRateZoneConfigurationDefaultsAndValidation() {
        let defaults = HeartRateZoneConfiguration.default

        #expect(defaults.lowerBoundsBPM == [115, 134, 153, 172])
        #expect(defaults.template(for: 114).level == 1)
        #expect(defaults.template(for: 115).level == 2)
        #expect(defaults.template(for: 134).level == 3)
        #expect(defaults.template(for: 153).level == 4)
        #expect(defaults.template(for: 172).level == 5)
        #expect(defaults.template(forLevel: 2).rangeLabel == "115-134 bpm")

        let custom = HeartRateZoneConfiguration(lowerBoundsBPM: [100, 120, 140, 160])
        let invalid = HeartRateZoneConfiguration(lowerBoundsBPM: [100, 120, 120, 160])

        #expect(custom.lowerBoundsBPM == [100, 120, 140, 160])
        #expect(invalid == .default)
        #expect(HeartRateZoneConfiguration.isValid(lowerBoundsBPM: [100, 120, 140, 160]))
        #expect(!HeartRateZoneConfiguration.isValid(lowerBoundsBPM: [100, 120, 120, 160]))
    }

    @Test
    func testCardioInsightAggregatesCustomHeartRateZones() throws {
        let goals = UserGoals(stepsPerDay: 10_000)
        let start = try date("2026-06-08T18:00:00Z")
        let workout = WorkoutActivity(
            sourceIdentifier: "run-zones",
            type: .running,
            startDate: start,
            endDate: start.addingTimeInterval(240),
            durationMinutes: 4,
            activeEnergyKilocalories: 80,
            heartRateSamples: [
                WorkoutHeartRateSample(timestamp: start, beatsPerMinute: 100),
                WorkoutHeartRateSample(timestamp: start.addingTimeInterval(60), beatsPerMinute: 120),
                WorkoutHeartRateSample(timestamp: start.addingTimeInterval(120), beatsPerMinute: 140),
                WorkoutHeartRateSample(timestamp: start.addingTimeInterval(180), beatsPerMinute: 180)
            ]
        )
        let summary = summary("2026-06-08T00:00:00Z", steps: 4_000, goals: goals, workouts: [workout])
        let period = engine.periodSummary(
            scope: .week,
            containing: try date("2026-06-08T12:00:00Z"),
            summaries: [summary],
            goals: goals,
            heartRateZoneConfiguration: HeartRateZoneConfiguration(lowerBoundsBPM: [90, 110, 130, 150])
        )

        #expect(period.cardioInsight.zoneSummaries.map(\.durationSeconds) == [0, 60, 60, 60, 60])
        #expect(period.cardioInsight.totalZoneSeconds == 240)
    }

    @Test
    func testTodayCoachUsesGoalWeekdayWorkoutAndHouseholdContext() throws {
        let goals = UserGoals(stepsPerDay: 10_000)
        let strengthStart = try date("2026-06-12T12:00:00Z")
        let strengthWorkout = WorkoutActivity(
            sourceIdentifier: "strength-today",
            type: .strengthTraining,
            title: "Traditional Strength Training",
            startDate: strengthStart,
            endDate: strengthStart.addingTimeInterval(60 * 60),
            activeEnergyKilocalories: 320
        )
        let today = DailyActivitySummary(
            dateStart: try date("2026-06-12T00:00:00Z"),
            steps: 6_000,
            distanceMeters: 4_500,
            activeEnergyKilocalories: 260,
            flightsClimbed: 5,
            workoutMinutes: 60,
            buckets: [],
            workouts: [strengthWorkout],
            goals: goals
        )
        let currentUserID = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000001"))
        let spouseID = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000002"))
        let competitionReceipt = CompetitionReceipt(
            window: .today,
            metric: .steps,
            generatedAt: try date("2026-06-12T13:00:00Z"),
            rows: [
                LeaderboardRow(
                    rank: 1,
                    competitor: CompetitorProfile(id: spouseID, displayName: "Tiffany"),
                    metric: .steps,
                    score: 8_000,
                    steps: 8_000,
                    distanceMeters: 6_000,
                    activeEnergyKilocalories: 320,
                    workoutMinutes: 20,
                    isCurrentUser: false
                ),
                LeaderboardRow(
                    rank: 2,
                    competitor: CompetitorProfile(id: currentUserID, displayName: "Tyron"),
                    metric: .steps,
                    score: 6_000,
                    steps: 6_000,
                    distanceMeters: 4_500,
                    activeEnergyKilocalories: 260,
                    workoutMinutes: 60,
                    isCurrentUser: true
                )
            ],
            currentUserRank: 2,
            gapToNextRank: 2_000,
            headline: "Tiffany is ahead today."
        )

        let insights = engine.todayCoachInsights(
            today: today,
            history: [
                summary("2026-05-29T00:00:00Z", steps: 10_000, goals: goals),
                summary("2026-06-05T00:00:00Z", steps: 9_500, goals: goals)
            ],
            competitionReceipt: competitionReceipt,
            now: try date("2026-06-13T12:00:00Z")
        )
        let titles = insights.map(\.title)

        #expect(titles.contains { $0.contains("steps left") })
        #expect(titles.contains { $0.hasPrefix("Behind usual") })
        #expect(titles.contains("Strength day context"))
        #expect(titles.contains("Household chase"))
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
        #expect(preferences.appTheme == .light)
        #expect(preferences.dailyStepGoalLiveActivityEnabled == false)
        #expect(preferences.heartRateZoneConfiguration == .default)
        #expect(ActivityFormatting.formattedDistance(from: 1_609.344, unit: .miles) == "1.00 mi")
        #expect(ActivityFormatting.formattedDistance(from: 1_000, unit: .kilometers) == "1.00 km")
        #expect(ActivityFormatting.formattedDuration(5_197) == "1h 26m 37s")
    }

    @Test
    func testWorkoutDisplayTitleUsesEnvironmentWithoutBreakingCustomTitles() {
        let indoorWalk = WorkoutActivity(
            sourceIdentifier: "walk",
            type: .walking,
            startDate: Date(timeIntervalSince1970: 0),
            endDate: Date(timeIntervalSince1970: 1_800),
            environment: .indoor
        )
        let customStrength = WorkoutActivity(
            sourceIdentifier: "strength",
            type: .strengthTraining,
            title: "Traditional Strength Training",
            startDate: Date(timeIntervalSince1970: 0),
            endDate: Date(timeIntervalSince1970: 1_800)
        )

        #expect(indoorWalk.displayTitle == "Indoor Walk")
        #expect(customStrength.displayTitle == "Traditional Strength Training")
    }

    @Test
    func testWorkoutHeartRateSamplesComputeAverageAndMax() {
        let start = Date(timeIntervalSince1970: 0)
        let workout = WorkoutActivity(
            sourceIdentifier: "hr",
            type: .strengthTraining,
            title: "Traditional Strength Training",
            startDate: start,
            endDate: start.addingTimeInterval(1_800),
            heartRateSamples: [
                WorkoutHeartRateSample(timestamp: start.addingTimeInterval(60), beatsPerMinute: 92),
                WorkoutHeartRateSample(timestamp: start.addingTimeInterval(120), beatsPerMinute: 118),
                WorkoutHeartRateSample(timestamp: start.addingTimeInterval(180), beatsPerMinute: 104)
            ]
        )

        #expect(abs((workout.averageHeartRateBPM ?? 0) - 104.666) < 0.01)
        #expect(workout.maxHeartRateBPM == 118)
    }

    @Test
    func testWorkoutRoutePointsAreSanitizedSortedAndLocalToWorkoutModel() throws {
        let start = Date(timeIntervalSince1970: 0)
        let late = try #require(WorkoutRoutePoint(
            latitude: 40.725,
            longitude: -73.990,
            altitudeMeters: 12,
            timestamp: start.addingTimeInterval(120)
        ))
        let early = try #require(WorkoutRoutePoint(
            latitude: 40.721,
            longitude: -73.995,
            altitudeMeters: .infinity,
            timestamp: start.addingTimeInterval(30)
        ))
        let invalid = WorkoutRoutePoint(
            latitude: 140,
            longitude: -73.995,
            timestamp: start.addingTimeInterval(60)
        )
        let workout = WorkoutActivity(
            sourceIdentifier: "route",
            type: .running,
            startDate: start,
            endDate: start.addingTimeInterval(1_800),
            environment: .outdoor,
            routePoints: [late, early]
        )

        #expect(invalid == nil)
        #expect(workout.hasRoute)
        #expect(workout.routePoints.map(\.timestamp) == [early.timestamp, late.timestamp])
        #expect(workout.routePoints.first?.altitudeMeters == nil)

        let encoded = try JSONEncoder().encode(workout)
        let decoded = try JSONDecoder().decode(WorkoutActivity.self, from: encoded)
        #expect(decoded.routePoints == workout.routePoints)
    }

    @Test
    func testSyncedRecordDoesNotIncludeWorkoutRoutePoints() throws {
        let start = try date("2026-06-10T10:00:00Z")
        let firstRoutePoint = try #require(WorkoutRoutePoint(
            latitude: 40.721,
            longitude: -73.995,
            timestamp: start
        ))
        let secondRoutePoint = try #require(WorkoutRoutePoint(
            latitude: 40.725,
            longitude: -73.990,
            timestamp: start.addingTimeInterval(60)
        ))
        let workout = WorkoutActivity(
            sourceIdentifier: "route-sync",
            type: .running,
            startDate: start,
            endDate: start.addingTimeInterval(1_800),
            environment: .outdoor,
            routePoints: [firstRoutePoint, secondRoutePoint]
        )
        let summary = DailyActivitySummary(
            dateStart: calendar.startOfDay(for: start),
            steps: 3_200,
            distanceMeters: 2_400,
            activeEnergyKilocalories: 180,
            flightsClimbed: 0,
            workoutMinutes: 30,
            buckets: [],
            workouts: [workout],
            goals: UserGoals()
        )

        let record = engine.syncedRecord(from: summary, updatedAt: start)
        let encoded = try JSONEncoder().encode(record)
        let text = String(data: encoded, encoding: .utf8) ?? ""

        #expect(record.workoutCount == 1)
        #expect(!text.contains("routePoints"))
        #expect(!text.contains("latitude"))
        #expect(!text.contains("longitude"))
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
        StrideSlip household code: SRWIFE2026
        Open StrideSlip > Compete, paste this code, set your board name, then tap Sync.
        """

        #expect(SharedCompetitionSettings.normalizedInviteCodeCandidates(from: inviteMessage).first == "SRWIFE2026")
        #expect(SharedCompetitionSettings.normalizedInviteCodeCandidates(from: "household code family beta").first == "FAMILYBETA")
        #expect(SharedCompetitionSettings.normalizedInviteCodeCandidates(from: "code is sr-wife-2026").first == "SRWIFE2026")
        #expect(SharedCompetitionSettings.normalizedInviteCodeCandidates(from: "SR-WIFE-2026").first == "SRWIFE2026")
        #expect(SharedCompetitionSettings.normalizedInviteCodeCandidates(from: "SRWIFE2026").first == "SRWIFE2026")
        #expect(SharedCompetitionSettings.normalizedInviteCodeCandidates(from: "copy something else").isEmpty)
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

    @Test
    func testFilteredPeriodSummaryKeepsOnlyGoalHitDays() throws {
        let goals = UserGoals(stepsPerDay: 10_000)
        let summaries = [
            summary("2026-06-09T00:00:00Z", steps: 12_000, goals: goals),
            summary("2026-06-10T00:00:00Z", steps: 4_000, goals: goals)
        ]
        let period = engine.periodSummary(
            scope: .week,
            containing: try date("2026-06-10T00:00:00Z"),
            summaries: summaries,
            goals: goals
        )
        let filtered = engine.filteredPeriodSummary(period, filter: .goalHit, goals: goals)
        #expect(filtered.summaries.count == 1)
        #expect(filtered.summaries.first?.steps == 12_000)
        #expect(filtered.goalHitDays == 1)
    }

    @Test
    func testStrengthInsightAggregatesStrengthSessions() throws {
        let goals = UserGoals()
        let strength = workout("2026-06-10T08:00:00Z", type: .strengthTraining)
        let summaries = [
            summary("2026-06-10T00:00:00Z", steps: 8_000, goals: goals, workouts: [strength])
        ]
        let period = engine.periodSummary(
            scope: .day,
            containing: try date("2026-06-10T00:00:00Z"),
            summaries: summaries,
            goals: goals
        )
        #expect(period.strengthInsight.hasStrength)
        #expect(period.strengthInsight.sessionCount == 1)
        #expect(period.strengthInsight.bestWorkout?.type == .strengthTraining)
    }

    @Test
    func testTodayCoachIncludesStreakAndPeakHourInsights() throws {
        let goals = UserGoals(stepsPerDay: 10_000)
        let today = summary(
            "2026-06-12T00:00:00Z",
            steps: 11_000,
            goals: goals,
            workouts: []
        )
        let history = [
            summary("2026-06-10T00:00:00Z", steps: 11_000, goals: goals),
            summary("2026-06-11T00:00:00Z", steps: 12_000, goals: goals),
            today
        ]
        let todayWithBuckets = DailyActivitySummary(
            dateStart: today.dateStart,
            steps: today.steps,
            distanceMeters: today.distanceMeters,
            activeEnergyKilocalories: today.activeEnergyKilocalories,
            flightsClimbed: today.flightsClimbed,
            workoutMinutes: today.workoutMinutes,
            buckets: [bucket("2026-06-12T09:00:00Z", steps: 2_400)],
            workouts: today.workouts,
            goals: goals
        )
        let insights = engine.todayCoachInsights(
            today: todayWithBuckets,
            history: history,
            competitionReceipt: nil,
            now: try date("2026-06-12T15:00:00Z")
        )
        #expect(insights.contains { $0.kind == .streak })
        #expect(insights.contains { $0.kind == .peakHour })
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

    private func summary(
        _ isoDayStart: String,
        steps: Int,
        goals: UserGoals,
        workouts: [WorkoutActivity] = []
    ) -> DailyActivitySummary {
        let start = try! date(isoDayStart)
        return DailyActivitySummary(
            dateStart: start,
            steps: steps,
            distanceMeters: Double(steps) * 0.75,
            activeEnergyKilocalories: Double(steps) * 0.04,
            flightsClimbed: steps / 2_000,
            workoutMinutes: workouts.isEmpty ? (steps >= goals.stepsPerDay ? 35 : 0) : workouts.reduce(0) { $0 + $1.durationMinutes },
            buckets: [],
            workouts: workouts,
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

struct WorkoutComparisonTests {
    private let service = WorkoutComparisonService()

    @Test
    func testLastAndBestSessionSelection() {
        let workouts = [
            workout(id: "a", day: 8, energy: 300),
            workout(id: "b", day: 9, energy: 420),
            workout(id: "c", day: 10, energy: 360)
        ]
        let current = workouts[2]
        let peers = service.peerWorkouts(for: current, in: workouts)
        #expect(service.lastSession(before: current, in: peers)?.sourceIdentifier == "b")
        #expect(service.bestSession(in: peers, excluding: current)?.sourceIdentifier == "b")
    }

    @Test
    func testCompareProducesBurnDelta() {
        let current = workout(id: "current", day: 10, energy: 400)
        let baseline = workout(id: "baseline", day: 9, energy: 320)
        let comparison = service.compare(current: current, baseline: baseline)
        #expect(comparison.deltas.contains { $0.label == "Active burn" })
        #expect(comparison.deltas.first(where: { $0.label == "Active burn" })?.deltaText.contains("+") == true)
    }

    private func workout(id: String, day: Int, energy: Double) -> WorkoutActivity {
        let calendar = Calendar(identifier: .gregorian)
        let start = calendar.date(from: DateComponents(year: 2026, month: 6, day: day, hour: 8))!
        return WorkoutActivity(
            sourceIdentifier: id,
            type: .strengthTraining,
            startDate: start,
            endDate: start.addingTimeInterval(45 * 60),
            activeEnergyKilocalories: energy
        )
    }
}
