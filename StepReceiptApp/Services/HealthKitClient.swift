import Foundation
import HealthKit

enum HealthAuthorizationState: Equatable, Sendable {
    case notDetermined
    case unavailable
    case authorized
    case deniedOrLimited
}

protocol HealthKitProviding: Sendable {
    var isAvailable: Bool { get }

    func requestAuthorization() async throws -> HealthAuthorizationState
    func fetchHourlyBuckets(for date: Date) async throws -> [HealthMetricBucket]
    func fetchDailyBuckets(daysBack: Int, endingAt endDate: Date) async throws -> [HealthMetricBucket]
    func fetchWorkouts(startDate: Date, endDate: Date) async throws -> [WorkoutActivity]
}

final class HealthKitClient: @unchecked Sendable {
    private let store = HKHealthStore()
    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func requestAuthorization() async throws -> HealthAuthorizationState {
        guard isAvailable else { return .unavailable }
        let readTypes = Set(readObjectTypes())
        try await store.requestAuthorization(toShare: [], read: readTypes)
        return .authorized
    }

    func fetchHourlyBuckets(for date: Date) async throws -> [HealthMetricBucket] {
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
        return try await fetchMetricBuckets(startDate: start, endDate: end, interval: DateComponents(hour: 1))
    }

    func fetchDailyBuckets(daysBack: Int, endingAt endDate: Date = Date()) async throws -> [HealthMetricBucket] {
        let clampedDaysBack = max(1, daysBack)
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: endDate)) ?? endDate
        let start = calendar.date(byAdding: .day, value: -clampedDaysBack, to: end) ?? end.addingTimeInterval(-86_400 * Double(clampedDaysBack))
        return try await fetchMetricBuckets(startDate: start, endDate: end, interval: DateComponents(day: 1))
    }

    func fetchWorkouts(startDate: Date, endDate: Date) async throws -> [WorkoutActivity] {
        guard isAvailable else { return [] }
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: [.strictStartDate])
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, samples, error in
                if error != nil {
                    continuation.resume(returning: [])
                    return
                }

                let workouts = (samples as? [HKWorkout] ?? []).map(Self.mapWorkout)
                continuation.resume(returning: workouts)
            }
            store.execute(query)
        }
    }

    private func fetchMetricBuckets(
        startDate: Date,
        endDate: Date,
        interval: DateComponents
    ) async throws -> [HealthMetricBucket] {
        async let steps = safelyQueryQuantityBuckets(
            identifier: .stepCount,
            unit: .count(),
            startDate: startDate,
            endDate: endDate,
            interval: interval
        )
        async let distance = safelyQueryQuantityBuckets(
            identifier: .distanceWalkingRunning,
            unit: .meter(),
            startDate: startDate,
            endDate: endDate,
            interval: interval
        )
        async let energy = safelyQueryQuantityBuckets(
            identifier: .activeEnergyBurned,
            unit: .kilocalorie(),
            startDate: startDate,
            endDate: endDate,
            interval: interval
        )
        async let flights = safelyQueryQuantityBuckets(
            identifier: .flightsClimbed,
            unit: .count(),
            startDate: startDate,
            endDate: endDate,
            interval: interval
        )

        let values = await (steps: steps, distance: distance, energy: energy, flights: flights)
        let starts = Set(values.steps.keys)
            .union(values.distance.keys)
            .union(values.energy.keys)
            .union(values.flights.keys)
            .sorted()

        return starts.map { start in
            let end = calendar.date(byAdding: interval, to: start) ?? start.addingTimeInterval(fallbackDuration(for: interval))
            return HealthMetricBucket(
                startDate: start,
                endDate: min(end, endDate),
                steps: Int((values.steps[start] ?? 0).rounded()),
                distanceMeters: values.distance[start] ?? 0,
                activeEnergyKilocalories: values.energy[start] ?? 0,
                flightsClimbed: Int((values.flights[start] ?? 0).rounded())
            )
        }
    }

    private func safelyQueryQuantityBuckets(
        identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        startDate: Date,
        endDate: Date,
        interval: DateComponents
    ) async -> [Date: Double] {
        do {
            return try await queryQuantityBuckets(
                identifier: identifier,
                unit: unit,
                startDate: startDate,
                endDate: endDate,
                interval: interval
            )
        } catch {
            return [:]
        }
    }

    private func queryQuantityBuckets(
        identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        startDate: Date,
        endDate: Date,
        interval: DateComponents
    ) async throws -> [Date: Double] {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: identifier), isAvailable else {
            return [:]
        }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: [.strictStartDate])
        let anchorDate = calendar.startOfDay(for: startDate)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: [.cumulativeSum],
                anchorDate: anchorDate,
                intervalComponents: interval
            )

            query.initialResultsHandler = { _, collection, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                var result: [Date: Double] = [:]
                collection?.enumerateStatistics(from: startDate, to: endDate) { statistics, _ in
                    result[statistics.startDate] = statistics.sumQuantity()?.doubleValue(for: unit) ?? 0
                }
                continuation.resume(returning: result)
            }

            store.execute(query)
        }
    }

    private func readObjectTypes() -> [HKObjectType] {
        var types: [HKObjectType] = [HKObjectType.workoutType()]
        for identifier in [
            HKQuantityTypeIdentifier.stepCount,
            .distanceWalkingRunning,
            .activeEnergyBurned,
            .flightsClimbed
        ] {
            if let type = HKQuantityType.quantityType(forIdentifier: identifier) {
                types.append(type)
            }
        }
        return types
    }

    private func fallbackDuration(for interval: DateComponents) -> TimeInterval {
        if let day = interval.day, day > 0 {
            return 86_400 * Double(day)
        }
        if let hour = interval.hour, hour > 0 {
            return 3_600 * Double(hour)
        }
        if let minute = interval.minute, minute > 0 {
            return 60 * Double(minute)
        }
        return 3_600
    }

    private static func mapWorkout(_ workout: HKWorkout) -> WorkoutActivity {
        let activeEnergyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)
        let activeEnergyKilocalories = activeEnergyType
            .flatMap { workout.statistics(for: $0)?.sumQuantity()?.doubleValue(for: .kilocalorie()) }
        let environment = mapWorkoutEnvironment(workout.metadata)
        let weatherTemperature = (workout.metadata?[HKMetadataKeyWeatherTemperature] as? HKQuantity)?
            .doubleValue(for: .degreeCelsius())
        let rawWeatherHumidity = (workout.metadata?[HKMetadataKeyWeatherHumidity] as? HKQuantity)?
            .doubleValue(for: .percent())
        let weatherHumidity = rawWeatherHumidity.map { $0 <= 1 ? $0 * 100 : $0 }

        return WorkoutActivity(
            id: workout.uuid,
            sourceIdentifier: workout.uuid.uuidString,
            type: mapActivityType(workout.workoutActivityType),
            title: displayTitle(for: workout.workoutActivityType, environment: environment),
            startDate: workout.startDate,
            endDate: workout.endDate,
            durationMinutes: workout.duration / 60,
            distanceMeters: workout.totalDistance?.doubleValue(for: .meter()),
            activeEnergyKilocalories: activeEnergyKilocalories,
            totalEnergyKilocalories: workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()),
            sourceName: workout.sourceRevision.source.name,
            environment: environment,
            weatherTemperatureCelsius: weatherTemperature,
            weatherHumidityPercent: weatherHumidity
        )
    }

    private static func mapActivityType(_ type: HKWorkoutActivityType) -> ActivityKind {
        switch type {
        case .walking: .walking
        case .running: .running
        case .cycling: .cycling
        case .traditionalStrengthTraining, .functionalStrengthTraining: .strengthTraining
        case .hiking: .hiking
        case .swimming: .swimming
        case .elliptical: .elliptical
        case .stairClimbing, .stairs, .stepTraining: .stairClimbing
        case .rowing: .rowing
        case .yoga: .yoga
        default: .other
        }
    }

    private static func mapWorkoutEnvironment(_ metadata: [String: Any]?) -> WorkoutEnvironment? {
        guard let isIndoor = metadata?[HKMetadataKeyIndoorWorkout] as? Bool else { return nil }
        return isIndoor ? .indoor : .outdoor
    }

    private static func displayTitle(for type: HKWorkoutActivityType, environment: WorkoutEnvironment?) -> String {
        switch type {
        case .walking:
            switch environment {
            case .indoor: "Indoor Walk"
            case .outdoor: "Outdoor Walk"
            case nil: "Walking"
            }
        case .traditionalStrengthTraining:
            "Traditional Strength Training"
        case .functionalStrengthTraining:
            "Functional Strength Training"
        case .stairClimbing:
            "Stair Climber"
        case .stairs:
            "Stairs"
        case .stepTraining:
            "Stair Stepper"
        default:
            mapActivityType(type).displayName
        }
    }
}

extension HealthKitClient: HealthKitProviding {}
