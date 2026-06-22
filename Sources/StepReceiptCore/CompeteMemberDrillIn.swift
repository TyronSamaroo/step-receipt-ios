import Foundation

public struct CompeteMemberDayBreakdown: Equatable, Identifiable, Sendable {
    public var id: String { dayKey }

    public let dateStart: Date
    public let dayKey: String
    public let steps: Int
    public let distanceMeters: Double
    public let activeEnergyKilocalories: Double
    public let workoutMinutes: Double

    public init(
        dateStart: Date,
        dayKey: String,
        steps: Int,
        distanceMeters: Double,
        activeEnergyKilocalories: Double,
        workoutMinutes: Double
    ) {
        self.dateStart = dateStart
        self.dayKey = dayKey
        self.steps = max(0, steps)
        self.distanceMeters = max(0, distanceMeters)
        self.activeEnergyKilocalories = max(0, activeEnergyKilocalories)
        self.workoutMinutes = max(0, workoutMinutes)
    }

    public init(from entry: CompetitionEntry, dateStart: Date) {
        self.init(
            dateStart: dateStart,
            dayKey: entry.dayKey,
            steps: entry.steps,
            distanceMeters: entry.distanceMeters,
            activeEnergyKilocalories: entry.activeEnergyKilocalories,
            workoutMinutes: entry.workoutMinutes
        )
    }

    public static func empty(dateStart: Date, dayKey: String) -> CompeteMemberDayBreakdown {
        CompeteMemberDayBreakdown(
            dateStart: dateStart,
            dayKey: dayKey,
            steps: 0,
            distanceMeters: 0,
            activeEnergyKilocalories: 0,
            workoutMinutes: 0
        )
    }

    public var hasActivity: Bool {
        steps > 0 || distanceMeters > 0 || activeEnergyKilocalories > 0 || workoutMinutes > 0
    }

    public func metricValue(_ metric: CompetitionMetric) -> Double {
        switch metric {
        case .steps:
            return Double(steps)
        case .distance:
            return distanceMeters
        case .activeEnergy:
            return activeEnergyKilocalories
        case .workoutMinutes:
            return workoutMinutes
        }
    }
}

public struct CompeteMemberPeriodBreakdown: Equatable, Sendable {
    public let competitor: CompetitorProfile
    public let scope: ActivityPeriodScope
    public let metric: CompetitionMetric
    public let periodStart: Date
    public let periodEnd: Date
    public let days: [CompeteMemberDayBreakdown]
    public let activeDays: Int
    public let goalHitDays: Int
    public let totalScore: Double
    public let bestDay: CompeteMemberDayBreakdown?

    public init(
        competitor: CompetitorProfile,
        scope: ActivityPeriodScope,
        metric: CompetitionMetric,
        periodStart: Date,
        periodEnd: Date,
        days: [CompeteMemberDayBreakdown],
        activeDays: Int,
        goalHitDays: Int,
        totalScore: Double,
        bestDay: CompeteMemberDayBreakdown?
    ) {
        self.competitor = competitor
        self.scope = scope
        self.metric = metric
        self.periodStart = periodStart
        self.periodEnd = periodEnd
        self.days = days
        self.activeDays = max(0, activeDays)
        self.goalHitDays = max(0, goalHitDays)
        self.totalScore = max(0, totalScore)
        self.bestDay = bestDay
    }

    public var dailyAverageScore: Double {
        guard !days.isEmpty else { return 0 }
        return totalScore / Double(days.count)
    }

    public var periodLabel: String {
        switch scope {
        case .day:
            periodStart.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().year())
        case .week:
            "\(periodStart.formatted(.dateTime.month(.abbreviated).day())) - \(periodEnd.addingTimeInterval(-1).formatted(.dateTime.month(.abbreviated).day()))"
        case .month:
            periodStart.formatted(.dateTime.month(.wide).year())
        }
    }
}

public extension CompetitionEngine {
    func dailySummaries(from entries: [CompetitionEntry], goals: UserGoals) -> [DailyActivitySummary] {
        entries.compactMap { entry in
            guard let date = date(fromDayKey: entry.dayKey) else { return nil }
            return DailyActivitySummary(
                dateStart: calendar.startOfDay(for: date),
                steps: entry.steps,
                distanceMeters: entry.distanceMeters,
                activeEnergyKilocalories: entry.activeEnergyKilocalories,
                flightsClimbed: 0,
                workoutMinutes: entry.workoutMinutes,
                buckets: [],
                workouts: [],
                goals: goals
            )
        }
        .sorted { $0.dateStart < $1.dateStart }
    }

    func memberPeriodBreakdown(
        entries: [CompetitionEntry],
        competitor: CompetitorProfile,
        scope: ActivityPeriodScope,
        metric: CompetitionMetric,
        goals: UserGoals,
        now: Date = Date()
    ) -> CompeteMemberPeriodBreakdown {
        let insightEngine = InsightEngine(calendar: calendar)
        let interval = insightEngine.dateInterval(for: scope, containing: now)
        let competitorEntries = entries.filter { $0.competitor.id == competitor.id }
        let entryByDayKey = Dictionary(uniqueKeysWithValues: competitorEntries.map { ($0.dayKey, $0) })

        var days: [CompeteMemberDayBreakdown] = []
        var current = calendar.startOfDay(for: interval.start)
        let end = interval.end

        while current < end {
            let dayKey = ActivityFormatting.dayKey(for: current, calendar: calendar)
            if let entry = entryByDayKey[dayKey] {
                days.append(CompeteMemberDayBreakdown(from: entry, dateStart: current))
            } else {
                days.append(.empty(dateStart: current, dayKey: dayKey))
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }

        let activeDays = days.filter(\.hasActivity).count
        let goalHitDays = days.filter { $0.steps >= goals.stepsPerDay }.count
        let totalScore = days.reduce(0) { $0 + $1.metricValue(metric) }
        let bestDay = days.max { lhs, rhs in
            let lhsScore = lhs.metricValue(metric)
            let rhsScore = rhs.metricValue(metric)
            if lhsScore == rhsScore {
                return lhs.dateStart < rhs.dateStart
            }
            return lhsScore < rhsScore
        }

        return CompeteMemberPeriodBreakdown(
            competitor: competitor,
            scope: scope,
            metric: metric,
            periodStart: interval.start,
            periodEnd: interval.end,
            days: days,
            activeDays: activeDays,
            goalHitDays: goalHitDays,
            totalScore: totalScore,
            bestDay: bestDay?.hasActivity == true ? bestDay : nil
        )
    }

    func date(fromDayKey dayKey: String) -> Date? {
        let parts = dayKey.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }
}
