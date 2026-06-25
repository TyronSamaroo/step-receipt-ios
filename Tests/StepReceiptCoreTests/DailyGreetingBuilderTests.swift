import Foundation
import Testing
@testable import StepReceiptCore

struct DailyGreetingBuilderTests {
    private let calendar = Calendar(identifier: .gregorian)

    @Test
    func testGreetingUsesDisplayNameAndTimeOfDay() throws {
        let date = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 25, hour: 8)))
        let summary = dailySummary(on: date, steps: 4_000)
        let greeting = DailyGreetingBuilder.build(
            displayName: "Tyron",
            date: date,
            summary: summary,
            history: [summary],
            now: date
        )

        #expect(greeting.greetingLine == "Good morning, Tyron")
        #expect(!greeting.affirmationLine.isEmpty)
    }

    @Test
    func testAffirmationIsDeterministicForSameDay() throws {
        let date = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 25, hour: 14)))
        let summary = dailySummary(on: date, steps: 8_500)
        let history = [summary]

        let first = DailyGreetingBuilder.build(
            displayName: "Tyron",
            date: date,
            summary: summary,
            history: history,
            now: date
        )
        let second = DailyGreetingBuilder.build(
            displayName: "Tyron",
            date: date,
            summary: summary,
            history: history,
            now: date
        )

        #expect(first.affirmationLine == second.affirmationLine)
    }

    @Test
    func testNearGoalAffirmationMentionsRemainingSteps() throws {
        let date = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 25, hour: 10)))
        let summary = dailySummary(on: date, steps: 8_200)
        let greeting = DailyGreetingBuilder.build(
            displayName: "Tyron",
            date: date,
            summary: summary,
            history: [summary],
            now: date
        )

        #expect(greeting.affirmationLine.contains("1,800"))
    }

    @Test
    func testDailySummariesCSVIncludesGoalHit() throws {
        let date = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 25)))
        let summary = dailySummary(on: date, steps: 12_000)
        let csv = WorkoutExportBuilder.dailySummariesCSV(history: [summary])
        let lines = csv.split(separator: "\n")

        #expect(lines.first == "date,steps,distance_m,active_energy_kcal,flights,workout_min,goal_steps,goal_hit")
        #expect(lines.count == 2)
        #expect(lines[1].hasSuffix(",yes"))
    }

    private func dailySummary(on date: Date, steps: Int) -> DailyActivitySummary {
        DailyActivitySummary(
            dateStart: calendar.startOfDay(for: date),
            steps: steps,
            distanceMeters: 4_500,
            activeEnergyKilocalories: 420,
            flightsClimbed: 8,
            workoutMinutes: 35,
            buckets: [],
            workouts: [],
            goals: UserGoals(stepsPerDay: 10_000)
        )
    }
}
