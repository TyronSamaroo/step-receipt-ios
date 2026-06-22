import Foundation

public struct StepPattern: Equatable, Sendable {
    public let scope: ActivityPeriodScope
    public let periodStart: Date
    public let periodEnd: Date
    public let hourlyMedianSteps: [Int]
    public let peakHour: Int
    public let peakHourMedianSteps: Int
    public let activeHours: [Int]
    public let quietHours: [Int]
    public let mostActiveWindowStart: Date?
    public let mostActiveWindowEnd: Date?

    public init(
        scope: ActivityPeriodScope,
        periodStart: Date,
        periodEnd: Date,
        hourlyMedianSteps: [Int],
        peakHour: Int,
        peakHourMedianSteps: Int,
        activeHours: [Int],
        quietHours: [Int],
        mostActiveWindowStart: Date?,
        mostActiveWindowEnd: Date?
    ) {
        self.scope = scope
        self.periodStart = periodStart
        self.periodEnd = periodEnd
        self.hourlyMedianSteps = hourlyMedianSteps
        self.peakHour = peakHour
        self.peakHourMedianSteps = peakHourMedianSteps
        self.activeHours = activeHours
        self.quietHours = quietHours
        self.mostActiveWindowStart = mostActiveWindowStart
        self.mostActiveWindowEnd = mostActiveWindowEnd
    }
}

public struct WeekPatternCoachInsight: Equatable, Sendable, Identifiable {
    public let id: String
    public let title: String
    public let detail: String
    public let systemImage: String

    public init(id: String, title: String, detail: String, systemImage: String) {
        self.id = id
        self.title = title
        self.detail = detail
        self.systemImage = systemImage
    }
}

public enum ActivityPatternAnalysis {
    public static func mostActiveWindow(in buckets: [HealthMetricBucket]) -> (start: Date, end: Date)? {
        let sortedBuckets = buckets.sorted { $0.startDate < $1.startDate }
        guard !sortedBuckets.isEmpty else { return nil }

        var best: (start: Date, end: Date, steps: Int)?
        var currentStart: Date?
        var currentEnd: Date?
        var currentSteps = 0

        func closeCurrentRange() {
            guard let start = currentStart, let end = currentEnd, currentSteps > 0 else { return }
            if best == nil || currentSteps > (best?.steps ?? 0) {
                best = (start, end, currentSteps)
            }
        }

        for bucket in sortedBuckets {
            if bucket.steps > 0 {
                if currentStart == nil {
                    currentStart = bucket.startDate
                }
                currentEnd = bucket.endDate
                currentSteps += bucket.steps
            } else if currentStart != nil {
                closeCurrentRange()
                currentStart = nil
                currentEnd = nil
                currentSteps = 0
            }
        }

        if currentStart != nil {
            closeCurrentRange()
        }

        guard let best else { return nil }
        return (best.start, best.end)
    }
}

public enum WeekPatternBuilder {
    public static func build(
        from hourlyBuckets: [HealthMetricBucket],
        scope: ActivityPeriodScope,
        periodStart: Date,
        periodEnd: Date,
        calendar: Calendar = .current
    ) -> StepPattern {
        let hourlyMedianSteps = medianStepsByClockHour(from: hourlyBuckets, calendar: calendar)
        let peakHour = hourlyMedianSteps.enumerated().max(by: { $0.element < $1.element })?.offset ?? 0
        let peakHourMedianSteps = hourlyMedianSteps[peakHour]
        let activeHours = hourlyMedianSteps.enumerated().compactMap { hour, steps in
            steps > 0 ? hour : nil
        }
        let quietHours = hourlyMedianSteps.enumerated().compactMap { hour, steps in
            steps == 0 ? hour : nil
        }

        let referenceDay = calendar.startOfDay(for: periodStart)
        let syntheticBuckets = syntheticHourlyBuckets(
            from: hourlyMedianSteps,
            referenceDay: referenceDay,
            calendar: calendar
        )
        let activeWindow = ActivityPatternAnalysis.mostActiveWindow(in: syntheticBuckets)

        return StepPattern(
            scope: scope,
            periodStart: periodStart,
            periodEnd: periodEnd,
            hourlyMedianSteps: hourlyMedianSteps,
            peakHour: peakHour,
            peakHourMedianSteps: peakHourMedianSteps,
            activeHours: activeHours,
            quietHours: quietHours,
            mostActiveWindowStart: activeWindow?.start,
            mostActiveWindowEnd: activeWindow?.end
        )
    }

    public static func medianStepsByClockHour(
        from buckets: [HealthMetricBucket],
        calendar: Calendar = .current
    ) -> [Int] {
        var stepsByHour: [[Int]] = Array(repeating: [], count: 24)
        for bucket in buckets {
            let hour = calendar.component(.hour, from: bucket.startDate)
            guard hour >= 0, hour < 24 else { continue }
            stepsByHour[hour].append(bucket.steps)
        }

        return stepsByHour.map { values in
            guard !values.isEmpty else { return 0 }
            let sorted = values.sorted()
            let mid = sorted.count / 2
            if sorted.count.isMultiple(of: 2) {
                return (sorted[mid - 1] + sorted[mid]) / 2
            }
            return sorted[mid]
        }
    }

    private static func syntheticHourlyBuckets(
        from medianSteps: [Int],
        referenceDay: Date,
        calendar: Calendar
    ) -> [HealthMetricBucket] {
        (0..<24).compactMap { hour in
            guard let start = calendar.date(byAdding: .hour, value: hour, to: referenceDay) else { return nil }
            let steps = medianSteps[hour]
            return HealthMetricBucket(
                startDate: start,
                endDate: start.addingTimeInterval(3_600),
                steps: steps,
                distanceMeters: Double(steps) * 0.74,
                activeEnergyKilocalories: Double(steps) * 0.038
            )
        }
    }
}
