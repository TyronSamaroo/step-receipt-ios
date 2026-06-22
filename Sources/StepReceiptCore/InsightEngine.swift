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
        now: Date = Date(),
        heartRateZoneConfiguration: HeartRateZoneConfiguration = .default
    ) -> PeriodActivitySummary {
        let interval = dateInterval(for: scope, containing: date)
        let scopedSummaries = self.summaries(in: scope, containing: date, from: summaries)
        let periodReceipt = receipt(for: scopedSummaries, goals: goals, now: now)
        let activeDays = scopedSummaries.filter(\.hasActivityData).count
        let goalHitDays = scopedSummaries.filter { $0.steps >= goals.stepsPerDay }.count
        let workoutCount = scopedSummaries.reduce(0) { $0 + $1.workouts.count }
        let cardioInsight = cardioInsight(
            from: scopedSummaries,
            heartRateZoneConfiguration: heartRateZoneConfiguration
        )
        let strengthInsight = strengthInsight(
            from: scopedSummaries,
            heartRateZoneConfiguration: heartRateZoneConfiguration
        )
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
            cardioInsight: cardioInsight,
            strengthInsight: strengthInsight,
            headline: periodHeadline(
                scope: scope,
                summaries: scopedSummaries,
                receipt: periodReceipt,
                goals: goals
            )
        )
    }

    public func filteredPeriodSummary(
        _ period: PeriodActivitySummary,
        filter: InsightsTrendFilter,
        goals: UserGoals,
        heartRateZoneConfiguration: HeartRateZoneConfiguration = .default,
        now: Date = Date()
    ) -> PeriodActivitySummary {
        let filteredSummaries = period.summaries.filter { filter.matches($0) }
        let periodReceipt = receipt(for: filteredSummaries, goals: goals, now: now)
        let activeDays = filteredSummaries.filter(\.hasActivityData).count
        let goalHitDays = filteredSummaries.filter { $0.steps >= goals.stepsPerDay }.count
        let workoutCount = filteredSummaries.reduce(0) { $0 + $1.workouts.count }
        let cardioInsight = cardioInsight(
            from: filteredSummaries,
            heartRateZoneConfiguration: heartRateZoneConfiguration
        )
        let strengthInsight = strengthInsight(
            from: filteredSummaries,
            heartRateZoneConfiguration: heartRateZoneConfiguration
        )
        let bestDay = filteredSummaries.max {
            if $0.steps == $1.steps {
                return $0.dateStart < $1.dateStart
            }
            return $0.steps < $1.steps
        }

        return PeriodActivitySummary(
            scope: period.scope,
            periodStart: period.periodStart,
            periodEnd: period.periodEnd,
            summaries: filteredSummaries,
            receipt: periodReceipt,
            activeDays: activeDays,
            goalHitDays: goalHitDays,
            workoutCount: workoutCount,
            bestDay: bestDay,
            cardioInsight: cardioInsight,
            strengthInsight: strengthInsight,
            headline: periodHeadline(
                scope: period.scope,
                summaries: filteredSummaries,
                receipt: periodReceipt,
                goals: goals
            )
        )
    }

    public func adjacentPeriodAnchor(
        scope: ActivityPeriodScope,
        containing date: Date,
        offset: Int,
        lowerBound: Date,
        upperBound: Date
    ) -> Date? {
        let lowerDay = calendar.startOfDay(for: lowerBound)
        let upperDay = calendar.startOfDay(for: upperBound)
        guard lowerDay <= upperDay else { return nil }
        guard offset != 0 else {
            let currentStart = calendar.startOfDay(for: dateInterval(for: scope, containing: date).start)
            return min(max(currentStart, lowerDay), upperDay)
        }

        let component: Calendar.Component = switch scope {
        case .day: .day
        case .week: .weekOfYear
        case .month: .month
        }
        guard let candidate = calendar.date(byAdding: component, value: offset, to: date) else {
            return nil
        }

        let candidateInterval = dateInterval(for: scope, containing: candidate)
        guard candidateInterval.end > lowerDay, candidateInterval.start <= upperDay else {
            return nil
        }

        let candidateDay = calendar.startOfDay(for: candidateInterval.start)
        return min(max(candidateDay, lowerDay), upperDay)
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
                    priority: 100,
                    kind: .general
                )
            ]
        }

        var insights: [TodayCoachInsight] = []
        insights.append(goalGapInsight(for: today))

        if let weekdayInsight = weekdayPaceInsight(today: today, history: history) {
            insights.append(weekdayInsight)
        }

        if let peakInsight = peakHourInsight(for: today) {
            insights.append(peakInsight)
        }

        if let streakInsight = streakInsight(history: history, goals: today.goals) {
            insights.append(streakInsight)
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

    public func weekPatternCoachInsights(
        pattern: StepPattern,
        period: PeriodActivitySummary,
        priorPeriod: PeriodActivitySummary?,
        goals: UserGoals
    ) -> [WeekPatternCoachInsight] {
        var insights: [WeekPatternCoachInsight] = []

        if pattern.peakHourMedianSteps > 0 {
            let peakLabel = ActivityFormatting.shortHourLabel(
                for: peakHourDate(hour: pattern.peakHour, calendar: calendar),
                calendar: calendar
            )
            insights.append(
                WeekPatternCoachInsight(
                    id: "peak-hour",
                    title: "Peak hour \(peakLabel)",
                    detail: "Your typical \(pattern.scope.displayName.lowercased()) peak lands around \(peakLabel) with about \(pattern.peakHourMedianSteps.formatted()) median steps.",
                    systemImage: "clock.fill"
                )
            )
        }

        if let windowStart = pattern.mostActiveWindowStart,
           let windowEnd = pattern.mostActiveWindowEnd {
            insights.append(
                WeekPatternCoachInsight(
                    id: "active-window",
                    title: "Active window",
                    detail: ActivityFormatting.formattedActiveWindowLabel(start: windowStart, end: windowEnd, calendar: calendar) + " is your most reliable movement block.",
                    systemImage: "figure.walk"
                )
            )
        }

        if !pattern.quietHours.isEmpty, pattern.activeHours.count >= 4 {
            insights.append(
                WeekPatternCoachInsight(
                    id: "quiet-hours",
                    title: "\(pattern.quietHours.count) quiet hours",
                    detail: "Most days stay quiet outside your active window — a short walk in a quiet block can add easy steps.",
                    systemImage: "moon.zzz.fill"
                )
            )
        }

        if period.goalHitDays > 0 {
            insights.append(
                WeekPatternCoachInsight(
                    id: "goal-days",
                    title: "\(period.goalHitDays) goal day\(period.goalHitDays == 1 ? "" : "s")",
                    detail: "You cleared \(goals.stepsPerDay.formatted()) steps on \(period.goalHitDays) of \(max(1, period.summaries.count)) days this \(pattern.scope.displayName.lowercased()).",
                    systemImage: "target"
                )
            )
        }

        if pattern.scope == .month,
           let priorPeriod,
           priorPeriod.receipt.dailyAverageSteps > 0 {
            let delta = period.receipt.dailyAverageSteps - priorPeriod.receipt.dailyAverageSteps
            if abs(delta) >= 250 {
                let direction = delta > 0 ? "up" : "down"
                insights.append(
                    WeekPatternCoachInsight(
                        id: "month-trend",
                        title: "Month vs last month",
                        detail: "Daily average is \(direction) \(abs(delta).formatted()) steps compared with last month.",
                        systemImage: delta > 0 ? "chart.line.uptrend.xyaxis" : "chart.line.downtrend.xyaxis"
                    )
                )
            }
        }

        return Array(insights.prefix(3))
    }

    private func peakHourDate(hour: Int, calendar: Calendar) -> Date {
        let reference = calendar.startOfDay(for: Date())
        return calendar.date(byAdding: .hour, value: hour, to: reference) ?? reference
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

    public func dateInterval(for scope: ActivityPeriodScope, containing date: Date) -> DateInterval {
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

    public func cardioInsight(
        from summaries: [DailyActivitySummary],
        scope: CardioSessionScope = .movement,
        heartRateZoneConfiguration: HeartRateZoneConfiguration
    ) -> CardioPeriodInsight {
        var workoutsBySource: [String: WorkoutActivity] = [:]
        for workout in summaries.flatMap(\.workouts) where scope.matches(workout) {
            workoutsBySource[workout.sourceIdentifier] = workout
        }

        let cardioWorkouts = workoutsBySource.values.sorted { $0.startDate < $1.startDate }
        let zoneSummaries = heartRateZoneConfiguration.zoneSummaries(for: cardioWorkouts)
        guard !cardioWorkouts.isEmpty else {
            return CardioPeriodInsight(zoneSummaries: zoneSummaries)
        }

        let heartRateSamples = cardioWorkouts.flatMap(\.heartRateSamples)
        let averageHeartRate = heartRateSamples.isEmpty
            ? nil
            : heartRateSamples.reduce(0) { $0 + $1.beatsPerMinute } / Double(heartRateSamples.count)
        let minHeartRate = heartRateSamples.map(\.beatsPerMinute).min()
        let maxHeartRate = heartRateSamples.map(\.beatsPerMinute).max()

        let bestWorkout = cardioWorkouts.max { lhs, rhs in
            let lhsEnergy = lhs.activeEnergyKilocalories ?? 0
            let rhsEnergy = rhs.activeEnergyKilocalories ?? 0
            if lhsEnergy != rhsEnergy {
                return lhsEnergy < rhsEnergy
            }

            let lhsDistance = lhs.distanceMeters ?? 0
            let rhsDistance = rhs.distanceMeters ?? 0
            if lhsDistance != rhsDistance {
                return lhsDistance < rhsDistance
            }

            if lhs.durationMinutes != rhs.durationMinutes {
                return lhs.durationMinutes < rhs.durationMinutes
            }

            return lhs.startDate < rhs.startDate
        }

        return CardioPeriodInsight(
            totalMinutes: cardioWorkouts.reduce(0) { $0 + $1.durationMinutes },
            sessionCount: cardioWorkouts.count,
            totalDistanceMeters: cardioWorkouts.reduce(0) { $0 + ($1.distanceMeters ?? 0) },
            totalActiveEnergyKilocalories: cardioWorkouts.reduce(0) { $0 + ($1.activeEnergyKilocalories ?? 0) },
            averageHeartRateBPM: averageHeartRate,
            minHeartRateBPM: minHeartRate,
            maxHeartRateBPM: maxHeartRate,
            bestWorkout: bestWorkout,
            zoneSummaries: zoneSummaries
        )
    }

    public func periodComparison(
        current: PeriodActivitySummary,
        prior: PeriodActivitySummary,
        goals: UserGoals
    ) -> PeriodComparisonInsight? {
        var metrics: [PeriodComparisonMetric] = []

        if let metric = gatedMetric(
            title: "Average Steps",
            currentValue: current.receipt.dailyAverageSteps,
            priorValue: prior.receipt.dailyAverageSteps,
            format: { "\($0.formatted())" },
            delta: signedInteger(current.receipt.dailyAverageSteps - prior.receipt.dailyAverageSteps),
            improvement: current.receipt.dailyAverageSteps > prior.receipt.dailyAverageSteps
        ) {
            metrics.append(metric)
        }

        if let metric = gatedMetric(
            title: "Goal Days",
            currentValue: current.goalHitDays,
            priorValue: prior.goalHitDays,
            format: { "\($0)/7" },
            delta: signedInteger(current.goalHitDays - prior.goalHitDays),
            improvement: current.goalHitDays > prior.goalHitDays
        ) {
            metrics.append(metric)
        }

        if let metric = gatedMetric(
            title: "Workout Minutes",
            currentValue: current.receipt.totalWorkoutMinutes,
            priorValue: prior.receipt.totalWorkoutMinutes,
            format: { ActivityFormatting.formattedMinutes($0) },
            delta: signedMinutes(current.receipt.totalWorkoutMinutes - prior.receipt.totalWorkoutMinutes),
            improvement: current.receipt.totalWorkoutMinutes > prior.receipt.totalWorkoutMinutes
        ) {
            metrics.append(metric)
        }

        if let metric = gatedMetric(
            title: "Cardio Minutes",
            currentValue: current.cardioInsight.totalMinutes,
            priorValue: prior.cardioInsight.totalMinutes,
            format: { ActivityFormatting.formattedMinutes($0) },
            delta: signedMinutes(current.cardioInsight.totalMinutes - prior.cardioInsight.totalMinutes),
            improvement: current.cardioInsight.totalMinutes > prior.cardioInsight.totalMinutes
        ) {
            metrics.append(metric)
        }

        if let metric = gatedMetric(
            title: "Distance",
            currentValue: current.receipt.totalDistanceMeters,
            priorValue: prior.receipt.totalDistanceMeters,
            format: { String(format: "%.2f km", $0 / 1_000) },
            delta: signedDistance(current.receipt.totalDistanceMeters - prior.receipt.totalDistanceMeters),
            improvement: current.receipt.totalDistanceMeters > prior.receipt.totalDistanceMeters
        ) {
            metrics.append(metric)
        }

        if let metric = gatedMetric(
            title: "Active Burn",
            currentValue: current.receipt.totalActiveEnergyKilocalories,
            priorValue: prior.receipt.totalActiveEnergyKilocalories,
            format: { ActivityFormatting.formattedCalories($0) },
            delta: signedCalories(current.receipt.totalActiveEnergyKilocalories - prior.receipt.totalActiveEnergyKilocalories),
            improvement: current.receipt.totalActiveEnergyKilocalories > prior.receipt.totalActiveEnergyKilocalories
        ) {
            metrics.append(metric)
        }

        guard !metrics.isEmpty else { return nil }
        return PeriodComparisonInsight(metrics: metrics)
    }

    private func strengthInsight(
        from summaries: [DailyActivitySummary],
        heartRateZoneConfiguration: HeartRateZoneConfiguration
    ) -> StrengthPeriodInsight {
        var workoutsBySource: [String: WorkoutActivity] = [:]
        for workout in summaries.flatMap(\.workouts) where workout.type == .strengthTraining {
            workoutsBySource[workout.sourceIdentifier] = workout
        }

        let strengthWorkouts = workoutsBySource.values.sorted { $0.startDate < $1.startDate }
        let zoneSummaries = heartRateZoneConfiguration.zoneSummaries(for: strengthWorkouts)
        guard !strengthWorkouts.isEmpty else {
            return StrengthPeriodInsight(zoneSummaries: zoneSummaries)
        }

        let heartRateSamples = strengthWorkouts.flatMap(\.heartRateSamples)
        let averageHeartRate = heartRateSamples.isEmpty
            ? nil
            : heartRateSamples.reduce(0) { $0 + $1.beatsPerMinute } / Double(heartRateSamples.count)
        let maxHeartRate = heartRateSamples.map(\.beatsPerMinute).max()

        let bestWorkout = strengthWorkouts.max { lhs, rhs in
            let lhsEnergy = lhs.activeEnergyKilocalories ?? 0
            let rhsEnergy = rhs.activeEnergyKilocalories ?? 0
            if lhsEnergy != rhsEnergy {
                return lhsEnergy < rhsEnergy
            }
            if lhs.durationMinutes != rhs.durationMinutes {
                return lhs.durationMinutes < rhs.durationMinutes
            }
            return lhs.startDate < rhs.startDate
        }

        return StrengthPeriodInsight(
            totalMinutes: strengthWorkouts.reduce(0) { $0 + $1.durationMinutes },
            sessionCount: strengthWorkouts.count,
            totalActiveEnergyKilocalories: strengthWorkouts.reduce(0) { $0 + ($1.activeEnergyKilocalories ?? 0) },
            averageHeartRateBPM: averageHeartRate,
            maxHeartRateBPM: maxHeartRate,
            bestWorkout: bestWorkout,
            zoneSummaries: zoneSummaries
        )
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
                priority: 95,
                kind: .goal
            )
        }

        let walkingMinutes = Int(ceil(Double(remaining) / 110.0))
        return TodayCoachInsight(
            title: "\(remaining.formatted()) steps left",
            detail: "About \(walkingMinutes) min of easy walking gets you to \(today.goals.stepsPerDay.formatted()).",
            systemImage: "figure.walk",
            priority: 100,
            kind: .goal
        )
    }

    private func peakHourInsight(for today: DailyActivitySummary) -> TodayCoachInsight? {
        guard let peak = today.buckets.max(by: { $0.steps < $1.steps }), peak.steps > 0 else { return nil }
        let hour = calendar.component(.hour, from: peak.startDate)
        let label: String = switch hour {
        case 0: "12a"
        case 1..<12: "\(hour)a"
        case 12: "12p"
        default: "\(hour - 12)p"
        }
        return TodayCoachInsight(
            title: "Peak hour \(label)",
            detail: "\(peak.steps.formatted()) steps landed around \(label) today.",
            systemImage: "clock.fill",
            priority: 72,
            kind: .peakHour
        )
    }

    private func streakInsight(history: [DailyActivitySummary], goals: UserGoals) -> TodayCoachInsight? {
        let streak = currentStepGoalStreak(in: history, goal: goals.stepsPerDay)
        guard streak >= 2 else { return nil }
        return TodayCoachInsight(
            title: "\(streak)-day goal streak",
            detail: "You've hit your step goal \(streak) days in a row. Keep the momentum.",
            systemImage: "flame.fill",
            priority: 76,
            kind: .streak
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
                priority: 65,
                kind: .pace
            )
        }

        if delta < 0 {
            return TodayCoachInsight(
                title: "Behind usual \(weekdayName(for: todayStart))",
                detail: "\(abs(delta).formatted()) steps under your recent \(weekdayName(for: todayStart)) average of \(average.formatted()).",
                systemImage: "clock.arrow.circlepath",
                priority: 90,
                kind: .pace
            )
        }

        return TodayCoachInsight(
            title: "Ahead of usual \(weekdayName(for: todayStart))",
            detail: "\(delta.formatted()) steps above your recent \(weekdayName(for: todayStart)) average.",
            systemImage: "chart.line.uptrend.xyaxis",
            priority: 85,
            kind: .pace
        )
    }

    private func workoutContextInsight(for today: DailyActivitySummary) -> TodayCoachInsight? {
        guard !today.workouts.isEmpty || today.workoutMinutes > 0 else { return nil }
        if today.workouts.contains(where: { $0.type == .stairClimbing }) {
            let stairMinutes = today.workouts
                .filter { $0.type == .stairClimbing }
                .reduce(0) { $0 + $1.durationMinutes }
            return TodayCoachInsight(
                title: "Stair session day",
                detail: "\(ActivityFormatting.formattedMinutes(stairMinutes)) on stairs logged. Compare burn and HR against your recent stair sessions.",
                systemImage: "arrow.up",
                priority: 84,
                kind: .workout
            )
        }
        if today.workouts.contains(where: { $0.type == .strengthTraining }) {
            return TodayCoachInsight(
                title: "Strength day context",
                detail: "\(ActivityFormatting.formattedMinutes(today.workoutMinutes)) logged. Steps can be lighter, but a short walk helps recovery.",
                systemImage: "dumbbell",
                priority: 82,
                kind: .workout
            )
        }

        if let topWorkout = today.workouts.first {
            return TodayCoachInsight(
                title: "\(topWorkout.displayTitle) logged",
                detail: "\(ActivityFormatting.formattedMinutes(today.workoutMinutes)) of workout time is already on the board today.",
                systemImage: "bolt.heart",
                priority: 80,
                kind: .workout
            )
        }

        return TodayCoachInsight(
            title: "Workout time logged",
            detail: "\(ActivityFormatting.formattedMinutes(today.workoutMinutes)) already counts toward your weekly training goal.",
            systemImage: "timer",
            priority: 78,
            kind: .workout
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
                priority: 75,
                kind: .household
            )
        }

        if let gap = receipt.gapToNextRank, gap > 0 {
            return TodayCoachInsight(
                title: "Household chase",
                detail: "\(formattedCompetitionScore(gap, metric: receipt.metric)) separates you from the next rank.",
                systemImage: "person.2.fill",
                priority: 75,
                kind: .household
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
                priority: 70,
                kind: .projection
            )
        }

        return TodayCoachInsight(
            title: "Projected short",
            detail: "Current pace points to about \(projected.formatted()) steps, below today's goal.",
            systemImage: "target",
            priority: 88,
            kind: .projection
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

    private func gatedMetric<T: BinaryInteger>(
        title: String,
        currentValue: T,
        priorValue: T,
        format: (T) -> String,
        delta: String,
        improvement: Bool?
    ) -> PeriodComparisonMetric? {
        guard priorValue > 0 else { return nil }
        return PeriodComparisonMetric(
            title: title,
            currentValue: format(currentValue),
            priorValue: format(priorValue),
            deltaText: delta,
            isImprovement: improvement
        )
    }

    private func gatedMetric(
        title: String,
        currentValue: Double,
        priorValue: Double,
        format: (Double) -> String,
        delta: String,
        improvement: Bool?
    ) -> PeriodComparisonMetric? {
        guard priorValue > 0 else { return nil }
        return PeriodComparisonMetric(
            title: title,
            currentValue: format(currentValue),
            priorValue: format(priorValue),
            deltaText: delta,
            isImprovement: improvement
        )
    }

    private func signedInteger(_ value: Int) -> String {
        if value == 0 { return "Even" }
        return value > 0 ? "+\(value)" : "\(value)"
    }

    private func signedMinutes(_ value: Double) -> String {
        let rounded = Int(value.rounded())
        if rounded == 0 { return "Even" }
        return rounded > 0 ? "+\(rounded)m" : "\(rounded)m"
    }

    private func signedCalories(_ value: Double) -> String {
        let rounded = Int(value.rounded())
        if rounded == 0 { return "Even" }
        return rounded > 0 ? "+\(rounded)" : "\(rounded)"
    }

    private func signedDistance(_ meters: Double) -> String {
        let rounded = Int(meters.rounded())
        if rounded == 0 { return "Even" }
        return rounded > 0 ? "+\(rounded)m" : "\(rounded)m"
    }
}

