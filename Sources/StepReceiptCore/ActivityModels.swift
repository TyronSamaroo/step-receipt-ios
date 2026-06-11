import Foundation

public enum ActivityKind: String, Codable, CaseIterable, Equatable, Identifiable, Sendable {
    case walking
    case running
    case cycling
    case strengthTraining
    case hiking
    case swimming
    case elliptical
    case stairClimbing
    case rowing
    case yoga
    case other

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .walking: "Walking"
        case .running: "Running"
        case .cycling: "Cycling"
        case .strengthTraining: "Strength"
        case .hiking: "Hiking"
        case .swimming: "Swimming"
        case .elliptical: "Elliptical"
        case .stairClimbing: "Stairs"
        case .rowing: "Rowing"
        case .yoga: "Yoga"
        case .other: "Other"
        }
    }
}

public struct HealthMetricBucket: Codable, Equatable, Identifiable, Sendable {
    public var id: String {
        "\(Int(startDate.timeIntervalSince1970))-\(Int(endDate.timeIntervalSince1970))"
    }

    public let startDate: Date
    public let endDate: Date
    public let steps: Int
    public let distanceMeters: Double
    public let activeEnergyKilocalories: Double
    public let flightsClimbed: Int
    public let workoutMinutes: Double

    public init(
        startDate: Date,
        endDate: Date,
        steps: Int = 0,
        distanceMeters: Double = 0,
        activeEnergyKilocalories: Double = 0,
        flightsClimbed: Int = 0,
        workoutMinutes: Double = 0
    ) {
        self.startDate = startDate
        self.endDate = endDate
        self.steps = max(0, steps)
        self.distanceMeters = max(0, distanceMeters)
        self.activeEnergyKilocalories = max(0, activeEnergyKilocalories)
        self.flightsClimbed = max(0, flightsClimbed)
        self.workoutMinutes = max(0, workoutMinutes)
    }
}

public struct WorkoutHeartRateSample: Codable, Equatable, Identifiable, Sendable {
    public var id: String {
        "\(Int(timestamp.timeIntervalSince1970))-\(Int(beatsPerMinute.rounded()))"
    }

    public let timestamp: Date
    public let beatsPerMinute: Double

    public init(timestamp: Date, beatsPerMinute: Double) {
        self.timestamp = timestamp
        self.beatsPerMinute = max(0, beatsPerMinute)
    }
}

