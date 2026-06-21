import Foundation

public enum WeatherDataSource: String, Codable, Equatable, Sendable {
    case weatherKit
    case healthKitWorkout
    case unavailable
}

public struct HourWeatherSnapshot: Equatable, Sendable, Identifiable {
    public var id: Date { date }

    public let date: Date
    public let temperatureCelsius: Double
    public let conditionSymbolName: String?
    public let conditionDescription: String?
    public let precipitationChancePercent: Double?

    public init(
        date: Date,
        temperatureCelsius: Double,
        conditionSymbolName: String? = nil,
        conditionDescription: String? = nil,
        precipitationChancePercent: Double? = nil
    ) {
        self.date = date
        self.temperatureCelsius = temperatureCelsius
        self.conditionSymbolName = conditionSymbolName
        self.conditionDescription = conditionDescription
        self.precipitationChancePercent = precipitationChancePercent
    }

    public var formattedTemperatureFahrenheit: String {
        "\(Int(DayWeatherSnapshot.celsiusToFahrenheit(temperatureCelsius).rounded()))°"
    }

    public var formattedPrecipitationChance: String? {
        guard let precipitationChancePercent else { return nil }
        return "\(Int(precipitationChancePercent.rounded()))%"
    }
}

public struct DayWeatherDetail: Equatable, Sendable {
    public let date: Date
    public let snapshot: DayWeatherSnapshot
    public let hourly: [HourWeatherSnapshot]

    public init(date: Date, snapshot: DayWeatherSnapshot, hourly: [HourWeatherSnapshot]) {
        self.date = date
        self.snapshot = snapshot
        self.hourly = hourly
    }
}

public struct DayWeatherSnapshot: Equatable, Sendable {
    public let temperatureCelsius: Double
    public let humidityPercent: Double
    public let apparentTemperatureCelsius: Double?
    public let conditionSymbolName: String?
    public let conditionDescription: String?
    public let windSpeedMetersPerSecond: Double?
    public let windDirectionDegrees: Double?
    public let uvIndex: Double?
    public let dewPointCelsius: Double?
    public let visibilityMeters: Double?
    public let precipitationChancePercent: Double?
    public let highTemperatureCelsius: Double?
    public let lowTemperatureCelsius: Double?
    public let cloudCoverPercent: Double?
    public let isDaylight: Bool?
    public let source: WeatherDataSource

    public init(
        temperatureCelsius: Double,
        humidityPercent: Double,
        apparentTemperatureCelsius: Double? = nil,
        conditionSymbolName: String? = nil,
        conditionDescription: String? = nil,
        windSpeedMetersPerSecond: Double? = nil,
        windDirectionDegrees: Double? = nil,
        uvIndex: Double? = nil,
        dewPointCelsius: Double? = nil,
        visibilityMeters: Double? = nil,
        precipitationChancePercent: Double? = nil,
        highTemperatureCelsius: Double? = nil,
        lowTemperatureCelsius: Double? = nil,
        cloudCoverPercent: Double? = nil,
        isDaylight: Bool? = nil,
        source: WeatherDataSource
    ) {
        self.temperatureCelsius = temperatureCelsius
        self.humidityPercent = max(0, humidityPercent)
        self.apparentTemperatureCelsius = apparentTemperatureCelsius
        self.conditionSymbolName = conditionSymbolName
        self.conditionDescription = conditionDescription
        self.windSpeedMetersPerSecond = windSpeedMetersPerSecond
        self.windDirectionDegrees = windDirectionDegrees
        self.uvIndex = uvIndex
        self.dewPointCelsius = dewPointCelsius
        self.visibilityMeters = visibilityMeters
        self.precipitationChancePercent = precipitationChancePercent
        self.highTemperatureCelsius = highTemperatureCelsius
        self.lowTemperatureCelsius = lowTemperatureCelsius
        self.cloudCoverPercent = cloudCoverPercent
        self.isDaylight = isDaylight
        self.source = source
    }

    public static func celsiusToFahrenheit(_ celsius: Double) -> Double {
        celsius * 9 / 5 + 32
    }

    public static func metersPerSecondToMPH(_ metersPerSecond: Double) -> Double {
        metersPerSecond * 2.23694
    }

    public static func metersToMiles(_ meters: Double) -> Double {
        meters / 1609.344
    }

