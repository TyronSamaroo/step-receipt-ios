import Foundation

public struct InsightEngine: Sendable {
    public let calendar: Calendar

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    public func aggregateDay(
        containing date: Date,
        buckets: [HealthMetricBucket],
        workouts: [WorkoutActivity],
        goals: UserGoals
    ) -> DailyActivitySummary {
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
        let dayBuckets = buckets.filter { bucket in
            bucket.startDate >= start && bucket.startDate < end
        }
        let dayWorkouts = workouts.filter { workout in
            workout.startDate < end && workout.endDate > start
        }
        let workoutMinutes = dayWorkouts.reduce(0) { total, workout in
            let overlapStart = max(workout.startDate, start)
            let overlapEnd = min(workout.endDate, end)
            return total + max(0, overlapEnd.timeIntervalSince(overlapStart) / 60)
        }

        return DailyActivitySummary(
            dateStart: start,
            steps: dayBuckets.reduce(0) { $0 + $1.steps },
            distanceMeters: dayBuckets.reduce(0) { $0 + $1.distanceMeters },
            activeEnergyKilocalories: dayBuckets.reduce(0) { $0 + $1.activeEnergyKilocalories },
            flightsClimbed: dayBuckets.reduce(0) { $0 + $1.flightsClimbed },
            workoutMinutes: workoutMinutes,
            buckets: dayBuckets,
            workouts: dayWorkouts,
            goals: goals
        )
    }

    public func dailySummaries(
        from buckets: [HealthMetricBucket],
        workouts: [WorkoutActivity],
        startDate: Date,
        endDate: Date,
        goals: UserGoals
    ) -> [DailyActivitySummary] {
        let start = calendar.startOfDay(for: startDate)
        let inclusiveEnd = calendar.startOfDay(for: endDate)
        guard start <= inclusiveEnd else { return [] }

        var summaries: [DailyActivitySummary] = []
        var cursor = start
        while cursor <= inclusiveEnd {
            summaries.append(aggregateDay(containing: cursor, buckets: buckets, workouts: workouts, goals: goals))
            cursor = calendar.date(byAdding: .day, value: 1, to: cursor) ?? cursor.addingTimeInterval(86_400)
        }
        return summaries
    }

    public func filterWorkouts(
        _ workouts: [WorkoutActivity],
        kind: ActivityKind?,
        startDate: Date? = nil,
        endDate: Date? = nil
    ) -> [WorkoutActivity] {
        workouts
            .filter { workout in
                if let kind, workout.type != kind { return false }
                if let startDate, workout.endDate < startDate { return false }
                if let endDate, workout.startDate > endDate { return false }
                return true
            }
            .sorted { $0.startDate > $1.startDate }
    }

    public func filterDailySummaries(
        _ summaries: [DailyActivitySummary],
        filter: DailySummaryFilter,
        sort: DailySummarySort
    ) -> [DailyActivitySummary] {
        summaries
            .filter { summary in
                switch filter {
                case .all:
                    return true
                case .activeDays:
                    return summary.hasActivityData
                case .goalHit:
                    return summary.steps >= summary.goals.stepsPerDay
                case .goalMissed:
                    return summary.steps < summary.goals.stepsPerDay
                case .workoutDays:
                    return !summary.workouts.isEmpty || summary.workoutMinutes > 0
                case .lightDays:
                    return summary.hasActivityData && summary.steps < summary.goals.stepsPerDay && summary.workoutMinutes == 0
                }
            }
            .sorted { lhs, rhs in
                switch sort {
                case .newest:
                    return lhs.dateStart > rhs.dateStart
                case .steps:
                    return lhs.steps == rhs.steps ? lhs.dateStart > rhs.dateStart : lhs.steps > rhs.steps
                case .distance:
                    return lhs.distanceMeters == rhs.distanceMeters ? lhs.dateStart > rhs.dateStart : lhs.distanceMeters > rhs.distanceMeters
                case .activeEnergy:
                    return lhs.activeEnergyKilocalories == rhs.activeEnergyKilocalories ? lhs.dateStart > rhs.dateStart : lhs.activeEnergyKilocalories > rhs.activeEnergyKilocalories
                case .workoutMinutes:
                    return lhs.workoutMinutes == rhs.workoutMinutes ? lhs.dateStart > rhs.dateStart : lhs.workoutMinutes > rhs.workoutMinutes
                }
            }
    }