public struct WorkoutActivity: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let sourceIdentifier: String
    public let type: ActivityKind
    public let title: String
    public let startDate: Date
    public let endDate: Date
    public let durationMinutes: Double
    public let distanceMeters: Double?
    public let activeEnergyKilocalories: Double?
    public let totalEnergyKilocalories: Double?
    public let steps: Int?
    public let sourceName: String
    public let environment: WorkoutEnvironment?
    public let weatherTemperatureCelsius: Double?
    public let weatherHumidityPercent: Double?
    public let heartRateSamples: [WorkoutHeartRateSample]

    public init(
        id: UUID = UUID(),
        sourceIdentifier: String,
        type: ActivityKind,
        title: String? = nil,
        startDate: Date,
        endDate: Date,
        durationMinutes: Double? = nil,
        distanceMeters: Double? = nil,
        activeEnergyKilocalories: Double? = nil,
        totalEnergyKilocalories: Double? = nil,
        steps: Int? = nil,
        sourceName: String = "Health",
        environment: WorkoutEnvironment? = nil,
        weatherTemperatureCelsius: Double? = nil,
        weatherHumidityPercent: Double? = nil,
        heartRateSamples: [WorkoutHeartRateSample] = []
    ) {
        self.id = id
        self.sourceIdentifier = sourceIdentifier
        self.type = type
        self.title = title ?? type.displayName
        self.startDate = startDate
        self.endDate = endDate
        self.durationMinutes = max(0, durationMinutes ?? endDate.timeIntervalSince(startDate) / 60)
        self.distanceMeters = distanceMeters.map { max(0, $0) }
        self.activeEnergyKilocalories = activeEnergyKilocalories.map { max(0, $0) }
        self.totalEnergyKilocalories = totalEnergyKilocalories.map { max(0, $0) }
        self.steps = steps.map { max(0, $0) }
        self.sourceName = sourceName
        self.environment = environment
        self.weatherTemperatureCelsius = weatherTemperatureCelsius
        self.weatherHumidityPercent = weatherHumidityPercent.map { max(0, $0) }
        self.heartRateSamples = heartRateSamples
            .filter { $0.beatsPerMinute > 0 }
            .sorted { $0.timestamp < $1.timestamp }
    }

    public var displayTitle: String {
        if title != type.displayName {
            return title
        }

        return switch (type, environment) {
        case (.walking, .indoor): "Indoor Walk"
        case (.walking, .outdoor): "Outdoor Walk"
        default: title
        }
    }

    public var averageHeartRateBPM: Double? {
        guard !heartRateSamples.isEmpty else { return nil }
        let total = heartRateSamples.reduce(0) { $0 + $1.beatsPerMinute }
        return total / Double(heartRateSamples.count)
    }

    public var maxHeartRateBPM: Double? {
        heartRateSamples.map(\.beatsPerMinute).max()
    }

    public func replacingDerivedHealthData(
        steps: Int? = nil,
        heartRateSamples: [WorkoutHeartRateSample]? = nil
    ) -> WorkoutActivity {
        WorkoutActivity(
            id: id,
            sourceIdentifier: sourceIdentifier,
            type: type,
            title: title,
            startDate: startDate,
            endDate: endDate,
            durationMinutes: durationMinutes,
            distanceMeters: distanceMeters,
            activeEnergyKilocalories: activeEnergyKilocalories,
            totalEnergyKilocalories: totalEnergyKilocalories,
            steps: steps ?? self.steps,
            sourceName: sourceName,
            environment: environment,
            weatherTemperatureCelsius: weatherTemperatureCelsius,
            weatherHumidityPercent: weatherHumidityPercent,
            heartRateSamples: heartRateSamples ?? self.heartRateSamples
        )
    }

    enum CodingKeys: String, CodingKey {
        case id
        case sourceIdentifier
        case type
        case title
        case startDate
        case endDate
        case durationMinutes
        case distanceMeters
        case activeEnergyKilocalories
        case totalEnergyKilocalories
        case steps
        case sourceName
        case environment
        case weatherTemperatureCelsius
        case weatherHumidityPercent
        case heartRateSamples
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            id: container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID(),
            sourceIdentifier: container.decode(String.self, forKey: .sourceIdentifier),
            type: container.decode(ActivityKind.self, forKey: .type),
            title: container.decodeIfPresent(String.self, forKey: .title),
            startDate: container.decode(Date.self, forKey: .startDate),
            endDate: container.decode(Date.self, forKey: .endDate),
            durationMinutes: container.decodeIfPresent(Double.self, forKey: .durationMinutes),
            distanceMeters: container.decodeIfPresent(Double.self, forKey: .distanceMeters),
            activeEnergyKilocalories: container.decodeIfPresent(Double.self, forKey: .activeEnergyKilocalories),
            totalEnergyKilocalories: container.decodeIfPresent(Double.self, forKey: .totalEnergyKilocalories),
            steps: container.decodeIfPresent(Int.self, forKey: .steps),
            sourceName: container.decodeIfPresent(String.self, forKey: .sourceName) ?? "Health",
            environment: container.decodeIfPresent(WorkoutEnvironment.self, forKey: .environment),
            weatherTemperatureCelsius: container.decodeIfPresent(Double.self, forKey: .weatherTemperatureCelsius),
            weatherHumidityPercent: container.decodeIfPresent(Double.self, forKey: .weatherHumidityPercent),
            heartRateSamples: container.decodeIfPresent([WorkoutHeartRateSample].self, forKey: .heartRateSamples) ?? []
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(sourceIdentifier, forKey: .sourceIdentifier)
        try container.encode(type, forKey: .type)
        try container.encode(title, forKey: .title)
        try container.encode(startDate, forKey: .startDate)
        try container.encode(endDate, forKey: .endDate)
        try container.encode(durationMinutes, forKey: .durationMinutes)
        try container.encodeIfPresent(distanceMeters, forKey: .distanceMeters)
        try container.encodeIfPresent(activeEnergyKilocalories, forKey: .activeEnergyKilocalories)
        try container.encodeIfPresent(totalEnergyKilocalories, forKey: .totalEnergyKilocalories)
        try container.encodeIfPresent(steps, forKey: .steps)
        try container.encode(sourceName, forKey: .sourceName)
        try container.encodeIfPresent(environment, forKey: .environment)
        try container.encodeIfPresent(weatherTemperatureCelsius, forKey: .weatherTemperatureCelsius)
        try container.encodeIfPresent(weatherHumidityPercent, forKey: .weatherHumidityPercent)
        try container.encode(heartRateSamples, forKey: .heartRateSamples)
    }
}

