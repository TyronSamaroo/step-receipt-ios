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

    public func summaries(
        in scope: ActivityPeriodScope,
        containing date: Date,
        from summaries: [DailyActivitySummary]
    ) -> [DailyActivitySummary] {
        let interval = dateInterval(for: scope, containing: date)
        return summaries
            .filter { summary in
                summary.dateStart >= interval.start && summary.dateStart < interval.end
            }
            .sorted { $0.dateStart < $1.dateStart }
    }

    public func periodSummary(
        scope: ActivityPeriodScope,
        containing date: Date,
        summaries: [DailyActivitySummary],
        goals: UserGoals,
        now: Date = Date()
    ) -> PeriodActivitySummary {
        let interval = dateInterval(for: scope, containing: date)
        let scopedSummaries = self.summaries(in: scope, containing: date, from: summaries)
        let periodReceipt = receipt(for: scopedSummaries, goals: goals, now: now)
        let activeDays = scopedSummaries.filter(\.hasActivityData).count
        let goalHitDays = scopedSummaries.filter { $0.steps >= goals.stepsPerDay }.count
        let workoutCount = scopedSummaries.reduce(0) { $0 + $1.workouts.count }
        let bestDay = scopedSummaries.max {
            if $0.steps == $1.steps {
                return $0.dateStart < $1.dateStart
            }
            return $0.steps < $1.steps
        }

        return PeriodActivitySummary(
            scope: scope,
            periodStart: interval.start,
            periodEnd: interval.end,
            summaries: scopedSummaries,
            receipt: periodReceipt,
            activeDays: activeDays,
            goalHitDays: goalHitDays,
            workoutCount: workoutCount,
            bestDay: bestDay,
            headline: periodHeadline(
                scope: scope,
                summaries: scopedSummaries,
                receipt: periodReceipt,
                goals: goals
            )
        )
    }

    public func todayCoachInsights(
        today: DailyActivitySummary?,
        history: [DailyActivitySummary],
        competitionReceipt: CompetitionReceipt?,
        now: Date = Date()
    ) -> [TodayCoachInsight] {
        guard let today else {
            return [
                TodayCoachInsight(
                    title: "Connect Apple Health",
                    detail: "Coach insights get personal once today's step summary is available.",
                    systemImage: "heart.fill",
                    priority: 100
                )
            ]
        }

        var insights: [TodayCoachInsight] = []
        insights.append(goalGapInsight(for: today))

        if let weekdayInsight = weekdayPaceInsight(today: today, history: history) {
            insights.append(weekdayInsight)
        }

        if let workoutInsight = workoutContextInsight(for: today) {
            insights.append(workoutInsight)
        }

        if let householdInsight = householdInsight(from: competitionReceipt) {
            insights.append(householdInsight)
        }

        if let projectionInsight = projectionInsight(today: today, now: now) {
            insights.append(projectionInsight)
        }

        return insights
            .sorted {
                if $0.priority == $1.priority {
                    return $0.title < $1.title
                }
                return $0.priority > $1.priority
            }
            .prefix(4)
            .map { $0 }
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

    private func dateInterval(for scope: ActivityPeriodScope, containing date: Date) -> DateInterval {
        switch scope {
        case .day:
            let start = calendar.startOfDay(for: date)
            let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
            return DateInterval(start: start, end: end)
        case .week:
            if let interval = calendar.dateInterval(of: .weekOfYear, for: date) {
                return interval
            }
            let start = calendar.startOfDay(for: date)
            let end = calendar.date(byAdding: .day, value: 7, to: start) ?? start.addingTimeInterval(604_800)
            return DateInterval(start: start, end: end)
        case .month:
            if let interval = calendar.dateInterval(of: .month, for: date) {
                return interval
            }
            let start = calendar.startOfDay(for: date)
            let end = calendar.date(byAdding: .day, value: 31, to: start) ?? start.addingTimeInterval(2_678_400)
            return DateInterval(start: start, end: end)
        }
    }

    private func periodHeadline(
        scope: ActivityPeriodScope,
        summaries: [DailyActivitySummary],
        receipt: InsightReceipt,
        goals: UserGoals
    ) -> String {
        guard !summaries.isEmpty else {
            return "No \(scope.displayName.lowercased()) activity yet."
        }

        let completionPercent = Int((receipt.stepGoalCompletionRate * 100).rounded())
        switch scope {
        case .day:
            if let day = summaries.first, day.steps >= goals.stepsPerDay {
                return "Daily goal cleared."
            }
            return receipt.onTrackMessage
        case .week:
            return "\(receipt.dailyAverageSteps.formatted()) average steps/day with \(completionPercent)% goal completion."
        case .month:
            return "\(summaries.filter(\.hasActivityData).count) active days and \(completionPercent)% goal completion this month."
        }
    }

    private func goalGapInsight(for today: DailyActivitySummary) -> TodayCoachInsight {
        let remaining = max(0, today.goals.stepsPerDay - today.steps)
        if remaining == 0 {
            return TodayCoachInsight(
                title: "Goal cleared",
                detail: "You are at \(today.steps.formatted()) steps. Keep the streak intact.",
                systemImage: "checkmark.circle.fill",
                priority: 95
            )
        }

        let walkingMinutes = Int(ceil(Double(remaining) / 110.0))
        return TodayCoachInsight(
            title: "\(remaining.formatted()) steps left",
            detail: "About \(walkingMinutes) min of easy walking gets you to \(today.goals.stepsPerDay.formatted()).",
            systemImage: "figure.walk",
            priority: 100
        )
    }

    private func weekdayPaceInsight(today: DailyActivitySummary, history: [DailyActivitySummary]) -> TodayCoachInsight? {
        let todayStart = calendar.startOfDay(for: today.dateStart)
        let weekday = calendar.component(.weekday, from: todayStart)
        let matchingDays = history.filter { summary in
            let sameWeekday = calendar.component(.weekday, from: summary.dateStart) == weekday
            return sameWeekday &&
                summary.dateStart < todayStart &&
                summary.hasActivityData
        }
        guard matchingDays.count >= 2 else { return nil }

        let average = Int((Double(matchingDays.reduce(0) { $0 + $1.steps }) / Double(matchingDays.count)).rounded())
        let delta = today.steps - average
        guard abs(delta) >= 750 else {
            return TodayCoachInsight(
                title: "Normal \(weekdayName(for: todayStart)) pace",
                detail: "You are within \(abs(delta).formatted()) steps of your recent \(weekdayName(for: todayStart)) average.",
                systemImage: "chart.line.uptrend.xyaxis",
                priority: 65
            )
        }

        if delta < 0 {
            return TodayCoachInsight(
                title: "Behind usual \(weekdayName(for: todayStart))",
                detail: "\(abs(delta).formatted()) steps under your recent \(weekdayName(for: todayStart)) average of \(average.formatted()).",
                systemImage: "clock.arrow.circlepath",
                priority: 90
            )
        }

        return TodayCoachInsight(
            title: "Ahead of usual \(weekdayName(for: todayStart))",
            detail: "\(delta.formatted()) steps above your recent \(weekdayName(for: todayStart)) average.",
            systemImage: "chart.line.uptrend.xyaxis",
            priority: 85
        )
    }

    private func workoutContextInsight(for today: DailyActivitySummary) -> TodayCoachInsight? {
        guard !today.workouts.isEmpty || today.workoutMinutes > 0 else { return nil }
        if today.workouts.contains(where: { $0.type == .strengthTraining }) {
            return TodayCoachInsight(
                title: "Strength day context",
                detail: "\(ActivityFormatting.formattedMinutes(today.workoutMinutes)) logged. Steps can be lighter, but a short walk helps recovery.",
                systemImage: "dumbbell",
                priority: 82
            )
        }

        if let topWorkout = today.workouts.first {
            return TodayCoachInsight(
                title: "\(topWorkout.displayTitle) logged",
                detail: "\(ActivityFormatting.formattedMinutes(today.workoutMinutes)) of workout time is already on the board today.",
                systemImage: "bolt.heart",
                priority: 80
            )
        }

        return TodayCoachInsight(
            title: "Workout time logged",
            detail: "\(ActivityFormatting.formattedMinutes(today.workoutMinutes)) already counts toward your weekly training goal.",
            systemImage: "timer",
            priority: 78
        )
    }

    private func householdInsight(from receipt: CompetitionReceipt?) -> TodayCoachInsight? {
        guard
            let receipt,
            let currentRow = receipt.rows.first(where: \.isCurrentUser),
            receipt.rows.count > 1
        else { return nil }

        if currentRow.rank == 1, let nextRow = receipt.rows.dropFirst().first {
            let lead = currentRow.score - nextRow.score
            return TodayCoachInsight(
                title: "Household lead",
                detail: "You are ahead by \(formattedCompetitionScore(lead, metric: receipt.metric)) in \(receipt.window.displayName.lowercased()).",
                systemImage: "person.2.fill",
                priority: 75
            )
        }

        if let gap = receipt.gapToNextRank, gap > 0 {
            return TodayCoachInsight(
                title: "Household chase",
                detail: "\(formattedCompetitionScore(gap, metric: receipt.metric)) separates you from the next rank.",
                systemImage: "person.2.fill",
                priority: 75
            )
        }

        return nil
    }

    private func projectionInsight(today: DailyActivitySummary, now: Date) -> TodayCoachInsight? {
        guard calendar.isDate(today.dateStart, inSameDayAs: now) else { return nil }
        let projected = projectionForToday(from: [today], now: now) ?? today.steps
        guard projected > 0 else { return nil }

        if projected >= today.goals.stepsPerDay {
            return TodayCoachInsight(
                title: "Projected on track",
                detail: "Current pace points to about \(projected.formatted()) steps today.",
                systemImage: "target",
                priority: 70
            )
        }

        return TodayCoachInsight(
            title: "Projected short",
            detail: "Current pace points to about \(projected.formatted()) steps, below today's goal.",
            systemImage: "target",
            priority: 88
        )
    }

    private func weekdayName(for date: Date) -> String {
        let index = calendar.component(.weekday, from: date) - 1
        let symbols = calendar.weekdaySymbols
        guard symbols.indices.contains(index) else { return "day" }
        return symbols[index]
    }

    private func formattedCompetitionScore(_ score: Double, metric: CompetitionMetric) -> String {
        switch metric {
        case .steps:
            return "\(Int(score.rounded()).formatted()) steps"
        case .distance:
            return String(format: "%.2f km", score / 1_000)
        case .activeEnergy:
            return ActivityFormatting.formattedCalories(score)
        case .workoutMinutes:
            return ActivityFormatting.formattedMinutes(score)
        }
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