    public var formattedTemperatureFahrenheit: String {
        "\(Int(Self.celsiusToFahrenheit(temperatureCelsius).rounded()))°"
    }

    public var formattedTemperatureFahrenheitWithUnit: String {
        "\(formattedTemperatureFahrenheit) F"
    }

    public var formattedApparentTemperatureFahrenheit: String? {
        guard let apparentTemperatureCelsius else { return nil }
        return "\(Int(Self.celsiusToFahrenheit(apparentTemperatureCelsius).rounded()))°"
    }

    public var formattedHumidity: String {
        "\(Int(humidityPercent.rounded()))%"
    }

    public var formattedWindSpeedMPH: String? {
        guard let windSpeedMetersPerSecond else { return nil }
        return "\(Int(Self.metersPerSecondToMPH(windSpeedMetersPerSecond).rounded())) mph"
    }

    public var formattedWind: String? {
        guard let windSpeedMetersPerSecond else { return nil }
        let speed = "\(Int(Self.metersPerSecondToMPH(windSpeedMetersPerSecond).rounded())) mph"
        guard let windDirectionDegrees else { return speed }
        return "\(Self.compassDirection(for: windDirectionDegrees)) \(speed)"
    }

    public var formattedUVIndex: String? {
        guard let uvIndex else { return nil }
        return "\(Int(uvIndex.rounded()))"
    }

    public var formattedDewPointFahrenheit: String? {
        guard let dewPointCelsius else { return nil }
        return "\(Int(Self.celsiusToFahrenheit(dewPointCelsius).rounded()))°"
    }

    public var formattedVisibilityMiles: String? {
        guard let visibilityMeters else { return nil }
        let miles = Self.metersToMiles(visibilityMeters)
        if miles >= 10 {
            return "\(Int(miles.rounded())) mi"
        }
        return String(format: "%.1f mi", miles)
    }

    public var formattedPrecipitationChance: String? {
        guard let precipitationChancePercent else { return nil }
        return "\(Int(precipitationChancePercent.rounded()))%"
    }

    public var formattedHighLowFahrenheit: String? {
        guard let highTemperatureCelsius, let lowTemperatureCelsius else { return nil }
        let high = Int(Self.celsiusToFahrenheit(highTemperatureCelsius).rounded())
        let low = Int(Self.celsiusToFahrenheit(lowTemperatureCelsius).rounded())
        return "H \(high)° · L \(low)°"
    }

    /// SF Symbol for UI when WeatherKit metadata is missing.
    public var displayConditionSymbolName: String {
        conditionSymbolName ?? "cloud.sun.fill"
    }

    /// Human-readable condition with source-aware fallback.
    public var displayConditionDescription: String {
        if let conditionDescription, !conditionDescription.isEmpty {
            return conditionDescription
        }
        switch source {
        case .healthKitWorkout:
            return "From workout"
        case .unavailable:
            return "Unavailable"
        case .weatherKit:
            return "Current conditions"
        }
    }

    public var displayApparentTemperatureFahrenheit: String {
        formattedApparentTemperatureFahrenheit ?? "—"
    }

    public var displayWind: String {
        formattedWind ?? "—"
    }

    public var displayUVIndex: String {
        formattedUVIndex ?? "—"
    }

    public var displayDewPointFahrenheit: String {
        formattedDewPointFahrenheit ?? "—"
    }

    public var displayVisibilityMiles: String {
        formattedVisibilityMiles ?? "—"
    }

    public var displayPrecipitationChance: String {
        formattedPrecipitationChance ?? "—"
    }

    public var hasSecondaryWeatherStats: Bool {
        formattedDewPointFahrenheit != nil
            || formattedVisibilityMiles != nil
            || formattedPrecipitationChance != nil
    }

    public static func compassDirection(for degrees: Double) -> String {
        let normalized = (degrees.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
        let directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        let index = Int((normalized + 22.5) / 45.0) % directions.count
        return directions[index]
    }

    public static func cacheKey(
        for date: Date,
        latitude: Double,
        longitude: Double,
        calendar: Calendar = .current
    ) -> String {
        let dayKey = ActivityFormatting.dayKey(for: date, calendar: calendar)
        let latBucket = Int((latitude * 100).rounded())
        let lonBucket = Int((longitude * 100).rounded())
        return "\(dayKey)-\(latBucket)-\(lonBucket)"
    }
}
