import Foundation

public struct DailyGreeting: Equatable, Sendable {
    public let greetingLine: String
    public let affirmationLine: String

    public init(greetingLine: String, affirmationLine: String) {
        self.greetingLine = greetingLine
        self.affirmationLine = affirmationLine
    }
}

public enum DailyGreetingBuilder {
    public static func build(
        displayName: String,
        date: Date,
        summary: DailyActivitySummary,
        history: [DailyActivitySummary],
        weekComparison: PeriodComparisonInsight? = nil,
        calendar: Calendar = .current,
        now: Date = Date()
    ) -> DailyGreeting {
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = trimmedName.isEmpty ? "You" : trimmedName
        let greetingLine = "\(timeOfDayGreeting(for: now, calendar: calendar)), \(name)"
        let affirmationLine = affirmation(
            date: date,
            displayName: name,
            summary: summary,
            history: history,
            weekComparison: weekComparison,
            calendar: calendar
        )
        return DailyGreeting(greetingLine: greetingLine, affirmationLine: affirmationLine)
    }

    private static func timeOfDayGreeting(for date: Date, calendar: Calendar) -> String {
        let hour = calendar.component(.hour, from: date)
        switch hour {
        case 5..<12:
            return "Good morning"
        case 12..<17:
            return "Good afternoon"
        case 17..<22:
            return "Good evening"
        default:
            return "Good night"
        }
    }

    private static func affirmation(
        date: Date,
        displayName: String,
        summary: DailyActivitySummary,
        history: [DailyActivitySummary],
        weekComparison: PeriodComparisonInsight?,
        calendar: Calendar
    ) -> String {
        let goal = summary.goals.stepsPerDay
        let remaining = max(0, goal - summary.steps)
        let streak = currentStepGoalStreak(in: history, goal: goal, calendar: calendar)
        let templates = affirmationTemplates(
            summary: summary,
            remaining: remaining,
            goal: goal,
            streak: streak,
            weekComparison: weekComparison
        )
        let index = deterministicTemplateIndex(
            date: date,
            displayName: displayName,
            count: templates.count
        )
        return templates[index]
    }

    private static func affirmationTemplates(
        summary: DailyActivitySummary,
        remaining: Int,
        goal: Int,
        streak: Int,
        weekComparison: PeriodComparisonInsight?
    ) -> [String] {
        if summary.stepGoalProgress >= 1 {
            return [
                "Goal cleared — enjoy the win and keep moving.",
                "You hit \(goal.formatted()) steps. Momentum looks good, \(summary.steps.formatted()) strong.",
                "Step goal done. Small wins stack into big weeks."
            ]
        }

        if remaining <= 2_000 {
            return [
                "You're \(remaining.formatted()) steps from your goal — steady wins today.",
                "\(remaining.formatted()) steps to go. A short walk closes the gap.",
                "Almost there — \(remaining.formatted()) steps stand between you and the goal."
            ]
        }

        if streak >= 2 {
            return [
                "\(streak)-day goal streak — protect it with one more walk.",
                "You've hit your goal \(streak) days running. Keep the rhythm today.",
                "Streak at \(streak) days. One focused push keeps it alive."
            ]
        }

        if let stepsMetric = weekComparison?.metrics.first(where: { $0.title.localizedCaseInsensitiveContains("step") }),
           stepsMetric.isImprovement == true {
            return [
                "Steps are up week over week — build on that today.",
                "You're ahead of last week on steps. Keep the pace.",
                "Week-over-week steps are climbing — stay consistent."
            ]
        }

        if summary.steps == 0 && summary.workoutMinutes == 0 {
            return [
                "Quiet day so far — a short walk is a great start.",
                "Plenty of day left. One lap now beats none later.",
                "No pressure — move when it fits and the steps will follow."
            ]
        }

        return [
            "\(remaining.formatted()) steps to \(goal.formatted()) — pace yourself and stay consistent.",
            "You're at \(summary.steps.formatted()) steps. Keep stacking them through the day.",
            "Every block of movement counts — \(remaining.formatted()) left on today's goal."
        ]
    }

    private static func deterministicTemplateIndex(date: Date, displayName: String, count: Int) -> Int {
        guard count > 0 else { return 0 }
        let dayToken = Calendar.current.startOfDay(for: date).timeIntervalSince1970
        var hasher = Hasher()
        hasher.combine(dayToken)
        hasher.combine(displayName.lowercased())
        return abs(hasher.finalize()) % count
    }

    private static func currentStepGoalStreak(
        in history: [DailyActivitySummary],
        goal: Int,
        calendar: Calendar
    ) -> Int {
        let sorted = history.sorted { $0.dateStart > $1.dateStart }
        var streak = 0
        for day in sorted {
            guard day.steps >= goal else { break }
            streak += 1
        }
        return streak
    }
}
