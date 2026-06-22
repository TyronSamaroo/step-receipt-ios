import Foundation
import Testing
#if canImport(StepReceiptCore)
@testable import StepReceiptCore
#endif

struct WeekPatternBuilderTests {
    private enum TestDateError: Error {
        case invalidISODate(String)
    }

    private let calendar: Calendar

    init() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 2
        self.calendar = calendar
    }

    @Test
    func testMedianStepsByClockHourUsesMedianAcrossDays() throws {
        let dayOne = try dayStart("2026-06-16T00:00:00Z")
        let dayTwo = try dayStart("2026-06-17T00:00:00Z")
        let buckets = [
            bucket(day: dayOne, hour: 8, steps: 400),
            bucket(day: dayOne, hour: 8, steps: 800),
            bucket(day: dayTwo, hour: 8, steps: 600),
            bucket(day: dayTwo, hour: 12, steps: 900)
        ]

        let medians = WeekPatternBuilder.medianStepsByClockHour(from: buckets, calendar: calendar)

        #expect(medians[8] == 600)
        #expect(medians[12] == 900)
        #expect(medians[0] == 0)
    }

    @Test
    func testBuildFindsPeakHourAndActiveWindow() throws {
        let periodStart = try dayStart("2026-06-16T00:00:00Z")
        let periodEnd = calendar.date(byAdding: .day, value: 7, to: periodStart)!
        var buckets: [HealthMetricBucket] = []

        for dayOffset in 0..<3 {
            let day = calendar.date(byAdding: .day, value: dayOffset, to: periodStart)!
            buckets.append(bucket(day: day, hour: 7, steps: 500))
            buckets.append(bucket(day: day, hour: 8, steps: 900))
            buckets.append(bucket(day: day, hour: 9, steps: 700))
            buckets.append(bucket(day: day, hour: 13, steps: 300))
        }

        let pattern = WeekPatternBuilder.build(
            from: buckets,
            scope: .week,
            periodStart: periodStart,
            periodEnd: periodEnd,
            calendar: calendar
        )

        #expect(pattern.peakHour == 8)
        #expect(pattern.peakHourMedianSteps == 900)
        #expect(pattern.activeHours == [7, 8, 9, 13])
        #expect(pattern.quietHours.contains(0))
        #expect(pattern.mostActiveWindowStart != nil)
        #expect(pattern.mostActiveWindowEnd != nil)
    }

    @Test
    func testMostActiveWindowMatchesSharedHelper() throws {
        let day = try dayStart("2026-06-17T00:00:00Z")
        let buckets = [
            bucket(day: day, hour: 7, steps: 400),
            bucket(day: day, hour: 8, steps: 900),
            bucket(day: day, hour: 9, steps: 0),
            bucket(day: day, hour: 12, steps: 300),
            bucket(day: day, hour: 13, steps: 350),
            bucket(day: day, hour: 14, steps: 500)
        ]

        let digest = TodayQuickDigestBuilder.digest(
            for: DailyActivitySummary(
                dateStart: day,
                steps: buckets.reduce(0) { $0 + $1.steps },
                distanceMeters: 0,
                activeEnergyKilocalories: 0,
                flightsClimbed: 0,
                workoutMinutes: 0,
                buckets: buckets,
                workouts: [],
                goals: UserGoals()
            )
        )

        let sharedWindow = ActivityPatternAnalysis.mostActiveWindow(in: buckets)

        #expect(digest.mostActiveWindowStart == sharedWindow?.start)
        #expect(digest.mostActiveWindowEnd == sharedWindow?.end)
    }

    @Test
    func testWeekPatternCoachInsightsIncludePeakAndGoalDays() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 2
        let engine = InsightEngine(calendar: calendar)
        let periodStart = try dayStart("2026-06-16T00:00:00Z")
        let periodEnd = calendar.date(byAdding: .day, value: 7, to: periodStart)!
        let goals = UserGoals(stepsPerDay: 8_000)

        let pattern = WeekPatternBuilder.build(
            from: [
                bucket(day: periodStart, hour: 18, steps: 1_200),
                bucket(day: periodStart, hour: 19, steps: 1_500)
            ],
            scope: .week,
            periodStart: periodStart,
            periodEnd: periodEnd,
            calendar: calendar
        )

        let summaries = (0..<3).map { offset in
            DailyActivitySummary(
                dateStart: calendar.date(byAdding: .day, value: offset, to: periodStart)!,
                steps: 9_000,
                distanceMeters: 0,
                activeEnergyKilocalories: 0,
                flightsClimbed: 0,
                workoutMinutes: 0,
                buckets: [],
                workouts: [],
                goals: goals
            )
        }

        let period = engine.periodSummary(
            scope: .week,
            containing: periodStart,
            summaries: summaries,
            goals: goals
        )

        let insights = engine.weekPatternCoachInsights(
            pattern: pattern,
            period: period,
            priorPeriod: nil,
            goals: goals
        )

        #expect(!insights.isEmpty)
        #expect(insights.contains { $0.id == "peak-hour" })
        #expect(insights.contains { $0.id == "goal-days" })
    }

    private func dayStart(_ isoDate: String) throws -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        guard let date = formatter.date(from: isoDate) else {
            throw TestDateError.invalidISODate(isoDate)
        }
        return calendar.startOfDay(for: date)
    }

    private func bucket(day: Date, hour: Int, steps: Int) -> HealthMetricBucket {
        let start = calendar.date(byAdding: .hour, value: hour, to: calendar.startOfDay(for: day))!
        return HealthMetricBucket(
            startDate: start,
            endDate: start.addingTimeInterval(3_600),
            steps: steps,
            distanceMeters: Double(steps) * 0.74,
            activeEnergyKilocalories: Double(steps) * 0.038
        )
    }
}
