import CoreLocation
import Foundation
import WeatherKit

protocol WeatherKitProviding: Sendable {
    func fetchDayWeather(for date: Date, at location: CLLocation, calendar: Calendar) async throws -> DayWeatherSnapshot
    func fetchWorkoutWeather(at location: CLLocation, around startDate: Date) async throws -> DayWeatherSnapshot
}

enum WeatherKitClientError: LocalizedError, Sendable {
    case unavailable
    case noHourlyData

    var errorDescription: String? {
        switch self {
        case .unavailable:
            "WeatherKit is unavailable."
        case .noHourlyData:
            "No hourly weather data for this time."
        }
    }
}

actor LiveWeatherKitClient: WeatherKitProviding {
    private let service: WeatherService
    private var cache: [String: CachedWeather] = [:]

    init(service: WeatherService = .shared) {
        self.service = service
    }

    func fetchDayWeather(for date: Date, at location: CLLocation, calendar: Calendar) async throws -> DayWeatherSnapshot {
        let dayStart = calendar.startOfDay(for: date)
        let isToday = calendar.isDateInToday(date)
        let cacheKey = DayWeatherSnapshot.cacheKey(
            for: dayStart,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            calendar: calendar
        )

        if let cached = cachedSnapshot(for: cacheKey, isToday: isToday) {
            return cached
        }

        let snapshot: DayWeatherSnapshot
        if isToday {
            snapshot = try await fetchCurrentWeather(at: location)
        } else {
            snapshot = try await fetchHistoricalDayWeather(for: dayStart, at: location, calendar: calendar)
        }

        let ttl: TimeInterval = isToday ? 30 * 60 : 24 * 60 * 60
        cache[cacheKey] = CachedWeather(snapshot: snapshot, fetchedAt: Date(), ttl: ttl)
        return snapshot
    }

    func fetchWorkoutWeather(at location: CLLocation, around startDate: Date) async throws -> DayWeatherSnapshot {
        let windowStart = startDate.addingTimeInterval(-30 * 60)
        let windowEnd = startDate.addingTimeInterval(30 * 60)
        let cacheKey = "workout-\(Int(startDate.timeIntervalSince1970))-\(DayWeatherSnapshot.cacheKey(for: startDate, latitude: location.coordinate.latitude, longitude: location.coordinate.longitude))"

        if let cached = cache[cacheKey], Date().timeIntervalSince(cached.fetchedAt) < 24 * 60 * 60 {
            return cached.snapshot
        }

        let forecast: Forecast<HourWeather> = try await service.weather(
            for: location,
            including: .hourly(startDate: windowStart, endDate: windowEnd)
        )
        let hours = Array(forecast)
        guard let hour = closestHour(to: startDate, in: hours) else {
            throw WeatherKitClientError.noHourlyData
        }

        let snapshot = snapshot(from: hour)
        cache[cacheKey] = CachedWeather(snapshot: snapshot, fetchedAt: Date(), ttl: 24 * 60 * 60)
        return snapshot
    }

    private func fetchCurrentWeather(at location: CLLocation) async throws -> DayWeatherSnapshot {
        let current: CurrentWeather = try await service.weather(for: location, including: .current)
        return snapshot(from: current)
    }

    private func fetchHistoricalDayWeather(for dayStart: Date, at location: CLLocation, calendar: Calendar) async throws -> DayWeatherSnapshot {
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart.addingTimeInterval(86_400)
        let forecast: Forecast<HourWeather> = try await service.weather(
            for: location,
            including: .hourly(startDate: dayStart, endDate: dayEnd)
        )
        let hours = Array(forecast)
        guard !hours.isEmpty else {
            throw WeatherKitClientError.noHourlyData
        }

        let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: dayStart) ?? dayStart.addingTimeInterval(43_200)
        guard let hour = closestHour(to: noon, in: hours) else {
            throw WeatherKitClientError.noHourlyData
        }

        return snapshot(from: hour)
    }

    private func snapshot(from current: CurrentWeather) -> DayWeatherSnapshot {
        DayWeatherSnapshot(
            temperatureCelsius: celsiusValue(from: current.temperature),
            humidityPercent: current.humidity * 100,
            apparentTemperatureCelsius: celsiusValue(from: current.apparentTemperature),
            conditionSymbolName: current.symbolName,
            source: .weatherKit
        )
    }

    private func snapshot(from hour: HourWeather) -> DayWeatherSnapshot {
        DayWeatherSnapshot(
            temperatureCelsius: celsiusValue(from: hour.temperature),
            humidityPercent: hour.humidity * 100,
            apparentTemperatureCelsius: celsiusValue(from: hour.apparentTemperature),
            conditionSymbolName: hour.symbolName,
            source: .weatherKit
        )
    }

    private func celsiusValue(from measurement: Measurement<UnitTemperature>) -> Double {
        measurement.converted(to: .celsius).value
    }

    private func closestHour(to date: Date, in hours: [HourWeather]) -> HourWeather? {
        hours.min { lhs, rhs in
            abs(lhs.date.timeIntervalSince(date)) < abs(rhs.date.timeIntervalSince(date))
        }
    }

    private func cachedSnapshot(for key: String, isToday: Bool) -> DayWeatherSnapshot? {
        guard let cached = cache[key] else { return nil }
        let age = Date().timeIntervalSince(cached.fetchedAt)
        if age > cached.ttl {
            cache.removeValue(forKey: key)
            return nil
        }
        if isToday, age > 30 * 60 {
            cache.removeValue(forKey: key)
            return nil
        }
        return cached.snapshot
    }
}

private struct CachedWeather: Sendable {
    let snapshot: DayWeatherSnapshot
    let fetchedAt: Date
    let ttl: TimeInterval
}

struct DisabledWeatherKitClient: WeatherKitProviding, Sendable {
    func fetchDayWeather(for date: Date, at location: CLLocation, calendar: Calendar) async throws -> DayWeatherSnapshot {
        throw WeatherKitClientError.unavailable
    }

    func fetchWorkoutWeather(at location: CLLocation, around startDate: Date) async throws -> DayWeatherSnapshot {
        throw WeatherKitClientError.unavailable
    }
}
