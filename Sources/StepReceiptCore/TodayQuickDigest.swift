import Foundation

public struct TodayQuickDigest: Equatable, Sendable {
    public let peakHourStart: Date?
    public let peakHourSteps: Int
    public let mostActiveWindowStart: Date?
    public let mostActiveWindowEnd: Date?
    public let activeEnergyKilocalories: Double
    public let remainingSteps: Int
    public let goalReached: Bool
    public let workoutCount: Int
    public let workoutMinutes: Double
    public let action: TodayQuickDigestAction

    public init(
        peakHourStart: Date?,
        peakHourSteps: Int,
        mostActiveWindowStart: Date? = nil,
        mostActiveWindowEnd: Date? = nil,
        activeEnergyKilocalories: Double = 0,
        remainingSteps: Int,
        goalReached: Bool,
        workoutCount: Int,
        workoutMinutes: Double,
        action: TodayQuickDigestAction
    ) {
        self.peakHourStart = peakHourStart
        self.peakHourSteps = max(0, peakHourSteps)
        self.mostActiveWindowStart = mostActiveWindowStart
        self.mostActiveWindowEnd = mostActiveWindowEnd
        self.activeEnergyKilocalories = max(0, activeEnergyKilocalories)
        self.remainingSteps = max(0, remainingSteps)
        self.goalReached = goalReached
        self.workoutCount = max(0, workoutCount)
        self.workoutMinutes = max(0, workoutMinutes)
        self.action = action
    }
}

public enum TodayQuickDigestAction: Equatable, Sendable {
    case refresh
    case openLatestWorkout
    case openTodayDetail
}

public enum TodayQuickDigestBuilder {
    public static func digest(for summary: DailyActivitySummary) -> TodayQuickDigest {
        let peakBucket = summary.buckets
            .filter { $0.steps > 0 }
            .max {
                if $0.steps == $1.steps {
                    return $0.startDate > $1.startDate
                }
                return $0.steps < $1.steps
            }
        let remainingSteps = max(0, summary.goals.stepsPerDay - summary.steps)
        let action: TodayQuickDigestAction

        if !summary.workouts.isEmpty {
            action = .openLatestWorkout
        } else if summary.hasActivityData {
            action = .openTodayDetail
        } else {
            action = .refresh
        }

        let activeWindow = ActivityPatternAnalysis.mostActiveWindow(in: summary.buckets)

        return TodayQuickDigest(
            peakHourStart: peakBucket?.startDate,
            peakHourSteps: peakBucket?.steps ?? 0,
            mostActiveWindowStart: activeWindow?.start,
            mostActiveWindowEnd: activeWindow?.end,
            activeEnergyKilocalories: summary.activeEnergyKilocalories,
            remainingSteps: remainingSteps,
            goalReached: remainingSteps == 0,
            workoutCount: summary.workouts.count,
            workoutMinutes: summary.workoutMinutes,
            action: action
        )
    }
}
