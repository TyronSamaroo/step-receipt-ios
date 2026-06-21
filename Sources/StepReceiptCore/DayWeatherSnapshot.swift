import Foundation

public enum WeatherDataSource: String, Codable, Equatable, Sendable {
    case weatherKit
    case healthKitWorkout
    case unavailable
}

public struct DayWeatherSnapshot: Equatable, Sendable {
    public let temperatureCelsius: Double
    public let humidityPercent: Double
    public let apparentTemperatureCelsius: Double?
    public let conditionSymbolName: String?
    public let source: WeatherDataSource

    public init(
        temperatureCelsius: Double,
        humidityPercent: Double,
        apparentTemperatureCelsius: Double? = nil,
        conditionSymbolName: String? = nil,
        source: WeatherDataSource
    ) {
        self.temperatureCelsius = temperatureCelsius
        self.humidityPercent = max(0, humidityPercent)
        self.apparentTemperatureCelsius = apparentTemperatureCelsius
        self.conditionSymbolName = conditionSymbolName
        self.source = source
    }

    public static func celsiusToFahrenheit(_ celsius: Double) -> Double {
        celsius * 9 / 5 + 32
    }

    public var formattedTemperatureFahrenheit: String {
        "\(Int(Self.celsiusToFahrenheit(temperatureCelsius).rounded())) F"
    }

    public var formattedApparentTemperatureFahrenheit: String? {
        guard let apparentTemperatureCelsius else { return nil }
        return "\(Int(Self.celsiusToFahrenheit(apparentTemperatureCelsius).rounded())) F"
    }

    public var formattedHumidity: String {
        "\(Int(humidityPercent.rounded()))%"
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
