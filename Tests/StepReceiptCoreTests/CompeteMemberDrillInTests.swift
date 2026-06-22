import Foundation
import Testing
@testable import StepReceiptCore

@Suite
struct CompeteMemberDrillInTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 2
        return calendar
    }()

    private func date(_ iso: String) throws -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        guard let value = formatter.date(from: iso) else {
            throw TestDateError.invalidISODate(iso)
        }
        return value
    }

    private enum TestDateError: Error {
        case invalidISODate(String)
    }

    @Test
    func testMemberPeriodBreakdownFillsWeekWithZeros() throws {
        let engine = CompetitionEngine(calendar: calendar)
        let tyron = try CompetitorProfile(
            id: #require(UUID(uuidString: "00000000-0000-0000-0000-000000000101")),
            displayName: "Tyron",
            initials: "T"
        )
        let tiffany = try CompetitorProfile(
            id: #require(UUID(uuidString: "00000000-0000-0000-0000-000000000102")),
            displayName: "Tiffany",
            initials: "TI"
        )
        let now = try date("2026-06-18T18:00:00Z")
        let entries = [
            CompetitionEntry(
                competitor: tyron,
                dayKey: "2026-06-16",
                steps: 11_200,
                distanceMeters: 8_400,
                activeEnergyKilocalories: 420,
                workoutMinutes: 45,
                updatedAt: now
            ),
            CompetitionEntry(
                competitor: tyron,
                dayKey: "2026-06-18",
                steps: 9_800,
                distanceMeters: 7_100,
                activeEnergyKilocalories: 360,
                workoutMinutes: 30,
                updatedAt: now
            ),
            CompetitionEntry(
                competitor: tiffany,
                dayKey: "2026-06-17",
                steps: 12_500,
                distanceMeters: 9_200,
                activeEnergyKilocalories: 510,
                workoutMinutes: 55,
                updatedAt: now
            )
        ]
        let goals = UserGoals(stepsPerDay: 10_000)

        let breakdown = engine.memberPeriodBreakdown(
            entries: entries,
            competitor: tyron,
            scope: .week,
            metric: .steps,
            goals: goals,
            now: now
        )

        #expect(breakdown.competitor.id == tyron.id)
        #expect(breakdown.days.count == 7)
        #expect(breakdown.activeDays == 2)
        #expect(breakdown.goalHitDays == 1)
        #expect(breakdown.totalScore == 21_000)
        #expect(breakdown.bestDay?.dayKey == "2026-06-16")
        #expect(breakdown.days.first(where: { $0.dayKey == "2026-06-15" })?.hasActivity == false)
    }

    @Test
    func testMemberPeriodBreakdownMonthScopeAndMetricTotals() throws {
        let engine = CompetitionEngine(calendar: calendar)
        let tiffany = try CompetitorProfile(
            id: #require(UUID(uuidString: "00000000-0000-0000-0000-000000000102")),
            displayName: "Tiffany",
            initials: "TI"
        )
        let now = try date("2026-06-18T18:00:00Z")
        let entries = [
            CompetitionEntry(
                competitor: tiffany,
                dayKey: "2026-06-05",
                steps: 8_000,
                distanceMeters: 6_000,
                activeEnergyKilocalories: 300,
                workoutMinutes: 20,
                updatedAt: now
            ),
            CompetitionEntry(
                competitor: tiffany,
                dayKey: "2026-06-18",
                steps: 10_500,
                distanceMeters: 7_800,
                activeEnergyKilocalories: 390,
                workoutMinutes: 35,
                updatedAt: now
            ),
            CompetitionEntry(
                competitor: tiffany,
                dayKey: "2026-05-20",
                steps: 99_000,
                distanceMeters: 70_000,
                activeEnergyKilocalories: 4_000,
                workoutMinutes: 500,
                updatedAt: now
            )
        ]

        let breakdown = engine.memberPeriodBreakdown(
            entries: entries,
            competitor: tiffany,
            scope: .month,
            metric: .distance,
            goals: UserGoals(stepsPerDay: 10_000),
            now: now
        )

        #expect(breakdown.scope == .month)
        #expect(breakdown.days.count >= 28)
        #expect(breakdown.activeDays == 2)
        #expect(breakdown.totalScore == 13_800)
        #expect(breakdown.dailyAverageScore > 0)
    }

    @Test
    func testDailySummariesFromCompetitionEntries() throws {
        let engine = CompetitionEngine(calendar: calendar)
        let tyron = try CompetitorProfile(
            id: #require(UUID(uuidString: "00000000-0000-0000-0000-000000000101")),
            displayName: "Tyron",
            initials: "T"
        )
        let entries = [
            CompetitionEntry(
                competitor: tyron,
                dayKey: "2026-06-10",
                steps: 10_000,
                distanceMeters: 7_500,
                activeEnergyKilocalories: 350,
                workoutMinutes: 40,
                updatedAt: try date("2026-06-10T12:00:00Z")
            )
        ]
        let goals = UserGoals(stepsPerDay: 10_000)

        let summaries = engine.dailySummaries(from: entries, goals: goals)

        #expect(summaries.count == 1)
        #expect(summaries[0].steps == 10_000)
        #expect(summaries[0].workoutMinutes == 40)
        #expect(summaries[0].hasActivityData)
        #expect(summaries[0].goals.stepsPerDay == 10_000)
    }
}