public enum WorkoutEnvironment: String, Codable, CaseIterable, Equatable, Identifiable, Sendable {
    case indoor
    case outdoor

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .indoor: "Indoor"
        case .outdoor: "Outdoor"
        }
    }
}

public struct UserGoals: Codable, Equatable, Sendable {
    public var stepsPerDay: Int
    public var workoutMinutesPerWeek: Int
    public var activeEnergyKilocaloriesPerDay: Int?

    public init(
        stepsPerDay: Int = 10_000,
        workoutMinutesPerWeek: Int = 150,
        activeEnergyKilocaloriesPerDay: Int? = nil
    ) {
        self.stepsPerDay = max(1, stepsPerDay)
        self.workoutMinutesPerWeek = max(0, workoutMinutesPerWeek)
        self.activeEnergyKilocaloriesPerDay = activeEnergyKilocaloriesPerDay.map { max(0, $0) }
    }
}

public enum DistanceUnit: String, Codable, CaseIterable, Equatable, Identifiable, Sendable {
    case miles
    case kilometers

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .miles: "Miles"
        case .kilometers: "Kilometers"
        }
    }
}

public enum AppTheme: String, Codable, CaseIterable, Equatable, Identifiable, Sendable {
    case system
    case light
    case dark

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
}

public enum DashboardMetric: String, Codable, CaseIterable, Equatable, Identifiable, Sendable {
    case distance
    case activeEnergy
    case flights
    case workoutMinutes

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .distance: "Distance"
        case .activeEnergy: "Active Burn"
        case .flights: "Flights"
        case .workoutMinutes: "Workout"
        }
    }
}

public enum DailySummaryFilter: String, Codable, CaseIterable, Equatable, Identifiable, Sendable {
    case all
    case activeDays
    case goalHit
    case goalMissed
    case workoutDays
    case lightDays

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .all: "All"
        case .activeDays: "Active"
        case .goalHit: "Goal Hit"
        case .goalMissed: "Goal Missed"
        case .workoutDays: "Workouts"
        case .lightDays: "Light"
        }
    }
}

public enum DailySummarySort: String, Codable, CaseIterable, Equatable, Identifiable, Sendable {
    case newest
    case steps
    case distance
    case activeEnergy
    case workoutMinutes

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .newest: "Newest"
        case .steps: "Steps"
        case .distance: "Distance"
        case .activeEnergy: "Burn"
        case .workoutMinutes: "Workout"
        }
    }
}

public struct UserPreferences: Codable, Equatable, Sendable {
    public var displayName: String
    public var distanceUnit: DistanceUnit
    public var visibleDashboardMetrics: [DashboardMetric]
    public var appTheme: AppTheme