    public func receipt(
        for summaries: [DailyActivitySummary],
        goals: UserGoals,
        now: Date = Date()
    ) -> InsightReceipt {
        let sorted = summaries.sorted { $0.dateStart < $1.dateStart }
        let periodStart = sorted.first?.dateStart ?? calendar.startOfDay(for: now)
        let periodEnd = sorted.last?.dateStart ?? calendar.startOfDay(for: now)
        let totalSteps = sorted.reduce(0) { $0 + $1.steps }
        let totalDistance = sorted.reduce(0) { $0 + $1.distanceMeters }
        let totalEnergy = sorted.reduce(0) { $0 + $1.activeEnergyKilocalories }
        let totalFlights = sorted.reduce(0) { $0 + $1.flightsClimbed }
        let totalWorkoutMinutes = sorted.reduce(0) { $0 + $1.workoutMinutes }
        let averageSteps = sorted.isEmpty ? 0 : Int((Double(totalSteps) / Double(sorted.count)).rounded())
        let bestSummary = sorted.max { $0.steps < $1.steps }
        let bestDay = bestSummary.map {
            DailyHighlight(
                date: $0.dateStart,
                steps: $0.steps,
                distanceMeters: $0.distanceMeters,
                activeEnergyKilocalories: $0.activeEnergyKilocalories
            )
        }
        let completionRate = sorted.isEmpty ? 0 : Double(sorted.filter { $0.steps >= goals.stepsPerDay }.count) / Double(sorted.count)
        let projectedStepsToday = projectionForToday(from: sorted, now: now)
        let streak = currentStepGoalStreak(in: sorted, goal: goals.stepsPerDay)

        return InsightReceipt(
            periodStart: periodStart,
            periodEnd: periodEnd,
            generatedAt: now,
            totalSteps: totalSteps,
            totalDistanceMeters: totalDistance,
            totalActiveEnergyKilocalories: totalEnergy,
            totalFlightsClimbed: totalFlights,
            totalWorkoutMinutes: totalWorkoutMinutes,
            dailyAverageSteps: averageSteps,
            bestDay: bestDay,
            bestMonth: bestMonth(from: sorted),
            currentStepGoalStreakDays: streak,
            projectedStepsToday: projectedStepsToday,
            stepGoalCompletionRate: completionRate,
            onTrackMessage: onTrackMessage(
                today: sorted.last,
                projectedStepsToday: projectedStepsToday,
                completionRate: completionRate,
                goals: goals
            )
        )
    }

    public func syncedRecord(
        from summary: DailyActivitySummary,
        updatedAt: Date = Date()
    ) -> SyncedSummaryRecord {
        SyncedSummaryRecord(
            dayKey: ActivityFormatting.dayKey(for: summary.dateStart, calendar: calendar),
            dateStart: summary.dateStart,
            steps: summary.steps,
            distanceMeters: summary.distanceMeters,
            activeEnergyKilocalories: summary.activeEnergyKilocalories,
            flightsClimbed: summary.flightsClimbed,
            workoutMinutes: summary.workoutMinutes,
            workoutCount: summary.workouts.count,
            stepGoal: summary.goals.stepsPerDay,
            updatedAt: updatedAt
        )
    }

    private func projectionForToday(from summaries: [DailyActivitySummary], now: Date) -> Int? {
        guard let today = summaries.last, calendar.isDate(today.dateStart, inSameDayAs: now) else { return nil }
        let start = calendar.startOfDay(for: now)
        let elapsed = max(1, now.timeIntervalSince(start))
        let dayLength = (calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)).timeIntervalSince(start)
        return Int((Double(today.steps) / min(1, elapsed / dayLength)).rounded())
    }

    private func currentStepGoalStreak(in summaries: [DailyActivitySummary], goal: Int) -> Int {
        var streak = 0
        for summary in summaries.sorted(by: { $0.dateStart > $1.dateStart }) {
            if summary.steps >= goal {
                streak += 1
            } else {
                break
            }
        }
        return streak
    }

    private func bestMonth(from summaries: [DailyActivitySummary]) -> MonthHighlight? {
        var monthTotals: [Date: (steps: Int, days: Int)] = [:]
        for summary in summaries {
            let components = calendar.dateComponents([.year, .month], from: summary.dateStart)
            guard let monthStart = calendar.date(from: components) else { continue }
            let existing = monthTotals[monthStart] ?? (0, 0)
            monthTotals[monthStart] = (existing.steps + summary.steps, existing.days + (summary.hasActivityData ? 1 : 0))
        }
        guard let best = monthTotals.max(by: { $0.value.steps < $1.value.steps }) else { return nil }
        return MonthHighlight(monthStart: best.key, steps: best.value.steps, activeDays: best.value.days)
    }

    private func onTrackMessage(
        today: DailyActivitySummary?,
        projectedStepsToday: Int?,
        completionRate: Double,
        goals: UserGoals
    ) -> String {
        if let projectedStepsToday, projectedStepsToday >= goals.stepsPerDay {
            return "On pace to hit your step goal today."
        }
        if let today, today.steps >= goals.stepsPerDay {
            return "Step goal already cleared today."
        }
        if completionRate >= 0.8 {
            return "Strong week: most days are landing above goal."
        }
        if completionRate >= 0.5 {
            return "Close: a short walk could push more days over goal."
        }
        return "Behind goal pace: prioritize an easy walk block."
    }
}