public struct WorkoutComparisonService: Sendable {
    private let calendar: Calendar

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    public func peerWorkouts(
        for workout: WorkoutActivity,
        in workouts: [WorkoutActivity],
        tagProvider: (WorkoutActivity) -> String? = { _ in nil },
        lookbackDays: Int = 90
    ) -> [WorkoutActivity] {
        let windowStart = calendar.date(byAdding: .day, value: -lookbackDays, to: workout.startDate) ?? workout.startDate
        return workouts
            .filter { candidate in
                candidate.type == workout.type
                    && candidate.startDate >= windowStart
                    && candidate.startDate <= workout.startDate
                    && matchesTag(candidate, workout: workout, tagProvider: tagProvider)
            }
            .sorted { $0.startDate > $1.startDate }
    }

    public func lastSession(before workout: WorkoutActivity, in peers: [WorkoutActivity]) -> WorkoutActivity? {
        peers.first { $0.sourceIdentifier != workout.sourceIdentifier && $0.startDate < workout.startDate }
    }

    public func bestSession(in peers: [WorkoutActivity], excluding workout: WorkoutActivity) -> WorkoutActivity? {
        peers
            .filter { $0.sourceIdentifier != workout.sourceIdentifier }
            .max { lhs, rhs in
                let lhsEnergy = lhs.activeEnergyKilocalories ?? 0
                let rhsEnergy = rhs.activeEnergyKilocalories ?? 0
                if lhsEnergy != rhsEnergy { return lhsEnergy < rhsEnergy }
                if lhs.durationMinutes != rhs.durationMinutes { return lhs.durationMinutes < rhs.durationMinutes }
                return lhs.startDate < rhs.startDate
            }
    }