    public init(
        displayName: String = "You",
        distanceUnit: DistanceUnit = .miles,
        visibleDashboardMetrics: [DashboardMetric] = DashboardMetric.allCases,
        appTheme: AppTheme = .system
    ) {
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.displayName = trimmedName.isEmpty ? "You" : trimmedName
        self.distanceUnit = distanceUnit
        self.visibleDashboardMetrics = visibleDashboardMetrics.isEmpty ? DashboardMetric.allCases : visibleDashboardMetrics
        self.appTheme = appTheme
    }

    public func shows(_ metric: DashboardMetric) -> Bool {
        visibleDashboardMetrics.contains(metric)
    }

    enum CodingKeys: String, CodingKey {
        case displayName
        case distanceUnit
        case visibleDashboardMetrics
        case appTheme
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            displayName: try container.decodeIfPresent(String.self, forKey: .displayName) ?? "You",
            distanceUnit: try container.decodeIfPresent(DistanceUnit.self, forKey: .distanceUnit) ?? .miles,
            visibleDashboardMetrics: try container.decodeIfPresent([DashboardMetric].self, forKey: .visibleDashboardMetrics) ?? DashboardMetric.allCases,
            appTheme: try container.decodeIfPresent(AppTheme.self, forKey: .appTheme) ?? .system
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(displayName, forKey: .displayName)
        try container.encode(distanceUnit, forKey: .distanceUnit)
        try container.encode(visibleDashboardMetrics, forKey: .visibleDashboardMetrics)
        try container.encode(appTheme, forKey: .appTheme)
    }
}

public struct DailyActivitySummary: Codable, Equatable, Identifiable, Sendable {
    public var id: String { "\(Int(dateStart.timeIntervalSince1970))" }

    public let dateStart: Date
    public let steps: Int
    public let distanceMeters: Double
    public let activeEnergyKilocalories: Double
    public let flightsClimbed: Int
    public let workoutMinutes: Double
    public let buckets: [HealthMetricBucket]
    public let workouts: [WorkoutActivity]
    public let goals: UserGoals

    public init(
        dateStart: Date,
        steps: Int,
        distanceMeters: Double,
        activeEnergyKilocalories: Double,
        flightsClimbed: Int,
        workoutMinutes: Double,
        buckets: [HealthMetricBucket],
        workouts: [WorkoutActivity],
        goals: UserGoals
    ) {
        self.dateStart = dateStart
        self.steps = max(0, steps)
        self.distanceMeters = max(0, distanceMeters)
        self.activeEnergyKilocalories = max(0, activeEnergyKilocalories)
        self.flightsClimbed = max(0, flightsClimbed)
        self.workoutMinutes = max(0, workoutMinutes)
        self.buckets = buckets.sorted { $0.startDate < $1.startDate }
        self.workouts = workouts.sorted { $0.startDate > $1.startDate }
        self.goals = goals
    }

    public var stepGoalProgress: Double {
        min(1, Double(steps) / Double(max(1, goals.stepsPerDay)))
    }

    public var activeEnergyGoalProgress: Double? {
        guard let goal = goals.activeEnergyKilocaloriesPerDay, goal > 0 else { return nil }
        return min(1, activeEnergyKilocalories / Double(goal))
    }

    public var hasActivityData: Bool {
        steps > 0 || distanceMeters > 0 || activeEnergyKilocalories > 0 || flightsClimbed > 0 || workoutMinutes > 0
    }
}

public struct DailyHighlight: Codable, Equatable, Sendable {
    public let date: Date
    public let steps: Int
    public let distanceMeters: Double
    public let activeEnergyKilocalories: Double

    public init(date: Date, steps: Int, distanceMeters: Double, activeEnergyKilocalories: Double) {
        self.date = date
        self.steps = steps
        self.distanceMeters = distanceMeters
        self.activeEnergyKilocalories = activeEnergyKilocalories
    }
}

