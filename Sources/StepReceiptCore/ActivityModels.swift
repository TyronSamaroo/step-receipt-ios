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

    public var isCardioMovement: Bool {
        switch self {
        case .walking, .running, .cycling, .hiking, .swimming, .elliptical, .stairClimbing, .rowing:
            true
        case .strengthTraining, .yoga, .other:
            false
        }
    }

    public var isMovementCardio: Bool {
        isCardioMovement && self != .stairClimbing
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

public struct WorkoutRoutePoint: Codable, Equatable, Identifiable, Sendable {
    public var id: String {
        "\(Int(timestamp.timeIntervalSince1970))-\(latitude)-\(longitude)"
    }

    public let latitude: Double
    public let longitude: Double
    public let altitudeMeters: Double?
    public let timestamp: Date

    public init?(
        latitude: Double,
        longitude: Double,
        altitudeMeters: Double? = nil,
        timestamp: Date
    ) {
        guard latitude.isFinite,
              longitude.isFinite,
              (-90...90).contains(latitude),
              (-180...180).contains(longitude)
        else {
            return nil
        }

        self.latitude = latitude
        self.longitude = longitude
        self.altitudeMeters = altitudeMeters?.isFinite == true ? altitudeMeters : nil
        self.timestamp = timestamp
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
    public let routePoints: [WorkoutRoutePoint]

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
        heartRateSamples: [WorkoutHeartRateSample] = [],
        routePoints: [WorkoutRoutePoint] = []
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
        self.routePoints = routePoints
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

    public var minHeartRateBPM: Double? {
        heartRateSamples.map(\.beatsPerMinute).min()
    }

    public var heartRateRangeBPM: Double? {
        guard let minHeartRateBPM, let maxHeartRateBPM else { return nil }
        return max(0, maxHeartRateBPM - minHeartRateBPM)
    }

    public var isMovementCardio: Bool {
        type.isMovementCardio
    }

    public func dominantHeartRateZone(using configuration: HeartRateZoneConfiguration) -> HeartRateZoneSummary? {
        let zones = configuration.zoneSummaries(for: self)
        guard let dominant = zones.max(by: { $0.durationSeconds < $1.durationSeconds }),
              dominant.durationSeconds > 0
        else {
            return nil
        }
        return dominant
    }

    public var hasRoute: Bool {
        routePoints.count >= 2
    }

    public func replacingDerivedHealthData(
        steps: Int? = nil,
        heartRateSamples: [WorkoutHeartRateSample]? = nil,
        routePoints: [WorkoutRoutePoint]? = nil
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
            heartRateSamples: heartRateSamples ?? self.heartRateSamples,
            routePoints: routePoints ?? self.routePoints
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
        case routePoints
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
            heartRateSamples: container.decodeIfPresent([WorkoutHeartRateSample].self, forKey: .heartRateSamples) ?? [],
            routePoints: container.decodeIfPresent([WorkoutRoutePoint].self, forKey: .routePoints) ?? []
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
        try container.encode(routePoints, forKey: .routePoints)
    }
}

public struct HeartRateZoneConfiguration: Codable, Equatable, Sendable {
    public static let `default` = HeartRateZoneConfiguration(validatedLowerBoundsBPM: [115, 134, 153, 172])

    public let zone2LowerBoundBPM: Int
    public let zone3LowerBoundBPM: Int
    public let zone4LowerBoundBPM: Int
    public let zone5LowerBoundBPM: Int

    public init(
        zone2LowerBoundBPM: Int = 115,
        zone3LowerBoundBPM: Int = 134,
        zone4LowerBoundBPM: Int = 153,
        zone5LowerBoundBPM: Int = 172
    ) {
        let lowerBounds = [
            zone2LowerBoundBPM,
            zone3LowerBoundBPM,
            zone4LowerBoundBPM,
            zone5LowerBoundBPM
        ]
        guard Self.isValid(lowerBoundsBPM: lowerBounds) else {
            self = Self.default
            return
        }
        self.init(validatedLowerBoundsBPM: lowerBounds)
    }

    public init(lowerBoundsBPM: [Int]) {
        guard Self.isValid(lowerBoundsBPM: lowerBoundsBPM) else {
            self = Self.default
            return
        }
        self.init(validatedLowerBoundsBPM: lowerBoundsBPM)
    }

    private init(validatedLowerBoundsBPM lowerBounds: [Int]) {
        self.zone2LowerBoundBPM = lowerBounds[0]
        self.zone3LowerBoundBPM = lowerBounds[1]
        self.zone4LowerBoundBPM = lowerBounds[2]
        self.zone5LowerBoundBPM = lowerBounds[3]
    }

    public var lowerBoundsBPM: [Int] {
        [
            zone2LowerBoundBPM,
            zone3LowerBoundBPM,
            zone4LowerBoundBPM,
            zone5LowerBoundBPM
        ]
    }

    public static func isValid(lowerBoundsBPM: [Int]) -> Bool {
        guard lowerBoundsBPM.count == 4 else { return false }
        guard lowerBoundsBPM.allSatisfy({ (30...240).contains($0) }) else { return false }
        return zip(lowerBoundsBPM, lowerBoundsBPM.dropFirst()).allSatisfy { lhs, rhs in
            lhs < rhs
        }
    }

    public func template(forLevel level: Int) -> HeartRateZoneSummary {
        switch level {
        case 1:
            HeartRateZoneSummary(level: 1, lowerBoundBPM: nil, upperBoundBPM: Double(zone2LowerBoundBPM))
        case 2:
            HeartRateZoneSummary(level: 2, lowerBoundBPM: Double(zone2LowerBoundBPM), upperBoundBPM: Double(zone3LowerBoundBPM))
        case 3:
            HeartRateZoneSummary(level: 3, lowerBoundBPM: Double(zone3LowerBoundBPM), upperBoundBPM: Double(zone4LowerBoundBPM))
        case 4:
            HeartRateZoneSummary(level: 4, lowerBoundBPM: Double(zone4LowerBoundBPM), upperBoundBPM: Double(zone5LowerBoundBPM))
        default:
            HeartRateZoneSummary(level: 5, lowerBoundBPM: Double(zone5LowerBoundBPM), upperBoundBPM: nil)
        }
    }

    public func template(for beatsPerMinute: Double) -> HeartRateZoneSummary {
        let zoneLevel: Int
        switch beatsPerMinute {
        case ..<Double(zone2LowerBoundBPM):
            zoneLevel = 1
        case ..<Double(zone3LowerBoundBPM):
            zoneLevel = 2
        case ..<Double(zone4LowerBoundBPM):
            zoneLevel = 3
        case ..<Double(zone5LowerBoundBPM):
            zoneLevel = 4
        default:
            zoneLevel = 5
        }
        return template(forLevel: zoneLevel)
    }

    public func zoneSummaries(for workout: WorkoutActivity) -> [HeartRateZoneSummary] {
        zoneSummaries(from: segments(for: workout))
    }

    public func zoneSummaries(for workouts: [WorkoutActivity]) -> [HeartRateZoneSummary] {
        zoneSummaries(from: workouts.flatMap { segments(for: $0) })
    }

    public func segments(for workout: WorkoutActivity) -> [HeartRateZoneSegment] {
        let samples = workout.heartRateSamples
        guard !samples.isEmpty else { return [] }

        let fallbackDuration = max(1, workout.durationMinutes * 60 / Double(samples.count))
        return samples.enumerated().map { index, sample in
            let nextDate = index + 1 < samples.count ? samples[index + 1].timestamp : workout.endDate
            var duration = nextDate.timeIntervalSince(sample.timestamp)
            if duration <= 0 || duration > fallbackDuration * 4 {
                duration = fallbackDuration
            }

            return HeartRateZoneSegment(
                zone: template(for: sample.beatsPerMinute),
                durationSeconds: max(1, duration)
            )
        }
    }

    private func zoneSummaries(from segments: [HeartRateZoneSegment]) -> [HeartRateZoneSummary] {
        let totals = segments.reduce(into: [Int: TimeInterval]()) { result, segment in
            result[segment.zone.level, default: 0] += segment.durationSeconds
        }

        return (1...5).map { level in
            let template = template(forLevel: level)
            return HeartRateZoneSummary(
                level: template.level,
                lowerBoundBPM: template.lowerBoundBPM,
                upperBoundBPM: template.upperBoundBPM,
                durationSeconds: totals[level] ?? 0
            )
        }
    }
}

public struct HeartRateZoneSummary: Codable, Equatable, Identifiable, Sendable {
    public var id: Int { level }

    public let level: Int
    public let title: String
    public let lowerBoundBPM: Double?
    public let upperBoundBPM: Double?
    public let durationSeconds: TimeInterval

    public init(
        level: Int,
        lowerBoundBPM: Double?,
        upperBoundBPM: Double?,
        durationSeconds: TimeInterval = 0
    ) {
        self.level = max(1, min(5, level))
        self.title = "Zone \(self.level)"
        self.lowerBoundBPM = lowerBoundBPM.map { max(0, $0) }
        self.upperBoundBPM = upperBoundBPM.map { max(0, $0) }
        self.durationSeconds = max(0, durationSeconds)
    }

    public var rangeLabel: String {
        switch (lowerBoundBPM, upperBoundBPM) {
        case (nil, let upper?):
            "< \(Int(upper.rounded())) bpm"
        case (let lower?, let upper?):
            "\(Int(lower.rounded()))-\(Int(upper.rounded())) bpm"
        case (let lower?, nil):
            ">= \(Int(lower.rounded())) bpm"
        default:
            "bpm"
        }
    }
}

public struct HeartRateZoneSegment: Codable, Equatable, Sendable {
    public let zone: HeartRateZoneSummary
    public let durationSeconds: TimeInterval

    public init(zone: HeartRateZoneSummary, durationSeconds: TimeInterval) {
        self.zone = zone
        self.durationSeconds = max(0, durationSeconds)
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

public enum CardioSessionScope: String, Codable, CaseIterable, Equatable, Identifiable, Sendable {
    case movement
    case includeStairs

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .movement: "Movement"
        case .includeStairs: "Include Stairs"
        }
    }

    public func matches(_ workout: WorkoutActivity) -> Bool {
        switch self {
        case .movement:
            workout.isMovementCardio
        case .includeStairs:
            workout.type.isCardioMovement
        }
    }
}

public enum InsightsTrendFilter: String, Codable, CaseIterable, Equatable, Identifiable, Sendable {
    case all
    case goalHit
    case goalMissed
    case workoutDays
    case lightDays
    case cardio
    case strength
    case stairs

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .all: "All"
        case .goalHit: "Goal Hit"
        case .goalMissed: "Goal Missed"
        case .workoutDays: "Workouts"
        case .lightDays: "Light"
        case .cardio: "Cardio"
        case .strength: "Strength"
        case .stairs: "Stairs"
        }
    }

    public func matches(_ summary: DailyActivitySummary) -> Bool {
        switch self {
        case .all:
            return true
        case .goalHit:
            return summary.steps >= summary.goals.stepsPerDay
        case .goalMissed:
            return summary.steps < summary.goals.stepsPerDay
        case .workoutDays:
            return !summary.workouts.isEmpty || summary.workoutMinutes > 0
        case .lightDays:
            return summary.hasActivityData && summary.steps < summary.goals.stepsPerDay && summary.workoutMinutes == 0
        case .cardio:
            return summary.workouts.contains { $0.type.isCardioMovement && $0.type != .stairClimbing }
        case .strength:
            return summary.workouts.contains { $0.type == .strengthTraining }
        case .stairs:
            return summary.workouts.contains { $0.type == .stairClimbing }
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

public enum ActivityPeriodScope: String, Codable, CaseIterable, Equatable, Identifiable, Sendable {
    case day
    case week
    case month

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .day: "Day"
        case .week: "Week"
        case .month: "Month"
        }
    }
}

public struct UserPreferences: Codable, Equatable, Sendable {
    public var displayName: String
    public var distanceUnit: DistanceUnit
    public var visibleDashboardMetrics: [DashboardMetric]
    public var appTheme: AppTheme
    public var dailyStepGoalLiveActivityEnabled: Bool
    public var heartRateZoneConfiguration: HeartRateZoneConfiguration

    public init(
        displayName: String = "You",
        distanceUnit: DistanceUnit = .miles,
        visibleDashboardMetrics: [DashboardMetric] = DashboardMetric.allCases,
        appTheme: AppTheme = .light,
        dailyStepGoalLiveActivityEnabled: Bool = false,
        heartRateZoneConfiguration: HeartRateZoneConfiguration = .default
    ) {
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.displayName = trimmedName.isEmpty ? "You" : trimmedName
        self.distanceUnit = distanceUnit
        self.visibleDashboardMetrics = visibleDashboardMetrics.isEmpty ? DashboardMetric.allCases : visibleDashboardMetrics
        self.appTheme = appTheme
        self.dailyStepGoalLiveActivityEnabled = dailyStepGoalLiveActivityEnabled
        self.heartRateZoneConfiguration = heartRateZoneConfiguration
    }

    public func shows(_ metric: DashboardMetric) -> Bool {
        visibleDashboardMetrics.contains(metric)
    }

    enum CodingKeys: String, CodingKey {
        case displayName
        case distanceUnit
        case visibleDashboardMetrics
        case appTheme
        case dailyStepGoalLiveActivityEnabled
        case heartRateZoneConfiguration
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            displayName: try container.decodeIfPresent(String.self, forKey: .displayName) ?? "You",
            distanceUnit: try container.decodeIfPresent(DistanceUnit.self, forKey: .distanceUnit) ?? .miles,
            visibleDashboardMetrics: try container.decodeIfPresent([DashboardMetric].self, forKey: .visibleDashboardMetrics) ?? DashboardMetric.allCases,
            appTheme: try container.decodeIfPresent(AppTheme.self, forKey: .appTheme) ?? .light,
            dailyStepGoalLiveActivityEnabled: try container.decodeIfPresent(Bool.self, forKey: .dailyStepGoalLiveActivityEnabled) ?? false,
            heartRateZoneConfiguration: try container.decodeIfPresent(HeartRateZoneConfiguration.self, forKey: .heartRateZoneConfiguration) ?? .default
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(displayName, forKey: .displayName)
        try container.encode(distanceUnit, forKey: .distanceUnit)
        try container.encode(visibleDashboardMetrics, forKey: .visibleDashboardMetrics)
        try container.encode(appTheme, forKey: .appTheme)
        try container.encode(dailyStepGoalLiveActivityEnabled, forKey: .dailyStepGoalLiveActivityEnabled)
        try container.encode(heartRateZoneConfiguration, forKey: .heartRateZoneConfiguration)
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

public struct CardioPeriodInsight: Codable, Equatable, Sendable {
    public static let empty = CardioPeriodInsight()

    public let totalMinutes: Double
    public let sessionCount: Int
    public let totalDistanceMeters: Double
    public let totalActiveEnergyKilocalories: Double
    public let averageHeartRateBPM: Double?
    public let minHeartRateBPM: Double?
    public let maxHeartRateBPM: Double?
    public let bestWorkout: WorkoutActivity?
    public let zoneSummaries: [HeartRateZoneSummary]

    public init(
        totalMinutes: Double = 0,
        sessionCount: Int = 0,
        totalDistanceMeters: Double = 0,
        totalActiveEnergyKilocalories: Double = 0,
        averageHeartRateBPM: Double? = nil,
        minHeartRateBPM: Double? = nil,
        maxHeartRateBPM: Double? = nil,
        bestWorkout: WorkoutActivity? = nil,
        zoneSummaries: [HeartRateZoneSummary] = HeartRateZoneConfiguration.default.zoneSummaries(for: [])
    ) {
        self.totalMinutes = max(0, totalMinutes)
        self.sessionCount = max(0, sessionCount)
        self.totalDistanceMeters = max(0, totalDistanceMeters)
        self.totalActiveEnergyKilocalories = max(0, totalActiveEnergyKilocalories)
        self.averageHeartRateBPM = averageHeartRateBPM.map { max(0, $0) }
        self.minHeartRateBPM = minHeartRateBPM.map { max(0, $0) }
        self.maxHeartRateBPM = maxHeartRateBPM.map { max(0, $0) }
        self.bestWorkout = bestWorkout
        self.zoneSummaries = zoneSummaries.sorted { $0.level < $1.level }
    }

    public var hasCardio: Bool {
        sessionCount > 0 || totalMinutes > 0
    }

    public var totalZoneSeconds: TimeInterval {
        zoneSummaries.reduce(0) { $0 + $1.durationSeconds }
    }

    enum CodingKeys: String, CodingKey {
        case totalMinutes
        case sessionCount
        case totalDistanceMeters
        case totalActiveEnergyKilocalories
        case averageHeartRateBPM
        case minHeartRateBPM
        case maxHeartRateBPM
        case bestWorkout
        case zoneSummaries
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            totalMinutes: try container.decodeIfPresent(Double.self, forKey: .totalMinutes) ?? 0,
            sessionCount: try container.decodeIfPresent(Int.self, forKey: .sessionCount) ?? 0,
            totalDistanceMeters: try container.decodeIfPresent(Double.self, forKey: .totalDistanceMeters) ?? 0,
            totalActiveEnergyKilocalories: try container.decodeIfPresent(Double.self, forKey: .totalActiveEnergyKilocalories) ?? 0,
            averageHeartRateBPM: try container.decodeIfPresent(Double.self, forKey: .averageHeartRateBPM),
            minHeartRateBPM: try container.decodeIfPresent(Double.self, forKey: .minHeartRateBPM),
            maxHeartRateBPM: try container.decodeIfPresent(Double.self, forKey: .maxHeartRateBPM),
            bestWorkout: try container.decodeIfPresent(WorkoutActivity.self, forKey: .bestWorkout),
            zoneSummaries: try container.decodeIfPresent([HeartRateZoneSummary].self, forKey: .zoneSummaries) ?? HeartRateZoneConfiguration.default.zoneSummaries(for: [])
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(totalMinutes, forKey: .totalMinutes)
        try container.encode(sessionCount, forKey: .sessionCount)
        try container.encode(totalDistanceMeters, forKey: .totalDistanceMeters)
        try container.encode(totalActiveEnergyKilocalories, forKey: .totalActiveEnergyKilocalories)
        try container.encodeIfPresent(averageHeartRateBPM, forKey: .averageHeartRateBPM)
        try container.encodeIfPresent(minHeartRateBPM, forKey: .minHeartRateBPM)
        try container.encodeIfPresent(maxHeartRateBPM, forKey: .maxHeartRateBPM)
        try container.encodeIfPresent(bestWorkout, forKey: .bestWorkout)
        try container.encode(zoneSummaries, forKey: .zoneSummaries)
    }
}

public struct StrengthPeriodInsight: Codable, Equatable, Sendable {
    public static let empty = StrengthPeriodInsight()

    public let totalMinutes: Double
    public let sessionCount: Int
    public let totalActiveEnergyKilocalories: Double
    public let averageHeartRateBPM: Double?
    public let maxHeartRateBPM: Double?
    public let bestWorkout: WorkoutActivity?
    public let zoneSummaries: [HeartRateZoneSummary]

    public init(
        totalMinutes: Double = 0,
        sessionCount: Int = 0,
        totalActiveEnergyKilocalories: Double = 0,
        averageHeartRateBPM: Double? = nil,
        maxHeartRateBPM: Double? = nil,
        bestWorkout: WorkoutActivity? = nil,
        zoneSummaries: [HeartRateZoneSummary] = HeartRateZoneConfiguration.default.zoneSummaries(for: [])
    ) {
        self.totalMinutes = max(0, totalMinutes)
        self.sessionCount = max(0, sessionCount)
        self.totalActiveEnergyKilocalories = max(0, totalActiveEnergyKilocalories)
        self.averageHeartRateBPM = averageHeartRateBPM.map { max(0, $0) }
        self.maxHeartRateBPM = maxHeartRateBPM.map { max(0, $0) }
        self.bestWorkout = bestWorkout
        self.zoneSummaries = zoneSummaries.sorted { $0.level < $1.level }
    }

    public var hasStrength: Bool {
        sessionCount > 0 || totalMinutes > 0
    }

    public var totalZoneSeconds: TimeInterval {
        zoneSummaries.reduce(0) { $0 + $1.durationSeconds }
    }
}

public struct PeriodComparisonMetric: Codable, Equatable, Sendable, Identifiable {
    public var id: String { title }

    public let title: String
    public let currentValue: String
    public let priorValue: String
    public let deltaText: String
    public let isImprovement: Bool?

    public init(
        title: String,
        currentValue: String,
        priorValue: String,
        deltaText: String,
        isImprovement: Bool?
    ) {
        self.title = title
        self.currentValue = currentValue
        self.priorValue = priorValue
        self.deltaText = deltaText
        self.isImprovement = isImprovement
    }
}

public struct PeriodComparisonInsight: Codable, Equatable, Sendable {
    public let metrics: [PeriodComparisonMetric]

    public init(metrics: [PeriodComparisonMetric]) {
        self.metrics = metrics
    }

    public var hasMetrics: Bool {
        !metrics.isEmpty
    }
}

public struct PeriodActivitySummary: Codable, Equatable, Sendable {
    public let scope: ActivityPeriodScope
    public let periodStart: Date
    public let periodEnd: Date
    public let summaries: [DailyActivitySummary]
    public let receipt: InsightReceipt
    public let activeDays: Int
    public let goalHitDays: Int
    public let workoutCount: Int
    public let bestDay: DailyActivitySummary?
    public let cardioInsight: CardioPeriodInsight
    public let strengthInsight: StrengthPeriodInsight
    public let headline: String

    public init(
        scope: ActivityPeriodScope,
        periodStart: Date,
        periodEnd: Date,
        summaries: [DailyActivitySummary],
        receipt: InsightReceipt,
        activeDays: Int,
        goalHitDays: Int,
        workoutCount: Int,
        bestDay: DailyActivitySummary?,
        cardioInsight: CardioPeriodInsight = .empty,
        strengthInsight: StrengthPeriodInsight = .empty,
        headline: String
    ) {
        self.scope = scope
        self.periodStart = periodStart
        self.periodEnd = periodEnd
        self.summaries = summaries.sorted { $0.dateStart < $1.dateStart }
        self.receipt = receipt
        self.activeDays = max(0, activeDays)
        self.goalHitDays = max(0, goalHitDays)
        self.workoutCount = max(0, workoutCount)
        self.bestDay = bestDay
        self.cardioInsight = cardioInsight
        self.strengthInsight = strengthInsight
        self.headline = headline
    }

    enum CodingKeys: String, CodingKey {
        case scope
        case periodStart
        case periodEnd
        case summaries
        case receipt
        case activeDays
        case goalHitDays
        case workoutCount
        case bestDay
        case cardioInsight
        case strengthInsight
        case headline
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            scope: try container.decode(ActivityPeriodScope.self, forKey: .scope),
            periodStart: try container.decode(Date.self, forKey: .periodStart),
            periodEnd: try container.decode(Date.self, forKey: .periodEnd),
            summaries: try container.decode([DailyActivitySummary].self, forKey: .summaries),
            receipt: try container.decode(InsightReceipt.self, forKey: .receipt),
            activeDays: try container.decode(Int.self, forKey: .activeDays),
            goalHitDays: try container.decode(Int.self, forKey: .goalHitDays),
            workoutCount: try container.decode(Int.self, forKey: .workoutCount),
            bestDay: try container.decodeIfPresent(DailyActivitySummary.self, forKey: .bestDay),
            cardioInsight: try container.decodeIfPresent(CardioPeriodInsight.self, forKey: .cardioInsight) ?? .empty,
            strengthInsight: try container.decodeIfPresent(StrengthPeriodInsight.self, forKey: .strengthInsight) ?? .empty,
            headline: try container.decode(String.self, forKey: .headline)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(scope, forKey: .scope)
        try container.encode(periodStart, forKey: .periodStart)
        try container.encode(periodEnd, forKey: .periodEnd)
        try container.encode(summaries, forKey: .summaries)
        try container.encode(receipt, forKey: .receipt)
        try container.encode(activeDays, forKey: .activeDays)
        try container.encode(goalHitDays, forKey: .goalHitDays)
        try container.encode(workoutCount, forKey: .workoutCount)
        try container.encodeIfPresent(bestDay, forKey: .bestDay)
        try container.encode(cardioInsight, forKey: .cardioInsight)
        try container.encode(strengthInsight, forKey: .strengthInsight)
        try container.encode(headline, forKey: .headline)
    }
}

public enum TodayCoachInsightKind: String, Codable, Sendable {
    case general
    case goal
    case pace
    case workout
    case household
    case projection
    case streak
    case peakHour
}

public struct TodayCoachInsight: Codable, Equatable, Identifiable, Sendable {
    public var id: String { "\(title)-\(detail)" }

    public let title: String
    public let detail: String
    public let systemImage: String
    public let priority: Int
    public let kind: TodayCoachInsightKind

    public init(
        title: String,
        detail: String,
        systemImage: String,
        priority: Int,
        kind: TodayCoachInsightKind = .general
    ) {
        self.title = title
        self.detail = detail
        self.systemImage = systemImage
        self.priority = priority
        self.kind = kind
    }

    enum CodingKeys: String, CodingKey {
        case title
        case detail
        case systemImage
        case priority
        case kind
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            title: try container.decode(String.self, forKey: .title),
            detail: try container.decode(String.self, forKey: .detail),
            systemImage: try container.decode(String.self, forKey: .systemImage),
            priority: try container.decode(Int.self, forKey: .priority),
            kind: try container.decodeIfPresent(TodayCoachInsightKind.self, forKey: .kind) ?? .general
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(title, forKey: .title)
        try container.encode(detail, forKey: .detail)
        try container.encode(systemImage, forKey: .systemImage)
        try container.encode(priority, forKey: .priority)
        try container.encode(kind, forKey: .kind)
    }
}

public struct WorkoutComparisonDelta: Codable, Equatable, Sendable {
    public let label: String
    public let currentValue: String
    public let baselineValue: String
    public let deltaText: String

    public init(label: String, currentValue: String, baselineValue: String, deltaText: String) {
        self.label = label
        self.currentValue = currentValue
        self.baselineValue = baselineValue
        self.deltaText = deltaText
    }
}

public struct WorkoutSessionComparison: Codable, Equatable, Sendable {
    public let current: WorkoutActivity
    public let baseline: WorkoutActivity
    public let deltas: [WorkoutComparisonDelta]

    public var canCompareRoutes: Bool {
        current.routePoints.count >= 2 && baseline.routePoints.count >= 2
    }

    public init(current: WorkoutActivity, baseline: WorkoutActivity, deltas: [WorkoutComparisonDelta]) {
        self.current = current
        self.baseline = baseline
        self.deltas = deltas
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