    public func compare(current: WorkoutActivity, baseline: WorkoutActivity) -> WorkoutSessionComparison {
        var deltas: [WorkoutComparisonDelta] = []

        deltas.append(WorkoutComparisonDelta(
            label: "Duration",
            currentValue: ActivityFormatting.formattedMinutes(current.durationMinutes),
            baselineValue: ActivityFormatting.formattedMinutes(baseline.durationMinutes),
            deltaText: signedMinutes(current.durationMinutes - baseline.durationMinutes)
        ))

        let currentBurn = current.activeEnergyKilocalories ?? 0
        let baselineBurn = baseline.activeEnergyKilocalories ?? 0
        deltas.append(WorkoutComparisonDelta(
            label: "Active burn",
            currentValue: ActivityFormatting.formattedCalories(currentBurn),
            baselineValue: ActivityFormatting.formattedCalories(baselineBurn),
            deltaText: signedCalories(currentBurn - baselineBurn)
        ))

        if current.durationMinutes > 0, baseline.durationMinutes > 0 {
            let currentRate = currentBurn / current.durationMinutes
            let baselineRate = baselineBurn / baseline.durationMinutes
            deltas.append(WorkoutComparisonDelta(
                label: "Burn rate",
                currentValue: String(format: "%.1f/min", currentRate),
                baselineValue: String(format: "%.1f/min", baselineRate),
                deltaText: signedCalories(currentRate - baselineRate) + "/min"
            ))
        }

        if let currentHR = current.averageHeartRateBPM, let baselineHR = baseline.averageHeartRateBPM {
            deltas.append(WorkoutComparisonDelta(
                label: "Avg HR",
                currentValue: "\(Int(currentHR.rounded())) bpm",
                baselineValue: "\(Int(baselineHR.rounded())) bpm",
                deltaText: signedInteger(Int(currentHR.rounded()) - Int(baselineHR.rounded())) + " bpm"
            ))
        }

        if let currentMaxHR = current.maxHeartRateBPM, let baselineMaxHR = baseline.maxHeartRateBPM {
            deltas.append(WorkoutComparisonDelta(
                label: "Max HR",
                currentValue: "\(Int(currentMaxHR.rounded())) bpm",
                baselineValue: "\(Int(baselineMaxHR.rounded())) bpm",
                deltaText: signedInteger(Int(currentMaxHR.rounded()) - Int(baselineMaxHR.rounded())) + " bpm"
            ))
        }

        if let currentDistance = current.distanceMeters, let baselineDistance = baseline.distanceMeters,
           currentDistance > 0 || baselineDistance > 0 {
            deltas.append(WorkoutComparisonDelta(
                label: "Distance",
                currentValue: formatDistanceMeters(currentDistance),
                baselineValue: formatDistanceMeters(baselineDistance),
                deltaText: signedDistance(currentDistance - baselineDistance)
            ))
        }

        return WorkoutSessionComparison(current: current, baseline: baseline, deltas: deltas)
    }