public struct MonthHighlight: Codable, Equatable, Sendable {
    public let monthStart: Date
    public let steps: Int
    public let activeDays: Int

    public init(monthStart: Date, steps: Int, activeDays: Int) {
        self.monthStart = monthStart
        self.steps = steps
        self.activeDays = activeDays
    }
}

public struct InsightReceipt: Codable, Equatable, Sendable {
    public let periodStart: Date
    public let periodEnd: Date
    public let generatedAt: Date
    public let totalSteps: Int
    public let totalDistanceMeters: Double
    public let totalActiveEnergyKilocalories: Double
    public let totalFlightsClimbed: Int
    public let totalWorkoutMinutes: Double
    public let dailyAverageSteps: Int
    public let bestDay: DailyHighlight?
    public let bestMonth: MonthHighlight?
    public let currentStepGoalStreakDays: Int
    public let projectedStepsToday: Int?
    public let stepGoalCompletionRate: Double
    public let onTrackMessage: String

    public init(
        periodStart: Date,
        periodEnd: Date,
        generatedAt: Date,
        totalSteps: Int,
        totalDistanceMeters: Double,
        totalActiveEnergyKilocalories: Double,
        totalFlightsClimbed: Int,
        totalWorkoutMinutes: Double,
        dailyAverageSteps: Int,
        bestDay: DailyHighlight?,
        bestMonth: MonthHighlight?,
        currentStepGoalStreakDays: Int,
        projectedStepsToday: Int?,
        stepGoalCompletionRate: Double,
        onTrackMessage: String
    ) {
        self.periodStart = periodStart
        self.periodEnd = periodEnd
        self.generatedAt = generatedAt
        self.totalSteps = max(0, totalSteps)
        self.totalDistanceMeters = max(0, totalDistanceMeters)
        self.totalActiveEnergyKilocalories = max(0, totalActiveEnergyKilocalories)
        self.totalFlightsClimbed = max(0, totalFlightsClimbed)
        self.totalWorkoutMinutes = max(0, totalWorkoutMinutes)
        self.dailyAverageSteps = max(0, dailyAverageSteps)
        self.bestDay = bestDay
        self.bestMonth = bestMonth
        self.currentStepGoalStreakDays = max(0, currentStepGoalStreakDays)
        self.projectedStepsToday = projectedStepsToday.map { max(0, $0) }
        self.stepGoalCompletionRate = max(0, min(1, stepGoalCompletionRate))
        self.onTrackMessage = onTrackMessage
    }
}

public struct SyncedSummaryRecord: Codable, Equatable, Identifiable, Sendable {
    public var id: String { dayKey }

    public let dayKey: String
    public let dateStart: Date
    public let steps: Int
    public let distanceMeters: Double
    public let activeEnergyKilocalories: Double
    public let flightsClimbed: Int
    public let workoutMinutes: Double
    public let workoutCount: Int
    public let stepGoal: Int
    public let updatedAt: Date

    public init(
        dayKey: String,
        dateStart: Date,
        steps: Int,
        distanceMeters: Double,
        activeEnergyKilocalories: Double,
        flightsClimbed: Int,
        workoutMinutes: Double,
        workoutCount: Int,
        stepGoal: Int,
        updatedAt: Date = Date()
    ) {
        self.dayKey = dayKey
        self.dateStart = dateStart
        self.steps = max(0, steps)
        self.distanceMeters = max(0, distanceMeters)
        self.activeEnergyKilocalories = max(0, activeEnergyKilocalories)
        self.flightsClimbed = max(0, flightsClimbed)
        self.workoutMinutes = max(0, workoutMinutes)
        self.workoutCount = max(0, workoutCount)
        self.stepGoal = max(1, stepGoal)
        self.updatedAt = updatedAt
    }
}
