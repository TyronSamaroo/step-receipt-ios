import Foundation
import Testing
#if canImport(StepReceiptCore)
@testable import StepReceiptCore
#endif

struct TodayQuickDigestTests {
    private let calendar: Calendar

    init() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        self.calendar = calendar
    }

    @Test
    func testEmptyDayPrefersRefreshAction() throws {
        let summary = dailySummary(steps: 0, buckets: [], workouts: [])

        let digest = TodayQuickDigestBuilder.digest(for: summary)

        #expect(digest.peakHourStart == nil)
        #expect(digest.peakHourSteps == 0)
        #expect(digest.remainingSteps == 10_000)
        #expect(!digest.goalReached)
        #expect(digest.workoutCount == 0)
        #expect(digest.action == .refresh)
    }

    @Test
    func testGoalHitDayReportsNoRemainingSteps() throws {
        let summary = dailySummary(steps: 12_300, buckets: [
            bucket(hour: 8, steps: 2_000),
            bucket(hour: 18, steps: 4_300)
        ])

        let digest = TodayQuickDigestBuilder.digest(for: summary)

        #expect(digest.remainingSteps == 0)
        #expect(digest.goalReached)
        #expect(digest.peakHourSteps == 4_300)
        #expect(digest.peakHourStart == bucketStart(hour: 18))
        #expect(digest.action == .openTodayDetail)
    }

    @Test
    func testWorkoutDayPrefersLatestWorkoutAction() throws {
        let day = bucketStart(hour: 0)
        let workout = WorkoutActivity(
            sourceIdentifier: "run",
            type: .running,
            startDate: day.addingTimeInterval(18 * 3_600),
            endDate: day.addingTimeInterval(18 * 3_600 + 45 * 60),
            distanceMeters: 5_000,
            activeEnergyKilocalories: 420
        )
        let summary = dailySummary(
            steps: 7_200,
            buckets: [bucket(hour: 10, steps: 1_800)],
            workouts: [workout]
        )

        let digest = TodayQuickDigestBuilder.digest(for: summary)

        #expect(digest.workoutCount == 1)
        #expect(digest.workoutMinutes == 45)
        #expect(digest.action == .openLatestWorkout)
    }

    @Test
    func testMostActiveWindowUsesLongestContiguousBlock() throws {
        let summary = dailySummary(
            steps: 8_500,
            buckets: [
                bucket(hour: 7, steps: 400),
                bucket(hour: 8, steps: 900),
                bucket(hour: 9, steps: 0),
                bucket(hour: 12, steps: 300),
                bucket(hour: 13, steps: 350),
                bucket(hour: 14, steps: 500)
            ]
        )

        let digest = TodayQuickDigestBuilder.digest(for: summary)

        #expect(digest.mostActiveWindowStart == bucketStart(hour: 7))
        #expect(digest.mostActiveWindowEnd == bucket(hour: 8, steps: 900).endDate)
        #expect(digest.activeEnergyKilocalories == summary.activeEnergyKilocalories)
    }

    @Test
    func testMostActiveWindowLabelMatchesDigestRange() throws {
        let summary = dailySummary(
            steps: 8_500,
            buckets: [
                bucket(hour: 7, steps: 400),
                bucket(hour: 8, steps: 900),
                bucket(hour: 9, steps: 0),
                bucket(hour: 12, steps: 300),
                bucket(hour: 13, steps: 350),
                bucket(hour: 14, steps: 500)
            ]
        )

        let digest = TodayQuickDigestBuilder.digest(for: summary)

        guard let start = digest.mostActiveWindowStart,
              let end = digest.mostActiveWindowEnd else {
            Issue.record("Expected active window for sample buckets")
            return
        }

        let label = ActivityFormatting.formattedActiveWindowLabel(
            start: start,
            end: end,
            calendar: calendar
        )

        #expect(label == "Active 7a–9a")
    }

    private func dailySummary(
        steps: Int,
        buckets: [HealthMetricBucket],
        workouts: [WorkoutActivity] = [],
        goals: UserGoals = UserGoals(stepsPerDay: 10_000)
    ) -> DailyActivitySummary {
        DailyActivitySummary(
            dateStart: bucketStart(hour: 0),
            steps: steps,
            distanceMeters: Double(steps) * 0.74,
            activeEnergyKilocalories: Double(steps) * 0.038,
            flightsClimbed: 0,
            workoutMinutes: workouts.reduce(0) { $0 + $1.durationMinutes },
            buckets: buckets,
            workouts: workouts,
            goals: goals
        )
    }

    private func bucket(hour: Int, steps: Int) -> HealthMetricBucket {
        let start = bucketStart(hour: hour)
        return HealthMetricBucket(
            startDate: start,
            endDate: start.addingTimeInterval(3_600),
            steps: steps,
            distanceMeters: Double(steps) * 0.74,
            activeEnergyKilocalories: Double(steps) * 0.038
        )
    }

    private func bucketStart(hour: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 6, day: 17, hour: hour))!
    }
}