    private func matchesTag(
        _ candidate: WorkoutActivity,
        workout: WorkoutActivity,
        tagProvider: (WorkoutActivity) -> String?
    ) -> Bool {
        guard workout.type == .strengthTraining || workout.type == .stairClimbing else { return true }
        let workoutTag = tagProvider(workout)?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let workoutTag, !workoutTag.isEmpty else { return true }
        let candidateTag = tagProvider(candidate)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return candidateTag?.caseInsensitiveCompare(workoutTag) == .orderedSame
    }

    private func signedMinutes(_ value: Double) -> String {
        let rounded = Int(value.rounded())
        if rounded == 0 { return "Even" }
        return rounded > 0 ? "+\(rounded)m" : "\(rounded)m"
    }

    private func signedCalories(_ value: Double) -> String {
        let rounded = Int(value.rounded())
        if rounded == 0 { return "Even" }
        return rounded > 0 ? "+\(rounded)" : "\(rounded)"
    }

    private func signedInteger(_ value: Int) -> String {
        if value == 0 { return "Even" }
        return value > 0 ? "+\(value)" : "\(value)"
    }

    private func signedDistance(_ meters: Double) -> String {
        let rounded = Int(meters.rounded())
        if rounded == 0 { return "Even" }
        return rounded > 0 ? "+\(rounded)m" : "\(rounded)m"
    }

    private func formatDistanceMeters(_ meters: Double) -> String {
        if meters >= 1_000 {
            return String(format: "%.2f km", meters / 1_000)
        }
        return "\(Int(meters.rounded())) m"
    }
}
